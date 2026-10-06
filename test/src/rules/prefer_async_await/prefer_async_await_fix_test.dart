// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_async_await/prefer_async_await.dart';
import 'package:elint/src/rules/prefer_async_await/prefer_async_await_fix.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferAsyncAwaitFixTest);
  });
}

@reflectiveTest
class PreferAsyncAwaitFixTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferAsyncAwait();
    super.setUp();
  }

  Future<void> test_rewrites_a_single_returned_callback() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> count() async {
  return readText().then((text) => text.length);
}
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
Future<String> readText() async => 'value';

Future<int> count() async {
  final text = await readText();
  return text.length;
}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_multi_fix_combines_independent_returns() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> count(bool first) async {
  if (first) {
    return readText().then((text) => text.length);
  }
  return readText().then((content) => content.length);
}
''';
    final diagnostics = await _diagnostics(source);
    expect(diagnostics, hasLength(2));
    final libraryResult = await _libraryResult();
    final builder = ChangeBuilder(session: result.session);

    for (final diagnostic in diagnostics) {
      final context = CorrectionProducerContext.createResolved(
        applyingBulkFixes: true,
        libraryResult: libraryResult,
        unitResult: result,
        diagnostic: diagnostic,
        selectionOffset: diagnostic.offset,
      );
      final fix = PreferAsyncAwaitFix(context: context);
      expect(fix.multiFixKind, PreferAsyncAwaitFix.multiKind);
      await fix.compute(builder);
    }

    final fixed = _applyEdits(source, builder.sourceChange.edits.single.edits);
    expect(fixed, '''
Future<String> readText() async => 'value';

Future<int> count(bool first) async {
  if (first) {
    final text = await readText();
    return text.length;
  }
  final content = await readText();
  return content.length;
}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_withholds_fix_when_function_is_not_async() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> count() => readText().then((text) => text.length);
''';
    final diagnostic = await _singleDiagnostic(source);
    final builder = await _computeFix(source, diagnostic);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> test_withholds_fix_for_chains_and_block_callbacks() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> count() async => readText()
    .then((text) => text)
    .then((text) => text.length);

Future<int> block() async => readText().then((text) {
  return text.length;
});
''';
    final diagnostics = await _diagnostics(source);
    expect(diagnostics, hasLength(3));
    for (final diagnostic in diagnostics) {
      final builder = await _computeFix(source, diagnostic);
      expect(builder.sourceChange.edits, isEmpty);
    }
  }

  Future<void> test_withholds_fix_when_rewrite_discards_comments() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> count() async {
  return readText().then((text) => /* keep */ text.length);
}
''';
    final diagnostic = await _singleDiagnostic(source);
    final builder = await _computeFix(source, diagnostic);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> test_withholds_fix_for_typed_callback_parameter() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> count() async {
  return readText().then((String text) => text.length);
}
''';
    final diagnostic = await _singleDiagnostic(source);
    final builder = await _computeFix(source, diagnostic);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> test_withholds_fix_when_callback_value_is_unused() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> count() async {
  return readText().then((text) => 1);
}
''';
    final diagnostic = await _singleDiagnostic(source);
    final builder = await _computeFix(source, diagnostic);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<Diagnostic> _singleDiagnostic(String source) async {
    final diagnostics = await _diagnostics(source);
    expect(diagnostics, hasLength(1));
    return diagnostics.single;
  }

  Future<List<Diagnostic>> _diagnostics(String source) async {
    await assertDiagnostics(source, [
      for (final match in RegExp(r'\.then\b').allMatches(source))
        lint(match.start + 1, 'then'.length),
    ]);
    return result.diagnostics;
  }

  Future<ChangeBuilder> _computeFix(
    String source,
    Diagnostic diagnostic,
  ) async {
    final libraryResult = await _libraryResult();
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      diagnostic: diagnostic,
      selectionOffset: diagnostic.offset,
    );
    final builder = ChangeBuilder(session: result.session);
    await PreferAsyncAwaitFix(context: context).compute(builder);
    return builder;
  }

  Future<String> _apply(String source, Diagnostic diagnostic) async {
    final builder = await _computeFix(source, diagnostic);
    return _applyEdits(source, builder.sourceChange.edits.single.edits);
  }

  Future<ResolvedLibraryResult> _libraryResult() async {
    final libraryResult = await result.session.getResolvedLibrary(
      testFile.path,
    );
    if (libraryResult is! ResolvedLibraryResult) {
      throw StateError('Expected a resolved library for the test source.');
    }
    return libraryResult;
  }

  Future<void> _assertCorrectedSource(String source) async {
    expect(parseString(content: source).errors, isEmpty);
    final correctedFile = newFile('${testFile.path}.fixed.dart', source);
    await resolveFile(path: correctedFile.path);
    await assertNoDiagnosticsInFile(correctedFile.path);
  }
}

String _applyEdits(String source, List<SourceEdit> edits) {
  var result = source;
  for (final edit in edits.toList()..sort((a, b) => b.offset - a.offset)) {
    result = result.replaceRange(
      edit.offset,
      edit.offset + edit.length,
      edit.replacement,
    );
  }
  return result;
}

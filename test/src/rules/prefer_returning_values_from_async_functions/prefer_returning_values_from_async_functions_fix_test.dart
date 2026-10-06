// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions.dart';
import 'package:elint/src/rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions_fix.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferReturningValuesFromAsyncFunctionsFixTest);
  });
}

@reflectiveTest
class PreferReturningValuesFromAsyncFunctionsFixTest()
    extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferReturningValuesFromAsyncFunctions();
    super.setUp();
  }

  Future<void> test_adds_async_to_sync_function() async {
    const source = '''
Future<int> count() {
  return Future<int>.value(1);
}
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
Future<int> count() async {
  return 1;
}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_keeps_existing_async_modifier() async {
    const source = '''
Future<int> count() async => Future.value(1);
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
Future<int> count() async => 1;
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_withholds_edit_when_wrapper_contains_comments() async {
    const source = '''
Future<int> count() => Future.value(/* keep */ 1);
''';
    final diagnostic = await _singleDiagnostic(source);
    final libraryResult = await _libraryResult();
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      diagnostic: diagnostic,
      selectionOffset: diagnostic.offset,
    );
    final builder = ChangeBuilder(session: result.session);
    await PreferReturningValuesFromAsyncFunctionsFix(context: context)
        .compute(builder);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void>
  test_multi_fix_rewrites_every_matching_return_in_function() async {
    const source = '''
Future<int> count(bool first) {
  if (first) return Future.value(1);
  return Future.value(2);
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
      final fix = PreferReturningValuesFromAsyncFunctionsFix(context: context);
      expect(
        fix.multiFixKind,
        PreferReturningValuesFromAsyncFunctionsFix.multiKind,
      );
      await fix.compute(builder);
    }

    final fixed = _applyEdits(source, builder.sourceChange.edits.single.edits);
    expect(fixed, '''
Future<int> count(bool first) async {
  if (first) return 1;
  return 2;
}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_in_file_fix_combines_separate_functions() async {
    const source = '''
Future<int> first() => Future.value(1);
Future<int> second() => Future.value(2);
''';
    final diagnostics = await _diagnostics(source);
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
      await PreferReturningValuesFromAsyncFunctionsFix(context: context)
          .compute(builder);
    }

    final fixed = _applyEdits(source, builder.sourceChange.edits.single.edits);
    expect(fixed, '''
Future<int> first() async => 1;
Future<int> second() async => 2;
''');
    await _assertCorrectedSource(fixed);
  }

  Future<Diagnostic> _singleDiagnostic(String source) async {
    final diagnostics = await _diagnostics(source);
    expect(diagnostics, hasLength(1));
    return diagnostics.single;
  }

  Future<List<Diagnostic>> _diagnostics(String source) async {
    await assertDiagnostics(source, [
      for (final match in RegExp(
        r'Future(?:<[^>]+>)?\.value',
      ).allMatches(source))
        lint(match.start, source.indexOf(')', match.start) + 1 - match.start),
    ]);
    return result.diagnostics;
  }

  Future<String> _apply(String source, Diagnostic diagnostic) async {
    final libraryResult = await _libraryResult();
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      diagnostic: diagnostic,
      selectionOffset: diagnostic.offset,
    );
    final builder = ChangeBuilder(session: result.session);
    await PreferReturningValuesFromAsyncFunctionsFix(context: context)
        .compute(builder);

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
    final resolved = await resolveFile(path: correctedFile.path);
    expect(resolved, isA<ResolvedUnitResult>());
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

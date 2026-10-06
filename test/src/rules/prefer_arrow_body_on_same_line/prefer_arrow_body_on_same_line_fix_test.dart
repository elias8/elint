// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line.dart';
import 'package:elint/src/rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line_fix.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferArrowBodyOnSameLineFixTest);
  });
}

@reflectiveTest
class PreferArrowBodyOnSameLineFixTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferArrowBodyOnSameLine();
    super.setUp();
  }

  Future<void> test_converts_value_function_to_block_return() async {
    const source = '''
class Item {}
String formatItem(Item item) => 'item';

String format(Item item) =>
    formatItem(item);
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
class Item {}
String formatItem(Item item) => 'item';

String format(Item item) {
    return formatItem(item);}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_converts_void_callback_to_expression_statement() async {
    const source = '''
class Item {}

void logItems(List<Item> items) {
  items.forEach((item) =>
      print(item));
}
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
class Item {}

void logItems(List<Item> items) {
  items.forEach((item) {
      print(item);});
}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_returns_future_from_synchronous_function() async {
    const source = '''
Future<int> loadValue() => Future<int>.value(1);

Future<int> load() =>
    loadValue();
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
Future<int> loadValue() => Future<int>.value(1);

Future<int> load() {
    return loadValue();}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void>
  test_returns_future_expression_from_async_value_function() async {
    const source = '''
Future<int> loadValue() async => 1;

Future<int> load() async =>
    loadValue();
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
Future<int> loadValue() async => 1;

Future<int> load() async {
    return loadValue();}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_awaits_future_from_async_void_callback() async {
    const source = '''
Future<void> write() async {}

final callback = () async =>
    write();
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
Future<void> write() async {}

final callback = () async {
    await (write());};
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_does_not_add_return_for_never_expression() async {
    const source = '''
class Stop {}
Never fail() => throw Stop();

void invoke() =>
    fail();

int value() =>
    fail();
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
      await PreferArrowBodyOnSameLineFix(context: context).compute(builder);
    }
    final fixed = _applyEdits(source, builder.sourceChange.edits.single.edits);

    expect(fixed, '''
class Stop {}
Never fail() => throw Stop();

void invoke() {
    fail();}

int value() {
    fail();}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_awaits_async_future_void_assignment() async {
    const source = '''
Future<void> ab = Future<void>.value();
Future<void> cd = Future<void>.value();

Future<void> update() async =>
    ab = cd;
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
Future<void> ab = Future<void>.value();
Future<void> cd = Future<void>.value();

Future<void> update() async {
    await (ab = cd);}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_keeps_async_modifier_and_comments() async {
    const source = '''
Future<int> loadValue() async => 1;

Future<int> load() async =>
    // Keep this explanation.
    await loadValue();
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _apply(source, diagnostic);

    expect(fixed, '''
Future<int> loadValue() async => 1;

Future<int> load() async {
    // Keep this explanation.
    return await loadValue();}
''');
    await _assertCorrectedSource(fixed);
  }

  Future<void> test_withholds_edit_for_trailing_callback_comment() async {
    const source = '''
final callbacks = <void Function()>[
  () =>
      print('value') /* attached to the callback */,
];
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
    await PreferArrowBodyOnSameLineFix(context: context).compute(builder);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> test_withholds_edit_for_dynamic_return_type() async {
    const source = '''
final dynamic Function(dynamic) callback = (value) =>
    value;
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
    await PreferArrowBodyOnSameLineFix(context: context).compute(builder);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> test_multi_fix_combines_nested_arrows() async {
    const source = '''
int Function() make() =>
    () =>
        1;
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
      final fix = PreferArrowBodyOnSameLineFix(context: context);
      expect(fix.multiFixKind, PreferArrowBodyOnSameLineFix.multiKind);
      await fix.compute(builder);
    }

    final edits = builder.sourceChange.edits.single.edits.toList()
      ..sort((a, b) => b.offset - a.offset);
    var fixed = source;
    for (final edit in edits) {
      fixed = fixed.replaceRange(
        edit.offset,
        edit.offset + edit.length,
        edit.replacement,
      );
    }
    expect(fixed, '''
int Function() make() {
    return () {
        return 1;};}
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
      for (final match in RegExp(r'=>\n').allMatches(source))
        lint(match.start, 2),
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
    final fix = PreferArrowBodyOnSameLineFix(context: context);
    expect(fix.fixKind, PreferArrowBodyOnSameLineFix.kind);
    await fix.compute(builder);
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

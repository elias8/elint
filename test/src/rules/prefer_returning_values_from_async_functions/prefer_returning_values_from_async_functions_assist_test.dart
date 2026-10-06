// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions.dart';
import 'package:elint/src/rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions_assist.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferReturningValuesFromAsyncFunctionsAssistTest);
  });
}

@reflectiveTest
class PreferReturningValuesFromAsyncFunctionsAssistTest()
    extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferReturningValuesFromAsyncFunctions();
    super.setUp();
  }

  Future<void> test_assists_on_selected_return_expression() async {
    const source = 'Future<int> count() => Future.value(1);';
    await assertDiagnostics(source, [
      lint(source.indexOf('Future.value'), 'Future.value(1)'.length),
    ]);
    final fixed = await _applyAssist(
      source,
      selectionOffset: source.indexOf('Future.value'),
      selectionLength: 'Future.value(1)'.length,
    );

    expect(fixed, 'Future<int> count() async => 1;');
    expect(parseString(content: fixed).errors, isEmpty);
  }

  Future<void> test_does_not_assist_outside_return_expression() async {
    const source = '''
Future<int> count() => Future.value(1);
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('Future.value'), 'Future.value(1)'.length),
    ]);
    final libraryResult = await result.session.getResolvedLibrary(
      testFile.path,
    );
    if (libraryResult is! ResolvedLibraryResult) {
      throw StateError('Expected a resolved library for the test source.');
    }
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      selectionOffset: source.indexOf('count'),
      selectionLength: 'count'.length,
    );
    final builder = ChangeBuilder(session: result.session);
    await PreferReturningValuesFromAsyncFunctionsAssist(context: context)
        .compute(builder);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<String> _applyAssist(
    String source, {
    required int selectionOffset,
    required int selectionLength,
  }) async {
    final libraryResult = await result.session.getResolvedLibrary(
      testFile.path,
    );
    if (libraryResult is! ResolvedLibraryResult) {
      throw StateError('Expected a resolved library for the test source.');
    }
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      selectionOffset: selectionOffset,
      selectionLength: selectionLength,
    );
    final builder = ChangeBuilder(session: result.session);
    await PreferReturningValuesFromAsyncFunctionsAssist(context: context)
        .compute(builder);

    final edits = builder.sourceChange.edits.single.edits.toList()
      ..sort((a, b) => b.offset - a.offset);
    var assisted = source;
    for (final edit in edits) {
      assisted = assisted.replaceRange(
        edit.offset,
        edit.offset + edit.length,
        edit.replacement,
      );
    }
    return assisted;
  }
}

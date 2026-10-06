// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_async_await/prefer_async_await.dart';
import 'package:elint/src/rules/prefer_async_await/prefer_async_await_assist.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferAsyncAwaitAssistTest);
  });
}

@reflectiveTest
class PreferAsyncAwaitAssistTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferAsyncAwait();
    super.setUp();
  }

  Future<void> test_assists_on_selected_invocation() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> count() async {
  return readText().then((text) => text.length);
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('then'), 'then'.length),
    ]);
    final fixed = await _applyAssist(
      source,
      selectionOffset: source.indexOf('then'),
      selectionLength: 'then'.length,
    );

    expect(fixed, '''
Future<String> readText() async => 'value';

Future<int> count() async {
  final text = await readText();
  return text.length;
}
''');
  }

  Future<void> test_does_not_assist_outside_invocation() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> count() async => readText().then((text) => text.length);
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('then'), 'then'.length),
    ]);
    final builder = await _computeAssist(
      source,
      selectionOffset: source.indexOf('count'),
      selectionLength: 'count'.length,
    );

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<String> _applyAssist(
    String source, {
    required int selectionOffset,
    required int selectionLength,
  }) async {
    final builder = await _computeAssist(
      source,
      selectionOffset: selectionOffset,
      selectionLength: selectionLength,
    );
    var result = source;
    for (final edit
        in builder.sourceChange.edits.single.edits.toList()
          ..sort((a, b) => b.offset - a.offset)) {
      result = result.replaceRange(
        edit.offset,
        edit.offset + edit.length,
        edit.replacement,
      );
    }
    return result;
  }

  Future<ChangeBuilder> _computeAssist(
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
    await PreferAsyncAwaitAssist(context: context).compute(builder);
    return builder;
  }
}

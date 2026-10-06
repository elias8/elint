// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line.dart';
import 'package:elint/src/rules/prefer_arrow_body_on_same_line/prefer_arrow_body_on_same_line_assist.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferArrowBodyOnSameLineAssistTest);
  });
}

@reflectiveTest
class PreferArrowBodyOnSameLineAssistTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferArrowBodyOnSameLine();
    super.setUp();
  }

  Future<void> test_assists_on_selected_callback_arrow_body() async {
    const source = '''
class Item {}
final items = <Item>[];
String formatItem(Item item) => 'item';

final values = items.map((item) =>
    formatItem(item));
''';
    await assertDiagnostics(source, [lint(source.lastIndexOf('=>'), 2)]);
    final fixed = await _applyAssist(
      source,
      selectionOffset: source.lastIndexOf('formatItem'),
      selectionLength: 'formatItem(item)'.length,
    );

    expect(fixed, '''
class Item {}
final items = <Item>[];
String formatItem(Item item) => 'item';

final values = items.map((item) {
    return formatItem(item);});
''');
    expect(parseString(content: fixed).errors, isEmpty);
  }

  Future<void> test_does_not_assist_outside_selected_body() async {
    const source = '''
class Item {}
String formatItem(Item item) => 'item';

String format(Item item) =>
    formatItem(item);
''';
    await assertDiagnostics(source, [lint(source.lastIndexOf('=>'), 2)]);
    final libraryResult = await _libraryResult();
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      selectionOffset: source.indexOf('format(Item'),
      selectionLength: 'format(Item item)'.length,
    );
    final builder = ChangeBuilder(session: result.session);
    await PreferArrowBodyOnSameLineAssist(context: context).compute(builder);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> test_does_not_assist_when_arrow_body_already_complies() async {
    const source = '''
class Item {}
String formatItem(Item item) => 'item';
String format(Item item) => formatItem(item);
''';
    await assertNoDiagnostics(source);
    final libraryResult = await _libraryResult();
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      selectionOffset: source.lastIndexOf('formatItem'),
      selectionLength: 'formatItem(item)'.length,
    );
    final builder = ChangeBuilder(session: result.session);
    await PreferArrowBodyOnSameLineAssist(context: context).compute(builder);

    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<String> _applyAssist(
    String source, {
    required int selectionOffset,
    required int selectionLength,
  }) async {
    final libraryResult = await _libraryResult();
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      selectionOffset: selectionOffset,
      selectionLength: selectionLength,
    );
    final builder = ChangeBuilder(session: result.session);
    await PreferArrowBodyOnSameLineAssist(context: context).compute(builder);
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

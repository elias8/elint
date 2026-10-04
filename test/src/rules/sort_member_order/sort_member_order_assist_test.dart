// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/sort_member_order/sort_member_order.dart';
import 'package:elint/src/rules/sort_member_order/sort_member_order_assist.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SortMemberOrderAssistTest);
  });
}

@reflectiveTest
class SortMemberOrderAssistTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = SortMemberOrder();
    super.setUp();
  }

  Future<void> test_moves_constructor_at_declaration_selection() async {
    const source = '''
class Example {
  Example();
  int value = 0;
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('Example();'), 'Example();'.length),
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
      selectionOffset: source.indexOf('class Example'),
    );
    final builder = ChangeBuilder(session: result.session);
    await SortMemberOrderAssist(context: context).compute(builder);

    final edits = builder.sourceChange.edits.single.edits;
    expect(edits, hasLength(1));
    final edit = edits.single;
    final assisted = source.replaceRange(
      edit.offset,
      edit.offset + edit.length,
      edit.replacement,
    );

    expect(assisted, '''
class Example {
  int value = 0;
  Example();
}
''');
    expect(parseString(content: assisted).errors, isEmpty);
  }

  Future<void> test_custom_order_assist_uses_selected_category_order() async {
    final optionsFile = resourceProvider.getFile(
      join(testPackageRootPath, 'analysis_options.yaml'),
    );
    optionsFile.writeAsStringSync(
      '${optionsFile.readAsStringSync()}\nelint:\n'
      '  diagnostics:\n'
      '    sort_member_order:\n'
      '      order: [constructors, fields, methods]\n',
    );
    const source = '''
class Example {
  Example();
  void run() {}
  int value = 0;
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('void run() {}'), 'void run() {}'.length),
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
      selectionOffset: source.indexOf('class Example'),
    );
    final builder = ChangeBuilder(session: result.session);
    await SortMemberOrderAssist(context: context).compute(builder);
    final edit = builder.sourceChange.edits.single.edits.single;
    final assisted = source.replaceRange(
      edit.offset,
      edit.offset + edit.length,
      edit.replacement,
    );
    expect(assisted, '''
class Example {
  Example();
  int value = 0;
  void run() {}
}
''');
  }
}

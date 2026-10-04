// ignore_for_file: non_constant_identifier_names
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/sort_member_order/member_order_config.dart';
import 'package:elint/src/rules/sort_member_order/sort_member_order.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SortMemberOrderTest);
  });
}

@reflectiveTest
class SortMemberOrderTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = SortMemberOrder();
    super.setUp();
  }

  Future<void> test_constructor_before_field() async {
    const source = 'class Example { Example(); int value = 0; }';

    await assertDiagnostics(source, [
      lint(source.indexOf('Example();'), 'Example();'.length),
    ]);
  }

  Future<void> test_enum_constructor_before_field() async {
    const source = '''
enum Level {
  low;
  const Level();
  final int rank = 0;
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('const Level();'), 'const Level();'.length),
    ]);
  }

  Future<void> test_field_before_constructor() async {
    await assertNoDiagnostics('''
class Example {
  int value = 0;
  Example();
}
''');
  }

  Future<void> test_method_does_not_affect_order() async {
    await assertNoDiagnostics('''
class Example {
  void method() {}
  int value = 0;
  Example();
}
''');
  }

  Future<void> test_primary_constructor_header() async {
    await assertNoDiagnostics('''
class Point(final int x) {
  int y = 0;
}
''');
  }

  Future<void> test_reports_once_per_declaration() async {
    const source =
        'class Example { Example(); Example.named(); int value = 0; }';

    await assertDiagnostics(source, [
      lint(source.indexOf('Example();'), 'Example();'.length),
    ]);
  }

  Future<void> test_constructor_without_fields() async {
    await assertNoDiagnostics('class Example { Example(); }');
  }

  Future<void> test_order_all_five_categories() async {
    const source = '''
class Example {
  void run() {}
  set value(int value) {}
  Example();
  int get count => 0;
  int field = 0;
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('Example();'), 'Example();'.length),
    ]);
  }

  Future<void> test_only_one_selected_category_is_noop() async {
    expect(
      planMemberOrder(const [], const [
        MemberCategory.fields,
      ]).firstChangedMember,
      isNull,
    );
  }

  Future<void> test_invalid_configuration_reports_once_for_the_unit() async {
    final optionsFile = resourceProvider.getFile(
      join(testPackageRootPath, 'analysis_options.yaml'),
    );
    optionsFile.writeAsStringSync(
      '${optionsFile.readAsStringSync()}\nelint:\n'
      '  diagnostics:\n'
      '    sort_member_order:\n'
      '      order: [fields, fields]\n',
    );
    const source = '''
class First {
  First();
  int value = 0;
}
class Second {
  Second();
  int value = 0;
}
''';
    await assertDiagnostics(source, [lint(0, source.length)]);
    expect(
      result.diagnostics.single.message,
      contains('analysis_options.yaml'),
    );
    expect(result.diagnostics.single.message, contains('duplicate category'));
  }

  Future<void> test_custom_order_reorders_selected_slots_stably() async {
    final unit = parseString(
      content: '''
class Example {
  Example.first();
  void before() {}
  int value = 0;
  void after() {}
  Example.second();
}
''',
    ).unit;
    final declaration = unit.declarations.single as ClassDeclaration;
    final plan = planMemberOrder(declaration.body.members, [
      MemberCategory.fields,
      MemberCategory.methods,
      MemberCategory.constructors,
    ]);
    expect(plan.members.map((member) => member.toSource()), [
      'int value = 0;',
      'void before() {}',
      'void after() {}',
      'Example.first();',
      'Example.second();',
    ]);
  }

  Future<void> test_partial_order_leaves_unselected_slots_unchanged() async {
    final unit = parseString(
      content: '''
class Example {
  Example();
  void before() {}
  int value = 0;
  void after() {}
}
''',
    ).unit;
    final declaration = unit.declarations.single as ClassDeclaration;
    final plan = planMemberOrder(declaration.body.members, [
      MemberCategory.fields,
      MemberCategory.constructors,
    ]);
    expect(plan.members.map((member) => member.toSource()), [
      'int value = 0;',
      'void before() {}',
      'Example();',
      'void after() {}',
    ]);
  }
}

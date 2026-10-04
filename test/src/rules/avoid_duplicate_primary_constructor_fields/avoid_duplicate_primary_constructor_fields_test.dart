// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidDuplicatePrimaryConstructorFieldsTest);
  });
}

@reflectiveTest
class AvoidDuplicatePrimaryConstructorFieldsTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidDuplicatePrimaryConstructorFields();
    super.setUp();
  }

  Future<void> test_reports_field_copied_from_declaring_parameter() async {
    const source = '''
class SomeClass(final int value) {
  final int _value = value;
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('final int value'), 'final int value'.length),
    ]);
  }

  Future<void> test_ignores_plain_constructor_parameter() async {
    await assertNoDiagnostics('''
class SomeClass(int value) {
  final int _value = value;
}
''');
  }

  Future<void> test_ignores_unrelated_field_initializer() async {
    await assertNoDiagnostics('''
class SomeClass(final int value) {
  final int _value = 0;
}
''');
  }

  Future<void> test_ignores_a_differently_named_private_field() async {
    await assertNoDiagnostics('''
class SomeClass(final int value) {
  final int _copy = value;
}
''');
  }

  Future<void> test_ignores_initializer_using_another_parameter() async {
    await assertNoDiagnostics('''
class SomeClass(final int value, int other) {
  final int _value = other;
}
''');
  }

  Future<void> test_reports_each_parameter_once() async {
    const source = '''
class Example(final int value, final String name) {
  final int _value = value;
  final String _name = name;
  final int _alsoValue = value;
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('final int value'), 'final int value'.length),
      lint(source.indexOf('final String name'), 'final String name'.length),
    ]);
  }
}

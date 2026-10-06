// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_returning_values_from_async_functions/prefer_returning_values_from_async_functions.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferReturningValuesFromAsyncFunctionsTest);
  });
}

@reflectiveTest
class PreferReturningValuesFromAsyncFunctionsTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferReturningValuesFromAsyncFunctions();
    super.setUp();
  }

  Future<void> test_reports_block_arrow_and_async_returns() async {
    const source = '''
Future<int> block() {
  return Future<int>.value(1);
}

Future<int> arrow() => Future.value(2);

Future<int> alreadyAsync() async {
  return Future.value(3);
}

final Future<int> Function() callback = () => Future.value(4);
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('Future<int>.value'), 'Future<int>.value(1)'.length),
      lint(source.indexOf('Future.value'), 'Future.value(2)'.length),
      lint(
        source.indexOf('Future.value', source.indexOf('Future.value') + 1),
        'Future.value(3)'.length,
      ),
      lint(source.lastIndexOf('Future.value'), 'Future.value(4)'.length),
    ]);
  }

  Future<void> test_ignores_other_uses_and_other_value_constructors() async {
    await assertNoDiagnostics('''
class Box {
  Box.value(int value);
}

Future<int> saved = Future.value(1);
Future<int> returnedSaved() => saved;
Box makeBox() => Box.value(2);
Future<void> empty() => Future<void>.value();
Object objectResult() => Future.value(3);
''');
  }
}

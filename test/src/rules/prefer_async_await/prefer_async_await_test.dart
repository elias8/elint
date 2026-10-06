// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_async_await/prefer_async_await.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferAsyncAwaitTest);
  });
}

@reflectiveTest
class PreferAsyncAwaitTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferAsyncAwait();
    super.setUp();
  }

  Future<void> test_reports_single_and_each_chained_call() async {
    const source = '''
Future<String> readText() async => 'value';

Future<int> single() => readText().then((text) => text.length);

Future<int> chained() =>
    readText().then((text) => text).then((text) => text.length);

void callback(Future<String> future) {
  future.then((_) {});
}
''';

    final singleThen = source.indexOf('then');
    final firstChainedThen = source.indexOf('then', singleThen + 1);
    final secondChainedThen = source.indexOf('then', firstChainedThen + 1);
    final callbackThen = source.lastIndexOf('then');
    await assertDiagnostics(source, [
      lint(singleThen, 'then'.length),
      lint(firstChainedThen, 'then'.length),
      lint(secondChainedThen, 'then'.length),
      lint(callbackThen, 'then'.length),
    ]);
  }

  Future<void> test_ignores_custom_then_method() async {
    await assertNoDiagnostics('''
class Box {
  void then(void Function() callback) {}
}

void useBox() {
  Box().then(() {});
}
''');
  }
}

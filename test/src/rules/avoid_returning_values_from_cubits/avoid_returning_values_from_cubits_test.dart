// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/avoid_returning_values_from_cubits/avoid_returning_values_from_cubits.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidReturningValuesFromCubitsTest);
  });
}

@reflectiveTest
class AvoidReturningValuesFromCubitsTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidReturningValuesFromCubits();
    newPackage('bloc')
      ..addFile('lib/bloc.dart', "export 'src/cubit.dart';")
      ..addFile('lib/src/cubit.dart', '''
abstract class Cubit<State>(State initialState) {
  State state = initialState;
  void emit(State state) => this.state = state;
}
''');
    super.setUp();
  }

  Future<void> test_reports_public_methods_that_return_values() async {
    const source = '''
import 'dart:async';
import 'package:bloc/bloc.dart';

class ProfileCubit() extends Cubit<int> {
  this : super(0);

  int currentCount() => state;
  Future<String> loadLabel() async => state.toString();
  Future<void>? maybeRefresh() => null;
  FutureOr<void> refreshMaybe() => Future<void>.value();
  currentCountInferred() => state;
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('int currentCount'), 'int'.length),
      lint(source.indexOf('Future<String>'), 'Future<String>'.length),
      lint(source.indexOf('Future<void>?'), 'Future<void>?'.length),
      lint(source.indexOf('FutureOr<void>'), 'FutureOr<void>'.length),
      lint(
        source.indexOf('currentCountInferred'),
        'currentCountInferred'.length,
      ),
    ]);
  }

  Future<void> test_allows_void_and_future_void_methods() async {
    await assertNoDiagnostics('''
import 'package:bloc/bloc.dart';

typedef Refresh = Future<void>;

class ProfileCubit() extends Cubit<int> {
  this : super(0);

  void refresh() {}
  Future<void> refreshAsync() async {}
  Refresh refreshThroughAlias() async {}
}
''');
  }

  Future<void> test_ignores_private_static_and_property_members() async {
    await assertNoDiagnostics('''
import 'package:bloc/bloc.dart';

class ProfileCubit() extends Cubit<int> {
  this : super(0);

  int get currentCount => state;
  int _helper() => state;
  static int parseCount(String value) => int.parse(value);
}
''');
  }

  Future<void> test_reports_methods_in_intermediate_cubit_subclasses() async {
    const source = '''
import 'package:bloc/bloc.dart';

abstract class BaseCubit<State>(super.initialState) extends Cubit<State>;

class ProfileCubit() extends BaseCubit<int> {
  this : super(0);

  int currentCount() => state;
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('int currentCount'), 'int'.length),
    ]);
  }

  Future<void> test_ignores_non_cubit_classes() async {
    await assertNoDiagnostics('''
class Cubit<State>(State state);

class ProfileCubit() extends Cubit<int> {
  this : super(0);

  int currentCount() => 0;
}
''');
  }
}

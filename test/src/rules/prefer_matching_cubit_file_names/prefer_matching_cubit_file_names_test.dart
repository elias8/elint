// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/prefer_matching_cubit_file_names/prefer_matching_cubit_file_names.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferMatchingCubitFileNamesTest);
  });
}

@reflectiveTest
class PreferMatchingCubitFileNamesTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferMatchingCubitFileNames();
    newPackage('bloc')
      ..addFile('lib/bloc.dart', "export 'src/cubit.dart';")
      ..addFile('lib/src/cubit.dart', '''
abstract class Cubit<State>(State initialState);
abstract class Bloc<Event, State>(State initialState);
''');
    super.setUp();
  }

  Future<void> test_accepts_matching_file_name_in_nested_directory() async {
    final source = _cubitSource('CounterCubit');
    newFile('/home/test/lib/features/counter/counter_cubit.dart', source);

    await assertNoDiagnosticsInFile(
      '/home/test/lib/features/counter/counter_cubit.dart',
    );
  }

  Future<void> test_reports_cubit_in_file_with_different_name() async {
    final source = _cubitSource('CounterCubit');
    newFile('/home/test/lib/main.dart', source);

    await assertDiagnosticsInFile('/home/test/lib/main.dart', [
      lint(source.indexOf('CounterCubit'), 'CounterCubit'.length),
    ]);
  }

  Future<void> test_reports_indirect_cubit_subclass() async {
    const source = '''
import 'package:bloc/bloc.dart';

abstract class BaseCubit<State>(super.initialState) extends Cubit<State>;

class CounterCubit() extends BaseCubit<int> {
  this : super(0);
}
''';
    newFile('/home/test/lib/counter.dart', source);

    await assertDiagnosticsInFile('/home/test/lib/counter.dart', [
      lint(source.indexOf('BaseCubit'), 'BaseCubit'.length),
      lint(source.indexOf('CounterCubit'), 'CounterCubit'.length),
    ]);
  }

  Future<void> test_converts_acronyms_to_snake_case() async {
    final source = _cubitSource('URLFetcherCubit');
    newFile('/home/test/lib/url_fetcher_cubit.dart', source);

    await assertNoDiagnosticsInFile('/home/test/lib/url_fetcher_cubit.dart');
  }

  Future<void> test_ignores_non_cubit_classes() async {
    const source = '''
class CounterCubit {
  CounterCubit();
}
''';
    newFile('/home/test/lib/main.dart', source);

    await assertNoDiagnosticsInFile('/home/test/lib/main.dart');
  }

  Future<void> test_ignores_classes_named_cubit_from_other_libraries() async {
    const source = '''
abstract class Cubit<State>(State initialState);

class CounterCubit() extends Cubit<int> {
  this : super(0);
}
''';
    newFile('/home/test/lib/main.dart', source);

    await assertNoDiagnosticsInFile('/home/test/lib/main.dart');
  }

  Future<void> test_ignores_bloc_classes() async {
    const source = '''
import 'package:bloc/bloc.dart';

class CounterBloc() extends Bloc<Object, int> {
  this : super(0);
}
''';
    newFile('/home/test/lib/main.dart', source);

    await assertNoDiagnosticsInFile('/home/test/lib/main.dart');
  }

  String _cubitSource(String className) {
    return '''
import 'package:bloc/bloc.dart';

class $className() extends Cubit<int> {
  this : super(0);
}
''';
  }
}

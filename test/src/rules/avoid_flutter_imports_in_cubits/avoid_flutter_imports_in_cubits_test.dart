// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/avoid_flutter_imports_in_cubits/avoid_flutter_imports_in_cubits.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidFlutterImportsInCubitsTest);
  });
}

@reflectiveTest
class AvoidFlutterImportsInCubitsTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidFlutterImportsInCubits();
    newPackage('bloc')
      ..addFile('lib/bloc.dart', "export 'src/cubit.dart';")
      ..addFile('lib/src/cubit.dart', '''
abstract class Cubit<State>(State initialState);
''');
    newPackage('flutter').addFile('lib/material.dart', '''
class Color {
  const Color();
}

abstract final class Colors {
  static const blue = Color();
}
''');
    newPackage('flutter_bloc').addFile('lib/flutter_bloc.dart', '''
class Widget {}
''');
    super.setUp();
  }

  Future<void> test_reports_flutter_sdk_import_in_cubit_unit() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';

class ThemeCubit() extends Cubit<Color> {
  this : super(Colors.blue);
}
''';
    newFile('/home/test/lib/theme_cubit.dart', source);

    await assertDiagnosticsInFile('/home/test/lib/theme_cubit.dart', [
      lint(
        source.indexOf("'package:flutter/material.dart'"),
        "'package:flutter/material.dart'".length,
      ),
    ]);
  }

  Future<void> test_reports_flutter_sdk_import_with_indirect_cubit() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';

abstract class BaseCubit<State>(super.initialState) extends Cubit<State>;

class ThemeCubit() extends BaseCubit<Color> {
  this : super(Colors.blue);
}
''';
    newFile('/home/test/lib/theme_cubit.dart', source);

    await assertDiagnosticsInFile('/home/test/lib/theme_cubit.dart', [
      lint(
        source.indexOf("'package:flutter/material.dart'"),
        "'package:flutter/material.dart'".length,
      ),
    ]);
  }

  Future<void> test_reports_flutter_uri_in_conditional_import() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'theme_stub.dart'
    if (dart.library.ui) 'package:flutter/material.dart' as ui;

class ThemeCubit() extends Cubit<ui.Color> {
  this : super(ui.Colors.blue);
}
''';
    newFile('/home/test/lib/theme_stub.dart', '''
class Color {
  const Color();
}

abstract final class Colors {
  static const blue = Color();
}
''');
    newFile('/home/test/lib/theme_cubit.dart', source);

    await assertDiagnosticsInFile('/home/test/lib/theme_cubit.dart', [
      lint(
        source.indexOf("'package:flutter/material.dart'"),
        "'package:flutter/material.dart'".length,
      ),
    ]);
  }

  Future<void> test_ignores_flutter_imports_without_cubit() async {
    const source = '''
import 'package:flutter/material.dart';

class ThemeView {
  final Color color = Colors.blue;
}
''';
    newFile('/home/test/lib/theme_view.dart', source);

    await assertNoDiagnosticsInFile('/home/test/lib/theme_view.dart');
  }

  Future<void> test_scopes_imports_to_each_compilation_unit() async {
    const cubitSource = '''
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';

class ThemeCubit() extends Cubit<Color> {
  this : super(Colors.blue);
}
''';
    const viewSource = '''
import 'package:flutter/material.dart';

class ThemeView {
  final Color color = Colors.blue;
}
''';
    newFile('/home/test/lib/theme_cubit.dart', cubitSource);
    newFile('/home/test/lib/theme_view.dart', viewSource);

    await assertDiagnosticsInUnits([
      (
        '/home/test/lib/theme_cubit.dart',
        [
          lint(
            cubitSource.indexOf("'package:flutter/material.dart'"),
            "'package:flutter/material.dart'".length,
          ),
        ],
      ),
      ('/home/test/lib/theme_view.dart', []),
    ]);
  }

  Future<void> test_ignores_flutter_bloc_package_imports() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeCubit(final Widget widget) extends Cubit<int> {
  this : super(0);
}
''';
    newFile('/home/test/lib/theme_cubit.dart', source);

    await assertNoDiagnosticsInFile('/home/test/lib/theme_cubit.dart');
  }

  Future<void> test_ignores_classes_named_cubit_from_other_libraries() async {
    const source = '''
import 'package:flutter/material.dart';

abstract class Cubit<State>(State initialState);

class ThemeCubit() extends Cubit<Color> {
  this : super(Colors.blue);
}
''';
    newFile('/home/test/lib/theme_cubit.dart', source);

    await assertNoDiagnosticsInFile('/home/test/lib/theme_cubit.dart');
  }
}

// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/avoid_cubit_parameters_in_widget_constructors/avoid_cubit_parameters_in_widget_constructors.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidCubitParametersInWidgetConstructorsTest);
  });
}

@reflectiveTest
class AvoidCubitParametersInWidgetConstructorsTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidCubitParametersInWidgetConstructors();
    newPackage('bloc').addFile('lib/bloc.dart', '''
abstract class Cubit<State>(State initialState);
class CartCubit() extends Cubit<int> {
  this : super(0);
}
''');
    newPackage('flutter').addFile('lib/widgets.dart', '''
abstract class Widget();
abstract class StatelessWidget() extends Widget;
abstract class StatefulWidget() extends Widget;
''');
    super.setUp();
  }

  Future<void> test_reports_cubit_in_primary_constructor() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

class CartView(final CartCubit cubit) extends StatelessWidget;
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('cubit)'), 'cubit'.length),
    ]);
  }

  Future<void> test_reports_cubit_in_body_constructor() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

class CartView extends StatelessWidget {
  CartView({required this.cubit});

  final CartCubit cubit;
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('cubit}'), 'cubit'.length),
    ]);
  }

  Future<void> test_reports_cubit_from_factory_and_named_constructors() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

class CartView extends StatelessWidget {
  factory CartView.create(Cubit<int> cubit) = CartView._;

  CartView._(this.cubit);

  final Cubit<int> cubit;
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('cubit) ='), 'cubit'.length),
      lint(source.indexOf('cubit);'), 'cubit'.length),
    ]);
  }

  Future<void> test_reports_cubit_through_a_type_alias() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

typedef CartCubitAlias = CartCubit;

class CartView(final CartCubitAlias cubit) extends StatelessWidget;
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('cubit)'), 'cubit'.length),
    ]);
  }

  Future<void> test_reports_widget_implementations() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

class CartView(final CartCubit cubit) implements Widget;
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('cubit)'), 'cubit'.length),
    ]);
  }

  Future<void> test_ignores_non_widgets_and_non_cubit_parameters() async {
    const source = '''
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

class CartController(final CartCubit cubit);
class CartView(final Object value) extends StatelessWidget;
class LocalWidget();
class LocalView(final CartCubit cubit) extends LocalWidget;
''';

    await assertNoDiagnostics(source);
  }

  Future<void> test_ignores_class_named_cubit_from_another_package() async {
    const source = '''
import 'package:flutter/widgets.dart';

class Cubit<State>();
class CartCubit() extends Cubit<int>;
class CartView(final CartCubit cubit) extends StatelessWidget;
''';

    await assertNoDiagnostics(source);
  }
}

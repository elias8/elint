// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/avoid_cubit_dependencies/avoid_cubit_dependencies.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidCubitDependenciesTest);
  });
}

@reflectiveTest
class AvoidCubitDependenciesTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidCubitDependencies();
    newPackage('bloc')
      ..addFile('lib/bloc.dart', "export 'src/cubit.dart';")
      ..addFile('lib/src/cubit.dart', '''
abstract class Cubit<State>(State initialState);
''');
    newFile('/home/test/lib/account_cubit.dart', '''
import 'package:bloc/bloc.dart';

class BaseAccountCubit() extends Cubit<int> {
  this : super(0);
}

class AccountCubit() extends BaseAccountCubit;
''');
    super.setUp();
  }

  Future<void>
  test_reports_cubit_references_inside_cubit_implementations() async {
    const source = '''
import 'account_cubit.dart';
import 'package:bloc/bloc.dart';

class CheckoutCubit(final AccountCubit accountCubit) extends Cubit<int> {
  this : super(0);

  void refresh(AccountCubit account) {
    final AccountCubit current = account;
  }
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('AccountCubit accountCubit'), 'AccountCubit'.length),
      lint(source.indexOf('AccountCubit account)'), 'AccountCubit'.length),
      lint(source.indexOf('AccountCubit current'), 'AccountCubit'.length),
    ]);
  }

  Future<void> test_reports_prefixed_and_generic_cubit_references() async {
    const source = '''
import 'account_cubit.dart' as account;
import 'package:bloc/bloc.dart';

class CheckoutCubit() extends Cubit<int> {
  this : super(0);

  void refresh() {
    void use(account.AccountCubit cubit) {}
    use(account.AccountCubit());
  }
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('AccountCubit cubit'), 'AccountCubit'.length),
      lint(source.lastIndexOf('AccountCubit'), 'AccountCubit'.length),
    ]);
  }

  Future<void> test_ignores_presentation_and_non_cubit_references() async {
    const source = '''
import 'account_cubit.dart';
import 'package:bloc/bloc.dart';

class BlocListener<SourceCubit, SourceState> {}

class CheckoutCubit() extends Cubit<int> {
  this : super(0);
}

class CheckoutPage(final BlocListener<AccountCubit, int> listener);

class CheckoutCoordinator(final AccountCubit accountCubit);
''';

    await assertNoDiagnostics(source);
  }

  Future<void> test_ignores_classes_named_cubit_from_other_libraries() async {
    await assertNoDiagnostics('''
abstract class Cubit<State>() {}

class AccountCubit() extends Cubit<int>;

class CheckoutCubit(final AccountCubit accountCubit) extends Cubit<int> {
  this : super();
}
''');
  }
}

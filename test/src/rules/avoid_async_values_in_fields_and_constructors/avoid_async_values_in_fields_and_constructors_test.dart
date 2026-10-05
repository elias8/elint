// ignore_for_file: non_constant_identifier_names
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/avoid_async_values_in_fields_and_constructors/avoid_async_values_in_fields_and_constructors.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidAsyncValuesInFieldsAndConstructorsTest);
  });
}

@reflectiveTest
class AvoidAsyncValuesInFieldsAndConstructorsTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidAsyncValuesInFieldsAndConstructors();
    super.setUp();
  }

  Future<void> test_reports_instance_and_static_future_like_fields() async {
    const source = '''
import 'dart:async';

typedef ConfigFuture = Future<Config>;
typedef ConfigOrInt = FutureOr<int>;
typedef MaybeFuture<T> = Future<T>?;
typedef MaybeCompleter = Completer<void>?;
class Config {}

class Example {
  final Future<Config> pending = Future.value(Config());
  final FutureOr<int>? maybe = 1;
  final ConfigOrInt aliasedOr = 1;
  final Completer<void> completion = Completer<void>();
  final MaybeCompleter nullableCompleter = null;
  final ConfigFuture aliased = Future.value(Config());
  final MaybeFuture<int> nullableAlias = null;
  static final Future<int> shared = Future.value(0);
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('pending ='), 'pending'.length),
      lint(source.indexOf('maybe ='), 'maybe'.length),
      lint(source.indexOf('aliasedOr ='), 'aliasedOr'.length),
      lint(source.indexOf('completion ='), 'completion'.length),
      lint(source.indexOf('nullableCompleter ='), 'nullableCompleter'.length),
      lint(source.indexOf('aliased ='), 'aliased'.length),
      lint(source.indexOf('nullableAlias ='), 'nullableAlias'.length),
      lint(source.indexOf('shared ='), 'shared'.length),
    ]);
  }

  Future<void> test_reports_constructor_parameters() async {
    const source = '''
import 'dart:async';

typedef MaybeFuture<T> = Future<T>?;

class Base {
  Base(Future<int> pending);
}

class Child extends Base {
  Child(super.pending);
}

class Primary(Future<int> pending);

class Declaring(final Future<int> pending);

class FieldFormal {
  final Future<int> pending;
  FieldFormal(this.pending);
}

class Named {
  Named({required FutureOr<int> pending});
}

class CompleterInput {
  CompleterInput(Completer<void> completion);
}

class AliasInput(MaybeFuture<int> maybe);
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('Future<int> pending'), 'Future<int> pending'.length),
      lint(source.indexOf('super.pending'), 'super.pending'.length),
      lint(
        source.indexOf('Future<int> pending', source.indexOf('class Primary')),
        'Future<int> pending'.length,
      ),
      lint(
        source.indexOf('final Future<int> pending'),
        'final Future<int> pending'.length,
      ),
      lint(
        source.indexOf('pending;', source.indexOf('class FieldFormal')),
        'pending'.length,
      ),
      lint(source.indexOf('this.pending'), 'this.pending'.length),
      lint(
        source.indexOf('required FutureOr<int> pending'),
        'required FutureOr<int> pending'.length,
      ),
      lint(
        source.indexOf('Completer<void> completion'),
        'Completer<void> completion'.length,
      ),
      lint(
        source.indexOf('MaybeFuture<int> maybe'),
        'MaybeFuture<int> maybe'.length,
      ),
    ]);
  }

  Future<void> test_reports_async_callback_constructor_parameters() async {
    const source = '''
import 'dart:async';

typedef Loader = Future<int> Function();
typedef MaybeLoader = FutureOr<int> Function();

class Example(Loader load, MaybeLoader loadOr);

class Inline(Future<void> Function() close);
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('Loader load'), 'Loader load'.length),
      lint(source.indexOf('MaybeLoader loadOr'), 'MaybeLoader loadOr'.length),
      lint(
        source.indexOf('Future<void> Function() close'),
        'Future<void> Function() close'.length,
      ),
    ]);
  }

  Future<void> test_ignores_methods_streams_and_synchronous_callbacks() async {
    await assertNoDiagnostics('''
import 'dart:async';

class Service {}

class Valid(void Function() onClose, final Service service) {
  late final Stream<int>? events;
  StreamSubscription<int>? subscription;

  Future<int> load(Future<int> input) => input;
}
''');
  }

  Future<void> test_ignores_non_async_constructor_parameters() async {
    await assertNoDiagnostics('''
class Config {}
class Service {}

class Example(Config config, Service service);
''');
  }
}

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

  Future<void> test_allows_one_transient_owned_operation() async {
    await assertNoDiagnostics('''
import 'dart:async';

class Example {
  Future<int>? _operation;

  Future<int> run() {
    final current = _operation;
    if (current != null) return current;
    return _operation = _run();
  }

  Future<int> _run() async {
    try {
      return await Future<int>.value(1);
    } finally {
      _operation = null;
    }
  }
}
''');
  }

  Future<void> test_allows_nullable_alias_and_explicit_this() async {
    final source = _ownedOperationSource
        .replaceFirst(
          "import 'dart:async';",
          "import 'dart:async';\ntypedef Pending = Future<int>?;",
        )
        .replaceFirst('Future<int>? _operation;', 'Pending _operation;')
        .replaceFirst('= _run();', '= this._run();')
        .replaceFirst('_operation = null;', 'this._operation = null;');
    await assertNoDiagnostics(source);
  }

  Future<void> test_allows_parenthesized_this_owned_operation() async {
    final source = _ownedOperationSource.replaceFirst(
      '= _run();',
      '= ((this))._run();',
    );
    await assertNoDiagnostics(source);
  }

  Future<void> test_reports_constructor_start() async {
    final source = _ownedOperationSource.replaceFirst(
      'class Example {',
      'class Example {\n  Example() { run(); }',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_constructor_parenthesized_this_start() async {
    final source = _ownedOperationSource.replaceFirst(
      'class Example {',
      'class Example {\n  Example() { ((this)).run(); }',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_constructor_owned_operation() async {
    final source = _ownedOperationSource.replaceFirst(
      'class Example {',
      'class Example {\n  Example() { _run(); }',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_named_constructor_start() async {
    final source = _ownedOperationSource.replaceFirst(
      'class Example {',
      'class Example {\n  Example.named() { run(); }',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_constructor_immediate_closure() async {
    final source = _ownedOperationSource.replaceFirst(
      'class Example {',
      'class Example {\n  Example() { (() { run(); })(); }',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_named_constructor_owned_operation() async {
    final source = _ownedOperationSource.replaceFirst(
      'class Example {',
      'class Example {\n  Example.named() { _run(); }',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_primary_constructor_start() async {
    final source = _ownedOperationSource.replaceFirst(
      'class Example {',
      'class Example() {\n  this { run(); }',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_primary_constructor_owned_operation() async {
    final source = _ownedOperationSource.replaceFirst(
      'class Example {',
      'class Example() {\n  this { this._run(); }',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_constructor_helper_chain() async {
    final source = _ownedOperationSource.replaceFirst('class Example {', '''
class Example {
  Example() { _setup(); }
  void _setup() { this._begin(); }
  void _begin() { run(); }
''');
    await _assertOperationLint(source);
  }

  Future<void> test_allows_callback_installed_during_construction() async {
    final source = _ownedOperationSource.replaceFirst('class Example {', '''
class Example {
  Future<int> Function()? _onEvent;
  Example() { _install(); }
  void _install() { _onEvent = () => run(); }
  Future<int> fire() => _onEvent!();
''');
    await assertNoDiagnostics(source);
  }

  Future<void> test_allows_tearoff_installed_during_construction() async {
    final source = _ownedOperationSource.replaceFirst('class Example {', '''
class Example {
  Future<int> Function()? _onEvent;
  Example() { _onEvent = run; }
  Future<int> fire() => _onEvent!();
''');
    await assertNoDiagnostics(source);
  }

  Future<void> test_reports_initialized_handle() async {
    final source = _ownedOperationSource.replaceFirst(
      '_operation;',
      '_operation = null;',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_constructor_written_handle() async {
    final source = _ownedOperationSource.replaceFirst(
      'class Example {',
      'class Example {\n  Example() : _operation = null;',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_public_handle() async {
    final source = _ownedOperationSource.replaceAll('_operation', 'operation');
    await _assertOperationLint(source);
  }

  Future<void> test_reports_static_handle() async {
    final source = _ownedOperationSource.replaceFirst(
      'Future<int>? _operation;',
      'static Future<int>? _operation;',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_late_handle() async {
    final source = _ownedOperationSource.replaceFirst(
      'Future<int>? _operation;',
      'late Future<int>? _operation;',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_future_or_handle() async {
    final source = _ownedOperationSource
        .replaceFirst('Future<int>? _operation;', 'FutureOr<int>? _operation;')
        .replaceFirst('return current;', 'return Future<int>.value(current);');
    await _assertOperationLint(source);
  }

  Future<void> test_reports_foreign_operation() async {
    final source = _ownedOperationSource.replaceFirst(
      '= _run();',
      '= Example()._run();',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_future_factory_operation() async {
    final source = _ownedOperationSource.replaceFirst(
      '= _run();',
      '= Future<int>.value(1);',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_non_async_operation() async {
    final source = _ownedOperationSource
        .replaceFirst('Future<int> _run() async', 'Future<int> _run()')
        .replaceFirst(
          'return await Future<int>.value(1);',
          'return Future<int>.value(1);',
        );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_supplied_future() async {
    final source = _ownedOperationSource
        .replaceFirst(
          'Future<int> run()',
          'Future<int> run(Future<int> supplied)',
        )
        .replaceFirst('= _run();', '= supplied;');
    await _assertOperationLint(source);
  }

  Future<void> test_reports_reset_in_different_operation() async {
    final source = _ownedOperationSource
        .replaceFirst('= _run();', '= _other();')
        .replaceFirst(
          'Future<int> _run()',
          'Future<int> _other() async => 1;\n  Future<int> _run()',
        );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_start_in_closure() async {
    final source = _ownedOperationSource.replaceFirst(
      'return _operation = _run();',
      'Future<int> start() => _operation = _run();\n    return start();',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_missing_reset() async {
    final source = _ownedOperationSource.replaceFirst('_operation = null;', '');
    await _assertOperationLint(source);
  }

  Future<void> test_reports_conditional_reset() async {
    final source = _ownedOperationSource.replaceFirst(
      '_operation = null;',
      'if (DateTime.now().millisecondsSinceEpoch > 0) _operation = null;',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_catch_reset() async {
    final source = _ownedOperationSource
        .replaceFirst('finally {', 'catch (_) {')
        .replaceFirst('_operation = null;', '_operation = null; rethrow;');
    await _assertOperationLint(source);
  }

  Future<void> test_reports_nested_reset() async {
    final source = _ownedOperationSource.replaceFirst(
      '_operation = null;',
      'void reset() { _operation = null; }\n      reset();',
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_conditional_owner_try() async {
    final source = _ownedOperationSource
        .replaceFirst(
          'try {',
          'if (DateTime.now().millisecondsSinceEpoch > 0) { try {',
        )
        .replaceFirst('\n  }\n}', '\n    }\n    return 1;\n  }\n}');
    await _assertOperationLint(source);
  }

  Future<void> test_reports_additional_write_anywhere_in_library() async {
    const source =
        '$_ownedOperationSource\n'
        'void clear(Example value) { value._operation = null; }';
    await _assertOperationLint(source);
  }

  Future<void> test_reports_write_in_part() async {
    newFile('/home/test/lib/other.dart', '''
part of 'test.dart';
void clear(Example value) { value._operation = null; }
''');
    final source = _ownedOperationSource.replaceFirst(
      "import 'dart:async';",
      "import 'dart:async';\npart 'other.dart';",
    );
    await _assertOperationLint(source);
  }

  Future<void> test_reports_multiple_future_like_fields() async {
    final source = _ownedOperationSource.replaceFirst(
      'Future<int>? _operation;',
      'Future<int>? _operation;\n  Completer<void>? other;',
    );
    await assertDiagnostics(source, [
      lint(source.indexOf('_operation;'), '_operation'.length),
      lint(source.indexOf('other;'), 'other'.length),
    ]);
  }

  Future<void> test_reports_cached_settled_close_future() async {
    const source = '''
import 'dart:async';
class Resource {
  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {}
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('_closing;'), '_closing'.length),
    ]);
  }

  Future<void> _assertOperationLint(String source) async {
    final declaration = RegExp(
      r'(?:Future(?:Or)?<int>\?|Pending) (_?operation)',
    ).firstMatch(source)!;
    final name = declaration.group(1)!;
    final start = declaration.end - name.length;
    await assertDiagnostics(source, [lint(start, name.length)]);
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

const _ownedOperationSource = """
import 'dart:async';

class Example {
  Future<int>? _operation;

  Future<int> run() {
    final current = _operation;
    if (current != null) return current;
    return _operation = _run();
  }

  Future<int> _run() async {
    try {
      return await Future<int>.value(1);
    } finally {
      _operation = null;
    }
  }
}
""";

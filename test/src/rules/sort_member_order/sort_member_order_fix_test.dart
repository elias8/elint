// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/sort_member_order/sort_member_order.dart';
import 'package:elint/src/rules/sort_member_order/sort_member_order_fix.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SortMemberOrderFixTest);
  });
}

@reflectiveTest
class SortMemberOrderFixTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = SortMemberOrder();
    super.setUp();
  }

  Future<void> test_moves_constructor_after_field() async {
    const source = '''
class Example {
  Example();
  int value = 0;
}
''';
    final diagnostic = await _singleDiagnostic(source);

    final fixed = await _applyFix(
      source,
      diagnostic,
      selectionOffset: source.indexOf('Example();'),
    );

    expect(fixed, '''
class Example {
  int value = 0;
  Example();
}
''');
    expect(parseString(content: fixed).errors, isEmpty);
  }

  Future<void>
  test_custom_order_fixes_fields_methods_then_constructors() async {
    final optionsFile = resourceProvider.getFile(
      join(testPackageRootPath, 'analysis_options.yaml'),
    );
    optionsFile.writeAsStringSync(
      '${optionsFile.readAsStringSync()}\nelint:\n'
      '  diagnostics:\n'
      '    sort_member_order:\n'
      '      order: [constructors, fields, methods]\n',
    );
    const source = '''
class Example {
  Example();
  void run() {}
  int value = 0;
}
''';
    final diagnostic = await _singleDiagnostic(
      source,
      diagnosticMember: 'void run() {}',
    );
    final fixed = await _applyFix(
      source,
      diagnostic,
      selectionOffset: source.indexOf('Example();'),
    );
    expect(fixed, '''
class Example {
  Example();
  int value = 0;
  void run() {}
}
''');
  }

  Future<void> test_keeps_enum_constants_before_members() async {
    const source = '''
enum Level {
  low;
  const Level();
  final int rank = 0;
}
''';
    final diagnostic = await _singleDiagnostic(source);

    final fixed = await _applyFix(
      source,
      diagnostic,
      selectionOffset: source.indexOf('const Level();'),
    );

    expect(fixed, '''
enum Level {
  low;
  final int rank = 0;
  const Level();
}
''');
    expect(parseString(content: fixed).errors, isEmpty);
  }

  Future<void> test_moves_documentation_with_members() async {
    const source = '''
class Example {
  /// Creates an example.
  Example();

  /// Stores the value.
  int value = 0;
}
''';
    final diagnostic = await _singleDiagnostic(source);

    final fixed = await _applyFix(
      source,
      diagnostic,
      selectionOffset: source.indexOf('Example();'),
    );

    expect(fixed, '''
class Example {

  /// Stores the value.
  int value = 0;
  /// Creates an example.
  Example();
}
''');
    expect(parseString(content: fixed).errors, isEmpty);
  }

  Future<void>
  test_withholds_edit_when_final_member_has_trailing_comment() async {
    const source = '''
class Example {
  Example();
  int value = 0; // This comment belongs to the field.
}
''';
    final diagnostic = await _singleDiagnostic(source);
    final libraryResult = await result.session.getResolvedLibrary(
      testFile.path,
    );
    if (libraryResult is! ResolvedLibraryResult) {
      throw StateError('Expected a resolved library for the test source.');
    }
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      diagnostic: diagnostic,
      selectionOffset: diagnostic.offset,
    );
    final builder = ChangeBuilder(session: result.session);
    await SortMemberOrderFix(context: context).compute(builder);
    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> test_fix_all_moves_constructors_in_file() async {
    const source = '''
class First {
  First();
  int value = 0;
}

class Second {
  Second();
  String name = '';
}
''';
    final diagnostics = await _diagnostics(source);
    expect(diagnostics, hasLength(2));

    final libraryResult = await result.session.getResolvedLibrary(
      testFile.path,
    );
    if (libraryResult is! ResolvedLibraryResult) {
      throw StateError('Expected a resolved library for the test source.');
    }

    final builder = ChangeBuilder(session: result.session);
    final firstContext = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      diagnostic: diagnostics.first,
      selectionOffset: diagnostics.first.offset,
    );
    final fix = SortMemberOrderFix(context: firstContext);
    expect(fix.applicability, CorrectionApplicability.acrossSingleFile);
    expect(fix.fixKind, SortMemberOrderFix.kind);
    expect(fix.multiFixKind, SortMemberOrderFix.multiKind);
    expect(fix.multiFixKind.id, isNot(fix.fixKind.id));

    for (final diagnostic in diagnostics) {
      final selectionOffset = diagnostic.offset;
      final context = CorrectionProducerContext.createResolved(
        libraryResult: libraryResult,
        unitResult: result,
        diagnostic: diagnostic,
        selectionOffset: selectionOffset,
      );
      await SortMemberOrderFix(context: context).compute(builder);
    }

    final edits = builder.sourceChange.edits.single.edits;
    expect(edits, hasLength(2));
    var fixed = source;
    for (final edit in edits.toList()..sort((a, b) => b.offset - a.offset)) {
      fixed = fixed.replaceRange(
        edit.offset,
        edit.offset + edit.length,
        edit.replacement,
      );
    }

    expect(fixed, '''
class First {
  int value = 0;
  First();
}

class Second {
  String name = '';
  Second();
}
''');
    expect(parseString(content: fixed).errors, isEmpty);
  }

  Future<Diagnostic> _singleDiagnostic(
    String source, {
    String? diagnosticMember,
  }) async {
    final diagnostics = await _diagnostics(
      source,
      diagnosticMember: diagnosticMember,
    );
    expect(diagnostics, hasLength(1));
    return diagnostics.single;
  }

  Future<List<Diagnostic>> _diagnostics(
    String source, {
    String? diagnosticMember,
  }) async {
    final constructorOffset = source.indexOf(RegExp(r'(?:const )?\w+\(\);'));
    final documentationOffset = source.lastIndexOf('///', constructorOffset);
    final diagnosticOffset = diagnosticMember != null
        ? source.indexOf(diagnosticMember)
        : documentationOffset == -1
        ? constructorOffset
        : documentationOffset;
    final diagnosticLength =
        diagnosticMember?.length ??
        source.indexOf(';', constructorOffset) + 1 - diagnosticOffset;
    await assertDiagnostics(source, [
      lint(diagnosticOffset, diagnosticLength),
      if (source.contains('Second();'))
        lint(source.indexOf('Second();'), 'Second();'.length),
    ]);
    return result.diagnostics;
  }

  Future<String> _applyFix(
    String source,
    Diagnostic diagnostic, {
    required int selectionOffset,
  }) async {
    final libraryResult = await result.session.getResolvedLibrary(
      testFile.path,
    );
    if (libraryResult is! ResolvedLibraryResult) {
      throw StateError('Expected a resolved library for the test source.');
    }

    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      diagnostic: diagnostic,
      selectionOffset: selectionOffset,
    );
    final builder = ChangeBuilder(session: result.session);
    await SortMemberOrderFix(context: context).compute(builder);

    final edits = builder.sourceChange.edits.single.edits;
    expect(edits, hasLength(1));
    final edit = edits.single;
    return source.replaceRange(
      edit.offset,
      edit.offset + edit.length,
      edit.replacement,
    );
  }
}

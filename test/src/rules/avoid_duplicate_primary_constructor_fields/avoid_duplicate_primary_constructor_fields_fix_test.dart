// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields.dart';
import 'package:elint/src/rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields_fix.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidDuplicatePrimaryConstructorFieldsFixTest);
  });
}

@reflectiveTest
class AvoidDuplicatePrimaryConstructorFieldsFixTest() extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidDuplicatePrimaryConstructorFields();
    super.setUp();
  }

  Future<void> test_uses_private_field_and_preserves_named_argument() async {
    const source = '''
class SomeClass({required final int value}) {
  final int _value = value;

  int read() => _value;
}

void use() => SomeClass(value: 1).read();
''';
    final diagnostic = await _singleDiagnostic(source);
    final fixed = await _applyFix(source, diagnostic);

    expect(fixed, '''
class SomeClass({required final int _value}) {
  int read() => _value;
}

void use() => SomeClass(value: 1).read();
''');
    expect(parseString(content: fixed).errors, isEmpty);
    final correctedFile = newFile('${testFile.path}.fixed.dart', fixed);
    final resolved = await resolveFile(path: correctedFile.path);
    expect(resolved, isA<ResolvedUnitResult>());
    await assertNoDiagnosticsInFile(correctedFile.path);
  }

  Future<void> test_preserves_comments_on_parameter() async {
    const source = '''
class SomeClass({required final /* keep this */ int value}) {
  final int _value = value;
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf('required final /* keep this */ int value'),
        'required final /* keep this */ int value'.length,
      ),
    ]);
    final diagnostic = _lintDiagnostics.single;
    final fixed = await _applyFix(source, diagnostic);

    expect(fixed, '''
class SomeClass({required final /* keep this */ int _value}) {
}
''');
    expect(parseString(content: fixed).errors, isEmpty);
  }

  Future<void> test_withholds_fix_when_field_has_documentation() async {
    const source = '''
class SomeClass({required final int value}) {
  /// Describes the stored value.
  final int _value = value;
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf('required final int value'),
        'required final int value'.length,
      ),
    ]);
    final diagnostic = _lintDiagnostics.single;
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
    await AvoidDuplicatePrimaryConstructorFieldsFix(context: context)
        .compute(builder);
    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> test_in_file_fix_uses_non_overlapping_edits() async {
    const source = '''
class First({required final int value}) {
  final int _value = value;
}

class Second({required final String name}) {
  final String _name = name;
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
    for (final diagnostic in diagnostics) {
      final context = CorrectionProducerContext.createResolved(
        libraryResult: libraryResult,
        unitResult: result,
        diagnostic: diagnostic,
        selectionOffset: diagnostic.offset,
      );
      final fix = AvoidDuplicatePrimaryConstructorFieldsFix(context: context);
      expect(fix.applicability, CorrectionApplicability.acrossSingleFile);
      expect(fix.fixKind, AvoidDuplicatePrimaryConstructorFieldsFix.kind);
      expect(
        fix.multiFixKind,
        AvoidDuplicatePrimaryConstructorFieldsFix.multiKind,
      );
      await fix.compute(builder);
    }

    final edits = builder.sourceChange.edits.single.edits;
    expect(edits, hasLength(4));
    var fixed = source;
    for (final edit in edits.toList()..sort((a, b) => b.offset - a.offset)) {
      fixed = fixed.replaceRange(
        edit.offset,
        edit.offset + edit.length,
        edit.replacement,
      );
    }

    expect(fixed, '''
class First({required final int _value}) {
}

class Second({required final String _name}) {
}
''');
    expect(parseString(content: fixed).errors, isEmpty);
  }

  Future<Diagnostic> _singleDiagnostic(String source) async {
    final diagnostics = await _diagnostics(source);
    return diagnostics.single;
  }

  List<Diagnostic> get _lintDiagnostics => result.diagnostics
      .where(
        (diagnostic) =>
            diagnostic.diagnosticCode.lowerCaseName ==
            AvoidDuplicatePrimaryConstructorFields.code.lowerCaseName,
      )
      .toList();

  Future<List<Diagnostic>> _diagnostics(String source) async {
    final valueOffset = source.indexOf('required final int value');
    final nameOffset = source.indexOf('required final String name');
    await assertDiagnostics(source, [
      lint(valueOffset, 'required final int value'.length),
      if (nameOffset != -1)
        lint(nameOffset, 'required final String name'.length),
    ]);
    return _lintDiagnostics;
  }

  Future<String> _applyFix(String source, Diagnostic diagnostic) async {
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
      selectionLength: diagnostic.length,
    );
    final builder = ChangeBuilder(session: result.session);
    await AvoidDuplicatePrimaryConstructorFieldsFix(context: context)
        .compute(builder);
    var fixed = source;
    final edits = builder.sourceChange.edits.single.edits.toList()
      ..sort((a, b) => b.offset - a.offset);
    for (final edit in edits) {
      fixed = fixed.replaceRange(
        edit.offset,
        edit.offset + edit.length,
        edit.replacement,
      );
    }
    return fixed;
  }
}

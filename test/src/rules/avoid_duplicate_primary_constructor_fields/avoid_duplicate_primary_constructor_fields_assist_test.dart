// ignore_for_file: non_constant_identifier_names
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:elint/src/rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields.dart';
import 'package:elint/src/rules/avoid_duplicate_primary_constructor_fields/avoid_duplicate_primary_constructor_fields_assist.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidDuplicatePrimaryConstructorFieldsAssistTest);
  });
}

@reflectiveTest
class AvoidDuplicatePrimaryConstructorFieldsAssistTest()
    extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidDuplicatePrimaryConstructorFields();
    super.setUp();
  }

  Future<void> test_assists_on_selected_parameter() async {
    const source = '''
class SomeClass({required final int value}) {
  final int _value = value;
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf('required final int value'),
        'required final int value'.length,
      ),
    ]);
    final assisted = await _applyAssist(
      source,
      selectionOffset: source.indexOf('value'),
    );

    expect(assisted, '''
class SomeClass({required final int _value}) {
}
''');
    expect(parseString(content: assisted).errors, isEmpty);
  }

  Future<void> test_does_not_assist_outside_parameter() async {
    const source = '''
class SomeClass({required final int value}) {
  final int _value = value;
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf('required final int value'),
        'required final int value'.length,
      ),
    ]);
    final libraryResult = await result.session.getResolvedLibrary(
      testFile.path,
    );
    if (libraryResult is! ResolvedLibraryResult) {
      throw StateError('Expected a resolved library for the test source.');
    }
    final selectionOffset = source.indexOf('_value');
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      selectionOffset: selectionOffset,
    );
    final builder = ChangeBuilder(session: result.session);
    await AvoidDuplicatePrimaryConstructorFieldsAssist(context: context)
        .compute(builder);
    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<void> test_does_not_assist_when_parameter_is_not_duplicated() async {
    const source = '''
class SomeClass({required final int value}) {
  final int _value = 0;
}
''';
    await assertNoDiagnostics(source);
    final libraryResult = await result.session.getResolvedLibrary(
      testFile.path,
    );
    if (libraryResult is! ResolvedLibraryResult) {
      throw StateError('Expected a resolved library for the test source.');
    }
    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      selectionOffset: source.indexOf('value'),
    );
    final builder = ChangeBuilder(session: result.session);
    await AvoidDuplicatePrimaryConstructorFieldsAssist(context: context)
        .compute(builder);
    expect(builder.sourceChange.edits, isEmpty);
  }

  Future<String> _applyAssist(
    String source, {
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
      selectionOffset: selectionOffset,
    );
    final builder = ChangeBuilder(session: result.session);
    await AvoidDuplicatePrimaryConstructorFieldsAssist(context: context)
        .compute(builder);
    var assisted = source;
    final edits = builder.sourceChange.edits.single.edits.toList()
      ..sort((a, b) => b.offset - a.offset);
    for (final edit in edits) {
      assisted = assisted.replaceRange(
        edit.offset,
        edit.offset + edit.length,
        edit.replacement,
      );
    }
    return assisted;
  }
}

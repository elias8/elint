import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'avoid_duplicate_primary_constructor_fields_edit.dart';

/// Uses the matching private field as a selected primary-constructor parameter.
class AvoidDuplicatePrimaryConstructorFieldsAssist({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = AssistKind(
    'elint.assist.avoidDuplicatePrimaryConstructorFields',
    30,
    'Use the private field as the declaring parameter',
  );

  @override
  CorrectionApplicability get applicability => .singleLocation;

  @override
  AssistKind get assistKind => kind;

  @override
  Future<void> compute(ChangeBuilder builder) => addPrivateFieldEdit(
    node,
    unitResult.content,
    file,
    builder,
    selectionOffset: selectionOffset,
    selectionLength: selectionLength,
  );
}

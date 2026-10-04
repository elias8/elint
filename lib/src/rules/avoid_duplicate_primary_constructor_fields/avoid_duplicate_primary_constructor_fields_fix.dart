import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import 'avoid_duplicate_primary_constructor_fields_edit.dart';

/// Uses the matching private field as the primary-constructor parameter.
class AvoidDuplicatePrimaryConstructorFieldsFix({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = FixKind(
    'elint.fix.avoidDuplicatePrimaryConstructorFields',
    DartFixKindPriority.standard,
    'Use the private field as the declaring parameter',
  );

  static const multiKind = FixKind(
    'elint.fix.avoidDuplicatePrimaryConstructorFields.multi',
    DartFixKindPriority.inFile,
    'Use private fields as declaring parameters',
  );

  @override
  CorrectionApplicability get applicability => .acrossSingleFile;

  @override
  FixKind get fixKind => kind;

  @override
  FixKind get multiFixKind => multiKind;

  @override
  Future<void> compute(ChangeBuilder builder) {
    return addPrivateFieldEdit(node, unitResult.content, file, builder);
  }
}

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import 'prefer_arrow_body_on_same_line_edit.dart';

/// Replaces a split arrow body with a block body.
class PreferArrowBodyOnSameLineFix({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = FixKind(
    'elint.fix.preferArrowBodyOnSameLine',
    DartFixKindPriority.standard,
    'Use a block body',
  );

  static const multiKind = FixKind(
    'elint.fix.preferArrowBodyOnSameLine.multi',
    DartFixKindPriority.inFile,
    'Use block bodies in file',
  );

  @override
  CorrectionApplicability get applicability => .acrossSingleFile;

  @override
  FixKind get fixKind => kind;

  @override
  FixKind get multiFixKind => multiKind;

  @override
  Future<void> compute(ChangeBuilder builder) => addArrowBodyBlockEdit(
    node,
    unitResult.content,
    file,
    builder,
    typeProvider: typeProvider,
    typeSystem: typeSystem,
  );
}

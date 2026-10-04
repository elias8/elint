import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import 'member_order_edit.dart';

/// Reorders selected members across all matching diagnostics in a file.
class SortMemberOrderFix({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = FixKind(
    'elint.fix.sortMemberOrder',
    DartFixKindPriority.standard,
    'Order selected members',
  );

  static const multiKind = FixKind(
    'elint.fix.sortMemberOrder.multi',
    DartFixKindPriority.inFile,
    'Order selected members in file',
  );

  @override
  CorrectionApplicability get applicability => .acrossSingleFile;

  @override
  FixKind get fixKind => kind;

  @override
  FixKind get multiFixKind => multiKind;

  @override
  Future<void> compute(ChangeBuilder builder) => addMemberOrderEdit(
    node,
    unitResult.content,
    file,
    resourceProvider,
    builder,
  );
}

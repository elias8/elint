import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'member_order_edit.dart';

/// Reorders selected members in the selected declaration.
class SortMemberOrderAssist({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = AssistKind(
    'elint.assist.sortMemberOrder',
    30,
    'Order selected members',
  );

  @override
  CorrectionApplicability get applicability => .singleLocation;

  @override
  AssistKind get assistKind => kind;

  @override
  Future<void> compute(ChangeBuilder builder) => addMemberOrderEdit(
    node,
    unitResult.content,
    file,
    resourceProvider,
    builder,
  );
}

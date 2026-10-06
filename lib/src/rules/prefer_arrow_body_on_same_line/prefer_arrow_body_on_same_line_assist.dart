import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'prefer_arrow_body_on_same_line_edit.dart';

/// Replaces a selected split arrow body with a block body.
class PreferArrowBodyOnSameLineAssist({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = AssistKind(
    'elint.assist.preferArrowBodyOnSameLine',
    30,
    'Use a block body',
  );

  @override
  CorrectionApplicability get applicability => .singleLocation;

  @override
  AssistKind get assistKind => kind;

  @override
  Future<void> compute(ChangeBuilder builder) => addArrowBodyBlockEdit(
    node,
    unitResult.content,
    file,
    builder,
    typeProvider: typeProvider,
    typeSystem: typeSystem,
    selectionOffset: selectionOffset,
    selectionLength: selectionLength,
  );
}

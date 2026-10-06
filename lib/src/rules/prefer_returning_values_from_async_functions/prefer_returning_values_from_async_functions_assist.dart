import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'prefer_returning_values_from_async_functions_edit.dart';

/// Returns a selected `Future.value` argument directly.
class PreferReturningValuesFromAsyncFunctionsAssist({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = AssistKind(
    'elint.assist.preferReturningValuesFromAsyncFunctions',
    30,
    'Return the value directly',
  );

  @override
  CorrectionApplicability get applicability => .singleLocation;

  @override
  AssistKind get assistKind => kind;

  @override
  Future<void> compute(ChangeBuilder builder) => addFutureValueReturnEdit(
    node,
    unitResult.content,
    file,
    builder,
    selectionOffset: selectionOffset,
    selectionLength: selectionLength,
  );
}

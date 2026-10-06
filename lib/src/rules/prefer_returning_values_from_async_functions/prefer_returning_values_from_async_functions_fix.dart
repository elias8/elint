import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import 'prefer_returning_values_from_async_functions_edit.dart';

/// Returns the argument directly, marking a synchronous function `async`.
class PreferReturningValuesFromAsyncFunctionsFix({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = FixKind(
    'elint.fix.preferReturningValuesFromAsyncFunctions',
    DartFixKindPriority.standard,
    'Return the value directly',
  );

  static const multiKind = FixKind(
    'elint.fix.preferReturningValuesFromAsyncFunctions.multi',
    DartFixKindPriority.inFile,
    'Return values directly in file',
  );

  @override
  CorrectionApplicability get applicability => .acrossSingleFile;

  @override
  FixKind get fixKind => kind;

  @override
  FixKind get multiFixKind => multiKind;

  @override
  Future<void> compute(ChangeBuilder builder) => addFutureValueReturnEdit(
    node,
    unitResult.content,
    file,
    builder,
    applyToFunction: applyingBulkFixes,
  );
}

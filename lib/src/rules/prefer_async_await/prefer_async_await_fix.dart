import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import 'prefer_async_await_edit.dart';

/// Rewrites a simple returned `Future.then()` callback inside an async
/// function.
class PreferAsyncAwaitFix({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = FixKind(
    'elint.fix.preferAsyncAwait',
    DartFixKindPriority.standard,
    'Rewrite with async/await',
  );

  static const multiKind = FixKind(
    'elint.fix.preferAsyncAwait.multi',
    DartFixKindPriority.inFile,
    'Rewrite Future.then calls in file',
  );

  @override
  CorrectionApplicability get applicability => .acrossSingleFile;

  @override
  FixKind get fixKind => kind;

  @override
  FixKind get multiFixKind => multiKind;

  @override
  Future<void> compute(ChangeBuilder builder) =>
      addPreferAsyncAwaitEdit(node, unitResult.content, file, builder);
}

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

import 'prefer_async_await_edit.dart';

/// Rewrites a selected simple returned `Future.then()` callback.
class PreferAsyncAwaitAssist({required super.context})
    extends ResolvedCorrectionProducer {
  static const kind = AssistKind(
    'elint.assist.preferAsyncAwait',
    30,
    'Rewrite with async/await',
  );

  @override
  CorrectionApplicability get applicability => .singleLocation;

  @override
  AssistKind get assistKind => kind;

  @override
  Future<void> compute(ChangeBuilder builder) => addPreferAsyncAwaitEdit(
    node,
    unitResult.content,
    file,
    builder,
    selectionOffset: selectionOffset,
    selectionLength: selectionLength,
  );
}

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/sort_member_order/sort_member_order.dart';
import 'src/rules/sort_member_order/sort_member_order_assist.dart';
import 'src/rules/sort_member_order/sort_member_order_fix.dart';

/// The plugin entry point loaded by the Dart analysis server.
final plugin = ElintPlugin();

/// Registers the custom diagnostics provided by `elint`.
class ElintPlugin extends Plugin {
  @override
  String get name => 'elint';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerLintRule(SortMemberOrder())
      ..registerFixForRule(SortMemberOrder.code, SortMemberOrderFix.new)
      ..registerAssist(SortMemberOrderAssist.new);
  }
}

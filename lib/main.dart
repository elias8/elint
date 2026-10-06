import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/catalog.dart';

/// The plugin entry point loaded by the Dart analysis server.
final plugin = ElintPlugin();

/// Registers the custom diagnostics provided by `elint`.
class ElintPlugin() extends Plugin {
  @override
  String get name => 'elint';

  @override
  void register(PluginRegistry registry) {
    for (final spec in ElintCatalog.rules) {
      final rule = spec.rule();
      registry.registerLintRule(rule);
      if (spec.fix case final fix?) {
        registry.registerFixForRule(rule.diagnosticCodes.single, fix);
      }
      if (spec.assist case final assist?) {
        registry.registerAssist(assist);
      }
    }
  }
}

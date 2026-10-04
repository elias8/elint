import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

/// The plugin entry point loaded by the Dart analysis server.
final plugin = ElintPlugin();

/// Registers the custom diagnostics provided by `elint`.
class ElintPlugin extends Plugin {
  @override
  String get name => 'elint';

  @override
  void register(PluginRegistry registry) {
    // Register custom rules here as they are added to the package.
  }
}

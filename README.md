# elint

Reusable custom analyzer plugin for Dart projects maintained by BitshiftHQ.

`elint` uses Dart's analysis server plugin system. Once custom diagnostics are
registered in `lib/main.dart`, they can run in supported IDEs and from
`dart analyze` or `flutter analyze`.

## Requirements

- Dart SDK 3.13 or later
- Flutter 3.38 or later for Flutter projects

## Use in a project

Add the package as a development dependency. While developing it locally, use a
path dependency:

```yaml
dev_dependencies:
  elint:
    path: ../elint
```

Enable the plugin in the consuming project's `analysis_options.yaml` and turn
on the diagnostics that package registers:

```yaml
plugins:
  elint:
    path: ../elint
    diagnostics:
      your_rule_name: true
```

Then run `dart analyze` (or `flutter analyze`). Lint rules are disabled until
enabled under `diagnostics`. Plugin warnings are enabled by default. Restart
the IDE analysis server after changing plugin configuration.

Suppress an individual diagnostic with its plugin-qualified name:

```dart
// ignore: elint/your_rule_name
```

## Add a rule

Implement an analyzer rule using `analysis_server_plugin`, then register it
from `ElintPlugin.register` in `lib/main.dart`. Give each diagnostic a stable
code; consuming projects use that code under `plugins.elint.diagnostics`.

See the [Dart analyzer plugin guide](https://dart.dev/tools/analyzer-plugins)
for rule, fix, and assist authoring details.

## License

MIT. See [LICENSE](LICENSE).

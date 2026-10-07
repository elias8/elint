# elint

Custom Dart lint rules and automatic fixes for BitshiftHQ projects.

elint reports diagnostics through Dart's analyzer plugin system in supported
IDEs, `dart analyze`, and `flutter analyze`. Its batch fixer applies registered
fixes across a project in one command. You can also call the fixer from Dart code.

## Requirements

Dart 3.13 or later. For Flutter projects, use a Flutter SDK that includes a
compatible Dart SDK.

## Use in a project

Add elint as a development dependency. For a local checkout:

```yaml
dev_dependencies:
  elint:
    path: ../elint
```

Run `dart pub get`, or `flutter pub get` for a Flutter project.

Enable the plugin and the rules you want in `analysis_options.yaml`:

```yaml
plugins:
  elint:
    path: ../elint
    diagnostics:
      sort_member_order: true
      prefer_returning_values_from_async_functions: true
```

Adjust both paths to your elint checkout. Rules are disabled until enabled under
`diagnostics`. The plugin configuration and the package dependency are both needed
for the setup above.

Run `dart analyze` or `flutter analyze` to see diagnostics. Restart your IDE's
analysis server after changing the plugin configuration.

See the [rule index](docs/rules.md) for descriptions, examples, and available fixes.
To suppress a diagnostic, use its plugin-qualified name:

```dart
// ignore: elint/sort_member_order
```

## Configure member order

`sort_member_order` defaults to fields before constructors. Set a custom order
in the top-level `elint` section of `analysis_options.yaml`:

```yaml
plugins:
  elint:
    path: ../elint
    diagnostics:
      sort_member_order: true

elint:
  diagnostics:
    sort_member_order:
      order: [fields, constructors, getters, setters, methods]
```

Only listed categories are ordered. Unlisted members keep their member positions,
and members within each category keep their relative order. An empty list or a
single category has no ordering comparisons. Disable the rule with
`plugins.elint.diagnostics.sort_member_order: false`.

The analyzer, IDE fixes and assists, and batch fixer use the same order. See the
[member-order rule](docs/rules/sort_member_order.md) for configuration precedence,
validation, and examples.

## Apply fixes

Run these commands from your project root:

```sh
dart run elint fix --dry-run
dart run elint fix --apply
```

`--dry-run` prints proposed changes without writing files. `--apply` writes the
changes after the selected fixes converge. Choose exactly one mode.

By default, the fixer selects rules enabled in each file's analyzer configuration.
Rules without a registered fix remain in the report for manual review.

Select individual rules, groups, or a file or directory:

```sh
dart run elint fix --apply --code sort_member_order
dart run elint fix --dry-run --code sort_member_order,prefer_returning_values_from_async_functions
dart run elint fix --apply --group layout --group async
dart run elint fix --dry-run lib/example.dart
```

Repeated or comma-separated selectors combine into one selection. Explicit
selectors also enable selected rules that the analyzer configuration has disabled.
Codes accept either `sort_member_order` or
`elint/sort_member_order`. The fixer respects analyzer exclusions and
ignore comments. Without a target, it analyzes the current directory.

| Group | Rules |
| --- | --- |
| `architecture` | `avoid_cubit_parameters_in_widget_constructors`, `avoid_cubit_dependencies`, `avoid_flutter_imports_in_cubits`, `avoid_returning_values_from_cubits`, `prefer_matching_cubit_file_names` |
| `layout` | `prefer_arrow_body_on_same_line`, `sort_member_order` |
| `async` | `prefer_async_await`, `prefer_returning_values_from_async_functions`, `avoid_async_values_in_fields_and_constructors` |

`avoid_duplicate_primary_constructor_fields` is available by code and has no group.
`avoid_async_values_in_fields_and_constructors` currently has no automatic fix.

Use `dart run elint fix --help` for command help. The package dependency lets
Dart resolve the default `bin/elint.dart` executable without a file path.
Without that dependency, run `dart /path/to/elint/bin/elint.dart fix --dry-run`.

## Call the fixer from Dart

Import `package:elint/tools.dart` to use the same engine as the CLI:

```dart
import 'dart:io';

import 'package:elint/tools.dart';

Future<void> main() async {
  final result = await runFixes(
    FixRequest(mode: FixMode.dryRun, groups: ['layout']),
    workingDirectory: Directory.current.path,
  );
  print('Files with proposed changes: ${result.changes.length}');
}
```

Pass an absolute working directory. The result includes proposed file changes,
fix counts by code, remaining diagnostics, and convergence status. Use
`FixMode.apply` to write changes. The engine checks original file contents before
writing; writes across multiple files are not atomic.

## Contribute

The CLI adapter lives in `lib/src/cli/`. The fix engine lives in
`lib/src/tools/fix.dart`, with its public API exported by `lib/tools.dart`.

To add a rule, register the rule and its optional fix and assist producers in
`lib/src/catalog.dart`. The plugin and batch fixer share this catalog. Add the
rule to [the rule index](docs/rules.md) and document it under `docs/rules/`.
See the [Dart analyzer plugin guide](https://dart.dev/tools/analyzer-plugins)
for authoring guidance.

The fix engine uses internal analyzer APIs. Its integration was checked with
analyzer 14.4.0 and analysis_server_plugin 0.3.23. Verify the fixer after upgrading
those dependencies.

## License

MIT. See [LICENSE](LICENSE).

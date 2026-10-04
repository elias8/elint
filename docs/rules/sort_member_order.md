# sort_member_order

Keep class and enum members in the configured order.

## Default behavior

When enabled without a custom order, the rule requires fields before body
constructors. Getters, setters, and methods are unconstrained.

**BAD:**

```dart
class User {
  const User(this.id);
  final String id;
}
```

**GOOD:**

```dart
class User {
  final String id;
  const User(this.id);
}
```

## Configure the order

Enable the rule under `plugins.elint.diagnostics`. Put parameters in the separate,
top-level `elint` section:

```yaml
plugins:
  elint:
    path: ../elint
    diagnostics:
      sort_member_order: true

elint:
  diagnostics:
    sort_member_order:
      order:
        - fields
        - constructors
        - getters
        - setters
        - methods
```

The supported categories are `fields`, `constructors`, `getters`, `setters`, and
`methods`. Fields include both static and instance fields. Constructors include
named and factory constructors. Enum constants and primary-constructor headers
are outside the member sequence.

A custom list replaces the default order entirely. For example,
`[constructors, fields]` requires constructors before fields. The rule does not
add omitted categories or sort members alphabetically.

Only listed categories participate in ordering. With `[fields, constructors]`,
this declaration:

```dart
class Example {
  Example();
  void method() {}
  int value = 0;
}
```

is fixed to:

```dart
class Example {
  int value = 0;
  void method() {}
  Example();
}
```

The method keeps its member position. Multiple fields retain their relative
order, as do multiple constructors or members of any other selected category.
An empty `order: []` or a single-category order has no ordering comparisons.
An omitted `order` uses `[fields, constructors]`.

Set `plugins.elint.diagnostics.sort_member_order: false` to disable diagnostics.
The CLI's explicit `--code sort_member_order` selector enables the rule for that
run and still uses the configured order.

## Configuration files

The nearest `analysis_options.yaml` determines the parameters for each Dart file.
Relative and `package:` includes are supported, including lists of includes.
Included configuration is applied in include order, followed by the local file.
A local `order` replaces the included list; lists are not concatenated.
Configuration changes are read on the next analysis or correction request.

Unknown or duplicate categories, non-list orders, and malformed configuration
produce a diagnostic on the affected Dart file. Its message identifies the
configuration file and problem. Invalid configuration produces no sorting edits.
The batch fixer stops with a configuration error before applying changes.

## Fixes and assists

The single fix sorts the affected declaration. The in-file fix handles matching
declarations in the file. The assist sorts the selected declaration.
All actions use the same configuration and ordering calculation as the lint.

Documentation and annotations move with their members. When a comment's
attachment would be ambiguous after reordering, the action is withheld.

## Related SDK rules

The default fields-before-constructors order conflicts with
[`sort_constructors_first`](https://dart.dev/tools/linter-rules/sort_constructors_first).
Enable that SDK rule only when your configured order also requires constructors
first. Unlisted categories remain unconstrained by `sort_member_order`, even
when the SDK rule constrains them.

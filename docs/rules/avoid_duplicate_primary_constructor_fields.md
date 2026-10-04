# avoid_duplicate_primary_constructor_fields

**Lint rule**

Avoid primary-constructor fields copied to another field.

## Details

**AVOID** declaring a field in a primary constructor when a field initializer
copies the same constructor parameter into another instance field. The
declaring parameter already exposes a field, so the extra field can leave an
unintended public property alongside the intended private one.

**BAD:**

```dart
class SomeClass({required final int value}) {
  final int _value = value;
}
```

**GOOD:**

```dart
class SomeClass({required final int _value});

SomeClass(value: 1);
```

## Description

The analyzer reports this diagnostic on a primary-constructor parameter that
declares a field when a non-static instance field named by prefixing the
parameter name with `_` is initialized directly from that parameter. The
reference must resolve to the parameter; unrelated fields and expressions that
merely use the same name are not reported.

## Example

This valid Dart code creates both a public `value` field and a private `_value`
field containing the same initial value:

```dart
class SomeClass({required final int value}) {
  final int _value = value;
}
```

## Common fixes

When a private field is named by prefixing the parameter name with `_`, make
that field the declaring primary-constructor parameter and remove the duplicate
field declaration:

```dart
class SomeClass({required final int _value});
```

The private named parameter keeps the public named argument `value` at call
sites, while the field itself is private. The quick fix and assist make this
change when the matching field can be removed without dropping comments or
metadata, and when its type and finality match the declaring parameter. The
in-file fix handles every safely convertible parameter in the file. Otherwise,
choose explicitly whether to keep the public primary field or retain the
separate private field with a plain parameter.

## Enable

Enable `avoid_duplicate_primary_constructor_fields` under
`plugins.elint.diagnostics` in `analysis_options.yaml`. See
[Enabling rules](../rules.md#enabling-rules) for the plugin configuration.

## See also

- [Dart primary constructors](https://dart.dev/language/primary-constructors)

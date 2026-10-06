# prefer_arrow_body_on_same_line

**Lint rule**

Keep the start of an arrow body on the same line as `=>`.

## Details

**PREFER** starting the expression on the same line as `=>`. The expression may
continue on later lines. This makes the arrow's body visible where the function
body begins.

**BAD:**

```dart
String format(Item item) =>
    formatItem(item);
```

**GOOD:**

```dart
String format(Item item) => formatParts(
  item.name,
  item.code,
);
```

Or use a block body when the expression would start on the next line:

```dart
String format(Item item) {
  return formatItem(item);
}
```

## Description

The analyzer reports this diagnostic when an arrow function's expression starts
on a different source line from its `=>` token. It applies to declarations and
anonymous functions, including callbacks. The expression can continue across
multiple lines when its first token follows `=>` on the same line. A function
signature may wrap across lines as long as the expression starts on the `=>`
line.

## Example

This callback starts its expression on the line after the arrow:

```dart
items.map((item) =>
    formatItem(item));
```

Keep the start of the expression beside the arrow, or use a block body:

```dart
items.map((item) => formatParts(
  item.name,
  item.code,
));
```

```dart
items.map((item) {
  return formatItem(item);
});
```

## Common fixes

- Move the expression's first token onto the `=>` line when the formatted line
  remains readable.
- Use the registered single fix or in-file fix to convert the arrow body to a
  block body. The fix preserves `async` and comments between `=>` and the
  expression. It uses `return` when the function must return a value, including
  when that value is a `Future`. For a `Future<void>` or `FutureOr<void>` async
  body, it awaits a known `Future` or `FutureOr` expression so the block keeps
  waiting for its completion; it leaves `void` and `Never` expressions as
  statements. It is withheld when a function or expression type is unresolved,
  `dynamic`, or invalid, or when a trailing callback comment cannot be safely
  retained.
- Select the affected arrow body to use the assist.

Nested arrows can be fixed together when their source edits do not overlap.
The rule is incompatible with the SDK lint
[`prefer_expression_function_bodies`](https://dart.dev/tools/linter-rules/prefer_expression_function_bodies),
which can recommend an arrow body in a case where this rule recommends a block.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

## See also

- [Dart functions](https://dart.dev/language/functions)
- [`prefer_expression_function_bodies`](https://dart.dev/tools/linter-rules/prefer_expression_function_bodies)

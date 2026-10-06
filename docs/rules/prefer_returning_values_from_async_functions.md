# prefer_returning_values_from_async_functions

**Lint rule**

Prefer returning values directly from asynchronous functions.

## Details

**PREFER** returning a value from an `async` function instead of explicitly
constructing a completed future. This makes the asynchronous contract clear and
avoids a redundant `Future.value` wrapper.

**BAD:**

```dart
Future<int> answer() {
  return Future<int>.value(42);
}
```

**GOOD:**

```dart
Future<int> answer() async {
  return 42;
}
```

## Description

The analyzer produces this diagnostic when a function, method, or closure
directly returns a resolved `dart:async` `Future.value` call with one argument.
This includes block bodies and expression bodies whose resolved return type
supports an `async` function (`Future`, `FutureOr`, or `dynamic`). Other uses of
`Future.value`, functions with incompatible return types, and similarly named
constructors from other libraries are not reported.

## Example

This function explicitly creates a future for a value it already has:

```dart
Future<String> greeting() {
  return Future<String>.value('hello');
}
```

Return the value from an asynchronous function instead:

```dart
Future<String> greeting() async => 'hello';
```

## Common fixes

- In a function already marked `async`, return the argument directly.
- In a synchronous function returning a `Future`, add `async` and return the
  argument directly.

The fix and assist make these edits when the returned expression has no comments
that would be removed. The single fix is offered for the reported return; the
in-file fix handles all matching returns in each affected function. The assist
is available when the selection overlaps the returned expression.

Changing a synchronous function to `async` changes how exceptions from evaluating
the returned expression are delivered: they become errors on the returned future
instead of being thrown synchronously at the call site. The quick fix is an
explicit action and is not automatically applied. Review that behavior when
applying it. The fix is withheld when comments inside the `Future.value` wrapper
would be lost.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

## See also

- [Effective Dart: Prefer async/await over using raw futures](https://dart.dev/effective-dart/usage#prefer-asyncawait-over-using-raw-futures)
- [`unnecessary_await_in_return`](https://dart.dev/tools/diagnostics/unnecessary_await_in_return)

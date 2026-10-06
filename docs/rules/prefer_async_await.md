# prefer_async_await

**Lint rule**

Prefer `async`/`await` over `Future.then()`.

## Details

**PREFER** `async`/`await` for Future continuations. It makes sequential
asynchronous work easier to read and allows ordinary control flow and error
handling.

**BAD:**

```dart
Future<int> loadLength() => readText().then((text) => text.length);
```

**GOOD:**

```dart
Future<int> loadLength() async {
  final text = await readText();
  return text.length;
}
```

This project rule is stricter than Effective Dart: simple `Future.then()` use
can still be appropriate, but this rule reports it by project policy.

## Description

The analyzer reports this diagnostic for each method invocation that resolves
to `then` declared by `dart:async`'s `Future` class. It reports single calls
and each call in a chain, in any function context. A similarly named method on
another class is not reported.

## Example

Both calls in this chain are reported:

```dart
Future<int> loadLength() =>
    readText().then((text) => text).then((text) => text.length);
```

Use `await` to make each continuation explicit:

```dart
Future<int> loadLength() async {
  final text = await readText();
  return text.length;
}
```

## Common fixes

The quick fix and assist rewrite a limited pattern: one `Future.then()` call
that is directly returned as a standalone statement from an already-`async`
block function, with one untyped positional callback parameter, an expression
callback body, and no error handler. They introduce a local variable for the
callback value and return the callback expression. Comments in the returned
statement, returns embedded in an unbraced control-flow body, callback blocks,
chains, callbacks with explicit parameter types, and other contexts do not
receive an automatic rewrite. The callback parameter must also be used by its
expression body. The diagnostic still applies to these cases.

The single fix edits only the reported return. The in-file fix can combine
separate eligible returns because each edit replaces a distinct return
statement. The assist is available when the selection overlaps the `then()`
invocation. Neither action is automatically applied.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

## See also

- [Effective Dart: Asynchrony](https://dart.dev/effective-dart/usage#prefer-asyncawait-over-using-raw-futures)
- [Dart asynchronous programming](https://dart.dev/libraries/dart-async)
- [`Future.then`](https://api.dart.dev/dart-async/Future/then.html)

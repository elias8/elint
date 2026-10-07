# prefer_matching_cubit_file_names

**Lint rule**

Do match Cubit class names to snake_case file names.

## Details

**DO** declare each Cubit in a Dart file whose basename matches the class name
converted to `lowercase_with_underscores`. This makes Cubit implementations
easier to find and keeps each implementation in its own file.

**BAD:** `CounterCubit` is declared in `main.dart`:

```dart
class CounterCubit() extends Cubit<int> {
  this : super(0);
}
```

**GOOD:** Declare the same class in `counter_cubit.dart`:

```dart
class CounterCubit() extends Cubit<int> {
  this : super(0);
}
```

## Description

The analyzer produces this diagnostic for a class declaration whose superclass
chain reaches `Cubit` from the `bloc` package when the containing file's basename
does not match the class name in `lowercase_with_underscores`, including the
`.dart` extension. Directory names do not affect the check. Classes that are not
resolved as `bloc` Cubit implementations are not reported.

For example, `URLFetcherCubit` belongs in `url_fetcher_cubit.dart`. The
diagnostic highlights the class name.

The Dart `file_names` diagnostic checks that source file names use
`lowercase_with_underscores`; it does not check whether a Cubit class name
matches its file. The `bloc_lint` package also provides
`prefer_file_naming_conventions` for Bloc and Cubit declarations. Enabling both
rules can produce duplicate diagnostics for Cubits.

There is no automatic fix or assist because moving a declaration requires a
file operation and may require updates to imports and project references.

## Example

This declaration triggers the diagnostic when it appears in `main.dart`:

```dart
class CounterCubit() extends Cubit<int> {
  this : super(0);
}
```

Move it to `counter_cubit.dart` to match the class name.

## Common fixes

Move the Cubit declaration to a file named after the class in snake_case. For
example, move `CounterCubit` to `counter_cubit.dart`.

There is no single or in-file fix or selection assist because moving a file can
change imports and project references.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

## See also

- [Bloc lint: prefer file naming conventions](https://bloclibrary.dev/lint-rules/prefer_file_naming_conventions/)
- [Effective Dart: source file names](https://dart.dev/effective-dart/style#identifiers)
- [Dart diagnostic: `file_names`](https://dart.dev/tools/diagnostics/file_names)

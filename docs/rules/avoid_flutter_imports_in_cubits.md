# avoid_flutter_imports_in_cubits

**Lint rule**

Avoid Flutter SDK imports in Cubit implementations.

## Details

**AVOID** importing Flutter SDK libraries into a Cubit implementation. Keep
business logic independent of Flutter so it can be tested and reused without
the Flutter framework.

**BAD:**

```dart
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';

class ThemeCubit() extends Cubit<Color> {
  this : super(Colors.blue);
}
```

**GOOD:**

```dart
import 'package:bloc/bloc.dart';

enum ThemeColor { blue }

class ThemeCubit() extends Cubit<ThemeColor> {
  this : super(ThemeColor.blue);
}
```

Keep Flutter-specific rendering and types in the presentation layer. Pass
framework-neutral values into the Cubit instead.

## Description

The analyzer produces this diagnostic for each import URI whose package name is
`flutter` in a compilation unit that declares a class whose superclass chain
reaches `Cubit` from the `bloc` package. Conditional import URIs are checked
too. The rule highlights the Flutter import URI. Units without a resolved
`bloc` Cubit declaration are not reported.

This rule checks the Flutter SDK package named `flutter`. Imports from
`flutter_bloc` or other packages are not reported. It overlaps with
`bloc_lint`'s `avoid_flutter_imports`, which also checks Bloc implementations;
enabling both rules can produce duplicate diagnostics for Cubits.

There is no automatic fix or assist because removing a Flutter dependency can
require changes to state types and a move of presentation-specific code.

## Example

This import is reported because the same compilation unit declares a Cubit:

```dart
import 'package:flutter/material.dart';
```

Move the Flutter-dependent code to the presentation layer and use a
framework-neutral type in the Cubit.

## Common fixes

Replace Flutter-specific types with framework-neutral types in the Cubit, then
move rendering or other Flutter-specific behavior into the presentation layer.
For example, use a domain enum or value object instead of `Color` in Cubit state.

There is no single or in-file fix or selection assist because the appropriate
replacement depends on the application's state model and presentation code.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

## See also

- [Bloc lint: avoid Flutter imports](https://bloclibrary.dev/lint-rules/avoid_flutter_imports/)
- [Bloc architecture](https://bloclibrary.dev/architecture/)

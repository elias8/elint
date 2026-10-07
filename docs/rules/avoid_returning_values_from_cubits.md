# avoid_returning_values_from_cubits

**Lint rule**

Do keep public Cubit method results in state; return `void` or `Future<void>`.

## Details

**AVOID** returning a value from a public Cubit method. Callers should observe
results through the Cubit's state, which keeps the state as the source of truth
for the operation.

**BAD:**

```dart
class CounterCubit() extends Cubit<int> {
  this : super(0);

  int increment() {
    emit(state + 1);
    return state;
  }
}
```

**GOOD:**

```dart
class CounterCubit() extends Cubit<int> {
  this : super(0);

  void increment() {
    emit(state + 1);
  }
}
```

Callers can invoke `increment()` and read `cubit.state` when they need the
current value. Asynchronous methods can use `Future<void>` and emit their
results through state in the same way.

## Description

The analyzer produces this diagnostic for a public, non-static method declared
in a class whose superclass chain reaches `Cubit` from the `bloc` package when
its resolved return type is not `void` or `Future<void>`. Methods with inferred
return types are checked using their resolved type. Private and static methods
are excluded, as are getters, setters, operators, constructors, and members that
are only inherited.

This rule permits `Future<void>` aliases because it checks resolved types. It
does not provide an automatic fix or assist: changing a method's API can require
updates to callers and decisions about which state should represent the result.
The `bloc_lint` package provides equivalent guidance through
`prefer_void_public_cubit_methods`; enabling both rules reports duplicate
diagnostics.

## Example

This method changes state but also returns the new value to its caller, creating
a second way to observe the result:

```dart
int increment() {
  emit(state + 1);
  return state;
}
```

The diagnostic highlights the method's return type. Use `void` or
`Future<void>` and expose the result through state instead.

## Common fixes

Change the method to return `void` or `Future<void>`, remove the returned value,
and update callers to read the Cubit's state. For example:

```dart
void increment() {
  emit(state + 1);
}
```

There is no single or in-file fix or selection assist because the right state
representation and caller updates depend on the application.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

## See also

- [Bloc lint: prefer void public Cubit methods](https://bloclibrary.dev/lint-rules/prefer_void_public_cubit_methods/)
- [Bloc FAQ: exposing public methods](https://bloclibrary.dev/faqs/#exposing-public-methods)
- [`avoid_void_async`](https://dart.dev/tools/linter-rules/avoid_void_async), which recommends `Future<void>` for asynchronous methods

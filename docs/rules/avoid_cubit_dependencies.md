# avoid_cubit_dependencies

**Lint rule**

Avoid direct dependencies between Cubit implementations. Coordinate through the
presentation layer or a shared domain source.

## Details

**AVOID** making a Cubit depend on another Cubit. Cubits belong to the same
business logic layer, so a direct dependency couples their lifecycles and makes
them harder to change independently.

**BAD:**

```dart
class CheckoutCubit(final AccountCubit accountCubit) extends Cubit<int> {
  this : super(0);
}
```

**GOOD:**

```dart
class CheckoutCubit(final AccountRepository accountRepository)
    extends Cubit<int> {
  this : super(0);
}
```

When one Cubit's state should trigger another Cubit, connect them in the
presentation layer with `BlocListener`. When both need the same changing data,
share a repository or another domain source.

## Description

The analyzer reports this diagnostic for a reference inside a Cubit
implementation to another class whose superclass chain reaches `Cubit` from
the `bloc` package. This includes references in types, constructor calls, and
generic arguments. Subclasses that inherit from an intermediate Cubit base
class are included. Classes merely named `Cubit`, and references outside a
Cubit implementation, are not reported.

## Example

This field makes `CheckoutCubit` depend directly on `AccountCubit`:

```dart
class CheckoutCubit(final AccountCubit accountCubit) extends Cubit<int> {
  this : super(0);
}
```

The same rule applies to a Cubit class reference in a method body, such as a
type argument to `context.read<AccountCubit>()`.

## Common fixes

If a state change in one Cubit should cause an action in another, let the
presentation layer coordinate them:

```dart
BlocListener<CheckoutCubit, CheckoutState>(
  listener: (context, state) {
    if (state is CheckoutCompleted) {
      context.read<AccountCubit>().refresh();
    }
  },
  child: const CheckoutView(),
)
```

If both Cubits need the same data, inject the same repository or domain source
into each Cubit and let each maintain its own state.

There is no automatic fix or assist. Choosing the presentation or domain
coordination path changes application architecture and requires a design
decision.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

## See also

- [Bloc architecture: connecting Blocs through presentation](https://bloclibrary.dev/architecture/#connecting-blocs-through-presentation)
- [Bloc architecture: connecting Blocs through domain](https://bloclibrary.dev/architecture/#connecting-blocs-through-domain)

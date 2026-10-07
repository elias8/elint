# avoid_cubit_parameters_in_widget_constructors

**Lint rule**

Do access Cubits through the widget tree.

## Details

**DO** provide a Cubit above the widgets that use it. Let child widgets obtain
it through `BlocBuilder`, `BlocConsumer`, `BlocListener`, or
`context.read<T>()`. This keeps widget constructors independent from Cubit
implementations and makes widgets easier to reuse. Use a builder, consumer, or
listener when the widget needs to react to state changes; `context.read<T>()`
is for an access that does not subscribe to state changes.

**BAD:**

```dart
class CartView(final CartCubit cubit) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('${cubit.state}');
}
```

**GOOD:**

```dart
class CartView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) => Text('$state'),
    );
  }
}
```

Provide the Cubit above the child:

```dart
BlocProvider(
  create: (_) => CartCubit(),
  child: CartView(),
)
```

## Description

The analyzer produces this diagnostic for a constructor parameter whose
resolved type is `Cubit` from the `bloc` package or a subclass of it, when the
constructor belongs to a class that extends or implements Flutter's `Widget`.
Primary constructors, body constructors, factories, and named constructors are
checked. The diagnostic highlights the parameter name. Unresolved parameter
types, non-widget classes, and types merely named `Cubit` from another package
are not reported.

This rule checks the widget's constructor declaration. It does not check a
constructor call to a widget from another package or report a Cubit-valued
field that is not accepted by a constructor.

The current [`bloc_lint`](https://pub.dev/packages/bloc_lint) catalog has no
equivalent rule for Cubit-typed widget constructor parameters. Its
`prefer_build_context_extensions` rule affects how a child accesses a Cubit
after it is provided, not whether the Cubit is passed through the constructor.

## Example

This valid Dart constructor triggers the diagnostic because it makes a Cubit a
part of the widget's constructor API:

```dart
class CartView(final CartCubit cubit) extends StatelessWidget;
```

Remove the Cubit parameter and read or listen to the provided Cubit from the
widget tree instead.

## Common fixes

Move Cubit creation or provision to an ancestor, usually with `BlocProvider`,
and access it from the child with a Bloc widget or `BuildContext` extension.
Use `BlocBuilder`, `BlocConsumer`, or `BlocListener` when responding to state
changes. Use `context.read<CartCubit>()` for actions that do not need a state
subscription.

There is no single fix, in-file fix, or assist. Removing a constructor
parameter also requires changing how the widget uses it and deciding where the
Cubit is provided, so an automatic edit could change behavior or ownership.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

## See also

- [Bloc architecture: connecting Blocs through presentation](https://bloclibrary.dev/architecture/#connecting-blocs-through-presentation)
- [Bloc Flutter counter tutorial](https://bloclibrary.dev/tutorials/flutter-counter/)
- [Bloc lint: prefer BuildContext extensions](https://bloclibrary.dev/lint-rules/prefer_build_context_extensions/)

# Elint lint rules

This index lists the lint rules provided by `elint`. Each rule page describes
when the diagnostic is reported and shows valid Dart examples and available
actions. The same rules are listed in the
[machine-readable rule catalog](all_lint_rules.yaml).

Rules are disabled until enabled in the `plugins.elint.diagnostics` section of
`analysis_options.yaml`. See [Use in a project](../README.md#use-in-a-project)
for the plugin configuration.

## Enabling rules

Enable an `elint` diagnostic in the consuming project's `analysis_options.yaml`:

```yaml
plugins:
  elint:
    path: ../elint
    diagnostics:
      avoid_duplicate_primary_constructor_fields: true
```

| Rule                                  | Description                                                        | Documentation                                           |
|---------------------------------------|--------------------------------------------------------------------|---------------------------------------------------------|
| `avoid_async_values_in_fields_and_constructors`                   | Keep asynchronous work out of class state and constructor inputs.  | [Details](rules/avoid_async_values_in_fields_and_constructors.md)                   |
| `avoid_duplicate_primary_constructor_fields` | Avoid primary-constructor fields copied to another field.          | [Details](rules/avoid_duplicate_primary_constructor_fields.md) |
| `sort_member_order`          | Keep class and enum members in the configured order.      | [Details](rules/sort_member_order.md)          |
| `prefer_returning_values_from_async_functions`               | Prefer returning values directly from asynchronous functions.    | [Details](rules/prefer_returning_values_from_async_functions.md)              |

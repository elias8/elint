# avoid_async_values_in_fields_and_constructors

**Lint rule**

Keep asynchronous work out of class state and constructor inputs.

## Details

**AVOID** storing `Future`, `FutureOr`, or `Completer` values in instance or
static fields, or accepting them as constructor inputs. Pass resolved data or a
service that starts the operation when a method is called. This keeps the
operation's start, error handling, and concurrency policy at its call site.

The rule also reports constructor parameters declared as functions returning
`Future` or `FutureOr`.

**BAD:**

```dart
class Repository(final Future<Config> initialLoad);
```

**GOOD:**

```dart
final config = await configService.load();
final repository = Repository(config);

class Repository(final Config config);
```

Or keep the service and start the operation in a method:

```dart
class Repository(final ConfigService configService) {
  Future<Config> loadConfig() => configService.load();
}
```

## Description

The analyzer reports instance and static fields whose resolved type is
`Future`, `FutureOr`, or `Completer`, including nullable types and aliases. It
also reports primary-constructor parameters, body-constructor parameters,
field-formal parameters, and super parameters with those types. A constructor
parameter whose function type returns `Future` or `FutureOr` is reported as
well.

Methods may accept or return futures. Stream and subscription fields, and local
variables, are outside this rule. A session or lifecycle coordinator may
narrowly ignore a diagnostic when sharing the same in-flight operation is part
of its contract; document why callers must join that operation and cover the
behavior with tests.

## Example

This constructor stores an unfinished operation as object state:

```dart
class Cache(final Future<Snapshot> initialSnapshot);
```

Await the result before construction:

```dart
final snapshot = await store.loadSnapshot();
final cache = Cache(snapshot);

class Cache(final Snapshot snapshot);
```

Or pass a service and perform asynchronous work from an operation:

```dart
class Cache(final SnapshotStore store) {
  Future<Snapshot> loadSnapshot() => store.loadSnapshot();
}
```

## Common fixes

- Await the operation before constructing the object and pass the resolved
  value.
- Pass a service and start asynchronous work from the method that needs it.
- If multiple callers must join one in-flight operation by contract, keep the
  shared state narrowly scoped, explain the contract beside the ignore, and
  test concurrent and completed-call behavior.

There is no automatic fix: changing when work starts, how errors are observed,
or whether callers share an unfinished operation requires a design decision.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

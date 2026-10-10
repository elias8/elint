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
variables, are outside this rule. One private nullable instance `Future` can represent a shared unfinished
operation under the structural exception below. This exception requires
ownership review; an accepted AST shape does not establish a valid contract.

## Transient shared operation exception

The rule accepts one field per declaring class only when all these structural
conditions hold:

- The field is private, nullable, mutable, nonstatic, and not `late`. Its resolved
  type is `Future`, including a nullable type alias. It has no initializer or
  constructor write.
- The class declares no other `Future`, `FutureOr`, or `Completer` fields.
  Computed getters are not stored fields.
- The field has exactly two resolved writes across the library, including its
  parts: one assignment of a direct private async method invocation on `this`,
  and one assignment of `null`. Both assignments target this instance.
  Parentheses around a `this` method receiver do not change its ownership.
- The start occurs in an instance method of the declaring class, outside a
  nested function. The invoked method is an async, nongenerator instance method
  of that same class. Resolved method calls on this instance must not connect
  a constructor to the invoked operation, directly or through other methods
  of the declaring class. This includes named and primary constructors and
  calls in their bodies and initializers.
- The invoked method's body is one outer `try` statement. Its `finally` block
  consists solely of the field's unconditional assignment to `null`.

Constructor async parameters and callbacks remain reported regardless of this
exception. `Completer`, `FutureOr`, public, static, externally supplied, multiply
written, and completed cached fields do not qualify. A cached close Future that
remains stored after cleanup is still reported.

### Required ownership review

The structural check does not prove the operation's domain purpose, exclusive
admission, error observation, or runtime settlement ordering. Review must establish:

- A concrete contract requires callers to share this unfinished operation.
- One owner starts the operation and prevents overlapping replacement of the
  handle, including synchronous reentry. The handle is assigned before its
  completion path clears it.
- Every failure is observed by its owner or caller. The handle is cleared on
  success and failure, and any durable result is stored as domain data.
- The Future is not a lifecycle flag or retained close/dispose result.
- Tests cover concurrent callers, failure, reentry, and post-settlement access.

A transient close method can have the same AST shape as domain work. The rule
cannot distinguish those contracts and does not authorize lifecycle coordination
merely because the field passes. Dynamic writes and runtime behavior also require
review. Constructor-origin checking follows only resolved direct method calls
on this instance within the declaring class. Directly invoked function literals
are included. Installed callbacks and tear-offs are not treated as immediate
calls. Callback invocation or scheduling, local function aliases, getters,
foreign receivers, virtual overrides, and dynamic dispatch require review; this
check is not whole-program execution analysis. There is no name whitelist,
annotation, pragma, or suppression mechanism for this exception.

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
- If a concrete contract requires callers to share unfinished work, retain
  only the operation handle described below and test its ownership and
  settlement behavior.

There is no automatic fix: changing when work starts, how errors are observed,
or whether callers share an unfinished operation requires a design decision.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

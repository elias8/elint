# avoid_post_frame_scheduling

**Lint rule**

Avoid post-frame work unless it depends on a completed frame.

## Details

**AVOID** scheduling work after a frame unless it depends on a completed frame.
Post-frame scheduling splits behavior across lifecycle phases and makes control
flow harder to follow.

**BAD:**

```dart
import 'package:flutter/widgets.dart';

void onEvent() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    handleEvent();
  });
}

void handleEvent() {}
```

**GOOD:**

```dart
void onEvent() => handleEvent();

void handleEvent() {}
```

Use `didChangeDependencies` for initialization that depends on inherited
widgets. Call event-driven work directly from its event callback, and use
`LayoutBuilder` when constraints provide the needed layout value.

## Description

The analyzer produces this diagnostic for resolved calls to Flutter's
`SchedulerBinding.addPostFrameCallback` and reads of
`SchedulerBinding.endOfFrame`. It recognizes calls through both
`SchedulerBinding` and `WidgetsBinding`, including aliases and inherited
members. Methods and properties with the same names from other libraries are
not reported.

The Dart SDK lint catalog has no rule for these Flutter APIs.

This rule does not report `scheduleFrameCallback`, which runs at the beginning
of a frame rather than after the rendering pipeline.

## Example

This call is reported because it schedules work to run after Flutter finishes
the current frame:

```dart
import 'package:flutter/widgets.dart';

void onEvent() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    handleEvent();
  });
}

void handleEvent() {}
```

`endOfFrame` is also reported because it waits for the same frame boundary and
is implemented using a post-frame callback.

## Common fixes

Choose the lifecycle or event that matches the work:

- Use `initState` for one-time initialization.
- Use `didChangeDependencies` for inherited dependencies.
- Run event-driven work directly from the event callback.
- Use `LayoutBuilder` when constraints provide the required layout value.

There is no single fix, in-file fix, or assist because the correct replacement
depends on why the code waits for a frame. Keep a diagnostic suppressed only
when the work genuinely depends on a completed frame, and explain
that requirement near the suppression.

## Enable

See [Enabling rules](../rules.md#enabling-rules) for instructions.

## See also

- [Flutter `addPostFrameCallback` API](https://api.flutter.dev/flutter/widgets/WidgetsBinding/addPostFrameCallback.html)
- [Flutter `endOfFrame` API](https://api.flutter.dev/flutter/widgets/WidgetsBinding/endOfFrame.html)
- [Flutter `State` lifecycle](https://api.flutter.dev/flutter/widgets/State-class.html)

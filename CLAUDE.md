# CLAUDE.md

Starling SDK: the Flutter framework ported to Swift, driven by the Flutter
engine's C core. No Dart VM. (The SwiftPM package name remains `FlutterSwift`.)

## Layout

- `Sources/` — SDK targets only (the framework, bridges, `FlutterGTK` host).
- `Examples/` — everything app-related: `FlutterDemoApp`, the ported samples,
  their shared `ExampleHost`, and `Examples/Calendar/` (the kalender port:
  `Library/` is the `CalendarKit` target, `App/` is `CalendarApp`).

## Build and test

```bash
swift build -c release
tools/run-tests.sh        # not `swift test` — see README (Ubuntu 26.04 <cmath> clash)
```

## Widget composition: use the trailing-closure result builders

`Sources/Flutter/Widgets/ResultBuilders.swift` gives every common container a
trailing-closure overload (`ChildrenBuilder` for `children:`, `ChildBuilder`
for `child:`). Prefer it over building `var children: [Widget]` imperatively
or standing a `SizedBox` in for "no child" — `if`, `if let`, `switch`, and
`for` work directly in the block, and a helper returning `Widget?` splices in
as zero-or-one children:

```swift
Column(crossAxisAlignment: .stretch) {
    HeaderRow()
    if state.showLane { _buildLane() }        // _buildLane() -> Widget? also works
    for date in dates { Expanded { DayCell(date) } }
}
```

Both spellings compile to the identical tree, and the ported
`children: [Widget]` / `child:` initializers remain the canonical 1:1 Dart
mapping — keep the array form where the children are a data-driven `.map`
(e.g. `LayoutId`-keyed tiles for a `CustomMultiChildLayout`), and note that
some widgets (`GestureDetector`, inherited widgets) have no builder overload.
When adding a builder overload, mirror the wrapped initializer's parameters
exactly, defaults included — a divergence is silently unexpressible in the
builder spelling rather than an error.

## App state: the BLoC pattern

Apps and app-level packages (see `Examples/Calendar/Library/CalendarBloc.swift`,
modeled on the desktop's `FileExplorerBloc`) use one value-type `State` struct,
one `Event` enum, and an `@Observable` bloc whose `add(_:)` is the only way the
UI mutates anything. Widgets read `bloc.state`, dispatch events, and rebuild
through `withObservationTracking` — not controllers, callbacks, or
`ValueNotifier` subscriptions (`ChangeNotifier.removeListener` is a documented
best-effort stub; avoid patterns that depend on it).

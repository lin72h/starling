// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Migration source: packages/flutter/lib/src/gestures/pointer_signal_resolver.dart
// Lines: 1-137

// TODO: Replace PointerEvent with PointerSignalEvent once it is migrated to Swift.
// In Dart, PointerSignalEvent is a subclass of PointerEvent. Until it exists in Swift,
// we use PointerEvent directly.

/// The callback to register with a `PointerSignalResolver` to express
/// interest in a pointer signal event.
///
/// **Dart Source:** `pointer_signal_resolver.dart:18`
public typealias PointerSignalResolvedCallback = (PointerEvent) -> Void

/// Returns whether `a` and `b` refer to the same original event.
///
/// **Dart Source:** `pointer_signal_resolver.dart:20-22`
private func _isSameEvent(_ event1: PointerEvent?, _ event2: PointerEvent) -> Bool {
    guard let event1 = event1 else { return false }
    let a = event1.original ?? event1
    let b = event2.original ?? event2
    return a === b
}

/// Mediates disputes over which listener should handle pointer signal events
/// when multiple listeners wish to handle those events.
///
/// Pointer signals (such as `PointerScrollEvent`) are immediate, so unlike
/// events that participate in the gesture arena, pointer signals always
/// resolve at the end of event dispatch. Yet if objects interested in handling
/// these signal events were to handle them directly, it would cause issues
/// such as multiple `Scrollable` widgets in the widget hierarchy responding
/// to the same mouse wheel event. Using this class, these events will only
/// be dispatched to the first registered handler, which will in turn
/// correspond to the widget that's deepest in the widget hierarchy.
///
/// To use this class, objects should register their event handler like so:
///
/// ```swift
/// func handleSignalEvent(_ event: PointerEvent) {
///     GestureBinding.instance.pointerSignalResolver.register(event: event) { event in
///         // handle the event...
///     }
/// }
/// ```
///
/// **Dart Source:** `pointer_signal_resolver.dart:62-137`
public class PointerSignalResolver {

    private var _firstRegisteredCallback: PointerSignalResolvedCallback?

    // TODO: Change type to PointerSignalEvent? once it is migrated to Swift.
    private var _currentEvent: PointerEvent?

    /// Registers interest in handling `event`.
    ///
    /// This method may be called multiple times (typically from different parts
    /// of the widget hierarchy) for the same `event`, with different `callback`s,
    /// as the event is being dispatched across the tree. Once the dispatching is
    /// complete, the `GestureBinding` calls `resolve(event:)`, and the first
    /// registered callback is called.
    ///
    /// The `callback` is invoked with one argument, the `event`.
    ///
    /// Once the `register(event:callback:)` method has been called with a
    /// particular `event`, it must not be called for other events until after
    /// `resolve(event:)` has been called. Only one event disambiguation can be
    /// in flight at a time. In normal use this is achieved by only registering
    /// callbacks for an event as it is actively being dispatched (for example,
    /// in `Listener.onPointerSignal`).
    ///
    /// **Dart Source:** `pointer_signal_resolver.dart:86-93`
    public func register(event: PointerEvent, callback: @escaping PointerSignalResolvedCallback) {
        assert(_currentEvent == nil || _isSameEvent(_currentEvent, event))
        if _firstRegisteredCallback != nil {
            return
        }
        _currentEvent = event
        _firstRegisteredCallback = callback
    }

    /// Resolves the event, calling the first registered callback if there was
    /// one.
    ///
    /// This is called by the `GestureBinding` after the framework has finished
    /// dispatching the pointer signal event.
    ///
    /// **Dart Source:** `pointer_signal_resolver.dart:101-136`
    public func resolve(event: PointerEvent) {
        if _firstRegisteredCallback == nil {
            assert(_currentEvent == nil)
            // Nothing in the framework/app wants to handle the `event`. Allow the
            // platform to trigger any default native actions.
            // TODO: Call event.respond(allowPlatformDefault: true) once respond() is available on PointerEvent.
            return
        }
        assert(_isSameEvent(_currentEvent, event))
        // In Dart, this invocation is wrapped in a try/catch that reports errors
        // via FlutterError.reportError. In Swift, the callback type is non-throwing,
        // so we invoke it directly. If error reporting is needed, the callback
        // signature should be changed to a throwing closure in the future.
        _firstRegisteredCallback!(_currentEvent!)
        _firstRegisteredCallback = nil
        _currentEvent = nil
    }
}

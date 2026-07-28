// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - RespondPointerEventCallback

/// A function that implements the `PointerSignalEvent.respond` method.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Line:** 1807
public typealias RespondPointerEventCallback = (_ allowPlatformDefault: Bool) -> Void

// MARK: - PointerSignalEvent

/// An event that corresponds to a discrete pointer signal.
///
/// Pointer signals are events that originate from the pointer but don't change
/// the state of the pointer itself, and are discrete rather than needing to be
/// interpreted in the context of a series of events.
///
/// See also:
///
///  * `PointerSignalResolver`, which provides an opt-in mechanism whereby
///    participating agents may disambiguate an event's target.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1792-1804
open class PointerSignalEvent: PointerEvent {

    /// Creates a pointer signal event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `kind` defaults to `.mouse` for signal events.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        pointer: Int = 0,
        kind: PointerDeviceKind = .mouse,
        device: Int = 0,
        position: Offset = .zero,
        embedderId: Int = 0
    ) {
        super.init(
            viewId: viewId,
            embedderId: embedderId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: kind,
            device: device,
            position: position
        )
    }

    /// Internal initializer used by transformed subclasses to pass
    /// through all properties including transform and original.
    internal override init(
        viewId: Int,
        embedderId: Int,
        timeStamp: Duration,
        pointer: Int,
        kind: PointerDeviceKind,
        device: Int,
        position: Offset,
        delta: Offset,
        buttons: Int,
        down: Bool,
        obscured: Bool,
        pressure: Double,
        pressureMin: Double,
        pressureMax: Double,
        distance: Double,
        distanceMax: Double,
        size: Double,
        radiusMajor: Double,
        radiusMinor: Double,
        radiusMin: Double,
        radiusMax: Double,
        orientation: Double,
        tilt: Double,
        platformData: Int,
        synthesized: Bool,
        transform: Matrix4?,
        original: PointerEvent?
    ) {
        super.init(
            viewId: viewId,
            embedderId: embedderId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: kind,
            device: device,
            position: position,
            delta: delta,
            buttons: buttons,
            down: down,
            obscured: obscured,
            pressure: pressure,
            pressureMin: pressureMin,
            pressureMax: pressureMax,
            distance: distance,
            distanceMax: distanceMax,
            size: size,
            radiusMajor: radiusMajor,
            radiusMinor: radiusMinor,
            radiusMin: radiusMin,
            radiusMax: radiusMax,
            orientation: orientation,
            tilt: tilt,
            platformData: platformData,
            synthesized: synthesized,
            transform: transform,
            original: original
        )
    }

    /// Sends a response to the native embedder for the `PointerSignalEvent`.
    ///
    /// The parameter `allowPlatformDefault` allows the platform to perform the
    /// default action associated with the native event when it's set to `true`.
    ///
    /// This method can be called any number of times, but once `allowPlatformDefault`
    /// is set to `true`, it can't be set to `false` again.
    ///
    /// Default implementation is a no-op; subclasses with respond behavior
    /// (e.g. `PointerScrollEvent`) override this.
    ///
    /// **Dart Source:** `events.dart:1809-1823` (from `_RespondablePointerEvent` mixin)
    open func respond(allowPlatformDefault: Bool) {}
}

// MARK: - PointerScrollEvent

/// The pointer issued a scroll event.
///
/// Scrolling the scroll wheel on a mouse is an example of an event that
/// would create a `PointerScrollEvent`.
///
/// See also:
///
///  * `PointerSignalResolver`, which provides an opt-in mechanism whereby
///    participating agents may disambiguate an event's target.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1880-1917
open class PointerScrollEvent: PointerSignalEvent {

    /// Creates a pointer scroll event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        kind: PointerDeviceKind = .mouse,
        device: Int = 0,
        position: Offset = .zero,
        scrollDelta: Offset = .zero,
        embedderId: Int = 0,
        onRespond: RespondPointerEventCallback? = nil
    ) {
        self.scrollDelta = scrollDelta
        self._onRespond = onRespond
        super.init(
            viewId: viewId,
            timeStamp: timeStamp,
            kind: kind,
            device: device,
            position: position,
            embedderId: embedderId
        )
    }

    /// Internal initializer used by `TransformedPointerScrollEvent` to pass
    /// through all properties including transform and original.
    internal init(
        viewId: Int,
        embedderId: Int,
        timeStamp: Duration,
        pointer: Int,
        kind: PointerDeviceKind,
        device: Int,
        position: Offset,
        delta: Offset,
        buttons: Int,
        down: Bool,
        obscured: Bool,
        pressure: Double,
        pressureMin: Double,
        pressureMax: Double,
        distance: Double,
        distanceMax: Double,
        size: Double,
        radiusMajor: Double,
        radiusMinor: Double,
        radiusMin: Double,
        radiusMax: Double,
        orientation: Double,
        tilt: Double,
        platformData: Int,
        synthesized: Bool,
        transform: Matrix4?,
        original: PointerEvent?,
        scrollDelta: Offset,
        onRespond: RespondPointerEventCallback?
    ) {
        self.scrollDelta = scrollDelta
        self._onRespond = onRespond
        super.init(
            viewId: viewId,
            embedderId: embedderId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: kind,
            device: device,
            position: position,
            delta: delta,
            buttons: buttons,
            down: down,
            obscured: obscured,
            pressure: pressure,
            pressureMin: pressureMin,
            pressureMax: pressureMax,
            distance: distance,
            distanceMax: distanceMax,
            size: size,
            radiusMajor: radiusMajor,
            radiusMinor: radiusMinor,
            radiusMin: radiusMin,
            radiusMax: radiusMax,
            orientation: orientation,
            tilt: tilt,
            platformData: platformData,
            synthesized: synthesized,
            transform: transform,
            original: original
        )
    }

    /// The amount to scroll, in logical pixels.
    ///
    /// **Dart Source:** `events.dart:1894-1895`
    public let scrollDelta: Offset

    /// The callback to invoke when `respond(allowPlatformDefault:)` is called.
    ///
    /// **Dart Source:** `events.dart:1911`
    internal let _onRespond: RespondPointerEventCallback?

    /// Sends a response to the native embedder for this scroll event.
    ///
    /// **Dart Source:** `events.dart:1913-1916`
    open override func respond(allowPlatformDefault: Bool) {
        _onRespond?(allowPlatformDefault)
    }

    /// Transforms this event into the coordinate space described by `transform`.
    ///
    /// If `transform` is nil or equal to the current transform, returns self.
    /// Otherwise, creates a `TransformedPointerScrollEvent`.
    ///
    /// **Dart Source:** `events.dart:1897-1903`
    open override func transformed(_ transform: Matrix4?) -> PointerScrollEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerScrollEvent) ?? self
        return TransformedPointerScrollEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:1825-1866` (via `_CopyPointerScrollEvent` mixin)
    open func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        pointer: Int? = nil,
        kind: PointerDeviceKind? = nil,
        device: Int? = nil,
        position: Offset? = nil,
        delta: Offset? = nil,
        buttons: Int? = nil,
        obscured: Bool? = nil,
        pressure: Double? = nil,
        pressureMin: Double? = nil,
        pressureMax: Double? = nil,
        distance: Double? = nil,
        distanceMax: Double? = nil,
        size: Double? = nil,
        radiusMajor: Double? = nil,
        radiusMinor: Double? = nil,
        radiusMin: Double? = nil,
        radiusMax: Double? = nil,
        orientation: Double? = nil,
        tilt: Double? = nil,
        synthesized: Bool? = nil,
        embedderId: Int? = nil,
        onRespond: RespondPointerEventCallback? = nil
    ) -> PointerScrollEvent {
        return PointerScrollEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            scrollDelta: scrollDelta,
            embedderId: embedderId ?? self.embedderId,
            onRespond: onRespond ?? self.respond
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerScrollEvent

/// Internal transformed variant of `PointerScrollEvent`.
///
/// In Dart, this class extends `_TransformedPointerEvent` and implements
/// `PointerScrollEvent`. Since Swift does not support multiple class inheritance,
/// this class extends `PointerScrollEvent` directly and overrides `localPosition`
/// and `localDelta` with lazily computed transformed values (mirroring the
/// behavior of `_TransformedPointerEvent`).
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1919-1949
internal class TransformedPointerScrollEvent: PointerScrollEvent {

    /// Creates a transformed pointer scroll event.
    internal init(original: PointerScrollEvent, transform: Matrix4) {
        self._typedOriginal = original
        self._storedTransform = transform
        super.init(
            viewId: original.viewId,
            embedderId: original.embedderId,
            timeStamp: original.timeStamp,
            pointer: original.pointer,
            kind: original.kind,
            device: original.device,
            position: original.position,
            delta: original.delta,
            buttons: original.buttons,
            down: original.down,
            obscured: original.obscured,
            pressure: original.pressure,
            pressureMin: original.pressureMin,
            pressureMax: original.pressureMax,
            distance: original.distance,
            distanceMax: original.distanceMax,
            size: original.size,
            radiusMajor: original.radiusMajor,
            radiusMinor: original.radiusMinor,
            radiusMin: original.radiusMin,
            radiusMax: original.radiusMax,
            orientation: original.orientation,
            tilt: original.tilt,
            platformData: original.platformData,
            synthesized: original.synthesized,
            transform: transform,
            original: original,
            scrollDelta: original.scrollDelta,
            onRespond: original._onRespond
        )
    }

    /// The original un-transformed `PointerScrollEvent`.
    private let _typedOriginal: PointerScrollEvent

    /// The transformation matrix for this event.
    private let _storedTransform: Matrix4

    // Lazy computed local position and delta, matching _TransformedPointerEvent behavior.
    private lazy var _localPosition: Offset = PointerEvent.transformPosition(
        _storedTransform,
        position
    )

    private lazy var _localDelta: Offset = PointerEvent.transformDeltaViaPositions(
        untransformedEndPosition: position,
        transformedEndPosition: _localPosition,
        untransformedDelta: delta,
        transform: _storedTransform
    )

    /// The position in the local coordinate system of the event receiver.
    open override var localPosition: Offset { _localPosition }

    /// The delta in the local coordinate system of the event receiver.
    open override var localDelta: Offset { _localDelta }

    /// Transforms this event by delegating to the original event.
    ///
    /// **Dart Source:** `events.dart:1934`
    open override func transformed(_ transform: Matrix4?) -> PointerScrollEvent {
        return _typedOriginal.transformed(transform)
    }

    /// Delegates respond to the original event.
    ///
    /// **Dart Source:** `events.dart:1946-1948`
    open override func respond(allowPlatformDefault: Bool) {
        _typedOriginal.respond(allowPlatformDefault: allowPlatformDefault)
    }

    /// Creates a copy of this event with the specified properties replaced,
    /// delegating to the `PointerScrollEvent.copyWith` behavior.
    ///
    /// **Dart Source:** `events.dart:1825-1866` (via `_CopyPointerScrollEvent` mixin)
    open override func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        pointer: Int? = nil,
        kind: PointerDeviceKind? = nil,
        device: Int? = nil,
        position: Offset? = nil,
        delta: Offset? = nil,
        buttons: Int? = nil,
        obscured: Bool? = nil,
        pressure: Double? = nil,
        pressureMin: Double? = nil,
        pressureMax: Double? = nil,
        distance: Double? = nil,
        distanceMax: Double? = nil,
        size: Double? = nil,
        radiusMajor: Double? = nil,
        radiusMinor: Double? = nil,
        radiusMin: Double? = nil,
        radiusMax: Double? = nil,
        orientation: Double? = nil,
        tilt: Double? = nil,
        synthesized: Bool? = nil,
        embedderId: Int? = nil,
        onRespond: RespondPointerEventCallback? = nil
    ) -> PointerScrollEvent {
        return PointerScrollEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            scrollDelta: scrollDelta,
            embedderId: embedderId ?? self.embedderId,
            onRespond: onRespond ?? self.respond
        ).transformed(transform)
    }
}

// MARK: - PointerScrollInertiaCancelEvent

/// The pointer issued a scroll-inertia cancel event.
///
/// Touching the trackpad immediately after a scroll is an example of an event
/// that would create a `PointerScrollInertiaCancelEvent`.
///
/// See also:
///
///  * `PointerSignalResolver`, which provides an opt-in mechanism whereby
///    participating agents may disambiguate an event's target.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2000-2022
open class PointerScrollInertiaCancelEvent: PointerSignalEvent {

    /// Creates a pointer scroll-inertia cancel event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    public override init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        pointer: Int = 0,
        kind: PointerDeviceKind = .mouse,
        device: Int = 0,
        position: Offset = .zero,
        embedderId: Int = 0
    ) {
        super.init(
            viewId: viewId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: kind,
            device: device,
            position: position,
            embedderId: embedderId
        )
    }

    /// Internal initializer used by `TransformedPointerScrollInertiaCancelEvent`
    /// to pass through all properties including transform and original.
    internal override init(
        viewId: Int,
        embedderId: Int,
        timeStamp: Duration,
        pointer: Int,
        kind: PointerDeviceKind,
        device: Int,
        position: Offset,
        delta: Offset,
        buttons: Int,
        down: Bool,
        obscured: Bool,
        pressure: Double,
        pressureMin: Double,
        pressureMax: Double,
        distance: Double,
        distanceMax: Double,
        size: Double,
        radiusMajor: Double,
        radiusMinor: Double,
        radiusMin: Double,
        radiusMax: Double,
        orientation: Double,
        tilt: Double,
        platformData: Int,
        synthesized: Bool,
        transform: Matrix4?,
        original: PointerEvent?
    ) {
        super.init(
            viewId: viewId,
            embedderId: embedderId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: kind,
            device: device,
            position: position,
            delta: delta,
            buttons: buttons,
            down: down,
            obscured: obscured,
            pressure: pressure,
            pressureMin: pressureMin,
            pressureMax: pressureMax,
            distance: distance,
            distanceMax: distanceMax,
            size: size,
            radiusMajor: radiusMajor,
            radiusMinor: radiusMinor,
            radiusMin: radiusMin,
            radiusMax: radiusMax,
            orientation: orientation,
            tilt: tilt,
            platformData: platformData,
            synthesized: synthesized,
            transform: transform,
            original: original
        )
    }

    /// Transforms this event into the coordinate space described by `transform`.
    ///
    /// If `transform` is nil or equal to the current transform, returns self.
    /// Otherwise, creates a `TransformedPointerScrollInertiaCancelEvent`.
    ///
    /// **Dart Source:** `events.dart:2012-2021`
    open override func transformed(_ transform: Matrix4?) -> PointerScrollInertiaCancelEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerScrollInertiaCancelEvent) ?? self
        return TransformedPointerScrollInertiaCancelEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:1951-1986` (via `_CopyPointerScrollInertiaCancelEvent` mixin)
    open override func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        pointer: Int? = nil,
        kind: PointerDeviceKind? = nil,
        device: Int? = nil,
        position: Offset? = nil,
        delta: Offset? = nil,
        buttons: Int? = nil,
        obscured: Bool? = nil,
        pressure: Double? = nil,
        pressureMin: Double? = nil,
        pressureMax: Double? = nil,
        distance: Double? = nil,
        distanceMax: Double? = nil,
        size: Double? = nil,
        radiusMajor: Double? = nil,
        radiusMinor: Double? = nil,
        radiusMin: Double? = nil,
        radiusMax: Double? = nil,
        orientation: Double? = nil,
        tilt: Double? = nil,
        synthesized: Bool? = nil,
        embedderId: Int? = nil
    ) -> PointerScrollInertiaCancelEvent {
        return PointerScrollInertiaCancelEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerScrollInertiaCancelEvent

/// Internal transformed variant of `PointerScrollInertiaCancelEvent`.
///
/// In Dart, this class extends `_TransformedPointerEvent` and implements
/// `PointerScrollInertiaCancelEvent`. Since Swift does not support multiple
/// class inheritance, this class extends `PointerScrollInertiaCancelEvent`
/// directly and overrides `localPosition` and `localDelta` with lazily computed
/// transformed values (mirroring the behavior of `_TransformedPointerEvent`).
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2024-2038
internal class TransformedPointerScrollInertiaCancelEvent: PointerScrollInertiaCancelEvent {

    /// Creates a transformed pointer scroll-inertia cancel event.
    internal init(original: PointerScrollInertiaCancelEvent, transform: Matrix4) {
        self._typedOriginal = original
        self._storedTransform = transform
        super.init(
            viewId: original.viewId,
            embedderId: original.embedderId,
            timeStamp: original.timeStamp,
            pointer: original.pointer,
            kind: original.kind,
            device: original.device,
            position: original.position,
            delta: original.delta,
            buttons: original.buttons,
            down: original.down,
            obscured: original.obscured,
            pressure: original.pressure,
            pressureMin: original.pressureMin,
            pressureMax: original.pressureMax,
            distance: original.distance,
            distanceMax: original.distanceMax,
            size: original.size,
            radiusMajor: original.radiusMajor,
            radiusMinor: original.radiusMinor,
            radiusMin: original.radiusMin,
            radiusMax: original.radiusMax,
            orientation: original.orientation,
            tilt: original.tilt,
            platformData: original.platformData,
            synthesized: original.synthesized,
            transform: transform,
            original: original
        )
    }

    /// The original un-transformed `PointerScrollInertiaCancelEvent`.
    private let _typedOriginal: PointerScrollInertiaCancelEvent

    /// The transformation matrix for this event.
    private let _storedTransform: Matrix4

    // Lazy computed local position and delta, matching _TransformedPointerEvent behavior.
    private lazy var _localPosition: Offset = PointerEvent.transformPosition(
        _storedTransform,
        position
    )

    private lazy var _localDelta: Offset = PointerEvent.transformDeltaViaPositions(
        untransformedEndPosition: position,
        transformedEndPosition: _localPosition,
        untransformedDelta: delta,
        transform: _storedTransform
    )

    /// The position in the local coordinate system of the event receiver.
    open override var localPosition: Offset { _localPosition }

    /// The delta in the local coordinate system of the event receiver.
    open override var localDelta: Offset { _localDelta }

    /// Transforms this event by delegating to the original event.
    ///
    /// **Dart Source:** `events.dart:2035-2037`
    open override func transformed(_ transform: Matrix4?) -> PointerScrollInertiaCancelEvent {
        return _typedOriginal.transformed(transform)
    }

    /// Creates a copy of this event with the specified properties replaced,
    /// delegating to the `PointerScrollInertiaCancelEvent.copyWith` behavior.
    ///
    /// **Dart Source:** `events.dart:1951-1986` (via `_CopyPointerScrollInertiaCancelEvent` mixin)
    open override func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        pointer: Int? = nil,
        kind: PointerDeviceKind? = nil,
        device: Int? = nil,
        position: Offset? = nil,
        delta: Offset? = nil,
        buttons: Int? = nil,
        obscured: Bool? = nil,
        pressure: Double? = nil,
        pressureMin: Double? = nil,
        pressureMax: Double? = nil,
        distance: Double? = nil,
        distanceMax: Double? = nil,
        size: Double? = nil,
        radiusMajor: Double? = nil,
        radiusMinor: Double? = nil,
        radiusMin: Double? = nil,
        radiusMax: Double? = nil,
        orientation: Double? = nil,
        tilt: Double? = nil,
        synthesized: Bool? = nil,
        embedderId: Int? = nil
    ) -> PointerScrollInertiaCancelEvent {
        return PointerScrollInertiaCancelEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - PointerScaleEvent

/// The pointer issued a scale event.
///
/// Pinching-to-zoom in the browser is an example of an event
/// that would create a `PointerScaleEvent`.
///
/// See also:
///
///  * `PointerSignalResolver`, which provides an opt-in mechanism whereby
///    participating agents may disambiguate an event's target.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2094-2117
open class PointerScaleEvent: PointerSignalEvent {

    /// Creates a pointer scale event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `scale` defaults to 1.0 (no scaling).
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        kind: PointerDeviceKind = .mouse,
        device: Int = 0,
        position: Offset = .zero,
        embedderId: Int = 0,
        scale: Double = 1.0
    ) {
        self.scale = scale
        super.init(
            viewId: viewId,
            timeStamp: timeStamp,
            kind: kind,
            device: device,
            position: position,
            embedderId: embedderId
        )
    }

    /// Internal initializer used by `TransformedPointerScaleEvent` to pass
    /// through all properties including transform and original.
    internal init(
        viewId: Int,
        embedderId: Int,
        timeStamp: Duration,
        pointer: Int,
        kind: PointerDeviceKind,
        device: Int,
        position: Offset,
        delta: Offset,
        buttons: Int,
        down: Bool,
        obscured: Bool,
        pressure: Double,
        pressureMin: Double,
        pressureMax: Double,
        distance: Double,
        distanceMax: Double,
        size: Double,
        radiusMajor: Double,
        radiusMinor: Double,
        radiusMin: Double,
        radiusMax: Double,
        orientation: Double,
        tilt: Double,
        platformData: Int,
        synthesized: Bool,
        transform: Matrix4?,
        original: PointerEvent?,
        scale: Double
    ) {
        self.scale = scale
        super.init(
            viewId: viewId,
            embedderId: embedderId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: kind,
            device: device,
            position: position,
            delta: delta,
            buttons: buttons,
            down: down,
            obscured: obscured,
            pressure: pressure,
            pressureMin: pressureMin,
            pressureMax: pressureMax,
            distance: distance,
            distanceMax: distanceMax,
            size: size,
            radiusMajor: radiusMajor,
            radiusMinor: radiusMinor,
            radiusMin: radiusMin,
            radiusMax: radiusMax,
            orientation: orientation,
            tilt: tilt,
            platformData: platformData,
            synthesized: synthesized,
            transform: transform,
            original: original
        )
    }

    /// The scale (zoom factor) of the event.
    ///
    /// **Dart Source:** `events.dart:2107-2108`
    public let scale: Double

    /// Transforms this event into the coordinate space described by `transform`.
    ///
    /// If `transform` is nil or equal to the current transform, returns self.
    /// Otherwise, creates a `TransformedPointerScaleEvent`.
    ///
    /// **Dart Source:** `events.dart:2110-2116`
    open override func transformed(_ transform: Matrix4?) -> PointerScaleEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerScaleEvent) ?? self
        return TransformedPointerScaleEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:2040-2080` (via `_CopyPointerScaleEvent` mixin)
    open func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        pointer: Int? = nil,
        kind: PointerDeviceKind? = nil,
        device: Int? = nil,
        position: Offset? = nil,
        delta: Offset? = nil,
        buttons: Int? = nil,
        obscured: Bool? = nil,
        pressure: Double? = nil,
        pressureMin: Double? = nil,
        pressureMax: Double? = nil,
        distance: Double? = nil,
        distanceMax: Double? = nil,
        size: Double? = nil,
        radiusMajor: Double? = nil,
        radiusMinor: Double? = nil,
        radiusMin: Double? = nil,
        radiusMax: Double? = nil,
        orientation: Double? = nil,
        tilt: Double? = nil,
        synthesized: Bool? = nil,
        embedderId: Int? = nil,
        scale: Double? = nil
    ) -> PointerScaleEvent {
        return PointerScaleEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId,
            scale: scale ?? self.scale
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerScaleEvent

/// Internal transformed variant of `PointerScaleEvent`.
///
/// In Dart, this class extends `_TransformedPointerEvent` and implements
/// `PointerScaleEvent`. Since Swift does not support multiple class inheritance,
/// this class extends `PointerScaleEvent` directly and overrides `localPosition`
/// and `localDelta` with lazily computed transformed values (mirroring the
/// behavior of `_TransformedPointerEvent`).
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2119-2135
internal class TransformedPointerScaleEvent: PointerScaleEvent {

    /// Creates a transformed pointer scale event.
    internal init(original: PointerScaleEvent, transform: Matrix4) {
        self._typedOriginal = original
        self._storedTransform = transform
        super.init(
            viewId: original.viewId,
            embedderId: original.embedderId,
            timeStamp: original.timeStamp,
            pointer: original.pointer,
            kind: original.kind,
            device: original.device,
            position: original.position,
            delta: original.delta,
            buttons: original.buttons,
            down: original.down,
            obscured: original.obscured,
            pressure: original.pressure,
            pressureMin: original.pressureMin,
            pressureMax: original.pressureMax,
            distance: original.distance,
            distanceMax: original.distanceMax,
            size: original.size,
            radiusMajor: original.radiusMajor,
            radiusMinor: original.radiusMinor,
            radiusMin: original.radiusMin,
            radiusMax: original.radiusMax,
            orientation: original.orientation,
            tilt: original.tilt,
            platformData: original.platformData,
            synthesized: original.synthesized,
            transform: transform,
            original: original,
            scale: original.scale
        )
    }

    /// The original un-transformed `PointerScaleEvent`.
    private let _typedOriginal: PointerScaleEvent

    /// The transformation matrix for this event.
    private let _storedTransform: Matrix4

    // Lazy computed local position and delta, matching _TransformedPointerEvent behavior.
    private lazy var _localPosition: Offset = PointerEvent.transformPosition(
        _storedTransform,
        position
    )

    private lazy var _localDelta: Offset = PointerEvent.transformDeltaViaPositions(
        untransformedEndPosition: position,
        transformedEndPosition: _localPosition,
        untransformedDelta: delta,
        transform: _storedTransform
    )

    /// The position in the local coordinate system of the event receiver.
    open override var localPosition: Offset { _localPosition }

    /// The delta in the local coordinate system of the event receiver.
    open override var localDelta: Offset { _localDelta }

    /// Transforms this event by delegating to the original event.
    ///
    /// **Dart Source:** `events.dart:2134`
    open override func transformed(_ transform: Matrix4?) -> PointerScaleEvent {
        return _typedOriginal.transformed(transform)
    }

    /// Creates a copy of this event with the specified properties replaced,
    /// delegating to the `PointerScaleEvent.copyWith` behavior.
    ///
    /// **Dart Source:** `events.dart:2040-2080` (via `_CopyPointerScaleEvent` mixin)
    open override func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        pointer: Int? = nil,
        kind: PointerDeviceKind? = nil,
        device: Int? = nil,
        position: Offset? = nil,
        delta: Offset? = nil,
        buttons: Int? = nil,
        obscured: Bool? = nil,
        pressure: Double? = nil,
        pressureMin: Double? = nil,
        pressureMax: Double? = nil,
        distance: Double? = nil,
        distanceMax: Double? = nil,
        size: Double? = nil,
        radiusMajor: Double? = nil,
        radiusMinor: Double? = nil,
        radiusMin: Double? = nil,
        radiusMax: Double? = nil,
        orientation: Double? = nil,
        tilt: Double? = nil,
        synthesized: Bool? = nil,
        embedderId: Int? = nil,
        scale: Double? = nil
    ) -> PointerScaleEvent {
        return PointerScaleEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId,
            scale: scale ?? self.scale
        ).transformed(transform)
    }
}

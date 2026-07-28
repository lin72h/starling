// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - PointerPanZoomStartEvent

/// A pointer pan/zoom has started.
///
/// This event is always generated with `kind: .trackpad` since pan/zoom
/// interactions originate from trackpad devices.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2181-2204
open class PointerPanZoomStartEvent: PointerEvent {

    /// Creates a pointer pan/zoom start event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `kind` is always `.trackpad`.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        device: Int = 0,
        pointer: Int = 0,
        position: Offset = .zero,
        embedderId: Int = 0,
        synthesized: Bool = false
    ) {
        super.init(
            viewId: viewId,
            embedderId: embedderId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: .trackpad,
            device: device,
            position: position,
            synthesized: synthesized
        )
    }

    /// Internal initializer used by `TransformedPointerPanZoomStartEvent` to pass
    /// through transform and original.
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
    /// Otherwise, creates a `TransformedPointerPanZoomStartEvent`.
    ///
    /// **Dart Source:** `events.dart:2195-2204`
    open override func transformed(_ transform: Matrix4?) -> PointerPanZoomStartEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerPanZoomStartEvent) ?? self
        return TransformedPointerPanZoomStartEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:2137-2172` (via `_CopyPointerPanZoomStartEvent` mixin)
    open func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        device: Int? = nil,
        pointer: Int? = nil,
        position: Offset? = nil,
        embedderId: Int? = nil,
        synthesized: Bool? = nil
    ) -> PointerPanZoomStartEvent {
        return PointerPanZoomStartEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            device: device ?? self.device,
            pointer: pointer ?? self.pointer,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId,
            synthesized: synthesized ?? self.synthesized
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerPanZoomStartEvent

/// Internal transformed variant of `PointerPanZoomStartEvent`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2206-2219
internal class TransformedPointerPanZoomStartEvent: PointerPanZoomStartEvent {

    /// Creates a transformed pointer pan/zoom start event.
    internal init(original: PointerPanZoomStartEvent, transform: Matrix4) {
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

    /// The original un-transformed `PointerPanZoomStartEvent`.
    private let _typedOriginal: PointerPanZoomStartEvent

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
    /// **Dart Source:** `events.dart:2216-2218`
    open override func transformed(_ transform: Matrix4?) -> PointerPanZoomStartEvent {
        return _typedOriginal.transformed(transform)
    }

    /// Creates a copy of this event with the specified properties replaced,
    /// delegating to the `PointerPanZoomStartEvent.copyWith` behavior.
    ///
    /// **Dart Source:** `events.dart:2137-2172` (via `_CopyPointerPanZoomStartEvent` mixin)
    open override func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        device: Int? = nil,
        pointer: Int? = nil,
        position: Offset? = nil,
        embedderId: Int? = nil,
        synthesized: Bool? = nil
    ) -> PointerPanZoomStartEvent {
        return PointerPanZoomStartEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            device: device ?? self.device,
            pointer: pointer ?? self.pointer,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId,
            synthesized: synthesized ?? self.synthesized
        ).transformed(transform)
    }
}

// MARK: - PointerPanZoomUpdateEvent

/// A pointer pan/zoom has been updated.
///
/// This event is always generated with `kind: .trackpad` since pan/zoom
/// interactions originate from trackpad devices. It carries extra properties
/// for `pan`, `panDelta`, `scale`, and `rotation`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2293-2333
open class PointerPanZoomUpdateEvent: PointerEvent {

    /// Creates a pointer pan/zoom update event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `kind` is always `.trackpad`.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        device: Int = 0,
        pointer: Int = 0,
        position: Offset = .zero,
        embedderId: Int = 0,
        pan: Offset = .zero,
        panDelta: Offset = .zero,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        synthesized: Bool = false
    ) {
        self.pan = pan
        self.panDelta = panDelta
        self.scale = scale
        self.rotation = rotation
        super.init(
            viewId: viewId,
            embedderId: embedderId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: .trackpad,
            device: device,
            position: position,
            synthesized: synthesized
        )
    }

    /// Internal initializer used by `TransformedPointerPanZoomUpdateEvent` to pass
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
        pan: Offset,
        panDelta: Offset,
        scale: Double,
        rotation: Double
    ) {
        self.pan = pan
        self.panDelta = panDelta
        self.scale = scale
        self.rotation = rotation
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

    /// The total pan offset of the pan/zoom.
    ///
    /// **Dart Source:** `events.dart:2313`
    public let pan: Offset

    /// The pan offset of the pan/zoom, transformed into the local coordinate
    /// space of the event receiver.
    ///
    /// For non-transformed events, this is the same as `pan`.
    ///
    /// **Dart Source:** `events.dart:2316`
    open var localPan: Offset { pan }

    /// The pan delta of the pan/zoom since the last event.
    ///
    /// **Dart Source:** `events.dart:2318`
    public let panDelta: Offset

    /// The pan delta of the pan/zoom, transformed into the local coordinate
    /// space of the event receiver.
    ///
    /// For non-transformed events, this is the same as `panDelta`.
    ///
    /// **Dart Source:** `events.dart:2321`
    open var localPanDelta: Offset { panDelta }

    /// The scale (zoom factor) of the pan/zoom.
    ///
    /// **Dart Source:** `events.dart:2323`
    public let scale: Double

    /// The rotation of the pan/zoom in radians.
    ///
    /// **Dart Source:** `events.dart:2325`
    public let rotation: Double

    /// Transforms this event into the coordinate space described by `transform`.
    ///
    /// If `transform` is nil or equal to the current transform, returns self.
    /// Otherwise, creates a `TransformedPointerPanZoomUpdateEvent`.
    ///
    /// **Dart Source:** `events.dart:2327-2333`
    open override func transformed(_ transform: Matrix4?) -> PointerPanZoomUpdateEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerPanZoomUpdateEvent) ?? self
        return TransformedPointerPanZoomUpdateEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:2221-2280` (via `_CopyPointerPanZoomUpdateEvent` mixin)
    open func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        device: Int? = nil,
        pointer: Int? = nil,
        position: Offset? = nil,
        embedderId: Int? = nil,
        pan: Offset? = nil,
        panDelta: Offset? = nil,
        scale: Double? = nil,
        rotation: Double? = nil,
        synthesized: Bool? = nil
    ) -> PointerPanZoomUpdateEvent {
        return PointerPanZoomUpdateEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            device: device ?? self.device,
            pointer: pointer ?? self.pointer,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId,
            pan: pan ?? self.pan,
            panDelta: panDelta ?? self.panDelta,
            scale: scale ?? self.scale,
            rotation: rotation ?? self.rotation,
            synthesized: synthesized ?? self.synthesized
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerPanZoomUpdateEvent

/// Internal transformed variant of `PointerPanZoomUpdateEvent`.
///
/// In Dart, this class extends `_TransformedPointerEvent` and implements
/// `PointerPanZoomUpdateEvent`. Since Swift does not support multiple class
/// inheritance, this class extends `PointerPanZoomUpdateEvent` directly and
/// overrides `localPosition`, `localDelta`, `localPan`, and `localPanDelta`
/// with lazily computed transformed values (mirroring the behavior of
/// `_TransformedPointerEvent`).
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2335-2371
internal class TransformedPointerPanZoomUpdateEvent: PointerPanZoomUpdateEvent {

    /// Creates a transformed pointer pan/zoom update event.
    internal init(original: PointerPanZoomUpdateEvent, transform: Matrix4) {
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
            pan: original.pan,
            panDelta: original.panDelta,
            scale: original.scale,
            rotation: original.rotation
        )
    }

    /// The original un-transformed `PointerPanZoomUpdateEvent`.
    private let _typedOriginal: PointerPanZoomUpdateEvent

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

    /// Lazily computed local pan using `PointerEvent.transformPosition`.
    ///
    /// **Dart Source:** `events.dart:2349`
    private lazy var _localPan: Offset = PointerEvent.transformPosition(
        _storedTransform,
        pan
    )

    /// Lazily computed local pan delta using `PointerEvent.transformDeltaViaPositions`.
    ///
    /// **Dart Source:** `events.dart:2352-2356`
    private lazy var _localPanDelta: Offset = PointerEvent.transformDeltaViaPositions(
        untransformedEndPosition: pan,
        transformedEndPosition: _localPan,
        untransformedDelta: panDelta,
        transform: _storedTransform
    )

    /// The position in the local coordinate system of the event receiver.
    open override var localPosition: Offset { _localPosition }

    /// The delta in the local coordinate system of the event receiver.
    open override var localDelta: Offset { _localDelta }

    /// The pan offset transformed into the local coordinate space.
    ///
    /// **Dart Source:** `events.dart:2349`
    open override var localPan: Offset { _localPan }

    /// The pan delta transformed into the local coordinate space.
    ///
    /// **Dart Source:** `events.dart:2352-2356`
    open override var localPanDelta: Offset { _localPanDelta }

    /// Transforms this event by delegating to the original event.
    ///
    /// **Dart Source:** `events.dart:2368-2370`
    open override func transformed(_ transform: Matrix4?) -> PointerPanZoomUpdateEvent {
        return _typedOriginal.transformed(transform)
    }

    /// Creates a copy of this event with the specified properties replaced,
    /// delegating to the `PointerPanZoomUpdateEvent.copyWith` behavior.
    ///
    /// **Dart Source:** `events.dart:2221-2280` (via `_CopyPointerPanZoomUpdateEvent` mixin)
    open override func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        device: Int? = nil,
        pointer: Int? = nil,
        position: Offset? = nil,
        embedderId: Int? = nil,
        pan: Offset? = nil,
        panDelta: Offset? = nil,
        scale: Double? = nil,
        rotation: Double? = nil,
        synthesized: Bool? = nil
    ) -> PointerPanZoomUpdateEvent {
        return PointerPanZoomUpdateEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            device: device ?? self.device,
            pointer: pointer ?? self.pointer,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId,
            pan: pan ?? self.pan,
            panDelta: panDelta ?? self.panDelta,
            scale: scale ?? self.scale,
            rotation: rotation ?? self.rotation,
            synthesized: synthesized ?? self.synthesized
        ).transformed(transform)
    }
}

// MARK: - PointerPanZoomEndEvent

/// A pointer pan/zoom has ended.
///
/// This event is always generated with `kind: .trackpad` since pan/zoom
/// interactions originate from trackpad devices.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2417-2440
open class PointerPanZoomEndEvent: PointerEvent {

    /// Creates a pointer pan/zoom end event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `kind` is always `.trackpad`.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        device: Int = 0,
        pointer: Int = 0,
        position: Offset = .zero,
        embedderId: Int = 0,
        synthesized: Bool = false
    ) {
        super.init(
            viewId: viewId,
            embedderId: embedderId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: .trackpad,
            device: device,
            position: position,
            synthesized: synthesized
        )
    }

    /// Internal initializer used by `TransformedPointerPanZoomEndEvent` to pass
    /// through transform and original.
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
    /// Otherwise, creates a `TransformedPointerPanZoomEndEvent`.
    ///
    /// **Dart Source:** `events.dart:2431-2440`
    open override func transformed(_ transform: Matrix4?) -> PointerPanZoomEndEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerPanZoomEndEvent) ?? self
        return TransformedPointerPanZoomEndEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:2373-2408` (via `_CopyPointerPanZoomEndEvent` mixin)
    open func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        device: Int? = nil,
        pointer: Int? = nil,
        position: Offset? = nil,
        embedderId: Int? = nil,
        synthesized: Bool? = nil
    ) -> PointerPanZoomEndEvent {
        return PointerPanZoomEndEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            device: device ?? self.device,
            pointer: pointer ?? self.pointer,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId,
            synthesized: synthesized ?? self.synthesized
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerPanZoomEndEvent

/// Internal transformed variant of `PointerPanZoomEndEvent`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2442-2455
internal class TransformedPointerPanZoomEndEvent: PointerPanZoomEndEvent {

    /// Creates a transformed pointer pan/zoom end event.
    internal init(original: PointerPanZoomEndEvent, transform: Matrix4) {
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

    /// The original un-transformed `PointerPanZoomEndEvent`.
    private let _typedOriginal: PointerPanZoomEndEvent

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
    /// **Dart Source:** `events.dart:2452-2454`
    open override func transformed(_ transform: Matrix4?) -> PointerPanZoomEndEvent {
        return _typedOriginal.transformed(transform)
    }

    /// Creates a copy of this event with the specified properties replaced,
    /// delegating to the `PointerPanZoomEndEvent.copyWith` behavior.
    ///
    /// **Dart Source:** `events.dart:2373-2408` (via `_CopyPointerPanZoomEndEvent` mixin)
    open override func copyWith(
        viewId: Int? = nil,
        timeStamp: Duration? = nil,
        device: Int? = nil,
        pointer: Int? = nil,
        position: Offset? = nil,
        embedderId: Int? = nil,
        synthesized: Bool? = nil
    ) -> PointerPanZoomEndEvent {
        return PointerPanZoomEndEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            device: device ?? self.device,
            pointer: pointer ?? self.pointer,
            position: position ?? self.position,
            embedderId: embedderId ?? self.embedderId,
            synthesized: synthesized ?? self.synthesized
        ).transformed(transform)
    }
}

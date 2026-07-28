// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - PointerCancelEvent

/// The input from the pointer is no longer directed towards this receiver.
///
/// See also:
///
///  * `Listener.onPointerCancel`, which allows callers to be notified of these
///    events in a widget tree.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2515-2549
open class PointerCancelEvent: PointerEvent {

    /// Creates a pointer cancel event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `down` property is always false and `pressure` is always 0.0.
    /// The `kind` must not be `.trackpad`.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        pointer: Int = 0,
        kind: PointerDeviceKind = .touch,
        device: Int = 0,
        position: Offset = .zero,
        buttons: Int = 0,
        obscured: Bool = false,
        pressureMin: Double = 1.0,
        pressureMax: Double = 1.0,
        distance: Double = 0.0,
        distanceMax: Double = 0.0,
        size: Double = 0.0,
        radiusMajor: Double = 0.0,
        radiusMinor: Double = 0.0,
        radiusMin: Double = 0.0,
        radiusMax: Double = 0.0,
        orientation: Double = 0.0,
        tilt: Double = 0.0,
        embedderId: Int = 0
    ) {
        assert(kind != .trackpad, "Trackpad pointer events should use PointerPanZoom events.")
        super.init(
            viewId: viewId,
            embedderId: embedderId,
            timeStamp: timeStamp,
            pointer: pointer,
            kind: kind,
            device: device,
            position: position,
            buttons: buttons,
            down: false,
            obscured: obscured,
            pressure: 0.0,
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
            tilt: tilt
        )
    }

    /// Internal initializer used by `TransformedPointerCancelEvent` to pass
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
    /// Otherwise, creates a `TransformedPointerCancelEvent`.
    ///
    /// **Dart Source:** `events.dart:2541-2549`
    open override func transformed(_ transform: Matrix4?) -> PointerCancelEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerCancelEvent) ?? self
        return TransformedPointerCancelEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:2457-2507` (via `_CopyPointerCancelEvent` mixin)
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
    ) -> PointerCancelEvent {
        return PointerCancelEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            pointer: pointer ?? self.pointer,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            buttons: buttons ?? self.buttons,
            obscured: obscured ?? self.obscured,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
            distance: distance ?? self.distance,
            distanceMax: distanceMax ?? self.distanceMax,
            size: size ?? self.size,
            radiusMajor: radiusMajor ?? self.radiusMajor,
            radiusMinor: radiusMinor ?? self.radiusMinor,
            radiusMin: radiusMin ?? self.radiusMin,
            radiusMax: radiusMax ?? self.radiusMax,
            orientation: orientation ?? self.orientation,
            tilt: tilt ?? self.tilt,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerCancelEvent

/// Internal transformed variant of `PointerCancelEvent`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2593-2606
internal class TransformedPointerCancelEvent: PointerCancelEvent {

    /// Creates a transformed pointer cancel event.
    internal init(original: PointerCancelEvent, transform: Matrix4) {
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

    /// The original un-transformed `PointerCancelEvent`.
    private let _typedOriginal: PointerCancelEvent

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
    /// **Dart Source:** `events.dart:2603-2605`
    open override func transformed(_ transform: Matrix4?) -> PointerCancelEvent {
        return _typedOriginal.transformed(transform)
    }

    /// Creates a copy of this event with the specified properties replaced,
    /// delegating to the `PointerCancelEvent.copyWith` behavior.
    ///
    /// **Dart Source:** `events.dart:2457-2507` (via `_CopyPointerCancelEvent` mixin)
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
    ) -> PointerCancelEvent {
        return PointerCancelEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            pointer: pointer ?? self.pointer,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            buttons: buttons ?? self.buttons,
            obscured: obscured ?? self.obscured,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
            distance: distance ?? self.distance,
            distanceMax: distanceMax ?? self.distanceMax,
            size: size ?? self.size,
            radiusMajor: radiusMajor ?? self.radiusMajor,
            radiusMinor: radiusMinor ?? self.radiusMinor,
            radiusMin: radiusMin ?? self.radiusMin,
            radiusMax: radiusMax ?? self.radiusMax,
            orientation: orientation ?? self.orientation,
            tilt: tilt ?? self.tilt,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - Slop Functions

/// Computes the hit slop for a given pointer device kind and gesture settings.
///
/// For mouse pointers, returns `kPrecisePointerHitSlop`. For all other pointer
/// kinds (stylus, inverted stylus, unknown, touch, trackpad), returns the
/// `touchSlop` from `settings`, or `kTouchSlop` if settings is nil.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2552-2561
public func computeHitSlop(_ kind: PointerDeviceKind, _ settings: DeviceGestureSettings?) -> Double {
    switch kind {
    case .mouse:
        return kPrecisePointerHitSlop
    case .stylus, .invertedStylus, .unknown, .touch, .trackpad:
        return settings?.touchSlop ?? kTouchSlop
    }
}

/// Computes the pan slop for a given pointer device kind and gesture settings.
///
/// For mouse pointers, returns `kPrecisePointerPanSlop`. For all other pointer
/// kinds (stylus, inverted stylus, unknown, touch, trackpad), returns the
/// `panSlop` from `settings`, or `kPanSlop` if settings is nil.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2563-2572
public func computePanSlop(_ kind: PointerDeviceKind, _ settings: DeviceGestureSettings?) -> Double {
    switch kind {
    case .mouse:
        return kPrecisePointerPanSlop
    case .stylus, .invertedStylus, .unknown, .touch, .trackpad:
        return settings?.panSlop ?? kPanSlop
    }
}

/// Computes the scale slop for a given pointer device kind.
///
/// For mouse pointers, returns `kPrecisePointerScaleSlop`. For all other pointer
/// kinds (stylus, inverted stylus, unknown, touch, trackpad), returns `kScaleSlop`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 2574-2591
public func computeScaleSlop(_ kind: PointerDeviceKind) -> Double {
    switch kind {
    case .mouse:
        return kPrecisePointerScaleSlop
    case .stylus, .invertedStylus, .unknown, .touch, .trackpad:
        return kScaleSlop
    }
}

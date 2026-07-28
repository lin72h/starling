// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - PointerHoverEvent

/// The pointer has moved with respect to the device while the pointer is not
/// in contact with the device.
///
/// See also:
///
///  * `PointerEnterEvent`, which reports when the pointer has entered an object.
///  * `PointerExitEvent`, which reports when the pointer has left an object.
///  * `PointerMoveEvent`, which reports movement while the pointer is in
///    contact with the device.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1097-1131
open class PointerHoverEvent: PointerEvent {

    /// Creates a pointer hover event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `down` property is always false and `pressure` is always 0.0.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        kind: PointerDeviceKind = .touch,
        pointer: Int = 0,
        device: Int = 0,
        position: Offset = .zero,
        delta: Offset = .zero,
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
        synthesized: Bool = false,
        embedderId: Int = 0
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
            tilt: tilt,
            synthesized: synthesized
        )
    }

    /// Internal initializer used by `TransformedPointerHoverEvent` to pass
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
    /// Otherwise, creates a `TransformedPointerHoverEvent`.
    ///
    /// **Dart Source:** `events.dart:1124-1131`
    open override func transformed(_ transform: Matrix4?) -> PointerHoverEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerHoverEvent) ?? self
        return TransformedPointerHoverEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:1032-1083`
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
    ) -> PointerHoverEvent {
        return PointerHoverEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            delta: delta ?? self.delta,
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
            synthesized: synthesized ?? self.synthesized,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerHoverEvent

/// Internal transformed variant of `PointerHoverEvent`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1133-1146
internal class TransformedPointerHoverEvent: PointerHoverEvent {

    /// Creates a transformed pointer hover event.
    internal init(original: PointerHoverEvent, transform: Matrix4) {
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

    private let _typedOriginal: PointerHoverEvent
    private let _storedTransform: Matrix4

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

    open override var localPosition: Offset { _localPosition }
    open override var localDelta: Offset { _localDelta }

    open override func transformed(_ transform: Matrix4?) -> PointerHoverEvent {
        return _typedOriginal.transformed(transform)
    }

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
    ) -> PointerHoverEvent {
        return PointerHoverEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            delta: delta ?? self.delta,
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
            synthesized: synthesized ?? self.synthesized,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - PointerEnterEvent

/// The pointer has moved with respect to the device while the pointer is or is
/// not in contact with the device, and it has entered a target object.
///
/// See also:
///
///  * `PointerHoverEvent`, which reports when the pointer has moved while
///    within an object.
///  * `PointerExitEvent`, which reports when the pointer has left an object.
///  * `PointerMoveEvent`, which reports movement while the pointer is in
///    contact with the device.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1213-1279
open class PointerEnterEvent: PointerEvent {

    /// Creates a pointer enter event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `pressure` is always 0.0. The `kind` must not be `.trackpad`.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        pointer: Int = 0,
        kind: PointerDeviceKind = .touch,
        device: Int = 0,
        position: Offset = .zero,
        delta: Offset = .zero,
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
        down: Bool = false,
        synthesized: Bool = false,
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
            delta: delta,
            buttons: buttons,
            down: down,
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
            tilt: tilt,
            synthesized: synthesized
        )
    }

    /// Internal initializer used by `TransformedPointerEnterEvent` to pass
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

    /// Creates an enter event from a `PointerEvent`.
    ///
    /// This is used by the `MouseTracker` to synthesize enter events.
    ///
    /// **Dart Source:** `events.dart:1247-1270`
    public static func fromMouseEvent(_ event: PointerEvent) -> PointerEnterEvent {
        return PointerEnterEvent(
            viewId: event.viewId,
            timeStamp: event.timeStamp,
            pointer: event.pointer,
            kind: event.kind,
            device: event.device,
            position: event.position,
            delta: event.delta,
            buttons: event.buttons,
            obscured: event.obscured,
            pressureMin: event.pressureMin,
            pressureMax: event.pressureMax,
            distance: event.distance,
            distanceMax: event.distanceMax,
            size: event.size,
            radiusMajor: event.radiusMajor,
            radiusMinor: event.radiusMinor,
            radiusMin: event.radiusMin,
            radiusMax: event.radiusMax,
            orientation: event.orientation,
            tilt: event.tilt,
            down: event.down,
            synthesized: event.synthesized,
            embedderId: event.embedderId
        ).transformed(event.transform)
    }

    /// Transforms this event into the coordinate space described by `transform`.
    ///
    /// If `transform` is nil or equal to the current transform, returns self.
    /// Otherwise, creates a `TransformedPointerEnterEvent`.
    ///
    /// **Dart Source:** `events.dart:1272-1279`
    open override func transformed(_ transform: Matrix4?) -> PointerEnterEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerEnterEvent) ?? self
        return TransformedPointerEnterEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:1148-1199`
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
    ) -> PointerEnterEvent {
        return PointerEnterEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            delta: delta ?? self.delta,
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
            synthesized: synthesized ?? self.synthesized,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerEnterEvent

/// Internal transformed variant of `PointerEnterEvent`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1281-1294
internal class TransformedPointerEnterEvent: PointerEnterEvent {

    internal init(original: PointerEnterEvent, transform: Matrix4) {
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

    private let _typedOriginal: PointerEnterEvent
    private let _storedTransform: Matrix4

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

    open override var localPosition: Offset { _localPosition }
    open override var localDelta: Offset { _localDelta }

    open override func transformed(_ transform: Matrix4?) -> PointerEnterEvent {
        return _typedOriginal.transformed(transform)
    }

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
    ) -> PointerEnterEvent {
        return PointerEnterEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            delta: delta ?? self.delta,
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
            synthesized: synthesized ?? self.synthesized,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - PointerExitEvent

/// The pointer has moved with respect to the device while the pointer is or is
/// not in contact with the device, and exited a target object.
///
/// See also:
///
///  * `PointerHoverEvent`, which reports when the pointer has moved while
///    within an object.
///  * `PointerEnterEvent`, which reports when the pointer has entered an object.
///  * `PointerMoveEvent`, which reports movement while the pointer is in
///    contact with the device.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1361-1425
open class PointerExitEvent: PointerEvent {

    /// Creates a pointer exit event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `pressure` is always 0.0. The `kind` must not be `.trackpad`.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        kind: PointerDeviceKind = .touch,
        pointer: Int = 0,
        device: Int = 0,
        position: Offset = .zero,
        delta: Offset = .zero,
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
        down: Bool = false,
        synthesized: Bool = false,
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
            delta: delta,
            buttons: buttons,
            down: down,
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
            tilt: tilt,
            synthesized: synthesized
        )
    }

    /// Internal initializer used by `TransformedPointerExitEvent` to pass
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

    /// Creates an exit event from a `PointerEvent`.
    ///
    /// This is used by the `MouseTracker` to synthesize exit events.
    ///
    /// **Dart Source:** `events.dart:1393-1416`
    public static func fromMouseEvent(_ event: PointerEvent) -> PointerExitEvent {
        return PointerExitEvent(
            viewId: event.viewId,
            timeStamp: event.timeStamp,
            kind: event.kind,
            pointer: event.pointer,
            device: event.device,
            position: event.position,
            delta: event.delta,
            buttons: event.buttons,
            obscured: event.obscured,
            pressureMin: event.pressureMin,
            pressureMax: event.pressureMax,
            distance: event.distance,
            distanceMax: event.distanceMax,
            size: event.size,
            radiusMajor: event.radiusMajor,
            radiusMinor: event.radiusMinor,
            radiusMin: event.radiusMin,
            radiusMax: event.radiusMax,
            orientation: event.orientation,
            tilt: event.tilt,
            down: event.down,
            synthesized: event.synthesized,
            embedderId: event.embedderId
        ).transformed(event.transform)
    }

    /// Transforms this event into the coordinate space described by `transform`.
    ///
    /// If `transform` is nil or equal to the current transform, returns self.
    /// Otherwise, creates a `TransformedPointerExitEvent`.
    ///
    /// **Dart Source:** `events.dart:1418-1425`
    open override func transformed(_ transform: Matrix4?) -> PointerExitEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerExitEvent) ?? self
        return TransformedPointerExitEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:1296-1347`
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
    ) -> PointerExitEvent {
        return PointerExitEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            delta: delta ?? self.delta,
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
            synthesized: synthesized ?? self.synthesized,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerExitEvent

/// Internal transformed variant of `PointerExitEvent`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1427-1440
internal class TransformedPointerExitEvent: PointerExitEvent {

    internal init(original: PointerExitEvent, transform: Matrix4) {
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

    private let _typedOriginal: PointerExitEvent
    private let _storedTransform: Matrix4

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

    open override var localPosition: Offset { _localPosition }
    open override var localDelta: Offset { _localDelta }

    open override func transformed(_ transform: Matrix4?) -> PointerExitEvent {
        return _typedOriginal.transformed(transform)
    }

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
    ) -> PointerExitEvent {
        return PointerExitEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            delta: delta ?? self.delta,
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
            synthesized: synthesized ?? self.synthesized,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - PointerDownEvent

/// The pointer has made contact with the device.
///
/// See also:
///
///  * `Listener.onPointerDown`, which allows callers to be notified of these
///    events in a widget tree.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1500-1533
open class PointerDownEvent: PointerEvent {

    /// Creates a pointer down event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `down` property is always true, `distance` is always 0.0,
    /// and `buttons` defaults to `kPrimaryButton`. The `kind` must not be `.trackpad`.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        pointer: Int = 0,
        kind: PointerDeviceKind = .touch,
        device: Int = 0,
        position: Offset = .zero,
        buttons: Int = kPrimaryButton,
        obscured: Bool = false,
        pressure: Double = 1.0,
        pressureMin: Double = 1.0,
        pressureMax: Double = 1.0,
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
            down: true,
            obscured: obscured,
            pressure: pressure,
            pressureMin: pressureMin,
            pressureMax: pressureMax,
            distance: 0.0,
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

    /// Internal initializer used by `TransformedPointerDownEvent` to pass
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
    /// Otherwise, creates a `TransformedPointerDownEvent`.
    ///
    /// **Dart Source:** `events.dart:1526-1533`
    open override func transformed(_ transform: Matrix4?) -> PointerDownEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerDownEvent) ?? self
        return TransformedPointerDownEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:1442-1492`
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
    ) -> PointerDownEvent {
        return PointerDownEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            pointer: pointer ?? self.pointer,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            buttons: buttons ?? self.buttons,
            obscured: obscured ?? self.obscured,
            pressure: pressure ?? self.pressure,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
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

// MARK: - TransformedPointerDownEvent

/// Internal transformed variant of `PointerDownEvent`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1535-1548
internal class TransformedPointerDownEvent: PointerDownEvent {

    internal init(original: PointerDownEvent, transform: Matrix4) {
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

    private let _typedOriginal: PointerDownEvent
    private let _storedTransform: Matrix4

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

    open override var localPosition: Offset { _localPosition }
    open override var localDelta: Offset { _localDelta }

    open override func transformed(_ transform: Matrix4?) -> PointerDownEvent {
        return _typedOriginal.transformed(transform)
    }

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
    ) -> PointerDownEvent {
        return PointerDownEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            pointer: pointer ?? self.pointer,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            buttons: buttons ?? self.buttons,
            obscured: obscured ?? self.obscured,
            pressure: pressure ?? self.pressure,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
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

// MARK: - PointerMoveEvent

/// The pointer has moved with respect to the device while the pointer is in
/// contact with the device.
///
/// See also:
///
///  * `PointerHoverEvent`, which reports movement while the pointer is not in
///    contact with the device.
///  * `Listener.onPointerMove`, which allows callers to be notified of these
///    events in a widget tree.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1613-1650
open class PointerMoveEvent: PointerEvent {

    /// Creates a pointer move event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `down` property is always true, `distance` is always 0.0,
    /// and `buttons` defaults to `kPrimaryButton`. The `kind` must not be `.trackpad`.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        pointer: Int = 0,
        kind: PointerDeviceKind = .touch,
        device: Int = 0,
        position: Offset = .zero,
        delta: Offset = .zero,
        buttons: Int = kPrimaryButton,
        obscured: Bool = false,
        pressure: Double = 1.0,
        pressureMin: Double = 1.0,
        pressureMax: Double = 1.0,
        distanceMax: Double = 0.0,
        size: Double = 0.0,
        radiusMajor: Double = 0.0,
        radiusMinor: Double = 0.0,
        radiusMin: Double = 0.0,
        radiusMax: Double = 0.0,
        orientation: Double = 0.0,
        tilt: Double = 0.0,
        platformData: Int = 0,
        synthesized: Bool = false,
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
            delta: delta,
            buttons: buttons,
            down: true,
            obscured: obscured,
            pressure: pressure,
            pressureMin: pressureMin,
            pressureMax: pressureMax,
            distance: 0.0,
            distanceMax: distanceMax,
            size: size,
            radiusMajor: radiusMajor,
            radiusMinor: radiusMinor,
            radiusMin: radiusMin,
            radiusMax: radiusMax,
            orientation: orientation,
            tilt: tilt,
            platformData: platformData,
            synthesized: synthesized
        )
    }

    /// Internal initializer used by `TransformedPointerMoveEvent` to pass
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
    /// Otherwise, creates a `TransformedPointerMoveEvent`.
    ///
    /// **Dart Source:** `events.dart:1642-1650`
    open override func transformed(_ transform: Matrix4?) -> PointerMoveEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerMoveEvent) ?? self
        return TransformedPointerMoveEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:1550-1602`
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
    ) -> PointerMoveEvent {
        return PointerMoveEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            pointer: pointer ?? self.pointer,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            delta: delta ?? self.delta,
            buttons: buttons ?? self.buttons,
            obscured: obscured ?? self.obscured,
            pressure: pressure ?? self.pressure,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
            distanceMax: distanceMax ?? self.distanceMax,
            size: size ?? self.size,
            radiusMajor: radiusMajor ?? self.radiusMajor,
            radiusMinor: radiusMinor ?? self.radiusMinor,
            radiusMin: radiusMin ?? self.radiusMin,
            radiusMax: radiusMax ?? self.radiusMax,
            orientation: orientation ?? self.orientation,
            tilt: tilt ?? self.tilt,
            synthesized: synthesized ?? self.synthesized,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerMoveEvent

/// Internal transformed variant of `PointerMoveEvent`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1652-1665
internal class TransformedPointerMoveEvent: PointerMoveEvent {

    internal init(original: PointerMoveEvent, transform: Matrix4) {
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

    private let _typedOriginal: PointerMoveEvent
    private let _storedTransform: Matrix4

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

    open override var localPosition: Offset { _localPosition }
    open override var localDelta: Offset { _localDelta }

    open override func transformed(_ transform: Matrix4?) -> PointerMoveEvent {
        return _typedOriginal.transformed(transform)
    }

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
    ) -> PointerMoveEvent {
        return PointerMoveEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            pointer: pointer ?? self.pointer,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            delta: delta ?? self.delta,
            buttons: buttons ?? self.buttons,
            obscured: obscured ?? self.obscured,
            pressure: pressure ?? self.pressure,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
            distanceMax: distanceMax ?? self.distanceMax,
            size: size ?? self.size,
            radiusMajor: radiusMajor ?? self.radiusMajor,
            radiusMinor: radiusMinor ?? self.radiusMinor,
            radiusMin: radiusMin ?? self.radiusMin,
            radiusMax: radiusMax ?? self.radiusMax,
            orientation: orientation ?? self.orientation,
            tilt: tilt ?? self.tilt,
            synthesized: synthesized ?? self.synthesized,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - PointerUpEvent

/// The pointer has stopped making contact with the device.
///
/// See also:
///
///  * `Listener.onPointerUp`, which allows callers to be notified of these
///    events in a widget tree.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1727-1763
open class PointerUpEvent: PointerEvent {

    /// Creates a pointer up event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The `down` property is always false and `pressure` defaults to 0.0.
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
        pressure: Double = 0.0,
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
            tilt: tilt
        )
    }

    /// Internal initializer used by `TransformedPointerUpEvent` to pass
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
    /// Otherwise, creates a `TransformedPointerUpEvent`.
    ///
    /// **Dart Source:** `events.dart:1756-1763`
    open override func transformed(_ transform: Matrix4?) -> PointerUpEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerUpEvent) ?? self
        return TransformedPointerUpEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:1667-1719`
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
    ) -> PointerUpEvent {
        return PointerUpEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            pointer: pointer ?? self.pointer,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            buttons: buttons ?? self.buttons,
            obscured: obscured ?? self.obscured,
            pressure: pressure ?? self.pressure,
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

// MARK: - TransformedPointerUpEvent

/// Internal transformed variant of `PointerUpEvent`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1765-1778
internal class TransformedPointerUpEvent: PointerUpEvent {

    internal init(original: PointerUpEvent, transform: Matrix4) {
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

    private let _typedOriginal: PointerUpEvent
    private let _storedTransform: Matrix4

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

    open override var localPosition: Offset { _localPosition }
    open override var localDelta: Offset { _localDelta }

    open override func transformed(_ transform: Matrix4?) -> PointerUpEvent {
        return _typedOriginal.transformed(transform)
    }

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
    ) -> PointerUpEvent {
        return PointerUpEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            pointer: pointer ?? self.pointer,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            buttons: buttons ?? self.buttons,
            obscured: obscured ?? self.obscured,
            pressure: pressure ?? self.pressure,
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

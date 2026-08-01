// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - PointerAddedEvent

/// The device has started tracking the pointer.
///
/// For example, the pointer might be hovering above the device, having not yet
/// made contact with the surface of the device.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 895-923
open class PointerAddedEvent: PointerEvent {

    /// Creates a pointer added event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The pressure is always set to 0.0 for added events.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        pointer: Int = 0,
        kind: PointerDeviceKind = .touch,
        device: Int = 0,
        position: Offset = .zero,
        obscured: Bool = false,
        pressureMin: Double = 1.0,
        pressureMax: Double = 1.0,
        distance: Double = 0.0,
        distanceMax: Double = 0.0,
        radiusMin: Double = 0.0,
        radiusMax: Double = 0.0,
        orientation: Double = 0.0,
        tilt: Double = 0.0,
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
            obscured: obscured,
            pressure: 0.0,
            pressureMin: pressureMin,
            pressureMax: pressureMax,
            distance: distance,
            distanceMax: distanceMax,
            radiusMin: radiusMin,
            radiusMax: radiusMax,
            orientation: orientation,
            tilt: tilt
        )
    }

    /// Internal initializer used by `TransformedPointerAddedEvent` to pass
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
    /// Otherwise, creates a `TransformedPointerAddedEvent`.
    ///
    /// **Dart Source:** `events.dart:916-922`
    open override func transformed(_ transform: Matrix4?) -> PointerAddedEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerAddedEvent) ?? self
        return TransformedPointerAddedEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:844-888`
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
    ) -> PointerAddedEvent {
        return PointerAddedEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            obscured: obscured ?? self.obscured,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
            distance: distance ?? self.distance,
            distanceMax: distanceMax ?? self.distanceMax,
            radiusMin: radiusMin ?? self.radiusMin,
            radiusMax: radiusMax ?? self.radiusMax,
            orientation: orientation ?? self.orientation,
            tilt: tilt ?? self.tilt,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerAddedEvent

/// Internal transformed variant of `PointerAddedEvent`.
///
/// In Dart, this class extends `_TransformedPointerEvent` and implements
/// `PointerAddedEvent`. Since Swift does not support multiple class inheritance,
/// this class extends `PointerAddedEvent` directly and overrides `localPosition`
/// and `localDelta` with lazily computed transformed values (mirroring the
/// behavior of `_TransformedPointerEvent`).
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 925-938
internal class TransformedPointerAddedEvent: PointerAddedEvent {

    /// Creates a transformed pointer added event.
    internal init(original: PointerAddedEvent, transform: Matrix4) {
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

    /// The original un-transformed `PointerAddedEvent`.
    private let _typedOriginal: PointerAddedEvent

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
    /// **Dart Source:** `events.dart:937`
    open override func transformed(_ transform: Matrix4?) -> PointerAddedEvent {
        return _typedOriginal.transformed(transform)
    }

    /// Creates a copy of this event with the specified properties replaced,
    /// delegating to the `PointerAddedEvent.copyWith` behavior.
    ///
    /// **Dart Source:** `events.dart:844-888` (via _CopyPointerAddedEvent mixin)
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
    ) -> PointerAddedEvent {
        return PointerAddedEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            obscured: obscured ?? self.obscured,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
            distance: distance ?? self.distance,
            distanceMax: distanceMax ?? self.distanceMax,
            radiusMin: radiusMin ?? self.radiusMin,
            radiusMax: radiusMax ?? self.radiusMax,
            orientation: orientation ?? self.orientation,
            tilt: tilt ?? self.tilt,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - PointerRemovedEvent

/// The device is no longer tracking the pointer.
///
/// For example, the pointer might have drifted out of the device's hover
/// detection range or might have been disconnected from the system entirely.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 988-1015
open class PointerRemovedEvent: PointerEvent {

    /// Creates a pointer removed event.
    ///
    /// All positional arguments default to appropriate zero/identity values.
    /// The pressure is always set to 0.0 for removed events.
    public init(
        viewId: Int = 0,
        timeStamp: Duration = .zero,
        pointer: Int = 0,
        kind: PointerDeviceKind = .touch,
        device: Int = 0,
        position: Offset = .zero,
        obscured: Bool = false,
        pressureMin: Double = 1.0,
        pressureMax: Double = 1.0,
        distanceMax: Double = 0.0,
        radiusMin: Double = 0.0,
        radiusMax: Double = 0.0,
        original: PointerRemovedEvent? = nil,
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
            obscured: obscured,
            pressure: 0.0,
            pressureMin: pressureMin,
            pressureMax: pressureMax,
            distanceMax: distanceMax,
            radiusMin: radiusMin,
            radiusMax: radiusMax,
            original: original
        )
    }

    /// Internal initializer used by `TransformedPointerRemovedEvent` to pass
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

    /// Transforms this event into the coordinate space described by `transform`.
    ///
    /// If `transform` is nil or equal to the current transform, returns self.
    /// Otherwise, creates a `TransformedPointerRemovedEvent`.
    ///
    /// **Dart Source:** `events.dart:1008-1014`
    open override func transformed(_ transform: Matrix4?) -> PointerRemovedEvent {
        if transform == nil || transform == self.transform {
            return self
        }
        let orig = (original as? PointerRemovedEvent) ?? self
        return TransformedPointerRemovedEvent(original: orig, transform: transform!)
    }

    /// Creates a copy of this event with the specified properties replaced.
    ///
    /// The returned event will be transformed with the current transform.
    ///
    /// **Dart Source:** `events.dart:940-981`
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
    ) -> PointerRemovedEvent {
        return PointerRemovedEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            obscured: obscured ?? self.obscured,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
            distanceMax: distanceMax ?? self.distanceMax,
            radiusMin: radiusMin ?? self.radiusMin,
            radiusMax: radiusMax ?? self.radiusMax,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

// MARK: - TransformedPointerRemovedEvent

/// Internal transformed variant of `PointerRemovedEvent`.
///
/// In Dart, this class extends `_TransformedPointerEvent` and implements
/// `PointerRemovedEvent`. Since Swift does not support multiple class inheritance,
/// this class extends `PointerRemovedEvent` directly and overrides `localPosition`
/// and `localDelta` with lazily computed transformed values (mirroring the
/// behavior of `_TransformedPointerEvent`).
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 1017-1030
internal class TransformedPointerRemovedEvent: PointerRemovedEvent {

    /// Creates a transformed pointer removed event.
    internal init(original: PointerRemovedEvent, transform: Matrix4) {
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

    /// The original un-transformed `PointerRemovedEvent`.
    private let _typedOriginal: PointerRemovedEvent

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
    /// **Dart Source:** `events.dart:1029`
    open override func transformed(_ transform: Matrix4?) -> PointerRemovedEvent {
        return _typedOriginal.transformed(transform)
    }

    /// Creates a copy of this event with the specified properties replaced,
    /// delegating to the `PointerRemovedEvent.copyWith` behavior.
    ///
    /// **Dart Source:** `events.dart:940-981` (via _CopyPointerRemovedEvent mixin)
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
    ) -> PointerRemovedEvent {
        return PointerRemovedEvent(
            viewId: viewId ?? self.viewId,
            timeStamp: timeStamp ?? self.timeStamp,
            kind: kind ?? self.kind,
            device: device ?? self.device,
            position: position ?? self.position,
            obscured: obscured ?? self.obscured,
            pressureMin: pressureMin ?? self.pressureMin,
            pressureMax: pressureMax ?? self.pressureMax,
            distanceMax: distanceMax ?? self.distanceMax,
            radiusMin: radiusMin ?? self.radiusMin,
            radiusMax: radiusMax ?? self.radiusMax,
            embedderId: embedderId ?? self.embedderId
        ).transformed(transform)
    }
}

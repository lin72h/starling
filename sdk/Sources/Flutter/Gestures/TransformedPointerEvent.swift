// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

/// Internal base class for transformed pointer events.
///
/// A `TransformedPointerEvent` stores an original event and the transform
/// matrix. It defers all field getters to the original event, except for
/// `localPosition` and `localDelta`, which are calculated when first used.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/events.dart`
/// **Lines:** 746-842
open class TransformedPointerEvent: PointerEvent {

    // MARK: - Initializer

    /// Creates a transformed pointer event from the given original event and transform.
    internal init(original: PointerEvent, transform: Matrix4) {
        self._original = original
        self._transform = transform
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

    // MARK: - Stored Properties

    /// The original un-transformed event.
    private let _original: PointerEvent

    /// The transformation matrix applied to this event.
    private let _transform: Matrix4

    // MARK: - Lazy Computed Properties

    /// The position transformed into the local coordinate system, computed lazily.
    ///
    /// **Dart Source:** `events.dart:830`
    private lazy var _localPosition: Offset = PointerEvent.transformPosition(
        _transform,
        position
    )

    /// The delta transformed into the local coordinate system, computed lazily.
    ///
    /// **Dart Source:** `events.dart:833-838`
    private lazy var _localDelta: Offset = PointerEvent.transformDeltaViaPositions(
        untransformedEndPosition: position,
        transformedEndPosition: _localPosition,
        untransformedDelta: delta,
        transform: _transform
    )

    // MARK: - Overrides

    /// The position in the local coordinate system of the event receiver.
    open override var localPosition: Offset { _localPosition }

    /// The delta in the local coordinate system of the event receiver.
    open override var localDelta: Offset { _localDelta }
}

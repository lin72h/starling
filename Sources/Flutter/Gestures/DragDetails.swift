// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Detail types and callback signatures for drag gesture recognition.
///
/// Each detail struct provides positional and motion information for a
/// particular phase of a drag gesture (down, start, update, end).
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/drag_details.dart`

import FlutterSwiftBridge

// MARK: - DragDownDetails

/// Details object for callbacks that use ``GestureDragDownCallback``.
///
/// See also:
///
///  - ``DragStartDetails``, the details for ``GestureDragStartCallback``.
///  - ``DragUpdateDetails``, the details for ``GestureDragUpdateCallback``.
///  - ``DragEndDetails``, the details for ``GestureDragEndCallback``.
///
/// **Dart Source:** `drag_details.dart:25-44`
public struct DragDownDetails: PositionedGestureDetails, CustomStringConvertible {

    /// Creates details for a ``GestureDragDownCallback``.
    ///
    /// **Dart Source:** `drag_details.dart:27-28`
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `drag_details.dart:32`
    public let globalPosition: Offset

    /// The local position in the coordinate system of the event receiver at
    /// which the pointer contacted the screen.
    ///
    /// **Dart Source:** `drag_details.dart:36`
    public let localPosition: Offset

    // MARK: CustomStringConvertible

    public var description: String {
        "DragDownDetails(globalPosition: \(globalPosition), localPosition: \(localPosition))"
    }
}

// MARK: - GestureDragDownCallback

/// Signature for when a pointer has contacted the screen and might begin to
/// move.
///
/// The `details` object provides the position of the touch.
///
/// **Dart Source:** `drag_details.dart:52`
public typealias GestureDragDownCallback = (DragDownDetails) -> Void

// MARK: - DragStartDetails

/// Details object for callbacks that use ``GestureDragStartCallback``.
///
/// See also:
///
///  - ``DragDownDetails``, the details for ``GestureDragDownCallback``.
///  - ``DragUpdateDetails``, the details for ``GestureDragUpdateCallback``.
///  - ``DragEndDetails``, the details for ``GestureDragEndCallback``.
///
/// **Dart Source:** `drag_details.dart:62-96`
public struct DragStartDetails: PositionedGestureDetails, CustomStringConvertible {

    /// Creates details for a ``GestureDragStartCallback``.
    ///
    /// **Dart Source:** `drag_details.dart:64-69`
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil,
        sourceTimeStamp: Duration? = nil,
        kind: PointerDeviceKind? = nil
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.sourceTimeStamp = sourceTimeStamp
        self.kind = kind
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `drag_details.dart:73`
    public let globalPosition: Offset

    /// The local position in the coordinate system of the event receiver at
    /// which the pointer contacted the screen.
    ///
    /// **Dart Source:** `drag_details.dart:77`
    public let localPosition: Offset

    /// Recorded timestamp of the source pointer event that triggered the drag
    /// event.
    ///
    /// Could be nil if triggered from proxied events such as accessibility.
    ///
    /// **Dart Source:** `drag_details.dart:83`
    public let sourceTimeStamp: Duration?

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** `drag_details.dart:86`
    public let kind: PointerDeviceKind?

    // MARK: CustomStringConvertible

    public var description: String {
        "DragStartDetails(globalPosition: \(globalPosition), localPosition: \(localPosition), sourceTimeStamp: \(String(describing: sourceTimeStamp)), kind: \(String(describing: kind)))"
    }
}

// MARK: - GestureDragStartCallback

/// Signature for when a pointer has contacted the screen and has begun to move.
///
/// The `details` object provides the position of the touch when it first
/// touched the surface.
///
/// **Dart Source:** `drag_details.dart:106`
public typealias GestureDragStartCallback = (DragStartDetails) -> Void

// MARK: - DragUpdateDetails

/// Details object for callbacks that use ``GestureDragUpdateCallback``.
///
/// See also:
///
///  - ``DragDownDetails``, the details for ``GestureDragDownCallback``.
///  - ``DragStartDetails``, the details for ``GestureDragStartCallback``.
///  - ``DragEndDetails``, the details for ``GestureDragEndCallback``.
///
/// **Dart Source:** `drag_details.dart:116-184`
public struct DragUpdateDetails: PositionedGestureDetails, CustomStringConvertible {

    /// Creates details for a ``GestureDragUpdateCallback``.
    ///
    /// If `primaryDelta` is non-nil, then its value must match one of the
    /// coordinates of `delta` and the other coordinate must be zero.
    ///
    /// **Dart Source:** `drag_details.dart:121-133`
    public init(
        globalPosition: Offset,
        localPosition: Offset? = nil,
        sourceTimeStamp: Duration? = nil,
        delta: Offset = .zero,
        primaryDelta: Double? = nil,
        kind: PointerDeviceKind? = nil
    ) {
        assert(
            primaryDelta == nil
                || (primaryDelta == delta.dx && delta.dy == 0.0)
                || (primaryDelta == delta.dy && delta.dx == 0.0),
            "primaryDelta must match one component of delta with the other being zero"
        )
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.sourceTimeStamp = sourceTimeStamp
        self.delta = delta
        self.primaryDelta = primaryDelta
        self.kind = kind
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `drag_details.dart:137`
    public let globalPosition: Offset

    /// The local position in the coordinate system of the event receiver at
    /// which the pointer contacted the screen.
    ///
    /// **Dart Source:** `drag_details.dart:141`
    public let localPosition: Offset

    /// Recorded timestamp of the source pointer event that triggered the drag
    /// event.
    ///
    /// Could be nil if triggered from proxied events such as accessibility.
    ///
    /// **Dart Source:** `drag_details.dart:147`
    public let sourceTimeStamp: Duration?

    /// The amount the pointer has moved in the coordinate space of the event
    /// receiver since the previous update.
    ///
    /// If the ``GestureDragUpdateCallback`` is for a one-dimensional drag (e.g.,
    /// a horizontal or vertical drag), then this offset contains only the delta
    /// in that direction (i.e., the coordinate in the other direction is zero).
    ///
    /// Defaults to zero if not specified in the constructor.
    ///
    /// **Dart Source:** `drag_details.dart:157`
    public let delta: Offset

    /// The amount the pointer has moved along the primary axis in the coordinate
    /// space of the event receiver since the previous update.
    ///
    /// If the ``GestureDragUpdateCallback`` is for a one-dimensional drag (e.g.,
    /// a horizontal or vertical drag), then this value contains the component of
    /// ``delta`` along the primary axis (e.g., horizontal or vertical,
    /// respectively). Otherwise, if the ``GestureDragUpdateCallback`` is for a
    /// two-dimensional drag (e.g., a pan), then this value is nil.
    ///
    /// Defaults to nil if not specified in the constructor.
    ///
    /// **Dart Source:** `drag_details.dart:170`
    public let primaryDelta: Double?

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** `drag_details.dart:173`
    public let kind: PointerDeviceKind?

    // MARK: CustomStringConvertible

    public var description: String {
        "DragUpdateDetails(globalPosition: \(globalPosition), localPosition: \(localPosition), sourceTimeStamp: \(String(describing: sourceTimeStamp)), delta: \(delta), primaryDelta: \(String(describing: primaryDelta)))"
    }
}

// MARK: - GestureDragUpdateCallback

/// Signature for when a pointer that is in contact with the screen and moving
/// has moved again.
///
/// The `details` object provides the position of the touch and the distance it
/// has traveled since the last update.
///
/// **Dart Source:** `drag_details.dart:195`
public typealias GestureDragUpdateCallback = (DragUpdateDetails) -> Void

// MARK: - DragEndDetails

/// Details object for callbacks that use ``GestureDragEndCallback``.
///
/// See also:
///
///  - ``DragDownDetails``, the details for ``GestureDragDownCallback``.
///  - ``DragStartDetails``, the details for ``GestureDragStartCallback``.
///  - ``DragUpdateDetails``, the details for ``GestureDragUpdateCallback``.
///
/// **Dart Source:** `drag_details.dart:205-256`
public struct DragEndDetails: PositionedGestureDetails, CustomStringConvertible {

    /// Creates details for a ``GestureDragEndCallback``.
    ///
    /// If `primaryVelocity` is non-nil, its value must match one of the
    /// coordinates of `velocity.pixelsPerSecond` and the other coordinate
    /// must be zero.
    ///
    /// **Dart Source:** `drag_details.dart:211-221`
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil,
        velocity: Velocity = .zero,
        primaryVelocity: Double? = nil
    ) {
        assert(
            primaryVelocity == nil
                || (primaryVelocity == velocity.pixelsPerSecond.dx && velocity.pixelsPerSecond.dy == 0)
                || (primaryVelocity == velocity.pixelsPerSecond.dy && velocity.pixelsPerSecond.dx == 0),
            "primaryVelocity must match one component of velocity.pixelsPerSecond with the other being zero"
        )
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.velocity = velocity
        self.primaryVelocity = primaryVelocity
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `drag_details.dart:225`
    public let globalPosition: Offset

    /// The local position in the coordinate system of the event receiver at
    /// which the pointer contacted the screen.
    ///
    /// **Dart Source:** `drag_details.dart:229`
    public let localPosition: Offset

    /// The velocity the pointer was moving when it stopped contacting the screen.
    ///
    /// Defaults to zero if not specified in the constructor.
    ///
    /// **Dart Source:** `drag_details.dart:234`
    public let velocity: Velocity

    /// The velocity the pointer was moving along the primary axis when it stopped
    /// contacting the screen, in logical pixels per second.
    ///
    /// If the ``GestureDragEndCallback`` is for a one-dimensional drag (e.g., a
    /// horizontal or vertical drag), then this value contains the component of
    /// ``velocity`` along the primary axis (e.g., horizontal or vertical,
    /// respectively). Otherwise, if the ``GestureDragEndCallback`` is for a
    /// two-dimensional drag (e.g., a pan), then this value is nil.
    ///
    /// Defaults to nil if not specified in the constructor.
    ///
    /// **Dart Source:** `drag_details.dart:246`
    public let primaryVelocity: Double?

    // MARK: CustomStringConvertible

    public var description: String {
        "DragEndDetails(globalPosition: \(globalPosition), localPosition: \(localPosition), velocity: \(velocity), primaryVelocity: \(String(describing: primaryVelocity)))"
    }
}

// MARK: - GestureDragEndCallback

/// Signature for when a pointer that was previously in contact with the screen
/// and moving is no longer in contact with the screen.
///
/// The velocity at which the pointer was moving when it stopped contacting
/// the screen is available in the `details`.
///
/// **Dart Source:** `drag_details.dart` (implicit from usage patterns)
public typealias GestureDragEndCallback = (DragEndDetails) -> Void

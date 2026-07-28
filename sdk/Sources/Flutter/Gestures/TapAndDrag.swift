// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tap-and-drag gesture recognizers: `BaseTapAndDragGestureRecognizer` (base),
/// `TapAndHorizontalDragGestureRecognizer`, and `TapAndPanGestureRecognizer`.
///
/// These recognizers combine tap and drag recognition into a single gesture
/// recognizer, tracking consecutive taps and transitioning between tap and
/// drag states.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/tap_and_drag.dart`
/// **Lines:** 1-1486
///
/// NOTE: `TapAndDragGestureRecognizer` (lines 1458-1486) was deprecated in
/// Dart and is NOT migrated. Use `TapAndPanGestureRecognizer` instead.

import FlutterSwiftBridge
import Foundation

// MARK: - Private Helpers

/// Returns the sign of a double value as a double (-1.0, 0.0, or 1.0).
///
/// Equivalent to Dart's `num.sign` getter.
///
/// DIFFERENCE FROM DART: Swift's `Double.sign` returns `FloatingPointSign` (an
/// enum), not a numeric value. This helper function replicates the Dart behavior.
private func _signOf(_ value: Double) -> Double {
    if value > 0.0 { return 1.0 }
    if value < 0.0 { return -1.0 }
    return 0.0
}

/// Computes the global distance between an event's position and an origin.
///
/// **Dart Source:** tap_and_drag.dart:26-30
private func _getGlobalDistance(_ event: PointerEvent, _ originPosition: OffsetPair?) -> Double {
    assert(originPosition != nil)
    let offset = event.position - originPosition!.global
    return offset.distance
}

// MARK: - TapDragState

/// The possible states of a `BaseTapAndDragGestureRecognizer`.
///
/// The recognizer advances from `ready` to `possible` when it starts tracking
/// a pointer. Where it advances from there depends on the sequence of pointer
/// events that is tracked by the recognizer.
///
/// **Dart Source:** tap_and_drag.dart:52-62
private enum TapDragState {
    /// The recognizer is ready to start recognizing a drag.
    case ready

    /// The sequence of pointer events seen thus far is consistent with a drag but
    /// it has not been accepted definitively.
    case possible

    /// The sequence of pointer events has been accepted definitively as a drag.
    case accepted
}

// MARK: - Callback Typealiases

/// Callback for when a pointer that might cause a tap has contacted the screen.
///
/// The consecutive tap count at the time the pointer contacted the
/// screen is given by `TapDragDownDetails.consecutiveTapCount`.
///
/// Used by `BaseTapAndDragGestureRecognizer.onTapDown`.
///
/// **Dart Source:** tap_and_drag.dart:70
public typealias GestureTapDragDownCallback = (_ details: TapDragDownDetails) -> Void

/// Callback for when a pointer that will trigger a tap has stopped contacting
/// the screen.
///
/// The consecutive tap count at the time the pointer contacted the
/// screen is given by `TapDragUpDetails.consecutiveTapCount`.
///
/// Used by `BaseTapAndDragGestureRecognizer.onTapUp`.
///
/// **Dart Source:** tap_and_drag.dart:123
public typealias GestureTapDragUpCallback = (_ details: TapDragUpDetails) -> Void

/// Callback for when a drag gesture has started.
///
/// The consecutive tap count at the time the pointer contacted the
/// screen is given by `TapDragStartDetails.consecutiveTapCount`.
///
/// Used by `BaseTapAndDragGestureRecognizer.onDragStart`.
///
/// **Dart Source:** tap_and_drag.dart:176
public typealias GestureTapDragStartCallback = (_ details: TapDragStartDetails) -> Void

/// Callback for when a drag gesture has updated.
///
/// The consecutive tap count at the time the pointer contacted the
/// screen is given by `TapDragUpdateDetails.consecutiveTapCount`.
///
/// Used by `BaseTapAndDragGestureRecognizer.onDragUpdate`.
///
/// **Dart Source:** tap_and_drag.dart:237
public typealias GestureTapDragUpdateCallback = (_ details: TapDragUpdateDetails) -> Void

/// Callback for when a drag gesture has ended.
///
/// The consecutive tap count at the time the pointer contacted the
/// screen is given by `TapDragEndDetails.consecutiveTapCount`.
///
/// Used by `BaseTapAndDragGestureRecognizer.onDragEnd`.
///
/// **Dart Source:** tap_and_drag.dart:352
public typealias GestureTapDragEndCallback = (_ endDetails: TapDragEndDetails) -> Void

/// Signature for when the pointer that previously triggered a
/// `GestureTapDragDownCallback` did not complete.
///
/// Used by `BaseTapAndDragGestureRecognizer.onCancel`.
///
/// **Dart Source:** tap_and_drag.dart:424
public typealias GestureCancelCallback = () -> Void

// MARK: - TapDragDownDetails

/// Details for `GestureTapDragDownCallback`, such as the number of
/// consecutive taps.
///
/// See also:
///
///  * `BaseTapAndDragGestureRecognizer`, which passes this information to its
///    `BaseTapAndDragGestureRecognizer.onTapDown` callback.
///  * `TapDragUpDetails`, the details for `GestureTapDragUpCallback`.
///  * `TapDragStartDetails`, the details for `GestureTapDragStartCallback`.
///  * `TapDragUpdateDetails`, the details for `GestureTapDragUpdateCallback`.
///  * `TapDragEndDetails`, the details for `GestureTapDragEndCallback`.
///
/// **Dart Source:** tap_and_drag.dart:83-115
///
/// DIFFERENCE FROM DART: In Dart, this uses `with Diagnosticable implements
/// PositionedGestureDetails`. In Swift, it conforms to both `Diagnosticable`
/// and `PositionedGestureDetails` protocols. Implemented as a class (reference
/// type) to conform to `Diagnosticable` (which requires `AnyObject`).
public class TapDragDownDetails: Diagnosticable, PositionedGestureDetails {

    /// Creates details for a `GestureTapDragDownCallback`.
    ///
    /// **Dart Source:** tap_and_drag.dart:85-90
    public init(
        globalPosition: Offset,
        localPosition: Offset,
        kind: PointerDeviceKind? = nil,
        consecutiveTapCount: Int
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition
        self.kind = kind
        self.consecutiveTapCount = consecutiveTapCount
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:94
    public let globalPosition: Offset

    /// The local position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:98
    public let localPosition: Offset

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** tap_and_drag.dart:101
    public let kind: PointerDeviceKind?

    /// If this tap is in a series of taps, then this value represents
    /// the number in the series this tap is.
    ///
    /// **Dart Source:** tap_and_drag.dart:105
    public let consecutiveTapCount: Int

    // MARK: - Diagnosticable

    /// **Dart Source:** tap_and_drag.dart:108-114
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(DiagnosticsProperty<Offset>("globalPosition", globalPosition))
        properties.add(DiagnosticsProperty<Offset>("localPosition", localPosition))
        if let kind = kind {
            properties.add(DiagnosticsProperty<String>("kind", "\(kind)"))
        }
        properties.add(IntProperty("consecutiveTapCount", consecutiveTapCount))
    }
}

// MARK: - TapDragUpDetails

/// Details for `GestureTapDragUpCallback`, such as the number of
/// consecutive taps.
///
/// See also:
///
///  * `BaseTapAndDragGestureRecognizer`, which passes this information to its
///    `BaseTapAndDragGestureRecognizer.onTapUp` callback.
///  * `TapDragDownDetails`, the details for `GestureTapDragDownCallback`.
///  * `TapDragStartDetails`, the details for `GestureTapDragStartCallback`.
///  * `TapDragUpdateDetails`, the details for `GestureTapDragUpdateCallback`.
///  * `TapDragEndDetails`, the details for `GestureTapDragEndCallback`.
///
/// **Dart Source:** tap_and_drag.dart:136-168
///
/// DIFFERENCE FROM DART: In Dart, this uses `with Diagnosticable implements
/// PositionedGestureDetails`. In Swift, it conforms to both `Diagnosticable`
/// and `PositionedGestureDetails` protocols. Implemented as a class (reference
/// type) to conform to `Diagnosticable` (which requires `AnyObject`).
public class TapDragUpDetails: Diagnosticable, PositionedGestureDetails {

    /// Creates details for a `GestureTapDragUpCallback`.
    ///
    /// **Dart Source:** tap_and_drag.dart:138-143
    public init(
        globalPosition: Offset,
        localPosition: Offset,
        kind: PointerDeviceKind,
        consecutiveTapCount: Int
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition
        self.kind = kind
        self.consecutiveTapCount = consecutiveTapCount
    }

    /// The global position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:146
    public let globalPosition: Offset

    /// The local position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:150
    public let localPosition: Offset

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** tap_and_drag.dart:154
    public let kind: PointerDeviceKind

    /// If this tap is in a series of taps, then this value represents
    /// the number in the series this tap is.
    ///
    /// **Dart Source:** tap_and_drag.dart:158
    public let consecutiveTapCount: Int

    // MARK: - Diagnosticable

    /// **Dart Source:** tap_and_drag.dart:161-167
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(DiagnosticsProperty<Offset>("globalPosition", globalPosition))
        properties.add(DiagnosticsProperty<Offset>("localPosition", localPosition))
        properties.add(DiagnosticsProperty<String>("kind", "\(kind)"))
        properties.add(IntProperty("consecutiveTapCount", consecutiveTapCount))
    }
}

// MARK: - TapDragStartDetails

/// Details for `GestureTapDragStartCallback`, such as the number of
/// consecutive taps.
///
/// See also:
///
///  * `BaseTapAndDragGestureRecognizer`, which passes this information to its
///    `BaseTapAndDragGestureRecognizer.onDragStart` callback.
///  * `TapDragDownDetails`, the details for `GestureTapDragDownCallback`.
///  * `TapDragUpDetails`, the details for `GestureTapDragUpCallback`.
///  * `TapDragUpdateDetails`, the details for `GestureTapDragUpdateCallback`.
///  * `TapDragEndDetails`, the details for `GestureTapDragEndCallback`.
///
/// **Dart Source:** tap_and_drag.dart:189-229
///
/// DIFFERENCE FROM DART: In Dart, this uses `with Diagnosticable implements
/// PositionedGestureDetails`. In Swift, it conforms to both `Diagnosticable`
/// and `PositionedGestureDetails` protocols. Implemented as a class (reference
/// type) to conform to `Diagnosticable` (which requires `AnyObject`).
public class TapDragStartDetails: Diagnosticable, PositionedGestureDetails {

    /// Creates details for a `GestureTapDragStartCallback`.
    ///
    /// **Dart Source:** tap_and_drag.dart:191-197
    public init(
        globalPosition: Offset,
        localPosition: Offset,
        sourceTimeStamp: Duration? = nil,
        kind: PointerDeviceKind? = nil,
        consecutiveTapCount: Int
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition
        self.sourceTimeStamp = sourceTimeStamp
        self.kind = kind
        self.consecutiveTapCount = consecutiveTapCount
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:200
    public let globalPosition: Offset

    /// The local position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:204
    public let localPosition: Offset

    /// Recorded timestamp of the source pointer event that triggered the drag
    /// event.
    ///
    /// Could be nil if triggered from proxied events such as accessibility.
    ///
    /// **Dart Source:** tap_and_drag.dart:211
    public let sourceTimeStamp: Duration?

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** tap_and_drag.dart:214
    public let kind: PointerDeviceKind?

    /// If this tap is in a series of taps, then this value represents
    /// the number in the series this tap is.
    ///
    /// **Dart Source:** tap_and_drag.dart:218
    public let consecutiveTapCount: Int

    // MARK: - Diagnosticable

    /// **Dart Source:** tap_and_drag.dart:221-228
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(DiagnosticsProperty<Offset>("globalPosition", globalPosition))
        properties.add(DiagnosticsProperty<Offset>("localPosition", localPosition))
        if let sourceTimeStamp = sourceTimeStamp {
            properties.add(DiagnosticsProperty<String>("sourceTimeStamp", "\(sourceTimeStamp)"))
        }
        if let kind = kind {
            properties.add(DiagnosticsProperty<String>("kind", "\(kind)"))
        }
        properties.add(IntProperty("consecutiveTapCount", consecutiveTapCount))
    }
}

// MARK: - TapDragUpdateDetails

/// Details for `GestureTapDragUpdateCallback`, such as the number of
/// consecutive taps.
///
/// See also:
///
///  * `BaseTapAndDragGestureRecognizer`, which passes this information to its
///    `BaseTapAndDragGestureRecognizer.onDragUpdate` callback.
///  * `TapDragDownDetails`, the details for `GestureTapDragDownCallback`.
///  * `TapDragUpDetails`, the details for `GestureTapDragUpCallback`.
///  * `TapDragStartDetails`, the details for `GestureTapDragStartCallback`.
///  * `TapDragEndDetails`, the details for `GestureTapDragEndCallback`.
///
/// **Dart Source:** tap_and_drag.dart:250-344
///
/// DIFFERENCE FROM DART: In Dart, this uses `with Diagnosticable implements
/// PositionedGestureDetails`. In Swift, it conforms to both `Diagnosticable`
/// and `PositionedGestureDetails` protocols. Implemented as a class (reference
/// type) to conform to `Diagnosticable` (which requires `AnyObject`).
public class TapDragUpdateDetails: Diagnosticable, PositionedGestureDetails {

    /// Creates details for a `GestureTapDragUpdateCallback`.
    ///
    /// If `primaryDelta` is non-nil, then its value must match one of the
    /// coordinates of `delta` and the other coordinate must be zero.
    ///
    /// **Dart Source:** tap_and_drag.dart:255-269
    public init(
        globalPosition: Offset,
        localPosition: Offset,
        sourceTimeStamp: Duration? = nil,
        delta: Offset = .zero,
        primaryDelta: Double? = nil,
        kind: PointerDeviceKind? = nil,
        offsetFromOrigin: Offset,
        localOffsetFromOrigin: Offset,
        consecutiveTapCount: Int
    ) {
        assert(
            primaryDelta == nil
                || (primaryDelta == delta.dx && delta.dy == 0.0)
                || (primaryDelta == delta.dy && delta.dx == 0.0)
        )
        self.globalPosition = globalPosition
        self.localPosition = localPosition
        self.sourceTimeStamp = sourceTimeStamp
        self.delta = delta
        self.primaryDelta = primaryDelta
        self.kind = kind
        self.offsetFromOrigin = offsetFromOrigin
        self.localOffsetFromOrigin = localOffsetFromOrigin
        self.consecutiveTapCount = consecutiveTapCount
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:272
    public let globalPosition: Offset

    /// The local position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:276
    public let localPosition: Offset

    /// Recorded timestamp of the source pointer event that triggered the drag
    /// event.
    ///
    /// Could be nil if triggered from proxied events such as accessibility.
    ///
    /// **Dart Source:** tap_and_drag.dart:283
    public let sourceTimeStamp: Duration?

    /// The amount the pointer has moved in the coordinate space of the event
    /// receiver since the previous update.
    ///
    /// If the `GestureTapDragUpdateCallback` is for a one-dimensional drag (e.g.,
    /// a horizontal or vertical drag), then this offset contains only the delta
    /// in that direction (i.e., the coordinate in the other direction is zero).
    ///
    /// Defaults to zero if not specified in the constructor.
    ///
    /// **Dart Source:** tap_and_drag.dart:293
    public let delta: Offset

    /// The amount the pointer has moved along the primary axis in the coordinate
    /// space of the event receiver since the previous update.
    ///
    /// If the `GestureTapDragUpdateCallback` is for a one-dimensional drag (e.g.,
    /// a horizontal or vertical drag), then this value contains the component of
    /// `delta` along the primary axis (e.g., horizontal or vertical,
    /// respectively). Otherwise, if the `GestureTapDragUpdateCallback` is for a
    /// two-dimensional drag (e.g., a pan), then this value is nil.
    ///
    /// Defaults to nil if not specified in the constructor.
    ///
    /// **Dart Source:** tap_and_drag.dart:306
    public let primaryDelta: Double?

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** tap_and_drag.dart:309
    public let kind: PointerDeviceKind?

    /// A delta offset from the point where the drag initially contacted
    /// the screen to the point where the pointer is currently located in global
    /// coordinates (the present `globalPosition`) when this callback is triggered.
    ///
    /// When considering a `GestureRecognizer` that tracks the number of consecutive taps,
    /// this offset is associated with the most recent `PointerDownEvent` that occurred.
    ///
    /// **Dart Source:** tap_and_drag.dart:317
    public let offsetFromOrigin: Offset

    /// A local delta offset from the point where the drag initially contacted
    /// the screen to the point where the pointer is currently located in local
    /// coordinates (the present `localPosition`) when this callback is triggered.
    ///
    /// When considering a `GestureRecognizer` that tracks the number of consecutive taps,
    /// this offset is associated with the most recent `PointerDownEvent` that occurred.
    ///
    /// **Dart Source:** tap_and_drag.dart:325
    public let localOffsetFromOrigin: Offset

    /// If this tap is in a series of taps, then this value represents
    /// the number in the series this tap is.
    ///
    /// **Dart Source:** tap_and_drag.dart:329
    public let consecutiveTapCount: Int

    // MARK: - Diagnosticable

    /// **Dart Source:** tap_and_drag.dart:332-343
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(DiagnosticsProperty<Offset>("globalPosition", globalPosition))
        properties.add(DiagnosticsProperty<Offset>("localPosition", localPosition))
        if let sourceTimeStamp = sourceTimeStamp {
            properties.add(DiagnosticsProperty<String>("sourceTimeStamp", "\(sourceTimeStamp)"))
        }
        properties.add(DiagnosticsProperty<Offset>("delta", delta))
        if let primaryDelta = primaryDelta {
            properties.add(DiagnosticsProperty<String>("primaryDelta", "\(primaryDelta)"))
        }
        if let kind = kind {
            properties.add(DiagnosticsProperty<String>("kind", "\(kind)"))
        }
        properties.add(DiagnosticsProperty<Offset>("offsetFromOrigin", offsetFromOrigin))
        properties.add(DiagnosticsProperty<Offset>("localOffsetFromOrigin", localOffsetFromOrigin))
        properties.add(IntProperty("consecutiveTapCount", consecutiveTapCount))
    }
}

// MARK: - TapDragEndDetails

/// Details for `GestureTapDragEndCallback`, such as the number of
/// consecutive taps.
///
/// See also:
///
///  * `BaseTapAndDragGestureRecognizer`, which passes this information to its
///    `BaseTapAndDragGestureRecognizer.onDragEnd` callback.
///  * `TapDragDownDetails`, the details for `GestureTapDragDownCallback`.
///  * `TapDragUpDetails`, the details for `GestureTapDragUpCallback`.
///  * `TapDragStartDetails`, the details for `GestureTapDragStartCallback`.
///  * `TapDragUpdateDetails`, the details for `GestureTapDragUpdateCallback`.
///
/// **Dart Source:** tap_and_drag.dart:365-418
///
/// DIFFERENCE FROM DART: In Dart, this uses `with Diagnosticable implements
/// PositionedGestureDetails`. In Swift, it conforms to both `Diagnosticable`
/// and `PositionedGestureDetails` protocols. Implemented as a class (reference
/// type) to conform to `Diagnosticable` (which requires `AnyObject`).
public class TapDragEndDetails: Diagnosticable, PositionedGestureDetails {

    /// Creates details for a `GestureTapDragEndCallback`.
    ///
    /// **Dart Source:** tap_and_drag.dart:367-378
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil,
        velocity: Velocity = .zero,
        primaryVelocity: Double? = nil,
        consecutiveTapCount: Int
    ) {
        assert(
            primaryVelocity == nil
                || primaryVelocity == velocity.pixelsPerSecond.dx
                || primaryVelocity == velocity.pixelsPerSecond.dy
        )
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.velocity = velocity
        self.primaryVelocity = primaryVelocity
        self.consecutiveTapCount = consecutiveTapCount
    }

    /// The global position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:381
    public let globalPosition: Offset

    /// The local position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:386
    public let localPosition: Offset

    /// The velocity the pointer was moving when it stopped contacting the screen.
    ///
    /// Defaults to zero if not specified in the constructor.
    ///
    /// **Dart Source:** tap_and_drag.dart:391
    public let velocity: Velocity

    /// The velocity the pointer was moving along the primary axis when it stopped
    /// contacting the screen, in logical pixels per second.
    ///
    /// If the `GestureTapDragEndCallback` is for a one-dimensional drag (e.g., a
    /// horizontal or vertical drag), then this value contains the component of
    /// `velocity` along the primary axis (e.g., horizontal or vertical,
    /// respectively). Otherwise, if the `GestureTapDragEndCallback` is for a
    /// two-dimensional drag (e.g., a pan), then this value is nil.
    ///
    /// Defaults to nil if not specified in the constructor.
    ///
    /// **Dart Source:** tap_and_drag.dart:403
    public let primaryVelocity: Double?

    /// If this tap is in a series of taps, then this value represents
    /// the number in the series this tap is.
    ///
    /// **Dart Source:** tap_and_drag.dart:407
    public let consecutiveTapCount: Int

    // MARK: - Diagnosticable

    /// **Dart Source:** tap_and_drag.dart:410-417
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(DiagnosticsProperty<Offset>("globalPosition", globalPosition))
        properties.add(DiagnosticsProperty<Offset>("localPosition", localPosition))
        properties.add(DiagnosticsProperty<String>("velocity", "\(velocity)"))
        if let primaryVelocity = primaryVelocity {
            properties.add(DiagnosticsProperty<String>("primaryVelocity", "\(primaryVelocity)"))
        }
        properties.add(IntProperty("consecutiveTapCount", consecutiveTapCount))
    }
}

// MARK: - BaseTapAndDragGestureRecognizer

/// A base class for gesture recognizers that recognize taps and movements.
///
/// Takes on the responsibilities of `TapGestureRecognizer` and
/// `DragGestureRecognizer` in one `GestureRecognizer`.
///
/// ### Gesture arena behavior
///
/// `BaseTapAndDragGestureRecognizer` competes on the pointer events of
/// `kPrimaryButton` only when it has at least one non-nil `onTap*`
/// or `onDrag*` callback.
///
/// It will declare defeat if it determines that a gesture is not a
/// tap (e.g. if the pointer is dragged too far while it's contacting the
/// screen) or a drag (e.g. if the pointer was not dragged far enough to
/// be considered a drag).
///
/// This recognizer will not immediately declare victory for every tap that it
/// recognizes, but it declares victory for every drag.
///
/// The recognizer will declare victory when all other recognizers in
/// the arena have lost, if the timer of `kPressTimeout` elapses and a tap
/// series greater than 1 is being tracked, or until the pointer has moved
/// a sufficient global distance from the origin to be considered a drag.
///
/// **Dart Source:** tap_and_drag.dart:750-1385
///
/// DIFFERENCE FROM DART: In Dart, `BaseTapAndDragGestureRecognizer` is a sealed
/// class with a `_TapStatusTrackerMixin`. In Swift, it is an open class with
/// the mixin logic embedded directly, because Swift does not support mixins
/// with stored properties.
///
/// DIFFERENCE FROM DART: Abstract methods `_getDeltaForDetails`,
/// `_getPrimaryValueFromOffset`, and `_hasSufficientGlobalDistanceToAccept` are
/// implemented as open methods with `fatalError` defaults. Subclasses must
/// override these.
open class BaseTapAndDragGestureRecognizer: OneSequenceGestureRecognizer {

    /// Creates a tap and drag gesture recognizer.
    ///
    /// **Dart Source:** tap_and_drag.dart:755-761
    public init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { buttons in buttons == kPrimaryButton },
        eagerVictoryOnDrag: Bool = true
    ) {
        self.eagerVictoryOnDrag = eagerVictoryOnDrag
        self._deadline = kPressTimeout
        self.dragStartBehavior = .start
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    // MARK: - Public Properties

    /// Configure the behavior of offsets passed to `onDragStart`.
    ///
    /// If set to `DragStartBehavior.start`, the `onDragStart` callback will be called
    /// with the position of the pointer at the time this gesture recognizer won
    /// the arena. If `DragStartBehavior.down`, `onDragStart` will be called with
    /// the position of the first detected down event for the pointer.
    ///
    /// By default, the drag start behavior is `DragStartBehavior.start`.
    ///
    /// **Dart Source:** tap_and_drag.dart:780
    public var dragStartBehavior: DragStartBehavior

    /// The frequency at which the `onDragUpdate` callback is called.
    ///
    /// The value defaults to nil, meaning there is no delay for `onDragUpdate` callback.
    ///
    /// **Dart Source:** tap_and_drag.dart:785
    ///
    /// DIFFERENCE FROM DART: Uses `TimeInterval` (Double, seconds) instead of `Duration`.
    /// REASON: Foundation `Timer` expects `TimeInterval`; this is idiomatic Swift.
    public var dragUpdateThrottleFrequency: TimeInterval?

    /// An upper bound for the amount of taps that can belong to one tap series.
    ///
    /// When this limit is reached the series of taps being tracked by this
    /// recognizer will be reset.
    ///
    /// **Dart Source:** tap_and_drag.dart:792
    public var maxConsecutiveTap: Int?

    /// Whether this recognizer eagerly declares victory when it has detected
    /// a drag.
    ///
    /// When this value is `false`, this recognizer will wait until it is the last
    /// recognizer in the gesture arena before declaring victory on a drag.
    ///
    /// Defaults to `true`.
    ///
    /// **Dart Source:** tap_and_drag.dart:801
    public var eagerVictoryOnDrag: Bool

    // MARK: - Tap/Drag Callbacks

    /// A pointer has contacted the screen with a primary button, which might be
    /// the start of a tap.
    ///
    /// This triggers after the down event, once a short timeout (`kPressTimeout`) has
    /// elapsed, or once the gesture has won the arena, whichever comes first.
    ///
    /// **Dart Source:** tap_and_drag.dart:820
    public var onTapDown: GestureTapDragDownCallback?

    /// A pointer has stopped contacting the screen, which is recognized as a tap.
    ///
    /// This triggers on the up event, if the recognizer wins the arena with it
    /// or has previously won.
    ///
    /// **Dart Source:** tap_and_drag.dart:836
    public var onTapUp: GestureTapDragUpCallback?

    /// A pointer has begun to move, which is recognized as a drag start.
    ///
    /// The position of the pointer is provided in the callback's `details`
    /// argument. The `dragStartBehavior` determines this position.
    ///
    /// **Dart Source:** tap_and_drag.dart:850
    public var onDragStart: GestureTapDragStartCallback?

    /// A pointer that is in contact with the screen and moving has moved again.
    ///
    /// **Dart Source:** tap_and_drag.dart:863
    public var onDragUpdate: GestureTapDragUpdateCallback?

    /// A pointer that was previously in contact with the screen and moving
    /// is no longer in contact with the screen.
    ///
    /// **Dart Source:** tap_and_drag.dart:876
    public var onDragEnd: GestureTapDragEndCallback?

    /// The pointer that previously triggered `onTapDown` did not complete.
    ///
    /// This is called when a `PointerCancelEvent` is tracked when the `onTapDown` callback
    /// was previously called.
    ///
    /// It may also be called if a `PointerUpEvent` is tracked after the pointer has moved
    /// past the tap tolerance but not past the drag tolerance, and the recognizer has not
    /// yet won the arena.
    ///
    /// **Dart Source:** tap_and_drag.dart:890
    public var onCancel: GestureCancelCallback?

    // MARK: - _TapStatusTrackerMixin State (embedded)

    /// The `PointerDownEvent` most recently tracked.
    ///
    /// **Dart Source:** tap_and_drag.dart:451 (from _TapStatusTrackerMixin)
    private var _down: PointerDownEvent?

    /// The `PointerUpEvent` most recently tracked.
    ///
    /// **Dart Source:** tap_and_drag.dart:461 (from _TapStatusTrackerMixin)
    private var _up: PointerUpEvent?

    /// The number of consecutive taps being tracked.
    ///
    /// **Dart Source:** tap_and_drag.dart:488 (from _TapStatusTrackerMixin)
    private var _consecutiveTapCount: Int = 0

    /// **Dart Source:** tap_and_drag.dart:490
    private var _tapOriginPosition: OffsetPair?

    /// **Dart Source:** tap_and_drag.dart:491
    private var _previousButtons: Int?

    /// **Dart Source:** tap_and_drag.dart:494
    private var _consecutiveTapTimer: Timer?

    /// **Dart Source:** tap_and_drag.dart:495
    private var _lastTapOffset: Offset?

    // MARK: - _TapStatusTrackerMixin Computed Properties

    /// The `PointerDownEvent` that was most recently tracked.
    ///
    /// **Dart Source:** tap_and_drag.dart:451
    public var currentDown: PointerDownEvent? { return _down }

    /// The `PointerUpEvent` that was most recently tracked.
    ///
    /// **Dart Source:** tap_and_drag.dart:461
    public var currentUp: PointerUpEvent? { return _up }

    /// The number of consecutive taps that the most recently tracked
    /// `PointerDownEvent` represents.
    ///
    /// **Dart Source:** tap_and_drag.dart:477
    public var consecutiveTapCount: Int { return _consecutiveTapCount }

    // MARK: - _TapStatusTrackerMixin Callbacks

    /// Called when tap tracking starts.
    ///
    /// **Dart Source:** tap_and_drag.dart:498
    public var onTapTrackStart: (() -> Void)?

    /// Called when tap tracking resets.
    ///
    /// **Dart Source:** tap_and_drag.dart:501
    public var onTapTrackReset: (() -> Void)?

    // MARK: - Tap Related State

    /// **Dart Source:** tap_and_drag.dart:893
    private var _pastSlopTolerance: Bool = false

    /// **Dart Source:** tap_and_drag.dart:894
    private var _sentTapDown: Bool = false

    /// **Dart Source:** tap_and_drag.dart:895
    private var _wonArenaForPrimaryPointer: Bool = false

    // MARK: - Primary Pointer State

    /// **Dart Source:** tap_and_drag.dart:898
    private var _primaryPointer: Int?

    /// **Dart Source:** tap_and_drag.dart:899
    private var _deadlineTimer: Timer?

    /// The recognizer will call `onTapDown` after this amount of time has elapsed
    /// since starting to track the primary pointer.
    ///
    /// **Dart Source:** tap_and_drag.dart:905
    private let _deadline: TimeInterval

    // MARK: - Drag Related State

    /// **Dart Source:** tap_and_drag.dart:908
    private var _dragState: TapDragState = .ready

    /// **Dart Source:** tap_and_drag.dart:909
    private var _start: PointerEvent?

    /// **Dart Source:** tap_and_drag.dart:910
    private var _initialPosition: OffsetPair = .zero

    /// **Dart Source:** tap_and_drag.dart:911
    private var _currentPosition: OffsetPair = .zero

    /// **Dart Source:** tap_and_drag.dart:912
    ///
    /// DIFFERENCE FROM DART: `fileprivate` instead of `private` because
    /// subclasses in this file need to access this property.
    fileprivate var _globalDistanceMoved: Double = 0.0

    /// **Dart Source:** tap_and_drag.dart:913
    fileprivate var _globalDistanceMovedAllAxes: Double = 0.0

    // MARK: - Drag Update Throttle State

    /// **Dart Source:** tap_and_drag.dart:916
    private var _lastDragUpdateDetails: TapDragUpdateDetails?

    /// **Dart Source:** tap_and_drag.dart:917
    private var _dragUpdateThrottleTimer: Timer?

    /// **Dart Source:** tap_and_drag.dart:919
    private var _acceptedActivePointers: Set<Int> = []

    // MARK: - Abstract Methods (Subclasses must override)

    /// Returns the effective delta for the given `delta`.
    ///
    /// **Dart Source:** tap_and_drag.dart:921
    open func _getDeltaForDetails(_ delta: Offset) -> Offset {
        fatalError("Subclass must override _getDeltaForDetails(_:)")
    }

    /// Returns the value for the primary axis from the given `value`.
    ///
    /// Returns nil if the recognizer does not have a primary axis.
    ///
    /// **Dart Source:** tap_and_drag.dart:922
    open func _getPrimaryValueFromOffset(_ value: Offset) -> Double? {
        fatalError("Subclass must override _getPrimaryValueFromOffset(_:)")
    }

    /// Whether the `_globalDistanceMoved` is big enough to accept the gesture.
    ///
    /// **Dart Source:** tap_and_drag.dart:923
    open func _hasSufficientGlobalDistanceToAccept(_ pointerDeviceKind: PointerDeviceKind) -> Bool {
        fatalError("Subclass must override _hasSufficientGlobalDistanceToAccept(_:)")
    }

    // MARK: - Drag Update Throttle

    /// Drag updates may require throttling to avoid excessive updating, such as
    /// for text layouts in text fields. The frequency of invocations is controlled
    /// by the `dragUpdateThrottleFrequency`.
    ///
    /// Once the drag gesture ends, any pending drag update will be fired
    /// immediately. See `_checkDragEnd`.
    ///
    /// **Dart Source:** tap_and_drag.dart:930-937
    private func _handleDragUpdateThrottled() {
        assert(_lastDragUpdateDetails != nil)
        if onDragUpdate != nil {
            invokeCallback("onDragUpdate", { self.onDragUpdate!(self._lastDragUpdateDetails!) })
        }
        _dragUpdateThrottleTimer = nil
        _lastDragUpdateDetails = nil
    }

    // MARK: - isPointerAllowed

    /// **Dart Source:** tap_and_drag.dart:940-962
    ///
    /// DIFFERENCE FROM DART: The Dart code accepts a generic `PointerEvent` and
    /// then casts to `PointerDownEvent`. In Swift, we need to handle this via
    /// the `PointerDownEvent` override signature from the parent class. The
    /// internal `_isPointerAllowed` method handles the generic event case.
    private func _isPointerAllowed(_ event: PointerEvent) -> Bool {
        if _primaryPointer == nil {
            switch event.buttons {
            case kPrimaryButton:
                if onTapDown == nil
                    && onDragStart == nil
                    && onDragUpdate == nil
                    && onDragEnd == nil
                    && onTapUp == nil
                    && onCancel == nil
                {
                    return false
                }
            default:
                return false
            }
        } else {
            if event.pointer != _primaryPointer {
                return false
            }
        }

        return true
    }

    /// **Dart Source:** tap_and_drag.dart:940-962
    open override func isPointerAllowed(_ event: PointerDownEvent) -> Bool {
        if !_isPointerAllowed(event) {
            return false
        }
        return super.isPointerAllowed(event)
    }

    // MARK: - addAllowedPointer (Mixin + Base combined)

    /// **Dart Source:** tap_and_drag.dart:506-527 (mixin) + tap_and_drag.dart:965-976 (base)
    open override func addAllowedPointer(_ event: PointerDownEvent) {
        if _dragState == .ready {
            // --- Mixin: _TapStatusTrackerMixin.addAllowedPointer ---
            // super.addAllowedPointer is called by the mixin's addAllowedPointer
            // which calls OneSequenceGestureRecognizer.addAllowedPointer (startTrackingPointer)
            super.addAllowedPointer(event)

            // Mixin: check consecutive tap timer expiry
            if _consecutiveTapTimer != nil && !_consecutiveTapTimer!.isValid {
                _tapTrackerReset()
            }
            // Mixin: check max consecutive tap limit
            if maxConsecutiveTap == _consecutiveTapCount {
                _tapTrackerReset()
            }
            _up = nil
            if _down != nil && !_representsSameSeries(event) {
                // The given tap does not match the specifications of the series
                _consecutiveTapCount = 1
            } else {
                _consecutiveTapCount += 1
            }
            _consecutiveTapTimerStop()
            // `_down` must be assigned in this method instead of handleEvent,
            // because acceptGesture might be called before handleEvent,
            // which may rely on `_down` to initiate a callback.
            _trackTap(event)

            // --- Base: BaseTapAndDragGestureRecognizer.addAllowedPointer ---
            _primaryPointer = event.pointer
            _globalDistanceMoved = 0.0
            _globalDistanceMovedAllAxes = 0.0
            _dragState = .possible
            _initialPosition = OffsetPair(local: event.localPosition, global: event.position)
            _currentPosition = _initialPosition
            nonisolated(unsafe) let capturedEvent = event
            nonisolated(unsafe) let capturedSelf = self
            _deadlineTimer = Timer.scheduledTimer(withTimeInterval: _deadline, repeats: false) { _ in
                capturedSelf._didExceedDeadlineWithEvent(capturedEvent)
            }
        }
    }

    // MARK: - handleNonAllowedPointer

    /// **Dart Source:** tap_and_drag.dart:979-986
    open override func handleNonAllowedPointer(_ event: PointerDownEvent) {
        // There can be multiple drags simultaneously. Their effects are combined.
        if event.buttons != kPrimaryButton {
            if !_wonArenaForPrimaryPointer {
                super.handleNonAllowedPointer(event)
            }
        }
    }

    // MARK: - acceptGesture

    /// **Dart Source:** tap_and_drag.dart:989-1027
    open override func acceptGesture(_ pointer: Int) {
        if pointer != _primaryPointer {
            return
        }

        _stopDeadlineTimer()

        assert(!_acceptedActivePointers.contains(pointer))
        _acceptedActivePointers.insert(pointer)

        // Called when this recognizer is accepted by the GestureArena.
        if currentDown != nil {
            _checkTapDown(currentDown!)
        }

        _wonArenaForPrimaryPointer = true

        // resolve(GestureDisposition.accepted) will be called when the PointerMoveEvent
        // has moved a sufficient global distance to be considered a drag and
        // `eagerVictoryOnDrag` is set to `true`.
        if _start != nil && eagerVictoryOnDrag {
            assert(_dragState == .accepted)
            assert(currentUp == nil)
            _acceptDrag(_start!)
        }

        // This recognizer will wait until it is the last one in the gesture arena
        // before accepting a drag when `eagerVictoryOnDrag` is set to `false`.
        if _start != nil && !eagerVictoryOnDrag {
            assert(_dragState == .possible)
            assert(currentUp == nil)
            _dragState = .accepted
            _acceptDrag(_start!)
        }

        if currentUp != nil {
            _checkTapUp(currentUp!)
        }
    }

    // MARK: - didStopTrackingLastPointer

    /// **Dart Source:** tap_and_drag.dart:1030-1072
    open override func didStopTrackingLastPointer(_ pointer: Int) {
        switch _dragState {
        case .ready:
            _checkCancel()
            resolve(.rejected)

        case .possible:
            if _pastSlopTolerance {
                // This means the pointer was not accepted as a tap.
                if _wonArenaForPrimaryPointer {
                    // If the recognizer has already won the arena for the primary pointer being tracked
                    // but the pointer has exceeded the tap tolerance, then the pointer is accepted as a
                    // drag gesture.
                    if currentDown != nil {
                        if _acceptedActivePointers.remove(pointer) == nil {
                            resolvePointer(pointer, .rejected)
                        }
                        _dragState = .accepted
                        _acceptDrag(currentDown!)
                        _checkDragEnd()
                    }
                } else {
                    _checkCancel()
                    resolve(.rejected)
                }
            } else {
                // The pointer is accepted as a tap.
                if currentUp != nil {
                    _checkTapUp(currentUp!)
                }
            }

        case .accepted:
            // For the case when the pointer has been accepted as a drag.
            // Meaning _checkTapDown and _checkDragStart have already ran.
            _checkDragEnd()
        }

        _stopDeadlineTimer()
        _start = nil
        _dragState = .ready
        _pastSlopTolerance = false
    }

    // MARK: - handleEvent (Mixin + Base combined)

    /// **Dart Source:** tap_and_drag.dart:530-549 (mixin) + tap_and_drag.dart:1075-1128 (base)
    open override func handleEvent(_ event: PointerEvent) {
        if event.pointer != _primaryPointer {
            return
        }

        // --- Mixin: _TapStatusTrackerMixin.handleEvent ---
        if event is PointerMoveEvent {
            let computedSlop = computeHitSlop(event.kind, gestureSettings)
            let isSlopPastTolerance = _getGlobalDistance(event, _tapOriginPosition) > computedSlop

            if isSlopPastTolerance {
                _consecutiveTapTimerStop()
                _previousButtons = nil
                _lastTapOffset = nil
            }
        } else if let upEvent = event as? PointerUpEvent {
            _up = upEvent
            if _down != nil {
                _consecutiveTapTimerStop()
                _consecutiveTapTimerStart()
            }
        } else if event is PointerCancelEvent {
            _tapTrackerReset()
        }

        // --- Base: BaseTapAndDragGestureRecognizer.handleEvent ---
        if let moveEvent = event as? PointerMoveEvent {
            // Receiving a PointerMoveEvent does not automatically mean the pointer
            // being tracked is doing a drag gesture. There is some drift that can happen
            // between the initial PointerDownEvent and subsequent PointerMoveEvents.
            let computedSlop = computeHitSlop(moveEvent.kind, gestureSettings)
            _pastSlopTolerance =
                _pastSlopTolerance || _getGlobalDistance(moveEvent, _initialPosition) > computedSlop

            if _dragState == .accepted {
                _currentPosition = OffsetPair.fromEventPosition(moveEvent)
                _checkDragUpdate(moveEvent)
            } else if _dragState == .possible {
                if _start == nil {
                    // Only check for a drag if the start of a drag was not already identified.
                    _checkDrag(moveEvent)
                }

                // This can occur when the recognizer is accepted before a PointerMoveEvent has been
                // received that moves the pointer a sufficient global distance to be considered a drag.
                if _start != nil && _wonArenaForPrimaryPointer {
                    _dragState = .accepted
                    _acceptDrag(_start!)
                }
            }
        } else if event is PointerUpEvent {
            if _dragState == .possible {
                // The drag has not been accepted before a PointerUpEvent, therefore the recognizer
                // attempts to recognize a tap.
                stopTrackingIfPointerNoLongerDown(event)
            } else if _dragState == .accepted {
                _giveUpPointer(event.pointer)
            }
        } else if event is PointerCancelEvent {
            _dragState = .ready
            _giveUpPointer(event.pointer)
        }
    }

    // MARK: - rejectGesture (Mixin + Base combined)

    /// **Dart Source:** tap_and_drag.dart:552-554 (mixin) + tap_and_drag.dart:1131-1141 (base)
    open override func rejectGesture(_ pointer: Int) {
        if pointer != _primaryPointer {
            return
        }

        // Mixin: _TapStatusTrackerMixin.rejectGesture
        _tapTrackerReset()

        // Base: BaseTapAndDragGestureRecognizer.rejectGesture
        _stopDeadlineTimer()
        _giveUpPointer(pointer)
        _resetTaps()
        _resetDragUpdateThrottle()
    }

    // MARK: - dispose (Mixin + Base combined)

    /// **Dart Source:** tap_and_drag.dart:557-560 (mixin) + tap_and_drag.dart:1143-1148 (base)
    open override func dispose() {
        // Mixin: _TapStatusTrackerMixin.dispose
        _tapTrackerReset()

        // Base: BaseTapAndDragGestureRecognizer.dispose
        _stopDeadlineTimer()
        _resetDragUpdateThrottle()
        super.dispose()
    }

    // MARK: - debugDescription

    /// **Dart Source:** tap_and_drag.dart:1151
    open override var debugDescription: String {
        return "tap_and_drag"
    }

    // MARK: - _TapStatusTrackerMixin Private Methods

    /// **Dart Source:** tap_and_drag.dart:562-568
    private func _trackTap(_ event: PointerDownEvent) {
        _down = event
        _previousButtons = event.buttons
        _lastTapOffset = event.position
        _tapOriginPosition = OffsetPair(local: event.localPosition, global: event.position)
        onTapTrackStart?()
    }

    /// **Dart Source:** tap_and_drag.dart:570-577
    private func _hasSameButton(_ buttons: Int) -> Bool {
        assert(_previousButtons != nil)
        if buttons == _previousButtons! {
            return true
        } else {
            return false
        }
    }

    /// **Dart Source:** tap_and_drag.dart:579-586
    private func _isWithinConsecutiveTapTolerance(_ secondTapOffset: Offset) -> Bool {
        if _lastTapOffset == nil {
            return false
        }

        let difference = secondTapOffset - _lastTapOffset!
        return difference.distance <= kDoubleTapSlop
    }

    /// **Dart Source:** tap_and_drag.dart:588-592
    private func _representsSameSeries(_ event: PointerDownEvent) -> Bool {
        return _consecutiveTapTimer != nil
            && _isWithinConsecutiveTapTolerance(event.position)
            && _hasSameButton(event.buttons)
    }

    /// **Dart Source:** tap_and_drag.dart:594-596
    private func _consecutiveTapTimerStart() {
        if _consecutiveTapTimer == nil {
            nonisolated(unsafe) let capturedSelf = self
            _consecutiveTapTimer = Timer.scheduledTimer(withTimeInterval: kDoubleTapTimeout, repeats: false) { _ in
                capturedSelf._consecutiveTapTimerTimeout()
            }
        }
    }

    /// **Dart Source:** tap_and_drag.dart:598-603
    private func _consecutiveTapTimerStop() {
        if _consecutiveTapTimer != nil {
            _consecutiveTapTimer!.invalidate()
            _consecutiveTapTimer = nil
        }
    }

    /// The consecutive tap timer may time out before a tap down/tap up event is
    /// fired. In this case we should not reset the tap tracker state immediately.
    /// Instead we should reset the tap tracker on the next call to `addAllowedPointer`,
    /// if the timer is no longer active.
    ///
    /// **Dart Source:** tap_and_drag.dart:605-611
    private func _consecutiveTapTimerTimeout() {
        // No-op: reset happens lazily in addAllowedPointer
    }

    /// **Dart Source:** tap_and_drag.dart:612-625
    private func _tapTrackerReset() {
        _consecutiveTapTimerStop()
        _previousButtons = nil
        _tapOriginPosition = nil
        _lastTapOffset = nil
        _consecutiveTapCount = 0
        _down = nil
        _up = nil
        onTapTrackReset?()
    }

    // MARK: - BaseTapAndDragGestureRecognizer Private Methods

    /// **Dart Source:** tap_and_drag.dart:1153-1181
    private func _acceptDrag(_ event: PointerEvent) {
        assert(_dragState == .accepted)

        if !_wonArenaForPrimaryPointer {
            return
        }

        if dragStartBehavior == .start {
            _initialPosition = _initialPosition + OffsetPair(local: event.localDelta, global: event.delta)
            _currentPosition = _initialPosition
        }
        _checkDragStart(event)
        let localDelta = event.localDelta
        if localDelta != .zero {
            _currentPosition = OffsetPair.fromEventPosition(event)
            let correctedLocalPosition = _initialPosition.local + localDelta
            let localToGlobalTransform: Matrix4?
            if let transform = event.transform {
                var invertedTransform = transform
                let det = invertedTransform.invert()
                localToGlobalTransform = det != 0.0 ? invertedTransform : nil
            } else {
                localToGlobalTransform = nil
            }
            let globalUpdateDelta = PointerEvent.transformDeltaViaPositions(
                untransformedEndPosition: correctedLocalPosition,
                untransformedDelta: localDelta,
                transform: localToGlobalTransform
            )
            let updateDelta = OffsetPair(local: localDelta, global: globalUpdateDelta)
            // Only adds delta for down behaviour
            _checkDragUpdate(event, corrected: _initialPosition + updateDelta)
        }
    }

    /// **Dart Source:** tap_and_drag.dart:1183-1213
    private func _checkDrag(_ event: PointerMoveEvent) {
        let localToGlobalTransform: Matrix4?
        if let transform = event.transform {
            var invertedTransform = transform
            let det = invertedTransform.invert()
            localToGlobalTransform = det != 0.0 ? invertedTransform : nil
        } else {
            localToGlobalTransform = nil
        }
        let movedLocally = _getDeltaForDetails(event.localDelta)
        _globalDistanceMoved +=
            PointerEvent.transformDeltaViaPositions(
                untransformedEndPosition: event.localPosition,
                untransformedDelta: movedLocally,
                transform: localToGlobalTransform
            ).distance
            * _signOf(_getPrimaryValueFromOffset(movedLocally) ?? 1)
        _globalDistanceMovedAllAxes +=
            PointerEvent.transformDeltaViaPositions(
                untransformedEndPosition: event.localPosition,
                untransformedDelta: event.localDelta,
                transform: localToGlobalTransform
            ).distance
            * 1.0  // 1.sign is always 1.0
        if _hasSufficientGlobalDistanceToAccept(event.kind)
            || (_wonArenaForPrimaryPointer
                && Swift.abs(_globalDistanceMovedAllAxes) > computePanSlop(event.kind, gestureSettings))
        {
            _start = event
            if eagerVictoryOnDrag {
                _dragState = .accepted
                if !_wonArenaForPrimaryPointer {
                    resolve(.accepted)
                }
            }
        }
    }

    /// **Dart Source:** tap_and_drag.dart:1215-1232
    private func _checkTapDown(_ event: PointerDownEvent) {
        if _sentTapDown {
            return
        }

        let details = TapDragDownDetails(
            globalPosition: event.position,
            localPosition: event.localPosition,
            kind: getKindForPointer(event.pointer),
            consecutiveTapCount: consecutiveTapCount
        )

        if onTapDown != nil {
            invokeCallback("onTapDown", { self.onTapDown!(details) })
        }

        _sentTapDown = true
    }

    /// **Dart Source:** tap_and_drag.dart:1234-1254
    private func _checkTapUp(_ event: PointerUpEvent) {
        if !_wonArenaForPrimaryPointer {
            return
        }

        let upDetails = TapDragUpDetails(
            globalPosition: event.position,
            localPosition: event.localPosition,
            kind: event.kind,
            consecutiveTapCount: consecutiveTapCount
        )

        if onTapUp != nil {
            invokeCallback("onTapUp", { self.onTapUp!(upDetails) })
        }

        _resetTaps()
        if _acceptedActivePointers.remove(event.pointer) == nil {
            resolvePointer(event.pointer, .rejected)
        }
    }

    /// **Dart Source:** tap_and_drag.dart:1256-1270
    private func _checkDragStart(_ event: PointerEvent) {
        if onDragStart != nil {
            let details = TapDragStartDetails(
                globalPosition: _initialPosition.global,
                localPosition: _initialPosition.local,
                sourceTimeStamp: event.timeStamp,
                kind: getKindForPointer(event.pointer),
                consecutiveTapCount: consecutiveTapCount
            )

            invokeCallback("onDragStart", { self.onDragStart!(details) })
        }

        _start = nil
    }

    /// **Dart Source:** tap_and_drag.dart:1272-1296
    private func _checkDragUpdate(_ event: PointerEvent, corrected: OffsetPair? = nil) {
        let globalPosition = corrected?.global ?? event.position
        let localPosition = corrected?.local ?? event.localPosition

        let details = TapDragUpdateDetails(
            globalPosition: globalPosition,
            localPosition: localPosition,
            sourceTimeStamp: event.timeStamp,
            delta: event.localDelta,
            kind: getKindForPointer(event.pointer),
            offsetFromOrigin: globalPosition - _initialPosition.global,
            localOffsetFromOrigin: localPosition - _initialPosition.local,
            consecutiveTapCount: consecutiveTapCount
        )

        if dragUpdateThrottleFrequency != nil {
            _lastDragUpdateDetails = details
            // Only schedule a new timer if there's not one pending.
            if _dragUpdateThrottleTimer == nil {
                let frequency = dragUpdateThrottleFrequency!
                nonisolated(unsafe) let capturedSelf = self
                _dragUpdateThrottleTimer = Timer.scheduledTimer(withTimeInterval: frequency, repeats: false) { _ in
                    capturedSelf._handleDragUpdateThrottled()
                }
            }
        } else {
            if onDragUpdate != nil {
                invokeCallback("onDragUpdate", { self.onDragUpdate!(details) })
            }
        }
    }

    /// **Dart Source:** tap_and_drag.dart:1298-1322
    private func _checkDragEnd() {
        let globalPosition = _currentPosition.global
        let localPosition = _currentPosition.local

        if _dragUpdateThrottleTimer != nil {
            // If there's already an update scheduled, trigger it immediately and
            // cancel the timer.
            _dragUpdateThrottleTimer!.invalidate()
            _handleDragUpdateThrottled()
        }

        let endDetails = TapDragEndDetails(
            globalPosition: globalPosition,
            localPosition: localPosition,
            primaryVelocity: 0.0,
            consecutiveTapCount: consecutiveTapCount
        )

        if onDragEnd != nil {
            invokeCallback("onDragEnd", { self.onDragEnd!(endDetails) })
        }

        _resetTaps()
        _resetDragUpdateThrottle()
    }

    /// **Dart Source:** tap_and_drag.dart:1324-1334
    private func _checkCancel() {
        if !_sentTapDown {
            // Do not fire tap cancel if onTapDown was never called.
            return
        }
        if onCancel != nil {
            invokeCallback("onCancel", onCancel!)
        }
        _resetDragUpdateThrottle()
        _resetTaps()
    }

    /// **Dart Source:** tap_and_drag.dart:1336-1338
    private func _didExceedDeadlineWithEvent(_ event: PointerDownEvent) {
        _didExceedDeadline()
    }

    /// **Dart Source:** tap_and_drag.dart:1340-1351
    private func _didExceedDeadline() {
        if currentDown != nil {
            _checkTapDown(currentDown!)

            if consecutiveTapCount > 1 {
                // If our consecutive tap count is greater than 1, i.e. is a double tap or greater,
                // then this recognizer declares victory to prevent the LongPressGestureRecognizer
                // from declaring itself the winner if a double tap is held for too long.
                resolve(.accepted)
            }
        }
    }

    /// **Dart Source:** tap_and_drag.dart:1353-1360
    private func _giveUpPointer(_ pointer: Int) {
        stopTrackingPointer(pointer)
        // If the pointer was never accepted, then it is rejected since this recognizer is no longer
        // interested in winning the gesture arena for it.
        if _acceptedActivePointers.remove(pointer) == nil {
            resolvePointer(pointer, .rejected)
        }
    }

    /// **Dart Source:** tap_and_drag.dart:1362-1366
    private func _resetTaps() {
        _sentTapDown = false
        _wonArenaForPrimaryPointer = false
        _primaryPointer = nil
    }

    /// **Dart Source:** tap_and_drag.dart:1368-1377
    private func _resetDragUpdateThrottle() {
        if dragUpdateThrottleFrequency == nil {
            return
        }
        _lastDragUpdateDetails = nil
        if _dragUpdateThrottleTimer != nil {
            _dragUpdateThrottleTimer!.invalidate()
            _dragUpdateThrottleTimer = nil
        }
    }

    /// **Dart Source:** tap_and_drag.dart:1379-1384
    private func _stopDeadlineTimer() {
        if _deadlineTimer != nil {
            _deadlineTimer!.invalidate()
            _deadlineTimer = nil
        }
    }
}

// MARK: - TapAndHorizontalDragGestureRecognizer

/// Recognizes taps along with movement in the horizontal direction.
///
/// Before this recognizer has won the arena for the primary pointer being tracked,
/// it will only accept a drag on the horizontal axis. If a drag is detected after
/// this recognizer has won the arena then it will accept a drag on any axis.
///
/// See also:
///
///  * `BaseTapAndDragGestureRecognizer`, for the class that provides the main
///    implementation details of this recognizer.
///  * `TapAndPanGestureRecognizer`, for a similar recognizer that accepts a drag
///    on any axis regardless if the recognizer has won the arena for the primary
///    pointer being tracked.
///  * `HorizontalDragGestureRecognizer`, for a similar recognizer that only recognizes
///    horizontal movement.
///
/// **Dart Source:** tap_and_drag.dart:1402-1421
public class TapAndHorizontalDragGestureRecognizer: BaseTapAndDragGestureRecognizer {

    /// Create a gesture recognizer for interactions in the horizontal axis.
    ///
    /// **Dart Source:** tap_and_drag.dart:1406
    public override init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { buttons in buttons == kPrimaryButton },
        eagerVictoryOnDrag: Bool = true
    ) {
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter,
            eagerVictoryOnDrag: eagerVictoryOnDrag
        )
    }

    /// **Dart Source:** tap_and_drag.dart:1409-1411
    public override func _hasSufficientGlobalDistanceToAccept(_ pointerDeviceKind: PointerDeviceKind) -> Bool {
        return Swift.abs(_globalDistanceMoved) > computeHitSlop(pointerDeviceKind, gestureSettings)
    }

    /// **Dart Source:** tap_and_drag.dart:1414
    public override func _getDeltaForDetails(_ delta: Offset) -> Offset {
        return Offset(delta.dx, 0.0)
    }

    /// **Dart Source:** tap_and_drag.dart:1417
    public override func _getPrimaryValueFromOffset(_ value: Offset) -> Double? {
        return value.dx
    }

    /// **Dart Source:** tap_and_drag.dart:1420
    public override var debugDescription: String {
        return "tap and horizontal drag"
    }
}

// MARK: - TapAndPanGestureRecognizer

/// Recognizes taps along with both horizontal and vertical movement.
///
/// This recognizer will accept a drag on any axis, regardless if it has won the
/// arena for the primary pointer being tracked.
///
/// See also:
///
///  * `BaseTapAndDragGestureRecognizer`, for the class that provides the main
///    implementation details of this recognizer.
///  * `TapAndHorizontalDragGestureRecognizer`, for a similar recognizer that
///    only accepts horizontal drags before it has won the arena for the primary
///    pointer being tracked.
///  * `PanGestureRecognizer`, for a similar recognizer that only recognizes
///    movement.
///
/// **Dart Source:** tap_and_drag.dart:1439-1456
public class TapAndPanGestureRecognizer: BaseTapAndDragGestureRecognizer {

    /// Create a gesture recognizer for interactions on a plane.
    ///
    /// **Dart Source:** tap_and_drag.dart:1441
    public override init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { buttons in buttons == kPrimaryButton },
        eagerVictoryOnDrag: Bool = true
    ) {
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter,
            eagerVictoryOnDrag: eagerVictoryOnDrag
        )
    }

    /// **Dart Source:** tap_and_drag.dart:1444-1446
    public override func _hasSufficientGlobalDistanceToAccept(_ pointerDeviceKind: PointerDeviceKind) -> Bool {
        return Swift.abs(_globalDistanceMoved) > computePanSlop(pointerDeviceKind, gestureSettings)
    }

    /// **Dart Source:** tap_and_drag.dart:1449
    public override func _getDeltaForDetails(_ delta: Offset) -> Offset {
        return delta
    }

    /// **Dart Source:** tap_and_drag.dart:1452
    public override func _getPrimaryValueFromOffset(_ value: Offset) -> Double? {
        return nil
    }

    /// **Dart Source:** tap_and_drag.dart:1455
    public override var debugDescription: String {
        return "tap and pan"
    }
}

// NOTE: `TapAndDragGestureRecognizer` (Dart lines 1458-1486) was deprecated
// in Dart (after v3.9.0-19.0.pre) and is NOT migrated to Swift.
// Use `TapAndPanGestureRecognizer` instead, which provides identical behavior.

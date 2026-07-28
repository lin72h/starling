// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Long-press gesture recognizer and related types.
///
/// Recognizes when the user has pressed down at the same location for a long
/// period of time. Supports primary, secondary, and tertiary button long
/// presses with separate callbacks for each button and each phase of the
/// gesture (down, start, move update, end, up, cancel).
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/long_press.dart`
/// **Lines:** 1-882

import FlutterSwiftBridge
import Foundation

// MARK: - Callback Typealiases

/// Callback signature for `LongPressGestureRecognizer.onLongPressDown`.
///
/// Called when a pointer that might cause a long-press has contacted the
/// screen. The position at which the pointer contacted the screen is available
/// in the `details`.
///
/// **Dart Source:** `long_press.dart:34`
public typealias GestureLongPressDownCallback = (_ details: LongPressDownDetails) -> Void

/// Callback signature for `LongPressGestureRecognizer.onLongPressCancel`.
///
/// Called when the pointer that previously triggered a
/// `GestureLongPressDownCallback` will not end up causing a long-press.
///
/// **Dart Source:** `long_press.dart:44`
public typealias GestureLongPressCancelCallback = () -> Void

/// Callback signature for `LongPressGestureRecognizer.onLongPress`.
///
/// Called when a pointer has remained in contact with the screen at the
/// same location for a long period of time.
///
/// **Dart Source:** `long_press.dart:56`
public typealias GestureLongPressCallback = () -> Void

/// Callback signature for `LongPressGestureRecognizer.onLongPressUp`.
///
/// Called when a pointer stops contacting the screen after a long press
/// gesture was detected.
///
/// **Dart Source:** `long_press.dart:66`
public typealias GestureLongPressUpCallback = () -> Void

/// Callback signature for `LongPressGestureRecognizer.onLongPressStart`.
///
/// Called when a pointer has remained in contact with the screen at the
/// same location for a long period of time. Also reports the long press down
/// position.
///
/// **Dart Source:** `long_press.dart:79`
public typealias GestureLongPressStartCallback = (_ details: LongPressStartDetails) -> Void

/// Callback signature for `LongPressGestureRecognizer.onLongPressMoveUpdate`.
///
/// Called when a pointer is moving after being held in contact at the same
/// location for a long period of time. Reports the new position and its offset
/// from the original down position.
///
/// **Dart Source:** `long_press.dart:90`
public typealias GestureLongPressMoveUpdateCallback = (_ details: LongPressMoveUpdateDetails) -> Void

/// Callback signature for `LongPressGestureRecognizer.onLongPressEnd`.
///
/// Called when a pointer stops contacting the screen after a long press
/// gesture was detected. Also reports the position where the pointer stopped
/// contacting the screen.
///
/// **Dart Source:** `long_press.dart:101`
public typealias GestureLongPressEndCallback = (_ details: LongPressEndDetails) -> Void

// MARK: - LongPressDownDetails

/// Details for callbacks that use `GestureLongPressDownCallback`.
///
/// See also:
///
///  * `LongPressGestureRecognizer.onLongPressDown`, whose callback passes
///    these details.
///  * `LongPressGestureRecognizer.onSecondaryLongPressDown`, whose callback
///    passes these details.
///  * `LongPressGestureRecognizer.onTertiaryLongPressDown`, whose callback
///    passes these details.
///
/// **Dart Source:** `long_press.dart:113-139`
public struct LongPressDownDetails: PositionedGestureDetails {

    /// Creates the details for a `GestureLongPressDownCallback`.
    ///
    /// If the `localPosition` argument is not specified, it will default to the
    /// global position.
    ///
    /// **Dart Source:** `long_press.dart:118-119`
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil,
        kind: PointerDeviceKind? = nil
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.kind = kind
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `long_press.dart:123`
    public let globalPosition: Offset

    /// The local position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `long_press.dart:127`
    public let localPosition: Offset

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** `long_press.dart:130`
    public let kind: PointerDeviceKind?
}

// MARK: - LongPressStartDetails

/// Details for callbacks that use `GestureLongPressStartCallback`.
///
/// See also:
///
///  * `LongPressGestureRecognizer.onLongPressStart`, which uses
///    `GestureLongPressStartCallback`.
///  * `LongPressMoveUpdateDetails`, the details for
///    `GestureLongPressMoveUpdateCallback`.
///  * `LongPressEndDetails`, the details for `GestureLongPressEndCallback`.
///
/// **Dart Source:** `long_press.dart:148-167`
public struct LongPressStartDetails: PositionedGestureDetails {

    /// Creates the details for a `GestureLongPressStartCallback`.
    ///
    /// **Dart Source:** `long_press.dart:150-151`
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `long_press.dart:155`
    public let globalPosition: Offset

    /// The local position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `long_press.dart:159`
    public let localPosition: Offset
}

// MARK: - LongPressMoveUpdateDetails

/// Details for callbacks that use `GestureLongPressMoveUpdateCallback`.
///
/// See also:
///
///  * `LongPressGestureRecognizer.onLongPressMoveUpdate`, which uses
///    `GestureLongPressMoveUpdateCallback`.
///  * `LongPressEndDetails`, the details for `GestureLongPressEndCallback`.
///  * `LongPressStartDetails`, the details for `GestureLongPressStartCallback`.
///
/// **Dart Source:** `long_press.dart:176-212`
public struct LongPressMoveUpdateDetails: PositionedGestureDetails {

    /// Creates the details for a `GestureLongPressMoveUpdateCallback`.
    ///
    /// **Dart Source:** `long_press.dart:178-184`
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil,
        offsetFromOrigin: Offset = .zero,
        localOffsetFromOrigin: Offset? = nil
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.offsetFromOrigin = offsetFromOrigin
        self.localOffsetFromOrigin = localOffsetFromOrigin ?? offsetFromOrigin
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `long_press.dart:188`
    public let globalPosition: Offset

    /// The local position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `long_press.dart:192`
    public let localPosition: Offset

    /// A delta offset from the point where the long press drag initially contacted
    /// the screen to the point where the pointer is currently located (the
    /// present `globalPosition`) when this callback is triggered.
    ///
    /// **Dart Source:** `long_press.dart:197`
    public let offsetFromOrigin: Offset

    /// A local delta offset from the point where the long press drag initially contacted
    /// the screen to the point where the pointer is currently located (the
    /// present `localPosition`) when this callback is triggered.
    ///
    /// **Dart Source:** `long_press.dart:202`
    public let localOffsetFromOrigin: Offset
}

// MARK: - LongPressEndDetails

/// Details for callbacks that use `GestureLongPressEndCallback`.
///
/// See also:
///
///  * `LongPressGestureRecognizer.onLongPressEnd`, which uses
///    `GestureLongPressEndCallback`.
///  * `LongPressMoveUpdateDetails`, the details for
///    `GestureLongPressMoveUpdateCallback`.
///  * `LongPressStartDetails`, the details for `GestureLongPressStartCallback`.
///
/// **Dart Source:** `long_press.dart:221-249`
public struct LongPressEndDetails: PositionedGestureDetails {

    /// Creates the details for a `GestureLongPressEndCallback`.
    ///
    /// **Dart Source:** `long_press.dart:223-227`
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil,
        velocity: Velocity = .zero
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.velocity = velocity
    }

    /// The global position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** `long_press.dart:231`
    public let globalPosition: Offset

    /// The local position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** `long_press.dart:235`
    public let localPosition: Offset

    /// The pointer's velocity when it stopped contacting the screen.
    ///
    /// Defaults to zero if not specified in the constructor.
    ///
    /// **Dart Source:** `long_press.dart:241`
    public let velocity: Velocity
}

// MARK: - LongPressGestureRecognizer

/// Recognizes when the user has pressed down at the same location for a long
/// period of time.
///
/// The gesture must not deviate in position from its touch down point for 500ms
/// until it's recognized. Once the gesture is accepted, the finger can be
/// moved, triggering `onLongPressMoveUpdate` callbacks, unless the
/// `postAcceptSlopTolerance` constructor argument is specified.
///
/// `LongPressGestureRecognizer` may compete on pointer events of
/// `kPrimaryButton`, `kSecondaryButton`, and/or `kTertiaryButton` if at least
/// one corresponding callback is non-nil. If it has no callbacks, it is a no-op.
///
/// **Dart Source:** `long_press.dart:262-882`
public class LongPressGestureRecognizer: PrimaryPointerGestureRecognizer {

    /// Creates a long-press gesture recognizer.
    ///
    /// Consider assigning the `onLongPressStart` callback after creating this
    /// object.
    ///
    /// The `postAcceptSlopTolerance` argument can be used to specify a maximum
    /// allowed distance for the gesture to deviate from the starting point once
    /// the long press has triggered. If the gesture deviates past that point,
    /// subsequent callbacks (`onLongPressMoveUpdate`, `onLongPressUp`,
    /// `onLongPressEnd`) will stop. Defaults to nil, which means the gesture
    /// can be moved without limit once the long press is accepted.
    ///
    /// The `duration` argument can be used to overwrite the default duration
    /// after which the long press will be recognized.
    ///
    /// **Dart Source:** `long_press.dart:281-290`
    public init(
        duration: TimeInterval? = nil,
        postAcceptSlopTolerance: Double? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        debugOwner: AnyObject? = nil,
        allowedButtonsFilter: AllowedButtonsFilter? = nil
    ) {
        super.init(
            deadline: duration ?? kLongPressTimeout,
            postAcceptSlopTolerance: postAcceptSlopTolerance,
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter ?? LongPressGestureRecognizer._defaultButtonAcceptBehavior
        )
    }

    /// **Dart Source:** `long_press.dart:292`
    private var _longPressAccepted: Bool = false

    /// **Dart Source:** `long_press.dart:293`
    private var _longPressOrigin: OffsetPair?

    /// The buttons sent by `PointerDownEvent`. If a `PointerMoveEvent` comes with a
    /// different set of buttons, the gesture is canceled.
    ///
    /// **Dart Source:** `long_press.dart:296`
    private var _initialButtons: Int?

    /// Accept the input if, and only if, a single button is pressed.
    ///
    /// **Dart Source:** `long_press.dart:299-300`
    private static func _defaultButtonAcceptBehavior(_ buttons: Int) -> Bool {
        return buttons == kPrimaryButton || buttons == kSecondaryButton || buttons == kTertiaryButton
    }

    // MARK: - Primary Button Callbacks

    /// Called when a pointer has contacted the screen at a particular location
    /// with a primary button, which might be the start of a long-press.
    ///
    /// This triggers after the pointer down event.
    ///
    /// If this recognizer doesn't win the arena, `onLongPressCancel` is called
    /// next. Otherwise, `onLongPressStart` is called next.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///  * `onSecondaryLongPressDown`, a similar callback but for a secondary button.
    ///  * `onTertiaryLongPressDown`, a similar callback but for a tertiary button.
    ///  * `LongPressDownDetails`, which is passed as an argument to this callback.
    ///
    /// **Dart Source:** `long_press.dart:317`
    public var onLongPressDown: GestureLongPressDownCallback?

    /// Called when a pointer that previously triggered `onLongPressDown` will
    /// not end up causing a long-press.
    ///
    /// This triggers once the gesture loses the arena if `onLongPressDown` has
    /// previously been triggered.
    ///
    /// If this recognizer wins the arena, `onLongPressStart` and `onLongPress`
    /// are called instead.
    ///
    /// **Dart Source:** `long_press.dart:335`
    public var onLongPressCancel: GestureLongPressCancelCallback?

    /// Called when a long press gesture by a primary button has been recognized.
    ///
    /// This is equivalent to (and is called immediately after) `onLongPressStart`.
    /// The only difference between the two is that this callback does not
    /// contain details of the position at which the pointer initially contacted
    /// the screen.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///
    /// **Dart Source:** `long_press.dart:347`
    public var onLongPress: GestureLongPressCallback?

    /// Called when a long press gesture by a primary button has been recognized.
    ///
    /// This is equivalent to (and is called immediately before) `onLongPress`.
    /// The only difference between the two is that this callback contains
    /// details of the position at which the pointer initially contacted the
    /// screen, whereas `onLongPress` does not.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///  * `LongPressStartDetails`, which is passed as an argument to this callback.
    ///
    /// **Dart Source:** `long_press.dart:360`
    public var onLongPressStart: GestureLongPressStartCallback?

    /// Called when moving after the long press by a primary button is recognized.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///  * `LongPressMoveUpdateDetails`, which is passed as an argument to this
    ///    callback.
    ///
    /// **Dart Source:** `long_press.dart:369`
    public var onLongPressMoveUpdate: GestureLongPressMoveUpdateCallback?

    /// Called when the pointer stops contacting the screen after a long-press
    /// by a primary button.
    ///
    /// This is equivalent to (and is called immediately after) `onLongPressEnd`.
    /// The only difference between the two is that this callback does not
    /// contain details of the state of the pointer when it stopped contacting
    /// the screen.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///
    /// **Dart Source:** `long_press.dart:382`
    public var onLongPressUp: GestureLongPressUpCallback?

    /// Called when the pointer stops contacting the screen after a long-press
    /// by a primary button.
    ///
    /// This is equivalent to (and is called immediately before) `onLongPressUp`.
    /// The only difference between the two is that this callback contains
    /// details of the state of the pointer when it stopped contacting the
    /// screen, whereas `onLongPressUp` does not.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///  * `LongPressEndDetails`, which is passed as an argument to this
    ///    callback.
    ///
    /// **Dart Source:** `long_press.dart:397`
    public var onLongPressEnd: GestureLongPressEndCallback?

    // MARK: - Secondary Button Callbacks

    /// Called when a pointer has contacted the screen at a particular location
    /// with a secondary button, which might be the start of a long-press.
    ///
    /// This triggers after the pointer down event.
    ///
    /// If this recognizer doesn't win the arena, `onSecondaryLongPressCancel` is
    /// called next. Otherwise, `onSecondaryLongPressStart` is called next.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///  * `onLongPressDown`, a similar callback but for a primary button.
    ///  * `onTertiaryLongPressDown`, a similar callback but for a tertiary button.
    ///  * `LongPressDownDetails`, which is passed as an argument to this callback.
    ///
    /// **Dart Source:** `long_press.dart:415`
    public var onSecondaryLongPressDown: GestureLongPressDownCallback?

    /// Called when a pointer that previously triggered `onSecondaryLongPressDown`
    /// will not end up causing a long-press.
    ///
    /// This triggers once the gesture loses the arena if
    /// `onSecondaryLongPressDown` has previously been triggered.
    ///
    /// If this recognizer wins the arena, `onSecondaryLongPressStart` and
    /// `onSecondaryLongPress` are called instead.
    ///
    /// **Dart Source:** `long_press.dart:433`
    public var onSecondaryLongPressCancel: GestureLongPressCancelCallback?

    /// Called when a long press gesture by a secondary button has been
    /// recognized.
    ///
    /// This is equivalent to (and is called immediately after)
    /// `onSecondaryLongPressStart`. The only difference between the two is that
    /// this callback does not contain details of the position at which the
    /// pointer initially contacted the screen.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///
    /// **Dart Source:** `long_press.dart:446`
    public var onSecondaryLongPress: GestureLongPressCallback?

    /// Called when a long press gesture by a secondary button has been recognized.
    ///
    /// This is equivalent to (and is called immediately before)
    /// `onSecondaryLongPress`. The only difference between the two is that this
    /// callback contains details of the position at which the pointer initially
    /// contacted the screen, whereas `onSecondaryLongPress` does not.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///  * `LongPressStartDetails`, which is passed as an argument to this
    ///    callback.
    ///
    /// **Dart Source:** `long_press.dart:460`
    public var onSecondaryLongPressStart: GestureLongPressStartCallback?

    /// Called when moving after the long press by a secondary button is
    /// recognized.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///  * `LongPressMoveUpdateDetails`, which is passed as an argument to this
    ///    callback.
    ///
    /// **Dart Source:** `long_press.dart:470`
    public var onSecondaryLongPressMoveUpdate: GestureLongPressMoveUpdateCallback?

    /// Called when the pointer stops contacting the screen after a long-press by
    /// a secondary button.
    ///
    /// This is equivalent to (and is called immediately after)
    /// `onSecondaryLongPressEnd`. The only difference between the two is that
    /// this callback does not contain details of the state of the pointer when
    /// it stopped contacting the screen.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///
    /// **Dart Source:** `long_press.dart:483`
    public var onSecondaryLongPressUp: GestureLongPressUpCallback?

    /// Called when the pointer stops contacting the screen after a long-press by
    /// a secondary button.
    ///
    /// This is equivalent to (and is called immediately before)
    /// `onSecondaryLongPressUp`. The only difference between the two is that
    /// this callback contains details of the state of the pointer when it
    /// stopped contacting the screen, whereas `onSecondaryLongPressUp` does not.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///  * `LongPressEndDetails`, which is passed as an argument to this callback.
    ///
    /// **Dart Source:** `long_press.dart:497`
    public var onSecondaryLongPressEnd: GestureLongPressEndCallback?

    // MARK: - Tertiary Button Callbacks

    /// Called when a pointer has contacted the screen at a particular location
    /// with a tertiary button, which might be the start of a long-press.
    ///
    /// This triggers after the pointer down event.
    ///
    /// If this recognizer doesn't win the arena, `onTertiaryLongPressCancel` is
    /// called next. Otherwise, `onTertiaryLongPressStart` is called next.
    ///
    /// See also:
    ///
    ///  * `kTertiaryButton`, the button this callback responds to.
    ///  * `onLongPressDown`, a similar callback but for a primary button.
    ///  * `onSecondaryLongPressDown`, a similar callback but for a secondary button.
    ///  * `LongPressDownDetails`, which is passed as an argument to this callback.
    ///
    /// **Dart Source:** `long_press.dart:515`
    public var onTertiaryLongPressDown: GestureLongPressDownCallback?

    /// Called when a pointer that previously triggered `onTertiaryLongPressDown`
    /// will not end up causing a long-press.
    ///
    /// This triggers once the gesture loses the arena if
    /// `onTertiaryLongPressDown` has previously been triggered.
    ///
    /// If this recognizer wins the arena, `onTertiaryLongPressStart` and
    /// `onTertiaryLongPress` are called instead.
    ///
    /// **Dart Source:** `long_press.dart:533`
    public var onTertiaryLongPressCancel: GestureLongPressCancelCallback?

    /// Called when a long press gesture by a tertiary button has been
    /// recognized.
    ///
    /// This is equivalent to (and is called immediately after)
    /// `onTertiaryLongPressStart`. The only difference between the two is that
    /// this callback does not contain details of the position at which the
    /// pointer initially contacted the screen.
    ///
    /// See also:
    ///
    ///  * `kTertiaryButton`, the button this callback responds to.
    ///
    /// **Dart Source:** `long_press.dart:546`
    public var onTertiaryLongPress: GestureLongPressCallback?

    /// Called when a long press gesture by a tertiary button has been recognized.
    ///
    /// This is equivalent to (and is called immediately before)
    /// `onTertiaryLongPress`. The only difference between the two is that this
    /// callback contains details of the position at which the pointer initially
    /// contacted the screen, whereas `onTertiaryLongPress` does not.
    ///
    /// See also:
    ///
    ///  * `kTertiaryButton`, the button this callback responds to.
    ///  * `LongPressStartDetails`, which is passed as an argument to this
    ///    callback.
    ///
    /// **Dart Source:** `long_press.dart:560`
    public var onTertiaryLongPressStart: GestureLongPressStartCallback?

    /// Called when moving after the long press by a tertiary button is
    /// recognized.
    ///
    /// See also:
    ///
    ///  * `kTertiaryButton`, the button this callback responds to.
    ///  * `LongPressMoveUpdateDetails`, which is passed as an argument to this
    ///    callback.
    ///
    /// **Dart Source:** `long_press.dart:570`
    public var onTertiaryLongPressMoveUpdate: GestureLongPressMoveUpdateCallback?

    /// Called when the pointer stops contacting the screen after a long-press by
    /// a tertiary button.
    ///
    /// This is equivalent to (and is called immediately after)
    /// `onTertiaryLongPressEnd`. The only difference between the two is that
    /// this callback does not contain details of the state of the pointer when
    /// it stopped contacting the screen.
    ///
    /// See also:
    ///
    ///  * `kTertiaryButton`, the button this callback responds to.
    ///
    /// **Dart Source:** `long_press.dart:583`
    public var onTertiaryLongPressUp: GestureLongPressUpCallback?

    /// Called when the pointer stops contacting the screen after a long-press by
    /// a tertiary button.
    ///
    /// This is equivalent to (and is called immediately before)
    /// `onTertiaryLongPressUp`. The only difference between the two is that
    /// this callback contains details of the state of the pointer when it
    /// stopped contacting the screen, whereas `onTertiaryLongPressUp` does not.
    ///
    /// See also:
    ///
    ///  * `kTertiaryButton`, the button this callback responds to.
    ///  * `LongPressEndDetails`, which is passed as an argument to this callback.
    ///
    /// **Dart Source:** `long_press.dart:597`
    public var onTertiaryLongPressEnd: GestureLongPressEndCallback?

    /// **Dart Source:** `long_press.dart:599`
    private var _velocityTracker: VelocityTracker?

    // MARK: - Pointer Filtering

    /// **Dart Source:** `long_press.dart:602-638`
    public override func isPointerAllowed(_ event: PointerDownEvent) -> Bool {
        switch event.buttons {
        case kPrimaryButton:
            if onLongPressDown == nil
                && onLongPressCancel == nil
                && onLongPressStart == nil
                && onLongPress == nil
                && onLongPressMoveUpdate == nil
                && onLongPressEnd == nil
                && onLongPressUp == nil
            {
                return false
            }
        case kSecondaryButton:
            if onSecondaryLongPressDown == nil
                && onSecondaryLongPressCancel == nil
                && onSecondaryLongPressStart == nil
                && onSecondaryLongPress == nil
                && onSecondaryLongPressMoveUpdate == nil
                && onSecondaryLongPressEnd == nil
                && onSecondaryLongPressUp == nil
            {
                return false
            }
        case kTertiaryButton:
            if onTertiaryLongPressDown == nil
                && onTertiaryLongPressCancel == nil
                && onTertiaryLongPressStart == nil
                && onTertiaryLongPress == nil
                && onTertiaryLongPressMoveUpdate == nil
                && onTertiaryLongPressEnd == nil
                && onTertiaryLongPressUp == nil
            {
                return false
            }
        default:
            return false
        }
        return super.isPointerAllowed(event)
    }

    // MARK: - Deadline Handling

    /// **Dart Source:** `long_press.dart:641-647`
    public override func didExceedDeadline() {
        // Exceeding the deadline puts the gesture in the accepted state.
        resolve(.accepted)
        _longPressAccepted = true
        super.acceptGesture(primaryPointer!)
        _checkLongPressStart()
    }

    // MARK: - Primary Pointer Handling

    /// **Dart Source:** `long_press.dart:650-686`
    public override func handlePrimaryPointer(_ event: PointerEvent) {
        if !event.synthesized {
            if event is PointerDownEvent {
                _velocityTracker = VelocityTracker(kind: event.kind)
                _velocityTracker!.addPosition(event.timeStamp, event.localPosition)
            }
            if event is PointerMoveEvent {
                assert(_velocityTracker != nil)
                _velocityTracker!.addPosition(event.timeStamp, event.localPosition)
            }
        }

        if event is PointerUpEvent {
            if _longPressAccepted {
                _checkLongPressEnd(event)
            } else {
                // Pointer is lifted before timeout.
                resolve(.rejected)
            }
            _reset()
        } else if event is PointerCancelEvent {
            _checkLongPressCancel()
            _reset()
        } else if event is PointerDownEvent {
            // The first touch.
            _longPressOrigin = OffsetPair.fromEventPosition(event)
            _initialButtons = event.buttons
            _checkLongPressDown(event as! PointerDownEvent)
        } else if event is PointerMoveEvent {
            if event.buttons != _initialButtons && !_longPressAccepted {
                resolve(.rejected)
                stopTrackingPointer(primaryPointer!)
            } else if _longPressAccepted {
                _checkLongPressMoveUpdate(event)
            }
        }
    }

    // MARK: - Private Check Methods

    /// **Dart Source:** `long_press.dart:688-714`
    private func _checkLongPressDown(_ event: PointerDownEvent) {
        assert(_longPressOrigin != nil)
        let details = LongPressDownDetails(
            globalPosition: _longPressOrigin!.global,
            localPosition: _longPressOrigin!.local,
            kind: getKindForPointer(event.pointer)
        )
        switch _initialButtons {
        case kPrimaryButton:
            if onLongPressDown != nil {
                invokeCallback("onLongPressDown", { self.onLongPressDown!(details) })
            }
        case kSecondaryButton:
            if onSecondaryLongPressDown != nil {
                invokeCallback(
                    "onSecondaryLongPressDown",
                    { self.onSecondaryLongPressDown!(details) }
                )
            }
        case kTertiaryButton:
            if onTertiaryLongPressDown != nil {
                invokeCallback("onTertiaryLongPressDown", { self.onTertiaryLongPressDown!(details) })
            }
        default:
            assert(false, "Unhandled button \(String(describing: _initialButtons))")
        }
    }

    /// **Dart Source:** `long_press.dart:716-735`
    private func _checkLongPressCancel() {
        if state == .possible {
            switch _initialButtons {
            case kPrimaryButton:
                if onLongPressCancel != nil {
                    invokeCallback("onLongPressCancel", onLongPressCancel!)
                }
            case kSecondaryButton:
                if onSecondaryLongPressCancel != nil {
                    invokeCallback("onSecondaryLongPressCancel", onSecondaryLongPressCancel!)
                }
            case kTertiaryButton:
                if onTertiaryLongPressCancel != nil {
                    invokeCallback("onTertiaryLongPressCancel", onTertiaryLongPressCancel!)
                }
            default:
                assert(false, "Unhandled button \(String(describing: _initialButtons))")
            }
        }
    }

    /// **Dart Source:** `long_press.dart:737-781`
    private func _checkLongPressStart() {
        switch _initialButtons {
        case kPrimaryButton:
            if onLongPressStart != nil {
                let details = LongPressStartDetails(
                    globalPosition: _longPressOrigin!.global,
                    localPosition: _longPressOrigin!.local
                )
                invokeCallback("onLongPressStart", { self.onLongPressStart!(details) })
            }
            if onLongPress != nil {
                invokeCallback("onLongPress", onLongPress!)
            }
        case kSecondaryButton:
            if onSecondaryLongPressStart != nil {
                let details = LongPressStartDetails(
                    globalPosition: _longPressOrigin!.global,
                    localPosition: _longPressOrigin!.local
                )
                invokeCallback(
                    "onSecondaryLongPressStart",
                    { self.onSecondaryLongPressStart!(details) }
                )
            }
            if onSecondaryLongPress != nil {
                invokeCallback("onSecondaryLongPress", onSecondaryLongPress!)
            }
        case kTertiaryButton:
            if onTertiaryLongPressStart != nil {
                let details = LongPressStartDetails(
                    globalPosition: _longPressOrigin!.global,
                    localPosition: _longPressOrigin!.local
                )
                invokeCallback(
                    "onTertiaryLongPressStart",
                    { self.onTertiaryLongPressStart!(details) }
                )
            }
            if onTertiaryLongPress != nil {
                invokeCallback("onTertiaryLongPress", onTertiaryLongPress!)
            }
        default:
            assert(false, "Unhandled button \(String(describing: _initialButtons))")
        }
    }

    /// **Dart Source:** `long_press.dart:783-812`
    private func _checkLongPressMoveUpdate(_ event: PointerEvent) {
        let details = LongPressMoveUpdateDetails(
            globalPosition: event.position,
            localPosition: event.localPosition,
            offsetFromOrigin: event.position - _longPressOrigin!.global,
            localOffsetFromOrigin: event.localPosition - _longPressOrigin!.local
        )
        switch _initialButtons {
        case kPrimaryButton:
            if onLongPressMoveUpdate != nil {
                invokeCallback("onLongPressMoveUpdate", { self.onLongPressMoveUpdate!(details) })
            }
        case kSecondaryButton:
            if onSecondaryLongPressMoveUpdate != nil {
                invokeCallback(
                    "onSecondaryLongPressMoveUpdate",
                    { self.onSecondaryLongPressMoveUpdate!(details) }
                )
            }
        case kTertiaryButton:
            if onTertiaryLongPressMoveUpdate != nil {
                invokeCallback(
                    "onTertiaryLongPressMoveUpdate",
                    { self.onTertiaryLongPressMoveUpdate!(details) }
                )
            }
        default:
            assert(false, "Unhandled button \(String(describing: _initialButtons))")
        }
    }

    /// **Dart Source:** `long_press.dart:814-851`
    private func _checkLongPressEnd(_ event: PointerEvent) {
        let estimate = _velocityTracker!.getVelocityEstimate()
        let velocity = estimate == nil
            ? Velocity.zero
            : Velocity(pixelsPerSecond: estimate!.pixelsPerSecond)
        let details = LongPressEndDetails(
            globalPosition: event.position,
            localPosition: event.localPosition,
            velocity: velocity
        )

        _velocityTracker = nil
        switch _initialButtons {
        case kPrimaryButton:
            if onLongPressEnd != nil {
                invokeCallback("onLongPressEnd", { self.onLongPressEnd!(details) })
            }
            if onLongPressUp != nil {
                invokeCallback("onLongPressUp", onLongPressUp!)
            }
        case kSecondaryButton:
            if onSecondaryLongPressEnd != nil {
                invokeCallback("onSecondaryLongPressEnd", { self.onSecondaryLongPressEnd!(details) })
            }
            if onSecondaryLongPressUp != nil {
                invokeCallback("onSecondaryLongPressUp", onSecondaryLongPressUp!)
            }
        case kTertiaryButton:
            if onTertiaryLongPressEnd != nil {
                invokeCallback("onTertiaryLongPressEnd", { self.onTertiaryLongPressEnd!(details) })
            }
            if onTertiaryLongPressUp != nil {
                invokeCallback("onTertiaryLongPressUp", onTertiaryLongPressUp!)
            }
        default:
            assert(false, "Unhandled button \(String(describing: _initialButtons))")
        }
    }

    /// **Dart Source:** `long_press.dart:853-858`
    private func _reset() {
        _longPressAccepted = false
        _longPressOrigin = nil
        _initialButtons = nil
        _velocityTracker = nil
    }

    // MARK: - Resolution

    /// **Dart Source:** `long_press.dart:861-872`
    public override func resolve(_ disposition: GestureDisposition) {
        if disposition == .rejected {
            if _longPressAccepted {
                // This can happen if the gesture has been canceled. For example when
                // the buttons have changed.
                _reset()
            } else {
                _checkLongPressCancel()
            }
        }
        super.resolve(disposition)
    }

    // MARK: - Arena

    /// **Dart Source:** `long_press.dart:875-878`
    public override func acceptGesture(_ pointer: Int) {
        // Winning the arena isn't important here since it may happen from a sweep.
        // Explicitly exceeding the deadline puts the gesture in accepted state.
    }

    // MARK: - Debug Description

    /// **Dart Source:** `long_press.dart:881`
    public override var debugDescription: String {
        return "long press"
    }
}

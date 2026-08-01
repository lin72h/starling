// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tap gesture recognizer and related types.
///
/// Recognizes taps, including primary, secondary, and tertiary button taps.
/// The tap gesture is a sequence of events that starts with a down, followed
/// by optional moves, then ends with an up. All move events must contain the
/// same `buttons` as the down event, and must not be too far from the initial
/// position.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/tap.dart`
/// **Lines:** 1-817

import FlutterSwiftBridge
import Foundation

// MARK: - TapDownDetails

/// Details for `GestureTapDownCallback`, such as position.
///
/// See also:
///
///  * `GestureDetector.onTapDown`, which receives this information.
///  * `TapGestureRecognizer`, which passes this information to one of its callbacks.
///
/// **Dart Source:** `tap.dart:32-55`
public struct TapDownDetails: PositionedGestureDetails {

    /// Creates details for a `GestureTapDownCallback`.
    ///
    /// **Dart Source:** `tap.dart:34-35`
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
    /// **Dart Source:** `tap.dart:39`
    public let globalPosition: Offset

    /// The local position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `tap.dart:43`
    public let localPosition: Offset

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** `tap.dart:46`
    public let kind: PointerDeviceKind?
}

// MARK: - TapUpDetails

/// Details for `GestureTapUpCallback`, such as position.
///
/// See also:
///
///  * `GestureDetector.onTapUp`, which receives this information.
///  * `TapGestureRecognizer`, which passes this information to one of its callbacks.
///
/// **Dart Source:** `tap.dart:77-100`
public struct TapUpDetails: PositionedGestureDetails {

    /// Creates a `TapUpDetails` data object.
    ///
    /// **Dart Source:** `tap.dart:79-80`
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil,
        kind: PointerDeviceKind
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.kind = kind
    }

    /// The global position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** `tap.dart:84`
    public let globalPosition: Offset

    /// The local position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** `tap.dart:88`
    public let localPosition: Offset

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** `tap.dart:91`
    public let kind: PointerDeviceKind
}

// MARK: - TapMoveDetails

/// Details object for callbacks that use `GestureTapMoveCallback`.
///
/// See also:
///
///  * `GestureDetector.onTapMove`, which receives this information.
///  * `TapGestureRecognizer`, which passes this information to one of its callbacks.
///
/// **Dart Source:** `tap.dart:108-129`
public struct TapMoveDetails {

    /// Creates a `TapMoveDetails` data object.
    ///
    /// **Dart Source:** `tap.dart:110-115`
    public init(
        kind: PointerDeviceKind,
        globalPosition: Offset = .zero,
        delta: Offset = .zero,
        localPosition: Offset? = nil
    ) {
        self.kind = kind
        self.globalPosition = globalPosition
        self.delta = delta
        self.localPosition = localPosition ?? globalPosition
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `tap.dart:118`
    public let globalPosition: Offset

    /// The local position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** `tap.dart:121`
    public let localPosition: Offset

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** `tap.dart:124`
    public let kind: PointerDeviceKind

    /// The amount the pointer has moved in the coordinate space of the
    /// event receiver since the previous update.
    ///
    /// **Dart Source:** `tap.dart:128`
    public let delta: Offset
}

// MARK: - Callback Typealiases

/// Signature for when a pointer that might cause a tap has contacted the
/// screen.
///
/// The position at which the pointer contacted the screen is available in the
/// `details`.
///
/// See also:
///
///  * `GestureDetector.onTapDown`, which matches this signature.
///  * `TapGestureRecognizer`, which uses this signature in one of its callbacks.
///
/// **Dart Source:** `tap.dart:57-69`
public typealias GestureTapDownCallback = (_ details: TapDownDetails) -> Void

/// Signature for when a pointer that will trigger a tap has stopped contacting
/// the screen.
///
/// The position at which the pointer stopped contacting the screen is available
/// in the `details`.
///
/// See also:
///
///  * `GestureDetector.onTapUp`, which matches this signature.
///  * `TapGestureRecognizer`, which uses this signature in one of its callbacks.
///
/// **Dart Source:** `tap.dart:131-143`
public typealias GestureTapUpCallback = (_ details: TapUpDetails) -> Void

/// Signature for when a tap has occurred.
///
/// See also:
///
///  * `GestureDetector.onTap`, which matches this signature.
///  * `TapGestureRecognizer`, which uses this signature in one of its callbacks.
///
/// **Dart Source:** `tap.dart:145-151`
public typealias GestureTapCallback = () -> Void

/// Signature for when a pointer that triggered a tap has moved.
///
/// The position at which the pointer moved is available in the `details`.
///
/// See also:
///
///  * `GestureDetector.onTapMove`, which matches this signature.
///  * `TapGestureRecognizer`, which uses this signature in one of its callbacks.
///
/// **Dart Source:** `tap.dart:153-161`
public typealias GestureTapMoveCallback = (_ details: TapMoveDetails) -> Void

/// Signature for when the pointer that previously triggered a
/// `GestureTapDownCallback` will not end up causing a tap.
///
/// See also:
///
///  * `GestureDetector.onTapCancel`, which matches this signature.
///  * `TapGestureRecognizer`, which uses this signature in one of its callbacks.
///
/// **Dart Source:** `tap.dart:163-170`
public typealias GestureTapCancelCallback = () -> Void

// MARK: - BaseTapGestureRecognizer

/// A base class for gesture recognizers that recognize taps.
///
/// Gesture recognizers take part in gesture arenas to enable potential gestures
/// to be disambiguated from each other. This process is managed by a
/// `GestureArenaManager`.
///
/// A tap is defined as a sequence of events that starts with a down, followed
/// by optional moves, then ends with an up. All move events must contain the
/// same `buttons` as the down event, and must not be too far from the initial
/// position. The gesture is rejected on any violation, a cancel event, or
/// if any other recognizers wins the arena. It is accepted only when it is the
/// last member of the arena.
///
/// The `BaseTapGestureRecognizer` considers all the pointers involved in the
/// pointer event sequence as contributing to one gesture. For this reason,
/// extra pointer interactions during a tap sequence are not recognized as
/// additional taps. For example, down-1, down-2, up-1, up-2 produces only one
/// tap on up-1.
///
/// The `BaseTapGestureRecognizer` can not be directly used, since it does not
/// define which buttons to accept, or what to do when a tap happens. If you
/// want to build a custom tap recognizer, extend this class by overriding
/// `isPointerAllowed` and the handler methods.
///
/// See also:
///
///  * `TapGestureRecognizer`, a ready-to-use tap recognizer that recognizes
///    taps of the primary button and taps of the secondary button.
///
/// **Dart Source:** `tap.dart:202-427`
///
/// DIFFERENCE FROM DART: In Dart, this is an abstract class. In Swift, it is
/// an open class. Subclasses must override `handleTapDown`, `handleTapUp`,
/// and `handleTapCancel`.
open class BaseTapGestureRecognizer: PrimaryPointerGestureRecognizer {

    /// Creates a tap gesture recognizer.
    ///
    /// **Dart Source:** `tap.dart:206-212`
    public init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { _ in true },
        preAcceptSlopTolerance: Double? = _unsetTouchSlop,
        postAcceptSlopTolerance: Double? = _unsetTouchSlop
    ) {
        super.init(
            deadline: kPressTimeout,
            preAcceptSlopTolerance: preAcceptSlopTolerance,
            postAcceptSlopTolerance: postAcceptSlopTolerance,
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    /// **Dart Source:** `tap.dart:214`
    private var _sentTapDown: Bool = false

    /// **Dart Source:** `tap.dart:215`
    private var _wonArenaForPrimaryPointer: Bool = false

    /// **Dart Source:** `tap.dart:217`
    private var _down: PointerDownEvent?

    /// **Dart Source:** `tap.dart:218`
    private var _up: PointerUpEvent?

    // MARK: - Abstract Handler Methods

    /// A pointer has contacted the screen, which might be the start of a tap.
    ///
    /// This triggers after the down event, once a short timeout (`deadline`) has
    /// elapsed, or once the gesture has won the arena, whichever comes first.
    ///
    /// The parameter `down` is the down event of the primary pointer that started
    /// the tap sequence.
    ///
    /// If this recognizer doesn't win the arena, `handleTapCancel` is called next.
    /// Otherwise, `handleTapUp` is called next.
    ///
    /// **Dart Source:** `tap.dart:220-231`
    open func handleTapDown(down: PointerDownEvent) {
        // Subclasses must override this method.
    }

    /// A pointer has stopped contacting the screen, which is recognized as a tap.
    ///
    /// This triggers on the up event if the recognizer wins the arena with it
    /// or has previously won.
    ///
    /// The parameter `down` is the down event of the primary pointer that started
    /// the tap sequence, and `up` is the up event that ended the tap sequence.
    ///
    /// If this recognizer doesn't win the arena, `handleTapCancel` is called
    /// instead.
    ///
    /// **Dart Source:** `tap.dart:233-244`
    open func handleTapUp(down: PointerDownEvent, up: PointerUpEvent) {
        // Subclasses must override this method.
    }

    /// A pointer that triggered a tap has moved.
    ///
    /// This triggers on the move event if the recognizer has recognized the tap gesture.
    ///
    /// The parameter `move` is the move event of the primary pointer that started
    /// the tap sequence.
    ///
    /// **Dart Source:** `tap.dart:246-253`
    open func handleTapMove(move: PointerMoveEvent) {
        // Default implementation does nothing.
    }

    /// A pointer that previously triggered `handleTapDown` will not end up
    /// causing a tap.
    ///
    /// This triggers once the gesture loses the arena if `handleTapDown` has
    /// been previously triggered.
    ///
    /// The parameter `down` is the down event of the primary pointer that started
    /// the tap sequence; `cancel` is the cancel event, which might be nil;
    /// `reason` is a short description of the cause if `cancel` is nil, which
    /// can be "forced" if other gestures won the arena, or "spontaneous"
    /// otherwise.
    ///
    /// If this recognizer wins the arena, `handleTapUp` is called instead.
    ///
    /// **Dart Source:** `tap.dart:255-273`
    open func handleTapCancel(
        down: PointerDownEvent,
        cancel: PointerCancelEvent?,
        reason: String
    ) {
        // Subclasses must override this method.
    }

    // MARK: - Pointer Handling

    /// **Dart Source:** `tap.dart:276-299`
    open override func addAllowedPointer(_ event: PointerDownEvent) {
        if state == .ready {
            // If there is no result in the previous gesture arena,
            // we ignore them and prepare to accept a new pointer.
            if _down != nil && _up != nil {
                assert(_down!.pointer == _up!.pointer)
                _reset()
            }

            assert(_down == nil && _up == nil)
            // `_down` must be assigned in this method instead of `handlePrimaryPointer`,
            // because `acceptGesture` might be called before `handlePrimaryPointer`,
            // which relies on `_down` to call `handleTapDown`.
            _down = event
        }
        if _down != nil {
            // This happens when this tap gesture has been rejected while the pointer
            // is down (i.e. due to movement), when another allowed pointer is added,
            // in which case all pointers are ignored. The `_down` being nil
            // means that _reset() has been called, since it is always set at the
            // first allowed down event and will not be cleared except for reset(),
            super.addAllowedPointer(event)
        }
    }

    /// **Dart Source:** `tap.dart:301-308`
    open override func startTrackingPointer(_ pointer: Int, _ transform: Matrix4? = nil) {
        // The recognizer should never track any pointers when `_down` is nil,
        // because calling `_checkDown` in this state will throw exception.
        assert(_down != nil)
        super.startTrackingPointer(pointer, transform)
    }

    /// **Dart Source:** `tap.dart:310-327`
    open override func handlePrimaryPointer(_ event: PointerEvent) {
        if event is PointerUpEvent {
            _up = event as? PointerUpEvent
            _checkUp()
        } else if event is PointerCancelEvent {
            resolve(.rejected)
            if _sentTapDown {
                _checkCancel(event as? PointerCancelEvent, "")
            }
            _reset()
        } else if event.buttons != _down!.buttons {
            resolve(.rejected)
            stopTrackingPointer(primaryPointer!)
        } else if event is PointerMoveEvent {
            _checkMove(event as! PointerMoveEvent)
        }
    }

    /// **Dart Source:** `tap.dart:329-339`
    open override func resolve(_ disposition: GestureDisposition) {
        if _wonArenaForPrimaryPointer && disposition == .rejected {
            // This can happen if the gesture has been canceled. For example, when
            // the pointer has exceeded the touch slop, the buttons have been changed,
            // or if the recognizer is disposed.
            assert(_sentTapDown)
            _checkCancel(nil, "spontaneous")
            _reset()
        }
        super.resolve(disposition)
    }

    /// **Dart Source:** `tap.dart:341-345`
    open override func didExceedDeadline() {
        _checkDown()
    }

    /// **Dart Source:** `tap.dart:347-355`
    open override func acceptGesture(_ pointer: Int) {
        super.acceptGesture(pointer)
        if pointer == primaryPointer {
            _checkDown()
            _wonArenaForPrimaryPointer = true
            _checkUp()
        }
    }

    /// **Dart Source:** `tap.dart:357-368`
    open override func rejectGesture(_ pointer: Int) {
        super.rejectGesture(pointer)
        if pointer == primaryPointer {
            // Another gesture won the arena.
            assert(state != .possible)
            if _sentTapDown {
                _checkCancel(nil, "forced")
            }
            _reset()
        }
    }

    // MARK: - Private Helpers

    /// **Dart Source:** `tap.dart:370-376`
    private func _checkDown() {
        if _sentTapDown {
            return
        }
        handleTapDown(down: _down!)
        _sentTapDown = true
    }

    /// **Dart Source:** `tap.dart:378-385`
    private func _checkUp() {
        if !_wonArenaForPrimaryPointer || _up == nil {
            return
        }
        assert(_up!.pointer == _down!.pointer)
        handleTapUp(down: _down!, up: _up!)
        _reset()
    }

    /// **Dart Source:** `tap.dart:387-389`
    private func _checkCancel(_ event: PointerCancelEvent?, _ note: String) {
        handleTapCancel(down: _down!, cancel: event, reason: note)
    }

    /// **Dart Source:** `tap.dart:391-394`
    private func _checkMove(_ event: PointerMoveEvent) {
        assert(event.pointer == _down!.pointer)
        handleTapMove(move: event)
    }

    /// **Dart Source:** `tap.dart:396-401`
    private func _reset() {
        _sentTapDown = false
        _wonArenaForPrimaryPointer = false
        _up = nil
        _down = nil
    }

    // MARK: - Debug Description

    /// **Dart Source:** `tap.dart:403-404`
    open override var debugDescription: String {
        return "base tap"
    }
}

// MARK: - TapGestureRecognizer

/// Recognizes taps.
///
/// Gesture recognizers take part in gesture arenas to enable potential gestures
/// to be disambiguated from each other. This process is managed by a
/// `GestureArenaManager`.
///
/// `TapGestureRecognizer` considers all the pointers involved in the pointer
/// event sequence as contributing to one gesture. For this reason, extra
/// pointer interactions during a tap sequence are not recognized as additional
/// taps. For example, down-1, down-2, up-1, up-2 produces only one tap on up-1.
///
/// `TapGestureRecognizer` competes on pointer events of `kPrimaryButton` only
/// when it has at least one non-nil `onTap*` callback, on events of
/// `kSecondaryButton` only when it has at least one non-nil `onSecondaryTap*`
/// callback, and on events of `kTertiaryButton` only when it has at least
/// one non-nil `onTertiaryTap*` callback. If it has no callbacks, it is a
/// no-op.
///
/// The `allowedButtonsFilter` argument only gives this recognizer the
/// ability to limit the buttons it accepts. It does not provide the
/// ability to recognize any buttons beyond the ones it already accepts:
/// kPrimaryButton, kSecondaryButton or kTertiaryButton. Therefore, a
/// combined value of `kPrimaryButton & kSecondaryButton` would be ignored,
/// but `kPrimaryButton | kSecondaryButton` would be allowed, as long as
/// only one of them is selected at a time.
///
/// See also:
///
///  * `GestureDetector.onTap`, which uses this recognizer.
///  * `MultiTapGestureRecognizer`
///
/// **Dart Source:** `tap.dart:461-816`
public class TapGestureRecognizer: BaseTapGestureRecognizer {

    /// Creates a tap gesture recognizer.
    ///
    /// **Dart Source:** `tap.dart:465-471`
    public override init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { _ in true },
        preAcceptSlopTolerance: Double? = _unsetTouchSlop,
        postAcceptSlopTolerance: Double? = _unsetTouchSlop
    ) {
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter,
            preAcceptSlopTolerance: preAcceptSlopTolerance,
            postAcceptSlopTolerance: postAcceptSlopTolerance
        )
    }

    // MARK: - Primary Button Callbacks

    /// A pointer has contacted the screen at a particular location with a primary
    /// button, which might be the start of a tap.
    ///
    /// This triggers after the down event, once a short timeout (`deadline`) has
    /// elapsed, or once the gestures has won the arena, whichever comes first.
    ///
    /// If this recognizer doesn't win the arena, `onTapCancel` is called next.
    /// Otherwise, `onTapUp` is called next.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///  * `onSecondaryTapDown`, a similar callback but for a secondary button.
    ///  * `onTertiaryTapDown`, a similar callback but for a tertiary button.
    ///  * `TapDownDetails`, which is passed as an argument to this callback.
    ///  * `GestureDetector.onTapDown`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:473-491`
    public var onTapDown: GestureTapDownCallback?

    /// A pointer has stopped contacting the screen at a particular location,
    /// which is recognized as a tap of a primary button.
    ///
    /// This triggers on the up event, if the recognizer wins the arena with it
    /// or has previously won, immediately followed by `onTap`.
    ///
    /// If this recognizer doesn't win the arena, `onTapCancel` is called instead.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///  * `onSecondaryTapUp`, a similar callback but for a secondary button.
    ///  * `onTertiaryTapUp`, a similar callback but for a tertiary button.
    ///  * `TapUpDetails`, which is passed as an argument to this callback.
    ///  * `GestureDetector.onTapUp`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:493-510`
    public var onTapUp: GestureTapUpCallback?

    /// A pointer has stopped contacting the screen, which is recognized as a tap
    /// of a primary button.
    ///
    /// This triggers on the up event, if the recognizer wins the arena with it
    /// or has previously won, immediately following `onTapUp`.
    ///
    /// If this recognizer doesn't win the arena, `onTapCancel` is called instead.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///  * `onSecondaryTap`, a similar callback but for a secondary button.
    ///  * `onTapUp`, which has the same timing but with details.
    ///  * `GestureDetector.onTap`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:512-526`
    public var onTap: GestureTapCallback?

    /// A pointer that triggered a tap has moved.
    ///
    /// This callback is triggered after the tap gesture has been recognized and
    /// the pointer starts to move.
    ///
    /// If the pointer moves beyond the `postAcceptSlopTolerance` distance, the
    /// tap will be canceled. To make `onTapMove` more useful, consider setting
    /// `postAcceptSlopTolerance` to a larger value, or to nil for no limit on
    /// movement.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///  * `GestureDetector.onTapMove`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:528-540`
    public var onTapMove: GestureTapMoveCallback?

    /// A pointer that previously triggered `onTapDown` will not end up causing
    /// a tap.
    ///
    /// This triggers once the gesture loses the arena if `onTapDown` has
    /// previously been triggered.
    ///
    /// If this recognizer wins the arena, `onTapUp` and `onTap` are called
    /// instead.
    ///
    /// See also:
    ///
    ///  * `kPrimaryButton`, the button this callback responds to.
    ///  * `onSecondaryTapCancel`, a similar callback but for a secondary button.
    ///  * `onTertiaryTapCancel`, a similar callback but for a tertiary button.
    ///  * `GestureDetector.onTapCancel`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:542-559`
    public var onTapCancel: GestureTapCancelCallback?

    // MARK: - Secondary Button Callbacks

    /// A pointer has stopped contacting the screen, which is recognized as a tap
    /// of a secondary button.
    ///
    /// This triggers on the up event, if the recognizer wins the arena with it or
    /// has previously won, immediately following `onSecondaryTapUp`.
    ///
    /// If this recognizer doesn't win the arena, `onSecondaryTapCancel` is called
    /// instead.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///  * `onSecondaryTapUp`, which has the same timing but with details.
    ///  * `GestureDetector.onSecondaryTap`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:561-577`
    public var onSecondaryTap: GestureTapCallback?

    /// A pointer has contacted the screen at a particular location with a
    /// secondary button, which might be the start of a secondary tap.
    ///
    /// This triggers after the down event, once a short timeout (`deadline`) has
    /// elapsed, or once the gestures has won the arena, whichever comes first.
    ///
    /// If this recognizer doesn't win the arena, `onSecondaryTapCancel` is called
    /// next. Otherwise, `onSecondaryTapUp` is called next.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///  * `onTapDown`, a similar callback but for a primary button.
    ///  * `onTertiaryTapDown`, a similar callback but for a tertiary button.
    ///  * `TapDownDetails`, which is passed as an argument to this callback.
    ///  * `GestureDetector.onSecondaryTapDown`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:579-597`
    public var onSecondaryTapDown: GestureTapDownCallback?

    /// A pointer has stopped contacting the screen at a particular location,
    /// which is recognized as a tap of a secondary button.
    ///
    /// This triggers on the up event if the recognizer wins the arena with it
    /// or has previously won.
    ///
    /// If this recognizer doesn't win the arena, `onSecondaryTapCancel` is called
    /// instead.
    ///
    /// See also:
    ///
    ///  * `onSecondaryTap`, a handler triggered right after this one that doesn't
    ///    pass any details about the tap.
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///  * `onTapUp`, a similar callback but for a primary button.
    ///  * `onTertiaryTapUp`, a similar callback but for a tertiary button.
    ///  * `TapUpDetails`, which is passed as an argument to this callback.
    ///  * `GestureDetector.onSecondaryTapUp`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:599-619`
    public var onSecondaryTapUp: GestureTapUpCallback?

    /// A pointer that previously triggered `onSecondaryTapDown` will not end up
    /// causing a tap.
    ///
    /// This triggers once the gesture loses the arena if `onSecondaryTapDown`
    /// has previously been triggered.
    ///
    /// If this recognizer wins the arena, `onSecondaryTapUp` is called instead.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///  * `onTapCancel`, a similar callback but for a primary button.
    ///  * `onTertiaryTapCancel`, a similar callback but for a tertiary button.
    ///  * `GestureDetector.onSecondaryTapCancel`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:621-637`
    public var onSecondaryTapCancel: GestureTapCancelCallback?

    // MARK: - Tertiary Button Callbacks

    /// A pointer has contacted the screen at a particular location with a
    /// tertiary button, which might be the start of a tertiary tap.
    ///
    /// This triggers after the down event, once a short timeout (`deadline`) has
    /// elapsed, or once the gestures has won the arena, whichever comes first.
    ///
    /// If this recognizer doesn't win the arena, `onTertiaryTapCancel` is called
    /// next. Otherwise, `onTertiaryTapUp` is called next.
    ///
    /// See also:
    ///
    ///  * `kTertiaryButton`, the button this callback responds to.
    ///  * `onTapDown`, a similar callback but for a primary button.
    ///  * `onSecondaryTapDown`, a similar callback but for a secondary button.
    ///  * `TapDownDetails`, which is passed as an argument to this callback.
    ///  * `GestureDetector.onTertiaryTapDown`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:639-655`
    public var onTertiaryTapDown: GestureTapDownCallback?

    /// A pointer has stopped contacting the screen at a particular location,
    /// which is recognized as a tap of a tertiary button.
    ///
    /// This triggers on the up event if the recognizer wins the arena with it
    /// or has previously won.
    ///
    /// If this recognizer doesn't win the arena, `onTertiaryTapCancel` is called
    /// instead.
    ///
    /// See also:
    ///
    ///  * `kTertiaryButton`, the button this callback responds to.
    ///  * `onTapUp`, a similar callback but for a primary button.
    ///  * `onSecondaryTapUp`, a similar callback but for a secondary button.
    ///  * `TapUpDetails`, which is passed as an argument to this callback.
    ///  * `GestureDetector.onTertiaryTapUp`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:657-673`
    public var onTertiaryTapUp: GestureTapUpCallback?

    /// A pointer that previously triggered `onTertiaryTapDown` will not end up
    /// causing a tap.
    ///
    /// This triggers once the gesture loses the arena if `onTertiaryTapDown`
    /// has previously been triggered.
    ///
    /// If this recognizer wins the arena, `onTertiaryTapUp` is called instead.
    ///
    /// See also:
    ///
    ///  * `kSecondaryButton`, the button this callback responds to.
    ///  * `onTapCancel`, a similar callback but for a primary button.
    ///  * `onSecondaryTapCancel`, a similar callback but for a secondary button.
    ///  * `GestureDetector.onTertiaryTapCancel`, which exposes this callback.
    ///
    /// **Dart Source:** `tap.dart:675-689`
    public var onTertiaryTapCancel: GestureTapCancelCallback?

    // MARK: - Pointer Filtering

    /// **Dart Source:** `tap.dart:691-717`
    public override func isPointerAllowed(_ event: PointerDownEvent) -> Bool {
        switch event.buttons {
        case kPrimaryButton:
            if onTapDown == nil
                && onTap == nil
                && onTapUp == nil
                && onTapCancel == nil
                && onTapMove == nil
            {
                return false
            }
        case kSecondaryButton:
            if onSecondaryTap == nil
                && onSecondaryTapDown == nil
                && onSecondaryTapUp == nil
                && onSecondaryTapCancel == nil
            {
                return false
            }
        case kTertiaryButton:
            if onTertiaryTapDown == nil
                && onTertiaryTapUp == nil
                && onTertiaryTapCancel == nil
            {
                return false
            }
        default:
            return false
        }
        return super.isPointerAllowed(event)
    }

    // MARK: - Tap Handler Overrides

    /// **Dart Source:** `tap.dart:719-742`
    public override func handleTapDown(down: PointerDownEvent) {
        let details = TapDownDetails(
            globalPosition: down.position,
            localPosition: down.localPosition,
            kind: getKindForPointer(down.pointer)
        )
        switch down.buttons {
        case kPrimaryButton:
            if onTapDown != nil {
                invokeCallback("onTapDown", { self.onTapDown!(details) })
            }
        case kSecondaryButton:
            if onSecondaryTapDown != nil {
                invokeCallback("onSecondaryTapDown", { self.onSecondaryTapDown!(details) })
            }
        case kTertiaryButton:
            if onTertiaryTapDown != nil {
                invokeCallback("onTertiaryTapDown", { self.onTertiaryTapDown!(details) })
            }
        default:
            break
        }
    }

    /// **Dart Source:** `tap.dart:744-773`
    public override func handleTapUp(down: PointerDownEvent, up: PointerUpEvent) {
        let details = TapUpDetails(
            globalPosition: up.position,
            localPosition: up.localPosition,
            kind: up.kind
        )
        switch down.buttons {
        case kPrimaryButton:
            if onTapUp != nil {
                invokeCallback("onTapUp", { self.onTapUp!(details) })
            }
            if onTap != nil {
                invokeCallback("onTap", self.onTap!)
            }
        case kSecondaryButton:
            if onSecondaryTapUp != nil {
                invokeCallback("onSecondaryTapUp", { self.onSecondaryTapUp!(details) })
            }
            if onSecondaryTap != nil {
                invokeCallback("onSecondaryTap", { self.onSecondaryTap!() })
            }
        case kTertiaryButton:
            if onTertiaryTapUp != nil {
                invokeCallback("onTertiaryTapUp", { self.onTertiaryTapUp!(details) })
            }
        default:
            break
        }
    }

    /// **Dart Source:** `tap.dart:775-787`
    public override func handleTapMove(move: PointerMoveEvent) {
        if onTapMove != nil && move.buttons == kPrimaryButton {
            let details = TapMoveDetails(
                kind: getKindForPointer(move.pointer),
                globalPosition: move.position,
                delta: move.delta,
                localPosition: move.localPosition
            )
            invokeCallback("onTapMove", { self.onTapMove!(details) })
        }
    }

    /// **Dart Source:** `tap.dart:789-812`
    public override func handleTapCancel(
        down: PointerDownEvent,
        cancel: PointerCancelEvent?,
        reason: String
    ) {
        let note = reason == "" ? reason : "\(reason) "
        switch down.buttons {
        case kPrimaryButton:
            if onTapCancel != nil {
                invokeCallback("\(note)onTapCancel", onTapCancel!)
            }
        case kSecondaryButton:
            if onSecondaryTapCancel != nil {
                invokeCallback("\(note)onSecondaryTapCancel", onSecondaryTapCancel!)
            }
        case kTertiaryButton:
            if onTertiaryTapCancel != nil {
                invokeCallback("\(note)onTertiaryTapCancel", onTertiaryTapCancel!)
            }
        default:
            break
        }
    }

    // MARK: - Debug Description

    /// **Dart Source:** `tap.dart:814-816`
    public override var debugDescription: String {
        return "tap"
    }
}

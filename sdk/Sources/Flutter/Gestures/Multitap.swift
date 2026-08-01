// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Multi-tap gesture recognizers and related types.
///
/// Implements `DoubleTapGestureRecognizer`, `MultiTapGestureRecognizer`,
/// and `SerialTapGestureRecognizer` along with their supporting types
/// such as `TapTracker`, `TapGesture`, `CountdownZoned`, and the
/// serial tap detail classes.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/multitap.dart`
/// **Lines:** 1-1048

import FlutterSwiftBridge
import Foundation

// MARK: - Callback Typealiases

/// Signature for callback when the user has tapped the screen at the same
/// location twice in quick succession.
///
/// See also:
///
///  * `GestureDetector.onDoubleTap`, which matches this signature.
///
/// **Dart Source:** multitap.dart:33
public typealias GestureDoubleTapCallback = () -> Void

/// Signature used by `MultiTapGestureRecognizer` for when a pointer that might
/// cause a tap has contacted the screen at a particular location.
///
/// **Dart Source:** multitap.dart:37
public typealias GestureMultiTapDownCallback = (_ pointer: Int, _ details: TapDownDetails) -> Void

/// Signature used by `MultiTapGestureRecognizer` for when a pointer that will
/// trigger a tap has stopped contacting the screen at a particular location.
///
/// **Dart Source:** multitap.dart:41
public typealias GestureMultiTapUpCallback = (_ pointer: Int, _ details: TapUpDetails) -> Void

/// Signature used by `MultiTapGestureRecognizer` for when a tap has occurred.
///
/// **Dart Source:** multitap.dart:44
public typealias GestureMultiTapCallback = (_ pointer: Int) -> Void

/// Signature for when the pointer that previously triggered a
/// `GestureMultiTapDownCallback` will not end up causing a tap.
///
/// **Dart Source:** multitap.dart:48
public typealias GestureMultiTapCancelCallback = (_ pointer: Int) -> Void

// MARK: - CountdownZoned

/// Tracks whether the specified duration has elapsed since creation.
///
/// **Dart Source:** multitap.dart:52-64
///
/// DIFFERENCE FROM DART: In Dart, this is file-private (`_CountdownZoned`).
/// In Swift, it is `internal` without underscore prefix.
internal class CountdownZoned {

    /// Creates a countdown zoned timer.
    ///
    /// **Dart Source:** multitap.dart:53-55
    init(duration: TimeInterval) {
        nonisolated(unsafe) let capturedSelf = self
        Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            capturedSelf._onTimeout()
        }
    }

    /// **Dart Source:** multitap.dart:57
    private var _timeout: Bool = false

    /// Whether the timeout has elapsed.
    ///
    /// **Dart Source:** multitap.dart:59
    var timeout: Bool { _timeout }

    /// **Dart Source:** multitap.dart:61-63
    private func _onTimeout() {
        _timeout = true
    }
}

// MARK: - TapTracker

/// Helps track individual tap sequences as part of a larger gesture.
///
/// **Dart Source:** multitap.dart:68-114
///
/// DIFFERENCE FROM DART: In Dart, this is file-private (`_TapTracker`).
/// In Swift, it is `internal` without underscore prefix.
///
/// DIFFERENCE FROM DART: In Dart, `PointerRoute` (a function typedef) is used
/// directly as a key for `addRoute`/`removeRoute`. In Swift, `addRoute` returns
/// a `PointerRouteEntry` token that must be stored and passed to `removeRoute`.
internal class TapTracker {

    /// Creates a tap tracker.
    ///
    /// **Dart Source:** multitap.dart:69-77
    init(
        event: PointerDownEvent,
        entry: GestureArenaEntry,
        doubleTapMinTime: TimeInterval,
        gestureSettings: DeviceGestureSettings?
    ) {
        self.pointer = event.pointer
        self._initialGlobalPosition = event.position
        self.initialButtons = event.buttons
        self.entry = entry
        self.gestureSettings = gestureSettings
        self._doubleTapMinTimeCountdown = CountdownZoned(duration: doubleTapMinTime)
    }

    /// **Dart Source:** multitap.dart:79
    let gestureSettings: DeviceGestureSettings?

    /// **Dart Source:** multitap.dart:80
    let pointer: Int

    /// **Dart Source:** multitap.dart:81
    let entry: GestureArenaEntry

    /// **Dart Source:** multitap.dart:82
    private let _initialGlobalPosition: Offset

    /// **Dart Source:** multitap.dart:83
    let initialButtons: Int

    /// **Dart Source:** multitap.dart:84
    private let _doubleTapMinTimeCountdown: CountdownZoned

    /// **Dart Source:** multitap.dart:86
    private var _isTrackingPointer: Bool = false

    /// The `PointerRouteEntry` token returned by `addRoute`, needed for `removeRoute`.
    ///
    /// DIFFERENCE FROM DART: In Dart, the route function reference is passed to
    /// both `addRoute` and `removeRoute`. In Swift, `addRoute` returns an opaque
    /// `PointerRouteEntry` token that must be stored and passed to `removeRoute`.
    private var _routeEntry: PointerRouteEntry?

    /// Starts tracking a pointer, registering a route and transform.
    ///
    /// **Dart Source:** multitap.dart:88-93
    func startTrackingPointer(_ route: @escaping PointerRoute, _ transform: Matrix4?) {
        if !_isTrackingPointer {
            _isTrackingPointer = true
            _routeEntry = GestureBinding.instance.pointerRouter.addRoute(pointer, route, transform)
        }
    }

    /// Stops tracking the pointer by removing the previously registered route.
    ///
    /// **Dart Source:** multitap.dart:95-100
    func stopTrackingPointer(_ route: @escaping PointerRoute) {
        if _isTrackingPointer {
            _isTrackingPointer = false
            if let routeEntry = _routeEntry {
                GestureBinding.instance.pointerRouter.removeRoute(pointer, routeEntry)
                _routeEntry = nil
            }
        }
    }

    /// Returns whether the given event is within the global tolerance of the
    /// initial position.
    ///
    /// **Dart Source:** multitap.dart:102-105
    func isWithinGlobalTolerance(_ event: PointerEvent, _ tolerance: Double) -> Bool {
        let offset = event.position - _initialGlobalPosition
        return offset.distance <= tolerance
    }

    /// Returns whether the minimum time has elapsed.
    ///
    /// **Dart Source:** multitap.dart:107-109
    func hasElapsedMinTime() -> Bool {
        return _doubleTapMinTimeCountdown.timeout
    }

    /// Returns whether the given event has the same button as this tracker.
    ///
    /// **Dart Source:** multitap.dart:111-113
    func hasSameButton(_ event: PointerDownEvent) -> Bool {
        return event.buttons == initialButtons
    }
}

// MARK: - DoubleTapGestureRecognizer

/// Recognizes when the user has tapped the screen at the same location twice in
/// quick succession.
///
/// `DoubleTapGestureRecognizer` competes on pointer events when it
/// has a non-nil callback. If it has no callbacks, it is a no-op.
///
/// **Dart Source:** multitap.dart:122-382
public class DoubleTapGestureRecognizer: GestureRecognizer {

    /// Create a gesture recognizer for double taps.
    ///
    /// **Dart Source:** multitap.dart:126-130
    public override init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { buttons in buttons == kPrimaryButton }
    ) {
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    // Implementation notes:
    //
    // The double tap recognizer can be in one of four states. There's no
    // explicit enum for the states, because they are already captured by
    // the state of existing fields. Specifically:
    //
    // 1. Waiting on first tap: In this state, the _trackers list is empty, and
    //    _firstTap is nil.
    // 2. First tap in progress: In this state, the _trackers list contains all
    //    the states for taps that have begun but not completed. This list can
    //    have more than one entry if two pointers begin to tap.
    // 3. Waiting on second tap: In this state, one of the in-progress taps has
    //    completed successfully. The _trackers list is again empty, and
    //    _firstTap records the successful tap.
    // 4. Second tap in progress: Much like the "first tap in progress" state, but
    //    _firstTap is non-nil. If a tap completes successfully while in this
    //    state, the callback is called and the state is reset.
    //
    // There are various other scenarios that cause the state to reset:
    //
    // - All in-progress taps are rejected (by time, distance, pointercancel, etc)
    // - The long timer between taps expires
    // - The gesture arena decides we have been rejected wholesale

    /// A pointer has contacted the screen with a primary button at the same
    /// location twice in quick succession, which might be the start of a double
    /// tap.
    ///
    /// This triggers immediately after the down event of the second tap.
    ///
    /// If this recognizer doesn't win the arena, `onDoubleTapCancel` is called
    /// next. Otherwise, `onDoubleTap` is called next.
    ///
    /// **Dart Source:** multitap.dart:174
    public var onDoubleTapDown: GestureTapDownCallback?

    /// Called when the user has tapped the screen with a primary button at the
    /// same location twice in quick succession.
    ///
    /// This triggers when the pointer stops contacting the device after the
    /// second tap.
    ///
    /// **Dart Source:** multitap.dart:186
    public var onDoubleTap: GestureDoubleTapCallback?

    /// A pointer that previously triggered `onDoubleTapDown` will not end up
    /// causing a double tap.
    ///
    /// This triggers once the gesture loses the arena if `onDoubleTapDown` has
    /// previously been triggered.
    ///
    /// If this recognizer wins the arena, `onDoubleTap` is called instead.
    ///
    /// **Dart Source:** multitap.dart:200
    public var onDoubleTapCancel: GestureTapCancelCallback?

    /// **Dart Source:** multitap.dart:202
    private var _doubleTapTimer: Timer?

    /// **Dart Source:** multitap.dart:203
    private var _firstTap: TapTracker?

    /// **Dart Source:** multitap.dart:204
    private var _trackers: [Int: TapTracker] = [:]

    // MARK: - Pointer Filtering

    /// **Dart Source:** multitap.dart:207-220
    public override func isPointerAllowed(_ event: PointerDownEvent) -> Bool {
        if _firstTap == nil {
            if onDoubleTapDown == nil && onDoubleTap == nil && onDoubleTapCancel == nil {
                return false
            }
        }

        // If second tap is not allowed, reset the state.
        let isAllowed = super.isPointerAllowed(event)
        if !isAllowed {
            _reset()
        }
        return isAllowed
    }

    // MARK: - Pointer Handling

    /// **Dart Source:** multitap.dart:223-243
    public override func addAllowedPointer(_ event: PointerDownEvent) {
        if _firstTap != nil {
            if !_firstTap!.isWithinGlobalTolerance(event, kDoubleTapSlop) {
                // Ignore out-of-bounds second taps.
                return
            } else if !_firstTap!.hasElapsedMinTime() || !_firstTap!.hasSameButton(event) {
                // Restart when the second tap is too close to the first (touch screens
                // often detect touches intermittently), or when buttons mismatch.
                _reset()
                return _trackTap(event)
            } else if onDoubleTapDown != nil {
                let details = TapDownDetails(
                    globalPosition: event.position,
                    localPosition: event.localPosition,
                    kind: getKindForPointer(event.pointer)
                )
                invokeCallback("onDoubleTapDown") { self.onDoubleTapDown!(details) }
            }
        }
        _trackTap(event)
    }

    /// **Dart Source:** multitap.dart:245-255
    private func _trackTap(_ event: PointerDownEvent) {
        _stopDoubleTapTimer()
        let tracker = TapTracker(
            event: event,
            entry: GestureBinding.instance.gestureArena.add(event.pointer, self),
            doubleTapMinTime: kDoubleTapMinTime,
            gestureSettings: gestureSettings
        )
        _trackers[event.pointer] = tracker
        tracker.startTrackingPointer(_handleEvent, event.transform)
    }

    /// **Dart Source:** multitap.dart:257-272
    private func _handleEvent(_ event: PointerEvent) {
        let tracker = _trackers[event.pointer]!
        if event is PointerUpEvent {
            if _firstTap == nil {
                _registerFirstTap(tracker)
            } else {
                _registerSecondTap(tracker)
            }
        } else if event is PointerMoveEvent {
            if !tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop) {
                _reject(tracker)
            }
        } else if event is PointerCancelEvent {
            _reject(tracker)
        }
    }

    // MARK: - Arena Resolution

    /// **Dart Source:** multitap.dart:275
    public override func acceptGesture(_ pointer: Int) {}

    /// **Dart Source:** multitap.dart:278-288
    public override func rejectGesture(_ pointer: Int) {
        var tracker = _trackers[pointer]
        // If tracker isn't in the list, check if this is the first tap tracker
        if tracker == nil && _firstTap != nil && _firstTap!.pointer == pointer {
            tracker = _firstTap
        }
        // If tracker is still nil, we rejected ourselves already
        if let tracker = tracker {
            _reject(tracker)
        }
    }

    /// **Dart Source:** multitap.dart:290-304
    private func _reject(_ tracker: TapTracker) {
        _trackers.removeValue(forKey: tracker.pointer)
        tracker.entry.resolve(.rejected)
        _freezeTracker(tracker)
        if _firstTap != nil {
            if tracker === _firstTap {
                _reset()
            } else {
                _checkCancel()
                if _trackers.isEmpty {
                    _reset()
                }
            }
        }
    }

    // MARK: - Lifecycle

    /// **Dart Source:** multitap.dart:307-310
    public override func dispose() {
        _reset()
        super.dispose()
    }

    /// **Dart Source:** multitap.dart:312-326
    private func _reset() {
        _stopDoubleTapTimer()
        if _firstTap != nil {
            if !_trackers.isEmpty {
                _checkCancel()
            }
            // Note, order is important below in order for the resolve -> reject logic
            // to work properly.
            let tracker = _firstTap!
            _firstTap = nil
            _reject(tracker)
            GestureBinding.instance.gestureArena.release(tracker.pointer)
        }
        _clearTrackers()
    }

    /// **Dart Source:** multitap.dart:328-337
    private func _registerFirstTap(_ tracker: TapTracker) {
        _startDoubleTapTimer()
        GestureBinding.instance.gestureArena.hold(tracker.pointer)
        // Note, order is important below in order for the clear -> reject logic to
        // work properly.
        _freezeTracker(tracker)
        _trackers.removeValue(forKey: tracker.pointer)
        _clearTrackers()
        _firstTap = tracker
    }

    /// **Dart Source:** multitap.dart:339-346
    private func _registerSecondTap(_ tracker: TapTracker) {
        _firstTap!.entry.resolve(.accepted)
        tracker.entry.resolve(.accepted)
        _freezeTracker(tracker)
        _trackers.removeValue(forKey: tracker.pointer)
        _checkUp(tracker.initialButtons)
        _reset()
    }

    /// **Dart Source:** multitap.dart:348-351
    private func _clearTrackers() {
        let trackerList = Array(_trackers.values)
        for tracker in trackerList {
            _reject(tracker)
        }
        assert(_trackers.isEmpty)
    }

    /// **Dart Source:** multitap.dart:353-355
    private func _freezeTracker(_ tracker: TapTracker) {
        tracker.stopTrackingPointer(_handleEvent)
    }

    // MARK: - Timer Management

    /// **Dart Source:** multitap.dart:357-359
    private func _startDoubleTapTimer() {
        if _doubleTapTimer == nil {
            nonisolated(unsafe) let capturedSelf = self
            _doubleTapTimer = Timer.scheduledTimer(
                withTimeInterval: kDoubleTapTimeout, repeats: false
            ) { _ in
                capturedSelf._reset()
            }
        }
    }

    /// **Dart Source:** multitap.dart:361-366
    private func _stopDoubleTapTimer() {
        if _doubleTapTimer != nil {
            _doubleTapTimer!.invalidate()
            _doubleTapTimer = nil
        }
    }

    // MARK: - Callback Checks

    /// **Dart Source:** multitap.dart:368-372
    private func _checkUp(_ buttons: Int) {
        if onDoubleTap != nil {
            invokeCallback("onDoubleTap", onDoubleTap!)
        }
    }

    /// **Dart Source:** multitap.dart:374-378
    private func _checkCancel() {
        if onDoubleTapCancel != nil {
            invokeCallback("onDoubleTapCancel", onDoubleTapCancel!)
        }
    }

    // MARK: - Debug Description

    /// **Dart Source:** multitap.dart:381
    public override var debugDescription: String {
        return "double tap"
    }
}

// MARK: - TapGesture

/// Represents a full gesture resulting from a single tap sequence,
/// as part of a `MultiTapGestureRecognizer`. Tap gestures are passive, meaning
/// that they will not preempt any other arena member in play.
///
/// **Dart Source:** multitap.dart:387-465
///
/// DIFFERENCE FROM DART: In Dart, this is file-private (`_TapGesture`) and
/// extends `_TapTracker`. In Swift, it is `internal` and extends `TapTracker`.
///
/// DIFFERENCE FROM DART: The reference to `gestureRecognizer` is `weak` to
/// avoid retain cycles, since the recognizer holds references to tap gestures
/// through its `_gestureMap`.
internal class TapGesture: TapTracker {

    /// Creates a tap gesture.
    ///
    /// **Dart Source:** multitap.dart:388-406
    init(
        gestureRecognizer: MultiTapGestureRecognizer,
        event: PointerEvent,
        longTapDelay: TimeInterval,
        gestureSettings: DeviceGestureSettings?
    ) {
        self._gestureRecognizer = gestureRecognizer
        self._lastPosition = OffsetPair.fromEventPosition(event)
        super.init(
            event: event as! PointerDownEvent,
            entry: GestureBinding.instance.gestureArena.add(event.pointer, gestureRecognizer),
            doubleTapMinTime: kDoubleTapMinTime,
            gestureSettings: gestureSettings
        )
        startTrackingPointer(handleEvent, event.transform)
        if longTapDelay > 0 {
            nonisolated(unsafe) let capturedSelf = self
            nonisolated(unsafe) let capturedEvent = event
            _timer = Timer.scheduledTimer(
                withTimeInterval: longTapDelay, repeats: false
            ) { _ in
                capturedSelf._timer = nil
                capturedSelf._gestureRecognizer?._dispatchLongTap(
                    capturedEvent.pointer, capturedSelf._lastPosition
                )
            }
        }
    }

    /// **Dart Source:** multitap.dart:408
    ///
    /// DIFFERENCE FROM DART: `weak` reference to avoid retain cycles.
    private weak var _gestureRecognizer: MultiTapGestureRecognizer?

    /// **Dart Source:** multitap.dart:410
    private var _wonArena: Bool = false

    /// **Dart Source:** multitap.dart:411
    private var _timer: Timer?

    /// **Dart Source:** multitap.dart:413
    private var _lastPosition: OffsetPair

    /// **Dart Source:** multitap.dart:414
    private var _finalPosition: OffsetPair?

    /// **Dart Source:** multitap.dart:416-431
    func handleEvent(_ event: PointerEvent) {
        assert(event.pointer == pointer)
        if event is PointerMoveEvent {
            if !isWithinGlobalTolerance(event, computeHitSlop(event.kind, gestureSettings)) {
                cancel()
            } else {
                _lastPosition = OffsetPair.fromEventPosition(event)
            }
        } else if event is PointerCancelEvent {
            cancel()
        } else if event is PointerUpEvent {
            stopTrackingPointer(handleEvent)
            _finalPosition = OffsetPair.fromEventPosition(event)
            _check()
        }
    }

    /// **Dart Source:** multitap.dart:434-438
    override func stopTrackingPointer(_ route: @escaping PointerRoute) {
        _timer?.invalidate()
        _timer = nil
        super.stopTrackingPointer(route)
    }

    /// **Dart Source:** multitap.dart:440-443
    func accept() {
        _wonArena = true
        _check()
    }

    /// **Dart Source:** multitap.dart:445-448
    func reject() {
        stopTrackingPointer(handleEvent)
        _gestureRecognizer?._dispatchCancel(pointer)
    }

    /// **Dart Source:** multitap.dart:450-458
    func cancel() {
        // If we won the arena already, then entry is resolved, so resolving
        // again is a no-op. But we still need to clean up our own state.
        if _wonArena {
            reject()
        } else {
            entry.resolve(.rejected)  // eventually calls reject()
        }
    }

    /// **Dart Source:** multitap.dart:460-464
    private func _check() {
        if _wonArena && _finalPosition != nil {
            _gestureRecognizer?._dispatchTap(pointer, _finalPosition!)
        }
    }
}

// MARK: - MultiTapGestureRecognizer

/// Recognizes taps on a per-pointer basis.
///
/// `MultiTapGestureRecognizer` considers each sequence of pointer events that
/// could constitute a tap independently of other pointers: For example, down-1,
/// down-2, up-1, up-2 produces two taps, on up-1 and up-2.
///
/// See also:
///
///  * `TapGestureRecognizer`
///
/// **Dart Source:** multitap.dart:476-607
public class MultiTapGestureRecognizer: GestureRecognizer {

    /// Creates a multi-tap gesture recognizer.
    ///
    /// The `longTapDelay` defaults to `0`, which means
    /// `onLongTapDown` is called immediately after `onTapDown`.
    ///
    /// **Dart Source:** multitap.dart:483-488
    public init(
        longTapDelay: TimeInterval = 0,
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { _ in true }
    ) {
        self.longTapDelay = longTapDelay
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    /// A pointer that might cause a tap has contacted the screen at a particular
    /// location.
    ///
    /// **Dart Source:** multitap.dart:492
    public var onTapDown: GestureMultiTapDownCallback?

    /// A pointer that will trigger a tap has stopped contacting the screen at a
    /// particular location.
    ///
    /// **Dart Source:** multitap.dart:496
    public var onTapUp: GestureMultiTapUpCallback?

    /// A tap has occurred.
    ///
    /// **Dart Source:** multitap.dart:499
    public var onTap: GestureMultiTapCallback?

    /// The pointer that previously triggered `onTapDown` will not end up causing
    /// a tap.
    ///
    /// **Dart Source:** multitap.dart:503
    public var onTapCancel: GestureMultiTapCancelCallback?

    /// The amount of time between `onTapDown` and `onLongTapDown`.
    ///
    /// **Dart Source:** multitap.dart:506
    public var longTapDelay: TimeInterval

    /// A pointer that might cause a tap is still in contact with the screen at a
    /// particular location after `longTapDelay`.
    ///
    /// **Dart Source:** multitap.dart:510
    public var onLongTapDown: GestureMultiTapDownCallback?

    /// **Dart Source:** multitap.dart:512
    private var _gestureMap: [Int: TapGesture] = [:]

    // MARK: - Pointer Handling

    /// **Dart Source:** multitap.dart:515-535
    public override func addAllowedPointer(_ event: PointerDownEvent) {
        assert(_gestureMap[event.pointer] == nil)
        _gestureMap[event.pointer] = TapGesture(
            gestureRecognizer: self,
            event: event,
            longTapDelay: longTapDelay,
            gestureSettings: gestureSettings
        )
        if onTapDown != nil {
            invokeCallback("onTapDown") {
                self.onTapDown!(
                    event.pointer,
                    TapDownDetails(
                        globalPosition: event.position,
                        localPosition: event.localPosition,
                        kind: event.kind
                    )
                )
            }
        }
    }

    // MARK: - Arena Resolution

    /// **Dart Source:** multitap.dart:538-541
    public override func acceptGesture(_ pointer: Int) {
        assert(_gestureMap[pointer] != nil)
        _gestureMap[pointer]!.accept()
    }

    /// **Dart Source:** multitap.dart:544-548
    public override func rejectGesture(_ pointer: Int) {
        assert(_gestureMap[pointer] != nil)
        _gestureMap[pointer]!.reject()
        assert(_gestureMap[pointer] == nil)
    }

    // MARK: - Dispatching

    /// **Dart Source:** multitap.dart:550-556
    internal func _dispatchCancel(_ pointer: Int) {
        assert(_gestureMap[pointer] != nil)
        _gestureMap.removeValue(forKey: pointer)
        if onTapCancel != nil {
            invokeCallback("onTapCancel") { self.onTapCancel!(pointer) }
        }
    }

    /// **Dart Source:** multitap.dart:558-576
    internal func _dispatchTap(_ pointer: Int, _ position: OffsetPair) {
        assert(_gestureMap[pointer] != nil)
        _gestureMap.removeValue(forKey: pointer)
        if onTapUp != nil {
            invokeCallback("onTapUp") {
                self.onTapUp!(
                    pointer,
                    TapUpDetails(
                        globalPosition: position.global,
                        localPosition: position.local,
                        kind: self.getKindForPointer(pointer)
                    )
                )
            }
        }
        if onTap != nil {
            invokeCallback("onTap") { self.onTap!(pointer) }
        }
    }

    /// **Dart Source:** multitap.dart:578-592
    internal func _dispatchLongTap(_ pointer: Int, _ lastPosition: OffsetPair) {
        assert(_gestureMap[pointer] != nil)
        if onLongTapDown != nil {
            invokeCallback("onLongTapDown") {
                self.onLongTapDown!(
                    pointer,
                    TapDownDetails(
                        globalPosition: lastPosition.global,
                        localPosition: lastPosition.local,
                        kind: self.getKindForPointer(pointer)
                    )
                )
            }
        }
    }

    // MARK: - Lifecycle

    /// **Dart Source:** multitap.dart:595-603
    public override func dispose() {
        let localGestures = Array(_gestureMap.values)
        for gesture in localGestures {
            gesture.cancel()
        }
        // Rejection of each gesture should cause it to be removed from our map
        assert(_gestureMap.isEmpty)
        super.dispose()
    }

    // MARK: - Debug Description

    /// **Dart Source:** multitap.dart:606
    public override var debugDescription: String {
        return "multitap"
    }
}

// MARK: - Serial Tap Callback Typealiases

/// Signature used by `SerialTapGestureRecognizer.onSerialTapDown` for when a
/// pointer that might cause a serial tap has contacted the screen at a
/// particular location.
///
/// **Dart Source:** multitap.dart:612
public typealias GestureSerialTapDownCallback = (_ details: SerialTapDownDetails) -> Void

/// Signature used by `SerialTapGestureRecognizer.onSerialTapCancel` for when a
/// pointer that previously triggered a `GestureSerialTapDownCallback` will not
/// end up completing the serial tap.
///
/// **Dart Source:** multitap.dart:678
public typealias GestureSerialTapCancelCallback = (_ details: SerialTapCancelDetails) -> Void

/// Signature used by `SerialTapGestureRecognizer.onSerialTapUp` for when a
/// pointer that will trigger a serial tap has stopped contacting the screen.
///
/// **Dart Source:** multitap.dart:710
public typealias GestureSerialTapUpCallback = (_ details: SerialTapUpDetails) -> Void

// MARK: - SerialTapDownDetails

/// Details for `GestureSerialTapDownCallback`, such as the tap count within
/// the series.
///
/// See also:
///
///  * `SerialTapGestureRecognizer`, which passes this information to its
///    `SerialTapGestureRecognizer.onSerialTapDown` callback.
///
/// **Dart Source:** multitap.dart:621-673
///
/// DIFFERENCE FROM DART: In Dart, this uses `with Diagnosticable implements
/// PositionedGestureDetails`. In Swift, it conforms to both `Diagnosticable`
/// and `PositionedGestureDetails` protocols. Implemented as a class (reference
/// type) to conform to `Diagnosticable` (which requires `AnyObject`).
public class SerialTapDownDetails: Diagnosticable, PositionedGestureDetails {

    /// Creates details for a `GestureSerialTapDownCallback`.
    ///
    /// The `count` argument must be greater than zero.
    ///
    /// **Dart Source:** multitap.dart:625-632
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil,
        kind: PointerDeviceKind,
        buttons: Int = 0,
        count: Int = 1
    ) {
        assert(count > 0)
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.kind = kind
        self.buttons = buttons
        self.count = count
    }

    /// The global position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** multitap.dart:636
    public let globalPosition: Offset

    /// The local position at which the pointer contacted the screen.
    ///
    /// **Dart Source:** multitap.dart:640
    public let localPosition: Offset

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** multitap.dart:643
    public let kind: PointerDeviceKind

    /// Which buttons were pressed when the pointer contacted the screen.
    ///
    /// See also:
    ///
    ///  * `PointerEvent.buttons`, which this field reflects.
    ///
    /// **Dart Source:** multitap.dart:650
    public let buttons: Int

    /// The number of consecutive taps that this "tap down" represents.
    ///
    /// This value will always be greater than zero. When the first pointer in a
    /// possible series contacts the screen, this value will be `1`, the second
    /// tap in a double-tap will be `2`, and so on.
    ///
    /// If a tap is determined to not be in the same series as the tap that
    /// preceded it (e.g. because too much time elapsed between the two taps or
    /// the two taps had too much distance between them), then this count will
    /// reset back to `1`, and a new series will have begun.
    ///
    /// **Dart Source:** multitap.dart:662
    public let count: Int

    // MARK: - Diagnosticable

    /// **Dart Source:** multitap.dart:665-672
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(DiagnosticsProperty<Offset>("globalPosition", globalPosition))
        properties.add(DiagnosticsProperty<Offset>("localPosition", localPosition))
        properties.add(DiagnosticsProperty<String>("kind", "\(kind)"))
        properties.add(IntProperty("buttons", buttons))
        properties.add(IntProperty("count", count))
    }
}

// MARK: - SerialTapCancelDetails

/// Details for `GestureSerialTapCancelCallback`, such as the tap count within
/// the series.
///
/// See also:
///
///  * `SerialTapGestureRecognizer`, which passes this information to its
///    `SerialTapGestureRecognizer.onSerialTapCancel` callback.
///
/// **Dart Source:** multitap.dart:687-706
///
/// DIFFERENCE FROM DART: In Dart, this uses `with Diagnosticable`. In Swift,
/// it conforms to the `Diagnosticable` protocol. Implemented as a class
/// (reference type) to conform to `Diagnosticable` (which requires `AnyObject`).
public class SerialTapCancelDetails: Diagnosticable {

    /// Creates details for a `GestureSerialTapCancelCallback`.
    ///
    /// The `count` argument must be greater than zero.
    ///
    /// **Dart Source:** multitap.dart:691
    public init(count: Int = 1) {
        assert(count > 0)
        self.count = count
    }

    /// The number of consecutive taps that were in progress when the gesture was
    /// interrupted.
    ///
    /// This number will match the corresponding count that was specified in
    /// `SerialTapDownDetails.count` for the tap that is being canceled. See
    /// that field for more information on how this count is reported.
    ///
    /// **Dart Source:** multitap.dart:699
    public let count: Int

    // MARK: - Diagnosticable

    /// **Dart Source:** multitap.dart:702-705
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(IntProperty("count", count))
    }
}

// MARK: - SerialTapUpDetails

/// Details for `GestureSerialTapUpCallback`, such as the tap count within
/// the series.
///
/// See also:
///
///  * `SerialTapGestureRecognizer`, which passes this information to its
///    `SerialTapGestureRecognizer.onSerialTapUp` callback.
///
/// **Dart Source:** multitap.dart:719-762
///
/// DIFFERENCE FROM DART: In Dart, this uses `with Diagnosticable implements
/// PositionedGestureDetails`. In Swift, it conforms to both `Diagnosticable`
/// and `PositionedGestureDetails` protocols. Implemented as a class (reference
/// type) to conform to `Diagnosticable` (which requires `AnyObject`).
public class SerialTapUpDetails: Diagnosticable, PositionedGestureDetails {

    /// Creates details for a `GestureSerialTapUpCallback`.
    ///
    /// The `count` argument must be greater than zero.
    ///
    /// **Dart Source:** multitap.dart:723-729
    public init(
        globalPosition: Offset = .zero,
        localPosition: Offset? = nil,
        kind: PointerDeviceKind? = nil,
        count: Int = 1
    ) {
        assert(count > 0)
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.kind = kind
        self.count = count
    }

    /// The global position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** multitap.dart:733
    public let globalPosition: Offset

    /// The local position at which the pointer stopped contacting the screen.
    ///
    /// **Dart Source:** multitap.dart:737
    public let localPosition: Offset

    /// The kind of the device that initiated the event.
    ///
    /// **Dart Source:** multitap.dart:740
    public let kind: PointerDeviceKind?

    /// The number of consecutive taps that this tap represents.
    ///
    /// This value will always be greater than zero. When the first pointer in a
    /// possible series completes its tap, this value will be `1`, the second
    /// tap in a double-tap will be `2`, and so on.
    ///
    /// If a tap is determined to not be in the same series as the tap that
    /// preceded it (e.g. because too much time elapsed between the two taps or
    /// the two taps had too much distance between them), then this count will
    /// reset back to `1`, and a new series will have begun.
    ///
    /// **Dart Source:** multitap.dart:752
    public let count: Int

    // MARK: - Diagnosticable

    /// **Dart Source:** multitap.dart:755-761
    public func debugFillProperties(_ properties: DiagnosticPropertiesBuilder) {
        properties.add(DiagnosticsProperty<Offset>("globalPosition", globalPosition))
        properties.add(DiagnosticsProperty<Offset>("localPosition", localPosition))
        properties.add(DiagnosticsProperty<String>("kind", kind != nil ? "\(kind!)" : "nil"))
        properties.add(IntProperty("count", count))
    }
}

// MARK: - SerialTapGestureRecognizer

/// Recognizes serial taps (taps in a series).
///
/// A collection of taps are considered to be _in a series_ if they occur in
/// rapid succession in the same location (within a tolerance). The number of
/// taps in the series is its count. A double-tap, for instance, is a special
/// case of a tap series with a count of two.
///
/// ### Gesture arena behavior
///
/// `SerialTapGestureRecognizer` competes on all pointer events (regardless of
/// button). It will declare defeat if it determines that a gesture is not a
/// tap (e.g. if the pointer is dragged too far while it's contacting the
/// screen). It will immediately declare victory for every tap that it
/// recognizes.
///
/// Each time a pointer contacts the screen, this recognizer will enter that
/// gesture into the arena. This means that this recognizer will yield multiple
/// winning entries in the arena for a single tap series as the series
/// progresses.
///
/// If this recognizer loses the arena (either by declaring defeat or by
/// another recognizer declaring victory) while the pointer is contacting the
/// screen, it will fire `onSerialTapCancel`, and `onSerialTapUp` will not
/// be fired.
///
/// ### Button behavior
///
/// A tap series is defined to have the same buttons across all taps. If a tap
/// with a different combination of buttons is delivered in the middle of a
/// series, it will "steal" the series and begin a new series, starting the
/// count over.
///
/// ### Interleaving tap behavior
///
/// A tap must be _completed_ in order for a subsequent tap to be considered
/// "in the same series" as that tap. Thus, if tap A is in-progress (the down
/// event has been received, but the corresponding up event has not yet been
/// received), and tap B begins (another pointer contacts the screen), tap A
/// will fire `onSerialTapCancel`, and tap B will begin a new series (tap B's
/// `SerialTapDownDetails.count` will be 1).
///
/// ### Relation to `TapGestureRecognizer` and `DoubleTapGestureRecognizer`
///
/// `SerialTapGestureRecognizer` fires `onSerialTapDown` and `onSerialTapUp`
/// for every tap that it recognizes (passing the count in the details),
/// regardless of whether that tap is a single-tap, double-tap, etc. This
/// makes it especially useful when you want to respond to every tap in a
/// series. Contrast this with `DoubleTapGestureRecognizer`, which only fires
/// if the user completes a double-tap, and `TapGestureRecognizer`, which
/// _doesn't_ fire if the recognizer is competing with a
/// `DoubleTapGestureRecognizer`, and the user double-taps.
///
/// ### When competing with `TapGestureRecognizer` and `DoubleTapGestureRecognizer`
///
/// Unlike `TapGestureRecognizer` and `DoubleTapGestureRecognizer`,
/// `SerialTapGestureRecognizer` aggressively declares victory when it detects
/// a tap, so when it is competing with those gesture recognizers, it will beat
/// them in the arena, regardless of which recognizer entered the arena first.
///
/// **Dart Source:** multitap.dart:836-1048
public class SerialTapGestureRecognizer: GestureRecognizer {

    /// Creates a serial tap gesture recognizer.
    ///
    /// **Dart Source:** multitap.dart:838-842
    public override init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { _ in true }
    ) {
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    /// A pointer has contacted the screen at a particular location, which might
    /// be the start of a serial tap.
    ///
    /// If this recognizer loses the arena before the serial tap is completed
    /// (either because the gesture does not end up being a tap or because another
    /// recognizer wins the arena), `onSerialTapCancel` is called next. Otherwise,
    /// `onSerialTapUp` is called next.
    ///
    /// The `SerialTapDownDetails.count` that is passed to this callback
    /// specifies the series tap count.
    ///
    /// **Dart Source:** multitap.dart:854
    public var onSerialTapDown: GestureSerialTapDownCallback?

    /// A pointer that previously triggered `onSerialTapDown` will not end up
    /// triggering the corresponding `onSerialTapUp`.
    ///
    /// If the user completes the serial tap, `onSerialTapUp` is called instead.
    ///
    /// The `SerialTapCancelDetails.count` that is passed to this callback will
    /// match the `SerialTapDownDetails.count` that was passed to the
    /// `onSerialTapDown` callback.
    ///
    /// **Dart Source:** multitap.dart:864
    public var onSerialTapCancel: GestureSerialTapCancelCallback?

    /// A pointer has stopped contacting the screen at a particular location,
    /// representing a serial tap.
    ///
    /// If the user didn't complete the tap, or if another recognizer won the
    /// arena, then `onSerialTapCancel` is called instead.
    ///
    /// The `SerialTapUpDetails.count` that is passed to this callback specifies
    /// the series tap count and will match the `SerialTapDownDetails.count` that
    /// was passed to the `onSerialTapDown` callback.
    ///
    /// **Dart Source:** multitap.dart:875
    public var onSerialTapUp: GestureSerialTapUpCallback?

    /// **Dart Source:** multitap.dart:877
    private var _serialTapTimer: Timer?

    /// **Dart Source:** multitap.dart:878
    private var _completedTaps: [TapTracker] = []

    /// **Dart Source:** multitap.dart:879
    private var _gestureResolutions: [Int: GestureDisposition] = [:]

    /// **Dart Source:** multitap.dart:880
    private var _pendingTap: TapTracker?

    /// Indicates whether this recognizer is currently tracking a pointer that's
    /// in contact with the screen.
    ///
    /// If this is true, it implies that `onSerialTapDown` has fired, but neither
    /// `onSerialTapCancel` nor `onSerialTapUp` have yet fired.
    ///
    /// **Dart Source:** multitap.dart:887
    public var isTrackingPointer: Bool { _pendingTap != nil }

    // MARK: - Pointer Filtering

    /// **Dart Source:** multitap.dart:890-895
    public override func isPointerAllowed(_ event: PointerDownEvent) -> Bool {
        if onSerialTapDown == nil && onSerialTapCancel == nil && onSerialTapUp == nil {
            return false
        }
        return super.isPointerAllowed(event)
    }

    // MARK: - Pointer Handling

    /// **Dart Source:** multitap.dart:898-904
    public override func addAllowedPointer(_ event: PointerDownEvent) {
        if (!_completedTaps.isEmpty && !_representsSameSeries(_completedTaps.last!, event))
            || _pendingTap != nil
        {
            _reset()
        }
        _trackTap(event)
    }

    /// **Dart Source:** multitap.dart:906-912
    private func _representsSameSeries(_ tap: TapTracker, _ event: PointerDownEvent) -> Bool {
        return tap.hasElapsedMinTime()  // touch screens often detect touches intermittently
            && tap.hasSameButton(event)
            && tap.isWithinGlobalTolerance(event, kDoubleTapSlop)
    }

    /// **Dart Source:** multitap.dart:914-935
    private func _trackTap(_ event: PointerDownEvent) {
        _stopSerialTapTimer()
        if onSerialTapDown != nil {
            let details = SerialTapDownDetails(
                globalPosition: event.position,
                localPosition: event.localPosition,
                kind: getKindForPointer(event.pointer),
                buttons: event.buttons,
                count: _completedTaps.count + 1
            )
            invokeCallback("onSerialTapDown") { self.onSerialTapDown!(details) }
        }
        let tracker = TapTracker(
            event: event,
            entry: GestureBinding.instance.gestureArena.add(event.pointer, self),
            doubleTapMinTime: kDoubleTapMinTime,
            gestureSettings: gestureSettings
        )
        assert(_pendingTap == nil)
        _pendingTap = tracker
        tracker.startTrackingPointer(_handleEvent, event.transform)
    }

    /// **Dart Source:** multitap.dart:937-950
    private func _handleEvent(_ event: PointerEvent) {
        assert(_pendingTap != nil)
        assert(_pendingTap!.pointer == event.pointer)
        let tracker = _pendingTap!
        if event is PointerUpEvent {
            _registerTap(event as! PointerUpEvent, tracker)
        } else if event is PointerMoveEvent {
            if !tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop) {
                _reset()
            }
        } else if event is PointerCancelEvent {
            _reset()
        }
    }

    // MARK: - Arena Resolution

    /// **Dart Source:** multitap.dart:953-957
    public override func acceptGesture(_ pointer: Int) {
        assert(_pendingTap != nil)
        assert(_pendingTap!.pointer == pointer)
        _gestureResolutions[pointer] = .accepted
    }

    /// **Dart Source:** multitap.dart:960-963
    public override func rejectGesture(_ pointer: Int) {
        _gestureResolutions[pointer] = .rejected
        _reset()
    }

    /// **Dart Source:** multitap.dart:965-977
    private func _rejectPendingTap() {
        assert(_pendingTap != nil)
        let tracker = _pendingTap!
        _pendingTap = nil
        // Order is important here; the `resolve` call can yield a re-entrant
        // `reset()`, so we need to check cancel here while we can trust the
        // length of our _completedTaps list.
        _checkCancel(_completedTaps.count + 1)
        if _gestureResolutions[tracker.pointer] == nil {
            tracker.entry.resolve(.rejected)
        }
        _stopTrackingPointer(tracker)
    }

    // MARK: - Lifecycle

    /// **Dart Source:** multitap.dart:980-983
    public override func dispose() {
        _reset()
        super.dispose()
    }

    /// **Dart Source:** multitap.dart:985-993
    private func _reset() {
        if _pendingTap != nil {
            _rejectPendingTap()
        }
        _pendingTap = nil
        _completedTaps.removeAll()
        _gestureResolutions.removeAll()
        _stopSerialTapTimer()
    }

    /// **Dart Source:** multitap.dart:995-1010
    private func _registerTap(_ event: PointerUpEvent, _ tracker: TapTracker) {
        assert(tracker === _pendingTap)
        assert(tracker.pointer == event.pointer)
        _startSerialTapTimer()
        assert(_gestureResolutions[event.pointer] != .rejected)
        if _gestureResolutions[event.pointer] == nil {
            tracker.entry.resolve(.accepted)
        }
        assert(_gestureResolutions[event.pointer] == .accepted)
        _stopTrackingPointer(tracker)
        // Note, order is important below in order for the clear -> reject logic to
        // work properly.
        _pendingTap = nil
        _checkUp(event, tracker)
        _completedTaps.append(tracker)
    }

    /// **Dart Source:** multitap.dart:1012-1014
    private func _stopTrackingPointer(_ tracker: TapTracker) {
        tracker.stopTrackingPointer(_handleEvent)
    }

    // MARK: - Timer Management

    /// **Dart Source:** multitap.dart:1016-1018
    private func _startSerialTapTimer() {
        if _serialTapTimer == nil {
            nonisolated(unsafe) let capturedSelf = self
            _serialTapTimer = Timer.scheduledTimer(
                withTimeInterval: kDoubleTapTimeout, repeats: false
            ) { _ in
                capturedSelf._reset()
            }
        }
    }

    /// **Dart Source:** multitap.dart:1020-1025
    private func _stopSerialTapTimer() {
        if _serialTapTimer != nil {
            _serialTapTimer!.invalidate()
            _serialTapTimer = nil
        }
    }

    // MARK: - Callback Checks

    /// **Dart Source:** multitap.dart:1027-1036
    private func _checkUp(_ event: PointerUpEvent, _ tracker: TapTracker) {
        if onSerialTapUp != nil {
            let details = SerialTapUpDetails(
                globalPosition: event.position,
                localPosition: event.localPosition,
                kind: getKindForPointer(tracker.pointer),
                count: _completedTaps.count + 1
            )
            invokeCallback("onSerialTapUp") { self.onSerialTapUp!(details) }
        }
    }

    /// **Dart Source:** multitap.dart:1039-1044
    private func _checkCancel(_ count: Int) {
        if onSerialTapCancel != nil {
            let details = SerialTapCancelDetails(count: count)
            invokeCallback("onSerialTapCancel") { self.onSerialTapCancel!(details) }
        }
    }

    // MARK: - Debug Description

    /// **Dart Source:** multitap.dart:1047
    public override var debugDescription: String {
        return "serial tap"
    }
}

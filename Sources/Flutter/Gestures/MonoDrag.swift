// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Mono-drag gesture recognizers: `DragGestureRecognizer` (sealed base),
/// `VerticalDragGestureRecognizer`, `HorizontalDragGestureRecognizer`, and
/// `PanGestureRecognizer`.
///
/// In contrast to `MultiDragGestureRecognizer`, `DragGestureRecognizer`
/// recognizes a single gesture sequence for all the pointers it watches, which
/// means that the recognizer has at most one drag sequence active at any given
/// time regardless of how many pointers are in contact with the screen.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/monodrag.dart`
/// **Lines:** 1-1104

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

// MARK: - _DragState

/// Internal drag state enum tracking the recognizer lifecycle.
///
/// **Dart Source:** `monodrag.dart:38`
private enum _DragState {
    case ready
    case possible
    case accepted
}

// MARK: - _DragDirection

/// Internal drag direction used for multitouch boundary pointer resolution.
///
/// **Dart Source:** `monodrag.dart:1103`
private enum _DragDirection {
    case horizontal
    case vertical
}

// MARK: - GestureDragCancelCallback

/// Signature for when the pointer that previously triggered a
/// `GestureDragDownCallback` did not complete.
///
/// Used by `DragGestureRecognizer.onCancel`.
///
/// **Dart Source:** `monodrag.dart:55`
public typealias GestureDragCancelCallback = () -> Void

// MARK: - GestureVelocityTrackerBuilder

/// Signature for a function that builds a `VelocityTracker`.
///
/// Used by `DragGestureRecognizer.velocityTrackerBuilder`.
///
/// **Dart Source:** `monodrag.dart:60`
public typealias GestureVelocityTrackerBuilder = (_ event: PointerEvent) -> VelocityTracker

// MARK: - DragGestureRecognizer

/// Recognizes movement.
///
/// In contrast to `MultiDragGestureRecognizer`, `DragGestureRecognizer`
/// recognizes a single gesture sequence for all the pointers it watches, which
/// means that the recognizer has at most one drag sequence active at any given
/// time regardless of how many pointers are in contact with the screen.
///
/// `DragGestureRecognizer` is not intended to be used directly. Instead,
/// consider using one of its subclasses to recognize specific types for drag
/// gestures.
///
/// `DragGestureRecognizer` competes on pointer events only when it has at
/// least one non-nil callback. If it has no callbacks, it is a no-op.
///
/// See also:
///
///  * `HorizontalDragGestureRecognizer`, for left and right drags.
///  * `VerticalDragGestureRecognizer`, for up and down drags.
///  * `PanGestureRecognizer`, for drags that are not locked to a single axis.
///
/// **Dart Source:** `monodrag.dart:81-919`
///
/// DIFFERENCE FROM DART: In Dart, `DragGestureRecognizer` is a sealed class.
/// In Swift, it is an open class because Swift does not have a `sealed`
/// keyword. Subclass only `VerticalDragGestureRecognizer`,
/// `HorizontalDragGestureRecognizer`, or `PanGestureRecognizer`.
open class DragGestureRecognizer: OneSequenceGestureRecognizer {

    /// Initialize the object.
    ///
    /// **Dart Source:** `monodrag.dart:85-93`
    public init(
        debugOwner: AnyObject? = nil,
        dragStartBehavior: DragStartBehavior = .start,
        multitouchDragStrategy: MultitouchDragStrategy = .latestPointer,
        velocityTrackerBuilder: @escaping GestureVelocityTrackerBuilder = { event in VelocityTracker(kind: event.kind) },
        onlyAcceptDragOnThreshold: Bool = false,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { buttons in buttons == kPrimaryButton }
    ) {
        self.dragStartBehavior = dragStartBehavior
        self.multitouchDragStrategy = multitouchDragStrategy
        self.velocityTrackerBuilder = velocityTrackerBuilder
        self.onlyAcceptDragOnThreshold = onlyAcceptDragOnThreshold
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    // MARK: - Static Defaults

    /// Default velocity tracker builder — creates a `VelocityTracker` matching
    /// the pointer event's device kind.
    ///
    /// **Dart Source:** `monodrag.dart:95-96`
    private static func _defaultBuilder(_ event: PointerEvent) -> VelocityTracker {
        return VelocityTracker(kind: event.kind)
    }

    /// Accept the input if, and only if, `kPrimaryButton` is pressed.
    ///
    /// **Dart Source:** `monodrag.dart:99`
    private static func _defaultButtonAcceptBehavior(_ buttons: Int) -> Bool {
        return buttons == kPrimaryButton
    }

    // MARK: - Public Properties

    /// Configure the behavior of offsets passed to `onStart`.
    ///
    /// If set to `DragStartBehavior.start`, the `onStart` callback will be called
    /// with the position of the pointer at the time this gesture recognizer won
    /// the arena. If `DragStartBehavior.down`, `onStart` will be called with
    /// the position of the first detected down event for the pointer.
    ///
    /// By default, the drag start behavior is `DragStartBehavior.start`.
    ///
    /// **Dart Source:** `monodrag.dart:125`
    public var dragStartBehavior: DragStartBehavior

    /// Configure the multi-finger drag strategy on multi-touch devices.
    ///
    /// By default, the strategy is `MultitouchDragStrategy.latestPointer`.
    ///
    /// **Dart Source:** `monodrag.dart:148`
    public var multitouchDragStrategy: MultitouchDragStrategy

    /// A pointer has contacted the screen with a primary button and might begin
    /// to move.
    ///
    /// **Dart Source:** `monodrag.dart:160`
    public var onDown: GestureDragDownCallback?

    /// A pointer has contacted the screen with a primary button and has begun to
    /// move.
    ///
    /// **Dart Source:** `monodrag.dart:175`
    public var onStart: GestureDragStartCallback?

    /// A pointer that is in contact with the screen with a primary button and
    /// moving has moved again.
    ///
    /// **Dart Source:** `monodrag.dart:197`
    public var onUpdate: GestureDragUpdateCallback?

    /// A pointer that was previously in contact with the screen with a primary
    /// button and moving is no longer in contact with the screen and was moving
    /// at a specific velocity when it stopped contacting the screen.
    ///
    /// **Dart Source:** `monodrag.dart:220`
    public var onEnd: GestureDragEndCallback?

    /// The pointer that previously triggered `onDown` did not complete.
    ///
    /// **Dart Source:** `monodrag.dart:227`
    public var onCancel: GestureDragCancelCallback?

    /// The minimum distance an input pointer drag must have moved
    /// to be considered a fling gesture.
    ///
    /// This value is typically compared with the distance traveled along the
    /// scrolling axis. If nil then `kTouchSlop` is used.
    ///
    /// **Dart Source:** `monodrag.dart:234`
    public var minFlingDistance: Double?

    /// The minimum velocity for an input pointer drag to be considered fling.
    ///
    /// This value is typically compared with the magnitude of fling gesture's
    /// velocity along the scrolling axis. If nil then `kMinFlingVelocity`
    /// is used.
    ///
    /// **Dart Source:** `monodrag.dart:241`
    public var minFlingVelocity: Double?

    /// Fling velocity magnitudes will be clamped to this value.
    ///
    /// If nil then `kMaxFlingVelocity` is used.
    ///
    /// **Dart Source:** `monodrag.dart:246`
    public var maxFlingVelocity: Double?

    /// Whether the drag threshold should be met before dispatching any drag callbacks.
    ///
    /// If true, the drag callbacks will only be dispatched when this recognizer has
    /// won the arena and the drag threshold has been met.
    ///
    /// If false, the drag callbacks will be dispatched immediately when this recognizer
    /// has won the arena.
    ///
    /// This value defaults to false.
    ///
    /// **Dart Source:** `monodrag.dart:265`
    public var onlyAcceptDragOnThreshold: Bool

    /// Determines the type of velocity estimation method to use for a potential
    /// drag gesture, when a new pointer is added.
    ///
    /// If left unspecified the default `velocityTrackerBuilder` creates a new
    /// `VelocityTracker` for every pointer added.
    ///
    /// **Dart Source:** `monodrag.dart:289`
    public var velocityTrackerBuilder: GestureVelocityTrackerBuilder

    // MARK: - Internal State

    /// **Dart Source:** `monodrag.dart:291`
    private var _state: _DragState = .ready

    /// **Dart Source:** `monodrag.dart:292`
    private var _initialPosition: OffsetPair = .zero

    /// **Dart Source:** `monodrag.dart:293`
    private var _pendingDragOffset: OffsetPair = .zero

    /// The local and global offsets of the last pointer event received.
    ///
    /// It is used to create the `DragEndDetails`, which provides information about
    /// the end of a drag gesture.
    ///
    /// **Dart Source:** `monodrag.dart:299-300`
    public private(set) var lastPosition: OffsetPair = .zero

    /// **Dart Source:** `monodrag.dart:302`
    private var _lastPendingEventTimestamp: Duration?

    /// When asserts are enabled, returns the last tracked pending event timestamp
    /// for this recognizer.
    ///
    /// Otherwise, returns nil.
    ///
    /// This getter is intended for use in framework unit tests. Applications must
    /// not depend on its value.
    ///
    /// **Dart Source:** `monodrag.dart:312-319`
    public var debugLastPendingEventTimestamp: Duration? {
        var lastPendingEventTimestamp: Duration?
        assert({
            lastPendingEventTimestamp = _lastPendingEventTimestamp
            return true
        }())
        return lastPendingEventTimestamp
    }

    /// The buttons sent by `PointerDownEvent`. If a `PointerMoveEvent` comes with a
    /// different set of buttons, the gesture is canceled.
    ///
    /// **Dart Source:** `monodrag.dart:323`
    private var _initialButtons: Int?

    /// **Dart Source:** `monodrag.dart:324`
    private var _lastTransform: Matrix4?

    /// Distance moved in the global coordinate space of the screen in drag direction.
    ///
    /// If drag is only allowed along a defined axis, this value may be negative to
    /// differentiate the direction of the drag.
    ///
    /// **Dart Source:** `monodrag.dart:330-331`
    public private(set) var globalDistanceMoved: Double = 0.0

    /// **Dart Source:** `monodrag.dart:378`
    private var _hasDragThresholdBeenMet: Bool = false

    /// **Dart Source:** `monodrag.dart:380`
    private var _velocityTrackers: [Int: VelocityTracker] = [:]

    // The move delta of each pointer before the next frame.
    //
    // The key is the pointer ID. It is cleared whenever a new batch of pointer events is detected.
    //
    /// **Dart Source:** `monodrag.dart:385`
    private var _moveDeltaBeforeFrame: [Int: Offset] = [:]

    // The timestamp of all events of the current frame.
    //
    // On an event with a different timestamp, the event is considered a new batch.
    //
    /// **Dart Source:** `monodrag.dart:390`
    private var _frameTimeStamp: Duration?

    /// **Dart Source:** `monodrag.dart:391`
    private var _lastUpdatedDeltaForPan: Offset = .zero

    // MARK: - Abstract Methods (to be overridden by subclasses)

    /// Determines if a gesture is a fling or not based on velocity.
    ///
    /// A fling calls its gesture end callback with a velocity, allowing the
    /// provider of the callback to respond by carrying the gesture forward with
    /// inertia, for example.
    ///
    /// **Dart Source:** `monodrag.dart:338`
    open func isFlingGesture(_ estimate: VelocityEstimate, _ kind: PointerDeviceKind) -> Bool {
        fatalError("Subclass must override isFlingGesture(_:_:)")
    }

    /// Determines if a gesture is a fling or not, and if so its effective velocity.
    ///
    /// A fling calls its gesture end callback with a velocity, allowing the
    /// provider of the callback to respond by carrying the gesture forward with
    /// inertia, for example.
    ///
    /// **Dart Source:** `monodrag.dart:345`
    open func considerFling(_ estimate: VelocityEstimate, _ kind: PointerDeviceKind) -> DragEndDetails? {
        fatalError("Subclass must override considerFling(_:_:)")
    }

    /// Returns the effective delta that should be considered for the incoming `delta`.
    ///
    /// **Dart Source:** `monodrag.dart:355`
    open func getDeltaForDetails(_ delta: Offset) -> Offset {
        fatalError("Subclass must override getDeltaForDetails(_:)")
    }

    /// Returns the value for the primary axis from the given `value`.
    ///
    /// Returns `nil` if the recognizer does not have a primary axis.
    ///
    /// **Dart Source:** `monodrag.dart:364`
    open func getPrimaryValueFromOffset(_ value: Offset) -> Double? {
        fatalError("Subclass must override getPrimaryValueFromOffset(_:)")
    }

    /// The axis (horizontal or vertical) corresponding to the primary drag direction.
    ///
    /// The `PanGestureRecognizer` returns nil.
    ///
    /// **Dart Source:** `monodrag.dart:369`
    fileprivate func _getPrimaryDragAxis() -> _DragDirection? {
        return nil
    }

    /// Whether the `globalDistanceMoved` is big enough to accept the gesture.
    ///
    /// If this method returns `true`, it means this recognizer should declare win in the gesture arena.
    ///
    /// **Dart Source:** `monodrag.dart:374-377`
    open func hasSufficientGlobalDistanceToAccept(
        _ pointerDeviceKind: PointerDeviceKind,
        _ deviceTouchSlop: Double?
    ) -> Bool {
        fatalError("Subclass must override hasSufficientGlobalDistanceToAccept(_:_:)")
    }

    // MARK: - Accepted Active Pointers

    /// **Dart Source:** `monodrag.dart:729`
    private var _acceptedActivePointers: [Int] = []

    /// This value is used when the multitouch strategy is `latestPointer`,
    /// it keeps track of the last accepted pointer.
    ///
    /// **Dart Source:** `monodrag.dart:735`
    private var _activePointer: Int?

    // MARK: - isPointerAllowed

    /// **Dart Source:** `monodrag.dart:394-410`
    open override func isPointerAllowed(_ event: PointerDownEvent) -> Bool {
        if _initialButtons == nil {
            if onDown == nil
                && onStart == nil
                && onUpdate == nil
                && onEnd == nil
                && onCancel == nil
            {
                return false
            }
        } else {
            // There can be multiple drags simultaneously. Their effects are combined.
            if event.buttons != _initialButtons {
                return false
            }
        }
        return super.isPointerAllowed(event)
    }

    // MARK: - _addPointer

    /// **Dart Source:** `monodrag.dart:412-429`
    private func _addPointer(_ event: PointerEvent) {
        _velocityTrackers[event.pointer] = velocityTrackerBuilder(event)
        switch _state {
        case .ready:
            _state = .possible
            _initialPosition = OffsetPair(local: event.localPosition, global: event.position)
            lastPosition = _initialPosition
            _pendingDragOffset = .zero
            globalDistanceMoved = 0.0
            _lastPendingEventTimestamp = event.timeStamp
            _lastTransform = event.transform
            _checkDown()
        case .possible:
            break
        case .accepted:
            resolve(.accepted)
        }
    }

    // MARK: - addAllowedPointer

    /// **Dart Source:** `monodrag.dart:432-438`
    open override func addAllowedPointer(_ event: PointerDownEvent) {
        super.addAllowedPointer(event)
        if _state == .ready {
            _initialButtons = event.buttons
        }
        _addPointer(event)
    }

    // MARK: - addAllowedPointerPanZoom

    /// **Dart Source:** `monodrag.dart:441-448`
    open override func addAllowedPointerPanZoom(_ event: PointerPanZoomStartEvent) {
        super.addAllowedPointerPanZoom(event)
        startTrackingPointer(event.pointer, event.transform)
        if _state == .ready {
            _initialButtons = kPrimaryButton
        }
        _addPointer(event)
    }

    // MARK: - Multitouch Tracking Helpers

    /// **Dart Source:** `monodrag.dart:450-460`
    private func _shouldTrackMoveEvent(_ pointer: Int) -> Bool {
        switch multitouchDragStrategy {
        case .sumAllPointers, .averageBoundaryPointers:
            return true
        case .latestPointer:
            return _activePointer == nil || pointer == _activePointer
        }
    }

    /// **Dart Source:** `monodrag.dart:462-481`
    private func _recordMoveDeltaForMultitouch(_ pointer: Int, _ localDelta: Offset) {
        if multitouchDragStrategy != .averageBoundaryPointers {
            assert(_frameTimeStamp == nil)
            assert(_moveDeltaBeforeFrame.isEmpty)
            return
        }

        // DIFFERENCE FROM DART: SchedulerBinding.instance.currentSystemFrameTimeStamp
        // is not yet available in Swift. We use the _frameTimeStamp set during
        // _resolveLocalDeltaForMultitouch as the frame timestamp proxy.

        if _state != .accepted || localDelta == .zero {
            return
        }

        if let existing = _moveDeltaBeforeFrame[pointer] {
            _moveDeltaBeforeFrame[pointer] = existing + localDelta
        } else {
            _moveDeltaBeforeFrame[pointer] = localDelta
        }
    }

    /// **Dart Source:** `monodrag.dart:483-510`
    private func _getSumDelta(pointer: Int, positive: Bool, axis: _DragDirection) -> Double {
        var sum = 0.0

        guard let offset = _moveDeltaBeforeFrame[pointer] else {
            return sum
        }

        if positive {
            if axis == .vertical {
                sum = max(offset.dy, 0.0)
            } else {
                sum = max(offset.dx, 0.0)
            }
        } else {
            if axis == .vertical {
                sum = min(offset.dy, 0.0)
            } else {
                sum = min(offset.dx, 0.0)
            }
        }

        return sum
    }

    /// **Dart Source:** `monodrag.dart:512-541`
    private func _getMaxSumDeltaPointer(positive: Bool, axis: _DragDirection) -> Int? {
        if _moveDeltaBeforeFrame.isEmpty {
            return nil
        }

        var ret: Int?
        var maxVal: Double?
        for pointer in _moveDeltaBeforeFrame.keys {
            let sum = _getSumDelta(pointer: pointer, positive: positive, axis: axis)
            if ret == nil {
                ret = pointer
                maxVal = sum
            } else {
                if positive {
                    if sum > maxVal! {
                        ret = pointer
                        maxVal = sum
                    }
                } else {
                    if sum < maxVal! {
                        ret = pointer
                        maxVal = sum
                    }
                }
            }
        }
        assert(ret != nil)
        return ret
    }

    /// **Dart Source:** `monodrag.dart:543-596`
    ///
    /// DIFFERENCE FROM DART: Since `SchedulerBinding.instance.currentSystemFrameTimeStamp`
    /// is not yet available, we use `_frameTimeStamp` as a proxy set at the
    /// beginning of each frame's event batch. For `averageBoundaryPointers`
    /// strategy, we detect new batches by checking if `_frameTimeStamp` differs
    /// from the current event's timestamp.
    /// REASON: `SchedulerBinding` is not yet migrated to Swift.
    private func _resolveLocalDeltaForMultitouch(_ pointer: Int, _ localDelta: Offset) -> Offset {
        if multitouchDragStrategy != .averageBoundaryPointers {
            if _frameTimeStamp != nil {
                _moveDeltaBeforeFrame.removeAll()
                _frameTimeStamp = nil
                _lastUpdatedDeltaForPan = .zero
            }
            return localDelta
        }

        // Use the event timestamp as a proxy for frame timestamp since
        // SchedulerBinding is not yet available.
        // In Dart: SchedulerBinding.instance.currentSystemFrameTimeStamp
        let currentFrameTimeStamp = _frameTimeStamp ?? _lastPendingEventTimestamp ?? .zero
        if _frameTimeStamp != currentFrameTimeStamp {
            _moveDeltaBeforeFrame.removeAll()
            _lastUpdatedDeltaForPan = .zero
            _frameTimeStamp = currentFrameTimeStamp
        }

        let axis = _getPrimaryDragAxis()

        if _state != .accepted
            || localDelta == .zero
            || (_moveDeltaBeforeFrame.isEmpty && axis != nil)
        {
            return localDelta
        }

        let dx: Double
        let dy: Double
        if axis == .horizontal {
            dx = _resolveDelta(pointer: pointer, axis: .horizontal, localDelta: localDelta)
            assert(Swift.abs(dx) <= Swift.abs(localDelta.dx))
            dy = 0.0
        } else if axis == .vertical {
            dx = 0.0
            dy = _resolveDelta(pointer: pointer, axis: .vertical, localDelta: localDelta)
            assert(Swift.abs(dy) <= Swift.abs(localDelta.dy))
        } else {
            let averageX = _resolveDeltaForPanGesture(
                axis: .horizontal,
                localDelta: localDelta
            )
            let averageY = _resolveDeltaForPanGesture(
                axis: .vertical,
                localDelta: localDelta
            )
            let updatedDelta = Offset(averageX, averageY) - _lastUpdatedDeltaForPan
            _lastUpdatedDeltaForPan = Offset(averageX, averageY)
            dx = updatedDelta.dx
            dy = updatedDelta.dy
        }

        return Offset(dx, dy)
    }

    /// **Dart Source:** `monodrag.dart:598-635`
    private func _resolveDelta(pointer: Int, axis: _DragDirection, localDelta: Offset) -> Double {
        let positive = axis == .horizontal ? localDelta.dx > 0 : localDelta.dy > 0
        let delta = axis == .horizontal ? localDelta.dx : localDelta.dy
        let maxSumDeltaPointer = _getMaxSumDeltaPointer(positive: positive, axis: axis)
        assert(maxSumDeltaPointer != nil)

        if maxSumDeltaPointer == pointer {
            return delta
        } else {
            let maxSumDelta = _getSumDelta(
                pointer: maxSumDeltaPointer!,
                positive: positive,
                axis: axis
            )
            let curPointerSumDelta = _getSumDelta(
                pointer: pointer,
                positive: positive,
                axis: axis
            )
            if positive {
                if curPointerSumDelta + delta > maxSumDelta {
                    return curPointerSumDelta + delta - maxSumDelta
                } else {
                    return 0.0
                }
            } else {
                if curPointerSumDelta + delta < maxSumDelta {
                    return curPointerSumDelta + delta - maxSumDelta
                } else {
                    return 0.0
                }
            }
        }
    }

    /// **Dart Source:** `monodrag.dart:637-651`
    private func _resolveDeltaForPanGesture(axis: _DragDirection, localDelta: Offset) -> Double {
        let delta = axis == .horizontal ? localDelta.dx : localDelta.dy
        let pointerCount = _acceptedActivePointers.count
        assert(pointerCount >= 1)

        var sum = delta
        for offset in _moveDeltaBeforeFrame.values {
            if axis == .horizontal {
                sum += offset.dx
            } else {
                sum += offset.dy
            }
        }
        return sum / Double(pointerCount)
    }

    // MARK: - handleEvent

    /// **Dart Source:** `monodrag.dart:654-727`
    open override func handleEvent(_ event: PointerEvent) {
        assert(_state != .ready)
        if !event.synthesized
            && (event is PointerDownEvent
                || event is PointerMoveEvent
                || event is PointerPanZoomStartEvent
                || event is PointerPanZoomUpdateEvent)
        {
            let position: Offset
            if event is PointerPanZoomStartEvent {
                position = .zero
            } else if let panZoomUpdate = event as? PointerPanZoomUpdateEvent {
                position = panZoomUpdate.pan
            } else {
                position = event.localPosition
            }
            _velocityTrackers[event.pointer]!.addPosition(event.timeStamp, position)
        }
        if let moveEvent = event as? PointerMoveEvent, moveEvent.buttons != _initialButtons {
            _giveUpPointer(event.pointer)
            return
        }
        if (event is PointerMoveEvent || event is PointerPanZoomUpdateEvent)
            && _shouldTrackMoveEvent(event.pointer)
        {
            let delta: Offset
            let localDelta: Offset
            let position: Offset
            let localPosition: Offset
            if let moveEvent = event as? PointerMoveEvent {
                delta = moveEvent.delta
                localDelta = moveEvent.localDelta
                position = moveEvent.position
                localPosition = moveEvent.localPosition
            } else {
                let panZoomUpdate = event as! PointerPanZoomUpdateEvent
                delta = panZoomUpdate.panDelta
                localDelta = panZoomUpdate.localPanDelta
                position = event.position + panZoomUpdate.pan
                localPosition = event.localPosition + panZoomUpdate.localPan
            }
            lastPosition = OffsetPair(local: localPosition, global: position)
            let resolvedDelta = _resolveLocalDeltaForMultitouch(event.pointer, localDelta)
            switch _state {
            case .ready, .possible:
                _pendingDragOffset = _pendingDragOffset + OffsetPair(local: localDelta, global: delta)
                _lastPendingEventTimestamp = event.timeStamp
                _lastTransform = event.transform
                let movedLocally = getDeltaForDetails(localDelta)
                let localToGlobalTransform: Matrix4?
                if let transform = event.transform {
                    var invertedTransform = transform
                    let det = invertedTransform.invert()
                    localToGlobalTransform = det != 0.0 ? invertedTransform : nil
                } else {
                    localToGlobalTransform = nil
                }
                globalDistanceMoved +=
                    PointerEvent.transformDeltaViaPositions(
                        untransformedEndPosition: localPosition,
                        untransformedDelta: movedLocally,
                        transform: localToGlobalTransform
                    ).distance
                    * _signOf(getPrimaryValueFromOffset(movedLocally) ?? 1)
                if hasSufficientGlobalDistanceToAccept(event.kind, gestureSettings?.touchSlop) {
                    _hasDragThresholdBeenMet = true
                    if _acceptedActivePointers.contains(event.pointer) {
                        _checkDrag(event.pointer)
                    } else {
                        resolve(.accepted)
                    }
                }
            case .accepted:
                _checkUpdate(
                    sourceTimeStamp: event.timeStamp,
                    delta: getDeltaForDetails(resolvedDelta),
                    primaryDelta: getPrimaryValueFromOffset(resolvedDelta),
                    globalPosition: position,
                    localPosition: localPosition,
                    pointer: event.pointer
                )
            }
            _recordMoveDeltaForMultitouch(event.pointer, localDelta)
        }
        if event is PointerUpEvent || event is PointerCancelEvent || event is PointerPanZoomEndEvent {
            _giveUpPointer(event.pointer)
        }
    }

    // MARK: - acceptGesture / rejectGesture

    /// **Dart Source:** `monodrag.dart:738-745`
    open override func acceptGesture(_ pointer: Int) {
        assert(!_acceptedActivePointers.contains(pointer))
        _acceptedActivePointers.append(pointer)
        _activePointer = pointer
        if !onlyAcceptDragOnThreshold || _hasDragThresholdBeenMet {
            _checkDrag(pointer)
        }
    }

    /// **Dart Source:** `monodrag.dart:748-750`
    open override func rejectGesture(_ pointer: Int) {
        _giveUpPointer(pointer)
    }

    // MARK: - didStopTrackingLastPointer

    /// **Dart Source:** `monodrag.dart:753-770`
    open override func didStopTrackingLastPointer(_ pointer: Int) {
        assert(_state != .ready)
        switch _state {
        case .ready:
            break
        case .possible:
            resolve(.rejected)
            _checkCancel()
        case .accepted:
            _checkEnd(pointer)
        }
        _hasDragThresholdBeenMet = false
        _velocityTrackers.removeAll()
        _initialButtons = nil
        _state = .ready
    }

    // MARK: - _giveUpPointer

    /// **Dart Source:** `monodrag.dart:772-784`
    private func _giveUpPointer(_ pointer: Int) {
        stopTrackingPointer(pointer)
        // If we never accepted the pointer, we reject it since we are no longer
        // interested in winning the gesture arena for it.
        if let index = _acceptedActivePointers.firstIndex(of: pointer) {
            _acceptedActivePointers.remove(at: index)
        } else {
            resolvePointer(pointer, .rejected)
        }

        _moveDeltaBeforeFrame.removeValue(forKey: pointer)
        if _activePointer == pointer {
            _activePointer = _acceptedActivePointers.isEmpty ? nil : _acceptedActivePointers.first
        }
    }

    // MARK: - Callback Helpers

    /// **Dart Source:** `monodrag.dart:786-794`
    private func _checkDown() {
        if onDown != nil {
            let details = DragDownDetails(
                globalPosition: _initialPosition.global,
                localPosition: _initialPosition.local
            )
            invokeCallback("onDown", { self.onDown!(details) })
        }
    }

    /// **Dart Source:** `monodrag.dart:796-840`
    private func _checkDrag(_ pointer: Int) {
        if _state == .accepted {
            return
        }
        _state = .accepted
        let delta = _pendingDragOffset
        let timestamp = _lastPendingEventTimestamp
        let transform = _lastTransform
        let localUpdateDelta: Offset
        switch dragStartBehavior {
        case .start:
            _initialPosition = _initialPosition + delta
            localUpdateDelta = .zero
        case .down:
            localUpdateDelta = getDeltaForDetails(delta.local)
        }
        _pendingDragOffset = .zero
        _lastPendingEventTimestamp = nil
        _lastTransform = nil
        _checkStart(timestamp, pointer)
        if localUpdateDelta != .zero && onUpdate != nil {
            let localToGlobal: Matrix4?
            if let transform = transform {
                var invertedTransform = transform
                let det = invertedTransform.invert()
                localToGlobal = det != 0.0 ? invertedTransform : nil
            } else {
                localToGlobal = nil
            }
            let correctedLocalPosition = _initialPosition.local + localUpdateDelta
            let globalUpdateDelta = PointerEvent.transformDeltaViaPositions(
                untransformedEndPosition: correctedLocalPosition,
                untransformedDelta: localUpdateDelta,
                transform: localToGlobal
            )
            let updateDelta = OffsetPair(local: localUpdateDelta, global: globalUpdateDelta)
            let correctedPosition =
                _initialPosition + updateDelta  // Only adds delta for down behaviour
            _checkUpdate(
                sourceTimeStamp: timestamp,
                delta: localUpdateDelta,
                primaryDelta: getPrimaryValueFromOffset(localUpdateDelta),
                globalPosition: correctedPosition.global,
                localPosition: correctedPosition.local,
                pointer: pointer
            )
        }
        // This acceptGesture might have been called only for one pointer, instead
        // of all pointers. Resolve all pointers to `accepted`. This won't cause
        // infinite recursion because an accepted pointer won't be accepted again.
        resolve(.accepted)
    }

    /// **Dart Source:** `monodrag.dart:842-852`
    private func _checkStart(_ timestamp: Duration?, _ pointer: Int) {
        if onStart != nil {
            let details = DragStartDetails(
                globalPosition: _initialPosition.global,
                localPosition: _initialPosition.local,
                sourceTimeStamp: timestamp,
                kind: getKindForPointer(pointer)
            )
            invokeCallback("onStart", { self.onStart!(details) })
        }
    }

    /// **Dart Source:** `monodrag.dart:854-873`
    private func _checkUpdate(
        sourceTimeStamp: Duration?,
        delta: Offset,
        primaryDelta: Double?,
        globalPosition: Offset,
        localPosition: Offset?,
        pointer: Int
    ) {
        if onUpdate != nil {
            let details = DragUpdateDetails(
                globalPosition: globalPosition,
                localPosition: localPosition,
                sourceTimeStamp: sourceTimeStamp,
                delta: delta,
                primaryDelta: primaryDelta,
                kind: getKindForPointer(pointer)
            )
            invokeCallback("onUpdate", { self.onUpdate!(details) })
        }
    }

    /// **Dart Source:** `monodrag.dart:875-900`
    private func _checkEnd(_ pointer: Int) {
        if onEnd == nil {
            return
        }

        let tracker = _velocityTrackers[pointer]!
        let estimate = tracker.getVelocityEstimate()

        var details: DragEndDetails?
        let debugReport: () -> String
        if estimate == nil {
            debugReport = { "Could not estimate velocity." }
        } else {
            details = considerFling(estimate!, tracker.kind)
            if details != nil {
                let capturedDetails = details
                debugReport = { "\(estimate!); fling at \(capturedDetails!.velocity)." }
            } else {
                debugReport = { "\(estimate!); judged to not be a fling." }
            }
        }
        details = details ?? DragEndDetails(
            globalPosition: lastPosition.global,
            localPosition: lastPosition.local,
            primaryVelocity: 0.0
        )

        invokeCallback("onEnd", { self.onEnd!(details!) }, debugReport: debugReport)
    }

    /// **Dart Source:** `monodrag.dart:902-906`
    private func _checkCancel() {
        if onCancel != nil {
            invokeCallback("onCancel", onCancel!)
        }
    }

    // MARK: - dispose

    /// **Dart Source:** `monodrag.dart:909-912`
    open override func dispose() {
        _velocityTrackers.removeAll()
        super.dispose()
    }

    // MARK: - debugDescription

    /// **Dart Source:** `monodrag.dart:915-918`
    open override var debugDescription: String {
        return "drag"
    }
}

// MARK: - VerticalDragGestureRecognizer

/// Recognizes movement in the vertical direction.
///
/// Used for vertical scrolling.
///
/// See also:
///
///  * `HorizontalDragGestureRecognizer`, for a similar recognizer but for
///    horizontal movement.
///  * `MultiDragGestureRecognizer`, for a family of gesture recognizers that
///    track each touch point independently.
///
/// **Dart Source:** `monodrag.dart:931-983`
public class VerticalDragGestureRecognizer: DragGestureRecognizer {

    /// Create a gesture recognizer for interactions in the vertical axis.
    ///
    /// **Dart Source:** `monodrag.dart:935-939`
    public init(
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

    /// **Dart Source:** `monodrag.dart:942-947`
    public override func isFlingGesture(_ estimate: VelocityEstimate, _ kind: PointerDeviceKind) -> Bool {
        let minVelocity = minFlingVelocity ?? kMinFlingVelocity
        let minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings)
        return Swift.abs(estimate.pixelsPerSecond.dy) > minVelocity
            && Swift.abs(estimate.offset.dy) > minDistance
    }

    /// **Dart Source:** `monodrag.dart:950-962`
    public override func considerFling(_ estimate: VelocityEstimate, _ kind: PointerDeviceKind) -> DragEndDetails? {
        if !isFlingGesture(estimate, kind) {
            return nil
        }
        let maxVelocity = maxFlingVelocity ?? kMaxFlingVelocity
        let dy = clampDouble(estimate.pixelsPerSecond.dy, -maxVelocity, maxVelocity)
        return DragEndDetails(
            globalPosition: lastPosition.global,
            localPosition: lastPosition.local,
            velocity: Velocity(pixelsPerSecond: Offset(0, dy)),
            primaryVelocity: dy
        )
    }

    /// **Dart Source:** `monodrag.dart:965-970`
    public override func hasSufficientGlobalDistanceToAccept(
        _ pointerDeviceKind: PointerDeviceKind,
        _ deviceTouchSlop: Double?
    ) -> Bool {
        return Swift.abs(globalDistanceMoved) > computeHitSlop(pointerDeviceKind, gestureSettings)
    }

    /// **Dart Source:** `monodrag.dart:973`
    public override func getDeltaForDetails(_ delta: Offset) -> Offset {
        return Offset(0.0, delta.dy)
    }

    /// **Dart Source:** `monodrag.dart:976`
    public override func getPrimaryValueFromOffset(_ value: Offset) -> Double? {
        return value.dy
    }

    /// **Dart Source:** `monodrag.dart:979`
    fileprivate override func _getPrimaryDragAxis() -> _DragDirection? {
        return .vertical
    }

    /// **Dart Source:** `monodrag.dart:982`
    public override var debugDescription: String {
        return "vertical drag"
    }
}

// MARK: - HorizontalDragGestureRecognizer

/// Recognizes movement in the horizontal direction.
///
/// Used for horizontal scrolling.
///
/// See also:
///
///  * `VerticalDragGestureRecognizer`, for a similar recognizer but for
///    vertical movement.
///  * `MultiDragGestureRecognizer`, for a family of gesture recognizers that
///    track each touch point independently.
///
/// **Dart Source:** `monodrag.dart:995-1047`
public class HorizontalDragGestureRecognizer: DragGestureRecognizer {

    /// Create a gesture recognizer for interactions in the horizontal axis.
    ///
    /// **Dart Source:** `monodrag.dart:999-1003`
    public init(
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

    /// **Dart Source:** `monodrag.dart:1006-1011`
    public override func isFlingGesture(_ estimate: VelocityEstimate, _ kind: PointerDeviceKind) -> Bool {
        let minVelocity = minFlingVelocity ?? kMinFlingVelocity
        let minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings)
        return Swift.abs(estimate.pixelsPerSecond.dx) > minVelocity
            && Swift.abs(estimate.offset.dx) > minDistance
    }

    /// **Dart Source:** `monodrag.dart:1014-1026`
    public override func considerFling(_ estimate: VelocityEstimate, _ kind: PointerDeviceKind) -> DragEndDetails? {
        if !isFlingGesture(estimate, kind) {
            return nil
        }
        let maxVelocity = maxFlingVelocity ?? kMaxFlingVelocity
        let dx = clampDouble(estimate.pixelsPerSecond.dx, -maxVelocity, maxVelocity)
        return DragEndDetails(
            globalPosition: lastPosition.global,
            localPosition: lastPosition.local,
            velocity: Velocity(pixelsPerSecond: Offset(dx, 0)),
            primaryVelocity: dx
        )
    }

    /// **Dart Source:** `monodrag.dart:1029-1034`
    public override func hasSufficientGlobalDistanceToAccept(
        _ pointerDeviceKind: PointerDeviceKind,
        _ deviceTouchSlop: Double?
    ) -> Bool {
        return Swift.abs(globalDistanceMoved) > computeHitSlop(pointerDeviceKind, gestureSettings)
    }

    /// **Dart Source:** `monodrag.dart:1037`
    public override func getDeltaForDetails(_ delta: Offset) -> Offset {
        return Offset(delta.dx, 0.0)
    }

    /// **Dart Source:** `monodrag.dart:1040`
    public override func getPrimaryValueFromOffset(_ value: Offset) -> Double? {
        return value.dx
    }

    /// **Dart Source:** `monodrag.dart:1043`
    fileprivate override func _getPrimaryDragAxis() -> _DragDirection? {
        return .horizontal
    }

    /// **Dart Source:** `monodrag.dart:1046`
    public override var debugDescription: String {
        return "horizontal drag"
    }
}

// MARK: - PanGestureRecognizer

/// Recognizes movement both horizontally and vertically.
///
/// See also:
///
///  * `ImmediateMultiDragGestureRecognizer`, for a similar recognizer that
///    tracks each touch point independently.
///  * `DelayedMultiDragGestureRecognizer`, for a similar recognizer that
///    tracks each touch point independently, but that doesn't start until
///    some time has passed.
///
/// **Dart Source:** `monodrag.dart:1058-1101`
public class PanGestureRecognizer: DragGestureRecognizer {

    /// Create a gesture recognizer for tracking movement on a plane.
    ///
    /// **Dart Source:** `monodrag.dart:1060`
    public init(
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

    /// **Dart Source:** `monodrag.dart:1063-1068`
    public override func isFlingGesture(_ estimate: VelocityEstimate, _ kind: PointerDeviceKind) -> Bool {
        let minVelocity = minFlingVelocity ?? kMinFlingVelocity
        let minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings)
        return estimate.pixelsPerSecond.distanceSquared > minVelocity * minVelocity
            && estimate.offset.distanceSquared > minDistance * minDistance
    }

    /// **Dart Source:** `monodrag.dart:1071-1083`
    public override func considerFling(_ estimate: VelocityEstimate, _ kind: PointerDeviceKind) -> DragEndDetails? {
        if !isFlingGesture(estimate, kind) {
            return nil
        }
        let velocity = Velocity(
            pixelsPerSecond: estimate.pixelsPerSecond
        ).clampMagnitude(
            minValue: minFlingVelocity ?? kMinFlingVelocity,
            maxValue: maxFlingVelocity ?? kMaxFlingVelocity
        )
        return DragEndDetails(
            globalPosition: lastPosition.global,
            localPosition: lastPosition.local,
            velocity: velocity
        )
    }

    /// **Dart Source:** `monodrag.dart:1086-1091`
    public override func hasSufficientGlobalDistanceToAccept(
        _ pointerDeviceKind: PointerDeviceKind,
        _ deviceTouchSlop: Double?
    ) -> Bool {
        return Swift.abs(globalDistanceMoved) > computePanSlop(pointerDeviceKind, gestureSettings)
    }

    /// **Dart Source:** `monodrag.dart:1094`
    public override func getDeltaForDetails(_ delta: Offset) -> Offset {
        return delta
    }

    /// **Dart Source:** `monodrag.dart:1097`
    public override func getPrimaryValueFromOffset(_ value: Offset) -> Double? {
        return nil
    }

    /// **Dart Source:** `monodrag.dart:1100`
    public override var debugDescription: String {
        return "pan"
    }
}

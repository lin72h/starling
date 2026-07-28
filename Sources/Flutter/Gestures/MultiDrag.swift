// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Multi-drag gesture recognizers for tracking multiple pointers independently.
///
/// In contrast to `DragGestureRecognizer` (mono-drag), these recognizers watch
/// each pointer separately, which means multiple drags can be recognized
/// concurrently if multiple pointers are in contact with the screen.
///
/// Contains:
/// - `GestureMultiDragStartCallback` typealias
/// - `MultiDragPointerState` (abstract base for per-pointer state)
/// - `MultiDragGestureRecognizer` (abstract base recognizer)
/// - `ImmediateMultiDragGestureRecognizer` and its pointer state
/// - `HorizontalMultiDragGestureRecognizer` and its pointer state
/// - `VerticalMultiDragGestureRecognizer` and its pointer state
/// - `DelayedMultiDragGestureRecognizer` and its pointer state
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/multidrag.dart`
/// **Lines:** 1-601

import FlutterSwiftBridge
import Foundation

// MARK: - GestureMultiDragStartCallback

/// Signature for when `MultiDragGestureRecognizer` recognizes the start of a drag gesture.
///
/// **Dart Source:** `multidrag.dart:32`
public typealias GestureMultiDragStartCallback = (_ position: Offset) -> Drag?

// MARK: - MultiDragPointerState

/// Per-pointer state for a `MultiDragGestureRecognizer`.
///
/// A `MultiDragGestureRecognizer` tracks each pointer separately. The state for
/// each pointer is a subclass of `MultiDragPointerState`.
///
/// **Dart Source:** `multidrag.dart:38-198`
///
/// DIFFERENCE FROM DART: In Dart, this is an abstract class. In Swift, it is
/// an open class with `fatalError` for abstract methods that subclasses must
/// override.
open class MultiDragPointerState {

    /// Creates per-pointer state for a `MultiDragGestureRecognizer`.
    ///
    /// **Dart Source:** `multidrag.dart:40-43`
    public init(initialPosition: Offset, kind: PointerDeviceKind, gestureSettings: DeviceGestureSettings?) {
        self.initialPosition = initialPosition
        self.kind = kind
        self.gestureSettings = gestureSettings
        self._velocityTracker = VelocityTracker(kind: kind)
    }

    /// Device specific gesture configuration that should be preferred over
    /// framework constants.
    ///
    /// These settings are commonly retrieved from a `MediaQuery`.
    ///
    /// **Dart Source:** `multidrag.dart:49`
    public let gestureSettings: DeviceGestureSettings?

    /// The global coordinates of the pointer when the pointer contacted the screen.
    ///
    /// **Dart Source:** `multidrag.dart:52`
    public let initialPosition: Offset

    /// The velocity tracker for this pointer.
    ///
    /// **Dart Source:** `multidrag.dart:54`
    private let _velocityTracker: VelocityTracker

    /// The kind of pointer performing the multi-drag gesture.
    ///
    /// Used by subclasses to determine the appropriate hit slop, for example.
    ///
    /// **Dart Source:** `multidrag.dart:59`
    public let kind: PointerDeviceKind

    /// The drag client currently receiving updates.
    ///
    /// **Dart Source:** `multidrag.dart:61`
    private var _client: Drag?

    /// The offset of the pointer from the last position that was reported to the client.
    ///
    /// After the pointer contacts the screen, the pointer might move some
    /// distance before this movement will be recognized as a drag. This field
    /// accumulates that movement so that we can report it to the client after
    /// the drag starts.
    ///
    /// **Dart Source:** `multidrag.dart:69-70`
    public var pendingDelta: Offset? {
        return _pendingDelta
    }
    internal var _pendingDelta: Offset? = .zero

    /// **Dart Source:** `multidrag.dart:72`
    private var _lastPendingEventTimestamp: Duration?

    /// **Dart Source:** `multidrag.dart:74`
    private var _arenaEntry: GestureArenaEntry?

    /// **Dart Source:** `multidrag.dart:75-80`
    internal func _setArenaEntry(_ entry: GestureArenaEntry) {
        assert(_arenaEntry == nil)
        assert(pendingDelta != nil)
        assert(_client == nil)
        _arenaEntry = entry
    }

    // MARK: - Resolution

    /// Resolve this pointer's entry in the `GestureArenaManager` with the given disposition.
    ///
    /// **Dart Source:** `multidrag.dart:85-87`
    open func resolve(_ disposition: GestureDisposition) {
        _arenaEntry!.resolve(disposition)
    }

    // MARK: - Move Handling

    /// **Dart Source:** `multidrag.dart:89-110`
    internal func _move(_ event: PointerMoveEvent) {
        assert(_arenaEntry != nil)
        if !event.synthesized {
            _velocityTracker.addPosition(event.timeStamp, event.position)
        }
        if _client != nil {
            assert(pendingDelta == nil)
            // Call client last to avoid reentrancy.
            _client!.update(
                DragUpdateDetails(
                    globalPosition: event.position,
                    sourceTimeStamp: event.timeStamp,
                    delta: event.delta
                )
            )
        } else {
            assert(pendingDelta != nil)
            _pendingDelta = _pendingDelta! + event.delta
            _lastPendingEventTimestamp = event.timeStamp
            checkForResolutionAfterMove()
        }
    }

    /// Override this to call `resolve()` if the drag should be accepted or rejected.
    /// This is called when a pointer movement is received, but only if the gesture
    /// has not yet been resolved.
    ///
    /// **Dart Source:** `multidrag.dart:116`
    open func checkForResolutionAfterMove() {}

    // MARK: - Accept/Reject

    /// Called when the gesture was accepted.
    ///
    /// Either immediately or at some future point before the gesture is disposed,
    /// call `starter`, passing it `initialPosition`, to start the drag.
    ///
    /// **Dart Source:** `multidrag.dart:123`
    open func accepted(_ starter: @escaping GestureMultiDragStartCallback) {
        fatalError("Subclasses must override accepted(_:)")
    }

    /// Called when the gesture was rejected.
    ///
    /// The `dispose` method will be called immediately following this.
    ///
    /// **Dart Source:** `multidrag.dart:130-137`
    open func rejected() {
        assert(_arenaEntry != nil)
        assert(_client == nil)
        assert(pendingDelta != nil)
        _pendingDelta = nil
        _lastPendingEventTimestamp = nil
        _arenaEntry = nil
    }

    // MARK: - Drag Start

    /// **Dart Source:** `multidrag.dart:139-153`
    internal func _startDrag(_ client: Drag) {
        assert(_arenaEntry != nil)
        assert(_client == nil)
        assert(pendingDelta != nil)
        _client = client
        let details = DragUpdateDetails(
            globalPosition: initialPosition,
            sourceTimeStamp: _lastPendingEventTimestamp,
            delta: pendingDelta!
        )
        _pendingDelta = nil
        _lastPendingEventTimestamp = nil
        // Call client last to avoid reentrancy.
        _client!.update(details)
    }

    // MARK: - Up/Cancel

    /// **Dart Source:** `multidrag.dart:155-169`
    internal func _up() {
        assert(_arenaEntry != nil)
        if _client != nil {
            assert(pendingDelta == nil)
            let details = DragEndDetails(velocity: _velocityTracker.getVelocity())
            let client = _client!
            _client = nil
            // Call client last to avoid reentrancy.
            client.end(details)
        } else {
            assert(pendingDelta != nil)
            _pendingDelta = nil
            _lastPendingEventTimestamp = nil
        }
    }

    /// **Dart Source:** `multidrag.dart:171-184`
    internal func _cancel() {
        assert(_arenaEntry != nil)
        if _client != nil {
            assert(pendingDelta == nil)
            let client = _client!
            _client = nil
            // Call client last to avoid reentrancy.
            client.cancel()
        } else {
            assert(pendingDelta != nil)
            _pendingDelta = nil
            _lastPendingEventTimestamp = nil
        }
    }

    // MARK: - Dispose

    /// Releases any resources used by the object.
    ///
    /// **Dart Source:** `multidrag.dart:189-197`
    open func dispose() {
        _arenaEntry?.resolve(.rejected)
        _arenaEntry = nil
        assert({
            _pendingDelta = nil
            return true
        }())
    }
}

// MARK: - MultiDragGestureRecognizer

/// Recognizes movement on a per-pointer basis.
///
/// In contrast to `DragGestureRecognizer`, `MultiDragGestureRecognizer` watches
/// each pointer separately, which means multiple drags can be recognized
/// concurrently if multiple pointers are in contact with the screen.
///
/// `MultiDragGestureRecognizer` is not intended to be used directly. Instead,
/// consider using one of its subclasses to recognize specific types of drag
/// gestures.
///
/// See also:
///
///  * `ImmediateMultiDragGestureRecognizer`, the most straight-forward variant
///    of multi-pointer drag gesture recognizer.
///  * `HorizontalMultiDragGestureRecognizer`, which only recognizes drags that
///    start horizontally.
///  * `VerticalMultiDragGestureRecognizer`, which only recognizes drags that
///    start vertically.
///  * `DelayedMultiDragGestureRecognizer`, which only recognizes drags that
///    start after a long-press gesture.
///
/// **Dart Source:** `multidrag.dart:220-336`
///
/// DIFFERENCE FROM DART: In Dart, this is an abstract class. In Swift, it is
/// an open class with `fatalError` for the abstract `createNewPointerState`
/// method that subclasses must override.
open class MultiDragGestureRecognizer: GestureRecognizer {

    /// Initialize the object.
    ///
    /// **Dart Source:** `multidrag.dart:224-228`
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

    // MARK: - Properties

    /// Called when this class recognizes the start of a drag gesture.
    ///
    /// The remaining notifications for this drag gesture are delivered to the
    /// `Drag` object returned by this callback.
    ///
    /// **Dart Source:** `multidrag.dart:237`
    public var onStart: GestureMultiDragStartCallback?

    /// Maps pointer IDs to their per-pointer state objects.
    ///
    /// **Dart Source:** `multidrag.dart:239`
    private var _pointers: [Int: MultiDragPointerState]? = [:]

    /// Maps pointer IDs to their `PointerRouteEntry` tokens for route removal.
    ///
    /// DIFFERENCE FROM DART: In Dart, `PointerRouter.removeRoute` takes a function
    /// reference. In the Swift PointerRouter, `addRoute` returns a `PointerRouteEntry`
    /// token that must be passed to `removeRoute`. This dictionary stores those tokens.
    private var _routeEntries: [Int: PointerRouteEntry] = [:]

    // MARK: - Pointer Handling

    /// **Dart Source:** `multidrag.dart:242-249`
    open override func addAllowedPointer(_ event: PointerDownEvent) {
        assert(_pointers != nil)
        assert(!_pointers!.keys.contains(event.pointer))
        let state = createNewPointerState(event)
        _pointers![event.pointer] = state
        let routeEntry = GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent)
        _routeEntries[event.pointer] = routeEntry
        state._setArenaEntry(GestureBinding.instance.gestureArena.add(event.pointer, self))
    }

    /// Subclasses should override this method to create per-pointer state
    /// objects to track the pointer associated with the given event.
    ///
    /// **Dart Source:** `multidrag.dart:255`
    open func createNewPointerState(_ event: PointerDownEvent) -> MultiDragPointerState {
        fatalError("Subclasses must override createNewPointerState(_:)")
    }

    /// **Dart Source:** `multidrag.dart:257-280`
    private func _handleEvent(_ event: PointerEvent) {
        assert(_pointers != nil)
        assert(_pointers!.keys.contains(event.pointer))
        let state = _pointers![event.pointer]!
        if let moveEvent = event as? PointerMoveEvent {
            state._move(moveEvent)
            // We might be disposed here.
        } else if event is PointerUpEvent {
            assert(event.delta == .zero)
            state._up()
            // We might be disposed here.
            _removeState(event.pointer)
        } else if event is PointerCancelEvent {
            assert(event.delta == .zero)
            state._cancel()
            // We might be disposed here.
            _removeState(event.pointer)
        } else if !(event is PointerDownEvent) {
            // we get the PointerDownEvent that resulted in our addPointer getting called since we
            // add ourselves to the pointer router then (before the pointer router has heard of
            // the event).
            assertionFailure("Unexpected event type: \(type(of: event))")
        }
    }

    // MARK: - Arena Callbacks

    /// **Dart Source:** `multidrag.dart:283-290`
    open override func acceptGesture(_ pointer: Int) {
        assert(_pointers != nil)
        guard let state = _pointers![pointer] else {
            return  // We might already have canceled this drag if the up comes before the accept.
        }
        state.accepted { [weak self] (initialPosition: Offset) -> Drag? in
            return self?._startDrag(initialPosition, pointer)
        }
    }

    /// **Dart Source:** `multidrag.dart:292-306`
    private func _startDrag(_ initialPosition: Offset, _ pointer: Int) -> Drag? {
        assert(_pointers != nil)
        let state = _pointers![pointer]!
        assert(state._pendingDelta != nil)
        var drag: Drag?
        if onStart != nil {
            let callback: RecognizerCallback<Drag?> = { [self] in onStart!(initialPosition) }
            drag = invokeCallback("onStart", callback) ?? nil
        }
        if drag != nil {
            state._startDrag(drag!)
        } else {
            _removeState(pointer)
        }
        return drag
    }

    /// **Dart Source:** `multidrag.dart:309-316`
    open override func rejectGesture(_ pointer: Int) {
        assert(_pointers != nil)
        if _pointers!.keys.contains(pointer) {
            let state = _pointers![pointer]!
            state.rejected()
            _removeState(pointer)
        }
        // else we already preemptively forgot about it (e.g. we got an up event)
    }

    // MARK: - State Management

    /// **Dart Source:** `multidrag.dart:318-327`
    private func _removeState(_ pointer: Int) {
        if _pointers == nil {
            // We've already been disposed. It's harmless to skip removing the state
            // for the given pointer because dispose() has already removed it.
            return
        }
        assert(_pointers!.keys.contains(pointer))
        if let routeEntry = _routeEntries[pointer] {
            GestureBinding.instance.pointerRouter.removeRoute(pointer, routeEntry)
        }
        _routeEntries.removeValue(forKey: pointer)
        _pointers!.removeValue(forKey: pointer)!.dispose()
    }

    // MARK: - Dispose

    /// **Dart Source:** `multidrag.dart:330-335`
    open override func dispose() {
        let pointerKeys = Array(_pointers!.keys)
        for pointer in pointerKeys {
            _removeState(pointer)
        }
        assert(_pointers!.isEmpty)
        _pointers = nil
        super.dispose()
    }
}

// MARK: - ImmediatePointerState

/// Per-pointer state for `ImmediateMultiDragGestureRecognizer`.
///
/// Immediately accepts the drag when the pointer moves past the hit slop.
///
/// **Dart Source:** `multidrag.dart:338-353`
internal class ImmediatePointerState: MultiDragPointerState {

    /// **Dart Source:** `multidrag.dart:339`
    init(_ initialPosition: Offset, _ kind: PointerDeviceKind, _ gestureSettings: DeviceGestureSettings?) {
        super.init(initialPosition: initialPosition, kind: kind, gestureSettings: gestureSettings)
    }

    /// **Dart Source:** `multidrag.dart:342-347`
    override func checkForResolutionAfterMove() {
        assert(pendingDelta != nil)
        if pendingDelta!.distance > computeHitSlop(kind, gestureSettings) {
            resolve(.accepted)
        }
    }

    /// **Dart Source:** `multidrag.dart:350-352`
    override func accepted(_ starter: @escaping GestureMultiDragStartCallback) {
        _ = starter(initialPosition)
    }
}

// MARK: - ImmediateMultiDragGestureRecognizer

/// Recognizes movement both horizontally and vertically on a per-pointer basis.
///
/// In contrast to `PanGestureRecognizer`, `ImmediateMultiDragGestureRecognizer`
/// watches each pointer separately, which means multiple drags can be
/// recognized concurrently if multiple pointers are in contact with the screen.
///
/// See also:
///
///  * `PanGestureRecognizer`, which recognizes only one drag gesture at a time,
///    regardless of how many fingers are involved.
///  * `HorizontalMultiDragGestureRecognizer`, which only recognizes drags that
///    start horizontally.
///  * `VerticalMultiDragGestureRecognizer`, which only recognizes drags that
///    start vertically.
///  * `DelayedMultiDragGestureRecognizer`, which only recognizes drags that
///    start after a long-press gesture.
///
/// **Dart Source:** `multidrag.dart:371-388`
public class ImmediateMultiDragGestureRecognizer: MultiDragGestureRecognizer {

    /// Create a gesture recognizer for tracking multiple pointers at once.
    ///
    /// **Dart Source:** `multidrag.dart:375-379`
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

    /// **Dart Source:** `multidrag.dart:382-384`
    public override func createNewPointerState(_ event: PointerDownEvent) -> MultiDragPointerState {
        return ImmediatePointerState(event.position, event.kind, gestureSettings)
    }

    /// **Dart Source:** `multidrag.dart:387`
    public override var debugDescription: String {
        return "multidrag"
    }
}

// MARK: - HorizontalPointerState

/// Per-pointer state for `HorizontalMultiDragGestureRecognizer`.
///
/// Accepts the drag when the horizontal component of the pointer movement
/// exceeds the hit slop.
///
/// **Dart Source:** `multidrag.dart:390-405`
internal class HorizontalPointerState: MultiDragPointerState {

    /// **Dart Source:** `multidrag.dart:391`
    init(_ initialPosition: Offset, _ kind: PointerDeviceKind, _ gestureSettings: DeviceGestureSettings?) {
        super.init(initialPosition: initialPosition, kind: kind, gestureSettings: gestureSettings)
    }

    /// **Dart Source:** `multidrag.dart:394-399`
    override func checkForResolutionAfterMove() {
        assert(pendingDelta != nil)
        if Swift.abs(pendingDelta!.dx) > computeHitSlop(kind, gestureSettings) {
            resolve(.accepted)
        }
    }

    /// **Dart Source:** `multidrag.dart:402-404`
    override func accepted(_ starter: @escaping GestureMultiDragStartCallback) {
        _ = starter(initialPosition)
    }
}

// MARK: - HorizontalMultiDragGestureRecognizer

/// Recognizes movement in the horizontal direction on a per-pointer basis.
///
/// In contrast to `HorizontalDragGestureRecognizer`,
/// `HorizontalMultiDragGestureRecognizer` watches each pointer separately,
/// which means multiple drags can be recognized concurrently if multiple
/// pointers are in contact with the screen.
///
/// See also:
///
///  * `HorizontalDragGestureRecognizer`, a gesture recognizer that just
///    looks at horizontal movement.
///  * `ImmediateMultiDragGestureRecognizer`, a similar recognizer, but without
///    the limitation that the drag must start horizontally.
///  * `VerticalMultiDragGestureRecognizer`, which only recognizes drags that
///    start vertically.
///
/// **Dart Source:** `multidrag.dart:422-440`
public class HorizontalMultiDragGestureRecognizer: MultiDragGestureRecognizer {

    /// Create a gesture recognizer for tracking multiple pointers at once
    /// but only if they first move horizontally.
    ///
    /// **Dart Source:** `multidrag.dart:427-431`
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

    /// **Dart Source:** `multidrag.dart:434-436`
    public override func createNewPointerState(_ event: PointerDownEvent) -> MultiDragPointerState {
        return HorizontalPointerState(event.position, event.kind, gestureSettings)
    }

    /// **Dart Source:** `multidrag.dart:439`
    public override var debugDescription: String {
        return "horizontal multidrag"
    }
}

// MARK: - VerticalPointerState

/// Per-pointer state for `VerticalMultiDragGestureRecognizer`.
///
/// Accepts the drag when the vertical component of the pointer movement
/// exceeds the hit slop.
///
/// **Dart Source:** `multidrag.dart:442-457`
internal class VerticalPointerState: MultiDragPointerState {

    /// **Dart Source:** `multidrag.dart:443`
    init(_ initialPosition: Offset, _ kind: PointerDeviceKind, _ gestureSettings: DeviceGestureSettings?) {
        super.init(initialPosition: initialPosition, kind: kind, gestureSettings: gestureSettings)
    }

    /// **Dart Source:** `multidrag.dart:446-451`
    override func checkForResolutionAfterMove() {
        assert(pendingDelta != nil)
        if Swift.abs(pendingDelta!.dy) > computeHitSlop(kind, gestureSettings) {
            resolve(.accepted)
        }
    }

    /// **Dart Source:** `multidrag.dart:454-456`
    override func accepted(_ starter: @escaping GestureMultiDragStartCallback) {
        _ = starter(initialPosition)
    }
}

// MARK: - VerticalMultiDragGestureRecognizer

/// Recognizes movement in the vertical direction on a per-pointer basis.
///
/// In contrast to `VerticalDragGestureRecognizer`,
/// `VerticalMultiDragGestureRecognizer` watches each pointer separately,
/// which means multiple drags can be recognized concurrently if multiple
/// pointers are in contact with the screen.
///
/// See also:
///
///  * `VerticalDragGestureRecognizer`, a gesture recognizer that just
///    looks at vertical movement.
///  * `ImmediateMultiDragGestureRecognizer`, a similar recognizer, but without
///    the limitation that the drag must start vertically.
///  * `HorizontalMultiDragGestureRecognizer`, which only recognizes drags that
///    start horizontally.
///
/// **Dart Source:** `multidrag.dart:474-492`
public class VerticalMultiDragGestureRecognizer: MultiDragGestureRecognizer {

    /// Create a gesture recognizer for tracking multiple pointers at once
    /// but only if they first move vertically.
    ///
    /// **Dart Source:** `multidrag.dart:479-483`
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

    /// **Dart Source:** `multidrag.dart:486-488`
    public override func createNewPointerState(_ event: PointerDownEvent) -> MultiDragPointerState {
        return VerticalPointerState(event.position, event.kind, gestureSettings)
    }

    /// **Dart Source:** `multidrag.dart:491`
    public override var debugDescription: String {
        return "vertical multidrag"
    }
}

// MARK: - DelayedPointerState

/// Per-pointer state for `DelayedMultiDragGestureRecognizer`.
///
/// Uses a timer to delay recognition. If the pointer moves past the hit slop
/// before the timer fires, the gesture is rejected.
///
/// **Dart Source:** `multidrag.dart:494-554`
internal class DelayedPointerState: MultiDragPointerState {

    /// **Dart Source:** `multidrag.dart:495-497`
    init(_ initialPosition: Offset, _ delay: TimeInterval, _ kind: PointerDeviceKind, _ gestureSettings: DeviceGestureSettings?) {
        super.init(initialPosition: initialPosition, kind: kind, gestureSettings: gestureSettings)
        nonisolated(unsafe) let capturedSelf = self
        _timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            capturedSelf._delayPassed()
        }
    }

    /// **Dart Source:** `multidrag.dart:499`
    private var _timer: Timer?

    /// **Dart Source:** `multidrag.dart:500`
    private var _starter: GestureMultiDragStartCallback?

    /// **Dart Source:** `multidrag.dart:502-514`
    private func _delayPassed() {
        assert(_timer != nil)
        assert(pendingDelta != nil)
        assert(pendingDelta!.distance <= computeHitSlop(kind, gestureSettings))
        _timer = nil
        if _starter != nil {
            _ = _starter!(initialPosition)
            _starter = nil
        } else {
            resolve(.accepted)
        }
        assert(_starter == nil)
    }

    /// **Dart Source:** `multidrag.dart:516-519`
    private func _ensureTimerStopped() {
        _timer?.invalidate()
        _timer = nil
    }

    /// **Dart Source:** `multidrag.dart:522-529`
    override func accepted(_ starter: @escaping GestureMultiDragStartCallback) {
        assert(_starter == nil)
        if _timer == nil {
            _ = starter(initialPosition)
        } else {
            _starter = starter
        }
    }

    /// **Dart Source:** `multidrag.dart:532-547`
    override func checkForResolutionAfterMove() {
        if _timer == nil {
            // If we've been accepted by the gesture arena but the pointer moves too
            // much before the timer fires, we end up in a state where the timer is
            // stopped but we keep getting calls to this function because we never
            // actually started the drag. In this case, _starter will be non-nil
            // because we're essentially waiting forever to start the drag.
            assert(_starter != nil)
            return
        }
        assert(pendingDelta != nil)
        if pendingDelta!.distance > computeHitSlop(kind, gestureSettings) {
            resolve(.rejected)
            _ensureTimerStopped()
        }
    }

    /// **Dart Source:** `multidrag.dart:550-553`
    override func dispose() {
        _ensureTimerStopped()
        super.dispose()
    }
}

// MARK: - DelayedMultiDragGestureRecognizer

/// Recognizes movement both horizontally and vertically on a per-pointer basis
/// after a delay.
///
/// In contrast to `ImmediateMultiDragGestureRecognizer`,
/// `DelayedMultiDragGestureRecognizer` waits for a `delay` before recognizing
/// the drag. If the pointer moves more than `kTouchSlop` before the delay
/// expires, the gesture is not recognized.
///
/// In contrast to `PanGestureRecognizer`, `DelayedMultiDragGestureRecognizer`
/// watches each pointer separately, which means multiple drags can be
/// recognized concurrently if multiple pointers are in contact with the screen.
///
/// See also:
///
///  * `ImmediateMultiDragGestureRecognizer`, a similar recognizer but without
///    the delay.
///  * `PanGestureRecognizer`, which recognizes only one drag gesture at a time,
///    regardless of how many fingers are involved.
///
/// **Dart Source:** `multidrag.dart:574-601`
public class DelayedMultiDragGestureRecognizer: MultiDragGestureRecognizer {

    /// Creates a drag recognizer that works on a per-pointer basis after a delay.
    ///
    /// In order for a drag to be recognized by this recognizer, the pointer must
    /// remain in the same place for `delay` (up to `kTouchSlop`). The `delay`
    /// defaults to `kLongPressTimeout` to match `LongPressGestureRecognizer` but
    /// can be changed for specific behaviors.
    ///
    /// **Dart Source:** `multidrag.dart:583-588`
    public init(
        delay: TimeInterval = kLongPressTimeout,
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { buttons in buttons == kPrimaryButton }
    ) {
        self.delay = delay
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    /// The amount of time the pointer must remain in the same place for the drag
    /// to be recognized.
    ///
    /// **Dart Source:** `multidrag.dart:592`
    public let delay: TimeInterval

    /// **Dart Source:** `multidrag.dart:595-597`
    public override func createNewPointerState(_ event: PointerDownEvent) -> MultiDragPointerState {
        return DelayedPointerState(event.position, delay, event.kind, gestureSettings)
    }

    /// **Dart Source:** `multidrag.dart:600`
    public override var debugDescription: String {
        return "long multidrag"
    }
}

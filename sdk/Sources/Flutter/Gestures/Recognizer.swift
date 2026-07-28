// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Gesture recognizer base classes and related types.
///
/// Implements the core gesture recognition hierarchy: `GestureRecognizer`,
/// `OneSequenceGestureRecognizer`, `PrimaryPointerGestureRecognizer`,
/// and supporting types like `OffsetPair`, `DragStartBehavior`,
/// `MultitouchDragStrategy`, and `GestureRecognizerState`.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/recognizer.dart`
/// **Lines:** 1-844

import FlutterSwiftBridge
import Foundation

// MARK: - RecognizerCallback

/// Generic signature for callbacks passed to
/// `GestureRecognizer.invokeCallback`. This allows the
/// `GestureRecognizer.invokeCallback` mechanism to be generically used with
/// anonymous functions that return objects of particular types.
///
/// **Dart Source:** `recognizer.dart:40`
public typealias RecognizerCallback<T> = () -> T

// MARK: - DragStartBehavior

/// Configuration of offset passed to `DragStartDetails`.
///
/// See also:
///
///  * `DragGestureRecognizer.dragStartBehavior`, which gives an example for the
///  different behaviors.
///
/// **Dart Source:** `recognizer.dart:48-56`
public enum DragStartBehavior {
    /// Set the initial offset at the position where the first down event was
    /// detected.
    case down

    /// Set the initial position at the position where this gesture recognizer
    /// won the arena.
    case start
}

// MARK: - MultitouchDragStrategy

/// Configuration of multi-finger drag strategy on multi-touch devices.
///
/// When dragging with only one finger, there's no difference in behavior
/// between all the settings.
///
/// Used by `DragGestureRecognizer.multitouchDragStrategy`.
///
/// **Dart Source:** `recognizer.dart:64-109`
public enum MultitouchDragStrategy {
    /// Only the latest active pointer is tracked by the recognizer.
    ///
    /// If the tracked pointer is released, the first accepted of the remaining active
    /// pointers will continue to be tracked.
    ///
    /// This is the behavior typically seen on Android.
    case latestPointer

    /// All active pointers will be tracked, and the result is computed from
    /// the boundary pointers.
    ///
    /// The scrolling offset is determined by the maximum deltas of both directions.
    ///
    /// If the user is dragging with 3 pointers at the same time, each having
    /// [+10, +20, +33] pixels of offset, the recognizer will report a delta of 33 pixels.
    ///
    /// If the user is dragging with 5 pointers at the same time, each having
    /// [+10, +20, +33, -1, -12] pixels of offset, the recognizer will report a
    /// delta of (+33) + (-12) = 21 pixels.
    ///
    /// The panning `PanGestureRecognizer` offset is the average of all pointers.
    ///
    /// If the user is dragging with 3 pointers at the same time, each having
    /// [+10, +50, -30] pixels of offset in one direction (horizontal or vertical),
    /// the recognizer will report a delta of (10 + 50 -30) / 3 = 10 pixels in this direction.
    ///
    /// This is the behavior typically seen on iOS.
    case averageBoundaryPointers

    /// All active pointers will be tracked together. The scrolling offset
    /// is the sum of the offsets of all active pointers.
    ///
    /// When a `Scrollable` drives scrolling by this drag strategy, the scrolling
    /// speed will double or triple, depending on how many fingers are dragging
    /// at the same time.
    ///
    /// If the user is dragging with 3 pointers at the same time, each having
    /// [+10, +20, +33] pixels of offset, the recognizer will report a delta
    /// of 10 + 20 + 33 = 63 pixels.
    ///
    /// If the user is dragging with 5 pointers at the same time, each having
    /// [+10, +20, +33, -1, -12] pixels of offset, the recognizer will report
    /// a delta of 10 + 20 + 33 - 1 - 12 = 50 pixels.
    case sumAllPointers
}

// MARK: - AllowedButtonsFilter

/// Signature for `GestureRecognizer.allowedButtonsFilter`.
///
/// Used to filter the input buttons of incoming pointer events.
/// The parameter `buttons` comes from `PointerEvent.buttons`.
///
/// **Dart Source:** `recognizer.dart:115`
public typealias AllowedButtonsFilter = (_ buttons: Int) -> Bool

// MARK: - GestureRecognizer

/// The base class that all gesture recognizers inherit from.
///
/// Provides a basic API that can be used by classes that work with
/// gesture recognizers but don't care about the specific details of
/// the gestures recognizers themselves.
///
/// See also:
///
///  * `GestureDetector`, the widget that is used to detect built-in gestures.
///  * `RawGestureDetector`, the widget that is used to detect custom gestures.
///  * `debugPrintRecognizerCallbacksTrace`, a flag that can be set to help
///    debug issues with gesture recognizers.
///
/// **Dart Source:** `recognizer.dart:129-377`
///
/// DIFFERENCE FROM DART: In Dart, `GestureRecognizer` extends
/// `GestureArenaMember` (a class) with `DiagnosticableTreeMixin`. In Swift,
/// `GestureArenaMember` is a protocol. This is implemented as an open class
/// conforming to the `GestureArenaMember` protocol. The `DiagnosticableTreeMixin`
/// diagnostics are simplified.
open class GestureRecognizer: GestureArenaMember {

    /// Initializes the gesture recognizer.
    ///
    /// The argument is optional and is only used for debug purposes (e.g. in the
    /// `description` serialization).
    ///
    /// It's possible to limit this recognizer to a specific set of `PointerDeviceKind`s
    /// by providing the optional `supportedDevices` argument. If `supportedDevices` is nil,
    /// the recognizer will accept pointer events from all device kinds.
    ///
    /// **Dart Source:** `recognizer.dart:140-146`
    public init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { _ in true }
    ) {
        self.debugOwner = debugOwner
        self.supportedDevices = supportedDevices
        self.allowedButtonsFilter = allowedButtonsFilter
    }

    /// The recognizer's owner.
    ///
    /// This is used in the `description` serialization to report the object for which
    /// this gesture recognizer was created, to aid in debugging.
    ///
    /// **Dart Source:** `recognizer.dart:152`
    public let debugOwner: AnyObject?

    /// Optional device specific configuration for device gestures that will
    /// take precedence over framework defaults.
    ///
    /// **Dart Source:** `recognizer.dart:156`
    public var gestureSettings: DeviceGestureSettings?

    /// The kind of devices that are allowed to be recognized as provided by
    /// `supportedDevices` in the constructor. If nil, events from all device
    /// kinds will be tracked and recognized.
    ///
    /// **Dart Source:** `recognizer.dart:162`
    public var supportedDevices: Set<PointerDeviceKind>?

    /// Called when interaction starts. This limits the dragging behavior
    /// for custom clicks (such as scroll click). Its parameter comes
    /// from `PointerEvent.buttons`.
    ///
    /// Due to how `kPrimaryButton`, `kSecondaryButton`, etc., use integers,
    /// bitwise operations can help filter how buttons are pressed.
    ///
    /// Defaults to all buttons.
    ///
    /// **Dart Source:** `recognizer.dart:181`
    public let allowedButtonsFilter: AllowedButtonsFilter

    /// Holds a mapping between pointer IDs and the kind of devices they are
    /// coming from.
    ///
    /// **Dart Source:** `recognizer.dart:189`
    private var _pointerToKind: [Int: PointerDeviceKind] = [:]

    // MARK: - Pointer Registration

    /// Registers a new pointer that might be relevant to this gesture detector.
    ///
    /// The owner of this gesture recognizer calls `addPointer()` with the
    /// `PointerDownEvent` of each pointer that should be considered for
    /// this gesture.
    ///
    /// It's the GestureRecognizer's responsibility to then add itself
    /// to the global pointer router (see `PointerRouter`) to receive
    /// subsequent events for this pointer, and to add the pointer to
    /// the global gesture arena manager (see `GestureArenaManager`) to track
    /// that pointer.
    ///
    /// This method is called for each and all pointers being added. In
    /// most cases, you want to override `addAllowedPointer` instead.
    ///
    /// **Dart Source:** `recognizer.dart:243-250`
    public func addPointer(_ event: PointerDownEvent) {
        _pointerToKind[event.pointer] = event.kind
        if isPointerAllowed(event) {
            addAllowedPointer(event)
        } else {
            handleNonAllowedPointer(event)
        }
    }

    /// Registers a new pointer that's been checked to be allowed by this gesture
    /// recognizer.
    ///
    /// Subclasses of `GestureRecognizer` are supposed to override this method
    /// instead of `addPointer` because `addPointer` will be called for each
    /// pointer being added while `addAllowedPointer` is only called for pointers
    /// that are allowed by this recognizer.
    ///
    /// **Dart Source:** `recognizer.dart:260`
    open func addAllowedPointer(_ event: PointerDownEvent) {}

    /// Handles a pointer being added that's not allowed by this recognizer.
    ///
    /// Subclasses can override this method and reject the gesture.
    ///
    /// See:
    /// - `OneSequenceGestureRecognizer.handleNonAllowedPointer`.
    ///
    /// **Dart Source:** `recognizer.dart:269`
    open func handleNonAllowedPointer(_ event: PointerDownEvent) {}

    /// Checks whether or not a pointer is allowed to be tracked by this recognizer.
    ///
    /// **Dart Source:** `recognizer.dart:273-276`
    open func isPointerAllowed(_ event: PointerDownEvent) -> Bool {
        return (supportedDevices == nil || supportedDevices!.contains(event.kind))
            && allowedButtonsFilter(event.buttons)
    }

    /// Registers a new pointer pan/zoom that might be relevant to this gesture
    /// detector.
    ///
    /// A pointer pan/zoom is a stream of events that conveys data covering
    /// pan, zoom, and rotate data from a multi-finger trackpad gesture.
    ///
    /// This method is called for each and all pointers being added. In
    /// most cases, you want to override `addAllowedPointerPanZoom` instead.
    ///
    /// **Dart Source:** `recognizer.dart:209-216`
    public func addPointerPanZoom(_ event: PointerPanZoomStartEvent) {
        _pointerToKind[event.pointer] = event.kind
        if isPointerPanZoomAllowed(event) {
            addAllowedPointerPanZoom(event)
        } else {
            handleNonAllowedPointerPanZoom(event)
        }
    }

    /// Registers a new pointer pan/zoom that's been checked to be allowed by this
    /// gesture recognizer.
    ///
    /// Subclasses of `GestureRecognizer` are supposed to override this method
    /// instead of `addPointerPanZoom`.
    ///
    /// **Dart Source:** `recognizer.dart:226`
    open func addAllowedPointerPanZoom(_ event: PointerPanZoomStartEvent) {}

    /// Handles a pointer pan/zoom being added that's not allowed by this recognizer.
    ///
    /// Subclasses can override this method and reject the gesture.
    ///
    /// **Dart Source:** `recognizer.dart:282`
    open func handleNonAllowedPointerPanZoom(_ event: PointerPanZoomStartEvent) {}

    /// Checks whether or not a pointer pan/zoom is allowed to be tracked by this recognizer.
    ///
    /// **Dart Source:** `recognizer.dart:286-288`
    open func isPointerPanZoomAllowed(_ event: PointerPanZoomStartEvent) -> Bool {
        return supportedDevices == nil || supportedDevices!.contains(event.kind)
    }

    /// For a given pointer ID, returns the device kind associated with it.
    ///
    /// The pointer ID is expected to be a valid one i.e. an event was received
    /// with that pointer ID.
    ///
    /// **Dart Source:** `recognizer.dart:295-298`
    public func getKindForPointer(_ pointer: Int) -> PointerDeviceKind {
        assert(_pointerToKind[pointer] != nil)
        return _pointerToKind[pointer]!
    }

    // MARK: - Lifecycle

    /// Releases any resources used by the object.
    ///
    /// This method is called by the owner of this gesture recognizer
    /// when the object is no longer needed (e.g. when a gesture
    /// recognizer is being unregistered from a `GestureDetector`, the
    /// GestureDetector widget calls this method).
    ///
    /// **Dart Source:** `recognizer.dart:307-309`
    open func dispose() {
        // Subclasses should clean up their resources.
    }

    // MARK: - Debug Description

    /// Returns a very short pretty description of the gesture that the
    /// recognizer looks for, like 'tap' or 'horizontal drag'.
    ///
    /// **Dart Source:** `recognizer.dart:313`
    open var debugDescription: String {
        return "GestureRecognizer"
    }

    // MARK: - GestureArenaMember

    /// Called when this member wins the arena for the given pointer id.
    ///
    /// **Dart Source:** `recognizer.dart` (inherited from `GestureArenaMember`)
    open func acceptGesture(_ pointer: Int) {}

    /// Called when this member loses the arena for the given pointer id.
    ///
    /// **Dart Source:** `recognizer.dart` (inherited from `GestureArenaMember`)
    open func rejectGesture(_ pointer: Int) {}

    // MARK: - Callback Invocation

    /// Invoke a callback provided by the application, catching and logging any
    /// exceptions.
    ///
    /// The `name` argument is ignored except when reporting exceptions.
    ///
    /// The `debugReport` argument is optional and is used when
    /// `debugPrintRecognizerCallbacksTrace` is true. If specified, it must be a
    /// callback that returns a string describing useful debugging information,
    /// e.g. the arguments passed to the callback.
    ///
    /// **Dart Source:** `recognizer.dart:326-370`
    ///
    /// DIFFERENCE FROM DART: In Dart, exceptions are caught and reported via
    /// `FlutterError.reportError`. In Swift, the callback is non-throwing by
    /// default, so we invoke it directly. Debug tracing is preserved.
    @discardableResult
    open func invokeCallback<T>(
        _ name: String,
        _ callback: RecognizerCallback<T>,
        debugReport: (() -> String)? = nil
    ) -> T? {
        var result: T?
        assert({
            if debugPrintRecognizerCallbacksTrace {
                let report = debugReport?()
                // The 19 in the line below is the width of the prefix used by
                // _debugLogDiagnostic in arena.dart.
                let prefix = debugPrintGestureArenaDiagnostics ? "\(String(repeating: " ", count: 19))\u{2759} " : ""
                debugPrint(
                    "\(prefix)\(self) calling \(name) callback.\(report?.isEmpty == false ? " \(report!)" : "")",
                    nil
                )
            }
            return true
        }())
        result = callback()
        return result
    }
}

// MARK: - OneSequenceGestureRecognizer

/// Base class for gesture recognizers that can only recognize one
/// gesture at a time. For example, a single `TapGestureRecognizer`
/// can never recognize two taps happening simultaneously, even if
/// multiple pointers are placed on the same widget.
///
/// This is in contrast to, for instance, `MultiTapGestureRecognizer`,
/// which manages each pointer independently and can consider multiple
/// simultaneous touches to each result in a separate tap.
///
/// **Dart Source:** `recognizer.dart:387-552`
///
/// DIFFERENCE FROM DART: In Dart, this is an abstract class. In Swift, it is
/// an open class. Subclasses must override `handleEvent(_:)` and
/// `didStopTrackingLastPointer(_:)`.
open class OneSequenceGestureRecognizer: GestureRecognizer {

    /// Initialize the object.
    ///
    /// **Dart Source:** `recognizer.dart:391-395`
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

    /// Maps pointer IDs to their gesture arena entries.
    ///
    /// **Dart Source:** `recognizer.dart:397`
    private var _entries: [Int: GestureArenaEntry] = [:]

    /// The set of pointer IDs currently being tracked by this recognizer.
    ///
    /// **Dart Source:** `recognizer.dart:398`
    private var _trackedPointers: Set<Int> = []

    /// Maps pointer IDs to their `PointerRouteEntry` tokens for route removal.
    ///
    /// DIFFERENCE FROM DART: In Dart, `PointerRouter.removeRoute` takes a
    /// function reference. In the Swift PointerRouter, `addRoute` returns a
    /// `PointerRouteEntry` token that must be passed to `removeRoute`. This
    /// dictionary stores those tokens.
    private var _routeEntries: [Int: PointerRouteEntry] = [:]

    // MARK: - Pointer Handling

    /// **Dart Source:** `recognizer.dart:402-404`
    open override func addAllowedPointer(_ event: PointerDownEvent) {
        startTrackingPointer(event.pointer, event.transform)
    }

    /// **Dart Source:** `recognizer.dart:408-410`
    open override func handleNonAllowedPointer(_ event: PointerDownEvent) {
        resolve(.rejected)
    }

    /// Called when a pointer event is routed to this recognizer.
    ///
    /// This will be called for every pointer event while the pointer is being
    /// tracked. Typically, this recognizer will start tracking the pointer in
    /// `addAllowedPointer`, which means that `handleEvent` will be called
    /// starting with the `PointerDownEvent` that was passed to `addAllowedPointer`.
    ///
    /// See also:
    ///
    ///  * `startTrackingPointer`, which causes pointer events to be routed to
    ///    this recognizer.
    ///  * `stopTrackingPointer`, which stops events from being routed to this
    ///    recognizer.
    ///  * `stopTrackingIfPointerNoLongerDown`, which conditionally stops events
    ///    from being routed to this recognizer.
    ///
    /// **Dart Source:** `recognizer.dart:428`
    open func handleEvent(_ event: PointerEvent) {
        // Subclasses must override this method.
    }

    /// **Dart Source:** `recognizer.dart:431`
    open override func acceptGesture(_ pointer: Int) {}

    /// **Dart Source:** `recognizer.dart:434`
    open override func rejectGesture(_ pointer: Int) {}

    /// Called when the number of pointers this recognizer is tracking changes from one to zero.
    ///
    /// The given pointer ID is the ID of the last pointer this recognizer was
    /// tracking.
    ///
    /// **Dart Source:** `recognizer.dart:441`
    open func didStopTrackingLastPointer(_ pointer: Int) {
        // Subclasses must override this method.
    }

    // MARK: - Resolution

    /// Resolves this recognizer's participation in each gesture arena with the
    /// given disposition.
    ///
    /// **Dart Source:** `recognizer.dart:447-453`
    open func resolve(_ disposition: GestureDisposition) {
        let localEntries = Array(_entries.values)
        _entries.removeAll()
        for entry in localEntries {
            entry.resolve(disposition)
        }
    }

    /// Resolves this recognizer's participation in the given gesture arena with
    /// the given disposition.
    ///
    /// **Dart Source:** `recognizer.dart:459-465`
    open func resolvePointer(_ pointer: Int, _ disposition: GestureDisposition) {
        if let entry = _entries[pointer] {
            _entries.removeValue(forKey: pointer)
            entry.resolve(disposition)
        }
    }

    // MARK: - Lifecycle

    /// **Dart Source:** `recognizer.dart:467-476`
    open override func dispose() {
        resolve(.rejected)
        for pointer in _trackedPointers {
            if let routeEntry = _routeEntries[pointer] {
                GestureBinding.instance.pointerRouter.removeRoute(pointer, routeEntry)
            }
        }
        _trackedPointers.removeAll()
        _routeEntries.removeAll()
        assert(_entries.isEmpty)
        super.dispose()
    }

    // MARK: - Team

    /// The team that this recognizer belongs to, if any.
    ///
    /// If `team` is nil, this recognizer competes directly in the
    /// `GestureArenaManager` to recognize a sequence of pointer events as a
    /// gesture. If `team` is non-nil, this recognizer competes in the arena in
    /// a group with other recognizers on the same team.
    ///
    /// A recognizer can be assigned to a team only when it is not participating
    /// in the arena. For example, a common time to assign a recognizer to a team
    /// is shortly after creating the recognizer.
    ///
    /// **Dart Source:** `recognizer.dart:488-498`
    public var team: GestureArenaTeam? {
        get { _team }
        set {
            assert(newValue != nil)
            assert(_entries.isEmpty)
            assert(_trackedPointers.isEmpty)
            assert(_team == nil)
            _team = newValue
        }
    }
    private var _team: GestureArenaTeam?

    /// Adds this recognizer (or its team) to the gesture arena for the specified
    /// pointer.
    ///
    /// **Dart Source:** `recognizer.dart:500-502`
    private func _addPointerToArena(_ pointer: Int) -> GestureArenaEntry {
        if let team = _team {
            return team.add(pointer, self)
        }
        return GestureBinding.instance.gestureArena.add(pointer, self)
    }

    // MARK: - Pointer Tracking

    /// Causes events related to the given pointer ID to be routed to this recognizer.
    ///
    /// The pointer events are transformed according to `transform` and then delivered
    /// to `handleEvent`. The value for the `transform` argument is usually obtained
    /// from `PointerDownEvent.transform` to transform the events from the global
    /// coordinate space into the coordinate space of the event receiver. It may be
    /// nil if no transformation is necessary.
    ///
    /// Use `stopTrackingPointer` to remove the route added by this function.
    ///
    /// This method also adds this recognizer (or its team if it's non-nil) to
    /// the gesture arena for the specified pointer.
    ///
    /// This is called by `OneSequenceGestureRecognizer.addAllowedPointer`.
    ///
    /// **Dart Source:** `recognizer.dart:519-525`
    open func startTrackingPointer(_ pointer: Int, _ transform: Matrix4? = nil) {
        let routeEntry = GestureBinding.instance.pointerRouter.addRoute(
            pointer, handleEvent, transform
        )
        _routeEntries[pointer] = routeEntry
        _trackedPointers.insert(pointer)
        // TODO(goderbauer): Enable assert after recognizers properly clean up their defunct
        // `_entries`, see https://github.com/flutter/flutter/issues/117356.
        // assert(_entries[pointer] == nil)
        _entries[pointer] = _addPointerToArena(pointer)
    }

    /// Stops events related to the given pointer ID from being routed to this recognizer.
    ///
    /// If this function reduces the number of tracked pointers to zero, it will
    /// call `didStopTrackingLastPointer` synchronously.
    ///
    /// Use `startTrackingPointer` to add the routes in the first place.
    ///
    /// **Dart Source:** `recognizer.dart:534-542`
    open func stopTrackingPointer(_ pointer: Int) {
        if _trackedPointers.contains(pointer) {
            if let routeEntry = _routeEntries[pointer] {
                GestureBinding.instance.pointerRouter.removeRoute(pointer, routeEntry)
            }
            _routeEntries.removeValue(forKey: pointer)
            _trackedPointers.remove(pointer)
            if _trackedPointers.isEmpty {
                didStopTrackingLastPointer(pointer)
            }
        }
    }

    /// Stops tracking the pointer associated with the given event if the event is
    /// a `PointerUpEvent` or a `PointerCancelEvent` event.
    ///
    /// **Dart Source:** `recognizer.dart:547-551`
    open func stopTrackingIfPointerNoLongerDown(_ event: PointerEvent) {
        if event is PointerUpEvent || event is PointerCancelEvent || event is PointerPanZoomEndEvent {
            stopTrackingPointer(event.pointer)
        }
    }
}

// MARK: - GestureRecognizerState

/// The possible states of a `PrimaryPointerGestureRecognizer`.
///
/// The recognizer advances from `ready` to `possible` when it starts tracking a
/// primary pointer. Where it advances from there depends on how the gesture is
/// resolved for that pointer:
///
///  * If the primary pointer is resolved by the gesture winning the arena, the
///    recognizer stays in the `possible` state as long as it continues to track
///    a pointer.
///  * If the primary pointer is resolved by the gesture being rejected and
///    losing the arena, the recognizer's state advances to `defunct`.
///
/// Once the recognizer has stopped tracking any remaining pointers, the
/// recognizer returns to `ready`.
///
/// **Dart Source:** `recognizer.dart:568-581`
public enum GestureRecognizerState {
    /// The recognizer is ready to start recognizing a gesture.
    case ready

    /// The sequence of pointer events seen thus far is consistent with the
    /// gesture the recognizer is attempting to recognize but the gesture has not
    /// been accepted definitively.
    case possible

    /// Further pointer events cannot cause this recognizer to recognize the
    /// gesture until the recognizer returns to the `ready` state (typically when
    /// all the pointers the recognizer is tracking are removed from the screen).
    case defunct
}

// MARK: - Private Constants

/// Sentinel value to indicate no touch slop was specified.
///
/// **Dart Source:** `recognizer.dart:584`
///
/// DIFFERENCE FROM DART: Made public so it can be used as a default argument
/// value in the public initializer. Prefixed with underscore to discourage
/// external use.
public let _unsetTouchSlop: Double = -1.0

// MARK: - PrimaryPointerGestureRecognizer

/// A base class for gesture recognizers that track a single primary pointer.
///
/// Gestures based on this class will stop tracking the gesture if the primary
/// pointer travels beyond `preAcceptSlopTolerance` or `postAcceptSlopTolerance`
/// pixels from the original contact point of the gesture.
///
/// If the `preAcceptSlopTolerance` was breached before the gesture was accepted
/// in the gesture arena, the gesture will be rejected.
///
/// **Dart Source:** `recognizer.dart:594-800`
///
/// DIFFERENCE FROM DART: In Dart, this is an abstract class. In Swift, it is
/// an open class. Subclasses must override `handlePrimaryPointer(_:)`.
open class PrimaryPointerGestureRecognizer: OneSequenceGestureRecognizer {

    /// Initializes the `deadline` field during construction of subclasses.
    ///
    /// **Dart Source:** `recognizer.dart:598-618`
    public init(
        deadline: TimeInterval? = nil,
        preAcceptSlopTolerance: Double? = _unsetTouchSlop,
        postAcceptSlopTolerance: Double? = _unsetTouchSlop,
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { _ in true }
    ) {
        assert(
            preAcceptSlopTolerance == _unsetTouchSlop
                || preAcceptSlopTolerance == nil
                || preAcceptSlopTolerance! >= 0,
            "The preAcceptSlopTolerance must be unspecified, positive, or nil"
        )
        assert(
            postAcceptSlopTolerance == _unsetTouchSlop
                || postAcceptSlopTolerance == nil
                || postAcceptSlopTolerance! >= 0,
            "The postAcceptSlopTolerance must be unspecified, positive, or nil"
        )
        self.deadline = deadline
        self._preAcceptSlopTolerance = preAcceptSlopTolerance
        self._postAcceptSlopTolerance = postAcceptSlopTolerance
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    /// If non-nil, the recognizer will call `didExceedDeadline` after this
    /// amount of time has elapsed since starting to track the primary pointer.
    ///
    /// The `didExceedDeadline` will not be called if the primary pointer is
    /// accepted, rejected, or all pointers are up or canceled before `deadline`.
    ///
    /// **Dart Source:** `recognizer.dart:625`
    public let deadline: TimeInterval?

    /// The maximum distance in logical pixels the gesture is allowed to drift
    /// from the initial touch down position before the gesture is accepted.
    ///
    /// Drifting past the allowed slop amount causes the gesture to be rejected.
    ///
    /// Can be nil to indicate that the gesture can drift for any distance.
    /// Defaults to `gestureSettings.touchSlop` with a fallback of 18 logical pixels.
    ///
    /// **Dart Source:** `recognizer.dart:634-635`
    public var preAcceptSlopTolerance: Double? {
        return _preAcceptSlopTolerance == _unsetTouchSlop ? _defaultTouchSlop : _preAcceptSlopTolerance
    }

    /// The maximum distance in logical pixels the gesture is allowed to drift
    /// after the gesture has been accepted.
    ///
    /// Drifting past the allowed slop amount causes the gesture to stop tracking
    /// and signaling subsequent callbacks.
    ///
    /// Can be nil to indicate that the gesture can drift for any distance.
    /// Defaults to `gestureSettings.touchSlop` with a fallback of 18 logical pixels.
    ///
    /// **Dart Source:** `recognizer.dart:645-646`
    public var postAcceptSlopTolerance: Double? {
        return _postAcceptSlopTolerance == _unsetTouchSlop ? _defaultTouchSlop : _postAcceptSlopTolerance
    }

    /// **Dart Source:** `recognizer.dart:648-649`
    private let _preAcceptSlopTolerance: Double?
    private let _postAcceptSlopTolerance: Double?

    /// **Dart Source:** `recognizer.dart:651`
    private var _defaultTouchSlop: Double {
        return gestureSettings?.touchSlop ?? kTouchSlop
    }

    /// The current state of the recognizer.
    ///
    /// See `GestureRecognizerState` for a description of the states.
    ///
    /// **Dart Source:** `recognizer.dart:656-657`
    public var state: GestureRecognizerState {
        return _state
    }
    private var _state: GestureRecognizerState = .ready

    /// The ID of the primary pointer this recognizer is tracking.
    ///
    /// If this recognizer is no longer tracking any pointers, this field holds
    /// the ID of the primary pointer this recognizer was most recently tracking.
    /// This enables the recognizer to know which pointer it was most recently
    /// tracking when `acceptGesture` or `rejectGesture` is called (which may be
    /// called after the recognizer is no longer tracking a pointer if, e.g.
    /// `GestureArenaManager.hold` has been called, or if there are other
    /// recognizers keeping the arena open).
    ///
    /// **Dart Source:** `recognizer.dart:668-669`
    public var primaryPointer: Int? {
        return _primaryPointer
    }
    private var _primaryPointer: Int?

    /// The location at which the primary pointer contacted the screen.
    ///
    /// This will only be non-nil while this recognizer is tracking at least
    /// one pointer.
    ///
    /// **Dart Source:** `recognizer.dart:675-676`
    public var initialPosition: OffsetPair? {
        return _initialPosition
    }
    private var _initialPosition: OffsetPair?

    /// Whether this pointer is accepted by winning the arena or as defined by
    /// a subclass calling acceptGesture.
    ///
    /// **Dart Source:** `recognizer.dart:680`
    private var _gestureAccepted: Bool = false

    /// Timer used for deadline management.
    ///
    /// **Dart Source:** `recognizer.dart:681`
    ///
    /// DIFFERENCE FROM DART: Uses Foundation `Timer` instead of `dart:async` `Timer`.
    private var _timer: Timer?

    // MARK: - Pointer Handling

    /// **Dart Source:** `recognizer.dart:684-694`
    open override func addAllowedPointer(_ event: PointerDownEvent) {
        super.addAllowedPointer(event)
        if state == .ready {
            _state = .possible
            _primaryPointer = event.pointer
            _initialPosition = OffsetPair(local: event.localPosition, global: event.position)
            if let deadline = deadline {
                nonisolated(unsafe) let capturedEvent = event
                nonisolated(unsafe) let capturedSelf = self
                _timer = Timer.scheduledTimer(withTimeInterval: deadline, repeats: false) { _ in
                    capturedSelf.didExceedDeadlineWithEvent(capturedEvent)
                }
            }
        }
    }

    /// **Dart Source:** `recognizer.dart:697-701`
    open override func handleNonAllowedPointer(_ event: PointerDownEvent) {
        if !_gestureAccepted {
            super.handleNonAllowedPointer(event)
        }
    }

    /// **Dart Source:** `recognizer.dart:704-725`
    open override func handleEvent(_ event: PointerEvent) {
        assert(state != .ready)
        if state == .possible && event.pointer == primaryPointer {
            let isPreAcceptSlopPastTolerance =
                !_gestureAccepted
                && preAcceptSlopTolerance != nil
                && _getGlobalDistance(event) > preAcceptSlopTolerance!
            let isPostAcceptSlopPastTolerance =
                _gestureAccepted
                && postAcceptSlopTolerance != nil
                && _getGlobalDistance(event) > postAcceptSlopTolerance!

            if event is PointerMoveEvent
                && (isPreAcceptSlopPastTolerance || isPostAcceptSlopPastTolerance)
            {
                resolve(.rejected)
                stopTrackingPointer(primaryPointer!)
            } else {
                handlePrimaryPointer(event)
            }
        }
        stopTrackingIfPointerNoLongerDown(event)
    }

    /// Override to provide behavior for the primary pointer when the gesture is still possible.
    ///
    /// **Dart Source:** `recognizer.dart:729`
    open func handlePrimaryPointer(_ event: PointerEvent) {
        // Subclasses must override this method.
    }

    /// Override to be notified when `deadline` is exceeded.
    ///
    /// You must override this method or `didExceedDeadlineWithEvent` if you
    /// supply a `deadline`. Subclasses that override this method must _not_
    /// call `super.didExceedDeadline()`.
    ///
    /// **Dart Source:** `recognizer.dart:737-739`
    open func didExceedDeadline() {
        assert(deadline == nil)
    }

    /// Same as `didExceedDeadline` but receives the `event` that initiated the
    /// gesture.
    ///
    /// You must override this method or `didExceedDeadline` if you supply a
    /// `deadline`. Subclasses that override this method must _not_ call
    /// `super.didExceedDeadlineWithEvent(event)`.
    ///
    /// **Dart Source:** `recognizer.dart:748-750`
    open func didExceedDeadlineWithEvent(_ event: PointerDownEvent) {
        didExceedDeadline()
    }

    // MARK: - Arena Resolution

    /// **Dart Source:** `recognizer.dart:753-758`
    open override func acceptGesture(_ pointer: Int) {
        if pointer == primaryPointer {
            _stopTimer()
            _gestureAccepted = true
        }
    }

    /// **Dart Source:** `recognizer.dart:761-766`
    open override func rejectGesture(_ pointer: Int) {
        if pointer == primaryPointer && state == .possible {
            _stopTimer()
            _state = .defunct
        }
    }

    /// **Dart Source:** `recognizer.dart:769-775`
    open override func didStopTrackingLastPointer(_ pointer: Int) {
        assert(state != .ready)
        _stopTimer()
        _state = .ready
        _initialPosition = nil
        _gestureAccepted = false
    }

    /// **Dart Source:** `recognizer.dart:778-781`
    open override func dispose() {
        _stopTimer()
        super.dispose()
    }

    // MARK: - Private Helpers

    /// **Dart Source:** `recognizer.dart:783-788`
    private func _stopTimer() {
        if _timer != nil {
            _timer!.invalidate()
            _timer = nil
        }
    }

    /// **Dart Source:** `recognizer.dart:790-793`
    private func _getGlobalDistance(_ event: PointerEvent) -> Double {
        let offset = event.position - initialPosition!.global
        return offset.distance
    }
}

// MARK: - OffsetPair

/// A container for a `local` and `global` `Offset` pair.
///
/// Usually, the `global` `Offset` is in the coordinate space of the screen
/// after conversion to logical pixels and the `local` offset is the same
/// `Offset`, but transformed to a local coordinate space.
///
/// **Dart Source:** `recognizer.dart:808-844`
public struct OffsetPair: Equatable, Sendable {

    /// Creates an `OffsetPair` combining a `local` and `global` `Offset`.
    ///
    /// **Dart Source:** `recognizer.dart:810`
    public init(local: Offset, global: Offset) {
        self.local = local
        self.global = global
    }

    /// Creates an `OffsetPair` from `PointerEvent.localPosition` and
    /// `PointerEvent.position`.
    ///
    /// **Dart Source:** `recognizer.dart:814-816`
    public static func fromEventPosition(_ event: PointerEvent) -> OffsetPair {
        return OffsetPair(local: event.localPosition, global: event.position)
    }

    /// Creates an `OffsetPair` from `PointerEvent.localDelta` and
    /// `PointerEvent.delta`.
    ///
    /// **Dart Source:** `recognizer.dart:820`
    public static func fromEventDelta(_ event: PointerEvent) -> OffsetPair {
        return OffsetPair(local: event.localDelta, global: event.delta)
    }

    /// An `OffsetPair` where both `Offset`s are `Offset.zero`.
    ///
    /// **Dart Source:** `recognizer.dart:823`
    public static let zero = OffsetPair(local: .zero, global: .zero)

    /// The `Offset` in the local coordinate space.
    ///
    /// **Dart Source:** `recognizer.dart:826`
    public let local: Offset

    /// The `Offset` in the global coordinate space after conversion to logical
    /// pixels.
    ///
    /// **Dart Source:** `recognizer.dart:830`
    public let global: Offset

    /// Adds the `other.global` to `global` and `other.local` to `local`.
    ///
    /// **Dart Source:** `recognizer.dart:833-835`
    public static func + (lhs: OffsetPair, rhs: OffsetPair) -> OffsetPair {
        return OffsetPair(local: lhs.local + rhs.local, global: lhs.global + rhs.global)
    }

    /// Subtracts the `other.global` from `global` and `other.local` from `local`.
    ///
    /// **Dart Source:** `recognizer.dart:838-840`
    public static func - (lhs: OffsetPair, rhs: OffsetPair) -> OffsetPair {
        return OffsetPair(local: lhs.local - rhs.local, global: lhs.global - rhs.global)
    }
}

// MARK: - OffsetPair CustomStringConvertible

extension OffsetPair: CustomStringConvertible {
    /// **Dart Source:** `recognizer.dart:843`
    public var description: String {
        return "OffsetPair(local: \(local), global: \(global))"
    }
}

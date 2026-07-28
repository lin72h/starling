// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Scale gesture recognizer and related types.
///
/// Recognizes scale (pinch), pan, and rotation gestures using multi-pointer
/// tracking. Supports both touch input and trackpad pan/zoom events.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/scale.dart`
/// **Lines:** 1-861

import FlutterSwiftBridge
import Foundation

// MARK: - Constants

/// The default conversion factor when treating mouse scrolling as scaling.
///
/// The value was arbitrarily chosen to feel natural for most mousewheels on
/// all supported platforms.
///
/// **Dart Source:** `scale.dart:24`
public let kDefaultMouseScrollToScaleFactor: Double = 200

/// The default conversion factor when treating trackpad scrolling as scaling.
///
/// This factor matches the default `kDefaultMouseScrollToScaleFactor` of 200 to
/// feel natural for most trackpads, and the convention that scrolling up means
/// zooming in.
///
/// **Dart Source:** `scale.dart:31`
public let kDefaultTrackpadScrollToScaleFactor = Offset(0, -1 / kDefaultMouseScrollToScaleFactor)

// MARK: - ScaleState

/// The possible states of a `ScaleGestureRecognizer`.
///
/// **Dart Source:** `scale.dart:34-50`
private enum ScaleState: Int {
    /// The recognizer is ready to start recognizing a gesture.
    case ready

    /// The sequence of pointer events seen thus far is consistent with a scale
    /// gesture but the gesture has not been accepted definitively.
    case possible

    /// The sequence of pointer events seen thus far has been accepted
    /// definitively as a scale gesture.
    case accepted

    /// The sequence of pointer events seen thus far has been accepted
    /// definitively as a scale gesture and the pointers established a focal point
    /// and initial scale.
    case started
}

// MARK: - PointerPanZoomData

/// Internal data holder for trackpad pan/zoom pointer state.
///
/// **Dart Source:** `scale.dart:52-94`
private class PointerPanZoomData: CustomStringConvertible {

    /// Creates pan/zoom data from a `PointerPanZoomStartEvent`.
    ///
    /// **Dart Source:** `scale.dart:53-57`
    init(fromStartEvent parent: ScaleGestureRecognizer, event: PointerPanZoomStartEvent) {
        self.parent = parent
        self._position = event.position
        self._pan = .zero
        self._scale = 1
        self._rotation = 0
    }

    /// Creates pan/zoom data from a `PointerPanZoomUpdateEvent`.
    ///
    /// **Dart Source:** `scale.dart:59-63`
    init(fromUpdateEvent parent: ScaleGestureRecognizer, event: PointerPanZoomUpdateEvent) {
        self.parent = parent
        self._position = event.position
        self._pan = event.pan
        self._scale = event.scale
        self._rotation = event.rotation
    }

    /// **Dart Source:** `scale.dart:65`
    let parent: ScaleGestureRecognizer

    /// **Dart Source:** `scale.dart:66`
    let _position: Offset

    /// **Dart Source:** `scale.dart:67`
    let _pan: Offset

    /// **Dart Source:** `scale.dart:68`
    let _scale: Double

    /// **Dart Source:** `scale.dart:69`
    let _rotation: Double

    /// **Dart Source:** `scale.dart:71-76`
    var focalPoint: Offset {
        if parent.trackpadScrollCausesScale {
            return _position
        }
        return _position + _pan
    }

    /// **Dart Source:** `scale.dart:78-87`
    var scale: Double {
        if parent.trackpadScrollCausesScale {
            return _scale
                * exp(
                    (_pan.dx * parent.trackpadScrollToScaleFactor.dx)
                        + (_pan.dy * parent.trackpadScrollToScaleFactor.dy)
                )
        }
        return _scale
    }

    /// **Dart Source:** `scale.dart:89`
    var rotation: Double { _rotation }

    /// **Dart Source:** `scale.dart:91-93`
    var description: String {
        "PointerPanZoomData(parent: \(parent), _position: \(_position), _pan: \(_pan), _scale: \(_scale), _rotation: \(_rotation))"
    }
}

// MARK: - ScaleStartDetails

/// Details for `GestureScaleStartCallback`.
///
/// **Dart Source:** `scale.dart:97-154`
public struct ScaleStartDetails {

    /// Creates details for `GestureScaleStartCallback`.
    ///
    /// **Dart Source:** `scale.dart:99-105`
    public init(
        focalPoint: Offset = .zero,
        localFocalPoint: Offset? = nil,
        pointerCount: Int = 0,
        sourceTimeStamp: Duration? = nil,
        kind: PointerDeviceKind? = nil
    ) {
        self.focalPoint = focalPoint
        self.localFocalPoint = localFocalPoint ?? focalPoint
        self.pointerCount = pointerCount
        self.sourceTimeStamp = sourceTimeStamp
        self.kind = kind
    }

    /// The initial focal point of the pointers in contact with the screen.
    ///
    /// Reported in global coordinates.
    ///
    /// **Dart Source:** `scale.dart:115`
    public let focalPoint: Offset

    /// The initial focal point of the pointers in contact with the screen.
    ///
    /// Reported in local coordinates. Defaults to `focalPoint` if not set in the
    /// constructor.
    ///
    /// **Dart Source:** `scale.dart:126`
    public let localFocalPoint: Offset

    /// The number of pointers being tracked by the gesture recognizer.
    ///
    /// Typically this is the number of fingers being used to pan the widget using the gesture
    /// recognizer.
    ///
    /// **Dart Source:** `scale.dart:132`
    public let pointerCount: Int

    /// Recorded timestamp of the source pointer event that triggered the scale
    /// event.
    ///
    /// Could be nil if triggered from proxied events such as accessibility.
    ///
    /// **Dart Source:** `scale.dart:138`
    public let sourceTimeStamp: Duration?

    /// The kind of the device that initiated the event.
    ///
    /// If multiple pointers are touching the screen, the kind of the pointer
    /// device that first initiated the event is used.
    ///
    /// **Dart Source:** `scale.dart:144`
    public let kind: PointerDeviceKind?
}

// MARK: - ScaleUpdateDetails

/// Details for `GestureScaleUpdateCallback`.
///
/// **Dart Source:** `scale.dart:157-269`
public struct ScaleUpdateDetails {

    /// Creates details for `GestureScaleUpdateCallback`.
    ///
    /// The `scale`, `horizontalScale`, and `verticalScale` arguments must be
    /// greater than or equal to zero.
    ///
    /// **Dart Source:** `scale.dart:162-175`
    public init(
        focalPoint: Offset = .zero,
        localFocalPoint: Offset? = nil,
        scale: Double = 1.0,
        horizontalScale: Double = 1.0,
        verticalScale: Double = 1.0,
        rotation: Double = 0.0,
        pointerCount: Int = 0,
        focalPointDelta: Offset = .zero,
        sourceTimeStamp: Duration? = nil
    ) {
        assert(scale >= 0.0)
        assert(horizontalScale >= 0.0)
        assert(verticalScale >= 0.0)
        self.focalPoint = focalPoint
        self.localFocalPoint = localFocalPoint ?? focalPoint
        self.scale = scale
        self.horizontalScale = horizontalScale
        self.verticalScale = verticalScale
        self.rotation = rotation
        self.pointerCount = pointerCount
        self.focalPointDelta = focalPointDelta
        self.sourceTimeStamp = sourceTimeStamp
    }

    /// The amount the gesture's focal point has moved in the coordinate space of
    /// the event receiver since the previous update.
    ///
    /// Defaults to zero if not specified in the constructor.
    ///
    /// **Dart Source:** `scale.dart:181`
    public let focalPointDelta: Offset

    /// The focal point of the pointers in contact with the screen.
    ///
    /// Reported in global coordinates.
    ///
    /// **Dart Source:** `scale.dart:191`
    public let focalPoint: Offset

    /// The focal point of the pointers in contact with the screen.
    ///
    /// Reported in local coordinates. Defaults to `focalPoint` if not set in the
    /// constructor.
    ///
    /// **Dart Source:** `scale.dart:202`
    public let localFocalPoint: Offset

    /// The scale implied by the average distance between the pointers in contact
    /// with the screen.
    ///
    /// This value must be greater than or equal to zero.
    ///
    /// **Dart Source:** `scale.dart:213`
    public let scale: Double

    /// The scale implied by the average distance along the horizontal axis
    /// between the pointers in contact with the screen.
    ///
    /// This value must be greater than or equal to zero.
    ///
    /// **Dart Source:** `scale.dart:224`
    public let horizontalScale: Double

    /// The scale implied by the average distance along the vertical axis
    /// between the pointers in contact with the screen.
    ///
    /// This value must be greater than or equal to zero.
    ///
    /// **Dart Source:** `scale.dart:235`
    public let verticalScale: Double

    /// The angle implied by the first two pointers to enter in contact with
    /// the screen.
    ///
    /// Expressed in radians.
    ///
    /// **Dart Source:** `scale.dart:241`
    public let rotation: Double

    /// The number of pointers being tracked by the gesture recognizer.
    ///
    /// Typically this is the number of fingers being used to pan the widget using the gesture
    /// recognizer. Due to platform limitations, trackpad gestures count as two fingers
    /// even if more than two fingers are used.
    ///
    /// **Dart Source:** `scale.dart:248`
    public let pointerCount: Int

    /// Recorded timestamp of the source pointer event that triggered the scale
    /// event.
    ///
    /// Could be nil if triggered from proxied events such as accessibility.
    ///
    /// **Dart Source:** `scale.dart:254`
    public let sourceTimeStamp: Duration?
}

// MARK: - ScaleEndDetails

/// Details for `GestureScaleEndCallback`.
///
/// **Dart Source:** `scale.dart:272-295`
public struct ScaleEndDetails {

    /// Creates details for `GestureScaleEndCallback`.
    ///
    /// **Dart Source:** `scale.dart:274`
    public init(
        velocity: Velocity = .zero,
        scaleVelocity: Double = 0,
        pointerCount: Int = 0
    ) {
        self.velocity = velocity
        self.scaleVelocity = scaleVelocity
        self.pointerCount = pointerCount
    }

    /// The velocity of the last pointer to be lifted off of the screen.
    ///
    /// **Dart Source:** `scale.dart:277`
    public let velocity: Velocity

    /// The final velocity of the scale factor reported by the gesture.
    ///
    /// **Dart Source:** `scale.dart:280`
    public let scaleVelocity: Double

    /// The number of pointers being tracked by the gesture recognizer.
    ///
    /// Typically this is the number of fingers being used to pan the widget using the gesture
    /// recognizer.
    ///
    /// **Dart Source:** `scale.dart:286`
    public let pointerCount: Int
}

// MARK: - Callback Typealiases

/// Signature for when the pointers in contact with the screen have established
/// a focal point and initial scale of 1.0.
///
/// **Dart Source:** `scale.dart:299`
public typealias GestureScaleStartCallback = (_ details: ScaleStartDetails) -> Void

/// Signature for when the pointers in contact with the screen have indicated a
/// new focal point and/or scale.
///
/// **Dart Source:** `scale.dart:303`
public typealias GestureScaleUpdateCallback = (_ details: ScaleUpdateDetails) -> Void

/// Signature for when the pointers are no longer in contact with the screen.
///
/// **Dart Source:** `scale.dart:306`
public typealias GestureScaleEndCallback = (_ details: ScaleEndDetails) -> Void

// MARK: - Private Helpers

/// Returns whether the given velocity is fast enough to be a fling gesture.
///
/// **Dart Source:** `scale.dart:308-311`
private func _isFlingGesture(_ velocity: Velocity) -> Bool {
    let speedSquared = velocity.pixelsPerSecond.distanceSquared
    return speedSquared > kMinFlingVelocity * kMinFlingVelocity
}

// MARK: - LineBetweenPointers

/// Defines a line between two pointers on screen.
///
/// `LineBetweenPointers` is an abstraction of a line between two pointers in
/// contact with the screen. Used to track the rotation of a scale gesture.
///
/// **Dart Source:** `scale.dart:317-335`
private struct LineBetweenPointers {

    /// Creates a `LineBetweenPointers`. `pointerStartId` and `pointerEndId`
    /// should be different.
    ///
    /// **Dart Source:** `scale.dart:321-326`
    init(
        pointerStartLocation: Offset = .zero,
        pointerStartId: Int = 0,
        pointerEndLocation: Offset = .zero,
        pointerEndId: Int = 1
    ) {
        assert(pointerStartId != pointerEndId)
        self.pointerStartLocation = pointerStartLocation
        self.pointerStartId = pointerStartId
        self.pointerEndLocation = pointerEndLocation
        self.pointerEndId = pointerEndId
    }

    /// The location of the pointer that marks the start of the line.
    ///
    /// **Dart Source:** `scale.dart:329`
    let pointerStartLocation: Offset

    /// The id of the pointer that marks the start of the line.
    ///
    /// **Dart Source:** `scale.dart:330`
    let pointerStartId: Int

    /// The location of the pointer that marks the end of the line.
    ///
    /// **Dart Source:** `scale.dart:333`
    let pointerEndLocation: Offset

    /// The id of the pointer that marks the end of the line.
    ///
    /// **Dart Source:** `scale.dart:334`
    let pointerEndId: Int
}

// MARK: - ScaleGestureRecognizer

/// Recognizes a scale gesture.
///
/// `ScaleGestureRecognizer` tracks the pointers in contact with the screen and
/// calculates their focal point, indicated scale, and rotation. When a focal
/// point is established, the recognizer calls `onStart`. As the focal point,
/// scale, and rotation change, the recognizer calls `onUpdate`. When the
/// pointers are no longer in contact with the screen, the recognizer calls
/// `onEnd`.
///
/// **Dart Source:** `scale.dart:345-860`
public class ScaleGestureRecognizer: OneSequenceGestureRecognizer {

    /// Create a gesture recognizer for interactions intended for scaling content.
    ///
    /// **Dart Source:** `scale.dart:349-356`
    public init(
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { _ in true },
        dragStartBehavior: DragStartBehavior = .down,
        trackpadScrollCausesScale: Bool = false,
        trackpadScrollToScaleFactor: Offset = kDefaultTrackpadScrollToScaleFactor
    ) {
        self.dragStartBehavior = dragStartBehavior
        self.trackpadScrollCausesScale = trackpadScrollCausesScale
        self.trackpadScrollToScaleFactor = trackpadScrollToScaleFactor
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    // MARK: - Public Properties

    /// Determines what point is used as the starting point in all calculations
    /// involving this gesture.
    ///
    /// When set to `DragStartBehavior.down`, the scale is calculated starting
    /// from the position where the pointer first contacted the screen.
    ///
    /// When set to `DragStartBehavior.start`, the scale is calculated starting
    /// from the position where the scale gesture began.
    ///
    /// Defaults to `DragStartBehavior.down`.
    ///
    /// **Dart Source:** `scale.dart:358-378`
    public var dragStartBehavior: DragStartBehavior

    /// The pointers in contact with the screen have established a focal point and
    /// initial scale of 1.0.
    ///
    /// This won't be called until the gesture arena has determined that this
    /// `GestureRecognizer` has won the gesture.
    ///
    /// **Dart Source:** `scale.dart:390`
    public var onStart: GestureScaleStartCallback?

    /// The pointers in contact with the screen have indicated a new focal point
    /// and/or scale.
    ///
    /// **Dart Source:** `scale.dart:394`
    public var onUpdate: GestureScaleUpdateCallback?

    /// The pointers are no longer in contact with the screen.
    ///
    /// **Dart Source:** `scale.dart:397`
    public var onEnd: GestureScaleEndCallback?

    /// Whether scrolling up/down on a trackpad should cause scaling instead of
    /// panning.
    ///
    /// Defaults to false.
    ///
    /// **Dart Source:** `scale.dart:403-409`
    public var trackpadScrollCausesScale: Bool

    /// A factor to control the direction and magnitude of scale when converting
    /// trackpad scrolling.
    ///
    /// Incoming trackpad pan offsets will be divided by this factor to get scale
    /// values. Increasing this offset will reduce the amount of scaling caused by
    /// a fixed amount of trackpad scrolling.
    ///
    /// Defaults to `kDefaultTrackpadScrollToScaleFactor`.
    ///
    /// **Dart Source:** `scale.dart:411-421`
    public var trackpadScrollToScaleFactor: Offset

    /// The number of pointers being tracked by the gesture recognizer.
    ///
    /// Typically this is the number of fingers being used to pan the widget using the gesture
    /// recognizer.
    ///
    /// **Dart Source:** `scale.dart:427-432`
    public var pointerCount: Int {
        // PointerPanZoom protocol doesn't contain the exact number of pointers
        // used on the trackpad, as it isn't exposed by all platforms. However, it
        // will always be at least two.
        return (2 * _pointerPanZooms.count) + _pointerQueue.count
    }

    // MARK: - Private State

    /// **Dart Source:** `scale.dart:399`
    private var _state: ScaleState = .ready

    /// **Dart Source:** `scale.dart:401`
    private var _lastTransform: Matrix4?

    /// **Dart Source:** `scale.dart:434`
    private var _initialFocalPoint: Offset = .zero

    /// **Dart Source:** `scale.dart:435`
    private var _currentFocalPoint: Offset?

    /// **Dart Source:** `scale.dart:436`
    private var _initialSpan: Double = 0.0

    /// **Dart Source:** `scale.dart:437`
    private var _currentSpan: Double = 0.0

    /// **Dart Source:** `scale.dart:438`
    private var _initialHorizontalSpan: Double = 0.0

    /// **Dart Source:** `scale.dart:439`
    private var _currentHorizontalSpan: Double = 0.0

    /// **Dart Source:** `scale.dart:440`
    private var _initialVerticalSpan: Double = 0.0

    /// **Dart Source:** `scale.dart:441`
    private var _currentVerticalSpan: Double = 0.0

    /// **Dart Source:** `scale.dart:442`
    private var _localFocalPoint: Offset = .zero

    /// **Dart Source:** `scale.dart:443`
    private var _initialLine: LineBetweenPointers?

    /// **Dart Source:** `scale.dart:444`
    private var _currentLine: LineBetweenPointers?

    /// **Dart Source:** `scale.dart:445`
    private var _pointerLocations: [Int: Offset] = [:]

    /// A queue to sort pointers in order of entrance.
    ///
    /// **Dart Source:** `scale.dart:446`
    private var _pointerQueue: [Int] = []

    /// **Dart Source:** `scale.dart:447`
    private var _velocityTrackers: [Int: VelocityTracker] = [:]

    /// **Dart Source:** `scale.dart:448`
    private var _scaleVelocityTracker: VelocityTracker?

    /// **Dart Source:** `scale.dart:449`
    private var _delta: Offset = .zero

    /// **Dart Source:** `scale.dart:450`
    private var _pointerPanZooms: [Int: PointerPanZoomData] = [:]

    /// **Dart Source:** `scale.dart:451`
    private var _initialPanZoomScaleFactor: Double = 1

    /// **Dart Source:** `scale.dart:452`
    private var _initialPanZoomRotationFactor: Double = 0

    /// **Dart Source:** `scale.dart:453`
    private var _initialEventTimestamp: Duration?

    // MARK: - Computed Scale Factors

    /// **Dart Source:** `scale.dart:455`
    private var _pointerScaleFactor: Double {
        return _initialSpan > 0.0 ? _currentSpan / _initialSpan : 1.0
    }

    /// **Dart Source:** `scale.dart:457-458`
    private var _pointerHorizontalScaleFactor: Double {
        return _initialHorizontalSpan > 0.0 ? _currentHorizontalSpan / _initialHorizontalSpan : 1.0
    }

    /// **Dart Source:** `scale.dart:460-461`
    private var _pointerVerticalScaleFactor: Double {
        return _initialVerticalSpan > 0.0 ? _currentVerticalSpan / _initialVerticalSpan : 1.0
    }

    /// **Dart Source:** `scale.dart:463-469`
    private var _scaleFactor: Double {
        var scale = _pointerScaleFactor
        for p in _pointerPanZooms.values {
            scale *= p.scale / _initialPanZoomScaleFactor
        }
        return scale
    }

    /// **Dart Source:** `scale.dart:471-477`
    private var _horizontalScaleFactor: Double {
        var scale = _pointerHorizontalScaleFactor
        for p in _pointerPanZooms.values {
            scale *= p.scale / _initialPanZoomScaleFactor
        }
        return scale
    }

    /// **Dart Source:** `scale.dart:479-485`
    private var _verticalScaleFactor: Double {
        var scale = _pointerVerticalScaleFactor
        for p in _pointerPanZooms.values {
            scale *= p.scale / _initialPanZoomScaleFactor
        }
        return scale
    }

    /// **Dart Source:** `scale.dart:487-510`
    private func _computeRotationFactor() -> Double {
        var factor: Double = 0.0
        if let initialLine = _initialLine, let currentLine = _currentLine {
            let fx = initialLine.pointerStartLocation.dx
            let fy = initialLine.pointerStartLocation.dy
            let sx = initialLine.pointerEndLocation.dx
            let sy = initialLine.pointerEndLocation.dy

            let nfx = currentLine.pointerStartLocation.dx
            let nfy = currentLine.pointerStartLocation.dy
            let nsx = currentLine.pointerEndLocation.dx
            let nsy = currentLine.pointerEndLocation.dy

            let angle1 = atan2(fy - sy, fx - sx)
            let angle2 = atan2(nfy - nsy, nfx - nsx)

            factor = angle2 - angle1
        }
        for p in _pointerPanZooms.values {
            factor += p.rotation
        }
        factor -= _initialPanZoomRotationFactor
        return factor
    }

    // MARK: - Pointer Registration

    /// **Dart Source:** `scale.dart:512-526`
    public override func addAllowedPointer(_ event: PointerDownEvent) {
        super.addAllowedPointer(event)
        _velocityTrackers[event.pointer] = VelocityTracker(kind: event.kind)
        _initialEventTimestamp = event.timeStamp
        if _state == .ready {
            _state = .possible
            _initialSpan = 0.0
            _currentSpan = 0.0
            _initialHorizontalSpan = 0.0
            _currentHorizontalSpan = 0.0
            _initialVerticalSpan = 0.0
            _currentVerticalSpan = 0.0
        }
    }

    /// **Dart Source:** `scale.dart:529`
    public override func isPointerPanZoomAllowed(_ event: PointerPanZoomStartEvent) -> Bool {
        return true
    }

    /// **Dart Source:** `scale.dart:532-542`
    public override func addAllowedPointerPanZoom(_ event: PointerPanZoomStartEvent) {
        super.addAllowedPointerPanZoom(event)
        startTrackingPointer(event.pointer, event.transform)
        _velocityTrackers[event.pointer] = VelocityTracker(kind: event.kind)
        _initialEventTimestamp = event.timeStamp
        if _state == .ready {
            _state = .possible
            _initialPanZoomScaleFactor = 1.0
            _initialPanZoomRotationFactor = 0.0
        }
    }

    // MARK: - Event Handling

    /// **Dart Source:** `scale.dart:545-595`
    public override func handleEvent(_ event: PointerEvent) {
        assert(_state != .ready)
        var didChangeConfiguration = false
        var shouldStartIfAccepted = false

        if let moveEvent = event as? PointerMoveEvent {
            let tracker = _velocityTrackers[event.pointer]!
            if !moveEvent.synthesized {
                tracker.addPosition(event.timeStamp, event.position)
            }
            _pointerLocations[event.pointer] = event.position
            shouldStartIfAccepted = true
            _lastTransform = event.transform
        } else if event is PointerDownEvent {
            _pointerLocations[event.pointer] = event.position
            _pointerQueue.append(event.pointer)
            didChangeConfiguration = true
            shouldStartIfAccepted = true
            _lastTransform = event.transform
        } else if event is PointerUpEvent || event is PointerCancelEvent {
            _pointerLocations.removeValue(forKey: event.pointer)
            _pointerQueue.removeAll { $0 == event.pointer }
            didChangeConfiguration = true
            _lastTransform = event.transform
        } else if let panZoomStart = event as? PointerPanZoomStartEvent {
            assert(_pointerPanZooms[event.pointer] == nil)
            _pointerPanZooms[event.pointer] = PointerPanZoomData(
                fromStartEvent: self, event: panZoomStart
            )
            didChangeConfiguration = true
            shouldStartIfAccepted = true
            _lastTransform = event.transform
        } else if let panZoomUpdate = event as? PointerPanZoomUpdateEvent {
            assert(_pointerPanZooms[event.pointer] != nil)
            if !panZoomUpdate.synthesized && !trackpadScrollCausesScale {
                _velocityTrackers[event.pointer]!.addPosition(event.timeStamp, panZoomUpdate.pan)
            }
            _pointerPanZooms[event.pointer] = PointerPanZoomData(
                fromUpdateEvent: self, event: panZoomUpdate
            )
            _lastTransform = event.transform
            shouldStartIfAccepted = true
        } else if event is PointerPanZoomEndEvent {
            assert(_pointerPanZooms[event.pointer] != nil)
            _pointerPanZooms.removeValue(forKey: event.pointer)
            didChangeConfiguration = true
        }

        _updateLines()
        _update()

        if !didChangeConfiguration || _reconfigure(event.pointer) {
            _advanceStateMachine(shouldStartIfAccepted, event)
        }
        stopTrackingIfPointerNoLongerDown(event)
    }

    // MARK: - Update Methods

    /// **Dart Source:** `scale.dart:597-644`
    private func _update() {
        let previousFocalPoint = _currentFocalPoint

        // Compute the focal point
        var focalPoint: Offset = .zero
        for pointer in _pointerLocations.keys {
            focalPoint = focalPoint + _pointerLocations[pointer]!
        }
        for p in _pointerPanZooms.values {
            focalPoint = focalPoint + p.focalPoint
        }
        _currentFocalPoint =
            focalPoint
            / Double(max(1, _pointerLocations.count + _pointerPanZooms.count))

        if previousFocalPoint == nil {
            _localFocalPoint = PointerEvent.transformPosition(_lastTransform, _currentFocalPoint!)
            _delta = .zero
        } else {
            let localPreviousFocalPoint = _localFocalPoint
            _localFocalPoint = PointerEvent.transformPosition(_lastTransform, _currentFocalPoint!)
            _delta = _localFocalPoint - localPreviousFocalPoint
        }

        let count = _pointerLocations.keys.count

        var pointerFocalPoint: Offset = .zero
        for pointer in _pointerLocations.keys {
            pointerFocalPoint = pointerFocalPoint + _pointerLocations[pointer]!
        }
        if count > 0 {
            pointerFocalPoint = pointerFocalPoint / Double(count)
        }

        // Span is the average deviation from focal point. Horizontal and vertical
        // spans are the average deviations from the focal point's horizontal and
        // vertical coordinates, respectively.
        var totalDeviation: Double = 0.0
        var totalHorizontalDeviation: Double = 0.0
        var totalVerticalDeviation: Double = 0.0
        for pointer in _pointerLocations.keys {
            totalDeviation += (pointerFocalPoint - _pointerLocations[pointer]!).distance
            totalHorizontalDeviation += Swift.abs(
                pointerFocalPoint.dx - _pointerLocations[pointer]!.dx)
            totalVerticalDeviation += Swift.abs(pointerFocalPoint.dy - _pointerLocations[pointer]!.dy)
        }
        _currentSpan = count > 0 ? totalDeviation / Double(count) : 0.0
        _currentHorizontalSpan = count > 0 ? totalHorizontalDeviation / Double(count) : 0.0
        _currentVerticalSpan = count > 0 ? totalVerticalDeviation / Double(count) : 0.0
    }

    /// Updates `_initialLine` and `_currentLine` accordingly to the situation of
    /// the registered pointers.
    ///
    /// **Dart Source:** `scale.dart:648-675`
    private func _updateLines() {
        let count = _pointerLocations.keys.count
        assert(_pointerQueue.count >= count)

        // In case of just one pointer registered, reconfigure _initialLine
        if count < 2 {
            _initialLine = _currentLine
        } else if _initialLine != nil
            && _initialLine!.pointerStartId == _pointerQueue[0]
            && _initialLine!.pointerEndId == _pointerQueue[1]
        {
            // Rotation updated, set the _currentLine
            _currentLine = LineBetweenPointers(
                pointerStartLocation: _pointerLocations[_pointerQueue[0]]!,
                pointerStartId: _pointerQueue[0],
                pointerEndLocation: _pointerLocations[_pointerQueue[1]]!,
                pointerEndId: _pointerQueue[1]
            )
        } else {
            // A new rotation process is on the way, set the _initialLine
            _initialLine = LineBetweenPointers(
                pointerStartLocation: _pointerLocations[_pointerQueue[0]]!,
                pointerStartId: _pointerQueue[0],
                pointerEndLocation: _pointerLocations[_pointerQueue[1]]!,
                pointerEndId: _pointerQueue[1]
            )
            _currentLine = _initialLine
        }
    }

    /// **Dart Source:** `scale.dart:677-736`
    private func _reconfigure(_ pointer: Int) -> Bool {
        _initialFocalPoint = _currentFocalPoint!
        _initialSpan = _currentSpan
        _initialLine = _currentLine
        _initialHorizontalSpan = _currentHorizontalSpan
        _initialVerticalSpan = _currentVerticalSpan
        if _pointerPanZooms.isEmpty {
            _initialPanZoomScaleFactor = 1.0
            _initialPanZoomRotationFactor = 0.0
        } else {
            _initialPanZoomScaleFactor = _scaleFactor / _pointerScaleFactor
            _initialPanZoomRotationFactor = _pointerPanZooms.values
                .map { $0.rotation }
                .reduce(0, +)
        }
        if _state == .started {
            if onEnd != nil {
                let tracker = _velocityTrackers[pointer]!

                var velocity = tracker.getVelocity()
                if _isFlingGesture(velocity) {
                    let pixelsPerSecond = velocity.pixelsPerSecond
                    if pixelsPerSecond.distanceSquared > kMaxFlingVelocity * kMaxFlingVelocity {
                        velocity = Velocity(
                            pixelsPerSecond: (pixelsPerSecond / pixelsPerSecond.distance)
                                * kMaxFlingVelocity
                        )
                    }
                    invokeCallback(
                        "onEnd",
                        {
                            self.onEnd!(
                                ScaleEndDetails(
                                    velocity: velocity,
                                    scaleVelocity: self._scaleVelocityTracker?.getVelocity()
                                        .pixelsPerSecond.dx ?? -1,
                                    pointerCount: self.pointerCount
                                )
                            )
                        }
                    )
                } else {
                    invokeCallback(
                        "onEnd",
                        {
                            self.onEnd!(
                                ScaleEndDetails(
                                    scaleVelocity: self._scaleVelocityTracker?.getVelocity()
                                        .pixelsPerSecond.dx ?? -1,
                                    pointerCount: self.pointerCount
                                )
                            )
                        }
                    )
                }
            }
            _state = .accepted
            // arbitrary PointerDeviceKind
            _scaleVelocityTracker = VelocityTracker(kind: .touch)
            return false
        }
        // arbitrary PointerDeviceKind
        _scaleVelocityTracker = VelocityTracker(kind: .touch)
        return true
    }

    // MARK: - State Machine

    /// **Dart Source:** `scale.dart:738-781`
    private func _advanceStateMachine(_ shouldStartIfAccepted: Bool, _ event: PointerEvent) {
        if _state == .ready {
            _state = .possible
        }

        if _state == .possible {
            let spanDelta = Swift.abs(_currentSpan - _initialSpan)
            let focalPointDelta = (_currentFocalPoint! - _initialFocalPoint).distance
            if spanDelta > computeScaleSlop(event.kind)
                || focalPointDelta > computePanSlop(event.kind, gestureSettings)
                || max(_scaleFactor / _pointerScaleFactor, _pointerScaleFactor / _scaleFactor) > 1.05
            {
                resolve(.accepted)
            }
        } else if _state.rawValue >= ScaleState.accepted.rawValue {
            resolve(.accepted)
        }

        if _state == .accepted && shouldStartIfAccepted {
            _initialEventTimestamp = event.timeStamp
            _state = .started
            _dispatchOnStartCallbackIfNeeded()
        }

        if _state == .started {
            _scaleVelocityTracker?.addPosition(event.timeStamp, Offset(_scaleFactor, 0))
            if onUpdate != nil {
                invokeCallback("onUpdate", {
                    self.onUpdate!(
                        ScaleUpdateDetails(
                            focalPoint: self._currentFocalPoint!,
                            localFocalPoint: self._localFocalPoint,
                            scale: self._scaleFactor,
                            horizontalScale: self._horizontalScaleFactor,
                            verticalScale: self._verticalScaleFactor,
                            rotation: self._computeRotationFactor(),
                            pointerCount: self.pointerCount,
                            focalPointDelta: self._delta,
                            sourceTimeStamp: event.timeStamp
                        )
                    )
                })
            }
        }
    }

    /// **Dart Source:** `scale.dart:783-803`
    private func _dispatchOnStartCallbackIfNeeded() {
        assert(_state == .started)
        if onStart != nil {
            invokeCallback("onStart", {
                self.onStart!(
                    ScaleStartDetails(
                        focalPoint: self._currentFocalPoint!,
                        localFocalPoint: self._localFocalPoint,
                        pointerCount: self.pointerCount,
                        sourceTimeStamp: self._initialEventTimestamp,
                        kind: !self._pointerQueue.isEmpty
                            ? self.getKindForPointer(self._pointerQueue.first!)
                            : !self._pointerPanZooms.isEmpty
                                ? self.getKindForPointer(self._pointerPanZooms.keys.first!)
                                : nil
                    )
                )
            })
        }
        _initialEventTimestamp = nil
    }

    // MARK: - Gesture Arena

    /// **Dart Source:** `scale.dart:806-827`
    public override func acceptGesture(_ pointer: Int) {
        if _state == .possible {
            _state = .started
            _dispatchOnStartCallbackIfNeeded()
            if dragStartBehavior == .start {
                _initialFocalPoint = _currentFocalPoint!
                _initialSpan = _currentSpan
                _initialLine = _currentLine
                _initialHorizontalSpan = _currentHorizontalSpan
                _initialVerticalSpan = _currentVerticalSpan
                if _pointerPanZooms.isEmpty {
                    _initialPanZoomScaleFactor = 1.0
                    _initialPanZoomRotationFactor = 0.0
                } else {
                    _initialPanZoomScaleFactor = _scaleFactor / _pointerScaleFactor
                    _initialPanZoomRotationFactor = _pointerPanZooms.values
                        .map { $0.rotation }
                        .reduce(0, +)
                }
            }
        }
    }

    /// **Dart Source:** `scale.dart:830-835`
    public override func rejectGesture(_ pointer: Int) {
        _pointerPanZooms.removeValue(forKey: pointer)
        _pointerLocations.removeValue(forKey: pointer)
        _pointerQueue.removeAll { $0 == pointer }
        stopTrackingPointer(pointer)
    }

    /// **Dart Source:** `scale.dart:838-850`
    public override func didStopTrackingLastPointer(_ pointer: Int) {
        switch _state {
        case .possible:
            resolve(.rejected)
        case .ready:
            assert(false)  // We should have not seen a pointer yet
        case .accepted:
            break
        case .started:
            assert(false)  // We should be in the accepted state when user is done
        }
        _state = .ready
    }

    /// **Dart Source:** `scale.dart:853-856`
    public override func dispose() {
        _velocityTrackers.removeAll()
        super.dispose()
    }

    // MARK: - Debug Description

    /// **Dart Source:** `scale.dart:859`
    public override var debugDescription: String {
        return "scale"
    }
}

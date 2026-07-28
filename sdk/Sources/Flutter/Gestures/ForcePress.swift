// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Force press gesture recognizer and related types.
///
/// Recognizes force press gestures on devices that have force sensors (e.g.
/// iPhone 6S and higher with 3D Touch). The recognizer tracks a state machine
/// from ready -> possible -> accepted -> started -> peaked, firing callbacks
/// at the appropriate thresholds.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/force_press.dart`
/// **Lines:** 1-372

import FlutterSwiftBridge
import Foundation

// MARK: - ForceState

/// The state of a force press gesture recognizer.
///
/// This enum tracks the progression of a force press gesture through its
/// lifecycle from initial touch to peak pressure.
///
/// **Dart Source:** `force_press.dart:15-36`
///
/// DIFFERENCE FROM DART: In Dart, `_ForceState` is a private enum. In Swift,
/// it is internal to the module so that it can be used by `ForcePressGestureRecognizer`.
internal enum ForceState {
    /// No pointer has touched down and the detector is ready for a pointer
    /// down to occur.
    ///
    /// **Dart Source:** `force_press.dart:17`
    case ready

    /// A pointer has touched down, but a force press gesture has not yet been
    /// detected.
    ///
    /// **Dart Source:** `force_press.dart:20`
    case possible

    /// A pointer is down and a force press gesture has been detected. However,
    /// if the `ForcePressGestureRecognizer` is the only recognizer in the
    /// arena, thus accepted as soon as the gesture state is possible, the
    /// gesture will not yet have started.
    ///
    /// **Dart Source:** `force_press.dart:23-26`
    case accepted

    /// A pointer is down and the gesture has started, i.e. the pressure of the
    /// pointer has just become greater than
    /// `ForcePressGestureRecognizer.startPressure`.
    ///
    /// **Dart Source:** `force_press.dart:28-30`
    case started

    /// A pointer is down and the pressure of the pointer has just become greater
    /// than `ForcePressGestureRecognizer.peakPressure`. Even after a pointer
    /// crosses this threshold, onUpdate callbacks will still be sent.
    ///
    /// **Dart Source:** `force_press.dart:32-35`
    case peaked
}

// MARK: - ForcePressDetails

/// Details object for callbacks that use `GestureForcePressStartCallback`,
/// `GestureForcePressPeakCallback`, `GestureForcePressEndCallback` or
/// `GestureForcePressUpdateCallback`.
///
/// See also:
///
///  * `ForcePressGestureRecognizer.onStart`, `ForcePressGestureRecognizer.onPeak`,
///    `ForcePressGestureRecognizer.onEnd`, and `ForcePressGestureRecognizer.onUpdate`
///    which use `ForcePressDetails`.
///
/// **Dart Source:** `force_press.dart:47-71`
public struct ForcePressDetails: PositionedGestureDetails {

    /// Creates details for a `GestureForcePressStartCallback`,
    /// `GestureForcePressPeakCallback` or `GestureForcePressEndCallback`.
    ///
    /// **Dart Source:** `force_press.dart:50-51`
    public init(
        globalPosition: Offset,
        localPosition: Offset? = nil,
        pressure: Double
    ) {
        self.globalPosition = globalPosition
        self.localPosition = localPosition ?? globalPosition
        self.pressure = pressure
    }

    /// The global position at which the pointer interacts with the screen.
    ///
    /// **Dart Source:** `force_press.dart:54-55`
    public let globalPosition: Offset

    /// The local position in the coordinate system of the event receiver at
    /// which the pointer interacts with the screen.
    ///
    /// **Dart Source:** `force_press.dart:58-59`
    public let localPosition: Offset

    /// The pressure of the pointer on the screen.
    ///
    /// **Dart Source:** `force_press.dart:62`
    public let pressure: Double
}

// MARK: - Callback Typealias

/// Signature used by a `ForcePressGestureRecognizer` for when a pointer has
/// pressed with at least `ForcePressGestureRecognizer.startPressure`.
///
/// **Dart Source:** `force_press.dart:73-75`
public typealias GestureForcePressStartCallback = (_ details: ForcePressDetails) -> Void

/// Signature used by `ForcePressGestureRecognizer` for when a pointer that has
/// pressed with at least `ForcePressGestureRecognizer.peakPressure`.
///
/// **Dart Source:** `force_press.dart:77-79`
public typealias GestureForcePressPeakCallback = (_ details: ForcePressDetails) -> Void

/// Signature used by `ForcePressGestureRecognizer` during the frames
/// after the triggering of a `ForcePressGestureRecognizer.onStart` callback.
///
/// **Dart Source:** `force_press.dart:81-83`
public typealias GestureForcePressUpdateCallback = (_ details: ForcePressDetails) -> Void

/// Signature for when the pointer that previously triggered a
/// `ForcePressGestureRecognizer.onStart` callback is no longer in contact
/// with the screen.
///
/// **Dart Source:** `force_press.dart:85-88`
public typealias GestureForcePressEndCallback = (_ details: ForcePressDetails) -> Void

/// Signature used by `ForcePressGestureRecognizer` for interpolating the raw
/// device pressure to a value in the range `[0, 1]` given the device's pressure
/// min and pressure max.
///
/// **Dart Source:** `force_press.dart:90-94`
public typealias GestureForceInterpolation = (
    _ pressureMin: Double,
    _ pressureMax: Double,
    _ pressure: Double
) -> Double

// MARK: - ForcePressGestureRecognizer

/// Recognizes a force press on devices that have force sensors.
///
/// Only the force from a single pointer is used to invoke events. A tap
/// recognizer will win against this recognizer on pointer up as long as the
/// pointer has not pressed with a force greater than
/// `ForcePressGestureRecognizer.startPressure`. A long press recognizer will
/// win when the press down time exceeds the threshold time as long as the
/// pointer's pressure was never greater than
/// `ForcePressGestureRecognizer.startPressure` in that duration.
///
/// As of November, 2018 iPhone devices of generation 6S and higher have
/// force touch functionality, with the exception of the iPhone XR. In addition,
/// a small handful of Android devices have this functionality as well.
///
/// Devices with faux screen pressure sensors like the Pixel 2 and 3 will not
/// send any force press related callbacks.
///
/// Reported pressure will always be in the range 0.0 to 1.0, where 1.0 is
/// maximum pressure and 0.0 is minimum pressure. If using a custom
/// `interpolation` callback, the pressure reported will correspond to that
/// custom curve.
///
/// **Dart Source:** `force_press.dart:96-372`
public class ForcePressGestureRecognizer: OneSequenceGestureRecognizer {

    /// Creates a force press gesture recognizer.
    ///
    /// The `startPressure` defaults to 0.4, and `peakPressure` defaults to 0.85
    /// where a value of 0.0 is no pressure and a value of 1.0 is maximum pressure.
    ///
    /// The `startPressure`, `peakPressure` and `interpolation` arguments must not
    /// be null. The `peakPressure` argument must be greater than `startPressure`.
    /// The `interpolation` callback must always return a value in the range 0.0
    /// to 1.0 for values of `pressure` that are between `pressureMin` and
    /// `pressureMax`.
    ///
    /// **Dart Source:** `force_press.dart:130-137`
    public init(
        startPressure: Double = 0.4,
        peakPressure: Double = 0.85,
        interpolation: @escaping GestureForceInterpolation = ForcePressGestureRecognizer._inverseLerp,
        debugOwner: AnyObject? = nil,
        supportedDevices: Set<PointerDeviceKind>? = nil,
        allowedButtonsFilter: @escaping AllowedButtonsFilter = { _ in true }
    ) {
        assert(peakPressure > startPressure)
        self.startPressure = startPressure
        self.peakPressure = peakPressure
        self.interpolation = interpolation
        super.init(
            debugOwner: debugOwner,
            supportedDevices: supportedDevices,
            allowedButtonsFilter: allowedButtonsFilter
        )
    }

    // MARK: - Callbacks

    /// A pointer is in contact with the screen and has just pressed with a force
    /// exceeding the `startPressure`. Consequently, if there were other gesture
    /// detectors, only the force press gesture will be detected and all others
    /// will be rejected.
    ///
    /// The position of the pointer is provided in the callback's `details`
    /// argument, which is a `ForcePressDetails` object.
    ///
    /// **Dart Source:** `force_press.dart:139-146`
    public var onStart: GestureForcePressStartCallback?

    /// A pointer is in contact with the screen and is either moving on the plane
    /// of the screen, pressing the screen with varying forces or both
    /// simultaneously.
    ///
    /// This callback will be invoked for every pointer event after the invocation
    /// of `onStart` and/or `onPeak` and before the invocation of `onEnd`, no
    /// matter what the pressure is during this time period. The position and
    /// pressure of the pointer is provided in the callback's `details` argument,
    /// which is a `ForcePressDetails` object.
    ///
    /// **Dart Source:** `force_press.dart:148-157`
    public var onUpdate: GestureForcePressUpdateCallback?

    /// A pointer is in contact with the screen and has just pressed with a force
    /// exceeding the `peakPressure`. This is an arbitrary second level action
    /// threshold and isn't necessarily the maximum possible device pressure
    /// (which is 1.0).
    ///
    /// The position of the pointer is provided in the callback's `details`
    /// argument, which is a `ForcePressDetails` object.
    ///
    /// **Dart Source:** `force_press.dart:159-166`
    public var onPeak: GestureForcePressPeakCallback?

    /// A pointer is no longer in contact with the screen.
    ///
    /// The position of the pointer is provided in the callback's `details`
    /// argument, which is a `ForcePressDetails` object.
    ///
    /// **Dart Source:** `force_press.dart:168-172`
    public var onEnd: GestureForcePressEndCallback?

    // MARK: - Pressure Thresholds

    /// The pressure of the press required to initiate a force press.
    ///
    /// A value of 0.0 is no pressure, and 1.0 is maximum pressure.
    ///
    /// **Dart Source:** `force_press.dart:174-177`
    public let startPressure: Double

    /// The pressure of the press required to peak a force press.
    ///
    /// A value of 0.0 is no pressure, and 1.0 is maximum pressure. This value
    /// must be greater than `startPressure`.
    ///
    /// **Dart Source:** `force_press.dart:179-183`
    public let peakPressure: Double

    /// The function used to convert the raw device pressure values into a value
    /// in the range 0.0 to 1.0.
    ///
    /// The function takes in the device's minimum, maximum and raw touch pressure
    /// and returns a value in the range 0.0 to 1.0 denoting the interpolated
    /// touch pressure.
    ///
    /// This function must always return values in the range 0.0 to 1.0 given a
    /// pressure that is between the minimum and maximum pressures. It may return
    /// `Double.nan` for values that it does not want to support.
    ///
    /// By default, the function is a linear interpolation; however, changing the
    /// function could be useful to accommodate variations in the way different
    /// devices respond to pressure, or to change how animations from pressure
    /// feedback are rendered.
    ///
    /// For example, an ease-in curve can be used to determine the interpolated
    /// value:
    ///
    /// ```swift
    /// func interpolateWithEasing(_ min: Double, _ max: Double, _ t: Double) -> Double {
    ///     let lerp = (t - min) / (max - min)
    ///     return Curves.easeIn.transform(lerp)
    /// }
    /// ```
    ///
    /// **Dart Source:** `force_press.dart:185-210`
    public let interpolation: GestureForceInterpolation

    // MARK: - Private State

    /// **Dart Source:** `force_press.dart:212`
    private var _lastPosition: OffsetPair = .zero

    /// **Dart Source:** `force_press.dart:213`
    private var _lastPressure: Double = 0.0

    /// **Dart Source:** `force_press.dart:214`
    private var _state: ForceState = .ready

    // MARK: - Pointer Handling

    /// **Dart Source:** `force_press.dart:216-230`
    public override func addAllowedPointer(_ event: PointerDownEvent) {
        // If the device has a maximum pressure of less than or equal to 1, it
        // doesn't have touch pressure sensing capabilities. Do not participate
        // in the gesture arena.
        if event.pressureMax <= 1.0 {
            resolve(.rejected)
        } else {
            super.addAllowedPointer(event)
            if _state == .ready {
                _state = .possible
                _lastPosition = OffsetPair.fromEventPosition(event)
            }
        }
    }

    /// **Dart Source:** `force_press.dart:232-306`
    public override func handleEvent(_ event: PointerEvent) {
        assert(_state != .ready)
        // A static pointer with changes in pressure creates PointerMoveEvent events.
        if event is PointerMoveEvent || event is PointerDownEvent {
            let pressure = interpolation(event.pressureMin, event.pressureMax, event.pressure)
            assert(
                (pressure >= 0.0 && pressure <= 1.0) // Interpolated pressure must be between 0.0 and 1.0...
                    || pressure.isNaN // and interpolation may return NaN for values it doesn't want to support...
            )

            _lastPosition = OffsetPair.fromEventPosition(event)
            _lastPressure = pressure

            if _state == .possible {
                if pressure > startPressure {
                    _state = .started
                    resolve(.accepted)
                } else if event.delta.distanceSquared > computeHitSlop(event.kind, gestureSettings) {
                    resolve(.rejected)
                }
            }
            // In case this is the only gesture detector we still don't want to start
            // the gesture until the pressure is greater than the startPressure.
            if pressure > startPressure && _state == .accepted {
                _state = .started
                if onStart != nil {
                    invokeCallback(
                        "onStart",
                        {
                            self.onStart!(
                                ForcePressDetails(
                                    globalPosition: self._lastPosition.global,
                                    localPosition: self._lastPosition.local,
                                    pressure: pressure
                                )
                            )
                        }
                    )
                }
            }
            if onPeak != nil && pressure > peakPressure && (_state == .started) {
                _state = .peaked
                if onPeak != nil {
                    invokeCallback(
                        "onPeak",
                        {
                            self.onPeak!(
                                ForcePressDetails(
                                    globalPosition: event.position,
                                    localPosition: event.localPosition,
                                    pressure: pressure
                                )
                            )
                        }
                    )
                }
            }
            if onUpdate != nil
                && !pressure.isNaN
                && (_state == .started || _state == .peaked)
            {
                if onUpdate != nil {
                    invokeCallback(
                        "onUpdate",
                        {
                            self.onUpdate!(
                                ForcePressDetails(
                                    globalPosition: event.position,
                                    localPosition: event.localPosition,
                                    pressure: pressure
                                )
                            )
                        }
                    )
                }
            }
        }
        stopTrackingIfPointerNoLongerDown(event)
    }

    // MARK: - Arena Resolution

    /// **Dart Source:** `force_press.dart:308-326`
    public override func acceptGesture(_ pointer: Int) {
        if _state == .possible {
            _state = .accepted
        }

        if onStart != nil && _state == .started {
            invokeCallback(
                "onStart",
                {
                    self.onStart!(
                        ForcePressDetails(
                            globalPosition: self._lastPosition.global,
                            localPosition: self._lastPosition.local,
                            pressure: self._lastPressure
                        )
                    )
                }
            )
        }
    }

    /// **Dart Source:** `force_press.dart:328-350`
    public override func didStopTrackingLastPointer(_ pointer: Int) {
        let wasAccepted = _state == .started || _state == .peaked
        if _state == .possible {
            resolve(.rejected)
            return
        }
        if wasAccepted && onEnd != nil {
            if onEnd != nil {
                invokeCallback(
                    "onEnd",
                    {
                        self.onEnd!(
                            ForcePressDetails(
                                globalPosition: self._lastPosition.global,
                                localPosition: self._lastPosition.local,
                                pressure: 0.0
                            )
                        )
                    }
                )
            }
        }
        _state = .ready
    }

    /// **Dart Source:** `force_press.dart:352-356`
    public override func rejectGesture(_ pointer: Int) {
        stopTrackingPointer(pointer)
        didStopTrackingLastPointer(pointer)
    }

    // MARK: - Static Interpolation Functions

    /// Default interpolation function that linearly maps pressure from
    /// `[min, max]` to `[0, 1]`.
    ///
    /// If the device incorrectly reports a pressure outside of `pressureMin`
    /// and `pressureMax`, the result is clamped to `[0, 1]`.
    ///
    /// **Dart Source:** `force_press.dart:358-368`
    public static func _inverseLerp(_ min: Double, _ max: Double, _ t: Double) -> Double {
        assert(min <= max)
        var value = (t - min) / (max - min)

        // If the device incorrectly reports a pressure outside of pressureMin
        // and pressureMax, we still want this recognizer to respond normally.
        if !value.isNaN {
            value = Swift.min(Swift.max(value, 0.0), 1.0)
        }
        return value
    }

    // MARK: - Debug Description

    /// **Dart Source:** `force_press.dart:370-371`
    public override var debugDescription: String {
        return "force press"
    }
}

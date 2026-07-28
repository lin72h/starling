// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import FlutterSwiftBridge

// MARK: - BouncingScrollSimulation

/// An implementation of scroll physics that matches iOS.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_simulation.dart:18-132`
public class BouncingScrollSimulation: Simulation {

    /// Creates a simulation group for scrolling on iOS.
    ///
    /// **Dart Source:** `scroll_simulation.dart:36-70`
    public init(
        position: Double,
        velocity: Double,
        leadingExtent: Double,
        trailingExtent: Double,
        spring: SpringDescription,
        constantDeceleration: Double = 0,
        tolerance: Tolerance = Tolerance.defaultTolerance
    ) {
        assert(leadingExtent <= trailingExtent)
        self.leadingExtent = leadingExtent
        self.trailingExtent = trailingExtent
        self.spring = spring
        super.init(tolerance: tolerance)

        if position < leadingExtent {
            _springSimulation = _underscrollSimulation(position, velocity)
            _springTime = -.infinity
        } else if position > trailingExtent {
            _springSimulation = _overscrollSimulation(position, velocity)
            _springTime = -.infinity
        } else {
            // Taken from UIScrollView.decelerationRate (.normal = 0.998)
            // 0.998^1000 = ~0.135
            _frictionSimulation = FrictionSimulation(
                0.135,
                position,
                velocity,
                constantDeceleration: constantDeceleration
            )
            let finalX = _frictionSimulation!.finalX
            if velocity > 0.0 && finalX > trailingExtent {
                _springTime = _frictionSimulation!.timeAtX(trailingExtent)
                _springSimulation = _overscrollSimulation(
                    trailingExtent,
                    min(_frictionSimulation!.dx(_springTime), BouncingScrollSimulation.maxSpringTransferVelocity)
                )
                assert(_springTime.isFinite)
            } else if velocity < 0.0 && finalX < leadingExtent {
                _springTime = _frictionSimulation!.timeAtX(leadingExtent)
                _springSimulation = _underscrollSimulation(
                    leadingExtent,
                    min(_frictionSimulation!.dx(_springTime), BouncingScrollSimulation.maxSpringTransferVelocity)
                )
                assert(_springTime.isFinite)
            } else {
                _springTime = Double.infinity
            }
        }
    }

    /// The maximum velocity that can be transferred from the inertia of a ballistic
    /// scroll into overscroll.
    ///
    /// **Dart Source:** `scroll_simulation.dart:73`
    public static let maxSpringTransferVelocity: Double = 5000.0

    /// When `x` falls below this value the simulation switches from an internal friction
    /// model to a spring model which causes `x` to "spring" back to `leadingExtent`.
    ///
    /// **Dart Source:** `scroll_simulation.dart:77`
    public let leadingExtent: Double

    /// When `x` exceeds this value the simulation switches from an internal friction
    /// model to a spring model which causes `x` to "spring" back to `trailingExtent`.
    ///
    /// **Dart Source:** `scroll_simulation.dart:81`
    public let trailingExtent: Double

    /// The spring used to return `x` to either `leadingExtent` or `trailingExtent`.
    ///
    /// **Dart Source:** `scroll_simulation.dart:84`
    public let spring: SpringDescription

    private var _frictionSimulation: FrictionSimulation?
    private var _springSimulation: Simulation!
    private var _springTime: Double = 0.0
    private var _timeOffset: Double = 0.0

    private func _underscrollSimulation(_ x: Double, _ dx: Double) -> Simulation {
        return ScrollSpringSimulation(spring, x, leadingExtent, dx)
    }

    private func _overscrollSimulation(_ x: Double, _ dx: Double) -> Simulation {
        return ScrollSpringSimulation(spring, x, trailingExtent, dx)
    }

    private func _simulation(_ time: Double) -> Simulation {
        let simulation: Simulation
        if time > _springTime {
            _timeOffset = _springTime.isFinite ? _springTime : 0.0
            simulation = _springSimulation
        } else {
            _timeOffset = 0.0
            simulation = _frictionSimulation!
        }
        simulation.tolerance = tolerance
        return simulation
    }

    /// **Dart Source:** `scroll_simulation.dart:119`
    public override func x(_ time: Double) -> Double {
        return _simulation(time).x(time - _timeOffset)
    }

    /// **Dart Source:** `scroll_simulation.dart:122`
    public override func dx(_ time: Double) -> Double {
        return _simulation(time).dx(time - _timeOffset)
    }

    /// **Dart Source:** `scroll_simulation.dart:125`
    public override func isDone(_ time: Double) -> Bool {
        return _simulation(time).isDone(time - _timeOffset)
    }

    /// **Dart Source:** `scroll_simulation.dart:128-130`
    public override var description: String {
        return "\(objectRuntimeType(self, "BouncingScrollSimulation"))(leadingExtent: \(leadingExtent), trailingExtent: \(trailingExtent))"
    }
}

// MARK: - ClampingScrollSimulation

/// An implementation of scroll physics that aligns with Android.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_simulation.dart:164-266`
public class ClampingScrollSimulation: Simulation {

    /// Creates a scroll physics simulation that aligns with Android scrolling.
    ///
    /// **Dart Source:** `scroll_simulation.dart:166-171`
    public init(
        position: Double,
        velocity: Double,
        friction: Double = 0.015,
        tolerance: Tolerance = Tolerance.defaultTolerance
    ) {
        self.position = position
        self.velocity = velocity
        self.friction = friction
        super.init(tolerance: tolerance)
        self._duration = _flingDuration()
        self._distance = _flingDistance()
    }

    /// The position of the particle at the beginning of the simulation.
    ///
    /// **Dart Source:** `scroll_simulation.dart:175`
    public let position: Double

    /// The velocity at which the particle is traveling at the beginning of the
    /// simulation.
    ///
    /// **Dart Source:** `scroll_simulation.dart:180`
    public let velocity: Double

    /// The amount of friction the particle experiences as it travels.
    ///
    /// **Dart Source:** `scroll_simulation.dart:190`
    public let friction: Double

    private var _duration: Double = 0.0
    private var _distance: Double = 0.0

    // See DECELERATION_RATE.
    private static let _kDecelerationRate: Double = log(0.78) / log(0.9)

    // See INFLEXION.
    private static let _kInflexion: Double = 0.35

    // See mPhysicalCoeff.
    private static let _physicalCoeff: Double =
        9.80665   // g, in meters per second^2
        * 39.37   // 1 meter / 1 inch
        * 160.0   // 1 inch / 1 logical pixel
        * 0.84    // "look and feel tuning"

    private func _flingDuration() -> Double {
        // See getSplineDeceleration().
        let referenceVelocity = friction * ClampingScrollSimulation._physicalCoeff / ClampingScrollSimulation._kInflexion
        // This is the value getSplineFlingDuration() would return, but in seconds.
        let androidDuration = pow(
            Swift.abs(velocity) / referenceVelocity,
            1.0 / (ClampingScrollSimulation._kDecelerationRate - 1.0)
        )
        // We finish a bit sooner than Android, in order to travel the same total distance.
        return ClampingScrollSimulation._kDecelerationRate * ClampingScrollSimulation._kInflexion * androidDuration
    }

    private func _flingDistance() -> Double {
        return velocity * _duration / ClampingScrollSimulation._kDecelerationRate
    }

    /// **Dart Source:** `scroll_simulation.dart:252-255`
    public override func x(_ time: Double) -> Double {
        let t = clampDouble(time / _duration, 0.0, 1.0)
        return position + _distance * (1.0 - pow(1.0 - t, ClampingScrollSimulation._kDecelerationRate))
    }

    /// **Dart Source:** `scroll_simulation.dart:258-261`
    public override func dx(_ time: Double) -> Double {
        let t = clampDouble(time / _duration, 0.0, 1.0)
        return velocity * pow(1.0 - t, ClampingScrollSimulation._kDecelerationRate - 1.0)
    }

    /// **Dart Source:** `scroll_simulation.dart:264-266`
    public override func isDone(_ time: Double) -> Bool {
        return time >= _duration
    }
}

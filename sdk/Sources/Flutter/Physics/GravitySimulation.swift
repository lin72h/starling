// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - GravitySimulation
/// A simulation that applies a constant accelerating force.
///
/// Models a particle that follows Newton's second law of motion. The simulation
/// ends when the position exceeds a defined threshold.
///
/// This simulation could be used with an AnimationController to animate the
/// position of a child as if it was falling.
///
/// The end distance threshold must be specified as a positive number but can be
/// reached in either the positive or negative direction. For example (assuming
/// negative numbers represent higher physical positions than positive numbers,
/// as is the case with the normal Canvas coordinate system), if the acceleration
/// is positive ("down") the starting velocity is negative ("up"), and the
/// starting distance is zero, the particle will climb from the origin, reach a
/// plateau, then fall back towards and past the origin. If the end distance
/// threshold is less than the height of the plateau, then the simulation will
/// end during the climb; otherwise, it will end during the fall, after the
/// particle travels below the origin by that distance.
///
/// **Dart Source:** `packages/flutter/lib/src/physics/gravity_simulation.dart`
/// **Original Name:** `GravitySimulation`
/// **Lines:** 56-95
public final class GravitySimulation: Simulation {
    /// Initial position (distance)
    /// **Dart Source:** `gravity_simulation.dart:78`
    private let _x: Double

    /// Initial velocity
    /// **Dart Source:** `gravity_simulation.dart:79`
    private let _v: Double

    /// Acceleration
    /// **Dart Source:** `gravity_simulation.dart:80`
    private let _a: Double

    /// End distance threshold
    /// **Dart Source:** `gravity_simulation.dart:81`
    private let _end: Double

    /// Creates a GravitySimulation using the given arguments, which are,
    /// respectively: an acceleration that is to be applied continually over time;
    /// an initial position relative to an origin; the magnitude of the distance
    /// from that origin beyond which (in either direction) to consider the
    /// simulation to be "done", which must be positive; and an initial velocity.
    ///
    /// The initial position and maximum distance are measured in arbitrary length
    /// units L from an arbitrary origin. The units will match those used for `x(_:)`.
    ///
    /// The time unit T used for the arguments to `x(_:)`, `dx(_:)`, and `isDone(_:)`,
    /// combined with the aforementioned length unit, together determine the units
    /// that must be used for the velocity and acceleration arguments: L/T and
    /// L/T^2 respectively. The same units of velocity are used for the velocity
    /// obtained from `dx(_:)`.
    ///
    /// **Dart Source:** `gravity_simulation.dart:57-76`
    public init(acceleration: Double, distance: Double, endDistance: Double, velocity: Double) {
        assert(endDistance >= 0, "endDistance must be non-negative")
        self._a = acceleration
        self._x = distance
        self._v = velocity
        self._end = endDistance
        super.init()
    }

    /// The position of the object in the simulation at the given time.
    ///
    /// Calculated using the equation: x(t) = x0 + v0*t + 0.5*a*t^2
    ///
    /// **Dart Source:** `gravity_simulation.dart:83-84`
    public override func x(_ time: Double) -> Double {
        return _x + _v * time + 0.5 * _a * time * time
    }

    /// The velocity of the object in the simulation at the given time.
    ///
    /// Calculated using the equation: v(t) = v0 + a*t
    ///
    /// **Dart Source:** `gravity_simulation.dart:86-87`
    public override func dx(_ time: Double) -> Double {
        return _v + time * _a
    }

    /// Whether the simulation is "done" at the given time.
    ///
    /// The simulation is considered done when the absolute position |x(t)| >= endDistance.
    ///
    /// **Dart Source:** `gravity_simulation.dart:89-90`
    public override func isDone(_ time: Double) -> Bool {
        return abs(x(time)) >= _end
    }

    /// **Dart Source:** `gravity_simulation.dart:92-94`
    public override var description: String {
        let aStr = String(format: "%.1f", _a)
        let xStr = String(format: "%.1f", _x)
        let vStr = String(format: "%.1f", _v)
        let endStr = String(format: "%.1f", _end)
        return "\(objectRuntimeType(self, "GravitySimulation"))(g: \(aStr), x\u{2080}: \(xStr), dx\u{2080}: \(vStr), x\u{2098}\u{2090}\u{2093}: \u{00B1}\(endStr))"
    }
}

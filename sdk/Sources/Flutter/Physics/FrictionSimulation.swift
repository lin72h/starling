// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import FlutterSwiftBridge

// MARK: - Newton's Method Helper

/// Numerically determine the input value which produces output value `target`
/// for a function `f`, given its first-derivative `df`.
///
/// **Dart Source:** `packages/flutter/lib/src/physics/friction_simulation.dart`
/// **Original Name:** `_newtonsMethod`
/// **Lines:** 15-27
fileprivate func newtonsMethod(
    initialGuess: Double,
    target: Double,
    f: (Double) -> Double,
    df: (Double) -> Double,
    iterations: Int
) -> Double {
    var guess = initialGuess
    for _ in 0..<iterations {
        guess = guess - (f(guess) - target) / df(guess)
    }
    return guess
}

// MARK: - FrictionSimulation

/// A simulation that applies a drag to slow a particle down.
///
/// Models a particle affected by fluid drag, e.g. air resistance.
///
/// The simulation ends when the velocity of the particle drops to zero (within
/// the current velocity `tolerance`).
///
/// **Dart Source:** `packages/flutter/lib/src/physics/friction_simulation.dart`
/// **Original Name:** `FrictionSimulation`
/// **Lines:** 35-165
public class FrictionSimulation: Simulation {
    /// The fluid drag coefficient.
    /// **Dart Source:** `friction_simulation.dart:88`
    internal let drag: Double

    /// The natural log of the drag coefficient.
    /// **Dart Source:** `friction_simulation.dart:89`
    internal let dragLog: Double

    /// The initial position.
    /// **Dart Source:** `friction_simulation.dart:90`
    internal let initialPosition: Double

    /// The initial velocity.
    /// **Dart Source:** `friction_simulation.dart:91`
    internal let initialVelocity: Double

    /// The constant deceleration (adjusted for direction).
    /// **Dart Source:** `friction_simulation.dart:92`
    internal let constantDeceleration: Double

    /// The time at which the simulation should be stopped.
    /// This is needed when constantDeceleration is not zero (on Desktop), when
    /// using the pure friction simulation, acceleration naturally reduces to zero
    /// and creates a stopping point.
    /// **Dart Source:** `friction_simulation.dart:93-98`
    internal var finalTime: Double

    /// Creates a `FrictionSimulation` with the given arguments, namely: the fluid
    /// drag coefficient _cx_, a unitless value; the initial position _x0_, in the same
    /// length units as used for `x(_:)`; and the initial velocity _dx0_, in the same
    /// velocity units as used for `dx(_:)`.
    ///
    /// **Dart Source:** `friction_simulation.dart:36-58`
    public init(
        _ drag: Double,
        _ position: Double,
        _ velocity: Double,
        tolerance: Tolerance = .defaultTolerance,
        constantDeceleration: Double = 0
    ) {
        self.drag = drag
        self.dragLog = log(drag)
        self.initialPosition = position
        self.initialVelocity = velocity
        self.constantDeceleration = constantDeceleration * (velocity >= 0 ? 1.0 : -1.0)
        // Needs to be infinity for newtonsMethod call before assignment
        self.finalTime = Double.infinity

        super.init(tolerance: tolerance)

        // Now compute final time using Newton's method
        self.finalTime = newtonsMethod(
            initialGuess: 0,
            target: 0,
            f: self.dx,
            df: { [self] (time: Double) -> Double in
                (self.initialVelocity * pow(self.drag, time) * self.dragLog) - self.constantDeceleration
            },
            iterations: 10
        )
    }

    /// Creates a new friction simulation with its fluid drag coefficient (_cx_) set so
    /// as to ensure that the simulation starts and ends at the specified
    /// positions and velocities.
    ///
    /// The positions must use the same units as expected from `x(_:)`, and the
    /// velocities must use the same units as expected from `dx(_:)`.
    ///
    /// The sign of the start and end velocities must be the same, the magnitude
    /// of the start velocity must be greater than the magnitude of the end
    /// velocity, and the velocities must be in the direction appropriate for the
    /// particle to start from the start position and reach the end position.
    ///
    /// **Dart Source:** `friction_simulation.dart:60-86`
    public static func through(
        startPosition: Double,
        endPosition: Double,
        startVelocity: Double,
        endVelocity: Double
    ) -> FrictionSimulation {
        assert(startVelocity == 0.0 || endVelocity == 0.0 || startVelocity.sign == endVelocity.sign)
        assert(Swift.abs(startVelocity) >= Swift.abs(endVelocity))
        assert((endPosition - startPosition).sign == startVelocity.sign)
        return FrictionSimulation(
            dragFor(startPosition, endPosition, startVelocity, endVelocity),
            startPosition,
            startVelocity,
            tolerance: Tolerance(velocity: Swift.abs(endVelocity))
        )
    }

    /// Return the drag value for a FrictionSimulation whose x() and dx() values pass
    /// through the specified start and end position/velocity values.
    ///
    /// Total time to reach endVelocity is just: (log(endVelocity) / log(startVelocity)) / log(_drag)
    /// or (log(v1) - log(v0)) / log(D), given v = v0 * D^t per the dx() function below.
    /// Solving for D given x(time) is trickier. Algebra courtesy of Wolfram Alpha:
    /// x1 = x0 + (v0 * D^((log(v1) - log(v0)) / log(D))) / log(D) - v0 / log(D), find D
    ///
    /// **Dart Source:** `friction_simulation.dart:100-115`
    private static func dragFor(
        _ startPosition: Double,
        _ endPosition: Double,
        _ startVelocity: Double,
        _ endVelocity: Double
    ) -> Double {
        return pow(M_E, (startVelocity - endVelocity) / (startPosition - endPosition))
    }

    /// The position of the object in the simulation at the given time.
    ///
    /// **Dart Source:** `friction_simulation.dart:117-126`
    public override func x(_ time: Double) -> Double {
        if time > finalTime {
            return finalX
        }
        return initialPosition +
            initialVelocity * pow(drag, time) / dragLog -
            initialVelocity / dragLog -
            ((constantDeceleration / 2) * time * time)
    }

    /// The velocity of the object in the simulation at the given time.
    ///
    /// **Dart Source:** `friction_simulation.dart:128-134`
    public override func dx(_ time: Double) -> Double {
        if time > finalTime {
            return 0
        }
        return initialVelocity * pow(drag, time) - constantDeceleration * time
    }

    /// The value of `x(_:)` at `Double.infinity`.
    ///
    /// **Dart Source:** `friction_simulation.dart:136-142`
    public var finalX: Double {
        if constantDeceleration == 0 {
            return initialPosition - initialVelocity / dragLog
        }
        return x(finalTime)
    }

    /// The time at which the value of `x(time)` will equal `x`.
    ///
    /// Returns `Double.infinity` if the simulation will never reach `x`.
    ///
    /// **Dart Source:** `friction_simulation.dart:144-155`
    public func timeAtX(_ x: Double) -> Double {
        if x == initialPosition {
            return 0.0
        }
        if initialVelocity == 0.0 || (initialVelocity > 0 ? (x < initialPosition || x > finalX) : (x > initialPosition || x < finalX)) {
            return Double.infinity
        }
        return newtonsMethod(initialGuess: 0, target: x, f: self.x, df: dx, iterations: 10)
    }

    /// Whether the simulation is "done" at the given time.
    ///
    /// **Dart Source:** `friction_simulation.dart:157-160`
    public override func isDone(_ time: Double) -> Bool {
        return Swift.abs(dx(time)) < tolerance.velocity
    }

    /// **Dart Source:** `friction_simulation.dart:162-164`
    public override var description: String {
        "\(objectRuntimeType(self, "FrictionSimulation"))(cx: \(String(format: "%.1f", drag)), x0: \(String(format: "%.1f", initialPosition)), dx0: \(String(format: "%.1f", initialVelocity)))"
    }
}

// MARK: - BoundedFrictionSimulation

/// A `FrictionSimulation` that clamps the modeled particle to a specific range
/// of values.
///
/// Only the position is clamped. The velocity `dx(_:)` will continue to report
/// unbounded simulated velocities once the particle has reached the bounds.
///
/// **Dart Source:** `packages/flutter/lib/src/physics/friction_simulation.dart`
/// **Original Name:** `BoundedFrictionSimulation`
/// **Lines:** 172-201
public class BoundedFrictionSimulation: FrictionSimulation {
    /// The minimum position value.
    /// **Dart Source:** `friction_simulation.dart:183`
    internal let minX: Double

    /// The maximum position value.
    /// **Dart Source:** `friction_simulation.dart:184`
    internal let maxX: Double

    /// Creates a `BoundedFrictionSimulation` with the given arguments, namely:
    /// the fluid drag coefficient _cx_, a unitless value; the initial position _x0_, in the
    /// same length units as used for `x(_:)`; the initial velocity _dx0_, in the same
    /// velocity units as used for `dx(_:)`, the minimum value for the position, and
    /// the maximum value for the position. The minimum and maximum values must be
    /// in the same units as the initial position, and the initial position must
    /// be within the given range.
    ///
    /// **Dart Source:** `friction_simulation.dart:173-181`
    public init(
        _ drag: Double,
        _ position: Double,
        _ velocity: Double,
        _ minX: Double,
        _ maxX: Double
    ) {
        assert(clampDouble(position, minX, maxX) == position, "position must be within [minX, maxX]")
        self.minX = minX
        self.maxX = maxX
        super.init(drag, position, velocity)
    }

    /// The position of the object in the simulation at the given time, clamped to [minX, maxX].
    ///
    /// **Dart Source:** `friction_simulation.dart:186-189`
    public override func x(_ time: Double) -> Double {
        return clampDouble(super.x(time), minX, maxX)
    }

    /// Whether the simulation is "done" at the given time.
    ///
    /// Returns true if the parent simulation is done OR if the particle has reached
    /// either the minimum or maximum bounds (within tolerance).
    ///
    /// **Dart Source:** `friction_simulation.dart:191-196`
    public override func isDone(_ time: Double) -> Bool {
        return super.isDone(time) ||
            Swift.abs(x(time) - minX) < tolerance.distance ||
            Swift.abs(x(time) - maxX) < tolerance.distance
    }

    /// **Dart Source:** `friction_simulation.dart:198-200`
    public override var description: String {
        "\(objectRuntimeType(self, "BoundedFrictionSimulation"))(cx: \(String(format: "%.1f", drag)), x0: \(String(format: "%.1f", initialPosition)), dx0: \(String(format: "%.1f", initialVelocity)), x: \(String(format: "%.1f", minX))..\(String(format: "%.1f", maxX)))"
    }
}

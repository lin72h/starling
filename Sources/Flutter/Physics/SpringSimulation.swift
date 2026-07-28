// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Spring simulation types: SpringDescription, SpringType, SpringSimulation,
/// ScrollSpringSimulation, and internal spring ODE solvers.
///
/// **Dart Source:** `packages/flutter/lib/src/physics/spring_simulation.dart`

import Foundation

// MARK: - SpringDescription

/// Structure that describes a spring's constants.
///
/// Used to configure a ``SpringSimulation``.
///
/// **Dart Source:** `spring_simulation.dart:23-159`
public struct SpringDescription: CustomStringConvertible, Sendable {

    /// Creates a spring given the mass, stiffness, and the damping coefficient.
    ///
    /// See ``mass``, ``stiffness``, and ``damping`` for the units of the arguments.
    ///
    /// **Dart Source:** `spring_simulation.dart:27`
    public init(mass: Double, stiffness: Double, damping: Double) {
        self.mass = mass
        self.stiffness = stiffness
        self.damping = damping
    }

    /// Creates a spring given the mass (m), stiffness (k), and damping ratio (zeta).
    ///
    /// The damping ratio describes a gradual reduction in a spring oscillation.
    /// A ratio of 1.0 creates a critically damped spring, > 1.0 creates an
    /// overdamped spring, and < 1.0 an underdamped one.
    ///
    /// **Dart Source:** `spring_simulation.dart:40-44`
    public init(mass: Double, stiffness: Double, ratio: Double = 1.0) {
        self.mass = mass
        self.stiffness = stiffness
        self.damping = ratio * 2.0 * sqrt(mass * stiffness)
    }

    /// Creates a ``SpringDescription`` based on a desired animation duration and
    /// bounce.
    ///
    /// This provides an intuitive way to define a spring based on its visual
    /// properties, `duration` and `bounce`.
    ///
    /// This produces the same result as SwiftUI's
    /// `spring(duration:bounce:blendDuration:)` animation.
    ///
    /// **Dart Source:** `spring_simulation.dart:70-82`
    public static func withDurationAndBounce(
        duration: Duration = .milliseconds(500),
        bounce: Double = 0.0
    ) -> SpringDescription {
        let components = duration.components
        let totalMilliseconds = components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000
        assert(totalMilliseconds > 0, "Duration must be positive")
        let durationInSeconds = Double(totalMilliseconds) / 1000.0
        let mass = 1.0
        let stiffness = (4 * Double.pi * Double.pi * mass) / pow(durationInSeconds, 2)
        let dampingRatio = bounce > 0 ? (1.0 - bounce) : (1 / (bounce + 1))
        let damping = dampingRatio * 2.0 * sqrt(mass * stiffness)
        return SpringDescription(mass: mass, stiffness: stiffness, damping: damping)
    }

    /// The mass of the spring (m).
    ///
    /// The units are arbitrary, but all springs within a system should use
    /// the same mass units.
    ///
    /// **Dart Source:** `spring_simulation.dart:91`
    public let mass: Double

    /// The spring constant (k).
    ///
    /// Stiffness defines the spring constant, which measures the strength of
    /// the spring.
    ///
    /// **Dart Source:** `spring_simulation.dart:102`
    public let stiffness: Double

    /// The damping coefficient (c).
    ///
    /// Do not confuse the damping _coefficient_ (c) with the damping _ratio_ (zeta).
    /// To create a ``SpringDescription`` with a damping ratio, use
    /// ``init(mass:stiffness:ratio:)``.
    ///
    /// **Dart Source:** `spring_simulation.dart:117`
    public let damping: Double

    /// The duration parameter, controlling the spring's overall pace.
    ///
    /// This is approximately equal to the time it takes for the spring to settle.
    ///
    /// **Dart Source:** `spring_simulation.dart:133-137`
    public var duration: Duration {
        let durationInSeconds = sqrt((4 * Double.pi * Double.pi * mass) / stiffness)
        let milliseconds = Int64((durationInSeconds * 1000.0).rounded())
        return .milliseconds(milliseconds)
    }

    /// The bounce parameter, controlling how bouncy the spring is.
    ///
    /// - 0: critically damped (no oscillation)
    /// - 0 to 1: underdamped (oscillates before settling)
    /// - 1: undamped (oscillates indefinitely)
    /// - Negative: overdamped (slow, resistive motion)
    ///
    /// **Dart Source:** `spring_simulation.dart:151-154`
    public var bounce: Double {
        let dampingRatio = damping / (2.0 * sqrt(mass * stiffness))
        return dampingRatio < 1.0 ? (1.0 - dampingRatio) : ((1 / dampingRatio) - 1)
    }

    /// **Dart Source:** `spring_simulation.dart:157-158`
    public var description: String {
        return "SpringDescription(mass: \(String(format: "%.1f", mass)), stiffness: \(String(format: "%.1f", stiffness)), damping: \(String(format: "%.1f", damping)))"
    }
}

// MARK: - SpringType

/// The kind of spring solution that the ``SpringSimulation`` is using to
/// simulate the spring.
///
/// **Dart Source:** `spring_simulation.dart:164-175`
public enum SpringType {
    /// A spring that does not bounce and returns to its rest position in the
    /// shortest possible time.
    ///
    /// **Dart Source:** `spring_simulation.dart:167`
    case criticallyDamped

    /// A spring that bounces.
    ///
    /// **Dart Source:** `spring_simulation.dart:170`
    case underDamped

    /// A spring that does not bounce but takes longer to return to its rest
    /// position than a critically damped one.
    ///
    /// **Dart Source:** `spring_simulation.dart:174`
    case overDamped
}

// MARK: - SpringSimulation

/// A spring simulation.
///
/// Models a particle attached to a spring that follows Hooke's law.
///
/// **Dart Source:** `spring_simulation.dart:204-267`
public class SpringSimulation: Simulation {

    /// Creates a spring simulation from the provided spring description, start
    /// distance, end distance, and initial velocity.
    ///
    /// If `snapToEnd` is true, ``x(_:)`` will be set to `end` and ``dx(_:)``
    /// to 0 when ``isDone(_:)`` returns true.
    ///
    /// **Dart Source:** `spring_simulation.dart:219-228`
    public init(
        _ spring: SpringDescription,
        _ start: Double,
        _ end: Double,
        _ velocity: Double,
        snapToEnd: Bool = false,
        tolerance: Tolerance = .defaultTolerance
    ) {
        self._endPosition = end
        self._solution = makeSpringSolution(spring, start - end, velocity)
        self._snapToEnd = snapToEnd
        super.init(tolerance: tolerance)
    }

    fileprivate let _endPosition: Double
    private let _solution: SpringSolution
    private let _snapToEnd: Bool

    /// The kind of spring being simulated, for debugging purposes.
    ///
    /// **Dart Source:** `spring_simulation.dart:238`
    public var type: SpringType { _solution.type }

    /// **Dart Source:** `spring_simulation.dart:241-247`
    public override func x(_ time: Double) -> Double {
        if _snapToEnd && isDone(time) {
            return _endPosition
        } else {
            return _endPosition + _solution.x(time)
        }
    }

    /// **Dart Source:** `spring_simulation.dart:250-256`
    public override func dx(_ time: Double) -> Double {
        if _snapToEnd && isDone(time) {
            return 0
        } else {
            return _solution.dx(time)
        }
    }

    /// **Dart Source:** `spring_simulation.dart:259-262`
    public override func isDone(_ time: Double) -> Bool {
        return nearZero(_solution.x(time), tolerance.distance) &&
            nearZero(_solution.dx(time), tolerance.velocity)
    }

    /// **Dart Source:** `spring_simulation.dart:265-266`
    public override var description: String {
        return "SpringSimulation(end: \(String(format: "%.1f", _endPosition)), \(type))"
    }
}

// MARK: - ScrollSpringSimulation

/// A ``SpringSimulation`` where the value of ``x(_:)`` is guaranteed to have
/// exactly the end value when the simulation ``isDone(_:)``.
///
/// **Dart Source:** `spring_simulation.dart:271-281`
public class ScrollSpringSimulation: SpringSimulation {

    /// Creates a spring simulation from the provided spring description, start
    /// distance, end distance, and initial velocity.
    ///
    /// **Dart Source:** `spring_simulation.dart:277`
    public override init(
        _ spring: SpringDescription,
        _ start: Double,
        _ end: Double,
        _ velocity: Double,
        snapToEnd: Bool = false,
        tolerance: Tolerance = .defaultTolerance
    ) {
        super.init(spring, start, end, velocity, snapToEnd: snapToEnd, tolerance: tolerance)
    }

    /// **Dart Source:** `spring_simulation.dart:280`
    public override func x(_ time: Double) -> Double {
        return isDone(time) ? _endPosition : super.x(time)
    }
}

// MARK: - SpringSolution (Internal)

/// Internal protocol for spring ODE solutions.
///
/// **Dart Source:** `spring_simulation.dart:285-301`
protocol SpringSolution {
    func x(_ time: Double) -> Double
    func dx(_ time: Double) -> Double
    var type: SpringType { get }
}

/// Factory function that creates the appropriate spring solution based on
/// the discriminant of the characteristic equation.
///
/// **Dart Source:** `spring_simulation.dart:286-296`
func makeSpringSolution(
    _ spring: SpringDescription,
    _ initialPosition: Double,
    _ initialVelocity: Double
) -> SpringSolution {
    let discriminant = spring.damping * spring.damping - 4 * spring.mass * spring.stiffness
    if discriminant > 0.0 {
        return OverdampedSolution(spring, initialPosition, initialVelocity)
    } else if discriminant < 0.0 {
        return UnderdampedSolution(spring, initialPosition, initialVelocity)
    } else {
        return CriticalSolution(spring, initialPosition, initialVelocity)
    }
}

// MARK: - CriticalSolution

/// Spring solution for the critically damped case.
///
/// **Dart Source:** `spring_simulation.dart:303-328`
struct CriticalSolution: SpringSolution {
    let _r: Double
    let _c1: Double
    let _c2: Double

    /// **Dart Source:** `spring_simulation.dart:304-309`
    init(_ spring: SpringDescription, _ distance: Double, _ velocity: Double) {
        let r = -spring.damping / (2.0 * spring.mass)
        let c1 = distance
        let c2 = velocity - (r * distance)
        self._r = r
        self._c1 = c1
        self._c2 = c2
    }

    /// **Dart Source:** `spring_simulation.dart:316-318`
    func x(_ time: Double) -> Double {
        return (_c1 + _c2 * time) * exp(_r * time)
    }

    /// **Dart Source:** `spring_simulation.dart:321-324`
    func dx(_ time: Double) -> Double {
        let power = exp(_r * time)
        return _r * (_c1 + _c2 * time) * power + _c2 * power
    }

    /// **Dart Source:** `spring_simulation.dart:327`
    var type: SpringType { .criticallyDamped }
}

// MARK: - OverdampedSolution

/// Spring solution for the overdamped case.
///
/// **Dart Source:** `spring_simulation.dart:330-360`
struct OverdampedSolution: SpringSolution {
    let _r1: Double
    let _r2: Double
    let _c1: Double
    let _c2: Double

    /// **Dart Source:** `spring_simulation.dart:331-338`
    init(_ spring: SpringDescription, _ distance: Double, _ velocity: Double) {
        let cmk = spring.damping * spring.damping - 4 * spring.mass * spring.stiffness
        let r1 = (-spring.damping - sqrt(cmk)) / (2.0 * spring.mass)
        let r2 = (-spring.damping + sqrt(cmk)) / (2.0 * spring.mass)
        let c2 = (velocity - r1 * distance) / (r2 - r1)
        let c1 = distance - c2
        self._r1 = r1
        self._r2 = r2
        self._c1 = c1
        self._c2 = c2
    }

    /// **Dart Source:** `spring_simulation.dart:349-351`
    func x(_ time: Double) -> Double {
        return _c1 * exp(_r1 * time) + _c2 * exp(_r2 * time)
    }

    /// **Dart Source:** `spring_simulation.dart:354-356`
    func dx(_ time: Double) -> Double {
        return _c1 * _r1 * exp(_r1 * time) + _c2 * _r2 * exp(_r2 * time)
    }

    /// **Dart Source:** `spring_simulation.dart:359`
    var type: SpringType { .overDamped }
}

// MARK: - UnderdampedSolution

/// Spring solution for the underdamped case.
///
/// **Dart Source:** `spring_simulation.dart:362-397`
struct UnderdampedSolution: SpringSolution {
    let _w: Double
    let _r: Double
    let _c1: Double
    let _c2: Double

    /// **Dart Source:** `spring_simulation.dart:363-371`
    init(_ spring: SpringDescription, _ distance: Double, _ velocity: Double) {
        let w = sqrt(4.0 * spring.mass * spring.stiffness - spring.damping * spring.damping) /
            (2.0 * spring.mass)
        let r = -(spring.damping / 2.0 / spring.mass)
        let c1 = distance
        let c2 = (velocity - r * distance) / w
        self._w = w
        self._r = r
        self._c1 = c1
        self._c2 = c2
    }

    /// **Dart Source:** `spring_simulation.dart:382-384`
    func x(_ time: Double) -> Double {
        return exp(_r * time) *
            (_c1 * cos(_w * time) + _c2 * sin(_w * time))
    }

    /// **Dart Source:** `spring_simulation.dart:387-393`
    func dx(_ time: Double) -> Double {
        let power = exp(_r * time)
        let cosine = cos(_w * time)
        let sine = sin(_w * time)
        return power * (_c2 * _w * cosine - _c1 * _w * sine) +
            _r * power * (_c2 * sine + _c1 * cosine)
    }

    /// **Dart Source:** `spring_simulation.dart:396`
    var type: SpringType { .underDamped }
}

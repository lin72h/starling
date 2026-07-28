// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for GravitySimulation
/// **Dart Test Source:** `packages/flutter/test/physics/gravity_simulation_test.dart`
final class GravitySimulationTests: XCTestCase {

    // MARK: - Dart Test Ports

    /// **Dart Test:** `gravity_simulation_test.dart:9-12` - "Gravity simulation 1"
    ///
    /// Tests basic creation and position calculation.
    func testGravitySimulation1() {
        let simulation = GravitySimulation(acceleration: 9.81, distance: 10.0, endDistance: 0.0, velocity: 0.0)

        // Test hasOneLineDescription equivalent
        XCTAssertFalse(simulation.description.contains("\n"), "Description should be a single line")

        // Test x(10.0) calculation: x = x0 + v0*t + 0.5*a*t^2
        // x = 10.0 + 0.0*10.0 + 0.5*9.81*10.0^2
        // x = 10.0 + 0 + 0.5*9.81*100
        // x = 10.0 + 490.5
        // x = 500.5 = 50.0 * 9.81 + 10.0
        let expected = 50.0 * 9.81 + 10.0
        XCTAssertEqual(simulation.x(10.0), expected, accuracy: 1e-10)
    }

    /// **Dart Test:** `gravity_simulation_test.dart:14-32` - "Gravity simulation 2"
    ///
    /// Tests full trajectory: up, peak, down, done.
    /// Configuration: acceleration=-10, x0=0.0, endDistance=6.0, v0=10.0
    /// This simulates a projectile launched upward that:
    /// - At t=0: starts at origin with velocity 10 m/s upward
    /// - At t=1: reaches peak height of 5 (velocity = 0)
    /// - At t=2: returns to origin (x=0) with velocity -10 m/s
    /// - At t=3: falls to x=-15, exceeds endDistance=6, isDone=true
    func testGravitySimulation2() {
        let gravity = GravitySimulation(acceleration: -10, distance: 0.0, endDistance: 6.0, velocity: 10.0)

        // Test at t=0.0 (initial state)
        XCTAssertEqual(gravity.x(0.0), 0.0)
        XCTAssertEqual(gravity.dx(0.0), 10.0)
        XCTAssertFalse(gravity.isDone(0.0))

        // Test at t=1.0 (peak of trajectory)
        // x = 0 + 10*1 + 0.5*(-10)*1^2 = 10 - 5 = 5
        // dx = 10 + (-10)*1 = 0
        XCTAssertEqual(gravity.x(1.0), 5.0)
        XCTAssertEqual(gravity.dx(1.0), 0.0)
        XCTAssertFalse(gravity.isDone(0.2))

        // Test at t=2.0 (return to origin)
        // x = 0 + 10*2 + 0.5*(-10)*4 = 20 - 20 = 0
        // dx = 10 + (-10)*2 = -10
        XCTAssertEqual(gravity.x(2.0), 0.0)
        XCTAssertEqual(gravity.dx(2.0), -10.0)
        XCTAssertFalse(gravity.isDone(2.0))

        // Test at t=3.0 (past end threshold)
        // x = 0 + 10*3 + 0.5*(-10)*9 = 30 - 45 = -15
        // dx = 10 + (-10)*3 = -20
        // |x(3.0)| = 15 >= endDistance = 6, so isDone = true
        XCTAssertEqual(gravity.x(3.0), -15.0)
        XCTAssertEqual(gravity.dx(3.0), -20.0)
        XCTAssertTrue(gravity.isDone(3.0))
    }

    // MARK: - Additional Tests

    /// Test that GravitySimulation properly inherits from Simulation.
    func testGravitySimulationInheritance() {
        let simulation: Simulation = GravitySimulation(acceleration: 9.81, distance: 0.0, endDistance: 10.0, velocity: 0.0)
        XCTAssertTrue(simulation is GravitySimulation)
    }

    /// Test that GravitySimulation has default tolerance from Simulation.
    func testGravitySimulationDefaultTolerance() {
        let simulation = GravitySimulation(acceleration: 9.81, distance: 0.0, endDistance: 10.0, velocity: 0.0)
        XCTAssertEqual(simulation.tolerance, Tolerance.defaultTolerance)
    }

    /// Test description format includes expected components.
    func testGravitySimulationDescription() {
        let simulation = GravitySimulation(acceleration: 9.81, distance: 10.0, endDistance: 5.0, velocity: 2.5)
        let description = simulation.description

        // Verify single line
        XCTAssertFalse(description.contains("\n"))

        // Verify contains expected format elements
        XCTAssertTrue(description.contains("GravitySimulation"))
        XCTAssertTrue(description.contains("g:"))  // acceleration
        XCTAssertTrue(description.contains("x₀:")) // initial position
        XCTAssertTrue(description.contains("dx₀:")) // initial velocity
        XCTAssertTrue(description.contains("xₘₐₓ:")) // end distance
    }

    /// Test with zero acceleration (constant velocity motion).
    func testGravitySimulationZeroAcceleration() {
        let simulation = GravitySimulation(acceleration: 0.0, distance: 0.0, endDistance: 10.0, velocity: 5.0)

        // x = 0 + 5*t + 0 = 5t
        XCTAssertEqual(simulation.x(0.0), 0.0)
        XCTAssertEqual(simulation.x(1.0), 5.0)
        XCTAssertEqual(simulation.x(2.0), 10.0)

        // dx = 5 + 0*t = 5 (constant)
        XCTAssertEqual(simulation.dx(0.0), 5.0)
        XCTAssertEqual(simulation.dx(1.0), 5.0)
        XCTAssertEqual(simulation.dx(2.0), 5.0)

        // isDone when |x| >= 10
        XCTAssertFalse(simulation.isDone(1.9))
        XCTAssertTrue(simulation.isDone(2.0))
    }

    /// Test with negative initial velocity (falling object).
    func testGravitySimulationNegativeVelocity() {
        let simulation = GravitySimulation(acceleration: 10.0, distance: 0.0, endDistance: 100.0, velocity: -20.0)

        // x = 0 + (-20)*t + 0.5*10*t^2 = -20t + 5t^2
        XCTAssertEqual(simulation.x(0.0), 0.0)
        XCTAssertEqual(simulation.x(1.0), -15.0) // -20 + 5 = -15
        XCTAssertEqual(simulation.x(2.0), -20.0) // -40 + 20 = -20
        XCTAssertEqual(simulation.x(4.0), 0.0)   // -80 + 80 = 0

        // dx = -20 + 10*t
        XCTAssertEqual(simulation.dx(0.0), -20.0)
        XCTAssertEqual(simulation.dx(2.0), 0.0)
        XCTAssertEqual(simulation.dx(4.0), 20.0)
    }

    /// Test that endDistance of 0 means simulation is always done when not at origin.
    func testGravitySimulationZeroEndDistance() {
        let simulation = GravitySimulation(acceleration: 10.0, distance: 0.0, endDistance: 0.0, velocity: 0.0)

        // At origin with no movement, we're at the threshold
        XCTAssertTrue(simulation.isDone(0.0)) // |0| >= 0 is true

        // Any movement makes it done
        let movingSimulation = GravitySimulation(acceleration: 10.0, distance: 0.0, endDistance: 0.0, velocity: 1.0)
        XCTAssertTrue(movingSimulation.isDone(0.001))
    }
}

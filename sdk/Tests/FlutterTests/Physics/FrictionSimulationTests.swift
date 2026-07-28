// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for FrictionSimulation and BoundedFrictionSimulation
/// **Dart Test Source:** `packages/flutter/test/physics/friction_simulation_test.dart`
final class FrictionSimulationTests: XCTestCase {

    // MARK: - Test Helpers

    /// Asserts that two doubles are approximately equal within a specified epsilon.
    ///
    /// **Dart Equivalent:** `moreOrLessEquals` matcher from flutter_test
    private func assertMoreOrLessEquals(
        _ actual: Double,
        _ expected: Double,
        epsilon: Double = 1e-10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            Swift.abs(actual - expected) <= epsilon,
            "Expected \(actual) to be within \(epsilon) of \(expected)",
            file: file,
            line: line
        )
    }

    // MARK: - Dart Test Ports

    /// **Dart Test:** `friction_simulation_test.dart:9-28` - "Friction simulation positive velocity"
    ///
    /// Tests a friction simulation with positive initial velocity.
    func testFrictionSimulationPositiveVelocity() {
        let friction = FrictionSimulation(0.135, 100.0, 100.0)

        // Test initial position and velocity
        assertMoreOrLessEquals(friction.x(0.0), 100.0)
        assertMoreOrLessEquals(friction.dx(0.0), 100.0)

        // Test positions at various times
        assertMoreOrLessEquals(friction.x(0.1), 110.0, epsilon: 1.0)
        assertMoreOrLessEquals(friction.x(0.5), 131.0, epsilon: 1.0)
        assertMoreOrLessEquals(friction.x(2.0), 149.0, epsilon: 1.0)

        // Test final position
        assertMoreOrLessEquals(friction.finalX, 149.0, epsilon: 1.0)

        // Test timeAtX inverse function
        XCTAssertEqual(friction.timeAtX(100.0), 0.0)
        assertMoreOrLessEquals(friction.timeAtX(friction.x(0.1)), 0.1)
        assertMoreOrLessEquals(friction.timeAtX(friction.x(0.5)), 0.5)
        assertMoreOrLessEquals(friction.timeAtX(friction.x(2.0)), 2.0)

        // Test out-of-range timeAtX returns infinity
        XCTAssertEqual(friction.timeAtX(-1.0), Double.infinity)
        XCTAssertEqual(friction.timeAtX(200.0), Double.infinity)
    }

    /// **Dart Test:** `friction_simulation_test.dart:30-49` - "Friction simulation negative velocity"
    ///
    /// Tests a friction simulation with negative initial velocity.
    func testFrictionSimulationNegativeVelocity() {
        let friction = FrictionSimulation(0.135, 100.0, -100.0)

        // Test initial position and velocity
        assertMoreOrLessEquals(friction.x(0.0), 100.0)
        assertMoreOrLessEquals(friction.dx(0.0), -100.0)

        // Test positions at various times
        assertMoreOrLessEquals(friction.x(0.1), 91.0, epsilon: 1.0)
        assertMoreOrLessEquals(friction.x(0.5), 68.0, epsilon: 1.0)
        assertMoreOrLessEquals(friction.x(2.0), 51.0, epsilon: 1.0)

        // Test final position
        assertMoreOrLessEquals(friction.finalX, 50.0, epsilon: 1.0)

        // Test timeAtX inverse function
        XCTAssertEqual(friction.timeAtX(100.0), 0.0)
        assertMoreOrLessEquals(friction.timeAtX(friction.x(0.1)), 0.1)
        assertMoreOrLessEquals(friction.timeAtX(friction.x(0.5)), 0.5)
        assertMoreOrLessEquals(friction.timeAtX(friction.x(2.0)), 2.0)

        // Test out-of-range timeAtX returns infinity
        XCTAssertEqual(friction.timeAtX(101.0), Double.infinity)
        XCTAssertEqual(friction.timeAtX(40.0), Double.infinity)
    }

    /// **Dart Test:** `friction_simulation_test.dart:51-75` - "Friction simulation constant deceleration"
    ///
    /// Tests a friction simulation with constant deceleration parameter.
    func testFrictionSimulationConstantDeceleration() {
        let friction = FrictionSimulation(
            0.135,
            100.0,
            -100.0,
            constantDeceleration: 100
        )

        // Test initial position and velocity
        assertMoreOrLessEquals(friction.x(0.0), 100.0)
        assertMoreOrLessEquals(friction.dx(0.0), -100.0)

        // Test positions at various times
        assertMoreOrLessEquals(friction.x(0.1), 91.0, epsilon: 1.0)
        assertMoreOrLessEquals(friction.x(0.5), 80.0, epsilon: 1.0)
        assertMoreOrLessEquals(friction.x(2.0), 80.0, epsilon: 1.0)

        // Test final position
        assertMoreOrLessEquals(friction.finalX, 80.0, epsilon: 1.0)

        // Test timeAtX inverse function
        XCTAssertEqual(friction.timeAtX(100.0), 0.0)
        assertMoreOrLessEquals(friction.timeAtX(friction.x(0.1)), 0.1)
        assertMoreOrLessEquals(friction.timeAtX(friction.x(0.2)), 0.2)
        assertMoreOrLessEquals(friction.timeAtX(friction.x(0.3)), 0.3)

        // Test out-of-range timeAtX returns infinity
        XCTAssertEqual(friction.timeAtX(101.0), Double.infinity)
        XCTAssertEqual(friction.timeAtX(40.0), Double.infinity)
    }

    // MARK: - Additional Tests

    /// Test that FrictionSimulation properly inherits from Simulation.
    func testFrictionSimulationInheritance() {
        let simulation: Simulation = FrictionSimulation(0.135, 0.0, 100.0)
        XCTAssertTrue(simulation is FrictionSimulation)
    }

    /// Test that FrictionSimulation has default tolerance from Simulation.
    func testFrictionSimulationDefaultTolerance() {
        let simulation = FrictionSimulation(0.135, 0.0, 100.0)
        XCTAssertEqual(simulation.tolerance, Tolerance.defaultTolerance)
    }

    /// Test FrictionSimulation.through factory method.
    func testFrictionSimulationThroughFactory() {
        let simulation = FrictionSimulation.through(
            startPosition: 0.0,
            endPosition: 100.0,
            startVelocity: 100.0,
            endVelocity: 0.0
        )

        // Should start at the specified position and velocity
        assertMoreOrLessEquals(simulation.x(0.0), 0.0)
        assertMoreOrLessEquals(simulation.dx(0.0), 100.0)

        // Should end at the specified position
        assertMoreOrLessEquals(simulation.finalX, 100.0, epsilon: 0.01)
    }

    /// Test FrictionSimulation description format.
    func testFrictionSimulationDescription() {
        let simulation = FrictionSimulation(0.135, 100.0, 50.0)
        let description = simulation.description

        // Verify single line
        XCTAssertFalse(description.contains("\n"))

        // Verify contains expected format elements
        XCTAssertTrue(description.contains("FrictionSimulation"))
        XCTAssertTrue(description.contains("cx:"))
        XCTAssertTrue(description.contains("x0:"))
        XCTAssertTrue(description.contains("dx0:"))
    }

    /// Test isDone returns true when velocity is below tolerance.
    func testFrictionSimulationIsDone() {
        let simulation = FrictionSimulation(0.135, 0.0, 100.0)

        // Should not be done initially
        XCTAssertFalse(simulation.isDone(0.0))

        // Should eventually be done as velocity approaches zero
        // At very large time values, velocity should be near zero
        XCTAssertTrue(simulation.isDone(100.0))
    }

    // MARK: - BoundedFrictionSimulation Tests

    /// Test BoundedFrictionSimulation clamps position to bounds.
    func testBoundedFrictionSimulationClampsBounds() {
        let simulation = BoundedFrictionSimulation(0.135, 50.0, 100.0, 0.0, 100.0)

        // Initial position should be within bounds
        assertMoreOrLessEquals(simulation.x(0.0), 50.0)

        // Should be clamped to maxX when it exceeds bounds
        let farFuture = 100.0
        let position = simulation.x(farFuture)
        XCTAssertLessThanOrEqual(position, 100.0)
        XCTAssertGreaterThanOrEqual(position, 0.0)
    }

    /// Test BoundedFrictionSimulation with negative velocity clamps to minX.
    func testBoundedFrictionSimulationClampsToMinX() {
        let simulation = BoundedFrictionSimulation(0.135, 50.0, -100.0, 0.0, 100.0)

        // Initial position should be within bounds
        assertMoreOrLessEquals(simulation.x(0.0), 50.0)

        // Should be clamped to minX when it goes below bounds
        let farFuture = 100.0
        let position = simulation.x(farFuture)
        XCTAssertGreaterThanOrEqual(position, 0.0)
    }

    /// Test BoundedFrictionSimulation isDone when reaching bounds.
    func testBoundedFrictionSimulationIsDoneAtBounds() {
        let simulation = BoundedFrictionSimulation(0.135, 50.0, 1000.0, 0.0, 100.0)

        // Should be done when position reaches maxX (within tolerance)
        // At some point, the position will hit the maxX bound
        var foundDone = false
        for t in stride(from: 0.0, through: 10.0, by: 0.1) {
            if simulation.isDone(t) {
                foundDone = true
                break
            }
        }
        XCTAssertTrue(foundDone, "Simulation should be done at some point when it reaches bounds")
    }

    /// Test BoundedFrictionSimulation description format.
    func testBoundedFrictionSimulationDescription() {
        let simulation = BoundedFrictionSimulation(0.135, 50.0, 100.0, 0.0, 100.0)
        let description = simulation.description

        // Verify single line
        XCTAssertFalse(description.contains("\n"))

        // Verify contains expected format elements
        XCTAssertTrue(description.contains("BoundedFrictionSimulation"))
        XCTAssertTrue(description.contains("cx:"))
        XCTAssertTrue(description.contains("x0:"))
        XCTAssertTrue(description.contains("dx0:"))
        XCTAssertTrue(description.contains("x:"))
        XCTAssertTrue(description.contains(".."))
    }

    /// Test BoundedFrictionSimulation properly inherits from FrictionSimulation.
    func testBoundedFrictionSimulationInheritance() {
        let simulation: Simulation = BoundedFrictionSimulation(0.135, 50.0, 100.0, 0.0, 100.0)
        XCTAssertTrue(simulation is BoundedFrictionSimulation)
        XCTAssertTrue(simulation is FrictionSimulation)
    }
}

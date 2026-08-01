// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import Foundation
@testable import Flutter

/// Tests for BouncingScrollSimulation and ClampingScrollSimulation.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/scroll_simulation_test.dart`
final class ScrollSimulationTests: XCTestCase {

    // MARK: - Test Helpers

    /// Asserts that two doubles are approximately equal within a specified epsilon.
    ///
    /// **Dart Equivalent:** `moreOrLessEquals` matcher from flutter_test
    private func assertMoreOrLessEquals(
        _ actual: Double,
        _ expected: Double,
        epsilon: Double = 1e-10,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            Swift.abs(actual - expected) <= epsilon,
            "Expected \(actual) to be within \(epsilon) of \(expected). \(message)",
            file: file,
            line: line
        )
    }

    /// A standard spring description for BouncingScrollSimulation tests,
    /// matching the iOS scrolling spring.
    private var testSpring: SpringDescription {
        SpringDescription(mass: 0.5, stiffness: 100.0, ratio: 1.1)
    }

    // MARK: - ClampingScrollSimulation: Stable Initial Conditions

    /// **Dart Test:** `scroll_simulation_test.dart:11-30`
    /// "ClampingScrollSimulation has a stable initial conditions"
    func testClampingScrollSimulationStableInitialConditions() {
        func checkInitialConditions(_ position: Double, _ velocity: Double) {
            let simulation = ClampingScrollSimulation(
                position: position,
                velocity: velocity
            )
            assertMoreOrLessEquals(simulation.x(0.0), position, epsilon: 1e-6)
            assertMoreOrLessEquals(simulation.dx(0.0), velocity, epsilon: 1e-6)
        }

        checkInitialConditions(51.0, 2866.91537)
        checkInitialConditions(584.0, 2617.294734)
        checkInitialConditions(345.0, 1982.785934)
        checkInitialConditions(0.0, 1831.366634)
        checkInitialConditions(-156.2, 1541.57665)
        checkInitialConditions(4.0, 1139.250439)
        checkInitialConditions(4534.0, 1073.553798)
        checkInitialConditions(75.0, 614.2093)
        checkInitialConditions(5469.0, 182.114534)
    }

    // MARK: - ClampingScrollSimulation: Monotonic Deceleration

    /// **Dart Test:** `scroll_simulation_test.dart:32-47`
    /// "ClampingScrollSimulation only decelerates, never speeds up"
    func testClampingScrollSimulationOnlyDecelerates() {
        let simulation = ClampingScrollSimulation(
            position: 0,
            velocity: 8000.0
        )
        var time = 0.0
        var velocity = simulation.dx(time)
        while !simulation.isDone(time) {
            XCTAssertLessThan(time, 3.0, "Simulation should finish within 3 seconds")
            time += 1.0 / 60.0
            let nextVelocity = simulation.dx(time)
            XCTAssertLessThanOrEqual(nextVelocity, velocity,
                "Velocity should never increase at time \(time)")
            velocity = nextVelocity
        }
    }

    // MARK: - ClampingScrollSimulation: Smooth Stop

    /// **Dart Test:** `scroll_simulation_test.dart:49-72`
    /// "ClampingScrollSimulation reaches a smooth stop: velocity is continuous and goes to zero"
    func testClampingScrollSimulationSmoothStop() {
        let initialVelocity = 8000.0
        let maxDeceleration = 5130.0
        let simulation = ClampingScrollSimulation(
            position: 0,
            velocity: initialVelocity
        )

        var time = 0.0
        var velocity = simulation.dx(time)
        let delta = 1.0 / 60.0
        repeat {
            XCTAssertLessThan(time, 3.0, "Simulation should finish within 3 seconds")
            time += delta
            let nextVelocity = simulation.dx(time)
            XCTAssertLessThan(
                Swift.abs(nextVelocity - velocity),
                delta * maxDeceleration,
                "Velocity change should be smooth at time \(time)"
            )
            velocity = nextVelocity
        } while !simulation.isDone(time)
        assertMoreOrLessEquals(velocity, 0.0, epsilon: 1e-1)
    }

    // MARK: - ClampingScrollSimulation: Ballistic Property

    /// **Dart Test:** `scroll_simulation_test.dart:74-111`
    /// "ClampingScrollSimulation is ballistic"
    func testClampingScrollSimulationIsBallistic() {
        let delta = 1.0 / 90.0
        let undisturbed = ClampingScrollSimulation(
            position: 0,
            velocity: 8000.0
        )

        var time = 0.0
        var restarted = undisturbed
        var xsRestarted: [Double] = []
        var xsUndisturbed: [Double] = []
        var dxsRestarted: [Double] = []
        var dxsUndisturbed: [Double] = []
        repeat {
            XCTAssertLessThan(time, 4.0, "Simulation should finish within 4 seconds")
            time += delta
            restarted = ClampingScrollSimulation(
                position: restarted.x(delta),
                velocity: restarted.dx(delta)
            )
            xsRestarted.append(restarted.x(0))
            xsUndisturbed.append(undisturbed.x(time))
            dxsRestarted.append(restarted.dx(0))
            dxsUndisturbed.append(undisturbed.dx(time))
        } while !restarted.isDone(0) || !undisturbed.isDone(time)

        // Compare total distances traveled first
        assertMoreOrLessEquals(xsRestarted.last!, xsUndisturbed.last!, epsilon: 1e-6)

        // Full trajectories should match
        for i in 0..<xsRestarted.count {
            assertMoreOrLessEquals(xsRestarted[i], xsUndisturbed[i], epsilon: 1e-6)
            assertMoreOrLessEquals(dxsRestarted[i], dxsUndisturbed[i], epsilon: 1e-6)
        }
    }

    // MARK: - ClampingScrollSimulation: Physical Acceleration Formula

    /// **Dart Test:** `scroll_simulation_test.dart:113-183`
    /// "ClampingScrollSimulation satisfies a physical acceleration formula"
    func testClampingScrollSimulationPhysicalAcceleration() {
        let kDecelerationRate = log(0.78) / log(0.9)
        let referenceVelocity = 0.015 * 9.80665 * 39.37 * 160.0 * 0.84 / 0.35
        let referenceDuration = kDecelerationRate * 0.35
        let referenceDeceleration = (kDecelerationRate - 1) * referenceVelocity / referenceDuration

        func acceleration(_ velocity: Double) -> Double {
            let sign: Double = velocity >= 0 ? 1.0 : -1.0
            return -sign *
                referenceDeceleration *
                pow(
                    Swift.abs(velocity) / referenceVelocity,
                    (kDecelerationRate - 2) / (kDecelerationRate - 1)
                )
        }

        func jerk(_ velocity: Double) -> Double {
            return referenceVelocity /
                referenceDuration /
                referenceDuration *
                (kDecelerationRate - 1) *
                (kDecelerationRate - 2) *
                pow(
                    Swift.abs(velocity) / referenceVelocity,
                    (kDecelerationRate - 3) / (kDecelerationRate - 1)
                )
        }

        func checkAcceleration(_ position: Double, _ velocity: Double) {
            let simulation = ClampingScrollSimulation(
                position: position,
                velocity: velocity
            )
            var time = 0.0
            let delta = 1.0 / 60.0
            while time < 2.0 {
                let difference = simulation.dx(time + delta) - simulation.dx(time)
                let predictedDifference = delta * acceleration(simulation.dx(time + delta / 2))
                let maxThirdDerivative = jerk(simulation.dx(time + delta))
                XCTAssertLessThan(
                    Swift.abs(difference - predictedDifference),
                    maxThirdDerivative * pow(delta, 2) / 2,
                    "Acceleration formula mismatch at time \(time) for position=\(position), velocity=\(velocity)"
                )
                time += delta
            }
        }

        checkAcceleration(51.0, 2866.91537)
        checkAcceleration(584.0, 2617.294734)
        checkAcceleration(345.0, 1982.785934)
        checkAcceleration(0.0, 1831.366634)
        checkAcceleration(-156.2, 1541.57665)
        checkAcceleration(4.0, 1139.250439)
        checkAcceleration(4534.0, 1073.553798)
        checkAcceleration(75.0, 614.2093)
        checkAcceleration(5469.0, 182.114534)
    }

    // MARK: - ClampingScrollSimulation: isDone

    func testClampingScrollSimulationIsDone() {
        let simulation = ClampingScrollSimulation(
            position: 0.0,
            velocity: 1000.0
        )
        // Should not be done at the start
        XCTAssertFalse(simulation.isDone(0.0))

        // Should eventually be done
        XCTAssertTrue(simulation.isDone(100.0))
    }

    // MARK: - ClampingScrollSimulation: Position Monotonicity

    func testClampingScrollSimulationPositionMonotonicallyIncreases() {
        let simulation = ClampingScrollSimulation(
            position: 0.0,
            velocity: 5000.0
        )
        var time = 0.0
        var position = simulation.x(time)
        while !simulation.isDone(time) {
            time += 1.0 / 60.0
            let nextPosition = simulation.x(time)
            XCTAssertGreaterThanOrEqual(nextPosition, position,
                "Position should increase for positive velocity at time \(time)")
            position = nextPosition
        }
    }

    // MARK: - ClampingScrollSimulation: Custom Friction

    func testClampingScrollSimulationCustomFriction() {
        let lowFriction = ClampingScrollSimulation(
            position: 0.0,
            velocity: 1000.0,
            friction: 0.005
        )
        let highFriction = ClampingScrollSimulation(
            position: 0.0,
            velocity: 1000.0,
            friction: 0.05
        )
        // With higher friction, the simulation should travel less distance
        // We check at a late time when both might still be going
        let lowX = lowFriction.x(1.0)
        let highX = highFriction.x(1.0)
        XCTAssertGreaterThan(lowX, highX,
            "Lower friction should result in greater distance traveled")
    }

    // MARK: - ClampingScrollSimulation: Negative Velocity

    func testClampingScrollSimulationNegativeVelocity() {
        let simulation = ClampingScrollSimulation(
            position: 100.0,
            velocity: -5000.0
        )
        assertMoreOrLessEquals(simulation.x(0.0), 100.0, epsilon: 1e-6)
        assertMoreOrLessEquals(simulation.dx(0.0), -5000.0, epsilon: 1e-6)

        // Position should decrease for negative velocity
        var time = 0.0
        var position = simulation.x(time)
        while !simulation.isDone(time) {
            time += 1.0 / 60.0
            let nextPosition = simulation.x(time)
            XCTAssertLessThanOrEqual(nextPosition, position,
                "Position should decrease for negative velocity at time \(time)")
            position = nextPosition
        }
    }

    // MARK: - BouncingScrollSimulation: Within Bounds (friction only)

    func testBouncingScrollSimulationWithinBoundsInitialConditions() {
        let simulation = BouncingScrollSimulation(
            position: 100.0,
            velocity: 500.0,
            leadingExtent: 0.0,
            trailingExtent: 1000.0,
            spring: testSpring
        )
        assertMoreOrLessEquals(simulation.x(0.0), 100.0, epsilon: 1e-3)
        assertMoreOrLessEquals(simulation.dx(0.0), 500.0, epsilon: 1.0)
    }

    func testBouncingScrollSimulationWithinBoundsEventuallyDone() {
        let simulation = BouncingScrollSimulation(
            position: 100.0,
            velocity: 500.0,
            leadingExtent: 0.0,
            trailingExtent: 1000.0,
            spring: testSpring
        )
        // Should eventually come to rest
        XCTAssertTrue(simulation.isDone(20.0),
            "Simulation should be done after sufficient time")
    }

    // MARK: - BouncingScrollSimulation: Overscroll (spring back)

    func testBouncingScrollSimulationOverscrollTrailing() {
        // Velocity pushes past trailingExtent
        let simulation = BouncingScrollSimulation(
            position: 900.0,
            velocity: 2000.0,
            leadingExtent: 0.0,
            trailingExtent: 1000.0,
            spring: testSpring
        )
        // Should eventually settle back near trailingExtent
        let finalPosition = simulation.x(20.0)
        assertMoreOrLessEquals(finalPosition, 1000.0, epsilon: 1.0,
            "Should settle near trailingExtent")
        XCTAssertTrue(simulation.isDone(20.0))
    }

    func testBouncingScrollSimulationOverscrollLeading() {
        // Velocity pushes past leadingExtent
        let simulation = BouncingScrollSimulation(
            position: 100.0,
            velocity: -2000.0,
            leadingExtent: 0.0,
            trailingExtent: 1000.0,
            spring: testSpring
        )
        // Should eventually settle back near leadingExtent
        let finalPosition = simulation.x(20.0)
        assertMoreOrLessEquals(finalPosition, 0.0, epsilon: 1.0,
            "Should settle near leadingExtent")
        XCTAssertTrue(simulation.isDone(20.0))
    }

    // MARK: - BouncingScrollSimulation: Starting Beyond Bounds

    func testBouncingScrollSimulationStartBeyondTrailing() {
        // Start position is already past trailingExtent
        let simulation = BouncingScrollSimulation(
            position: 1100.0,
            velocity: 0.0,
            leadingExtent: 0.0,
            trailingExtent: 1000.0,
            spring: testSpring
        )
        // Should spring back to trailingExtent
        let finalPosition = simulation.x(20.0)
        assertMoreOrLessEquals(finalPosition, 1000.0, epsilon: 1.0,
            "Should spring back to trailingExtent")
    }

    func testBouncingScrollSimulationStartBeyondLeading() {
        // Start position is before leadingExtent
        let simulation = BouncingScrollSimulation(
            position: -100.0,
            velocity: 0.0,
            leadingExtent: 0.0,
            trailingExtent: 1000.0,
            spring: testSpring
        )
        // Should spring back to leadingExtent
        let finalPosition = simulation.x(20.0)
        assertMoreOrLessEquals(finalPosition, 0.0, epsilon: 1.0,
            "Should spring back to leadingExtent")
    }

    // MARK: - BouncingScrollSimulation: Zero Velocity Within Bounds

    func testBouncingScrollSimulationZeroVelocityWithinBounds() {
        let simulation = BouncingScrollSimulation(
            position: 500.0,
            velocity: 0.0,
            leadingExtent: 0.0,
            trailingExtent: 1000.0,
            spring: testSpring
        )
        // Should be done immediately (or nearly so) with zero velocity inside bounds
        assertMoreOrLessEquals(simulation.x(0.0), 500.0, epsilon: 1e-3)
        assertMoreOrLessEquals(simulation.dx(0.0), 0.0, epsilon: 1e-3)
        XCTAssertTrue(simulation.isDone(0.0),
            "Zero velocity within bounds should be done immediately")
    }

    // MARK: - BouncingScrollSimulation: maxSpringTransferVelocity

    func testBouncingScrollSimulationMaxSpringTransferVelocity() {
        XCTAssertEqual(BouncingScrollSimulation.maxSpringTransferVelocity, 5000.0)
    }

    // MARK: - BouncingScrollSimulation: Properties

    func testBouncingScrollSimulationProperties() {
        let spring = testSpring
        let simulation = BouncingScrollSimulation(
            position: 50.0,
            velocity: 100.0,
            leadingExtent: 0.0,
            trailingExtent: 500.0,
            spring: spring
        )
        XCTAssertEqual(simulation.leadingExtent, 0.0)
        XCTAssertEqual(simulation.trailingExtent, 500.0)
        XCTAssertEqual(simulation.spring.mass, spring.mass)
        XCTAssertEqual(simulation.spring.stiffness, spring.stiffness)
        XCTAssertEqual(simulation.spring.damping, spring.damping)
    }

    // MARK: - BouncingScrollSimulation: Description

    func testBouncingScrollSimulationDescription() {
        let simulation = BouncingScrollSimulation(
            position: 50.0,
            velocity: 100.0,
            leadingExtent: 0.0,
            trailingExtent: 500.0,
            spring: testSpring
        )
        let desc = simulation.description
        XCTAssertTrue(desc.contains("BouncingScrollSimulation"))
        XCTAssertTrue(desc.contains("leadingExtent"))
        XCTAssertTrue(desc.contains("trailingExtent"))
    }

    // MARK: - BouncingScrollSimulation: Velocity Transitions

    func testBouncingScrollSimulationVelocityDecreasesOverTime() {
        let simulation = BouncingScrollSimulation(
            position: 100.0,
            velocity: 1000.0,
            leadingExtent: 0.0,
            trailingExtent: 10000.0,
            spring: testSpring
        )
        // For a simulation that stays within bounds (large trailing extent),
        // velocity should decrease monotonically
        var time = 0.0
        var velocity = simulation.dx(time)
        for _ in 0..<60 {
            time += 1.0 / 60.0
            let nextVelocity = simulation.dx(time)
            XCTAssertLessThanOrEqual(nextVelocity, velocity + 1e-6,
                "Velocity should not increase within bounds at time \(time)")
            velocity = nextVelocity
        }
    }

    // MARK: - BouncingScrollSimulation: Tolerance

    func testBouncingScrollSimulationCustomTolerance() {
        let tightTolerance = Tolerance(distance: 1e-6, time: 1e-6, velocity: 1e-6)
        let looseTolerance = Tolerance(distance: 10.0, time: 10.0, velocity: 10.0)

        let tightSim = BouncingScrollSimulation(
            position: 100.0,
            velocity: 500.0,
            leadingExtent: 0.0,
            trailingExtent: 1000.0,
            spring: testSpring,
            tolerance: tightTolerance
        )
        let looseSim = BouncingScrollSimulation(
            position: 100.0,
            velocity: 500.0,
            leadingExtent: 0.0,
            trailingExtent: 1000.0,
            spring: testSpring,
            tolerance: looseTolerance
        )

        // The loose tolerance simulation should finish sooner
        // Find a time where loose is done but tight might not be
        var time = 0.0
        while !looseSim.isDone(time) && time < 20.0 {
            time += 1.0 / 60.0
        }
        let looseDoneTime = time

        time = 0.0
        while !tightSim.isDone(time) && time < 20.0 {
            time += 1.0 / 60.0
        }
        let tightDoneTime = time

        XCTAssertLessThanOrEqual(looseDoneTime, tightDoneTime,
            "Looser tolerance should finish sooner or at the same time")
    }

    // MARK: - ClampingScrollSimulation: Zero Velocity

    func testClampingScrollSimulationZeroVelocity() {
        let simulation = ClampingScrollSimulation(
            position: 100.0,
            velocity: 0.0
        )
        // With zero velocity, should be done immediately
        assertMoreOrLessEquals(simulation.x(0.0), 100.0, epsilon: 1e-6)
        XCTAssertTrue(simulation.isDone(0.0),
            "Zero velocity should mean immediately done")
    }

    // MARK: - ClampingScrollSimulation: Position at Clamped Time

    func testClampingScrollSimulationPositionClampedTime() {
        let simulation = ClampingScrollSimulation(
            position: 0.0,
            velocity: 1000.0
        )
        // At time 0, position should be the initial position
        assertMoreOrLessEquals(simulation.x(0.0), 0.0, epsilon: 1e-6)

        // At very large time, position should not change (clamped to 1.0)
        let posAtLargeTime = simulation.x(100.0)
        let posAtVeryLargeTime = simulation.x(200.0)
        assertMoreOrLessEquals(posAtLargeTime, posAtVeryLargeTime, epsilon: 1e-6,
            "Position should stop changing after duration")
    }

    // MARK: - ClampingScrollSimulation: Velocity at Clamped Time

    func testClampingScrollSimulationVelocityClampedTime() {
        let simulation = ClampingScrollSimulation(
            position: 0.0,
            velocity: 1000.0
        )
        // Velocity at time 0 should be initial velocity
        assertMoreOrLessEquals(simulation.dx(0.0), 1000.0, epsilon: 1e-6)

        // Velocity at large time should be 0 (clamped)
        let velAtLargeTime = simulation.dx(100.0)
        assertMoreOrLessEquals(velAtLargeTime, 0.0, epsilon: 1e-6,
            "Velocity should be 0 after duration")
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for ClampedSimulation
/// **Dart Test Source:** `packages/flutter/test/physics/clamped_simulation_test.dart`
final class ClampedSimulationTests: XCTestCase {

    // MARK: - Dart Test Ports

    /// **Dart Test:** `clamped_simulation_test.dart:9-24` - "Clamped simulation 1"
    ///
    /// Tests x clamping with xMin/xMax and dx clamping with dxMin/dxMax.
    /// Uses GravitySimulation(9.81, 10.0, 0.0, 0.0) as underlying simulation.
    ///
    /// Initial conditions:
    /// - gravity: acceleration=9.81, distance=10.0, endDistance=0.0, velocity=0.0
    /// - At t=0: x = 10.0, dx = 0.0
    /// - At t=100: x = 10 + 0 + 0.5*9.81*10000 = 49060, dx = 0 + 9.81*100 = 981
    ///
    /// Clamping:
    /// - xMin=20.0, xMax=100.0 -> x(0)=10 clamped to 20, x(100)=49060 clamped to 100
    /// - dxMin=7.0, dxMax=11.0 -> dx(0)=0 clamped to 7, dx(100)=981 clamped to 11
    func testClampedSimulation1() {
        let gravity = GravitySimulation(acceleration: 9.81, distance: 10.0, endDistance: 0.0, velocity: 0.0)
        let clamped = ClampedSimulation(
            gravity,
            xMin: 20.0,
            xMax: 100.0,
            dxMin: 7.0,
            dxMax: 11.0
        )

        // At t=0: x(0)=10.0 < xMin=20.0, so clamped to 20.0
        XCTAssertEqual(clamped.x(0.0), 20.0)
        // At t=0: dx(0)=0.0 < dxMin=7.0, so clamped to 7.0
        XCTAssertEqual(clamped.dx(0.0), 7.0)

        // At t=100: x(100) = 10 + 0 + 0.5*9.81*10000 >> xMax=100.0, so clamped to 100.0
        XCTAssertEqual(clamped.x(100.0), 100.0)
        // At t=100: dx(100) = 0 + 9.81*100 = 981 > dxMax=11.0, so clamped to 11.0
        XCTAssertEqual(clamped.dx(100.0), 11.0)
    }

    /// **Dart Test:** `clamped_simulation_test.dart:26-51` - "Clamped simulation 2"
    ///
    /// Tests x and dx clamping over time, plus isDone delegation.
    /// Uses GravitySimulation(-10, 0.0, 6.0, 10.0) as underlying simulation.
    ///
    /// Unclamped trajectory:
    /// - At t=0: x=0.0, dx=10.0
    /// - At t=1: x=5.0 (peak), dx=0.0
    /// - At t=2: x=0.0, dx=-10.0
    /// - At t=3: x=-15.0, dx=-20.0, isDone=true (|x|=15 >= endDistance=6)
    ///
    /// Clamping:
    /// - xMin=0.0, xMax=2.5 -> x(1)=5 clamped to 2.5, x(2)=0 stays 0, x(3)=-15 clamped to 0
    /// - dxMin=-1.0, dxMax=1.0 -> dx(0)=10 clamped to 1, dx(2)=-10 clamped to -1, dx(3)=-20 clamped to -1
    func testClampedSimulation2() {
        let gravity = GravitySimulation(acceleration: -10, distance: 0.0, endDistance: 6.0, velocity: 10.0)
        let clamped = ClampedSimulation(
            gravity,
            xMin: 0.0,
            xMax: 2.5,
            dxMin: -1.0,
            dxMax: 1.0
        )

        // At t=0: x=0.0, dx=10.0 -> clamped x=0.0, dx=1.0
        XCTAssertEqual(clamped.x(0.0), 0.0)
        XCTAssertEqual(clamped.dx(0.0), 1.0)
        XCTAssertFalse(clamped.isDone(0.0))

        // At t=1: x=5.0 (peak), dx=0.0 -> clamped x=2.5, dx=0.0
        XCTAssertEqual(clamped.x(1.0), 2.5)
        XCTAssertEqual(clamped.dx(1.0), 0.0)
        XCTAssertFalse(clamped.isDone(0.2))

        // At t=2: x=0.0, dx=-10.0 -> clamped x=0.0, dx=-1.0
        XCTAssertEqual(clamped.x(2.0), 0.0)
        XCTAssertEqual(clamped.dx(2.0), -1.0)
        XCTAssertFalse(clamped.isDone(2.0))

        // At t=3: x=-15.0, dx=-20.0 -> clamped x=0.0 (since -15 < xMin=0), dx=-1.0
        // isDone=true because underlying simulation |x(3)|=15 >= endDistance=6
        XCTAssertEqual(clamped.x(3.0), 0.0)
        XCTAssertEqual(clamped.dx(3.0), -1.0)
        XCTAssertTrue(clamped.isDone(3.0))
    }

    // MARK: - Additional Tests

    /// Test that ClampedSimulation properly inherits from Simulation.
    func testClampedSimulationInheritance() {
        let gravity = GravitySimulation(acceleration: 9.81, distance: 0.0, endDistance: 10.0, velocity: 0.0)
        let simulation: Simulation = ClampedSimulation(gravity)
        XCTAssertTrue(simulation is ClampedSimulation)
    }

    /// Test that ClampedSimulation has default tolerance from Simulation.
    func testClampedSimulationDefaultTolerance() {
        let gravity = GravitySimulation(acceleration: 9.81, distance: 0.0, endDistance: 10.0, velocity: 0.0)
        let simulation = ClampedSimulation(gravity)
        XCTAssertEqual(simulation.tolerance, Tolerance.defaultTolerance)
    }

    /// Test default clamp values (no clamping with infinity bounds).
    func testClampedSimulationDefaultValues() {
        let gravity = GravitySimulation(acceleration: -10, distance: 0.0, endDistance: 6.0, velocity: 10.0)
        let clamped = ClampedSimulation(gravity) // Uses default -.infinity to .infinity

        // Unclamped values should pass through unchanged
        // At t=1: x=5.0, dx=0.0 (peak of trajectory)
        XCTAssertEqual(clamped.x(1.0), gravity.x(1.0))
        XCTAssertEqual(clamped.dx(1.0), gravity.dx(1.0))

        // At t=3: x=-15.0, dx=-20.0
        XCTAssertEqual(clamped.x(3.0), gravity.x(3.0))
        XCTAssertEqual(clamped.dx(3.0), gravity.dx(3.0))
    }

    /// Test that isDone is always delegated to underlying simulation.
    func testClampedSimulationIsDoneDelegation() {
        let gravity = GravitySimulation(acceleration: -10, distance: 0.0, endDistance: 6.0, velocity: 10.0)
        let clamped = ClampedSimulation(gravity, xMin: 0.0, xMax: 2.5)

        // isDone should match the underlying simulation regardless of clamping
        for t in stride(from: 0.0, to: 4.0, by: 0.5) {
            XCTAssertEqual(clamped.isDone(t), gravity.isDone(t),
                          "isDone should match underlying simulation at t=\(t)")
        }
    }

    /// Test description format includes expected components.
    func testClampedSimulationDescription() {
        let gravity = GravitySimulation(acceleration: 9.81, distance: 0.0, endDistance: 10.0, velocity: 0.0)
        let clamped = ClampedSimulation(gravity, xMin: 0.0, xMax: 100.0, dxMin: -5.0, dxMax: 10.0)
        let description = clamped.description

        // Verify single line
        XCTAssertFalse(description.contains("\n"))

        // Verify contains expected format elements
        XCTAssertTrue(description.contains("ClampedSimulation"))
        XCTAssertTrue(description.contains("simulation:"))
        XCTAssertTrue(description.contains("x:"))
        XCTAssertTrue(description.contains("dx:"))
    }

    /// Test clamping only x (dx remains unclamped with infinity bounds).
    func testClampedSimulationXOnlyClamping() {
        let gravity = GravitySimulation(acceleration: -10, distance: 0.0, endDistance: 100.0, velocity: 10.0)
        let clamped = ClampedSimulation(gravity, xMin: 2.0, xMax: 4.0)

        // dx should pass through unchanged
        XCTAssertEqual(clamped.dx(0.0), gravity.dx(0.0)) // 10.0
        XCTAssertEqual(clamped.dx(1.0), gravity.dx(1.0)) // 0.0
        XCTAssertEqual(clamped.dx(2.0), gravity.dx(2.0)) // -10.0

        // x should be clamped
        XCTAssertEqual(clamped.x(0.0), 2.0) // gravity.x(0)=0 -> clamped to xMin=2.0
        XCTAssertEqual(clamped.x(1.0), 4.0) // gravity.x(1)=5 -> clamped to xMax=4.0
        XCTAssertEqual(clamped.x(2.0), 2.0) // gravity.x(2)=0 -> clamped to xMin=2.0
    }

    /// Test clamping only dx (x remains unclamped with infinity bounds).
    func testClampedSimulationDxOnlyClamping() {
        let gravity = GravitySimulation(acceleration: -10, distance: 0.0, endDistance: 100.0, velocity: 10.0)
        let clamped = ClampedSimulation(gravity, dxMin: -5.0, dxMax: 5.0)

        // x should pass through unchanged
        XCTAssertEqual(clamped.x(0.0), gravity.x(0.0)) // 0.0
        XCTAssertEqual(clamped.x(1.0), gravity.x(1.0)) // 5.0
        XCTAssertEqual(clamped.x(2.0), gravity.x(2.0)) // 0.0

        // dx should be clamped
        XCTAssertEqual(clamped.dx(0.0), 5.0)  // gravity.dx(0)=10 -> clamped to dxMax=5.0
        XCTAssertEqual(clamped.dx(1.0), 0.0)  // gravity.dx(1)=0 -> within range, unchanged
        XCTAssertEqual(clamped.dx(2.0), -5.0) // gravity.dx(2)=-10 -> clamped to dxMin=-5.0
    }

    /// Test that wrapped simulation is accessible.
    func testClampedSimulationWrappedSimulationAccessible() {
        let gravity = GravitySimulation(acceleration: 9.81, distance: 10.0, endDistance: 5.0, velocity: 0.0)
        let clamped = ClampedSimulation(gravity, xMin: 0.0, xMax: 100.0)

        // The wrapped simulation should be accessible
        XCTAssertTrue(clamped.simulation === gravity, "Wrapped simulation should be the same object")
    }

    /// Test nested ClampedSimulation.
    func testClampedSimulationNested() {
        let gravity = GravitySimulation(acceleration: -10, distance: 0.0, endDistance: 100.0, velocity: 10.0)

        // First clamping: x in [0, 10], dx in [-20, 20]
        let clamped1 = ClampedSimulation(gravity, xMin: 0.0, xMax: 10.0, dxMin: -20.0, dxMax: 20.0)

        // Second clamping: x in [2, 5], dx in [-5, 5]
        let clamped2 = ClampedSimulation(clamped1, xMin: 2.0, xMax: 5.0, dxMin: -5.0, dxMax: 5.0)

        // At t=0: gravity.x=0, gravity.dx=10
        // After clamped1: x=0, dx=10 (within [-20, 20])
        // After clamped2: x=2 (clamped from 0), dx=5 (clamped from 10)
        XCTAssertEqual(clamped2.x(0.0), 2.0)
        XCTAssertEqual(clamped2.dx(0.0), 5.0)

        // At t=1 (peak): gravity.x=5, gravity.dx=0
        // After clamped1: x=5, dx=0 (both within range)
        // After clamped2: x=5, dx=0 (both within range)
        XCTAssertEqual(clamped2.x(1.0), 5.0)
        XCTAssertEqual(clamped2.dx(1.0), 0.0)

        // At t=3: gravity.x=-15, gravity.dx=-20
        // After clamped1: x=0 (clamped from -15), dx=-20 (at boundary)
        // After clamped2: x=2 (clamped from 0), dx=-5 (clamped from -20)
        XCTAssertEqual(clamped2.x(3.0), 2.0)
        XCTAssertEqual(clamped2.dx(3.0), -5.0)
    }
}

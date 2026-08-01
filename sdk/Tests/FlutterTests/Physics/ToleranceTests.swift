// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for Tolerance
/// **Dart Test Source:** `packages/flutter/test/physics/tolerance_test.dart`
final class ToleranceTests: XCTestCase {

    // MARK: - Dart Test Ports

    /// **Dart Test:** `tolerance_test.dart:9-11` - "Tolerance control test"
    func testToleranceHasOneLineDescription() {
        let description = Tolerance.defaultTolerance.description
        XCTAssertFalse(description.contains("\n"), "Tolerance description should be a single line")
        XCTAssertTrue(description.contains("Tolerance"), "Tolerance description should contain type name")
    }

    // MARK: - Default Tolerance Tests

    /// Test that default tolerance has the expected default values.
    func testDefaultToleranceValues() {
        let tolerance = Tolerance.defaultTolerance
        XCTAssertEqual(tolerance.distance, 1e-3)
        XCTAssertEqual(tolerance.time, 1e-3)
        XCTAssertEqual(tolerance.velocity, 1e-3)
    }

    /// Test that Tolerance() creates default tolerance with expected values.
    func testDefaultInitializerValues() {
        let tolerance = Tolerance()
        XCTAssertEqual(tolerance.distance, 1e-3)
        XCTAssertEqual(tolerance.time, 1e-3)
        XCTAssertEqual(tolerance.velocity, 1e-3)
    }

    // MARK: - Custom Tolerance Tests

    /// Test tolerance with custom values for all properties.
    func testCustomToleranceValues() {
        let tolerance = Tolerance(distance: 0.01, time: 0.02, velocity: 0.03)
        XCTAssertEqual(tolerance.distance, 0.01)
        XCTAssertEqual(tolerance.time, 0.02)
        XCTAssertEqual(tolerance.velocity, 0.03)
    }

    /// Test tolerance with partial custom values (only distance).
    func testPartialCustomValuesDistance() {
        let tolerance = Tolerance(distance: 0.5)
        XCTAssertEqual(tolerance.distance, 0.5)
        XCTAssertEqual(tolerance.time, 1e-3, "time should use default")
        XCTAssertEqual(tolerance.velocity, 1e-3, "velocity should use default")
    }

    /// Test tolerance with partial custom values (only time).
    func testPartialCustomValuesTime() {
        let tolerance = Tolerance(time: 0.5)
        XCTAssertEqual(tolerance.distance, 1e-3, "distance should use default")
        XCTAssertEqual(tolerance.time, 0.5)
        XCTAssertEqual(tolerance.velocity, 1e-3, "velocity should use default")
    }

    /// Test tolerance with partial custom values (only velocity).
    func testPartialCustomValuesVelocity() {
        let tolerance = Tolerance(velocity: 0.5)
        XCTAssertEqual(tolerance.distance, 1e-3, "distance should use default")
        XCTAssertEqual(tolerance.time, 1e-3, "time should use default")
        XCTAssertEqual(tolerance.velocity, 0.5)
    }

    // MARK: - Hashable Conformance Tests

    /// Test that identical tolerances are equal.
    func testToleranceEquality() {
        let tolerance1 = Tolerance(distance: 0.1, time: 0.2, velocity: 0.3)
        let tolerance2 = Tolerance(distance: 0.1, time: 0.2, velocity: 0.3)
        XCTAssertEqual(tolerance1, tolerance2)
    }

    /// Test that different tolerances are not equal.
    func testToleranceInequality() {
        let tolerance1 = Tolerance(distance: 0.1, time: 0.2, velocity: 0.3)
        let tolerance2 = Tolerance(distance: 0.4, time: 0.5, velocity: 0.6)
        XCTAssertNotEqual(tolerance1, tolerance2)
    }

    /// Test that identical tolerances have the same hash value.
    func testToleranceHashableConsistency() {
        let tolerance1 = Tolerance(distance: 0.1, time: 0.2, velocity: 0.3)
        let tolerance2 = Tolerance(distance: 0.1, time: 0.2, velocity: 0.3)
        XCTAssertEqual(tolerance1.hashValue, tolerance2.hashValue)
    }

    /// Test that tolerances can be used in a Set.
    func testToleranceInSet() {
        let tolerance1 = Tolerance(distance: 0.1, time: 0.2, velocity: 0.3)
        let tolerance2 = Tolerance(distance: 0.1, time: 0.2, velocity: 0.3)
        let tolerance3 = Tolerance(distance: 0.4, time: 0.5, velocity: 0.6)

        let set: Set<Tolerance> = [tolerance1, tolerance2, tolerance3]
        XCTAssertEqual(set.count, 2, "Set should have 2 unique tolerances")
        XCTAssertTrue(set.contains(tolerance1))
        XCTAssertTrue(set.contains(tolerance3))
    }

    // MARK: - Description Format Tests

    /// Test that description contains expected format elements.
    func testToleranceDescriptionFormat() {
        let tolerance = Tolerance(distance: 0.001, time: 0.001, velocity: 0.001)
        let description = tolerance.description

        XCTAssertTrue(description.contains("Tolerance"), "Description should contain type name")
        XCTAssertTrue(description.contains("distance:"), "Description should contain distance label")
        XCTAssertTrue(description.contains("time:"), "Description should contain time label")
        XCTAssertTrue(description.contains("velocity:"), "Description should contain velocity label")
    }

    /// Test description with plus-minus symbol for tolerances.
    func testToleranceDescriptionPlusMinusSymbol() {
        let tolerance = Tolerance.defaultTolerance
        let description = tolerance.description

        // The description should contain the plus-minus symbol
        XCTAssertTrue(description.contains("\u{00B1}"), "Description should contain plus-minus symbol")
    }

    // MARK: - Static Instance Tests

    /// Test that defaultTolerance is the same as a new default Tolerance.
    func testDefaultToleranceMatchesNewTolerance() {
        let defaultTol = Tolerance.defaultTolerance
        let newTol = Tolerance()
        XCTAssertEqual(defaultTol, newTol)
    }
}

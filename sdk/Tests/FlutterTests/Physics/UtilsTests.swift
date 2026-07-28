// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for Physics utility functions (nearEqual, nearZero)
///
/// **Dart Test Source:** `packages/flutter/test/physics/utils_test.dart`
final class UtilsTests: XCTestCase {

    // MARK: - nearEqual Tests

    /// Test nearEqual with positive infinity values.
    /// **Dart Test:** `utils_test.dart:10` - "nearEquals"
    func testNearEqualPositiveInfinity() {
        XCTAssertTrue(nearEqual(Double.infinity, Double.infinity, 0.1))
    }

    /// Test nearEqual with negative infinity values.
    /// **Dart Test:** `utils_test.dart:11` - "nearEquals"
    func testNearEqualNegativeInfinity() {
        XCTAssertTrue(nearEqual(-Double.infinity, -Double.infinity, 0.1))
    }

    /// Test nearEqual with mixed infinity values.
    /// **Dart Test:** `utils_test.dart:13` - "nearEquals"
    func testNearEqualMixedInfinity() {
        XCTAssertFalse(nearEqual(Double.infinity, -Double.infinity, 0.1))
    }

    /// Test nearEqual with numeric values - not within epsilon.
    /// **Dart Test:** `utils_test.dart:15` - "nearEquals"
    func testNearEqualNumericNotWithinEpsilon() {
        XCTAssertFalse(nearEqual(0.1, 0.11, 0.001))
    }

    /// Test nearEqual with numeric values - within epsilon.
    /// **Dart Test:** `utils_test.dart:16` - "nearEquals"
    func testNearEqualNumericWithinEpsilon() {
        XCTAssertTrue(nearEqual(0.1, 0.11, 0.1))
    }

    /// Test nearEqual with same numeric values.
    /// **Dart Test:** `utils_test.dart:17` - "nearEquals"
    func testNearEqualSameNumericValues() {
        XCTAssertTrue(nearEqual(0.1, 0.1, 0.0000001))
    }

    // MARK: - nearEqual with nil Tests (Swift-specific)

    /// Test nearEqual with both nil values.
    func testNearEqualBothNil() {
        XCTAssertTrue(nearEqual(nil, nil, 0.1))
    }

    /// Test nearEqual with first value nil.
    func testNearEqualFirstNil() {
        XCTAssertFalse(nearEqual(nil, 1.0, 0.1))
    }

    /// Test nearEqual with second value nil.
    func testNearEqualSecondNil() {
        XCTAssertFalse(nearEqual(1.0, nil, 0.1))
    }

    // MARK: - nearZero Tests

    /// Test nearZero with zero value.
    func testNearZeroWithZero() {
        XCTAssertTrue(nearZero(0.0, 0.1))
    }

    /// Test nearZero with small positive value within epsilon.
    func testNearZeroSmallPositiveWithinEpsilon() {
        XCTAssertTrue(nearZero(0.05, 0.1))
    }

    /// Test nearZero with value outside epsilon.
    func testNearZeroOutsideEpsilon() {
        XCTAssertFalse(nearZero(0.5, 0.1))
    }

    /// Test nearZero with small negative value within epsilon.
    func testNearZeroSmallNegativeWithinEpsilon() {
        XCTAssertTrue(nearZero(-0.05, 0.1))
    }

    // MARK: - Edge Cases

    /// Test nearEqual with zero epsilon (exact match required).
    func testNearEqualZeroEpsilon() {
        XCTAssertTrue(nearEqual(1.0, 1.0, 0.0))
        XCTAssertFalse(nearEqual(1.0, 1.0000001, 0.0))
    }

    /// Test nearEqual with very small epsilon.
    func testNearEqualVerySmallEpsilon() {
        XCTAssertTrue(nearEqual(1.0, 1.0, 1e-15))
        XCTAssertFalse(nearEqual(1.0, 1.0 + 1e-10, 1e-15))
    }

    /// Test nearEqual with negative values.
    func testNearEqualNegativeValues() {
        XCTAssertTrue(nearEqual(-1.0, -1.05, 0.1))
        XCTAssertFalse(nearEqual(-1.0, -1.2, 0.1))
    }
}

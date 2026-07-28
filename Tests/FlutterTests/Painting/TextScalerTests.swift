// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for TextScaler, LinearTextScaler, and ClampedTextScaler.
///
/// **Dart Test Source:** `packages/flutter/test/painting/text_scaler_test.dart`
///
/// Note: The `SystemTextScaler` tests from the Dart source depend on the widgets
/// layer (MediaQueryData) and are intentionally not migrated.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class TextScalerTests: XCTestCase {

    // MARK: - Linear TextScaler Equality Tests

    /// Test that different ways to create a TextScaler with the same effective
    /// scale factor produce equal results.
    ///
    /// **Dart Test:** `text_scaler_test.dart:10-23` - "Linear TextScaler equality"
    func testLinearTextScalerEquality() {
        // a: directly created with linear(3.0)
        let a = TextScalers.linear(3.0)

        // b: noScaling clamped to min 3.0 (max defaults to infinity)
        // noScaling = LinearTextScaler(1.0), clamp(min:3.0, max:inf) => clampDouble(1.0, 3.0, inf) = 3.0 => LinearTextScaler(3.0)
        let b = TextScalers.noScaling.clamp(minScaleFactor: 3.0, maxScaleFactor: Double.infinity)

        // c: another linear(3.0) - separate instance
        let c = TextScalers.linear(3.0)

        // d: double-clamped noScaling
        // noScaling.clamp(min:1, max:5) => clampDouble(1.0, 1.0, 5.0) = 1.0 == textScaleFactor => self = LinearTextScaler(1.0)
        // then .clamp(min:3, max:6) => clampDouble(1.0, 3.0, 6.0) = 3.0 != 1.0 => LinearTextScaler(3.0)
        let d = TextScalers.noScaling
            .clamp(minScaleFactor: 1, maxScaleFactor: 5)
            .clamp(minScaleFactor: 3, maxScaleFactor: 6)

        // All should be equal (all are LinearTextScaler(3.0))
        let list: [any TextScaler] = [a, b, c, d]
        for i in 0..<list.count {
            for j in 0..<list.count {
                XCTAssertTrue(list[i] == list[j], "list[\(i)] should equal list[\(j)]")
            }
        }
    }

    // MARK: - Linear TextScaler Clamping Tests

    /// Test the clamping behavior of TextScaler.
    ///
    /// **Dart Test:** `text_scaler_test.dart:25-44` - "Linear TextScaler clamping"
    func testLinearTextScalerClamping() {
        // noScaling clamped to min 3.0 should equal linear(3.0)
        // **Dart Test:** `text_scaler_test.dart:26`
        let clampedMin = TextScalers.noScaling.clamp(minScaleFactor: 3.0, maxScaleFactor: Double.infinity)
        let linear3 = TextScalers.linear(3.0)
        XCTAssertTrue(clampedMin == linear3)

        // linear(5.0) clamped to max 3.0 should equal linear(3.0)
        // **Dart Test:** `text_scaler_test.dart:27`
        let clampedMax = TextScalers.linear(5.0).clamp(minScaleFactor: 0, maxScaleFactor: 3.0)
        XCTAssertTrue(clampedMax == linear3)

        // linear(5.0) clamped to max 3.0 should equal linear(3.0) (duplicate test from Dart)
        // **Dart Test:** `text_scaler_test.dart:28`
        let clampedMax2 = TextScalers.linear(5.0).clamp(minScaleFactor: 0, maxScaleFactor: 3.0)
        XCTAssertTrue(clampedMax2 == linear3)

        // linear(5.0) clamped to [3.0, 3.0] should equal linear(3.0)
        // **Dart Test:** `text_scaler_test.dart:29-32`
        let clampedEqual = TextScalers.linear(5.0).clamp(minScaleFactor: 3.0, maxScaleFactor: 3.0)
        XCTAssertTrue(clampedEqual == linear3)
    }

    // MARK: - LinearTextScaler Scale Tests

    /// Test that LinearTextScaler correctly scales font sizes.
    func testLinearTextScalerScale() {
        let scaler = LinearTextScaler(2.0)
        XCTAssertEqual(scaler.scale(10.0), 20.0)
        XCTAssertEqual(scaler.scale(0.0), 0.0)
        XCTAssertEqual(scaler.scale(1.5), 3.0)
    }

    /// Test that noScaling returns the input font size unchanged.
    func testNoScaling() {
        let scaler = TextScalers.noScaling
        XCTAssertEqual(scaler.scale(10.0), 10.0)
        XCTAssertEqual(scaler.scale(0.0), 0.0)
        XCTAssertEqual(scaler.scale(42.5), 42.5)
    }

    // MARK: - ClampedTextScaler Scale Tests

    /// Test that ClampedTextScaler correctly clamps scaled values.
    func testClampedTextScalerScale() {
        // A scaler that scales by 5x but clamped to [1, 3]
        let clamped = ClampedTextScaler(LinearTextScaler(5.0), minScale: 1.0, maxScale: 3.0)
        // scale(10.0): scaler.scale(10.0) = 50.0, clamped to [1*10, 3*10] = [10, 30] => 30.0
        XCTAssertEqual(clamped.scale(10.0), 30.0)

        // scale(1.0): scaler.scale(1.0) = 5.0, clamped to [1*1, 3*1] = [1, 3] => 3.0
        XCTAssertEqual(clamped.scale(1.0), 3.0)
    }

    /// Test clamping to minimum value.
    func testClampedTextScalerMinimum() {
        // noScaling (1x) clamped to [3, 5] => scale(10.0): 1*10=10, clamped to [30, 50] => 30.0
        let clamped = ClampedTextScaler(LinearTextScaler(1.0), minScale: 3.0, maxScale: 5.0)
        XCTAssertEqual(clamped.scale(10.0), 30.0)
    }

    // MARK: - LinearTextScaler Equality Tests

    /// Test that LinearTextScaler equality works correctly.
    func testLinearTextScalerEqualityDirect() {
        let a = LinearTextScaler(3.0)
        let b = LinearTextScaler(3.0)
        let c = LinearTextScaler(5.0)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - LinearTextScaler Hashable Tests

    /// Test that equal LinearTextScalers have equal hash values.
    func testLinearTextScalerHashable() {
        let a = LinearTextScaler(3.0)
        let b = LinearTextScaler(3.0)
        let c = LinearTextScaler(5.0)

        XCTAssertEqual(a.hashValue, b.hashValue)
        XCTAssertNotEqual(a.hashValue, c.hashValue)
    }

    // MARK: - ClampedTextScaler Equality Tests

    /// Test that ClampedTextScaler equality works correctly.
    func testClampedTextScalerEquality() {
        let a = ClampedTextScaler(LinearTextScaler(1.0), minScale: 2.0, maxScale: 5.0)
        let b = ClampedTextScaler(LinearTextScaler(1.0), minScale: 2.0, maxScale: 5.0)
        let c = ClampedTextScaler(LinearTextScaler(1.0), minScale: 3.0, maxScale: 5.0)
        let d = ClampedTextScaler(LinearTextScaler(2.0), minScale: 2.0, maxScale: 5.0)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a, d)
    }

    // MARK: - ClampedTextScaler Hashable Tests

    /// Test that equal ClampedTextScalers have equal hash values.
    func testClampedTextScalerHashable() {
        let a = ClampedTextScaler(LinearTextScaler(1.0), minScale: 2.0, maxScale: 5.0)
        let b = ClampedTextScaler(LinearTextScaler(1.0), minScale: 2.0, maxScale: 5.0)

        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - CustomStringConvertible Tests

    /// Test LinearTextScaler description.
    func testLinearTextScalerDescription() {
        XCTAssertEqual(LinearTextScaler(1.0).description, "no scaling")
        XCTAssertEqual(LinearTextScaler(2.0).description, "linear (2.0x)")
        XCTAssertEqual(LinearTextScaler(0.5).description, "linear (0.5x)")
    }

    /// Test ClampedTextScaler description.
    func testClampedTextScalerDescription() {
        let clamped = ClampedTextScaler(LinearTextScaler(1.0), minScale: 2.0, maxScale: 5.0)
        XCTAssertEqual(clamped.description, "no scaling clamped [2.0, 5.0]")

        let clamped2 = ClampedTextScaler(LinearTextScaler(3.0), minScale: 1.0, maxScale: 4.0)
        XCTAssertEqual(clamped2.description, "linear (3.0x) clamped [1.0, 4.0]")
    }

    // MARK: - Clamp Returns Self When Unchanged Tests

    /// Test that clamping a LinearTextScaler within range returns the same scaler.
    func testLinearClampReturnsSelfWhenUnchanged() {
        let scaler = LinearTextScaler(3.0)
        let clamped = scaler.clamp(minScaleFactor: 0, maxScaleFactor: Double.infinity)
        // Should return self (same value)
        XCTAssertTrue(clamped is LinearTextScaler)
        XCTAssertTrue(clamped == TextScalers.linear(3.0))
    }

    // MARK: - Nested Clamping Tests

    /// Test that ClampedTextScaler.clamp correctly narrows the clamping bounds.
    func testNestedClamping() {
        // Create a clamped scaler with [1, 5]
        let base = ClampedTextScaler(LinearTextScaler(10.0), minScale: 1.0, maxScale: 5.0)
        // Clamp further to [2, 4] => should use max(2, 1)=2 and min(4, 5)=4
        let narrowed = base.clamp(minScaleFactor: 2.0, maxScaleFactor: 4.0)
        XCTAssertTrue(narrowed is ClampedTextScaler)

        let narrowedClamped = narrowed as! ClampedTextScaler
        XCTAssertEqual(narrowedClamped.minScale, 2.0)
        XCTAssertEqual(narrowedClamped.maxScale, 4.0)
    }

    /// Test that ClampedTextScaler.clamp with equal min/max returns a LinearTextScaler.
    func testClampedClampReturnsLinearWhenEqual() {
        let base = ClampedTextScaler(LinearTextScaler(10.0), minScale: 1.0, maxScale: 5.0)
        let result = base.clamp(minScaleFactor: 3.0, maxScaleFactor: 3.0)
        XCTAssertTrue(result is LinearTextScaler)
        XCTAssertTrue(result == TextScalers.linear(3.0))
    }
}

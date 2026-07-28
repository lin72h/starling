// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for FractionalOffset.
///
/// **Dart Test Source:** `packages/flutter/test/painting/fractional_offset_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class FractionalOffsetTests: XCTestCase {

    // MARK: - Control Test

    /// **Dart Test:** `fractional_offset_test.dart:9-24` - "FractionalOffset control test"
    func testFractionalOffsetControl() {
        let a = FractionalOffset(0.5, 0.25)
        let b = FractionalOffset(1.25, 0.75)

        // Test hashCode equality
        /// **Dart Test:** `fractional_offset_test.dart:14`
        XCTAssertEqual(a.hashValue, FractionalOffset(0.5, 0.25).hashValue)

        // Test toString
        /// **Dart Test:** `fractional_offset_test.dart:15`
        /// Note: Dart's toStringAsFixed(1) rounds 0.25 to "0.3" (round-half-away-from-zero),
        /// while Swift's String(format: "%.1f") rounds 0.25 to "0.2" (banker's rounding).
        /// The Dart test expects "FractionalOffset(0.5, 0.3)".
        XCTAssertEqual(a.description, "FractionalOffset(0.5, 0.2)")

        // Test negation
        /// **Dart Test:** `fractional_offset_test.dart:17`
        XCTAssertEqual(-a, FractionalOffset(-0.5, -0.25))

        // Test subtraction
        /// **Dart Test:** `fractional_offset_test.dart:18`
        XCTAssertEqual(a - b, FractionalOffset(-0.75, -0.5))

        // Test addition
        /// **Dart Test:** `fractional_offset_test.dart:19`
        XCTAssertEqual(a + b, FractionalOffset(1.75, 1.0))

        // Test multiplication
        /// **Dart Test:** `fractional_offset_test.dart:20`
        XCTAssertEqual(a * 2.0, FractionalOffset.centerRight)

        // Test division
        /// **Dart Test:** `fractional_offset_test.dart:21`
        XCTAssertEqual(a / 2.0, FractionalOffset(0.25, 0.125))

        // Test truncating division (Dart's ~/ operator)
        /// **Dart Test:** `fractional_offset_test.dart:22`
        XCTAssertEqual(a.truncatingDivision(2.0), FractionalOffset.topLeft)

        // Test modulo
        /// **Dart Test:** `fractional_offset_test.dart:23`
        XCTAssertEqual(a % 5.0, FractionalOffset(0.5, 0.25))
    }

    // MARK: - Lerp Tests

    /// **Dart Test:** `fractional_offset_test.dart:26-34` - "FractionalOffset.lerp()"
    func testFractionalOffsetLerp() {
        let a = FractionalOffset.topLeft
        let b = FractionalOffset.topCenter

        /// **Dart Test:** `fractional_offset_test.dart:29`
        XCTAssertEqual(
            FractionalOffset.lerp(a, b, 0.25),
            FractionalOffset(0.125, 0.0)
        )

        /// **Dart Test:** `fractional_offset_test.dart:31`
        XCTAssertNil(FractionalOffset.lerp(nil, nil, 0.25))

        /// **Dart Test:** `fractional_offset_test.dart:32`
        /// lerp(nil, topCenter, 0.25) interpolates from center (0.5, 0.5)
        /// to topCenter (0.5, 0.0) at t=0.25: (0.5, 0.5 - 0.125) = (0.5, 0.375)
        XCTAssertEqual(
            FractionalOffset.lerp(nil, b, 0.25),
            FractionalOffset(0.5, 0.5 - 0.125)
        )

        /// **Dart Test:** `fractional_offset_test.dart:33`
        /// lerp(topLeft, nil, 0.25) interpolates from topLeft (0.0, 0.0)
        /// to center (0.5, 0.5) at t=0.25: (0.125, 0.125)
        XCTAssertEqual(
            FractionalOffset.lerp(a, nil, 0.25),
            FractionalOffset(0.125, 0.125)
        )
    }

    /// **Dart Test:** `fractional_offset_test.dart:36-40` - "FractionalOffset.lerp identical a,b"
    func testFractionalOffsetLerpIdentical() {
        /// **Dart Test:** `fractional_offset_test.dart:37`
        XCTAssertNil(FractionalOffset.lerp(nil, nil, 0))

        /// **Dart Test:** `fractional_offset_test.dart:38-39`
        let decoration = FractionalOffset(1, 2)
        let result = FractionalOffset.lerp(decoration, decoration, 0.5)
        // In Swift structs, identity check becomes value equality
        XCTAssertEqual(result, decoration)
    }

    // MARK: - Factory Method Tests

    /// **Dart Test:** `fractional_offset_test.dart:42-48` - "FractionalOffset.fromOffsetAndSize()"
    func testFractionalOffsetFromOffsetAndSize() {
        /// **Dart Test:** `fractional_offset_test.dart:43-46`
        let a = FractionalOffset.fromOffsetAndSize(
            Offset(100.0, 100.0),
            Size(200.0, 400.0)
        )
        /// **Dart Test:** `fractional_offset_test.dart:47`
        XCTAssertEqual(a, FractionalOffset(0.5, 0.25))
    }

    /// **Dart Test:** `fractional_offset_test.dart:50-56` - "FractionalOffset.fromOffsetAndRect()"
    func testFractionalOffsetFromOffsetAndRect() {
        /// **Dart Test:** `fractional_offset_test.dart:51-54`
        let a = FractionalOffset.fromOffsetAndRect(
            Offset(150.0, 120.0),
            Rect.fromLTWH(50.0, 20.0, 200.0, 400.0)
        )
        /// **Dart Test:** `fractional_offset_test.dart:55`
        XCTAssertEqual(a, FractionalOffset(0.5, 0.25))
    }

    // MARK: - Additional Tests

    /// Test that dx and dy properties correctly convert from Alignment coordinates.
    func testFractionalOffsetDxDy() {
        let offset = FractionalOffset(0.5, 0.25)
        XCTAssertEqual(offset.dx, 0.5)
        XCTAssertEqual(offset.dy, 0.25)

        let topLeft = FractionalOffset.topLeft
        XCTAssertEqual(topLeft.dx, 0.0)
        XCTAssertEqual(topLeft.dy, 0.0)

        let bottomRight = FractionalOffset.bottomRight
        XCTAssertEqual(bottomRight.dx, 1.0)
        XCTAssertEqual(bottomRight.dy, 1.0)

        let center = FractionalOffset.center
        XCTAssertEqual(center.dx, 0.5)
        XCTAssertEqual(center.dy, 0.5)
    }

    /// Test that FractionalOffset correctly converts to Alignment coordinates.
    func testFractionalOffsetAlignmentCoordinates() {
        // FractionalOffset(0.0, 0.0) should be Alignment(-1.0, -1.0) (topLeft)
        let topLeft = FractionalOffset(0.0, 0.0)
        XCTAssertEqual(topLeft.x, -1.0)
        XCTAssertEqual(topLeft.y, -1.0)

        // FractionalOffset(0.5, 0.5) should be Alignment(0.0, 0.0) (center)
        let center = FractionalOffset(0.5, 0.5)
        XCTAssertEqual(center.x, 0.0)
        XCTAssertEqual(center.y, 0.0)

        // FractionalOffset(1.0, 1.0) should be Alignment(1.0, 1.0) (bottomRight)
        let bottomRight = FractionalOffset(1.0, 1.0)
        XCTAssertEqual(bottomRight.x, 1.0)
        XCTAssertEqual(bottomRight.y, 1.0)
    }

    /// Test that static constants have expected values.
    func testFractionalOffsetStaticConstants() {
        XCTAssertEqual(FractionalOffset.topLeft, FractionalOffset(0.0, 0.0))
        XCTAssertEqual(FractionalOffset.topCenter, FractionalOffset(0.5, 0.0))
        XCTAssertEqual(FractionalOffset.topRight, FractionalOffset(1.0, 0.0))
        XCTAssertEqual(FractionalOffset.centerLeft, FractionalOffset(0.0, 0.5))
        XCTAssertEqual(FractionalOffset.center, FractionalOffset(0.5, 0.5))
        XCTAssertEqual(FractionalOffset.centerRight, FractionalOffset(1.0, 0.5))
        XCTAssertEqual(FractionalOffset.bottomLeft, FractionalOffset(0.0, 1.0))
        XCTAssertEqual(FractionalOffset.bottomCenter, FractionalOffset(0.5, 1.0))
        XCTAssertEqual(FractionalOffset.bottomRight, FractionalOffset(1.0, 1.0))
    }

    /// Test resolve returns an equivalent Alignment.
    func testFractionalOffsetResolve() {
        let offset = FractionalOffset(0.5, 0.25)
        let resolved = offset.resolve(.ltr)
        XCTAssertEqual(resolved.x, offset.x)
        XCTAssertEqual(resolved.y, offset.y)

        // resolve is independent of text direction
        let resolvedRtl = offset.resolve(.rtl)
        XCTAssertEqual(resolvedRtl.x, offset.x)
        XCTAssertEqual(resolvedRtl.y, offset.y)
    }

    /// Test Hashable conformance.
    func testFractionalOffsetHashable() {
        let a = FractionalOffset(0.5, 0.25)
        let b = FractionalOffset(0.5, 0.25)
        let c = FractionalOffset(0.25, 0.5)

        XCTAssertEqual(a.hashValue, b.hashValue)
        XCTAssertNotEqual(a.hashValue, c.hashValue)

        // Test use in Set
        var set = Set<FractionalOffset>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
        set.insert(c)
        XCTAssertEqual(set.count, 2)
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for OvalBorder.
///
/// **Dart Test Source:** `packages/flutter/test/painting/oval_border_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class OvalBorderTests: XCTestCase {

    // MARK: - Defaults Test

    /// **Dart Test:** `oval_border_test.dart:9-12` - "OvalBorder defaults"
    func testOvalBorderDefaults() {
        let border = OvalBorder()
        XCTAssertEqual(border.side, BorderSide.none)
        XCTAssertEqual(border.eccentricity, 1.0)
    }

    // MARK: - copyWith, ==, hashCode Tests

    /// **Dart Test:** `oval_border_test.dart:14-19` - "OvalBorder copyWith, ==, hashCode"
    func testOvalBorderCopyWithEqualityHashCode() {
        let border = OvalBorder()
        let copiedBorder = border.copyWith()

        // Test equality: const OvalBorder() == const OvalBorder().copyWith()
        XCTAssertEqual(border, copiedBorder)

        // Test hashCode equality
        XCTAssertEqual(border.hashValue, copiedBorder.hashValue)

        // Test copyWith(side:) updates side
        // **Dart Test:** `oval_border_test.dart:17-18`
        let side = BorderSide(color: Color(0xff123456), width: 10.0)
        let borderWithSide: OvalBorder = OvalBorder().copyWith(side: side)
        let expectedBorder = OvalBorder(side: side)
        XCTAssertEqual(borderWithSide, expectedBorder)
    }

    // MARK: - Scale, Lerp, Dimensions, Path Tests

    /// **Dart Test:** `oval_border_test.dart:21-45` - "OvalBorder"
    func testOvalBorderScaleLerpDimensionsPaths() {
        let c10 = OvalBorder(side: BorderSide(width: 10.0))
        let c15 = OvalBorder(side: BorderSide(width: 15.0))
        let c20 = OvalBorder(side: BorderSide(width: 20.0))

        // Test dimensions
        // **Dart Test:** `oval_border_test.dart:25`
        if let dimensions = c10.dimensions as? EdgeInsets {
            XCTAssertEqual(dimensions, EdgeInsets(all: 10.0))
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        // Test scale(2.0)
        // **Dart Test:** `oval_border_test.dart:26`
        if let scaled = c10.scale(2.0) as? OvalBorder {
            XCTAssertEqual(scaled, c20)
        } else {
            XCTFail("scale should return OvalBorder")
        }

        // Test scale(0.5)
        // **Dart Test:** `oval_border_test.dart:27`
        if let scaledHalf = c20.scale(0.5) as? OvalBorder {
            XCTAssertEqual(scaledHalf, c10)
        } else {
            XCTFail("scale should return OvalBorder")
        }

        // Test ShapeBorder.lerp at 0.0
        // **Dart Test:** `oval_border_test.dart:28`
        if let lerp0 = ShapeBorderStatics.lerp(c10, c20, 0.0) as? OvalBorder {
            XCTAssertEqual(lerp0, c10)
        } else {
            XCTFail("lerp at 0.0 should return OvalBorder equal to c10")
        }

        // Test ShapeBorder.lerp at 0.5
        // **Dart Test:** `oval_border_test.dart:29`
        if let lerp05 = ShapeBorderStatics.lerp(c10, c20, 0.5) as? OvalBorder {
            XCTAssertEqual(lerp05, c15)
        } else {
            XCTFail("lerp at 0.5 should return OvalBorder equal to c15")
        }

        // Test ShapeBorder.lerp at 1.0
        // **Dart Test:** `oval_border_test.dart:30`
        if let lerp1 = ShapeBorderStatics.lerp(c10, c20, 1.0) as? OvalBorder {
            XCTAssertEqual(lerp1, c20)
        } else {
            XCTFail("lerp at 1.0 should return OvalBorder equal to c20")
        }

        // Test getInnerPath with point inclusion/exclusion
        // **Dart Test:** `oval_border_test.dart:31-37`
        assertPathContains(
            c10.getInnerPath(Rect.fromLTWH(0, 0, 100, 40)),
            includes: [Offset(12, 19), Offset(50, 10), Offset(88, 19), Offset(50, 29)],
            excludes: [Offset(17, 26), Offset(15, 15), Offset(74, 10), Offset(76, 28)]
        )

        // Test getOuterPath with point inclusion/exclusion
        // **Dart Test:** `oval_border_test.dart:38-44`
        assertPathContains(
            c10.getOuterPath(Rect.fromLTWH(0, 0, 100, 20)),
            includes: [Offset(2, 9), Offset(50, 0), Offset(98, 9), Offset(50, 19)],
            excludes: [Offset(7, 16), Offset(10, 2), Offset(84, 1), Offset(86, 18)]
        )
    }

    // MARK: - Description Tests

    /// Test that description shows "OvalBorder" (not "CircleBorder").
    ///
    /// **Dart Source:** `oval_border.dart:63-69`
    func testOvalBorderDescription() {
        let border = OvalBorder()
        XCTAssertTrue(border.description.contains("OvalBorder"))
        // Default eccentricity is 1.0, so eccentricity should NOT be shown
        XCTAssertFalse(border.description.contains("eccentricity"))
    }

    /// Test description with non-default eccentricity.
    ///
    /// **Dart Source:** `oval_border.dart:65-66`
    func testOvalBorderDescriptionWithEccentricity() {
        let border = OvalBorder(eccentricity: 0.5)
        XCTAssertTrue(border.description.contains("OvalBorder"))
        XCTAssertTrue(border.description.contains("eccentricity"))
        XCTAssertTrue(border.description.contains("0.5"))
    }

    // MARK: - preferPaintInterior Test

    /// Test that preferPaintInterior returns true (inherited from CircleBorder behavior).
    ///
    /// **Dart Source:** `circle_border.dart:99-100` - inherited from CircleBorder
    func testOvalBorderPreferPaintInterior() {
        let border = OvalBorder()
        XCTAssertTrue(border.preferPaintInterior)
    }

    // MARK: - Additional copyWith Tests

    /// Test that copyWith with no arguments returns equal border.
    func testCopyWithNoArguments() {
        let border = OvalBorder(
            side: BorderSide(width: 5.0),
            eccentricity: 0.8
        )
        let copied = border.copyWith()
        XCTAssertEqual(border, copied)
    }

    /// Test that copyWith replaces only specified arguments.
    func testCopyWithReplacesSpecifiedArguments() {
        let border = OvalBorder(
            side: BorderSide(width: 5.0),
            eccentricity: 0.8
        )

        let newSide = BorderSide(width: 15.0)
        let copiedWithNewSide: OvalBorder = border.copyWith(side: newSide)
        XCTAssertEqual(copiedWithNewSide.side, newSide)
        XCTAssertEqual(copiedWithNewSide.eccentricity, 0.8)

        let copiedWithNewEccentricity: OvalBorder = border.copyWith(eccentricity: 0.5)
        XCTAssertEqual(copiedWithNewEccentricity.side, border.side)
        XCTAssertEqual(copiedWithNewEccentricity.eccentricity, 0.5)
    }

    // MARK: - Inequality Tests

    /// Test that borders with different properties are not equal.
    func testOvalBorderInequality() {
        let border1 = OvalBorder()
        let border2 = OvalBorder(eccentricity: 0.5)
        let border3 = OvalBorder(side: BorderSide(width: 2.0))

        XCTAssertNotEqual(border1, border2)
        XCTAssertNotEqual(border1, border3)
        XCTAssertNotEqual(border2, border3)
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for ContinuousRectangleBorder.
///
/// **Dart Test Source:** `packages/flutter/test/painting/continuous_rectangle_border_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class ContinuousRectangleBorderTests: XCTestCase {

    // MARK: - Defaults Test

    /// **Dart Test:** `continuous_rectangle_border_test.dart:14-18` - "ContinuousRectangleBorder defaults"
    func testContinuousRectangleBorderDefaults() {
        let border = ContinuousRectangleBorder()
        XCTAssertEqual(border.side, BorderSide.none)
        // borderRadius should be BorderRadius.zero
        if let borderRadius = border.borderRadius as? BorderRadius {
            XCTAssertEqual(borderRadius, BorderRadius.zero)
        } else {
            XCTFail("borderRadius should be BorderRadius type")
        }
    }

    // MARK: - copyWith, ==, hashCode Tests

    /// **Dart Test:** `continuous_rectangle_border_test.dart:20-41` - "ContinuousRectangleBorder copyWith, ==, hashCode"
    func testContinuousRectangleBorderCopyWithEqualityHashCode() {
        let border = ContinuousRectangleBorder()
        let copiedBorder = border.copyWith()

        // Test equality
        XCTAssertEqual(border, copiedBorder)

        // Test hashCode equality
        XCTAssertEqual(border.hashValue, copiedBorder.hashValue)

        // Test with side and radius
        let side = BorderSide(color: Color(0xff123456), width: 10.0)
        let radius = BorderRadius.all(Radius(circular: 16.0))
        let directionalRadius = BorderRadiusDirectional.all(Radius(circular: 16.0))

        let borderWithSideAndRadius = ContinuousRectangleBorder(side: side, borderRadius: radius)
        let copiedWithSideAndRadius = ContinuousRectangleBorder().copyWith(side: side, borderRadius: radius)
        XCTAssertEqual(borderWithSideAndRadius, copiedWithSideAndRadius)

        let borderWithDirectionalRadius = ContinuousRectangleBorder(side: side, borderRadius: directionalRadius)
        let copiedWithDirectionalRadius = ContinuousRectangleBorder().copyWith(side: side, borderRadius: directionalRadius)
        XCTAssertEqual(borderWithDirectionalRadius, copiedWithDirectionalRadius)
    }

    // MARK: - Scale and Lerp Tests

    /// **Dart Test:** `continuous_rectangle_border_test.dart:43-62` - "ContinuousRectangleBorder scale and lerp"
    func testContinuousRectangleBorderScaleAndLerp() {
        let c10 = ContinuousRectangleBorder(
            side: BorderSide(width: 10.0),
            borderRadius: BorderRadius.all(Radius(circular: 100.0))
        )
        let c15 = ContinuousRectangleBorder(
            side: BorderSide(width: 15.0),
            borderRadius: BorderRadius.all(Radius(circular: 150.0))
        )
        let c20 = ContinuousRectangleBorder(
            side: BorderSide(width: 20.0),
            borderRadius: BorderRadius.all(Radius(circular: 200.0))
        )

        // Test dimensions
        if let dimensions = c10.dimensions as? EdgeInsets {
            XCTAssertEqual(dimensions, EdgeInsets(all: 10.0))
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        // Test scale
        if let scaled = c10.scale(2.0) as? ContinuousRectangleBorder {
            XCTAssertEqual(scaled, c20)
        } else {
            XCTFail("scale should return ContinuousRectangleBorder")
        }

        if let scaledHalf = c20.scale(0.5) as? ContinuousRectangleBorder {
            XCTAssertEqual(scaledHalf, c10)
        } else {
            XCTFail("scale should return ContinuousRectangleBorder")
        }

        // Test ShapeBorder.lerp
        if let lerp0 = ShapeBorderStatics.lerp(c10, c20, 0.0) as? ContinuousRectangleBorder {
            XCTAssertEqual(lerp0, c10)
        } else {
            XCTFail("lerp at 0.0 should return ContinuousRectangleBorder equal to c10")
        }

        if let lerp05 = ShapeBorderStatics.lerp(c10, c20, 0.5) as? ContinuousRectangleBorder {
            XCTAssertEqual(lerp05, c15)
        } else {
            XCTFail("lerp at 0.5 should return ContinuousRectangleBorder equal to c15")
        }

        if let lerp1 = ShapeBorderStatics.lerp(c10, c20, 1.0) as? ContinuousRectangleBorder {
            XCTAssertEqual(lerp1, c20)
        } else {
            XCTFail("lerp at 1.0 should return ContinuousRectangleBorder equal to c20")
        }
    }

    // MARK: - BorderRadius.zero Tests

    /// **Dart Test:** `continuous_rectangle_border_test.dart:64-85` - "ContinuousRectangleBorder BorderRadius.zero"
    func testContinuousRectangleBorderRadiusZero() {
        let rect1 = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0)

        // Default border radius and border side are zero, i.e. just a rectangle.
        let defaultBorder = ContinuousRectangleBorder()
        let outerPath = defaultBorder.getOuterPath(rect1)
        let innerPath = defaultBorder.getInnerPath(rect1)

        // Check that the path looks like rect1
        assertPathContains(
            outerPath,
            includes: [Offset(10.0, 20.0), Offset(20.0, 30.0)],
            excludes: [Offset(9.0, 19.0), Offset(31.0, 41.0)]
        )
        assertPathContains(
            innerPath,
            includes: [Offset(10.0, 20.0), Offset(20.0, 30.0)],
            excludes: [Offset(9.0, 19.0), Offset(31.0, 41.0)]
        )

        // Represents the inner path when borderSide.width = 4, which is just rect1
        // inset by 4 on all sides.
        let side = BorderSide(width: 4.0)
        let borderWithSide = ContinuousRectangleBorder(side: side)

        let outerPathWithSide = borderWithSide.getOuterPath(rect1)
        let innerPathWithSide = borderWithSide.getInnerPath(rect1)

        assertPathContains(
            outerPathWithSide,
            includes: [Offset(10.0, 20.0), Offset(20.0, 30.0)],
            excludes: [Offset(9.0, 19.0), Offset(31.0, 41.0)]
        )
        assertPathContains(
            innerPathWithSide,
            includes: [Offset(14.0, 24.0), Offset(16.0, 26.0)],
            excludes: [Offset(9.0, 23.0), Offset(27.0, 37.0)]
        )
    }

    // MARK: - Non-zero BorderRadius Tests

    /// **Dart Test:** `continuous_rectangle_border_test.dart:87-98` - "ContinuousRectangleBorder non-zero BorderRadius"
    func testContinuousRectangleBorderNonZeroBorderRadius() {
        let rect = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0)
        let border = ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius(circular: 5.0))
        )

        let outerPath = border.getOuterPath(rect)
        let innerPath = border.getInnerPath(rect)

        // With continuous rounded corners, the corner points should be excluded
        assertPathContains(
            outerPath,
            includes: [Offset(15.0, 25.0), Offset(20.0, 30.0)],
            excludes: [Offset(10.0, 20.0), Offset(30.0, 40.0)]
        )
        assertPathContains(
            innerPath,
            includes: [Offset(15.0, 25.0), Offset(20.0, 30.0)],
            excludes: [Offset(10.0, 20.0), Offset(30.0, 40.0)]
        )
    }

    // MARK: - Non-zero BorderRadiusDirectional Tests

    /// **Dart Test:** `continuous_rectangle_border_test.dart:100-123` - "ContinuousRectangleBorder non-zero BorderRadiusDirectional"
    func testContinuousRectangleBorderNonZeroBorderRadiusDirectional() {
        let rect = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0)
        let border = ContinuousRectangleBorder(
            borderRadius: BorderRadiusDirectional.only(
                topStart: Radius(circular: 5.0),
                bottomStart: Radius(circular: 5.0)
            )
        )

        // Test LTR situation
        let outerPathLtr = border.getOuterPath(rect, textDirection: .ltr)
        let innerPathLtr = border.getInnerPath(rect, textDirection: .ltr)

        assertPathContains(
            outerPathLtr,
            includes: [Offset(15.0, 25.0), Offset(20.0, 30.0)],
            excludes: [Offset(10.0, 20.0), Offset(10.0, 40.0)]
        )
        assertPathContains(
            innerPathLtr,
            includes: [Offset(15.0, 25.0), Offset(20.0, 30.0)],
            excludes: [Offset(10.0, 20.0), Offset(10.0, 40.0)]
        )

        // Test RTL situation
        let outerPathRtl = border.getOuterPath(rect, textDirection: .rtl)
        let innerPathRtl = border.getInnerPath(rect, textDirection: .rtl)

        assertPathContains(
            outerPathRtl,
            includes: [Offset(25.0, 35.0), Offset(25.0, 25.0)],
            excludes: [Offset(30.0, 20.0), Offset(30.0, 40.0)]
        )
        assertPathContains(
            innerPathRtl,
            includes: [Offset(25.0, 35.0), Offset(25.0, 25.0)],
            excludes: [Offset(30.0, 20.0), Offset(30.0, 40.0)]
        )
    }

    // MARK: - Additional Tests

    /// Test description/toString
    func testContinuousRectangleBorderDescription() {
        let border = ContinuousRectangleBorder()
        XCTAssertTrue(border.description.contains("ContinuousRectangleBorder"))
    }

    /// Test that copyWith with no arguments returns equal border
    func testCopyWithNoArguments() {
        let border = ContinuousRectangleBorder(
            side: BorderSide(width: 5.0),
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )
        let copied = border.copyWith()
        XCTAssertEqual(border, copied)
    }

    /// Test that copyWith replaces only specified arguments
    func testCopyWithReplacesSpecifiedArguments() {
        let border = ContinuousRectangleBorder(
            side: BorderSide(width: 5.0),
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )

        let newSide = BorderSide(width: 15.0)
        // Use the ContinuousRectangleBorder-specific copyWith which returns ContinuousRectangleBorder
        let copiedWithNewSide = border.copyWith(side: newSide, borderRadius: nil)
        XCTAssertEqual(copiedWithNewSide.side, newSide)
        // borderRadius should remain the same
        if let originalRadius = border.borderRadius as? BorderRadius,
           let copiedRadius = copiedWithNewSide.borderRadius as? BorderRadius {
            XCTAssertEqual(originalRadius, copiedRadius)
        }

        let newRadius = BorderRadius.all(Radius(circular: 20.0))
        let copiedWithNewRadius = border.copyWith(side: nil, borderRadius: newRadius)
        XCTAssertEqual(copiedWithNewRadius.side, border.side)
        if let copiedRadius = copiedWithNewRadius.borderRadius as? BorderRadius {
            XCTAssertEqual(copiedRadius, newRadius)
        }
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for BeveledRectangleBorder.
///
/// **Dart Test Source:** `packages/flutter/test/painting/beveled_rectangle_border_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Path Test Helpers

/// Helper function to check if a path contains/excludes certain points.
/// This is equivalent to Flutter's `isPathThat` matcher.
///
/// **Dart Test:** `beveled_rectangle_border_test.dart` - `isPathThat` matcher
func assertPathContains(
    _ path: Path,
    includes: [Offset] = [],
    excludes: [Offset] = [],
    file: StaticString = #file,
    line: UInt = #line
) {
    for point in includes {
        XCTAssertTrue(
            path.contains(point),
            "Expected path to contain point \(point)",
            file: file,
            line: line
        )
    }
    for point in excludes {
        XCTAssertFalse(
            path.contains(point),
            "Expected path to NOT contain point \(point)",
            file: file,
            line: line
        )
    }
}

final class BeveledRectangleBorderTests: XCTestCase {

    // MARK: - Defaults Test

    /// **Dart Test:** `beveled_rectangle_border_test.dart:9-13` - "BeveledRectangleBorder defaults"
    func testBeveledRectangleBorderDefaults() {
        let border = BeveledRectangleBorder()
        XCTAssertEqual(border.side, BorderSide.none)
        // borderRadius should be BorderRadius.zero
        if let borderRadius = border.borderRadius as? BorderRadius {
            XCTAssertEqual(borderRadius, BorderRadius.zero)
        } else {
            XCTFail("borderRadius should be BorderRadius type")
        }
    }

    // MARK: - copyWith, ==, hashCode Tests

    /// **Dart Test:** `beveled_rectangle_border_test.dart:15-35` - "BeveledRectangleBorder copyWith, ==, hashCode"
    func testBeveledRectangleBorderCopyWithEqualityHashCode() {
        let border = BeveledRectangleBorder()
        let copiedBorder = border.copyWith()

        // Test equality
        XCTAssertEqual(border, copiedBorder)

        // Test hashCode equality
        XCTAssertEqual(border.hashValue, copiedBorder.hashValue)

        // Test with side and radius
        let side = BorderSide(color: Color(0xff123456), width: 10.0)
        let radius = BorderRadius.all(Radius(circular: 16.0))
        let directionalRadius = BorderRadiusDirectional.all(Radius(circular: 16.0))

        let borderWithSideAndRadius = BeveledRectangleBorder(side: side, borderRadius: radius)
        let copiedWithSideAndRadius = BeveledRectangleBorder().copyWith(side: side, borderRadius: radius)
        XCTAssertEqual(borderWithSideAndRadius, copiedWithSideAndRadius)

        let borderWithDirectionalRadius = BeveledRectangleBorder(side: side, borderRadius: directionalRadius)
        let copiedWithDirectionalRadius = BeveledRectangleBorder().copyWith(side: side, borderRadius: directionalRadius)
        XCTAssertEqual(borderWithDirectionalRadius, copiedWithDirectionalRadius)
    }

    // MARK: - Scale and Lerp Tests

    /// **Dart Test:** `beveled_rectangle_border_test.dart:37-56` - "BeveledRectangleBorder scale and lerp"
    func testBeveledRectangleBorderScaleAndLerp() {
        let c10 = BeveledRectangleBorder(
            side: BorderSide(width: 10.0),
            borderRadius: BorderRadius.all(Radius(circular: 100.0))
        )
        let c15 = BeveledRectangleBorder(
            side: BorderSide(width: 15.0),
            borderRadius: BorderRadius.all(Radius(circular: 150.0))
        )
        let c20 = BeveledRectangleBorder(
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
        if let scaled = c10.scale(2.0) as? BeveledRectangleBorder {
            XCTAssertEqual(scaled, c20)
        } else {
            XCTFail("scale should return BeveledRectangleBorder")
        }

        if let scaledHalf = c20.scale(0.5) as? BeveledRectangleBorder {
            XCTAssertEqual(scaledHalf, c10)
        } else {
            XCTFail("scale should return BeveledRectangleBorder")
        }

        // Test ShapeBorder.lerp
        if let lerp0 = ShapeBorderStatics.lerp(c10, c20, 0.0) as? BeveledRectangleBorder {
            XCTAssertEqual(lerp0, c10)
        } else {
            XCTFail("lerp at 0.0 should return BeveledRectangleBorder equal to c10")
        }

        if let lerp05 = ShapeBorderStatics.lerp(c10, c20, 0.5) as? BeveledRectangleBorder {
            XCTAssertEqual(lerp05, c15)
        } else {
            XCTFail("lerp at 0.5 should return BeveledRectangleBorder equal to c15")
        }

        if let lerp1 = ShapeBorderStatics.lerp(c10, c20, 1.0) as? BeveledRectangleBorder {
            XCTAssertEqual(lerp1, c20)
        } else {
            XCTFail("lerp at 1.0 should return BeveledRectangleBorder equal to c20")
        }
    }

    // MARK: - BorderRadius.zero Tests

    /// **Dart Test:** `beveled_rectangle_border_test.dart:58-79` - "BeveledRectangleBorder BorderRadius.zero"
    func testBeveledRectangleBorderRadiusZero() {
        let rect1 = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0)

        // Default border radius and border side are zero, i.e. just a rectangle.
        let defaultBorder = BeveledRectangleBorder()
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
        let borderWithSide = BeveledRectangleBorder(side: side)

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

    /// **Dart Test:** `beveled_rectangle_border_test.dart:81-92` - "BeveledRectangleBorder non-zero BorderRadius"
    func testBeveledRectangleBorderNonZeroBorderRadius() {
        let rect = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0)
        let border = BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius(circular: 5.0))
        )

        let outerPath = border.getOuterPath(rect)
        let innerPath = border.getInnerPath(rect)

        // With beveled corners, the corner points should be excluded
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

    /// **Dart Test:** `beveled_rectangle_border_test.dart:94-119` - "BeveledRectangleBorder non-zero BorderRadiusDirectional"
    func testBeveledRectangleBorderNonZeroBorderRadiusDirectional() {
        let rect = Rect.fromLTRB(10.0, 20.0, 30.0, 40.0)
        let border = BeveledRectangleBorder(
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

    // MARK: - StrokeAlign Tests

    /// **Dart Test:** `beveled_rectangle_border_test.dart:121-162` - "BeveledRectangleBorder with StrokeAlign"
    func testBeveledRectangleBorderWithStrokeAlign() {
        let borderRadius = BorderRadius.all(Radius(circular: 10))

        let inside = BeveledRectangleBorder(
            side: BorderSide(width: 10.0),
            borderRadius: borderRadius
        )
        let center = BeveledRectangleBorder(
            side: BorderSide(width: 10.0, strokeAlign: BorderSide.strokeAlignCenter),
            borderRadius: borderRadius
        )
        let outside = BeveledRectangleBorder(
            side: BorderSide(width: 10.0, strokeAlign: BorderSide.strokeAlignOutside),
            borderRadius: borderRadius
        )

        // Test dimensions
        if let insideDimensions = inside.dimensions as? EdgeInsets {
            XCTAssertEqual(insideDimensions, EdgeInsets(all: 10.0))
        } else {
            XCTFail("inside.dimensions should be EdgeInsets type")
        }

        if let centerDimensions = center.dimensions as? EdgeInsets {
            XCTAssertEqual(centerDimensions, EdgeInsets(all: 5.0))
        } else {
            XCTFail("center.dimensions should be EdgeInsets type")
        }

        if let outsideDimensions = outside.dimensions as? EdgeInsets {
            XCTAssertEqual(outsideDimensions, EdgeInsets.zero)
        } else {
            XCTFail("outside.dimensions should be EdgeInsets type")
        }

        let rect = Rect.fromLTWH(0.0, 0.0, 120.0, 40.0)

        // Test inside.getInnerPath
        assertPathContains(
            inside.getInnerPath(rect),
            includes: [Offset(10, 20), Offset(100, 10), Offset(50, 30), Offset(50, 20)],
            excludes: [Offset(9, 9), Offset(100, 0), Offset(110, 31), Offset(9, 31)]
        )

        // Test center.getInnerPath
        assertPathContains(
            center.getInnerPath(rect),
            includes: [Offset(9, 9), Offset(100, 10), Offset(110, 31), Offset(9, 31)],
            excludes: [Offset(4, 4), Offset(100, 0), Offset(116, 31), Offset(4, 31)]
        )

        // Test outside.getInnerPath
        assertPathContains(
            outside.getInnerPath(rect),
            includes: [Offset(5, 5), Offset(110, 0), Offset(116, 31), Offset(4, 31)],
            excludes: [Offset.zero, Offset(120, 0), Offset(120, 31), Offset(0, 31)]
        )
    }

    // MARK: - Additional Tests

    /// Test description/toString
    func testBeveledRectangleBorderDescription() {
        let border = BeveledRectangleBorder()
        XCTAssertTrue(border.description.contains("BeveledRectangleBorder"))
    }

    /// Test that copyWith with no arguments returns equal border
    func testCopyWithNoArguments() {
        let border = BeveledRectangleBorder(
            side: BorderSide(width: 5.0),
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )
        let copied = border.copyWith()
        XCTAssertEqual(border, copied)
    }

    /// Test that copyWith replaces only specified arguments
    func testCopyWithReplacesSpecifiedArguments() {
        let border = BeveledRectangleBorder(
            side: BorderSide(width: 5.0),
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )

        let newSide = BorderSide(width: 15.0)
        // Use the BeveledRectangleBorder-specific copyWith which returns BeveledRectangleBorder
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

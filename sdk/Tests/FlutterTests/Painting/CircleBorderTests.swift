// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for CircleBorder.
///
/// **Dart Test Source:** `packages/flutter/test/painting/circle_border_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class CircleBorderTests: XCTestCase {

    // MARK: - Defaults Test

    /// **Dart Test:** `circle_border_test.dart:11-15` - "CircleBorder defaults"
    func testCircleBorderDefaults() {
        let border = CircleBorder()
        XCTAssertEqual(border.side, BorderSide.none)
        XCTAssertEqual(border.eccentricity, 0.0)
    }

    // MARK: - getInnerPath and getOuterPath Tests

    /// **Dart Test:** `circle_border_test.dart:17-31` - "CircleBorder getInnerPath and getOuterPath"
    func testCircleBorderGetInnerPathAndGetOuterPath() {
        // A 200x100 rect should produce a 100x100 circle rect centered at (100, 50)
        // which is Rect.fromLTWH(50, 0, 100, 100)
        let circleRect = Rect.fromLTWH(50, 0, 100, 100)
        let rect = Rect.fromLTWH(0, 0, 200, 100)

        // Default CircleBorder (eccentricity = 0.0) produces a circle
        let defaultBorder = CircleBorder()
        XCTAssertEqual(defaultBorder.getInnerPath(rect).getBounds(), circleRect)
        XCTAssertEqual(defaultBorder.getOuterPath(rect).getBounds(), circleRect)

        // Eccentricity 1.0 produces an oval filling the entire rect
        let oval = CircleBorder(eccentricity: 1.0)
        XCTAssertEqual(oval.getOuterPath(rect).getBounds(), rect)
        XCTAssertEqual(oval.getInnerPath(rect).getBounds(), rect)

        // With border side width 10, eccentricity 1.0
        let o10 = CircleBorder(side: BorderSide(width: 10.0), eccentricity: 1.0)
        // Outer path should be the full rect
        let outerBounds = o10.getOuterPath(rect).getBounds()
        let expectedOuter = Rect.fromLTWH(0, 0, 200, 100)
        XCTAssertEqual(outerBounds.left, expectedOuter.left, accuracy: 1e-10)
        XCTAssertEqual(outerBounds.top, expectedOuter.top, accuracy: 1e-10)
        XCTAssertEqual(outerBounds.right, expectedOuter.right, accuracy: 1e-10)
        XCTAssertEqual(outerBounds.bottom, expectedOuter.bottom, accuracy: 1e-10)

        // Inner path should be inset by strokeInset (10.0 for default strokeAlign)
        let innerBounds = o10.getInnerPath(rect).getBounds()
        let expectedInner = Rect.fromLTWH(10, 10, 180, 80)
        XCTAssertEqual(innerBounds.left, expectedInner.left, accuracy: 1e-10)
        XCTAssertEqual(innerBounds.top, expectedInner.top, accuracy: 1e-10)
        XCTAssertEqual(innerBounds.right, expectedInner.right, accuracy: 1e-10)
        XCTAssertEqual(innerBounds.bottom, expectedInner.bottom, accuracy: 1e-10)
    }

    // MARK: - copyWith, ==, hashCode Tests

    /// **Dart Test:** `circle_border_test.dart:33-42` - "CircleBorder copyWith, ==, hashCode"
    func testCircleBorderCopyWithEqualityHashCode() {
        let border = CircleBorder()
        let copiedBorder = border.copyWith()

        // Test equality
        XCTAssertEqual(border, copiedBorder)

        // Test hashCode equality
        XCTAssertEqual(border.hashValue, copiedBorder.hashValue)

        // Test eccentricity copyWith
        let eccBorder = CircleBorder(eccentricity: 0.5)
        let copiedEcc = CircleBorder().copyWith(eccentricity: 0.5)
        XCTAssertEqual(eccBorder.hashValue, copiedEcc.hashValue)

        // Test side copyWith
        let side = BorderSide(color: Color(0xff123456), width: 10.0)
        let borderWithSide: CircleBorder = CircleBorder().copyWith(side: side)
        let expectedBorder = CircleBorder(side: side)
        XCTAssertEqual(borderWithSide, expectedBorder)
    }

    // MARK: - Scale, Lerp, Dimensions, Paint Tests

    /// **Dart Test:** `circle_border_test.dart:44-63` - "CircleBorder"
    func testCircleBorderScaleLerpDimensionsPaint() {
        let c10 = CircleBorder(side: BorderSide(width: 10.0))
        let c15 = CircleBorder(side: BorderSide(width: 15.0))
        let c20 = CircleBorder(side: BorderSide(width: 20.0))

        // Test dimensions
        if let dimensions = c10.dimensions as? EdgeInsets {
            XCTAssertEqual(dimensions, EdgeInsets(all: 10.0))
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        // Test scale
        if let scaled = c10.scale(2.0) as? CircleBorder {
            XCTAssertEqual(scaled, c20)
        } else {
            XCTFail("scale should return CircleBorder")
        }

        if let scaledHalf = c20.scale(0.5) as? CircleBorder {
            XCTAssertEqual(scaledHalf, c10)
        } else {
            XCTFail("scale should return CircleBorder")
        }

        // Test ShapeBorder.lerp
        if let lerp0 = ShapeBorderStatics.lerp(c10, c20, 0.0) as? CircleBorder {
            XCTAssertEqual(lerp0, c10)
        } else {
            XCTFail("lerp at 0.0 should return CircleBorder equal to c10")
        }

        if let lerp05 = ShapeBorderStatics.lerp(c10, c20, 0.5) as? CircleBorder {
            XCTAssertEqual(lerp05, c15)
        } else {
            XCTFail("lerp at 0.5 should return CircleBorder equal to c15")
        }

        if let lerp1 = ShapeBorderStatics.lerp(c10, c20, 1.0) as? CircleBorder {
            XCTAssertEqual(lerp1, c20)
        } else {
            XCTFail("lerp at 1.0 should return CircleBorder equal to c20")
        }

        // Test getInnerPath produces unit circle when given appropriate rect
        // c10 has side width 10, so innerPath deflates by strokeInset (10.0).
        // Rect.fromCircle(center: .zero, radius: 1.0).inflate(10.0) gives a rect
        // centered at origin with radius 11.0. After deflating by 10.0, the oval
        // should be the unit circle.
        let unitCircleRect = Rect.fromCircle(center: Offset.zero, radius: 1.0)
        let inflatedRect = unitCircleRect.inflate(10.0)
        let innerPath = c10.getInnerPath(inflatedRect)
        let innerBounds = innerPath.getBounds()
        // The inner path should approximate a unit circle: bounds ~ (-1, -1, 1, 1)
        XCTAssertEqual(innerBounds.left, -1.0, accuracy: 1e-10)
        XCTAssertEqual(innerBounds.top, -1.0, accuracy: 1e-10)
        XCTAssertEqual(innerBounds.right, 1.0, accuracy: 1e-10)
        XCTAssertEqual(innerBounds.bottom, 1.0, accuracy: 1e-10)

        // Test getOuterPath produces unit circle
        let outerPath = c10.getOuterPath(unitCircleRect)
        let outerBounds = outerPath.getBounds()
        XCTAssertEqual(outerBounds.left, -1.0, accuracy: 1e-10)
        XCTAssertEqual(outerBounds.top, -1.0, accuracy: 1e-10)
        XCTAssertEqual(outerBounds.right, 1.0, accuracy: 1e-10)
        XCTAssertEqual(outerBounds.bottom, 1.0, accuracy: 1e-10)
    }

    // MARK: - Eccentricity Lerp Tests

    /// Test that eccentricity is properly interpolated during lerp.
    func testCircleBorderEccentricityLerp() {
        let c0 = CircleBorder(eccentricity: 0.0)
        let c1 = CircleBorder(eccentricity: 1.0)

        if let lerp05 = ShapeBorderStatics.lerp(c0, c1, 0.5) as? CircleBorder {
            XCTAssertEqual(lerp05.eccentricity, 0.5, accuracy: 1e-10)
        } else {
            XCTFail("lerp should return CircleBorder")
        }

        if let lerp0 = ShapeBorderStatics.lerp(c0, c1, 0.0) as? CircleBorder {
            XCTAssertEqual(lerp0.eccentricity, 0.0, accuracy: 1e-10)
        } else {
            XCTFail("lerp should return CircleBorder")
        }

        if let lerp1 = ShapeBorderStatics.lerp(c0, c1, 1.0) as? CircleBorder {
            XCTAssertEqual(lerp1.eccentricity, 1.0, accuracy: 1e-10)
        } else {
            XCTFail("lerp should return CircleBorder")
        }
    }

    // MARK: - Description Tests

    /// Test description/toString
    func testCircleBorderDescription() {
        let border = CircleBorder()
        XCTAssertTrue(border.description.contains("CircleBorder"))
    }

    /// Test description with eccentricity
    ///
    /// **Dart Source:** `circle_border.dart:151-156`
    func testCircleBorderDescriptionWithEccentricity() {
        let border = CircleBorder(eccentricity: 0.5)
        XCTAssertTrue(border.description.contains("CircleBorder"))
        XCTAssertTrue(border.description.contains("eccentricity"))
        XCTAssertTrue(border.description.contains("0.5"))
    }

    // MARK: - preferPaintInterior Test

    /// Test that preferPaintInterior returns true.
    ///
    /// **Dart Source:** `circle_border.dart:99-100`
    func testCircleBorderPreferPaintInterior() {
        let border = CircleBorder()
        XCTAssertTrue(border.preferPaintInterior)
    }

    // MARK: - copyWith Tests

    /// Test that copyWith with no arguments returns equal border
    func testCopyWithNoArguments() {
        let border = CircleBorder(
            side: BorderSide(width: 5.0),
            eccentricity: 0.5
        )
        let copied = border.copyWith()
        XCTAssertEqual(border, copied)
    }

    /// Test that copyWith replaces only specified arguments
    func testCopyWithReplacesSpecifiedArguments() {
        let border = CircleBorder(
            side: BorderSide(width: 5.0),
            eccentricity: 0.5
        )

        let newSide = BorderSide(width: 15.0)
        let copiedWithNewSide: CircleBorder = border.copyWith(side: newSide)
        XCTAssertEqual(copiedWithNewSide.side, newSide)
        XCTAssertEqual(copiedWithNewSide.eccentricity, 0.5)

        let copiedWithNewEccentricity: CircleBorder = border.copyWith(eccentricity: 0.8)
        XCTAssertEqual(copiedWithNewEccentricity.side, border.side)
        XCTAssertEqual(copiedWithNewEccentricity.eccentricity, 0.8)
    }

    // MARK: - Inequality Tests

    /// Test that borders with different properties are not equal
    func testCircleBorderInequality() {
        let border1 = CircleBorder()
        let border2 = CircleBorder(eccentricity: 0.5)
        let border3 = CircleBorder(side: BorderSide(width: 2.0))

        XCTAssertNotEqual(border1, border2)
        XCTAssertNotEqual(border1, border3)
        XCTAssertNotEqual(border2, border3)
    }

    // MARK: - Adjust Rect Tests

    /// Test that getOuterPath correctly adjusts for eccentricity on tall rects
    func testCircleBorderAdjustRectTallRect() {
        // A tall rect: 100 wide, 200 tall
        let rect = Rect.fromLTWH(0, 0, 100, 200)

        // eccentricity 0.0: should produce a 100x100 square centered in the rect
        let circle = CircleBorder(eccentricity: 0.0)
        let circleBounds = circle.getOuterPath(rect).getBounds()
        XCTAssertEqual(circleBounds.left, 0.0, accuracy: 1e-10)
        XCTAssertEqual(circleBounds.top, 50.0, accuracy: 1e-10)
        XCTAssertEqual(circleBounds.right, 100.0, accuracy: 1e-10)
        XCTAssertEqual(circleBounds.bottom, 150.0, accuracy: 1e-10)

        // eccentricity 1.0: should fill the entire rect
        let oval = CircleBorder(eccentricity: 1.0)
        let ovalBounds = oval.getOuterPath(rect).getBounds()
        XCTAssertEqual(ovalBounds.left, 0.0, accuracy: 1e-10)
        XCTAssertEqual(ovalBounds.top, 0.0, accuracy: 1e-10)
        XCTAssertEqual(ovalBounds.right, 100.0, accuracy: 1e-10)
        XCTAssertEqual(ovalBounds.bottom, 200.0, accuracy: 1e-10)

        // eccentricity 0.5: should be halfway between circle and full rect
        let half = CircleBorder(eccentricity: 0.5)
        let halfBounds = half.getOuterPath(rect).getBounds()
        XCTAssertEqual(halfBounds.left, 0.0, accuracy: 1e-10)
        XCTAssertEqual(halfBounds.top, 25.0, accuracy: 1e-10)
        XCTAssertEqual(halfBounds.right, 100.0, accuracy: 1e-10)
        XCTAssertEqual(halfBounds.bottom, 175.0, accuracy: 1e-10)
    }

    /// Test that getOuterPath correctly adjusts for eccentricity on wide rects
    func testCircleBorderAdjustRectWideRect() {
        // A wide rect: 200 wide, 100 tall
        let rect = Rect.fromLTWH(0, 0, 200, 100)

        // eccentricity 0.0: should produce a 100x100 square centered in the rect
        let circle = CircleBorder(eccentricity: 0.0)
        let circleBounds = circle.getOuterPath(rect).getBounds()
        XCTAssertEqual(circleBounds.left, 50.0, accuracy: 1e-10)
        XCTAssertEqual(circleBounds.top, 0.0, accuracy: 1e-10)
        XCTAssertEqual(circleBounds.right, 150.0, accuracy: 1e-10)
        XCTAssertEqual(circleBounds.bottom, 100.0, accuracy: 1e-10)

        // eccentricity 1.0: should fill the entire rect
        let oval = CircleBorder(eccentricity: 1.0)
        let ovalBounds = oval.getOuterPath(rect).getBounds()
        XCTAssertEqual(ovalBounds.left, 0.0, accuracy: 1e-10)
        XCTAssertEqual(ovalBounds.top, 0.0, accuracy: 1e-10)
        XCTAssertEqual(ovalBounds.right, 200.0, accuracy: 1e-10)
        XCTAssertEqual(ovalBounds.bottom, 100.0, accuracy: 1e-10)
    }

    /// Test that a square rect with eccentricity 0.0 produces the same bounds
    func testCircleBorderSquareRect() {
        let rect = Rect.fromLTWH(10, 20, 100, 100)

        let circle = CircleBorder(eccentricity: 0.0)
        let bounds = circle.getOuterPath(rect).getBounds()
        XCTAssertEqual(bounds.left, 10.0, accuracy: 1e-10)
        XCTAssertEqual(bounds.top, 20.0, accuracy: 1e-10)
        XCTAssertEqual(bounds.right, 110.0, accuracy: 1e-10)
        XCTAssertEqual(bounds.bottom, 120.0, accuracy: 1e-10)
    }

    // MARK: - StrokeAlign Dimensions Tests

    /// Test dimensions with different stroke alignments
    func testCircleBorderStrokeAlignDimensions() {
        let inside = CircleBorder(side: BorderSide(width: 10.0))
        let center = CircleBorder(
            side: BorderSide(width: 10.0, strokeAlign: BorderSide.strokeAlignCenter)
        )
        let outside = CircleBorder(
            side: BorderSide(width: 10.0, strokeAlign: BorderSide.strokeAlignOutside)
        )

        if let insideDim = inside.dimensions as? EdgeInsets {
            XCTAssertEqual(insideDim, EdgeInsets(all: 10.0))
        } else {
            XCTFail("inside.dimensions should be EdgeInsets type")
        }

        if let centerDim = center.dimensions as? EdgeInsets {
            XCTAssertEqual(centerDim, EdgeInsets(all: 5.0))
        } else {
            XCTFail("center.dimensions should be EdgeInsets type")
        }

        if let outsideDim = outside.dimensions as? EdgeInsets {
            XCTAssertEqual(outsideDim, EdgeInsets.zero)
        } else {
            XCTFail("outside.dimensions should be EdgeInsets type")
        }
    }
}

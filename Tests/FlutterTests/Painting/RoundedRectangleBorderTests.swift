// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for RoundedRectangleBorder.
///
/// **Dart Test Source:** `packages/flutter/test/painting/rounded_rectangle_border_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class RoundedRectangleBorderTests: XCTestCase {

    // MARK: - Defaults Test

    /// **Dart Test:** `rounded_rectangle_border_test.dart:11-15` - "RoundedRectangleBorder defaults"
    func testRoundedRectangleBorderDefaults() {
        let border = RoundedRectangleBorder()
        XCTAssertEqual(border.side, BorderSide.none)
        if let borderRadius = border.borderRadius as? BorderRadius {
            XCTAssertEqual(borderRadius, BorderRadius.zero)
        } else {
            XCTFail("borderRadius should be BorderRadius type")
        }
    }

    // MARK: - copyWith, ==, hashCode Tests

    /// **Dart Test:** `rounded_rectangle_border_test.dart:17-38` - "RoundedRectangleBorder copyWith, ==, hashCode"
    func testRoundedRectangleBorderCopyWithEqualityHashCode() {
        let border = RoundedRectangleBorder()
        let copiedBorder = border.copyWith()

        // Test equality
        XCTAssertEqual(border, copiedBorder)

        // Test hashCode equality
        XCTAssertEqual(border.hashValue, copiedBorder.hashValue)

        // Test with side and radius
        let side = BorderSide(color: Color(0xff123456), width: 10.0)
        let radius = BorderRadius.all(Radius(circular: 16.0))
        let directionalRadius = BorderRadiusDirectional.all(Radius(circular: 16.0))

        let borderWithSideAndRadius = RoundedRectangleBorder(side: side, borderRadius: radius)
        let copiedWithSideAndRadius = RoundedRectangleBorder().copyWith(side: side, borderRadius: radius)
        XCTAssertEqual(borderWithSideAndRadius, copiedWithSideAndRadius)

        let borderWithDirectionalRadius = RoundedRectangleBorder(side: side, borderRadius: directionalRadius)
        let copiedWithDirectionalRadius = RoundedRectangleBorder().copyWith(side: side, borderRadius: directionalRadius)
        XCTAssertEqual(borderWithDirectionalRadius, copiedWithDirectionalRadius)
    }

    // MARK: - Scale, Lerp, Path Tests

    /// **Dart Test:** `rounded_rectangle_border_test.dart:40-84` - "RoundedRectangleBorder"
    func testRoundedRectangleBorderScaleLerpPath() {
        let c10 = RoundedRectangleBorder(
            side: BorderSide(width: 10.0),
            borderRadius: BorderRadius.all(Radius(circular: 100.0))
        )
        let c15 = RoundedRectangleBorder(
            side: BorderSide(width: 15.0),
            borderRadius: BorderRadius.all(Radius(circular: 150.0))
        )
        let c20 = RoundedRectangleBorder(
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
        if let scaled = c10.scale(2.0) as? RoundedRectangleBorder {
            XCTAssertEqual(scaled, c20)
        } else {
            XCTFail("scale should return RoundedRectangleBorder")
        }

        if let scaledHalf = c20.scale(0.5) as? RoundedRectangleBorder {
            XCTAssertEqual(scaledHalf, c10)
        } else {
            XCTFail("scale should return RoundedRectangleBorder")
        }

        // Test ShapeBorder.lerp
        if let lerp0 = ShapeBorderStatics.lerp(c10, c20, 0.0) as? RoundedRectangleBorder {
            XCTAssertEqual(lerp0, c10)
        } else {
            XCTFail("lerp at 0.0 should return RoundedRectangleBorder equal to c10")
        }

        if let lerp05 = ShapeBorderStatics.lerp(c10, c20, 0.5) as? RoundedRectangleBorder {
            XCTAssertEqual(lerp05, c15)
        } else {
            XCTFail("lerp at 0.5 should return RoundedRectangleBorder equal to c15")
        }

        if let lerp1 = ShapeBorderStatics.lerp(c10, c20, 1.0) as? RoundedRectangleBorder {
            XCTAssertEqual(lerp1, c20)
        } else {
            XCTFail("lerp at 1.0 should return RoundedRectangleBorder equal to c20")
        }

        // Test getInnerPath produces unit circle
        // c2 has side width 1, borderRadius 2.0, so inner path of
        // Rect.fromCircle(center: .zero, radius: 2.0) deflated by 1.0 (strokeInset)
        // gives the unit circle.
        let c2 = RoundedRectangleBorder(
            side: BorderSide(),
            borderRadius: BorderRadius.all(Radius(circular: 2.0))
        )
        let innerPath = c2.getInnerPath(Rect.fromCircle(center: Offset.zero, radius: 2.0))
        let innerBounds = innerPath.getBounds()
        XCTAssertEqual(innerBounds.left, -1.0, accuracy: 1e-6)
        XCTAssertEqual(innerBounds.top, -1.0, accuracy: 1e-6)
        XCTAssertEqual(innerBounds.right, 1.0, accuracy: 1e-6)
        XCTAssertEqual(innerBounds.bottom, 1.0, accuracy: 1e-6)

        // Test getOuterPath produces unit circle
        let c1 = RoundedRectangleBorder(
            side: BorderSide(),
            borderRadius: BorderRadius.all(Radius(circular: 1.0))
        )
        let outerPath = c1.getOuterPath(Rect.fromCircle(center: Offset.zero, radius: 1.0))
        let outerBounds = outerPath.getBounds()
        XCTAssertEqual(outerBounds.left, -1.0, accuracy: 1e-6)
        XCTAssertEqual(outerBounds.top, -1.0, accuracy: 1e-6)
        XCTAssertEqual(outerBounds.right, 1.0, accuracy: 1e-6)
        XCTAssertEqual(outerBounds.bottom, 1.0, accuracy: 1e-6)

        // Test directional border radius lerp
        let directional = RoundedRectangleBorder(
            borderRadius: BorderRadiusDirectional.only(topStart: Radius(circular: 20))
        )
        let lerpDirectionalTo = ShapeBorderStatics.lerp(directional, c10, 1.0)
        let lerpDirectionalFrom = ShapeBorderStatics.lerp(c10, directional, 0.0)
        // Both should equal c10 at those t values
        if let result1 = lerpDirectionalTo as? RoundedRectangleBorder,
           let result2 = lerpDirectionalFrom as? RoundedRectangleBorder {
            XCTAssertEqual(result1, result2)
        } else {
            XCTFail("lerp should return RoundedRectangleBorder")
        }
    }

    // MARK: - RoundedRectangleBorder and CircleBorder Lerp Tests

    /// **Dart Test:** `rounded_rectangle_border_test.dart:86-167` - "RoundedRectangleBorder and CircleBorder"
    func testRoundedRectangleBorderAndCircleBorderLerp() {
        let r = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )
        let c = CircleBorder()
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 20.0) // center is x=40..60 y=10

        // "looksLikeR" - points that should be in the rounded rect but not in a circle
        let looksLikeRIncludes: [Offset] = [Offset(30.0, 10.0), Offset(50.0, 10.0)]
        let looksLikeRExcludes: [Offset] = [Offset(1.0, 1.0), Offset(99.0, 19.0)]

        // "looksLikeC" - points that should be in a circle
        let looksLikeCIncludes: [Offset] = [Offset(50.0, 10.0)]
        let looksLikeCExcludes: [Offset] = [Offset(1.0, 1.0), Offset(30.0, 10.0), Offset(99.0, 19.0)]

        // Test r.getOuterPath looks like R
        assertPathContains(
            r.getOuterPath(rect),
            includes: looksLikeRIncludes,
            excludes: looksLikeRExcludes
        )

        // Test c.getOuterPath looks like C
        assertPathContains(
            c.getOuterPath(rect),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(r, c, 0.1) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(r, c, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes,
            excludes: looksLikeRExcludes
        )

        // Test lerp(r, c, 0.9) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(r, c, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(lerp(r, c, 0.9), r, 0.1) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(r, c, 0.9), r, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(lerp(r, c, 0.9), r, 0.9) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(r, c, 0.9), r, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes,
            excludes: looksLikeRExcludes
        )

        // Test lerp(lerp(r, c, 0.1), c, 0.1) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(r, c, 0.1), c, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes,
            excludes: looksLikeRExcludes
        )

        // Test lerp(lerp(r, c, 0.1), c, 0.9) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(r, c, 0.1), c, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(lerp(r, c, 0.1), lerp(r, c, 0.9), 0.1) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(r, c, 0.1),
                ShapeBorderStatics.lerp(r, c, 0.9),
                0.1
            )!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes,
            excludes: looksLikeRExcludes
        )

        // Test lerp(lerp(r, c, 0.1), lerp(r, c, 0.9), 0.9) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(r, c, 0.1),
                ShapeBorderStatics.lerp(r, c, 0.9),
                0.9
            )!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(r, lerp(r, c, 0.9), 0.1) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(r, ShapeBorderStatics.lerp(r, c, 0.9), 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes,
            excludes: looksLikeRExcludes
        )

        // Test lerp(r, lerp(r, c, 0.9), 0.9) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(r, ShapeBorderStatics.lerp(r, c, 0.9), 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(c, lerp(r, c, 0.1), 0.1) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(c, ShapeBorderStatics.lerp(r, c, 0.1), 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(c, lerp(r, c, 0.1), 0.9) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(c, ShapeBorderStatics.lerp(r, c, 0.1), 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes,
            excludes: looksLikeRExcludes
        )
    }

    /// **Dart Test:** `rounded_rectangle_border_test.dart:129-153` - toString tests
    func testRoundedRectangleBorderToCircleLerpDescription() {
        let r = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )
        let c = CircleBorder()

        // lerp(r, c, 0.1)
        let lerp01 = ShapeBorderStatics.lerp(r, c, 0.1)!
        XCTAssertTrue(lerp01.description.contains("RoundedRectangleBorder"))
        XCTAssertTrue(lerp01.description.contains("10.0% of the way to being a CircleBorder"))

        // lerp(r, c, 0.2)
        let lerp02 = ShapeBorderStatics.lerp(r, c, 0.2)!
        XCTAssertTrue(lerp02.description.contains("20.0% of the way to being a CircleBorder"))

        // lerp(lerp(r, c, 0.1), lerp(r, c, 0.9), 0.9)
        let complex = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(r, c, 0.1),
            ShapeBorderStatics.lerp(r, c, 0.9),
            0.9
        )!
        XCTAssertTrue(complex.description.contains("82.0% of the way to being a CircleBorder"))

        // lerp(c, r, 0.9)
        let lerpCR09 = ShapeBorderStatics.lerp(c, r, 0.9)!
        XCTAssertTrue(lerpCR09.description.contains("10.0% of the way to being a CircleBorder"))

        // lerp(c, r, 0.8)
        let lerpCR08 = ShapeBorderStatics.lerp(c, r, 0.8)!
        XCTAssertTrue(lerpCR08.description.contains("20.0% of the way to being a CircleBorder"))

        // lerp(lerp(r, c, 0.9), lerp(r, c, 0.1), 0.1)
        let complexReverse = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(r, c, 0.9),
            ShapeBorderStatics.lerp(r, c, 0.1),
            0.1
        )!
        XCTAssertTrue(complexReverse.description.contains("82.0% of the way to being a CircleBorder"))
    }

    /// **Dart Test:** `rounded_rectangle_border_test.dart:155-166` - equality and hashCode for lerped borders
    func testRoundedRectangleBorderToCircleLerpEqualityHashCode() {
        let r = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )
        let c = CircleBorder()

        // lerp(r, c, 0.1) == lerp(r, c, 0.1)
        let lerp1 = ShapeBorderStatics.lerp(r, c, 0.1)!
        let lerp2 = ShapeBorderStatics.lerp(r, c, 0.1)!
        XCTAssertTrue(lerp1.description == lerp2.description)

        // direct50 == indirect50
        let direct50 = ShapeBorderStatics.lerp(r, c, 0.5)!
        let indirect50 = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(c, r, 0.1),
            ShapeBorderStatics.lerp(c, r, 0.9),
            0.5
        )!
        XCTAssertTrue(direct50.description == indirect50.description)
    }

    // MARK: - Dimensions Tests

    /// **Dart Test:** `rounded_rectangle_border_test.dart:169-197` - "RoundedRectangleBorder.dimensions and CircleBorder.dimensions"
    func testRoundedRectangleBorderDimensionsAndCircleBorderDimensions() {
        // RoundedRectangleBorder inside
        let insideRoundedRectangleBorder = RoundedRectangleBorder(
            side: BorderSide(width: 10)
        )
        if let dims = insideRoundedRectangleBorder.dimensions as? EdgeInsets {
            XCTAssertEqual(dims, EdgeInsets(all: 10))
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        // RoundedRectangleBorder center
        let centerRoundedRectangleBorder = RoundedRectangleBorder(
            side: BorderSide(width: 10, strokeAlign: BorderSide.strokeAlignCenter)
        )
        if let dims = centerRoundedRectangleBorder.dimensions as? EdgeInsets {
            XCTAssertEqual(dims, EdgeInsets(all: 5))
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        // RoundedRectangleBorder outside
        let outsideRoundedRectangleBorder = RoundedRectangleBorder(
            side: BorderSide(width: 10, strokeAlign: BorderSide.strokeAlignOutside)
        )
        if let dims = outsideRoundedRectangleBorder.dimensions as? EdgeInsets {
            XCTAssertEqual(dims, EdgeInsets.zero)
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        // CircleBorder inside
        let insideCircleBorder = CircleBorder(side: BorderSide(width: 10))
        if let dims = insideCircleBorder.dimensions as? EdgeInsets {
            XCTAssertEqual(dims, EdgeInsets(all: 10))
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        // CircleBorder center
        let centerCircleBorder = CircleBorder(
            side: BorderSide(width: 10, strokeAlign: BorderSide.strokeAlignCenter)
        )
        if let dims = centerCircleBorder.dimensions as? EdgeInsets {
            XCTAssertEqual(dims, EdgeInsets(all: 5))
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        // CircleBorder outside
        let outsideCircleBorder = CircleBorder(
            side: BorderSide(width: 10, strokeAlign: BorderSide.strokeAlignOutside)
        )
        if let dims = outsideCircleBorder.dimensions as? EdgeInsets {
            XCTAssertEqual(dims, EdgeInsets.zero)
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }
    }

    // MARK: - Lerp with Different StrokeAlign Tests

    /// **Dart Test:** `rounded_rectangle_border_test.dart:199-208` - "RoundedRectangleBorder.lerp with different StrokeAlign"
    func testRoundedRectangleBorderLerpWithDifferentStrokeAlign() {
        let rInside = RoundedRectangleBorder(side: BorderSide(width: 10.0))
        let rOutside = RoundedRectangleBorder(
            side: BorderSide(width: 20.0, strokeAlign: BorderSide.strokeAlignOutside)
        )
        let rCenter = RoundedRectangleBorder(
            side: BorderSide(width: 15.0, strokeAlign: BorderSide.strokeAlignCenter)
        )

        if let lerped = ShapeBorderStatics.lerp(rInside, rOutside, 0.5) as? RoundedRectangleBorder {
            XCTAssertEqual(lerped, rCenter)
        } else {
            XCTFail("lerp should return RoundedRectangleBorder")
        }
    }

    // MARK: - Additional Tests

    /// Test description/toString
    func testRoundedRectangleBorderDescription() {
        let border = RoundedRectangleBorder()
        XCTAssertTrue(border.description.contains("RoundedRectangleBorder"))
    }

    /// Test that preferPaintInterior returns true
    func testRoundedRectangleBorderPreferPaintInterior() {
        let border = RoundedRectangleBorder()
        XCTAssertTrue(border.preferPaintInterior)
    }

    /// Test that copyWith with no arguments returns equal border
    func testCopyWithNoArguments() {
        let border = RoundedRectangleBorder(
            side: BorderSide(width: 5.0),
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )
        let copied = border.copyWith()
        XCTAssertEqual(border, copied)
    }

    /// Test that copyWith replaces only specified arguments
    func testCopyWithReplacesSpecifiedArguments() {
        let border = RoundedRectangleBorder(
            side: BorderSide(width: 5.0),
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )

        let newSide = BorderSide(width: 15.0)
        let copiedWithNewSide = border.copyWith(side: newSide, borderRadius: nil)
        XCTAssertEqual(copiedWithNewSide.side, newSide)
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

    /// Test that borders with different properties are not equal
    func testRoundedRectangleBorderInequality() {
        let border1 = RoundedRectangleBorder()
        let border2 = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius(circular: 10.0))
        )
        let border3 = RoundedRectangleBorder(
            side: BorderSide(width: 2.0)
        )

        XCTAssertNotEqual(border1, border2)
        XCTAssertNotEqual(border1, border3)
        XCTAssertNotEqual(border2, border3)
    }
}


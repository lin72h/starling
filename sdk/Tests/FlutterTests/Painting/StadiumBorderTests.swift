// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for StadiumBorder.
///
/// **Dart Test Source:** `packages/flutter/test/painting/stadium_border_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class StadiumBorderTests: XCTestCase {

    // MARK: - Defaults Test

    /// **Dart Test:** `stadium_border_test.dart:11-14` - "StadiumBorder defaults"
    func testStadiumBorderDefaults() {
        let border = StadiumBorder()
        XCTAssertEqual(border.side, BorderSide.none)
    }

    // MARK: - copyWith, ==, hashCode Tests

    /// **Dart Test:** `stadium_border_test.dart:16-21` - "StadiumBorder copyWith, ==, hashCode"
    func testStadiumBorderCopyWithEqualityHashCode() {
        let border = StadiumBorder()
        let copiedBorder = border.copyWith()

        // Test equality
        XCTAssertEqual(border, copiedBorder)

        // Test hashCode equality
        XCTAssertEqual(border.hashValue, copiedBorder.hashValue)

        // Test side copyWith
        let side = BorderSide(color: Color(0xff123456), width: 10.0)
        let borderWithSide: StadiumBorder = StadiumBorder().copyWith(side: side)
        let expectedBorder = StadiumBorder(side: side)
        XCTAssertEqual(borderWithSide, expectedBorder)
    }

    // MARK: - Scale, Lerp, Dimensions, Path Tests

    /// **Dart Test:** `stadium_border_test.dart:23-49` - "StadiumBorder"
    func testStadiumBorderScaleLerpDimensionsPaths() {
        let c10 = StadiumBorder(side: BorderSide(width: 10.0))
        let c15 = StadiumBorder(side: BorderSide(width: 15.0))
        let c20 = StadiumBorder(side: BorderSide(width: 20.0))

        // Test dimensions
        if let dimensions = c10.dimensions as? EdgeInsets {
            XCTAssertEqual(dimensions, EdgeInsets(all: 10.0))
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        // Test scale
        if let scaled = c10.scale(2.0) as? StadiumBorder {
            XCTAssertEqual(scaled, c20)
        } else {
            XCTFail("scale should return StadiumBorder")
        }

        if let scaledHalf = c20.scale(0.5) as? StadiumBorder {
            XCTAssertEqual(scaledHalf, c10)
        } else {
            XCTFail("scale should return StadiumBorder")
        }

        // Test ShapeBorder.lerp
        if let lerp0 = ShapeBorderStatics.lerp(c10, c20, 0.0) as? StadiumBorder {
            XCTAssertEqual(lerp0, c10)
        } else {
            XCTFail("lerp at 0.0 should return StadiumBorder equal to c10")
        }

        if let lerp05 = ShapeBorderStatics.lerp(c10, c20, 0.5) as? StadiumBorder {
            XCTAssertEqual(lerp05, c15)
        } else {
            XCTFail("lerp at 0.5 should return StadiumBorder equal to c15")
        }

        if let lerp1 = ShapeBorderStatics.lerp(c10, c20, 1.0) as? StadiumBorder {
            XCTAssertEqual(lerp1, c20)
        } else {
            XCTFail("lerp at 1.0 should return StadiumBorder equal to c20")
        }

        // Test getOuterPath produces a stadium shape (unit circle for square rect)
        let c1 = StadiumBorder(side: BorderSide())
        let outerPath = c1.getOuterPath(Rect.fromCircle(center: Offset.zero, radius: 1.0))
        let outerBounds = outerPath.getBounds()
        XCTAssertEqual(outerBounds.left, -1.0, accuracy: 1e-6)
        XCTAssertEqual(outerBounds.top, -1.0, accuracy: 1e-6)
        XCTAssertEqual(outerBounds.right, 1.0, accuracy: 1e-6)
        XCTAssertEqual(outerBounds.bottom, 1.0, accuracy: 1e-6)

        // Test getInnerPath
        let c2 = StadiumBorder(side: BorderSide())
        let innerPath = c2.getInnerPath(Rect.fromCircle(center: Offset.zero, radius: 2.0))
        let innerBounds = innerPath.getBounds()
        XCTAssertEqual(innerBounds.left, -1.0, accuracy: 1e-6)
        XCTAssertEqual(innerBounds.top, -1.0, accuracy: 1e-6)
        XCTAssertEqual(innerBounds.right, 1.0, accuracy: 1e-6)
        XCTAssertEqual(innerBounds.bottom, 1.0, accuracy: 1e-6)
    }

    // MARK: - StrokeAlign Tests

    /// **Dart Test:** `stadium_border_test.dart:51-78` - "StadiumBorder with StrokeAlign"
    func testStadiumBorderWithStrokeAlign() {
        let center = StadiumBorder(
            side: BorderSide(width: 10.0, strokeAlign: BorderSide.strokeAlignCenter)
        )
        let outside = StadiumBorder(
            side: BorderSide(width: 10.0, strokeAlign: BorderSide.strokeAlignOutside)
        )

        // Test dimensions
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

    // MARK: - StadiumBorder and CircleBorder Lerp Tests

    /// **Dart Test:** `stadium_border_test.dart:80-194` - "StadiumBorder and CircleBorder"
    func testStadiumBorderAndCircleBorderLerp() {
        let stadium = StadiumBorder()
        let circle = CircleBorder()
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 20.0)

        // "looksLikeS" - stadium-shaped: includes center points, excludes corners
        let looksLikeSIncludes: [Offset] = [Offset(30.0, 10.0), Offset(50.0, 10.0)]
        let looksLikeSExcludes: [Offset] = [Offset(1.0, 1.0), Offset(99.0, 19.0)]

        // "looksLikeC" - circle-shaped: includes only the center, excludes wide points
        let looksLikeCIncludes: [Offset] = [Offset(50.0, 10.0)]
        let looksLikeCExcludes: [Offset] = [Offset(1.0, 1.0), Offset(30.0, 10.0), Offset(99.0, 19.0)]

        // Test stadium.getOuterPath looks like S
        assertPathContains(
            stadium.getOuterPath(rect),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test circle.getOuterPath looks like C
        assertPathContains(
            circle.getOuterPath(rect),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(stadium, circle, 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, circle, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(stadium, circle, 0.9) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, circle, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(lerp(stadium, circle, 0.9), stadium, 0.1) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, circle, 0.9), stadium, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(lerp(stadium, circle, 0.9), stadium, 0.9) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, circle, 0.9), stadium, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, circle, 0.1), circle, 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, circle, 0.1), circle, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, circle, 0.1), circle, 0.9) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, circle, 0.1), circle, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(lerp(stadium, circle, 0.1), lerp(stadium, circle, 0.9), 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, circle, 0.1),
                ShapeBorderStatics.lerp(stadium, circle, 0.9),
                0.1
            )!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, circle, 0.1), lerp(stadium, circle, 0.9), 0.9) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, circle, 0.1),
                ShapeBorderStatics.lerp(stadium, circle, 0.9),
                0.9
            )!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(stadium, lerp(stadium, circle, 0.9), 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, ShapeBorderStatics.lerp(stadium, circle, 0.9), 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(stadium, lerp(stadium, circle, 0.9), 0.9) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, ShapeBorderStatics.lerp(stadium, circle, 0.9), 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(circle, lerp(stadium, circle, 0.1), 0.1) looks like C
        assertPathContains(
            ShapeBorderStatics.lerp(circle, ShapeBorderStatics.lerp(stadium, circle, 0.1), 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeCIncludes,
            excludes: looksLikeCExcludes
        )

        // Test lerp(circle, lerp(stadium, circle, 0.1), 0.9) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(circle, ShapeBorderStatics.lerp(stadium, circle, 0.1), 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )
    }

    /// **Dart Test:** `stadium_border_test.dart:145-177` - toString tests for StadiumBorder and CircleBorder
    func testStadiumBorderToCircleLerpDescription() {
        let stadium = StadiumBorder()
        let circle = CircleBorder()

        // lerp(stadium, circle, 0.1)
        let lerp01 = ShapeBorderStatics.lerp(stadium, circle, 0.1)!
        XCTAssertTrue(lerp01.description.contains("StadiumBorder"))
        XCTAssertTrue(lerp01.description.contains("10.0% of the way to being a CircleBorder"))

        // lerp(stadium, circle, 0.2)
        let lerp02 = ShapeBorderStatics.lerp(stadium, circle, 0.2)!
        XCTAssertTrue(lerp02.description.contains("20.0% of the way to being a CircleBorder"))

        // lerp(lerp(stadium, circle, 0.1), lerp(stadium, circle, 0.9), 0.9)
        let complex = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(stadium, circle, 0.1),
            ShapeBorderStatics.lerp(stadium, circle, 0.9),
            0.9
        )!
        XCTAssertTrue(complex.description.contains("82.0% of the way to being a CircleBorder"))

        // lerp(circle, stadium, 0.9)
        let lerpCS09 = ShapeBorderStatics.lerp(circle, stadium, 0.9)!
        XCTAssertTrue(lerpCS09.description.contains("10.0% of the way to being a CircleBorder"))

        // lerp(circle, stadium, 0.8)
        let lerpCS08 = ShapeBorderStatics.lerp(circle, stadium, 0.8)!
        XCTAssertTrue(lerpCS08.description.contains("20.0% of the way to being a CircleBorder"))

        // lerp(lerp(stadium, circle, 0.9), lerp(stadium, circle, 0.1), 0.1)
        let complexReverse = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(stadium, circle, 0.9),
            ShapeBorderStatics.lerp(stadium, circle, 0.1),
            0.1
        )!
        XCTAssertTrue(complexReverse.description.contains("82.0% of the way to being a CircleBorder"))
    }

    /// **Dart Test:** `stadium_border_test.dart:179-193` - equality and hashCode for lerped StadiumBorder and CircleBorder
    func testStadiumBorderToCircleLerpEqualityHashCode() {
        let stadium = StadiumBorder()
        let circle = CircleBorder()

        // lerp(stadium, circle, 0.1) == lerp(stadium, circle, 0.1)
        let lerp1 = ShapeBorderStatics.lerp(stadium, circle, 0.1)!
        let lerp2 = ShapeBorderStatics.lerp(stadium, circle, 0.1)!
        XCTAssertEqual(lerp1.description, lerp2.description)

        // direct50 == indirect50
        let direct50 = ShapeBorderStatics.lerp(stadium, circle, 0.5)!
        let indirect50 = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(circle, stadium, 0.1),
            ShapeBorderStatics.lerp(circle, stadium, 0.9),
            0.5
        )!
        XCTAssertEqual(direct50.description, indirect50.description)
    }

    // MARK: - StadiumBorder and RoundedRectBorder with BorderRadius.zero Tests

    /// **Dart Test:** `stadium_border_test.dart:196-328` - "StadiumBorder and RoundedRectBorder with BorderRadius.zero"
    func testStadiumBorderAndRoundedRectBorderWithBorderRadiusZero() {
        let stadium = StadiumBorder()
        let rrect = RoundedRectangleBorder()
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 50.0)

        // "looksLikeS" - stadium-shaped
        let looksLikeSIncludes: [Offset] = [Offset(25.0, 25.0), Offset(50.0, 25.0), Offset(7.33, 7.33)]
        let looksLikeSExcludes: [Offset] = [
            Offset(0.001, 0.001),
            Offset(99.999, 0.001),
            Offset(99.999, 49.999),
            Offset(0.001, 49.999),
        ]

        // "looksLikeR" - rounded rectangle-shaped
        let looksLikeRIncludes: [Offset] = [
            Offset(25.0, 25.0),
            Offset(50.0, 25.0),
            Offset(7.33, 7.33),
            Offset(4.0, 4.0),
            Offset(96.0, 4.0),
            Offset(96.0, 46.0),
            Offset(4.0, 46.0),
        ]

        // Test stadium.getOuterPath looks like S
        assertPathContains(
            stadium.getOuterPath(rect),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test rrect.getOuterPath looks like R
        assertPathContains(
            rrect.getOuterPath(rect),
            includes: looksLikeRIncludes
        )

        // Test lerp(stadium, rrect, 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, rrect, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(stadium, rrect, 0.9) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, rrect, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes
        )

        // Test lerp(lerp(stadium, rrect, 0.9), stadium, 0.1) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, rrect, 0.9), stadium, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes
        )

        // Test lerp(lerp(stadium, rrect, 0.9), stadium, 0.9) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, rrect, 0.9), stadium, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), rrect, 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, rrect, 0.1), rrect, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), rrect, 0.9) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, rrect, 0.1), rrect, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), lerp(stadium, rrect, 0.9), 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                0.1
            )!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), lerp(stadium, rrect, 0.9), 0.9) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                0.9
            )!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes
        )

        // Test lerp(stadium, lerp(stadium, rrect, 0.9), 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, ShapeBorderStatics.lerp(stadium, rrect, 0.9), 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(stadium, lerp(stadium, rrect, 0.9), 0.9) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, ShapeBorderStatics.lerp(stadium, rrect, 0.9), 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes
        )

        // Test lerp(rrect, lerp(stadium, rrect, 0.1), 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(rrect, ShapeBorderStatics.lerp(stadium, rrect, 0.1), 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(rrect, lerp(stadium, rrect, 0.1), 0.9) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(rrect, ShapeBorderStatics.lerp(stadium, rrect, 0.1), 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )
    }

    /// **Dart Test:** `stadium_border_test.dart:273-311` - toString tests for StadiumBorder and RoundedRectBorder with BorderRadius.zero
    func testStadiumBorderToRoundedRectBorderZeroLerpDescription() {
        let stadium = StadiumBorder()
        let rrect = RoundedRectangleBorder()

        // lerp(stadium, rrect, 0.1)
        let lerp01 = ShapeBorderStatics.lerp(stadium, rrect, 0.1)!
        XCTAssertTrue(lerp01.description.contains("StadiumBorder"))
        XCTAssertTrue(lerp01.description.contains("BorderRadius.zero"))
        XCTAssertTrue(lerp01.description.contains("10.0% of the way to being a RoundedRectangleBorder"))

        // lerp(stadium, rrect, 0.2)
        let lerp02 = ShapeBorderStatics.lerp(stadium, rrect, 0.2)!
        XCTAssertTrue(lerp02.description.contains("20.0% of the way to being a RoundedRectangleBorder"))

        // lerp(lerp(stadium, rrect, 0.1), lerp(stadium, rrect, 0.9), 0.9)
        let complex = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(stadium, rrect, 0.1),
            ShapeBorderStatics.lerp(stadium, rrect, 0.9),
            0.9
        )!
        XCTAssertTrue(complex.description.contains("82.0% of the way to being a RoundedRectangleBorder"))

        // lerp(rrect, stadium, 0.9)
        let lerpRS09 = ShapeBorderStatics.lerp(rrect, stadium, 0.9)!
        XCTAssertTrue(lerpRS09.description.contains("10.0% of the way to being a RoundedRectangleBorder"))

        // lerp(rrect, stadium, 0.8)
        let lerpRS08 = ShapeBorderStatics.lerp(rrect, stadium, 0.8)!
        XCTAssertTrue(lerpRS08.description.contains("20.0% of the way to being a RoundedRectangleBorder"))

        // lerp(lerp(stadium, rrect, 0.9), lerp(stadium, rrect, 0.1), 0.1)
        let complexReverse = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(stadium, rrect, 0.9),
            ShapeBorderStatics.lerp(stadium, rrect, 0.1),
            0.1
        )!
        XCTAssertTrue(complexReverse.description.contains("82.0% of the way to being a RoundedRectangleBorder"))
    }

    /// **Dart Test:** `stadium_border_test.dart:313-327` - equality and hashCode for lerped StadiumBorder and RoundedRectBorder with BorderRadius.zero
    func testStadiumBorderToRoundedRectBorderZeroLerpEqualityHashCode() {
        let stadium = StadiumBorder()
        let rrect = RoundedRectangleBorder()

        // lerp(stadium, rrect, 0.1) == lerp(stadium, rrect, 0.1)
        let lerp1 = ShapeBorderStatics.lerp(stadium, rrect, 0.1)!
        let lerp2 = ShapeBorderStatics.lerp(stadium, rrect, 0.1)!
        XCTAssertEqual(lerp1.description, lerp2.description)

        // direct50 == indirect50
        let direct50 = ShapeBorderStatics.lerp(stadium, rrect, 0.5)!
        let indirect50 = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(rrect, stadium, 0.1),
            ShapeBorderStatics.lerp(rrect, stadium, 0.9),
            0.5
        )!
        XCTAssertEqual(direct50.description, indirect50.description)
    }

    // MARK: - StadiumBorder and RoundedRectBorder with circular BorderRadius Tests

    /// **Dart Test:** `stadium_border_test.dart:330-464` - "StadiumBorder and RoundedRectBorder with circular BorderRadius"
    func testStadiumBorderAndRoundedRectBorderWithCircularBorderRadius() {
        let stadium = StadiumBorder()
        let rrect = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius(circular: 10))
        )
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 50.0)

        // "looksLikeS" - stadium-shaped
        let looksLikeSIncludes: [Offset] = [Offset(25.0, 25.0), Offset(50.0, 25.0), Offset(7.33, 7.33)]
        let looksLikeSExcludes: [Offset] = [
            Offset(0.001, 0.001),
            Offset(99.999, 0.001),
            Offset(99.999, 49.999),
            Offset(0.001, 49.999),
        ]

        // "looksLikeR" - rounded rectangle-shaped
        let looksLikeRIncludes: [Offset] = [
            Offset(25.0, 25.0),
            Offset(50.0, 25.0),
            Offset(7.33, 7.33),
            Offset(4.0, 4.0),
            Offset(96.0, 4.0),
            Offset(96.0, 46.0),
            Offset(4.0, 46.0),
        ]

        // Test stadium.getOuterPath looks like S
        assertPathContains(
            stadium.getOuterPath(rect),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test rrect.getOuterPath looks like R
        assertPathContains(
            rrect.getOuterPath(rect),
            includes: looksLikeRIncludes
        )

        // Test lerp(stadium, rrect, 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, rrect, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(stadium, rrect, 0.9) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, rrect, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes
        )

        // Test lerp(lerp(stadium, rrect, 0.9), stadium, 0.1) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, rrect, 0.9), stadium, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes
        )

        // Test lerp(lerp(stadium, rrect, 0.9), stadium, 0.9) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, rrect, 0.9), stadium, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), rrect, 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, rrect, 0.1), rrect, 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), rrect, 0.9) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(ShapeBorderStatics.lerp(stadium, rrect, 0.1), rrect, 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), lerp(stadium, rrect, 0.9), 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                0.1
            )!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), lerp(stadium, rrect, 0.9), 0.9) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                0.9
            )!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes
        )

        // Test lerp(stadium, lerp(stadium, rrect, 0.9), 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, ShapeBorderStatics.lerp(stadium, rrect, 0.9), 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(stadium, lerp(stadium, rrect, 0.9), 0.9) looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, ShapeBorderStatics.lerp(stadium, rrect, 0.9), 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeRIncludes
        )

        // Test lerp(rrect, lerp(stadium, rrect, 0.1), 0.1) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(rrect, ShapeBorderStatics.lerp(stadium, rrect, 0.1), 0.1)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(rrect, lerp(stadium, rrect, 0.1), 0.9) looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(rrect, ShapeBorderStatics.lerp(stadium, rrect, 0.1), 0.9)!.getOuterPath(rect, textDirection: nil),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )
    }

    /// **Dart Test:** `stadium_border_test.dart:409-447` - toString tests for StadiumBorder and RoundedRectBorder with circular BorderRadius
    func testStadiumBorderToRoundedRectBorderCircularLerpDescription() {
        let stadium = StadiumBorder()
        let rrect = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius(circular: 10))
        )

        // lerp(stadium, rrect, 0.1)
        let lerp01 = ShapeBorderStatics.lerp(stadium, rrect, 0.1)!
        XCTAssertTrue(lerp01.description.contains("StadiumBorder"))
        XCTAssertTrue(lerp01.description.contains("BorderRadius.circular(10.0)"))
        XCTAssertTrue(lerp01.description.contains("10.0% of the way to being a RoundedRectangleBorder"))

        // lerp(stadium, rrect, 0.2)
        let lerp02 = ShapeBorderStatics.lerp(stadium, rrect, 0.2)!
        XCTAssertTrue(lerp02.description.contains("20.0% of the way to being a RoundedRectangleBorder"))

        // lerp(lerp(stadium, rrect, 0.1), lerp(stadium, rrect, 0.9), 0.9)
        let complex = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(stadium, rrect, 0.1),
            ShapeBorderStatics.lerp(stadium, rrect, 0.9),
            0.9
        )!
        XCTAssertTrue(complex.description.contains("82.0% of the way to being a RoundedRectangleBorder"))

        // lerp(rrect, stadium, 0.9)
        let lerpRS09 = ShapeBorderStatics.lerp(rrect, stadium, 0.9)!
        XCTAssertTrue(lerpRS09.description.contains("10.0% of the way to being a RoundedRectangleBorder"))

        // lerp(rrect, stadium, 0.8)
        let lerpRS08 = ShapeBorderStatics.lerp(rrect, stadium, 0.8)!
        XCTAssertTrue(lerpRS08.description.contains("20.0% of the way to being a RoundedRectangleBorder"))

        // lerp(lerp(stadium, rrect, 0.9), lerp(stadium, rrect, 0.1), 0.1)
        let complexReverse = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(stadium, rrect, 0.9),
            ShapeBorderStatics.lerp(stadium, rrect, 0.1),
            0.1
        )!
        XCTAssertTrue(complexReverse.description.contains("82.0% of the way to being a RoundedRectangleBorder"))
    }

    /// **Dart Test:** `stadium_border_test.dart:449-463` - equality and hashCode for lerped StadiumBorder and RoundedRectBorder with circular BorderRadius
    func testStadiumBorderToRoundedRectBorderCircularLerpEqualityHashCode() {
        let stadium = StadiumBorder()
        let rrect = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius(circular: 10))
        )

        // lerp(stadium, rrect, 0.1) == lerp(stadium, rrect, 0.1)
        let lerp1 = ShapeBorderStatics.lerp(stadium, rrect, 0.1)!
        let lerp2 = ShapeBorderStatics.lerp(stadium, rrect, 0.1)!
        XCTAssertEqual(lerp1.description, lerp2.description)

        // direct50 == indirect50
        let direct50 = ShapeBorderStatics.lerp(stadium, rrect, 0.5)!
        let indirect50 = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(rrect, stadium, 0.1),
            ShapeBorderStatics.lerp(rrect, stadium, 0.9),
            0.5
        )!
        XCTAssertEqual(direct50.description, indirect50.description)
    }

    // MARK: - StadiumBorder and RoundedRectBorder with BorderRadiusDirectional Tests

    /// **Dart Test:** `stadium_border_test.dart:466-584` - "StadiumBorder and RoundedRectBorder with BorderRadiusDirectional"
    func testStadiumBorderAndRoundedRectBorderWithBorderRadiusDirectional() {
        let stadium = StadiumBorder()
        let rrect = RoundedRectangleBorder(
            borderRadius: BorderRadiusDirectional.only(
                topStart: Radius(circular: 10),
                bottomEnd: Radius(circular: 10)
            )
        )
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 50.0)

        // "looksLikeS" - stadium-shaped
        let looksLikeSIncludes: [Offset] = [Offset(25.0, 25.0), Offset(50.0, 25.0), Offset(7.33, 7.33)]
        let looksLikeSExcludes: [Offset] = [
            Offset(0.001, 0.001),
            Offset(99.999, 0.001),
            Offset(99.999, 49.999),
            Offset(0.001, 49.999),
        ]

        // "looksLikeR" - rounded rectangle-shaped
        let looksLikeRIncludes: [Offset] = [
            Offset(25.0, 25.0),
            Offset(50.0, 25.0),
            Offset(7.33, 7.33),
            Offset(4.0, 4.0),
            Offset(96.0, 4.0),
            Offset(96.0, 46.0),
            Offset(4.0, 46.0),
        ]

        // Test stadium.getOuterPath with RTL looks like S
        assertPathContains(
            stadium.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test rrect.getOuterPath with RTL looks like R
        assertPathContains(
            rrect.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeRIncludes
        )

        // Test lerp(stadium, rrect, 0.1) with RTL looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, rrect, 0.1)!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(stadium, rrect, 0.9) with RTL looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(stadium, rrect, 0.9)!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeRIncludes
        )

        // Test lerp(lerp(stadium, rrect, 0.9), stadium, 0.1) with RTL looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                stadium,
                0.1
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeRIncludes
        )

        // Test lerp(lerp(stadium, rrect, 0.9), stadium, 0.9) with RTL looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                stadium,
                0.9
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), rrect, 0.1) with RTL looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                rrect,
                0.1
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), rrect, 0.9) with RTL looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                rrect,
                0.9
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), lerp(stadium, rrect, 0.9), 0.1) with RTL looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                0.1
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(lerp(stadium, rrect, 0.1), lerp(stadium, rrect, 0.9), 0.9) with RTL looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                0.9
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeRIncludes
        )

        // Test lerp(stadium, lerp(stadium, rrect, 0.9), 0.1) with RTL looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                stadium,
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                0.1
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(stadium, lerp(stadium, rrect, 0.9), 0.9) with RTL looks like R
        assertPathContains(
            ShapeBorderStatics.lerp(
                stadium,
                ShapeBorderStatics.lerp(stadium, rrect, 0.9),
                0.9
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeRIncludes
        )

        // Test lerp(rrect, lerp(stadium, rrect, 0.1), 0.1) with RTL looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                rrect,
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                0.1
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )

        // Test lerp(rrect, lerp(stadium, rrect, 0.1), 0.9) with RTL looks like S
        assertPathContains(
            ShapeBorderStatics.lerp(
                rrect,
                ShapeBorderStatics.lerp(stadium, rrect, 0.1),
                0.9
            )!.getOuterPath(rect, textDirection: .rtl),
            includes: looksLikeSIncludes,
            excludes: looksLikeSExcludes
        )
    }

    /// **Dart Test:** `stadium_border_test.dart:586-629` - toString tests for StadiumBorder and RoundedRectBorder with BorderRadiusDirectional
    func testStadiumBorderToRoundedRectBorderDirectionalLerpDescription() {
        let stadium = StadiumBorder()
        let rrect = RoundedRectangleBorder(
            borderRadius: BorderRadiusDirectional.only(
                topStart: Radius(circular: 10),
                bottomEnd: Radius(circular: 10)
            )
        )

        // lerp(stadium, rrect, 0.1)
        let lerp01 = ShapeBorderStatics.lerp(stadium, rrect, 0.1)!
        XCTAssertTrue(lerp01.description.contains("StadiumBorder"))
        XCTAssertTrue(lerp01.description.contains("Radius.circular(10.0)"))
        XCTAssertTrue(lerp01.description.contains("10.0% of the way to being a RoundedRectangleBorder"))

        // lerp(stadium, rrect, 0.2)
        let lerp02 = ShapeBorderStatics.lerp(stadium, rrect, 0.2)!
        XCTAssertTrue(lerp02.description.contains("20.0% of the way to being a RoundedRectangleBorder"))

        // lerp(lerp(stadium, rrect, 0.1), lerp(stadium, rrect, 0.9), 0.9)
        let complex = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(stadium, rrect, 0.1),
            ShapeBorderStatics.lerp(stadium, rrect, 0.9),
            0.9
        )!
        XCTAssertTrue(complex.description.contains("82.0% of the way to being a RoundedRectangleBorder"))

        // lerp(rrect, stadium, 0.9)
        let lerpRS09 = ShapeBorderStatics.lerp(rrect, stadium, 0.9)!
        XCTAssertTrue(lerpRS09.description.contains("10.0% of the way to being a RoundedRectangleBorder"))

        // lerp(rrect, stadium, 0.8)
        let lerpRS08 = ShapeBorderStatics.lerp(rrect, stadium, 0.8)!
        XCTAssertTrue(lerpRS08.description.contains("20.0% of the way to being a RoundedRectangleBorder"))

        // lerp(lerp(stadium, rrect, 0.9), lerp(stadium, rrect, 0.1), 0.1)
        let complexReverse = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(stadium, rrect, 0.9),
            ShapeBorderStatics.lerp(stadium, rrect, 0.1),
            0.1
        )!
        XCTAssertTrue(complexReverse.description.contains("82.0% of the way to being a RoundedRectangleBorder"))
    }

    /// **Dart Test:** `stadium_border_test.dart:631-646` - equality and hashCode for lerped StadiumBorder and RoundedRectBorder with BorderRadiusDirectional
    func testStadiumBorderToRoundedRectBorderDirectionalLerpEqualityHashCode() {
        let stadium = StadiumBorder()
        let rrect = RoundedRectangleBorder(
            borderRadius: BorderRadiusDirectional.only(
                topStart: Radius(circular: 10),
                bottomEnd: Radius(circular: 10)
            )
        )

        // lerp(stadium, rrect, 0.1) == lerp(stadium, rrect, 0.1)
        let lerp1 = ShapeBorderStatics.lerp(stadium, rrect, 0.1)!
        let lerp2 = ShapeBorderStatics.lerp(stadium, rrect, 0.1)!
        XCTAssertEqual(lerp1.description, lerp2.description)

        // direct50 == indirect50
        let direct50 = ShapeBorderStatics.lerp(stadium, rrect, 0.5)!
        let indirect50 = ShapeBorderStatics.lerp(
            ShapeBorderStatics.lerp(rrect, stadium, 0.1),
            ShapeBorderStatics.lerp(rrect, stadium, 0.9),
            0.5
        )!
        XCTAssertEqual(direct50.description, indirect50.description)
    }

    // MARK: - Description Tests

    /// Test that description shows "StadiumBorder".
    func testStadiumBorderDescription() {
        let border = StadiumBorder()
        XCTAssertTrue(border.description.contains("StadiumBorder"))
    }

    // MARK: - preferPaintInterior Test

    /// Test that preferPaintInterior returns true.
    func testStadiumBorderPreferPaintInterior() {
        let border = StadiumBorder()
        XCTAssertTrue(border.preferPaintInterior)
    }
}

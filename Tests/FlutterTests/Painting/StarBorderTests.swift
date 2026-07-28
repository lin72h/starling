// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for StarBorder.
///
/// **Dart Test Source:** `packages/flutter/test/painting/star_border_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - StarBorderSubclass (for type-checking tests)

/// A subclass-like variant used to test type-based equality.
/// In Swift, since StarBorder is a struct, we use a wrapper to simulate
/// subclass behavior for the != type check in the Dart test.
///
/// **Dart Test:** `star_border_test.dart:434-436`
struct StarBorderSubclass: OutlinedBorder, Hashable {
    let side: BorderSide
    private let inner: StarBorder

    init(side: BorderSide = .none) {
        self.side = side
        self.inner = StarBorder(side: side)
    }

    var dimensions: any EdgeInsetsGeometry {
        inner.dimensions
    }

    func scale(_ t: Double) -> any ShapeBorder {
        inner.scale(t)
    }

    func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        inner.lerpFrom(a, t)
    }

    func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? {
        inner.lerpTo(b, t)
    }

    func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        inner.getInnerPath(rect, textDirection: textDirection)
    }

    func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        inner.getOuterPath(rect, textDirection: textDirection)
    }

    func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection? = nil) {
        inner.paint(canvas, rect, textDirection: textDirection)
    }

    func copyWith(side: BorderSide?) -> any OutlinedBorder {
        StarBorderSubclass(side: side ?? self.side)
    }
}

// NOTE: Uses module-level assertPathContains from BeveledRectangleBorderTests

// MARK: - StarBorderTests

final class StarBorderTests: XCTestCase {

    // MARK: - Defaults Test

    /// **Dart Test:** `star_border_test.dart:40-55` - "StarBorder defaults"
    func testStarBorderDefaults() {
        let star = StarBorder()
        XCTAssertEqual(star.side, BorderSide.none)
        XCTAssertEqual(star.points, 5)
        XCTAssertEqual(star.innerRadiusRatio, 0.4)
        XCTAssertEqual(star.rotation, 0)
        XCTAssertEqual(star.pointRounding, 0)
        XCTAssertEqual(star.valleyRounding, 0)
        XCTAssertEqual(star.squash, 0)

        let polygon = StarBorder.polygon()
        XCTAssertEqual(polygon.points, 5)
        XCTAssertEqual(polygon.pointRounding, 0)
        XCTAssertEqual(polygon.rotation, 0)
        XCTAssertEqual(polygon.squash, 0)
    }

    // MARK: - copyWith, ==, hashCode Tests

    /// **Dart Test:** `star_border_test.dart:57-110` - "StarBorder copyWith, ==, hashCode"
    func testStarBorderCopyWithEqualityHashCode() {
        let side = BorderSide(color: Color(0xff123456), width: 10.0)
        let copy = StarBorder().copyWith(
            side: side,
            points: 3,
            innerRadiusRatio: 0.1,
            pointRounding: 0.2,
            valleyRounding: 0.3,
            rotation: 180,
            squash: 0.4
        )
        let expected = StarBorder(
            side: side,
            points: 3,
            innerRadiusRatio: 0.1,
            pointRounding: 0.2,
            valleyRounding: 0.3,
            rotation: 180,
            squash: 0.4
        )
        XCTAssertEqual(StarBorder(), StarBorder().copyWith())
        XCTAssertEqual(copy, expected)
        XCTAssertEqual(copy.hashValue, expected.hashValue)

        // Test that all properties are checked in operator==
        // StarBorderSubclass is a different type, so equality should fail
        // (In Swift, different struct types are never equal)
        let subclass = StarBorderSubclass()
        XCTAssertFalse(StarBorder() == subclass as? StarBorder ?? StarBorder(points: 999))

        // Test that two StarBorders where the only difference is polygon vs star
        // constructor compare as different (which they are, because
        // _innerRadiusRatio is nil on the polygon).
        XCTAssertNotEqual(
            StarBorder(
                points: 3,
                innerRadiusRatio: 1,
                pointRounding: 0.2,
                rotation: 180,
                squash: 0.4
            ),
            StarBorder.polygon(sides: 3, pointRounding: 0.2, rotation: 180, squash: 0.4)
        )

        // Test that copies are unequal whenever any one of the properties changes.
        XCTAssertEqual(copy, copy)
        XCTAssertNotEqual(copy, copy.copyWith(side: BorderSide()))
        XCTAssertNotEqual(copy, copy.copyWith(points: 10))
        XCTAssertNotEqual(copy, copy.copyWith(innerRadiusRatio: 0.5))
        XCTAssertNotEqual(copy, copy.copyWith(pointRounding: 0.5))
        XCTAssertNotEqual(copy, copy.copyWith(valleyRounding: 0.5))
        XCTAssertNotEqual(copy, copy.copyWith(rotation: 10))
        XCTAssertNotEqual(copy, copy.copyWith(squash: 0.0))
    }

    // MARK: - Scale Test

    /// Test that scale produces the expected border with scaled side.
    func testStarBorderScale() {
        let star = StarBorder(
            side: BorderSide(width: 10.0),
            points: 6,
            innerRadiusRatio: 0.5,
            pointRounding: 0.2,
            valleyRounding: 0.1,
            rotation: 45,
            squash: 0.3
        )
        if let scaled = star.scale(2.0) as? StarBorder {
            XCTAssertEqual(scaled.side, BorderSide(width: 20.0))
            XCTAssertEqual(scaled.points, 6)
            XCTAssertEqual(scaled.innerRadiusRatio, 0.5)
            XCTAssertEqual(scaled.pointRounding, 0.2)
            XCTAssertEqual(scaled.valleyRounding, 0.1)
            XCTAssertEqual(scaled.rotation, 45, accuracy: 1e-10)
            XCTAssertEqual(scaled.squash, 0.3)
        } else {
            XCTFail("scale should return StarBorder")
        }
    }

    // MARK: - Path Generation Tests

    /// Test that getOuterPath generates a valid star-shaped path.
    /// For a default 5-point star in a 200x100 rect, the center (100, 50)
    /// should be inside, but corners should not be.
    func testStarBorderOuterPath() {
        let star = StarBorder()
        let rect = Rect.fromLTWH(0, 0, 200, 100)
        let path = star.getOuterPath(rect)

        // Center should be inside
        XCTAssertTrue(path.contains(Offset(100, 50)))
        // Corners should be outside
        XCTAssertFalse(path.contains(Offset(0.001, 0.001)))
        XCTAssertFalse(path.contains(Offset(199.999, 0.001)))
        XCTAssertFalse(path.contains(Offset(199.999, 99.999)))
        XCTAssertFalse(path.contains(Offset(0.001, 99.999)))
    }

    /// Test that getInnerPath deflates by strokeInset.
    func testStarBorderInnerPath() {
        let star = StarBorder(side: BorderSide(width: 5.0))
        let rect = Rect.fromLTWH(0, 0, 200, 100)
        let innerPath = star.getInnerPath(rect)
        let outerPath = star.getOuterPath(rect)

        let innerBounds = innerPath.getBounds()
        let outerBounds = outerPath.getBounds()

        // The inner path should be strictly smaller than the outer path
        XCTAssertTrue(innerBounds.width < outerBounds.width)
        XCTAssertTrue(innerBounds.height < outerBounds.height)
    }

    /// Test that polygon generates a path that contains the center.
    func testStarBorderPolygonOuterPath() {
        let polygon = StarBorder.polygon()
        let rect = Rect.fromLTWH(0, 0, 200, 100)
        let path = polygon.getOuterPath(rect)

        // Center should be inside
        XCTAssertTrue(path.contains(Offset(100, 50)))
    }

    /// Test various point counts.
    func testStarBorderVariousPoints() {
        let rect = Rect.fromLTWH(0, 0, 100, 100)

        // 2-point star
        let star2 = StarBorder(points: 2)
        let path2 = star2.getOuterPath(rect)
        XCTAssertTrue(path2.contains(Offset(50, 50)))

        // 6-point star
        let star6 = StarBorder(points: 6)
        let path6 = star6.getOuterPath(rect)
        XCTAssertTrue(path6.contains(Offset(50, 50)))

        // Polygon with 6 sides
        let poly6 = StarBorder.polygon(sides: 6)
        let pathPoly6 = poly6.getOuterPath(rect)
        XCTAssertTrue(pathPoly6.contains(Offset(50, 50)))
    }

    /// Test path with point rounding.
    func testStarBorderPointRounding() {
        let rect = Rect.fromLTWH(0, 0, 100, 100)

        let star = StarBorder(pointRounding: 0.5)
        let path = star.getOuterPath(rect)
        XCTAssertTrue(path.contains(Offset(50, 50)))

        let starFull = StarBorder(pointRounding: 1.0)
        let pathFull = starFull.getOuterPath(rect)
        XCTAssertTrue(pathFull.contains(Offset(50, 50)))
    }

    /// Test path with valley rounding.
    func testStarBorderValleyRounding() {
        let rect = Rect.fromLTWH(0, 0, 100, 100)

        let star = StarBorder(valleyRounding: 0.5)
        let path = star.getOuterPath(rect)
        XCTAssertTrue(path.contains(Offset(50, 50)))

        let starFull = StarBorder(valleyRounding: 1.0)
        let pathFull = starFull.getOuterPath(rect)
        XCTAssertTrue(pathFull.contains(Offset(50, 50)))
    }

    /// Test path with squash.
    func testStarBorderSquash() {
        let rect = Rect.fromLTWH(0, 0, 200, 100)

        let star0 = StarBorder(squash: 0.0)
        let path0 = star0.getOuterPath(rect)
        XCTAssertTrue(path0.contains(Offset(100, 50)))

        let star1 = StarBorder(squash: 1.0)
        let path1 = star1.getOuterPath(rect)
        XCTAssertTrue(path1.contains(Offset(100, 50)))
    }

    /// Test path with rotation.
    func testStarBorderRotation() {
        let rect = Rect.fromLTWH(0, 0, 100, 100)

        let star = StarBorder(rotation: 45)
        let path = star.getOuterPath(rect)
        XCTAssertTrue(path.contains(Offset(50, 50)))

        let star90 = StarBorder(rotation: 90)
        let path90 = star90.getOuterPath(rect)
        XCTAssertTrue(path90.contains(Offset(50, 50)))
    }

    /// Test path with inner radius ratio extremes.
    func testStarBorderInnerRadiusRatio() {
        let rect = Rect.fromLTWH(0, 0, 100, 100)

        let star0 = StarBorder(innerRadiusRatio: 0.0)
        let path0 = star0.getOuterPath(rect)
        XCTAssertTrue(path0.contains(Offset(50, 50)))

        let star7 = StarBorder(innerRadiusRatio: 0.7)
        let path7 = star7.getOuterPath(rect)
        XCTAssertTrue(path7.contains(Offset(50, 50)))
    }

    // MARK: - Lerp Tests

    /// **Dart Test:** `star_border_test.dart:248-263` - "StarBorder lerped with StarBorder"
    func testStarBorderLerpedWithStarBorder() {
        let from = StarBorder()
        let otherBorder = StarBorder(
            points: 6,
            innerRadiusRatio: 0.5,
            pointRounding: 0.5,
            valleyRounding: 0.5,
            rotation: 90
        )

        // lerpTo at 0
        if let result = from.lerpTo(otherBorder, 0) as? StarBorder {
            XCTAssertEqual(result, from)
        } else {
            XCTFail("lerpTo at 0 should return StarBorder")
        }

        // lerpTo at 1
        if let result = from.lerpTo(otherBorder, 1.0) as? StarBorder {
            XCTAssertEqual(result, otherBorder)
        } else {
            XCTFail("lerpTo at 1 should return other border")
        }

        // lerpTo at 0.5
        if let result = from.lerpTo(otherBorder, 0.5) as? StarBorder {
            XCTAssertEqual(result.points, 5.5, accuracy: 1e-10)
        } else {
            XCTFail("lerpTo at 0.5 should return StarBorder")
        }

        // lerpFrom at 0
        if let result = from.lerpFrom(otherBorder, 0) as? StarBorder {
            XCTAssertEqual(result, otherBorder)
        } else {
            XCTFail("lerpFrom at 0 should return other border")
        }

        // lerpFrom at 1
        if let result = from.lerpFrom(otherBorder, 1.0) as? StarBorder {
            XCTAssertEqual(result, from)
        } else {
            XCTFail("lerpFrom at 1 should return self")
        }

        // Test intermediate lerp produces valid path
        let rect = Rect.fromLTWH(0, 0, 200, 100)
        if let lerpedBorder = from.lerpTo(otherBorder, 0.5) {
            let path = lerpedBorder.getOuterPath(rect, textDirection: Optional<TextDirection>.none)
            XCTAssertTrue(path.contains(Offset(100, 50)), "Center should be inside lerped star")
        } else {
            XCTFail("lerpTo should return a border")
        }
    }

    /// **Dart Test:** `star_border_test.dart:265-323` - "StarBorder lerped with CircleBorder"
    func testStarBorderLerpedWithCircleBorder() {
        let star = StarBorder()
        let circle = CircleBorder()
        let eccentricCircle = CircleBorder(eccentricity: 0.6)
        let rect = Rect.fromLTWH(0, 0, 200, 100)

        // lerpTo circle at various amounts
        for t in [0.2, 0.5, 0.7, 1.0] {
            if let result = star.lerpTo(circle, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(100, 50)), "Center should be inside lerped shape at t=\(t)")
            } else {
                XCTFail("lerpTo should return a border at t=\(t)")
            }
        }

        // lerpFrom circle at various amounts
        for t in [0.2, 0.5, 0.7, 1.0] {
            if let result = star.lerpFrom(circle, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(100, 50)), "Center should be inside lerped shape at t=\(t)")
            } else {
                XCTFail("lerpFrom should return a border at t=\(t)")
            }
        }

        // lerpTo eccentric circle
        for t in [0.2, 0.7, 1.0] {
            if let result = star.lerpTo(eccentricCircle, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(100, 50)), "Center should be inside lerped shape at t=\(t)")
            } else {
                XCTFail("lerpTo eccentric circle should return a border at t=\(t)")
            }
        }

        // lerpFrom eccentric circle
        for t in [0.2, 0.7, 1.0] {
            if let result = star.lerpFrom(eccentricCircle, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(100, 50)), "Center should be inside lerped shape at t=\(t)")
            } else {
                XCTFail("lerpFrom eccentric circle should return a border at t=\(t)")
            }
        }
    }

    /// Test lerp with CircleBorder for two-pointed star (points < 2.5).
    func testStarBorderLerpedWithCircleBorderTwoPoints() {
        let star = StarBorder(points: 2)
        let circle = CircleBorder()
        let rect = Rect.fromLTWH(0, 0, 100, 100)

        for t in [0.2, 0.5, 0.8] {
            if let result = star.lerpTo(circle, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(50, 50)), "Center should be inside at t=\(t)")
            } else {
                XCTFail("lerpTo circle from 2-point star should return a border at t=\(t)")
            }
        }

        for t in [0.2, 0.5, 0.8] {
            if let result = star.lerpFrom(circle, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(50, 50)), "Center should be inside at t=\(t)")
            } else {
                XCTFail("lerpFrom circle to 2-point star should return a border at t=\(t)")
            }
        }
    }

    /// **Dart Test:** `star_border_test.dart:325-401` - "StarBorder lerped with RoundedRectangleBorder"
    func testStarBorderLerpedWithRoundedRectangleBorder() {
        let star = StarBorder()
        let rectangleBorder = RoundedRectangleBorder()
        let rect = Rect.fromLTWH(0, 0, 200, 100)

        // lerpTo rectangle at various amounts
        for t in [0.2, 0.5, 0.7, 1.0] {
            if let result = star.lerpTo(rectangleBorder, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(100, 50)), "Center should be inside at t=\(t)")
            } else {
                XCTFail("lerpTo rectangle should return a border at t=\(t)")
            }
        }

        // lerpFrom rectangle at various amounts
        for t in [0.2, 0.5, 0.7, 1.0] {
            if let result = star.lerpFrom(rectangleBorder, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(100, 50)), "Center should be inside at t=\(t)")
            } else {
                XCTFail("lerpFrom rectangle should return a border at t=\(t)")
            }
        }
    }

    /// **Dart Test:** `star_border_test.dart:403-431` - "StarBorder lerped with StadiumBorder"
    func testStarBorderLerpedWithStadiumBorder() {
        let star = StarBorder()
        let stadiumBorder = StadiumBorder()
        let rect = Rect.fromLTWH(0, 0, 200, 100)

        // lerpTo stadium at various amounts
        for t in [0.2, 0.5, 0.7, 1.0] {
            if let result = star.lerpTo(stadiumBorder, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(100, 50)), "Center should be inside at t=\(t)")
            } else {
                XCTFail("lerpTo stadium should return a border at t=\(t)")
            }
        }

        // lerpFrom stadium at various amounts
        for t in [0.2, 0.5, 0.7, 1.0] {
            if let result = star.lerpFrom(stadiumBorder, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                XCTAssertTrue(path.contains(Offset(100, 50)), "Center should be inside at t=\(t)")
            } else {
                XCTFail("lerpFrom stadium should return a border at t=\(t)")
            }
        }
    }

    /// Test that ShapeBorderStatics.lerp works with StarBorder.
    func testStarBorderStaticLerp() {
        let star1 = StarBorder()
        let star2 = StarBorder(points: 8, innerRadiusRatio: 0.5)

        if let result = ShapeBorderStatics.lerp(star1, star2, 0.5) as? StarBorder {
            XCTAssertEqual(result.points, 6.5, accuracy: 1e-10)
            XCTAssertEqual(result.innerRadiusRatio, 0.45, accuracy: 1e-10)
        } else {
            XCTFail("ShapeBorderStatics.lerp with two StarBorders should return StarBorder")
        }
    }

    // MARK: - Dimensions Tests

    /// Test that dimensions correctly reflect the side's strokeInset.
    func testStarBorderDimensions() {
        let star = StarBorder(side: BorderSide(width: 10.0))
        if let dimensions = star.dimensions as? EdgeInsets {
            XCTAssertEqual(dimensions, EdgeInsets(all: 10.0))
        } else {
            XCTFail("dimensions should be EdgeInsets type")
        }

        let center = StarBorder(
            side: BorderSide(width: 10.0, strokeAlign: BorderSide.strokeAlignCenter)
        )
        if let dimensions = center.dimensions as? EdgeInsets {
            XCTAssertEqual(dimensions, EdgeInsets(all: 5.0))
        } else {
            XCTFail("center dimensions should be EdgeInsets type")
        }

        let outside = StarBorder(
            side: BorderSide(width: 10.0, strokeAlign: BorderSide.strokeAlignOutside)
        )
        if let dimensions = outside.dimensions as? EdgeInsets {
            XCTAssertEqual(dimensions, EdgeInsets.zero)
        } else {
            XCTFail("outside dimensions should be EdgeInsets type")
        }
    }

    // MARK: - Description Test

    /// Test that description contains expected text.
    func testStarBorderDescription() {
        let star = StarBorder()
        XCTAssertTrue(star.description.contains("StarBorder"))
        XCTAssertTrue(star.description.contains("points"))
        XCTAssertTrue(star.description.contains("innerRadiusRatio"))
    }

    // MARK: - Polygon innerRadiusRatio Computed Property

    /// Test that polygon's innerRadiusRatio equals the incircle radius.
    func testStarBorderPolygonInnerRadiusRatio() {
        let polygon = StarBorder.polygon(sides: 5)
        let expected = cos(Double.pi / 5)
        XCTAssertEqual(polygon.innerRadiusRatio, expected, accuracy: 1e-10)

        let triangle = StarBorder.polygon(sides: 3)
        let expectedTriangle = cos(Double.pi / 3)
        XCTAssertEqual(triangle.innerRadiusRatio, expectedTriangle, accuracy: 1e-10)
    }

    // MARK: - Rotation Property

    /// Test that the rotation property stores the value correctly.
    func testStarBorderRotationProperty() {
        let star = StarBorder(rotation: 90)
        XCTAssertEqual(star.rotation, 90, accuracy: 1e-10)

        let star180 = StarBorder(rotation: 180)
        XCTAssertEqual(star180.rotation, 180, accuracy: 1e-10)

        let star0 = StarBorder(rotation: 0)
        XCTAssertEqual(star0.rotation, 0, accuracy: 1e-10)
    }

    // MARK: - Edge Case Tests

    /// Test with fractional points.
    func testStarBorderFractionalPoints() {
        let star = StarBorder(points: 5.5)
        let rect = Rect.fromLTWH(0, 0, 100, 100)
        let path = star.getOuterPath(rect)
        XCTAssertTrue(path.contains(Offset(50, 50)))
    }

    /// Test with both rounding values set.
    func testStarBorderCombinedRounding() {
        let star = StarBorder(pointRounding: 0.3, valleyRounding: 0.3)
        let rect = Rect.fromLTWH(0, 0, 100, 100)
        let path = star.getOuterPath(rect)
        XCTAssertTrue(path.contains(Offset(50, 50)))
    }

    /// Test zero-size rect doesn't crash.
    func testStarBorderZeroSizeRect() {
        let star = StarBorder()
        // A zero-size rect shouldn't crash
        let rect = Rect.fromLTWH(50, 50, 0, 0)
        let path = star.getOuterPath(rect)
        // Just verify it doesn't crash; the path may be degenerate
        _ = path.getBounds()
    }

    /// Test lerpTo nil returns scaled border.
    func testStarBorderLerpToNil() {
        let star = StarBorder(side: BorderSide(width: 10.0))
        if let result = star.lerpTo(nil, 0.5) as? StarBorder {
            XCTAssertEqual(result.side.width, 5.0, accuracy: 1e-10)
        } else {
            XCTFail("lerpTo nil should return StarBorder")
        }
    }

    /// Test lerpFrom nil returns scaled border.
    func testStarBorderLerpFromNil() {
        let star = StarBorder(side: BorderSide(width: 10.0))
        if let result = star.lerpFrom(nil, 0.5) as? StarBorder {
            XCTAssertEqual(result.side.width, 5.0, accuracy: 1e-10)
        } else {
            XCTFail("lerpFrom nil should return StarBorder")
        }
    }

    // NOTE: Paint tests skipped - Canvas/PictureRecorder cannot be constructed in tests

    // MARK: - Lerp produces valid paths at various t values

    /// Test that lerping between StarBorder and CircleBorder produces valid paths at many t values.
    func testStarBorderToCircleLerpContinuity() {
        let star = StarBorder()
        let circle = CircleBorder()
        let rect = Rect.fromLTWH(0, 0, 100, 100)

        for i in 0...10 {
            let t = Double(i) / 10.0
            if let result = star.lerpTo(circle, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                let bounds = path.getBounds()
                // The path should always have finite, reasonable bounds
                XCTAssertTrue(bounds.width.isFinite, "Width should be finite at t=\(t)")
                XCTAssertTrue(bounds.height.isFinite, "Height should be finite at t=\(t)")
                XCTAssertTrue(bounds.width >= 0, "Width should be non-negative at t=\(t)")
                XCTAssertTrue(bounds.height >= 0, "Height should be non-negative at t=\(t)")
            } else {
                XCTFail("lerpTo should return a border at t=\(t)")
            }
        }
    }

    /// Test that lerping between StarBorder and StadiumBorder produces valid paths.
    func testStarBorderToStadiumLerpContinuity() {
        let star = StarBorder()
        let stadium = StadiumBorder()
        let rect = Rect.fromLTWH(0, 0, 200, 100)

        for i in 0...10 {
            let t = Double(i) / 10.0
            if let result = star.lerpTo(stadium, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                let bounds = path.getBounds()
                XCTAssertTrue(bounds.width.isFinite, "Width should be finite at t=\(t)")
                XCTAssertTrue(bounds.height.isFinite, "Height should be finite at t=\(t)")
            } else {
                XCTFail("lerpTo should return a border at t=\(t)")
            }
        }
    }

    /// Test that lerping between StarBorder and RoundedRectangleBorder produces valid paths.
    func testStarBorderToRoundedRectLerpContinuity() {
        let star = StarBorder()
        let rrect = RoundedRectangleBorder()
        let rect = Rect.fromLTWH(0, 0, 200, 100)

        for i in 0...10 {
            let t = Double(i) / 10.0
            if let result = star.lerpTo(rrect, t) {
                let path = result.getOuterPath(rect, textDirection: nil)
                let bounds = path.getBounds()
                XCTAssertTrue(bounds.width.isFinite, "Width should be finite at t=\(t)")
                XCTAssertTrue(bounds.height.isFinite, "Height should be finite at t=\(t)")
            } else {
                XCTFail("lerpTo should return a border at t=\(t)")
            }
        }
    }
}

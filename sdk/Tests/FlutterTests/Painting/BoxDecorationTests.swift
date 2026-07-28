// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for BoxDecoration.
///
/// **Dart Test Source:** `packages/flutter/test/painting/box_decoration_test.dart`
///
/// Note: Widget-layer tests using MaterialApp, Canvas matchers (paints..rrect),
/// and golden file tests are skipped. Only painting-layer unit tests are ported.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - BoxDecorationTests

final class BoxDecorationTests: XCTestCase {

    // MARK: - Lerp Tests

    /// **Dart Test:** `box_decoration_test.dart:9-13`
    /// BoxDecoration.lerp identical a,b
    func testLerpIdenticalReturnsOriginal() {
        XCTAssertNil(BoxDecoration.lerp(nil, nil, 0))
        let decoration = BoxDecoration()
        let result = BoxDecoration.lerp(decoration, decoration, 0.5)
        XCTAssertTrue(result === decoration, "lerp of identical objects should return the same instance")
    }

    /// Test lerp with nil `a` returns scaled `b`.
    func testLerpFromNilScalesB() {
        let b = BoxDecoration(color: Color(0xFFFF0000))
        let result = BoxDecoration.lerp(nil, b, 0.5)
        XCTAssertNotNil(result)
        // scale(0.5) on b should produce a color lerped from nil to 0xFFFF0000 at 0.5
        let expected = Color.lerp(nil, Color(0xFFFF0000), 0.5)
        XCTAssertEqual(result!.color, expected)
    }

    /// Test lerp with nil `b` returns scaled `a`.
    func testLerpToNilScalesA() {
        let a = BoxDecoration(color: Color(0xFF00FF00))
        let result = BoxDecoration.lerp(a, nil, 0.5)
        XCTAssertNotNil(result)
        // scale(1.0 - 0.5) = scale(0.5) on a
        let expected = Color.lerp(nil, Color(0xFF00FF00), 0.5)
        XCTAssertEqual(result!.color, expected)
    }

    /// Test lerp at t=0 returns `a`.
    func testLerpAtZeroReturnsA() {
        let a = BoxDecoration(color: Color(0xFF000000))
        let b = BoxDecoration(color: Color(0xFFFFFFFF))
        let result = BoxDecoration.lerp(a, b, 0.0)
        XCTAssertTrue(result === a, "lerp at t=0 should return a")
    }

    /// Test lerp at t=1 returns `b`.
    func testLerpAtOneReturnsB() {
        let a = BoxDecoration(color: Color(0xFF000000))
        let b = BoxDecoration(color: Color(0xFFFFFFFF))
        let result = BoxDecoration.lerp(a, b, 1.0)
        XCTAssertTrue(result === b, "lerp at t=1 should return b")
    }

    // MARK: - BorderRadiusDirectional Hit Test

    /// **Dart Test:** `box_decoration_test.dart:15-62`
    /// BoxDecoration with BorderRadiusDirectional
    func testHitTestWithBorderRadiusDirectionalRTL() {
        let decoration = BoxDecoration(
            color: Color(0xFF000000),
            borderRadius: BorderRadiusDirectional.only(topStart: Radius(circular: 100.0))
        )
        let size = Size(1000.0, 1000.0)

        // In RTL, topStart becomes topRight. Point (10, 10) is in the topLeft
        // corner which has no border radius, so it should hit.
        XCTAssertTrue(
            decoration.hitTest(size, Offset(10.0, 10.0), textDirection: .rtl)
        )
        // In RTL, topStart becomes topRight. Point (990, 10) is in the topRight
        // corner which has a 100px border radius, so it should miss.
        XCTAssertFalse(
            decoration.hitTest(size, Offset(990.0, 10.0), textDirection: .rtl)
        )
    }

    /// **Dart Test:** `box_decoration_test.dart:42-61`
    func testHitTestWithBorderRadiusDirectionalLTR() {
        let decoration = BoxDecoration(
            color: Color(0xFF000000),
            borderRadius: BorderRadiusDirectional.only(topStart: Radius(circular: 100.0))
        )
        let size = Size(1000.0, 1000.0)

        // In LTR, topStart becomes topLeft. Point (10, 10) is in the topLeft
        // corner which has a 100px border radius, so it should miss.
        XCTAssertFalse(
            decoration.hitTest(size, Offset(10.0, 10.0), textDirection: .ltr)
        )
        // In LTR, topStart becomes topLeft. Point (990, 10) is in the topRight
        // corner which has no border radius, so it should hit.
        XCTAssertTrue(
            decoration.hitTest(size, Offset(990.0, 10.0), textDirection: .ltr)
        )
    }

    // MARK: - getClipPath Tests

    /// **Dart Test:** `box_decoration_test.dart:84-94`
    /// BoxDecoration.getClipPath with borderRadius
    func testGetClipPathWithBorderRadius() {
        let radius: Double = 10
        let decoration = BoxDecoration(borderRadius: BorderRadius.circular(radius))
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 20.0)
        let clipPath = decoration.getClipPath(rect, .ltr)

        // Points inside the rounded rectangle (far from corners) should be included.
        XCTAssertTrue(
            clipPath.contains(Offset(30.0, 10.0)),
            "Point (30, 10) in the middle should be inside the clip path"
        )
        XCTAssertTrue(
            clipPath.contains(Offset(50.0, 10.0)),
            "Point (50, 10) in the middle should be inside the clip path"
        )
        // Points in the corners should be excluded due to border radius.
        XCTAssertFalse(
            clipPath.contains(Offset(1.0, 1.0)),
            "Point (1, 1) near the corner should be outside the clip path"
        )
        XCTAssertFalse(
            clipPath.contains(Offset(99.0, 19.0)),
            "Point (99, 19) near the corner should be outside the clip path"
        )
    }

    /// **Dart Test:** `box_decoration_test.dart:96-105`
    /// BoxDecoration.getClipPath with shape BoxShape.circle
    func testGetClipPathWithCircleShape() {
        let decoration = BoxDecoration(shape: .circle)
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 20.0)
        let clipPath = decoration.getClipPath(rect, .ltr)

        // The circle is inscribed into the shortest side (20), centered at (50, 10).
        // radius = 10. Points on the boundary/inside should be included.
        XCTAssertTrue(
            clipPath.contains(Offset(50.0, 0.0)),
            "Point (50, 0) at top of circle should be inside"
        )
        XCTAssertTrue(
            clipPath.contains(Offset(40.0, 10.0)),
            "Point (40, 10) on the circle boundary should be inside"
        )
        // Points outside the circle should be excluded.
        XCTAssertFalse(
            clipPath.contains(Offset(40.0, 0.0)),
            "Point (40, 0) outside the circle should be excluded"
        )
        XCTAssertFalse(
            clipPath.contains(Offset(10.0, 10.0)),
            "Point (10, 10) far outside the circle should be excluded"
        )
    }

    // MARK: - Equality Tests

    /// **Dart Test:** `box_decoration_test.dart:107-118`
    /// BoxDecorations with different blendModes are not equal
    func testDifferentBlendModesNotEqual() {
        let one = BoxDecoration(
            color: Color(0x00000000),
            backgroundBlendMode: .color
        )
        let two = BoxDecoration(
            color: Color(0x00000000),
            backgroundBlendMode: .difference
        )
        XCTAssertNotEqual(one, two)
    }

    /// Test that two BoxDecorations with the same properties are equal.
    func testEqualDecorations() {
        let a = BoxDecoration(
            color: Color(0xFFFF0000),
            shape: .rectangle
        )
        let b = BoxDecoration(
            color: Color(0xFFFF0000),
            shape: .rectangle
        )
        XCTAssertEqual(a, b)
    }

    /// Test that BoxDecorations with different shapes are not equal.
    func testDifferentShapesNotEqual() {
        let a = BoxDecoration(shape: .rectangle)
        let b = BoxDecoration(shape: .circle)
        XCTAssertNotEqual(a, b)
    }

    /// Test that BoxDecorations with different colors are not equal.
    func testDifferentColorsNotEqual() {
        let a = BoxDecoration(color: Color(0xFFFF0000))
        let b = BoxDecoration(color: Color(0xFF00FF00))
        XCTAssertNotEqual(a, b)
    }

    // MARK: - copyWith Tests

    /// Test that copyWith returns a new decoration with the specified changes.
    func testCopyWithColor() {
        let original = BoxDecoration(
            color: Color(0xFFFF0000),
            shape: .rectangle
        )
        let copy = original.copyWith(color: Color(0xFF00FF00))
        XCTAssertEqual(copy.color, Color(0xFF00FF00))
        XCTAssertEqual(copy.shape, .rectangle)
    }

    /// Test that copyWith with no arguments returns an equivalent decoration.
    func testCopyWithNoChanges() {
        let original = BoxDecoration(
            color: Color(0xFFFF0000),
            shape: .circle
        )
        let copy = original.copyWith()
        XCTAssertEqual(copy.color, original.color)
        XCTAssertEqual(copy.shape, original.shape)
    }

    /// Test that copyWith changes shape.
    func testCopyWithShape() {
        let original = BoxDecoration(shape: .rectangle)
        let copy = original.copyWith(shape: .circle)
        XCTAssertEqual(copy.shape, .circle)
    }

    // MARK: - scale Tests

    /// Test that scale produces a scaled decoration.
    func testScale() {
        let decoration = BoxDecoration(color: Color(0xFFFF0000))
        let scaled = decoration.scale(0.5)
        let expectedColor = Color.lerp(nil, Color(0xFFFF0000), 0.5)
        XCTAssertEqual(scaled.color, expectedColor)
    }

    /// Test that scale with factor 0 produces nil/zero values.
    func testScaleZero() {
        let decoration = BoxDecoration(color: Color(0xFFFF0000))
        let scaled = decoration.scale(0.0)
        let expectedColor = Color.lerp(nil, Color(0xFFFF0000), 0.0)
        XCTAssertEqual(scaled.color, expectedColor)
    }

    // MARK: - isComplex Tests

    /// Test that isComplex is true when boxShadow is present.
    func testIsComplexWithShadow() {
        let decoration = BoxDecoration(
            boxShadow: [BoxShadow(color: Color(0xFF000000), blurRadius: 5.0)]
        )
        XCTAssertTrue(decoration.isComplex)
    }

    /// Test that isComplex is false when there is no boxShadow.
    func testIsComplexWithoutShadow() {
        let decoration = BoxDecoration(color: Color(0xFFFF0000))
        XCTAssertFalse(decoration.isComplex)
    }

    // MARK: - padding Tests

    /// Test that padding returns EdgeInsets.zero when there is no border.
    func testPaddingWithNoBorder() {
        let decoration = BoxDecoration()
        let padding = decoration.padding
        if let edgeInsets = padding as? EdgeInsets {
            XCTAssertEqual(edgeInsets, EdgeInsets.zero)
        } else {
            XCTFail("Expected EdgeInsets.zero for decoration without border")
        }
    }

    /// Test that padding returns border dimensions when a border is provided.
    func testPaddingWithBorder() {
        let border = Border(
            top: BorderSide(width: 2.0),
            right: BorderSide(width: 3.0),
            bottom: BorderSide(width: 4.0),
            left: BorderSide(width: 5.0)
        )
        let decoration = BoxDecoration(border: border)
        let padding = decoration.padding
        if let edgeInsets = padding as? EdgeInsets {
            // strokeInset for default strokeAlign (inside) with given widths
            XCTAssertEqual(edgeInsets.top, border.top.strokeInset)
            XCTAssertEqual(edgeInsets.right, border.right.strokeInset)
            XCTAssertEqual(edgeInsets.bottom, border.bottom.strokeInset)
            XCTAssertEqual(edgeInsets.left, border.left.strokeInset)
        } else {
            XCTFail("Expected EdgeInsets for decoration with Border")
        }
    }

    // MARK: - hitTest Tests

    /// Test hitTest for circle shape.
    func testHitTestCircle() {
        let decoration = BoxDecoration(shape: .circle)
        let size = Size(100.0, 100.0)

        // Center of circle should hit.
        XCTAssertTrue(decoration.hitTest(size, Offset(50.0, 50.0)))

        // Point at the edge of the circle should hit.
        XCTAssertTrue(decoration.hitTest(size, Offset(50.0, 0.0)))

        // Point just inside the circle (diagonally) should hit.
        // Distance from center: sqrt(30^2 + 30^2) ~= 42.4, radius = 50
        XCTAssertTrue(decoration.hitTest(size, Offset(80.0, 50.0)))
    }

    /// Test hitTest for rectangle shape with no border radius.
    func testHitTestRectangle() {
        let decoration = BoxDecoration(shape: .rectangle)
        let size = Size(100.0, 100.0)

        // All points within the rect should hit.
        XCTAssertTrue(decoration.hitTest(size, Offset(0.0, 0.0)))
        XCTAssertTrue(decoration.hitTest(size, Offset(50.0, 50.0)))
        XCTAssertTrue(decoration.hitTest(size, Offset(99.0, 99.0)))
    }

    /// Test hitTest for rectangle with border radius.
    func testHitTestRectangleWithBorderRadius() {
        let decoration = BoxDecoration(
            borderRadius: BorderRadius.circular(50.0),
            shape: .rectangle
        )
        let size = Size(100.0, 100.0)

        // Center should hit.
        XCTAssertTrue(decoration.hitTest(size, Offset(50.0, 50.0)))

        // Corner point (1, 1) should miss because of 50px radius.
        XCTAssertFalse(decoration.hitTest(size, Offset(1.0, 1.0)))
    }

    // MARK: - Hashable Tests

    /// Test that equal decorations produce the same hash value.
    func testHashConsistency() {
        let a = BoxDecoration(
            color: Color(0xFFFF0000),
            shape: .rectangle
        )
        let b = BoxDecoration(
            color: Color(0xFFFF0000),
            shape: .rectangle
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - createBoxPainter Tests

    /// Test that createBoxPainter returns a valid painter.
    func testCreateBoxPainter() {
        let decoration = BoxDecoration(color: Color(0xFFFF0000))
        let painter = decoration.createBoxPainter()
        XCTAssertNotNil(painter, "createBoxPainter should return a non-nil painter")
    }

    // MARK: - debugAssertIsValid Tests

    /// Test that debugAssertIsValid returns true for valid configurations.
    func testDebugAssertIsValidRectangle() {
        let decoration = BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            shape: .rectangle
        )
        XCTAssertTrue(decoration.debugAssertIsValid())
    }

    func testDebugAssertIsValidCircleNoBorderRadius() {
        let decoration = BoxDecoration(shape: .circle)
        XCTAssertTrue(decoration.debugAssertIsValid())
    }

    // MARK: - lerpFrom / lerpTo Tests

    /// Test lerpFrom with nil returns scaled self.
    func testLerpFromNil() {
        let decoration = BoxDecoration(color: Color(0xFFFF0000))
        let result = decoration.lerpFrom(nil, t: 0.5) as? BoxDecoration
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.color, Color.lerp(nil, Color(0xFFFF0000), 0.5))
    }

    /// Test lerpFrom with another BoxDecoration.
    func testLerpFromBoxDecoration() {
        let a = BoxDecoration(color: Color(0xFF000000))
        let b = BoxDecoration(color: Color(0xFFFFFFFF))
        let result = b.lerpFrom(a, t: 0.5) as? BoxDecoration
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.color, Color.lerp(Color(0xFF000000), Color(0xFFFFFFFF), 0.5))
    }

    /// Test lerpTo with nil returns scaled self.
    func testLerpToNil() {
        let decoration = BoxDecoration(color: Color(0xFFFF0000))
        let result = decoration.lerpTo(nil, t: 0.5) as? BoxDecoration
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.color, Color.lerp(nil, Color(0xFFFF0000), 0.5))
    }

    /// Test lerpTo with another BoxDecoration.
    func testLerpToBoxDecoration() {
        let a = BoxDecoration(color: Color(0xFF000000))
        let b = BoxDecoration(color: Color(0xFFFFFFFF))
        let result = a.lerpTo(b, t: 0.5) as? BoxDecoration
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.color, Color.lerp(Color(0xFF000000), Color(0xFFFFFFFF), 0.5))
    }

    /// Test lerpFrom with an incompatible decoration returns nil.
    func testLerpFromIncompatible() {
        let a = FlutterLogoDecoration()
        let b = BoxDecoration(color: Color(0xFFFF0000))
        let result = b.lerpFrom(a, t: 0.5)
        XCTAssertNil(result)
    }

    /// Test lerpTo with an incompatible decoration returns nil.
    func testLerpToIncompatible() {
        let a = BoxDecoration(color: Color(0xFFFF0000))
        let b = FlutterLogoDecoration()
        let result = a.lerpTo(b, t: 0.5)
        XCTAssertNil(result)
    }

    // MARK: - Lerp with shape Tests

    /// Test that lerp picks shape from `a` when t < 0.5.
    func testLerpShapePicksABeforeHalf() {
        let a = BoxDecoration(shape: .rectangle)
        let b = BoxDecoration(shape: .circle)
        let result = BoxDecoration.lerp(a, b, 0.25)
        XCTAssertEqual(result!.shape, .rectangle)
    }

    /// Test that lerp picks shape from `b` when t >= 0.5.
    func testLerpShapePicksBAtOrAfterHalf() {
        let a = BoxDecoration(shape: .rectangle)
        let b = BoxDecoration(shape: .circle)
        let result = BoxDecoration.lerp(a, b, 0.5)
        XCTAssertEqual(result!.shape, .circle)
    }
}

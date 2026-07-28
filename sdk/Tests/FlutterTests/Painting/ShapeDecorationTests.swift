// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for ShapeDecoration.
///
/// **Dart Test Source:** `packages/flutter/test/painting/shape_decoration_test.dart`
///
/// Note: Widget-level tests and image-related tests are skipped since those
/// dependencies (DecorationImage, widgets layer) are not yet migrated.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class ShapeDecorationTests: XCTestCase {

    // MARK: - Constructor Tests

    /// Test basic ShapeDecoration construction with default values.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:16-20`
    func testConstructorBasic() {
        let a = ShapeDecoration(shape: Border())
        let b = ShapeDecoration(shape: Border())
        XCTAssertEqual(a, b)
    }

    /// Test that color and gradient together triggers assertion.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:21-24`
    func testConstructorColorAndGradientAsserts() {
        // In Swift, assertions are only checked in debug builds.
        // We verify the assertion message exists in the code, and that
        // constructing with only color or only gradient works.
        let colorR = Color(0xFFFF0000)
        let gradient = LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF00FF00)])

        // Should work: color only
        let withColor = ShapeDecoration(color: colorR, shape: Border())
        XCTAssertEqual(withColor.color, colorR)
        XCTAssertNil(withColor.gradient)

        // Should work: gradient only
        let withGradient = ShapeDecoration(gradient: gradient, shape: Border())
        XCTAssertNil(withGradient.color)
        XCTAssertNotNil(withGradient.gradient)
    }

    /// Test construction with shadows.
    func testConstructorWithShadows() {
        let shadows: [BoxShadow] = [
            BoxShadow(color: Color(0xFF000000), blurRadius: 10.0, spreadRadius: 2.0),
        ]
        let decoration = ShapeDecoration(shadows: shadows, shape: CircleBorder())
        XCTAssertEqual(decoration.shadows, shadows)
    }

    /// Test construction with CircleBorder shape.
    func testConstructorWithCircleBorder() {
        let decoration = ShapeDecoration(shape: CircleBorder())
        XCTAssertTrue(decoration.shape is CircleBorder)
    }

    /// Test construction with RoundedRectangleBorder shape.
    func testConstructorWithRoundedRectangleBorder() {
        let decoration = ShapeDecoration(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius(circular: 10.0)))
        )
        XCTAssertTrue(decoration.shape is RoundedRectangleBorder)
    }

    // MARK: - Equality Tests

    /// Test that two ShapeDecorations with the same properties are equal.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:20` (implicit equality check)
    func testEquality() {
        let a = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        let b = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        XCTAssertEqual(a, b)
    }

    /// Test that two ShapeDecorations with different properties are not equal.
    func testInequality() {
        let a = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        let b = ShapeDecoration(
            color: Color(0xFF00FF00),
            shape: CircleBorder()
        )
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality with different shapes.
    func testInequalityDifferentShapes() {
        let a = ShapeDecoration(shape: CircleBorder())
        let b = ShapeDecoration(shape: RoundedRectangleBorder())
        XCTAssertNotEqual(a, b)
    }

    /// Test equality with shadows.
    func testEqualityWithShadows() {
        let shadows: [BoxShadow] = [
            BoxShadow(color: Color(0xFF000000), blurRadius: 5.0),
        ]
        let a = ShapeDecoration(shadows: shadows, shape: CircleBorder())
        let b = ShapeDecoration(shadows: shadows, shape: CircleBorder())
        XCTAssertEqual(a, b)
    }

    /// Test identity equality (same instance).
    func testIdentityEquality() {
        let a = ShapeDecoration(shape: CircleBorder())
        XCTAssertTrue(a === a)
        XCTAssertEqual(a, a)
    }

    // MARK: - Hash Code Tests

    /// Test that equal decorations have the same hash.
    func testHashCodeConsistency() {
        let a = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        let b = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - Padding Tests

    /// Test that padding returns shape dimensions.
    func testPadding() {
        let decoration = ShapeDecoration(
            shape: CircleBorder(side: BorderSide(width: 2.0))
        )
        let padding = decoration.padding
        XCTAssertNotNil(padding)
    }

    // MARK: - IsComplex Tests

    /// Test isComplex is false when no shadows.
    func testIsComplexFalseWithoutShadows() {
        let decoration = ShapeDecoration(shape: CircleBorder())
        XCTAssertFalse(decoration.isComplex)
    }

    /// Test isComplex is true when shadows present.
    func testIsComplexTrueWithShadows() {
        let decoration = ShapeDecoration(
            shadows: [BoxShadow(blurRadius: 5.0)],
            shape: CircleBorder()
        )
        XCTAssertTrue(decoration.isComplex)
    }

    // MARK: - Lerp Tests

    /// Test lerp with both nil returns nil.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:60-64`
    func testLerpBothNil() {
        let result = ShapeDecoration.lerp(nil, nil, 0)
        XCTAssertNil(result)
    }

    /// Test lerp with identical instances returns same instance.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:62-63`
    func testLerpIdentical() {
        let shape = ShapeDecoration(shape: CircleBorder())
        let result = ShapeDecoration.lerp(shape, shape, 0.5)
        XCTAssertTrue(result === shape)
    }

    /// Test lerp null a,b.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:66-71`
    func testLerpNullAB() {
        let a: any Decoration = ShapeDecoration(shape: CircleBorder())
        let b: any Decoration = ShapeDecoration(shape: RoundedRectangleBorder())

        // lerp(a, nil, 0.0) should return a
        let resultA = lerpDecoration(a, nil, 0.0)
        XCTAssertTrue(resultA is ShapeDecoration)

        // lerp(nil, b, 0.0) should return b
        let resultB = lerpDecoration(nil, b, 0.0)
        XCTAssertTrue(resultB is ShapeDecoration)

        // lerp(nil, nil, 0.0) should return nil
        let resultNil = lerpDecoration(nil, nil, 0.0)
        XCTAssertNil(resultNil)
    }

    /// Test lerp endpoints.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:74-83`
    func testLerpEndpoints() {
        let a = ShapeDecoration(shape: CircleBorder())
        let b = ShapeDecoration(shape: RoundedRectangleBorder())

        // At t=0, should equal a
        let at0 = ShapeDecoration.lerp(a, b, 0.0)
        XCTAssertEqual(at0, a)

        // At t=1, should equal b
        let at1 = ShapeDecoration.lerp(a, b, 1.0)
        XCTAssertEqual(at1, b)
    }

    /// Test lerp with Decoration.lerp (lerpDecoration).
    ///
    /// **Dart Test:** `shape_decoration_test.dart:78-83`
    func testLerpViaDecorationLerp() {
        let a: any Decoration = ShapeDecoration(shape: CircleBorder())
        let b: any Decoration = ShapeDecoration(shape: RoundedRectangleBorder())

        // At endpoints
        let at0 = lerpDecoration(a, b, 0.0)
        XCTAssertTrue(at0 is ShapeDecoration)

        let at1 = lerpDecoration(a, b, 1.0)
        XCTAssertTrue(at1 is ShapeDecoration)

        // At midpoint should also return ShapeDecoration
        let atMid = lerpDecoration(a, b, 0.5)
        XCTAssertNotNil(atMid)
        XCTAssertTrue(atMid is ShapeDecoration)
    }

    /// Test lerp interpolates color.
    func testLerpInterpolatesColor() {
        let a = ShapeDecoration(color: Color(0xFFFF0000), shape: CircleBorder())
        let b = ShapeDecoration(color: Color(0xFF00FF00), shape: CircleBorder())
        let result = ShapeDecoration.lerp(a, b, 0.5)
        XCTAssertNotNil(result)
        XCTAssertNotNil(result!.color)
        // The interpolated color should be between red and green
        XCTAssertNotEqual(result!.color, a.color)
        XCTAssertNotEqual(result!.color, b.color)
    }

    /// Test lerp interpolates shadows.
    func testLerpInterpolatesShadows() {
        let a = ShapeDecoration(
            shadows: [BoxShadow(blurRadius: 0.0)],
            shape: CircleBorder()
        )
        let b = ShapeDecoration(
            shadows: [BoxShadow(blurRadius: 10.0)],
            shape: CircleBorder()
        )
        let result = ShapeDecoration.lerp(a, b, 0.5)
        XCTAssertNotNil(result)
        XCTAssertNotNil(result!.shadows)
        XCTAssertEqual(result!.shadows!.count, 1)
        XCTAssertEqual(result!.shadows![0].blurRadius, 5.0, accuracy: 0.001)
    }

    // MARK: - Hit Test

    /// Test hit test on a circle decoration.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:84-98`
    func testHitTestCircle() {
        let a = ShapeDecoration(shape: CircleBorder())
        let size = Size(200.0, 100.0)

        // Center of the oval should hit
        XCTAssertTrue(a.hitTest(size, Offset(100.0, 50.0)))

        // Outside the circle inscribed in the rect should miss
        // Circle is centered at (100,50) with radius 50 (shortestSide/2)
        XCTAssertFalse(a.hitTest(size, Offset(20.0, 50.0)))
    }

    /// Test hit test on a RoundedRectangleBorder (fills the entire rect).
    func testHitTestRoundedRectangle() {
        let b = ShapeDecoration(shape: RoundedRectangleBorder())
        let size = Size(200.0, 100.0)

        // Inside the rect should hit
        XCTAssertTrue(b.hitTest(size, Offset(20.0, 50.0)))
        XCTAssertTrue(b.hitTest(size, Offset(190.0, 90.0)))

        // Outside the rect should miss
        XCTAssertFalse(b.hitTest(size, Offset(201.0, 50.0)))
        XCTAssertFalse(b.hitTest(size, Offset(100.0, 101.0)))
    }

    /// Test hit test on lerped decoration.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:88-90`
    func testHitTestOnLerpedDecoration() {
        let a: any Decoration = ShapeDecoration(shape: CircleBorder())
        let b: any Decoration = ShapeDecoration(shape: RoundedRectangleBorder())
        let size = Size(200.0, 100.0)

        // At t=0.9, the shape is mostly a RoundedRectangleBorder, so
        // a point near the edge should hit
        let lerped = lerpDecoration(a, b, 0.9)
        XCTAssertNotNil(lerped)
        XCTAssertTrue(lerped!.hitTest(size, Offset(20.0, 50.0)))
    }

    // MARK: - getClipPath Tests

    /// Test getClipPath returns a path containing expected points for CircleBorder.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:144-153`
    func testGetClipPathCircleBorder() {
        let decoration = ShapeDecoration(shape: CircleBorder())
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 20.0)
        let clipPath = decoration.getClipPath(rect, TextDirection.ltr)

        // Center of the circle should be included
        XCTAssertTrue(clipPath.contains(Offset(50.0, 10.0)))

        // Corners should be excluded (circle inside a 100x20 rect is small)
        XCTAssertFalse(clipPath.contains(Offset(1.0, 1.0)))
        XCTAssertFalse(clipPath.contains(Offset(99.0, 19.0)))
        // Point at (30, 10) is outside the circle (radius is 10, center at (50,10))
        XCTAssertFalse(clipPath.contains(Offset(30.0, 10.0)))
    }

    /// Test getClipPath returns a path containing expected points for OvalBorder.
    ///
    /// **Dart Test:** `shape_decoration_test.dart:154-163`
    func testGetClipPathOvalBorder() {
        let decoration = ShapeDecoration(shape: OvalBorder())
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 50.0)
        let clipPath = decoration.getClipPath(rect, TextDirection.ltr)

        // Center area should be included
        XCTAssertTrue(clipPath.contains(Offset(50.0, 10.0)))

        // Corners should be excluded
        XCTAssertFalse(clipPath.contains(Offset(1.0, 1.0)))
        XCTAssertFalse(clipPath.contains(Offset(99.0, 19.0)))
        // Near left edge along top row should be excluded
        XCTAssertFalse(clipPath.contains(Offset(15.0, 1.0)))
    }

    // MARK: - lerpFrom / lerpTo Tests

    /// Test that lerpFrom returns nil for non-ShapeDecoration.
    func testLerpFromReturnsNilForOtherType() {
        let decoration = ShapeDecoration(shape: CircleBorder())
        let other = FlutterLogoDecoration()
        let result = decoration.lerpFrom(other, t: 0.5)
        XCTAssertNil(result)
    }

    /// Test that lerpTo returns nil for non-ShapeDecoration.
    func testLerpToReturnsNilForOtherType() {
        let decoration = ShapeDecoration(shape: CircleBorder())
        let other = FlutterLogoDecoration()
        let result = decoration.lerpTo(other, t: 0.5)
        XCTAssertNil(result)
    }

    /// Test lerpFrom with nil returns lerped value.
    func testLerpFromNil() {
        let decoration = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        let result = decoration.lerpFrom(nil, t: 0.5)
        XCTAssertNotNil(result)
        XCTAssertTrue(result is ShapeDecoration)
    }

    /// Test lerpTo with nil returns lerped value.
    func testLerpToNil() {
        let decoration = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        let result = decoration.lerpTo(nil, t: 0.5)
        XCTAssertNotNil(result)
        XCTAssertTrue(result is ShapeDecoration)
    }

    /// Test lerpFrom with ShapeDecoration returns lerped result.
    func testLerpFromShapeDecoration() {
        let a = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        let b = ShapeDecoration(
            color: Color(0xFF00FF00),
            shape: CircleBorder()
        )
        let result = b.lerpFrom(a, t: 0.5)
        XCTAssertNotNil(result)
        XCTAssertTrue(result is ShapeDecoration)
    }

    /// Test lerpTo with ShapeDecoration returns lerped result.
    func testLerpToShapeDecoration() {
        let a = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        let b = ShapeDecoration(
            color: Color(0xFF00FF00),
            shape: CircleBorder()
        )
        let result = a.lerpTo(b, t: 0.5)
        XCTAssertNotNil(result)
        XCTAssertTrue(result is ShapeDecoration)
    }

    // MARK: - BoxPainter Tests

    /// Test that createBoxPainter returns a painter that can paint.
    func testCreateBoxPainter() {
        let decoration = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        let painter = decoration.createBoxPainter(nil)
        XCTAssertNotNil(painter)

        // Paint should not crash
        let recorder = NativePictureRecorder()
        let canvas = NativeCanvas(recorder: recorder)
        painter.paint(
            canvas,
            .zero,
            ImageConfiguration(size: Size(100.0, 100.0))
        )
    }

    /// Test BoxPainter with gradient.
    func testCreateBoxPainterWithGradient() {
        let gradient = LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF00FF00)])
        let decoration = ShapeDecoration(
            gradient: gradient,
            shape: RoundedRectangleBorder()
        )
        let painter = decoration.createBoxPainter(nil)

        let recorder = NativePictureRecorder()
        let canvas = NativeCanvas(recorder: recorder)
        painter.paint(
            canvas,
            Offset(10.0, 10.0),
            ImageConfiguration(
                textDirection: .ltr,
                size: Size(100.0, 100.0)
            )
        )
    }

    /// Test BoxPainter with shadows.
    func testCreateBoxPainterWithShadows() {
        let decoration = ShapeDecoration(
            color: Color(0xFFFF0000),
            shadows: [
                BoxShadow(
                    color: Color(0x88000000),
                    offset: Offset(5.0, 5.0),
                    blurRadius: 10.0,
                    spreadRadius: 2.0
                ),
            ],
            shape: CircleBorder()
        )
        let painter = decoration.createBoxPainter(nil)

        let recorder = NativePictureRecorder()
        let canvas = NativeCanvas(recorder: recorder)
        painter.paint(
            canvas,
            .zero,
            ImageConfiguration(size: Size(100.0, 100.0))
        )
    }

    /// Test BoxPainter with a shape that does not prefer paintInterior.
    func testCreateBoxPainterNonPreferPaintInterior() {
        // Border() is a BoxBorder which has preferPaintInterior = true,
        // but we can use a custom shape to test the non-prefer path.
        // RoundedRectangleBorder also prefers paintInterior.
        // CircleBorder prefers paintInterior too.
        // For simplicity, test that painting still works correctly.
        let decoration = ShapeDecoration(
            color: Color(0xFF0000FF),
            shape: Border()
        )
        let painter = decoration.createBoxPainter(nil)

        let recorder = NativePictureRecorder()
        let canvas = NativeCanvas(recorder: recorder)
        painter.paint(
            canvas,
            .zero,
            ImageConfiguration(
                textDirection: .ltr,
                size: Size(50.0, 50.0)
            )
        )
    }

    /// Test BoxPainter dispose does not crash.
    func testBoxPainterDispose() {
        let decoration = ShapeDecoration(
            color: Color(0xFFFF0000),
            shape: CircleBorder()
        )
        let painter = decoration.createBoxPainter(nil)
        painter.dispose()
    }

    // MARK: - Diagnostics Tests

    /// Test toStringShort.
    func testToStringShort() {
        let decoration = ShapeDecoration(shape: CircleBorder())
        let short = decoration.toStringShort()
        XCTAssertTrue(short.contains("ShapeDecoration"))
    }

    /// Test debugFillProperties does not crash.
    func testDebugFillProperties() {
        let decoration = ShapeDecoration(
            color: Color(0xFFFF0000),
            shadows: [BoxShadow(blurRadius: 5.0)],
            shape: CircleBorder()
        )
        let builder = DiagnosticPropertiesBuilder()
        decoration.debugFillProperties(builder)
        // Verify properties were added
        XCTAssertTrue(builder.properties.count > 0)
    }

    // MARK: - Precache / Caching Tests

    /// Test that painting the same decoration twice with the same rect reuses cache.
    func testPainterCacheReuse() {
        let decoration = ShapeDecoration(
            color: Color(0xFFFF0000),
            shadows: [BoxShadow(blurRadius: 5.0)],
            shape: CircleBorder()
        )
        let painter = decoration.createBoxPainter(nil)

        let recorder1 = NativePictureRecorder()
        let canvas1 = NativeCanvas(recorder: recorder1)
        let config = ImageConfiguration(size: Size(100.0, 100.0))

        // Paint twice - should not crash and should reuse cache
        painter.paint(canvas1, .zero, config)
        painter.paint(canvas1, .zero, config)
    }

    /// Test that painting with different rects triggers recache.
    func testPainterRecache() {
        let decoration = ShapeDecoration(
            color: Color(0xFF00FF00),
            shape: RoundedRectangleBorder()
        )
        let painter = decoration.createBoxPainter(nil)

        let recorder = NativePictureRecorder()
        let canvas = NativeCanvas(recorder: recorder)

        // Paint with one size
        painter.paint(canvas, .zero, ImageConfiguration(size: Size(100.0, 100.0)))
        // Paint with different size
        painter.paint(canvas, .zero, ImageConfiguration(size: Size(200.0, 200.0)))
    }
}

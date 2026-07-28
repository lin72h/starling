// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for BoxBorder, Border, and BorderDirectional.
///
/// **Dart Test Source:**
/// - `packages/flutter/test/painting/border_test.dart`
/// - `packages/flutter/test/painting/border_rtl_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Mock Canvas

/// A mock Canvas that records method calls for verification.
final class BoxBorderMockCanvas: Canvas {
    enum Call {
        case drawRect(Rect, Paint)
        case drawRRect(RRect, Paint)
        case drawDRRect(RRect, RRect, Paint)
        case drawCircle(Offset, Double, Paint)
        case drawPath(Path, Paint)
    }

    var calls: [Call] = []

    func save() {}
    func saveLayer(_ bounds: Rect?, _ paint: Paint) {}
    func restore() {}
    func restoreToCount(_ count: Int) {}
    func getSaveCount() -> Int { return 1 }
    func translate(_ dx: Double, _ dy: Double) {}
    func scale(_ sx: Double, _ sy: Double?) {}
    func rotate(_ radians: Double) {}
    func skew(_ sx: Double, _ sy: Double) {}
    func transform(_ matrix4: [Double]) {}
    func getTransform() -> [Double] { return [Double](repeating: 0, count: 16) }
    func clipRect(_ rect: Rect, clipOp: ClipOp, doAntiAlias: Bool) {}
    func clipRRect(_ rrect: RRect, doAntiAlias: Bool) {}
    func clipRSuperellipse(_ rsuperellipse: RSuperellipse, doAntiAlias: Bool) {}
    func clipPath(_ path: Path, doAntiAlias: Bool) {}
    func getLocalClipBounds() -> Rect { return .zero }
    func getDestinationClipBounds() -> Rect { return .zero }
    func drawColor(_ color: Color, _ blendMode: BlendMode) {}
    func drawLine(_ p1: Offset, _ p2: Offset, _ paint: Paint) {}
    func drawPaint(_ paint: Paint) {}

    func drawRect(_ rect: Rect, _ paint: Paint) {
        calls.append(.drawRect(rect, paint))
    }

    func drawRRect(_ rrect: RRect, _ paint: Paint) {
        calls.append(.drawRRect(rrect, paint))
    }

    func drawDRRect(_ outer: RRect, _ inner: RRect, _ paint: Paint) {
        calls.append(.drawDRRect(outer, inner, paint))
    }

    func drawRSuperellipse(_ rsuperellipse: RSuperellipse, _ paint: Paint) {}
    func drawOval(_ rect: Rect, _ paint: Paint) {}

    func drawCircle(_ c: Offset, _ radius: Double, _ paint: Paint) {
        calls.append(.drawCircle(c, radius, paint))
    }

    func drawArc(_ rect: Rect, _ startAngle: Double, _ sweepAngle: Double, _ useCenter: Bool, _ paint: Paint) {}

    func drawPath(_ path: Path, _ paint: Paint) {
        calls.append(.drawPath(path, paint))
    }

    func drawImage(_ image: Image, _ offset: Offset, _ paint: Paint) {}
    func drawImageRect(_ image: Image, _ src: Rect, _ dst: Rect, _ paint: Paint) {}
    func drawImageNine(_ image: Image, _ center: Rect, _ dst: Rect, _ paint: Paint) {}
    func drawPicture(_ picture: any FlutterSwiftBridge.Picture) {}
    func drawParagraph(_ paragraph: any Paragraph, _ offset: Offset) {}
    func drawPoints(_ pointMode: PointMode, _ points: [Offset], _ paint: Paint) {}
    func drawRawPoints(_ pointMode: PointMode, _ points: [Float], _ paint: Paint) {}
    func drawVertices(_ vertices: Vertices, _ blendMode: BlendMode, _ paint: Paint) {}
    func drawAtlas(_ atlas: Image, _ transforms: [RSTransform], _ rects: [Rect], _ colors: [Color]?, _ blendMode: BlendMode?, _ cullRect: Rect?, _ paint: Paint) {}
    func drawRawAtlas(_ atlas: Image, _ rstTransforms: [Float], _ rects: [Float], _ colors: [Int32]?, _ blendMode: BlendMode?, _ cullRect: Rect?, _ paint: Paint) {}
    func drawShadow(_ path: Path, _ color: Color, _ elevation: Double, _ transparentOccluder: Bool) {}
}

// MARK: - Helper Functions

/// Checks if two BorderSide values match within a color tolerance.
private func sideMatches(_ x: BorderSide, _ y: BorderSide) -> Bool {
    let limit: Double = 1.0 / 255.0
    let da: Double = Swift.abs(x.color.a - y.color.a)
    let dr: Double = Swift.abs(x.color.r - y.color.r)
    let dg: Double = Swift.abs(x.color.g - y.color.g)
    let db: Double = Swift.abs(x.color.b - y.color.b)
    guard da < limit else { return false }
    guard dr < limit else { return false }
    guard dg < limit else { return false }
    guard db < limit else { return false }
    guard x.width == y.width else { return false }
    guard x.style == y.style else { return false }
    guard x.strokeAlign == y.strokeAlign else { return false }
    return true
}

/// Checks if two Border values match within a color tolerance.
private func borderMatches(_ item: BoxBorder, _ target: BoxBorder) -> Bool {
    guard let itemBorder = item as? Border, let targetBorder = target as? Border else {
        return false
    }
    return sideMatches(itemBorder.top, targetBorder.top) &&
        sideMatches(itemBorder.right, targetBorder.right) &&
        sideMatches(itemBorder.bottom, targetBorder.bottom) &&
        sideMatches(itemBorder.left, targetBorder.left)
}

/// Checks if two BorderDirectional values match within a color tolerance.
private func borderDirectionalMatches(_ item: BoxBorder, _ target: BoxBorder) -> Bool {
    guard let itemDir = item as? BorderDirectional,
          let targetDir = target as? BorderDirectional else {
        return false
    }
    return sideMatches(itemDir.top, targetDir.top) &&
        sideMatches(itemDir.start, targetDir.start) &&
        sideMatches(itemDir.bottom, targetDir.bottom) &&
        sideMatches(itemDir.end, targetDir.end)
}

// MARK: - Tests

final class BoxBorderTests: XCTestCase {

    // MARK: - BoxShape Tests

    /// Test BoxShape enum values.
    func testBoxShapeValues() {
        XCTAssertNotEqual(BoxShape.rectangle, BoxShape.circle)
    }

    // MARK: - Border Constructor Tests

    /// **Dart Test:** `border_test.dart` - "Border.fromBorderSide constructor"
    func testBorderFromBorderSideConstructor() {
        let side = BorderSide()
        let border = Border.fromBorderSide(side)
        XCTAssertEqual(border.left, side)
        XCTAssertEqual(border.top, side)
        XCTAssertEqual(border.right, side)
        XCTAssertEqual(border.bottom, side)
    }

    /// **Dart Test:** `border_test.dart` - "Border.symmetric constructor"
    func testBorderSymmetricConstructor() {
        let side1 = BorderSide(color: Color(0xFFFFFFFF))
        let side2 = BorderSide()
        let border = Border.symmetric(vertical: side1, horizontal: side2)
        XCTAssertEqual(border.left, side1)
        XCTAssertEqual(border.top, side2)
        XCTAssertEqual(border.right, side1)
        XCTAssertEqual(border.bottom, side2)
    }

    // MARK: - Border.merge Tests

    /// **Dart Test:** `border_test.dart` - "Border.merge"
    func testBorderMerge() {
        let magenta3 = BorderSide(color: Color(0xFFFF00FF), width: 3.0)
        let magenta6 = BorderSide(color: Color(0xFFFF00FF), width: 6.0)
        let yellow2 = BorderSide(color: Color(0xFFFFFF00), width: 2.0)
        let yellowNone0 = BorderSide(
            color: Color(0xFFFFFF00),
            width: 0.0,
            style: .none
        )

        XCTAssertEqual(
            Border.merge(Border(top: yellow2), Border(right: magenta3)),
            Border(top: yellow2, right: magenta3)
        )
        XCTAssertEqual(
            Border.merge(Border(bottom: magenta3), Border(bottom: magenta3)),
            Border(bottom: magenta6)
        )
        XCTAssertEqual(
            Border.merge(Border(right: yellowNone0, left: magenta3), Border(right: yellow2)),
            Border(right: yellow2, left: magenta3)
        )
        XCTAssertEqual(
            Border.merge(Border(), Border()),
            Border()
        )
    }

    // MARK: - Border.add Tests

    /// **Dart Test:** `border_test.dart` - "Border.add"
    func testBorderAdd() {
        let magenta3 = BorderSide(color: Color(0xFFFF00FF), width: 3.0)
        let magenta6 = BorderSide(color: Color(0xFFFF00FF), width: 6.0)
        let yellow2 = BorderSide(color: Color(0xFFFFFF00), width: 2.0)
        let yellowNone0 = BorderSide(
            color: Color(0xFFFFFF00),
            width: 0.0,
            style: .none
        )

        let result1 = Border(top: yellow2) + Border(right: magenta3)
        XCTAssertEqual(result1 as? Border, Border(top: yellow2, right: magenta3))

        let result2 = Border(bottom: magenta3) + Border(bottom: magenta3)
        XCTAssertEqual(result2 as? Border, Border(bottom: magenta6))

        let result3 = Border(right: yellowNone0, left: magenta3) + Border(right: yellow2)
        XCTAssertEqual(result3 as? Border, Border(right: yellow2, left: magenta3))

        let result4 = Border() + Border()
        XCTAssertEqual(result4 as? Border, Border())

        // Incompatible merge returns compound border
        let result5 = Border(left: magenta3) + Border(left: yellow2)
        XCTAssertFalse(result5 is Border, "Incompatible borders should not produce a Border")

        let b3 = Border(top: magenta3)
        let b6 = Border(top: magenta6)
        XCTAssertEqual((b3 + b3) as? Border, b6)

        let b0 = Border(top: yellowNone0)
        let bZ = Border()
        XCTAssertEqual((b0 + b0) as? Border, bZ)
        XCTAssertEqual((bZ + bZ) as? Border, bZ)
        XCTAssertEqual((b0 + bZ) as? Border, bZ)
        XCTAssertEqual((bZ + b0) as? Border, bZ)
    }

    // MARK: - Border.scale Tests

    /// **Dart Test:** `border_test.dart` - "Border.scale"
    func testBorderScale() {
        let magenta3 = BorderSide(color: Color(0xFFFF00FF), width: 3.0)
        let magenta6 = BorderSide(color: Color(0xFFFF00FF), width: 6.0)
        let yellow2 = BorderSide(color: Color(0xFFFFFF00), width: 2.0)
        let yellowNone0 = BorderSide(
            color: Color(0xFFFFFF00),
            width: 0.0,
            style: .none
        )

        let b3 = Border(left: magenta3)
        let b6 = Border(left: magenta6)
        XCTAssertEqual(b3.scale(2.0) as? Border, b6)

        let bY0 = Border(top: yellowNone0)
        XCTAssertEqual(bY0.scale(3.0) as? Border, bY0)

        let bY2 = Border(top: yellow2)
        XCTAssertEqual(bY2.scale(0.0) as? Border, bY0)
    }

    // MARK: - Border.dimensions Tests

    /// **Dart Test:** `border_test.dart` - "Border.dimensions"
    func testBorderDimensions() {
        let border = Border(
            top: BorderSide(width: 3.0),
            right: BorderSide(width: 7.0),
            bottom: BorderSide(width: 5.0),
            left: BorderSide(width: 2.0)
        )
        let dimensions = border.dimensions as? EdgeInsets
        XCTAssertNotNil(dimensions)
        XCTAssertEqual(dimensions, EdgeInsets.fromLTRB(2.0, 3.0, 7.0, 5.0))
    }

    /// **Dart Test:** `border_test.dart` - "Border.dimension" (stroke align variants)
    func testBorderDimensionWithStrokeAlign() {
        let insideBorder = Border.all(width: 10)
        let insideDimensions = insideBorder.dimensions as? EdgeInsets
        XCTAssertEqual(insideDimensions, EdgeInsets(all: 10))

        let centerBorder = Border.all(width: 10, strokeAlign: BorderSide.strokeAlignCenter)
        let centerDimensions = centerBorder.dimensions as? EdgeInsets
        XCTAssertEqual(centerDimensions, EdgeInsets(all: 5))

        let outsideBorder = Border.all(width: 10, strokeAlign: BorderSide.strokeAlignOutside)
        let outsideDimensions = outsideBorder.dimensions as? EdgeInsets
        XCTAssertEqual(outsideDimensions, EdgeInsets.zero)

        let nonUniformBorder = Border(
            top: BorderSide(width: 10, strokeAlign: BorderSide.strokeAlignCenter),
            right: BorderSide(width: 15, strokeAlign: BorderSide.strokeAlignOutside),
            bottom: BorderSide(width: 20),
            left: BorderSide(width: 5)
        )
        let nonUniformDimensions = nonUniformBorder.dimensions as? EdgeInsets
        XCTAssertEqual(nonUniformDimensions, EdgeInsets.fromLTRB(5, 5, 0, 20))
    }

    // MARK: - Border.isUniform Tests

    /// **Dart Test:** `border_test.dart` - "Border.isUniform"
    func testBorderIsUniform() {
        // Not uniform (width differs)
        XCTAssertFalse(
            Border(
                top: BorderSide(width: 3.0),
                right: BorderSide(width: 3.0),
                bottom: BorderSide(width: 3.1),
                left: BorderSide(width: 3.0)
            ).isUniform
        )

        // Uniform (all same)
        XCTAssertTrue(
            Border(
                top: BorderSide(width: 3.0),
                right: BorderSide(width: 3.0),
                bottom: BorderSide(width: 3.0),
                left: BorderSide(width: 3.0)
            ).isUniform
        )

        // Not uniform (color differs)
        XCTAssertFalse(
            Border(
                top: BorderSide(color: Color(0xFFFFFFFF)),
                right: BorderSide(color: Color(0xFFFFFFFF)),
                bottom: BorderSide(color: Color(0xFFFFFFFF)),
                left: BorderSide(color: Color(0xFFFFFFFE))
            ).isUniform
        )

        // Uniform (all same color)
        XCTAssertTrue(
            Border(
                top: BorderSide(color: Color(0xFFFFFFFF)),
                right: BorderSide(color: Color(0xFFFFFFFF)),
                bottom: BorderSide(color: Color(0xFFFFFFFF)),
                left: BorderSide(color: Color(0xFFFFFFFF))
            ).isUniform
        )

        // Not uniform (style differs)
        XCTAssertFalse(
            Border(
                top: BorderSide(style: .none),
                right: BorderSide(style: .none),
                bottom: BorderSide(width: 0.0),
                left: BorderSide(style: .none)
            ).isUniform
        )

        // Not uniform (default bottom is solid but others are none)
        XCTAssertFalse(
            Border(
                top: BorderSide(style: .none),
                right: BorderSide(style: .none),
                left: BorderSide(style: .none)
            ).isUniform
        )

        // Not uniform (strokeAlign differs)
        XCTAssertFalse(
            Border(
                top: BorderSide(strokeAlign: BorderSide.strokeAlignCenter),
                right: BorderSide(strokeAlign: BorderSide.strokeAlignOutside),
                left: BorderSide()
            ).isUniform
        )

        // Default border is uniform
        XCTAssertTrue(Border().isUniform)
    }

    // MARK: - Border.lerp Tests

    /// **Dart Test:** `border_test.dart` - "Border.lerp"
    func testBorderLerp() {
        let visualWithTop10 = Border(top: BorderSide(width: 10.0))
        let atMinus100 = Border(right: BorderSide(width: 300.0), left: BorderSide(width: 0.0))
        let at0 = Border(right: BorderSide(width: 200.0), left: BorderSide(width: 100.0))
        let at25 = Border(right: BorderSide(width: 175.0), left: BorderSide(width: 125.0))
        let at75 = Border(right: BorderSide(width: 125.0), left: BorderSide(width: 175.0))
        let at100 = Border(right: BorderSide(width: 100.0), left: BorderSide(width: 200.0))
        let at200 = Border(right: BorderSide(width: 0.0), left: BorderSide(width: 300.0))

        XCTAssertNil(Border.lerp(nil, nil, -1.0))
        XCTAssertEqual(Border.lerp(visualWithTop10, nil, -1.0), Border(top: BorderSide(width: 20.0)))
        XCTAssertEqual(Border.lerp(nil, visualWithTop10, -1.0), Border())
        XCTAssertEqual(Border.lerp(at0, at100, -1.0), atMinus100)

        XCTAssertNil(Border.lerp(nil, nil, 0.0))
        XCTAssertEqual(Border.lerp(visualWithTop10, nil, 0.0), Border(top: BorderSide(width: 10.0)))
        XCTAssertEqual(Border.lerp(nil, visualWithTop10, 0.0), Border())
        XCTAssertEqual(Border.lerp(at0, at100, 0.0), at0)

        XCTAssertNil(Border.lerp(nil, nil, 0.25))
        XCTAssertEqual(Border.lerp(visualWithTop10, nil, 0.25), Border(top: BorderSide(width: 7.5)))
        XCTAssertEqual(Border.lerp(nil, visualWithTop10, 0.25), Border(top: BorderSide(width: 2.5)))
        XCTAssertEqual(Border.lerp(at0, at100, 0.25), at25)

        XCTAssertNil(Border.lerp(nil, nil, 0.75))
        XCTAssertEqual(Border.lerp(visualWithTop10, nil, 0.75), Border(top: BorderSide(width: 2.5)))
        XCTAssertEqual(Border.lerp(nil, visualWithTop10, 0.75), Border(top: BorderSide(width: 7.5)))
        XCTAssertEqual(Border.lerp(at0, at100, 0.75), at75)

        XCTAssertNil(Border.lerp(nil, nil, 1.0))
        XCTAssertEqual(Border.lerp(visualWithTop10, nil, 1.0), Border())
        XCTAssertEqual(Border.lerp(nil, visualWithTop10, 1.0), Border(top: BorderSide(width: 10.0)))
        XCTAssertEqual(Border.lerp(at0, at100, 1.0), at100)

        XCTAssertNil(Border.lerp(nil, nil, 2.0))
        XCTAssertEqual(Border.lerp(visualWithTop10, nil, 2.0), Border())
        XCTAssertEqual(Border.lerp(nil, visualWithTop10, 2.0), Border(top: BorderSide(width: 20.0)))
        XCTAssertEqual(Border.lerp(at0, at100, 2.0), at200)
    }

    // MARK: - Border.paint Tests

    /// Test that uniform border paints correctly.
    func testBorderPaintUniform() {
        let canvas = BoxBorderMockCanvas()
        let border = Border.all(color: Color(0xFFFF0000), width: 2.0)
        border.paint(canvas, Rect.fromLTWH(10.0, 20.0, 30.0, 40.0))
        // Uniform solid border paints a rectangle
        XCTAssertFalse(canvas.calls.isEmpty, "Border should have painted something")
    }

    /// Test that none-style uniform border does not paint.
    func testBorderPaintNone() {
        let canvas = BoxBorderMockCanvas()
        let border = Border.all(width: 0.0, style: .none)
        border.paint(canvas, Rect.fromLTWH(10.0, 20.0, 30.0, 40.0))
        XCTAssertTrue(canvas.calls.isEmpty, "None-style border should not paint")
    }

    /// Test that uniform border paints with circle shape.
    func testBorderPaintCircle() {
        let canvas = BoxBorderMockCanvas()
        let border = Border.all(color: Color(0xFFFF0000), width: 2.0)
        border.paint(canvas, Rect.fromLTWH(10.0, 20.0, 30.0, 40.0), shape: BoxShape.circle)
        XCTAssertFalse(canvas.calls.isEmpty, "Circle border should have painted something")
    }

    /// Test that uniform border paints with border radius.
    func testBorderPaintWithBorderRadius() {
        let canvas = BoxBorderMockCanvas()
        let border = Border.all(color: Color(0xFFFF0000), width: 2.0)
        let borderRadius = BorderRadius.circular(10.0)
        border.paint(canvas, Rect.fromLTWH(10.0, 20.0, 30.0, 40.0), borderRadius: borderRadius)
        XCTAssertFalse(canvas.calls.isEmpty, "Border with radius should have painted something")
    }

    // MARK: - Border Equality Tests

    /// Test Border equality.
    func testBorderEquality() {
        let a = Border(top: BorderSide(width: 2.0))
        let b = Border(top: BorderSide(width: 2.0))
        let c = Border(top: BorderSide(width: 3.0))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// Test Border hash code.
    func testBorderHashCode() {
        let side = BorderSide(width: 2.0)
        XCTAssertEqual(Border(top: side).hashValue, Border(top: side).hashValue)
        // Different borders should (usually) have different hash codes
        XCTAssertNotEqual(Border(top: side).hashValue, Border(bottom: side).hashValue)
    }

    // MARK: - Border.toString Tests

    /// Test Border description.
    func testBorderDescription() {
        let uniformBorder = Border.all(color: Color(0xFFFF0000), width: 2.0)
        XCTAssertTrue(uniformBorder.description.hasPrefix("Border.all("))

        let nonUniformBorder = Border(
            top: BorderSide(width: 2.0),
            right: BorderSide(width: 3.0)
        )
        XCTAssertTrue(nonUniformBorder.description.hasPrefix("Border("))
        XCTAssertTrue(nonUniformBorder.description.contains("top:"))
        XCTAssertTrue(nonUniformBorder.description.contains("right:"))
    }

    // MARK: - BoxBorder Factory Tests

    /// **Dart Test:** `border_test.dart` - "BoxBorder factories"
    func testBoxBorderFactories() {
        let side1 = BorderSide()
        let side2 = BorderSide(width: 2)
        let side3 = BorderSide(width: 3)
        let side4 = BorderSide(width: 4)

        XCTAssertEqual(
            BoxBorder.fromLTRB(top: side2, right: side3, bottom: side4, left: side1),
            Border(top: side2, right: side3, bottom: side4, left: side1)
        )

        XCTAssertEqual(
            BoxBorder.all(width: 4),
            Border.all(width: 4)
        )

        XCTAssertEqual(
            BoxBorder.fromBorderSide(side3),
            Border.fromBorderSide(side3)
        )

        XCTAssertEqual(
            BoxBorder.symmetric(vertical: side3, horizontal: side2),
            Border.symmetric(vertical: side3, horizontal: side2)
        )

        let steb = BoxBorder.fromSTEB(top: side2, start: side1, end: side3, bottom: side4)
        let expected = BorderDirectional(top: side2, start: side1, end: side3, bottom: side4)
        XCTAssertEqual(steb, expected)
    }

    // MARK: - BorderDirectional.merge Tests

    /// **Dart Test:** `border_rtl_test.dart` - "BorderDirectional.merge"
    func testBorderDirectionalMerge() {
        let magenta3 = BorderSide(color: Color(0xFFFF00FF), width: 3.0)
        let magenta6 = BorderSide(color: Color(0xFFFF00FF), width: 6.0)
        let yellow2 = BorderSide(color: Color(0xFFFFFF00), width: 2.0)
        let yellowNone0 = BorderSide(
            color: Color(0xFFFFFF00),
            width: 0.0,
            style: .none
        )

        XCTAssertEqual(
            BorderDirectional.merge(
                BorderDirectional(top: yellow2),
                BorderDirectional(end: magenta3)
            ),
            BorderDirectional(top: yellow2, end: magenta3)
        )

        XCTAssertEqual(
            BorderDirectional.merge(
                BorderDirectional(bottom: magenta3),
                BorderDirectional(bottom: magenta3)
            ),
            BorderDirectional(bottom: magenta6)
        )

        XCTAssertEqual(
            BorderDirectional.merge(
                BorderDirectional(start: magenta3, end: yellowNone0),
                BorderDirectional(end: yellow2)
            ),
            BorderDirectional(start: magenta3, end: yellow2)
        )

        XCTAssertEqual(
            BorderDirectional.merge(BorderDirectional(), BorderDirectional()),
            BorderDirectional()
        )
    }

    // MARK: - BorderDirectional.dimensions Tests

    /// **Dart Test:** `border_rtl_test.dart` - "BorderDirectional.dimensions"
    func testBorderDirectionalDimensions() {
        let border = BorderDirectional(
            top: BorderSide(width: 3.0),
            start: BorderSide(width: 2.0),
            end: BorderSide(width: 7.0),
            bottom: BorderSide(width: 5.0)
        )
        let dims = border.dimensions as? EdgeInsetsDirectional
        XCTAssertNotNil(dims)
        XCTAssertEqual(dims, EdgeInsetsDirectional.fromSTEB(2.0, 3.0, 7.0, 5.0))
    }

    /// **Dart Test:** `border_test.dart` - "Border.dimension" (directional variants)
    func testBorderDirectionalDimensionWithStrokeAlign() {
        let insideSide = BorderSide(width: 10)
        let insideBorderDirectional = BorderDirectional(
            top: insideSide,
            start: insideSide,
            end: insideSide,
            bottom: insideSide
        )
        let insideDims = insideBorderDirectional.dimensions as? EdgeInsetsDirectional
        XCTAssertEqual(insideDims, EdgeInsetsDirectional(all: 10))

        let centerSide = BorderSide(width: 10, strokeAlign: BorderSide.strokeAlignCenter)
        let centerBorderDirectional = BorderDirectional(
            top: centerSide,
            start: centerSide,
            end: centerSide,
            bottom: centerSide
        )
        let centerDims = centerBorderDirectional.dimensions as? EdgeInsetsDirectional
        XCTAssertEqual(centerDims, EdgeInsetsDirectional(all: 5))

        let outsideSide = BorderSide(
            width: 10,
            strokeAlign: BorderSide.strokeAlignOutside
        )
        let outsideBorderDirectional = BorderDirectional(
            top: outsideSide,
            start: outsideSide,
            end: outsideSide,
            bottom: outsideSide
        )
        let outsideDims = outsideBorderDirectional.dimensions as? EdgeInsetsDirectional
        XCTAssertEqual(outsideDims, EdgeInsetsDirectional.zero)

        let nonUniformBorderDirectional = BorderDirectional(
            top: BorderSide(width: 10, strokeAlign: BorderSide.strokeAlignCenter),
            start: BorderSide(width: 5),
            end: BorderSide(width: 15, strokeAlign: BorderSide.strokeAlignOutside),
            bottom: BorderSide(width: 20)
        )
        let nonUniformDims = nonUniformBorderDirectional.dimensions as? EdgeInsetsDirectional
        XCTAssertEqual(nonUniformDims, EdgeInsetsDirectional.fromSTEB(5, 5, 0, 20))
    }

    // MARK: - BorderDirectional.isUniform Tests

    /// **Dart Test:** `border_rtl_test.dart` - "BorderDirectional.isUniform"
    func testBorderDirectionalIsUniform() {
        // Not uniform (width differs)
        XCTAssertFalse(
            BorderDirectional(
                top: BorderSide(width: 3.0),
                start: BorderSide(width: 3.0),
                end: BorderSide(width: 3.0),
                bottom: BorderSide(width: 3.1)
            ).isUniform
        )

        // Uniform
        XCTAssertTrue(
            BorderDirectional(
                top: BorderSide(width: 3.0),
                start: BorderSide(width: 3.0),
                end: BorderSide(width: 3.0),
                bottom: BorderSide(width: 3.0)
            ).isUniform
        )

        // Not uniform (color differs)
        XCTAssertFalse(
            BorderDirectional(
                top: BorderSide(color: Color(0xFFFFFFFF)),
                start: BorderSide(color: Color(0xFFFFFFFE)),
                end: BorderSide(color: Color(0xFFFFFFFF)),
                bottom: BorderSide(color: Color(0xFFFFFFFF))
            ).isUniform
        )

        // Uniform (all same color)
        XCTAssertTrue(
            BorderDirectional(
                top: BorderSide(color: Color(0xFFFFFFFF)),
                start: BorderSide(color: Color(0xFFFFFFFF)),
                end: BorderSide(color: Color(0xFFFFFFFF)),
                bottom: BorderSide(color: Color(0xFFFFFFFF))
            ).isUniform
        )

        // Not uniform (style differs)
        XCTAssertFalse(
            BorderDirectional(
                top: BorderSide(style: .none),
                start: BorderSide(style: .none),
                end: BorderSide(style: .none),
                bottom: BorderSide(width: 0.0)
            ).isUniform
        )

        // Not uniform (default bottom is solid but others are none)
        XCTAssertFalse(
            BorderDirectional(
                top: BorderSide(style: .none),
                start: BorderSide(style: .none),
                end: BorderSide(style: .none)
            ).isUniform
        )

        // Default border is uniform
        XCTAssertTrue(BorderDirectional().isUniform)
    }

    // MARK: - BorderDirectional.add Tests

    /// **Dart Test:** `border_rtl_test.dart` - "BorderDirectional.add - all directional"
    func testBorderDirectionalAddAllDirectional() {
        let magenta3 = BorderSide(color: Color(0xFFFF00FF), width: 3.0)
        let magenta6 = BorderSide(color: Color(0xFFFF00FF), width: 6.0)
        let yellow2 = BorderSide(color: Color(0xFFFFFF00), width: 2.0)
        let yellowNone0 = BorderSide(
            color: Color(0xFFFFFF00),
            width: 0.0,
            style: .none
        )

        let r1 = BorderDirectional(top: yellow2) + BorderDirectional(end: magenta3)
        XCTAssertEqual(r1 as? BorderDirectional, BorderDirectional(top: yellow2, end: magenta3))

        let r2 = BorderDirectional(bottom: magenta3) + BorderDirectional(bottom: magenta3)
        XCTAssertEqual(r2 as? BorderDirectional, BorderDirectional(bottom: magenta6))

        let r3 = BorderDirectional(start: magenta3, end: yellowNone0) + BorderDirectional(end: yellow2)
        XCTAssertEqual(r3 as? BorderDirectional, BorderDirectional(start: magenta3, end: yellow2))

        let r4 = BorderDirectional() + BorderDirectional()
        XCTAssertEqual(r4 as? BorderDirectional, BorderDirectional())

        // Incompatible
        let r5 = BorderDirectional(start: magenta3) + BorderDirectional(start: yellow2)
        XCTAssertFalse(r5 is BorderDirectional, "Incompatible directional borders should not produce a BorderDirectional")

        let b3 = BorderDirectional(top: magenta3)
        let b6 = BorderDirectional(top: magenta6)
        XCTAssertEqual((b3 + b3) as? BorderDirectional, b6)

        let b0 = BorderDirectional(top: yellowNone0)
        let bZ = BorderDirectional()
        XCTAssertEqual((b0 + b0) as? BorderDirectional, bZ)
        XCTAssertEqual((bZ + bZ) as? BorderDirectional, bZ)
        XCTAssertEqual((b0 + bZ) as? BorderDirectional, bZ)
        XCTAssertEqual((bZ + b0) as? BorderDirectional, bZ)
    }

    /// **Dart Test:** `border_rtl_test.dart` - "BorderDirectional.add" (mixed with Border)
    func testBorderDirectionalAddMixed() {
        let side1 = BorderSide(color: Color(0x11111111))
        let doubleSide1 = BorderSide(color: Color(0x11111111), width: 2.0)
        let side2 = BorderSide(color: Color(0x22222222))
        let doubleSide2 = BorderSide(color: Color(0x22222222), width: 2.0)

        // Adding tops and sides
        let r1 = Border(left: side1) + BorderDirectional(top: side2)
        XCTAssertEqual(r1 as? Border, Border(top: side2, left: side1))

        let r2 = BorderDirectional(start: side1) + Border(top: side2)
        XCTAssertEqual(r2 as? BorderDirectional, BorderDirectional(top: side2, start: side1))

        let r3 = Border(top: side2) + BorderDirectional(start: side1)
        XCTAssertEqual(r3 as? BorderDirectional, BorderDirectional(top: side2, start: side1))

        let r4 = BorderDirectional(top: side2) + Border(left: side1)
        XCTAssertEqual(r4 as? Border, Border(top: side2, left: side1))

        // Adding incompatible tops/bottoms produces compound border
        let r5 = Border(top: side1) + BorderDirectional(top: side2)
        XCTAssertTrue(r5.description.contains(" + "))

        let r6 = BorderDirectional(top: side2) + Border(top: side1)
        XCTAssertTrue(r6.description.contains(" + "))

        let r7 = Border(bottom: side1) + BorderDirectional(bottom: side2)
        XCTAssertTrue(r7.description.contains(" + "))

        let r8 = BorderDirectional(bottom: side2) + Border(bottom: side1)
        XCTAssertTrue(r8.description.contains(" + "))

        // Adding compatible tops and bottoms
        let r9 = BorderDirectional(top: side1) + Border(top: side1)
        XCTAssertEqual(r9 as? Border, Border(top: doubleSide1))

        let r10 = Border(top: side1) + BorderDirectional(top: side1)
        XCTAssertEqual(r10 as? Border, Border(top: doubleSide1))

        let r11 = BorderDirectional(bottom: side1) + Border(bottom: side1)
        XCTAssertEqual(r11 as? Border, Border(bottom: doubleSide1))

        let r12 = Border(bottom: side1) + BorderDirectional(bottom: side1)
        XCTAssertEqual(r12 as? Border, Border(bottom: doubleSide1))

        // Complex mixed cases
        let borderWithLeft = Border(top: side2, bottom: side2, left: side1)
        let borderWithoutSides = Border(top: side2, bottom: side2)
        let borderDirectionalWithStart = BorderDirectional(top: side2, start: side1, bottom: side2)
        let borderDirectionalWithoutSides = BorderDirectional(top: side2, bottom: side2)

        // Border(left) + BorderDirectional(no sides) = Border(left, merged tops/bottoms)
        XCTAssertEqual(
            (borderWithLeft + borderDirectionalWithoutSides).description,
            Border(top: doubleSide2, bottom: doubleSide2, left: side1).description
        )

        // Border(no sides) + BorderDirectional(start) = BorderDirectional(start, merged tops/bottoms)
        XCTAssertEqual(
            (borderWithoutSides + borderDirectionalWithStart).description,
            BorderDirectional(top: doubleSide2, start: side1, bottom: doubleSide2).description
        )

        // Border(no sides) + BorderDirectional(no sides) = Border(merged tops/bottoms)
        XCTAssertEqual(
            (borderWithoutSides + borderDirectionalWithoutSides).description,
            Border(top: doubleSide2, bottom: doubleSide2).description
        )

        // Reverse: BorderDirectional(no sides) + Border(left) = Border(left, merged tops/bottoms)
        XCTAssertEqual(
            (borderDirectionalWithoutSides + borderWithLeft).description,
            Border(top: doubleSide2, bottom: doubleSide2, left: side1).description
        )

        // BorderDirectional(start) + Border(no sides) = BorderDirectional(start, merged tops/bottoms)
        XCTAssertEqual(
            (borderDirectionalWithStart + borderWithoutSides).description,
            BorderDirectional(top: doubleSide2, start: side1, bottom: doubleSide2).description
        )

        // BorderDirectional(no sides) + Border(no sides) = Border(merged tops/bottoms)
        XCTAssertEqual(
            (borderDirectionalWithoutSides + borderWithoutSides).description,
            Border(top: doubleSide2, bottom: doubleSide2).description
        )
    }

    // MARK: - BorderDirectional.scale Tests

    /// **Dart Test:** `border_rtl_test.dart` - "BorderDirectional.scale"
    func testBorderDirectionalScale() {
        let magenta3 = BorderSide(color: Color(0xFFFF00FF), width: 3.0)
        let magenta6 = BorderSide(color: Color(0xFFFF00FF), width: 6.0)
        let yellow2 = BorderSide(color: Color(0xFFFFFF00), width: 2.0)
        let yellowNone0 = BorderSide(
            color: Color(0xFFFFFF00),
            width: 0.0,
            style: .none
        )

        let b3 = BorderDirectional(start: magenta3)
        let b6 = BorderDirectional(start: magenta6)
        XCTAssertEqual(b3.scale(2.0) as? BorderDirectional, b6)

        let bY0 = BorderDirectional(top: yellowNone0)
        XCTAssertEqual(bY0.scale(3.0) as? BorderDirectional, bY0)

        let bY2 = BorderDirectional(top: yellow2)
        XCTAssertEqual(bY2.scale(0.0) as? BorderDirectional, bY0)
    }

    // MARK: - BorderDirectional.lerp Tests

    /// **Dart Test:** `border_rtl_test.dart` - "BorderDirectional.lerp"
    func testBorderDirectionalLerp() {
        let directionalWithTop10 = BorderDirectional(top: BorderSide(width: 10.0))
        let atMinus100 = BorderDirectional(
            start: BorderSide(width: 0.0),
            end: BorderSide(width: 300.0)
        )
        let at0 = BorderDirectional(
            start: BorderSide(width: 100.0),
            end: BorderSide(width: 200.0)
        )
        let at25 = BorderDirectional(
            start: BorderSide(width: 125.0),
            end: BorderSide(width: 175.0)
        )
        let at75 = BorderDirectional(
            start: BorderSide(width: 175.0),
            end: BorderSide(width: 125.0)
        )
        let at100 = BorderDirectional(
            start: BorderSide(width: 200.0),
            end: BorderSide(width: 100.0)
        )
        let at200 = BorderDirectional(
            start: BorderSide(width: 300.0),
            end: BorderSide(width: 0.0)
        )

        XCTAssertNil(BorderDirectional.lerp(nil, nil, -1.0))
        XCTAssertEqual(
            BorderDirectional.lerp(directionalWithTop10, nil, -1.0),
            BorderDirectional(top: BorderSide(width: 20.0))
        )
        XCTAssertEqual(BorderDirectional.lerp(nil, directionalWithTop10, -1.0), BorderDirectional())
        XCTAssertEqual(BorderDirectional.lerp(at0, at100, -1.0), atMinus100)

        XCTAssertNil(BorderDirectional.lerp(nil, nil, 0.0))
        XCTAssertEqual(
            BorderDirectional.lerp(directionalWithTop10, nil, 0.0),
            BorderDirectional(top: BorderSide(width: 10.0))
        )
        XCTAssertEqual(BorderDirectional.lerp(nil, directionalWithTop10, 0.0), BorderDirectional())
        XCTAssertEqual(BorderDirectional.lerp(at0, at100, 0.0), at0)

        XCTAssertNil(BorderDirectional.lerp(nil, nil, 0.25))
        XCTAssertEqual(
            BorderDirectional.lerp(directionalWithTop10, nil, 0.25),
            BorderDirectional(top: BorderSide(width: 7.5))
        )
        XCTAssertEqual(
            BorderDirectional.lerp(nil, directionalWithTop10, 0.25),
            BorderDirectional(top: BorderSide(width: 2.5))
        )
        XCTAssertEqual(BorderDirectional.lerp(at0, at100, 0.25), at25)

        XCTAssertNil(BorderDirectional.lerp(nil, nil, 0.75))
        XCTAssertEqual(
            BorderDirectional.lerp(directionalWithTop10, nil, 0.75),
            BorderDirectional(top: BorderSide(width: 2.5))
        )
        XCTAssertEqual(
            BorderDirectional.lerp(nil, directionalWithTop10, 0.75),
            BorderDirectional(top: BorderSide(width: 7.5))
        )
        XCTAssertEqual(BorderDirectional.lerp(at0, at100, 0.75), at75)

        XCTAssertNil(BorderDirectional.lerp(nil, nil, 1.0))
        XCTAssertEqual(BorderDirectional.lerp(directionalWithTop10, nil, 1.0), BorderDirectional())
        XCTAssertEqual(
            BorderDirectional.lerp(nil, directionalWithTop10, 1.0),
            BorderDirectional(top: BorderSide(width: 10.0))
        )
        XCTAssertEqual(BorderDirectional.lerp(at0, at100, 1.0), at100)

        XCTAssertNil(BorderDirectional.lerp(nil, nil, 2.0))
        XCTAssertEqual(BorderDirectional.lerp(directionalWithTop10, nil, 2.0), BorderDirectional())
        XCTAssertEqual(
            BorderDirectional.lerp(nil, directionalWithTop10, 2.0),
            BorderDirectional(top: BorderSide(width: 20.0))
        )
        XCTAssertEqual(BorderDirectional.lerp(at0, at100, 2.0), at200)
    }

    // MARK: - BorderDirectional.paint Tests

    /// **Dart Test:** `border_rtl_test.dart` - "BorderDirectional.paint"
    func testBorderDirectionalPaint() {
        let canvas = BoxBorderMockCanvas()

        // Uniform border paints correctly
        let border = BorderDirectional(
            top: BorderSide(width: 2.0),
            start: BorderSide(width: 2.0),
            end: BorderSide(width: 2.0),
            bottom: BorderSide(width: 2.0)
        )
        border.paint(canvas, Rect.fromLTRB(10.0, 20.0, 30.0, 40.0), textDirection: .ltr)
        XCTAssertFalse(canvas.calls.isEmpty, "BorderDirectional should have painted something")
    }

    // MARK: - BorderDirectional Hashable Tests

    /// **Dart Test:** `border_rtl_test.dart` - "BorderDirectional hashCode"
    func testBorderDirectionalHashCode() {
        let side = BorderSide(width: 2.0)
        XCTAssertEqual(
            BorderDirectional(top: side).hashValue,
            BorderDirectional(top: side).hashValue
        )
        XCTAssertNotEqual(
            BorderDirectional(top: side).hashValue,
            BorderDirectional(bottom: side).hashValue
        )
    }

    // MARK: - BorderDirectional Equality Tests

    /// Test BorderDirectional equality.
    func testBorderDirectionalEquality() {
        let a = BorderDirectional(start: BorderSide(width: 2.0))
        let b = BorderDirectional(start: BorderSide(width: 2.0))
        let c = BorderDirectional(start: BorderSide(width: 3.0))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// Test that Border and BorderDirectional are not equal.
    func testBorderAndBorderDirectionalNotEqual() {
        let border = Border(left: BorderSide(width: 2.0))
        let directional = BorderDirectional(start: BorderSide(width: 2.0))
        XCTAssertNotEqual(border as BoxBorder, directional as BoxBorder)
    }

    // MARK: - BorderDirectional.toString Tests

    /// Test BorderDirectional description.
    func testBorderDirectionalDescription() {
        let border = BorderDirectional(
            top: BorderSide(width: 3.0),
            start: BorderSide(width: 2.0)
        )
        XCTAssertTrue(border.description.hasPrefix("BorderDirectional("))
        XCTAssertTrue(border.description.contains("top:"))
        XCTAssertTrue(border.description.contains("start:"))
    }

    // MARK: - BoxBorder.lerp Tests (Cross-type interpolation)

    /// **Dart Test:** `border_rtl_test.dart` - "BoxBorder.lerp" (partial)
    /// Tests the basic cross-type interpolation cases.
    func testBoxBorderLerpBasic() {
        let directionalWithTop10: BoxBorder = BorderDirectional(top: BorderSide(width: 10.0))
        let visualWithTop100: BoxBorder = Border(top: BorderSide(width: 100.0))

        // null-null
        XCTAssertNil(BoxBorder.lerp(nil, nil, 0.0))
        XCTAssertNil(BoxBorder.lerp(nil, nil, 0.5))
        XCTAssertNil(BoxBorder.lerp(nil, nil, 1.0))

        // Border-null
        XCTAssertEqual(BoxBorder.lerp(Border.all(width: 10.0), nil, 0.0), Border.all(width: 10.0))
        XCTAssertEqual(BoxBorder.lerp(Border.all(width: 10.0), nil, 0.25), Border.all(width: 7.5))
        XCTAssertEqual(BoxBorder.lerp(Border.all(width: 10.0), nil, 0.75), Border.all(width: 2.5))
        XCTAssertEqual(
            BoxBorder.lerp(Border.all(width: 10.0), nil, 1.0),
            Border.all(width: 0.0, style: .none)
        )

        // null-Border
        XCTAssertEqual(BoxBorder.lerp(nil, Border.all(width: 10.0), 0.0), Border())
        XCTAssertEqual(BoxBorder.lerp(nil, Border.all(width: 10.0), 0.25), Border.all(width: 2.5))
        XCTAssertEqual(BoxBorder.lerp(nil, Border.all(width: 10.0), 0.75), Border.all(width: 7.5))
        XCTAssertEqual(BoxBorder.lerp(nil, Border.all(width: 10.0), 1.0), Border.all(width: 10.0))

        // BorderDirectional-null
        XCTAssertEqual(
            BoxBorder.lerp(directionalWithTop10, nil, 0.0),
            BorderDirectional(top: BorderSide(width: 10.0))
        )
        XCTAssertEqual(
            BoxBorder.lerp(directionalWithTop10, nil, 0.25),
            BorderDirectional(top: BorderSide(width: 7.5))
        )
        XCTAssertEqual(
            BoxBorder.lerp(directionalWithTop10, nil, 0.75),
            BorderDirectional(top: BorderSide(width: 2.5))
        )
        XCTAssertEqual(BoxBorder.lerp(directionalWithTop10, nil, 1.0), BorderDirectional())

        // null-BorderDirectional
        XCTAssertEqual(BoxBorder.lerp(nil, directionalWithTop10, 0.0), BorderDirectional())
        XCTAssertEqual(
            BoxBorder.lerp(nil, directionalWithTop10, 0.25),
            BorderDirectional(top: BorderSide(width: 2.5))
        )
        XCTAssertEqual(
            BoxBorder.lerp(nil, directionalWithTop10, 0.75),
            BorderDirectional(top: BorderSide(width: 7.5))
        )
        XCTAssertEqual(
            BoxBorder.lerp(nil, directionalWithTop10, 1.0),
            BorderDirectional(top: BorderSide(width: 10.0))
        )

        // Border to BorderDirectional (when b has no start/end)
        XCTAssertEqual(
            BoxBorder.lerp(directionalWithTop10, visualWithTop100, 0.0),
            Border(top: BorderSide(width: 10.0))
        )
        XCTAssertEqual(
            BoxBorder.lerp(directionalWithTop10, visualWithTop100, 0.25),
            Border(top: BorderSide(width: 32.5))
        )
    }

    /// **Dart Test:** `border_rtl_test.dart` - "BoxBorder.lerp" (with sides)
    func testBoxBorderLerpWithSides() {
        let visualWithSides10: BoxBorder = Border(
            right: BorderSide(width: 20.0),
            left: BorderSide(width: 10.0)
        )
        let directionalWithSides10: BoxBorder = BorderDirectional(
            start: BorderSide(width: 10.0),
            end: BorderSide(width: 20.0)
        )
        let directionalWithSides20: BoxBorder = BorderDirectional(
            start: BorderSide(width: 20.0),
            end: BorderSide(width: 40.0)
        )
        let directionalWithSides30: BoxBorder = BorderDirectional(
            start: BorderSide(width: 30.0),
            end: BorderSide(width: 60.0)
        )
        let visualWithSides20: BoxBorder = Border(
            right: BorderSide(width: 40.0),
            left: BorderSide(width: 20.0)
        )
        let visualWithSides30: BoxBorder = Border(
            right: BorderSide(width: 60.0),
            left: BorderSide(width: 30.0)
        )

        // visual -> directional (same sides), should interpolate through visual then directional
        // At t=-1, visual sides double
        XCTAssertEqual(
            BoxBorder.lerp(visualWithSides10, directionalWithSides10, -1.0),
            visualWithSides30
        )

        // At t=1, should be directionalWithSides10
        XCTAssertEqual(
            BoxBorder.lerp(visualWithSides10, directionalWithSides10, 1.0),
            directionalWithSides10
        )

        // At t=2, directional sides double
        XCTAssertEqual(
            BoxBorder.lerp(visualWithSides10, directionalWithSides10, 2.0),
            directionalWithSides30
        )
    }

    /// **Dart Test:** `border_rtl_test.dart` - "BoxBorder.lerp" (visual + directional magenta top)
    func testBoxBorderLerpVisualDirectionalMagentaTop() {
        let directionalWithMagentaTop5: BoxBorder = BorderDirectional(
            top: BorderSide(color: Color(0xFFFF00FF), width: 5.0)
        )
        let visualWithSides10: BoxBorder = Border(
            right: BorderSide(width: 20.0),
            left: BorderSide(width: 10.0)
        )
        let visualWithMagentaTop5: BoxBorder = Border(
            top: BorderSide(color: Color(0xFFFF00FF), width: 5.0)
        )
        let visualWithMagentaTop10: BoxBorder = Border(
            top: BorderSide(color: Color(0xFFFF00FF), width: 10.0)
        )

        // At t=1.0, should be the directional magenta top as Border (since sides=0)
        let r1 = BoxBorder.lerp(visualWithSides10, directionalWithMagentaTop5, 1.0)
        XCTAssertTrue(borderMatches(r1!, visualWithMagentaTop5))

        // At t=2.0, should be visual magenta top 10
        let r2 = BoxBorder.lerp(visualWithSides10, directionalWithMagentaTop5, 2.0)
        XCTAssertTrue(borderMatches(r2!, visualWithMagentaTop10))
    }

    /// **Dart Test:** `border_rtl_test.dart` - "BoxBorder.lerp" (visual yellow top + directional sides)
    func testBoxBorderLerpVisualYellowTopDirectionalSides() {
        let visualWithYellowTop5: BoxBorder = Border(
            top: BorderSide(color: Color(0xFFFFFF00), width: 5.0)
        )
        let directionalWithSides10: BoxBorder = BorderDirectional(
            start: BorderSide(width: 10.0),
            end: BorderSide(width: 20.0)
        )
        let directionalWithSides20: BoxBorder = BorderDirectional(
            start: BorderSide(width: 20.0),
            end: BorderSide(width: 40.0)
        )

        // At t=0.0, result is directional (since a has no left/right)
        let r0 = BoxBorder.lerp(visualWithYellowTop5, directionalWithSides10, 0.0)
        XCTAssertNotNil(r0)

        // At t=1.0, result is directionalWithSides10
        let r1 = BoxBorder.lerp(visualWithYellowTop5, directionalWithSides10, 1.0)
        XCTAssertEqual(r1, directionalWithSides10)

        // At t=2.0, result is directionalWithSides20
        let r2 = BoxBorder.lerp(visualWithYellowTop5, directionalWithSides10, 2.0)
        XCTAssertEqual(r2, directionalWithSides20)
    }

    // MARK: - BoxBorder.getInnerPath / getOuterPath Tests

    /// **Dart Test:** `border_rtl_test.dart` - "BoxBorder.getInnerPath / BoxBorder.getOuterPath"
    func testBorderGetOuterPath() {
        let border = Border(top: BorderSide(width: 10.0), right: BorderSide(width: 20.0))
        let outerPath = border.getOuterPath(
            Rect.fromLTRB(50.0, 60.0, 110.0, 190.0),
            textDirection: .rtl
        )
        // Outer path should be the full rect
        let bounds = outerPath.getBounds()
        XCTAssertEqual(bounds.left, 50.0, accuracy: 0.1)
        XCTAssertEqual(bounds.top, 60.0, accuracy: 0.1)
        XCTAssertEqual(bounds.right, 110.0, accuracy: 0.1)
        XCTAssertEqual(bounds.bottom, 190.0, accuracy: 0.1)
    }

    /// Test Border getInnerPath with text direction.
    func testBorderGetInnerPath() {
        let border = Border(top: BorderSide(width: 10.0), right: BorderSide(width: 20.0))
        let innerPath = border.getInnerPath(
            Rect.fromLTRB(50.0, 60.0, 110.0, 190.0),
            textDirection: .rtl
        )
        // Inner path should be deflated by the border dimensions
        // left: 0, top: 10, right: 20, bottom: 0
        // So inner rect is from (50, 70) to (90, 190)
        let bounds = innerPath.getBounds()
        XCTAssertEqual(bounds.left, 50.0, accuracy: 0.1)
        XCTAssertEqual(bounds.top, 70.0, accuracy: 0.1)
        XCTAssertEqual(bounds.right, 90.0, accuracy: 0.1)
        XCTAssertEqual(bounds.bottom, 190.0, accuracy: 0.1)
    }

    /// Test BorderDirectional getOuterPath with text direction.
    func testBorderDirectionalGetOuterPath() {
        let borderDirectional = BorderDirectional(
            top: BorderSide(width: 10.0),
            end: BorderSide(width: 20.0)
        )
        let outerPath = borderDirectional.getOuterPath(
            Rect.fromLTRB(50.0, 60.0, 110.0, 190.0),
            textDirection: .rtl
        )
        let bounds = outerPath.getBounds()
        XCTAssertEqual(bounds.left, 50.0, accuracy: 0.1)
        XCTAssertEqual(bounds.top, 60.0, accuracy: 0.1)
        XCTAssertEqual(bounds.right, 110.0, accuracy: 0.1)
        XCTAssertEqual(bounds.bottom, 190.0, accuracy: 0.1)
    }

    /// Test BorderDirectional getInnerPath with RTL text direction.
    func testBorderDirectionalGetInnerPathRTL() {
        let borderDirectional = BorderDirectional(
            top: BorderSide(width: 10.0),
            end: BorderSide(width: 20.0)
        )
        // In RTL, end maps to left, so inner rect deflated by left:20, top:10
        let innerPath = borderDirectional.getInnerPath(
            Rect.fromLTRB(50.0, 60.0, 110.0, 190.0),
            textDirection: .rtl
        )
        let bounds = innerPath.getBounds()
        // dimensions are EdgeInsetsDirectional(start: 0, top: 10, end: 20, bottom: 0)
        // In RTL: left=end=20, right=start=0
        XCTAssertEqual(bounds.left, 70.0, accuracy: 0.1)
        XCTAssertEqual(bounds.top, 70.0, accuracy: 0.1)
        XCTAssertEqual(bounds.right, 110.0, accuracy: 0.1)
        XCTAssertEqual(bounds.bottom, 190.0, accuracy: 0.1)
    }

    /// Test BorderDirectional getInnerPath with LTR text direction.
    func testBorderDirectionalGetInnerPathLTR() {
        let borderDirectional = BorderDirectional(
            top: BorderSide(width: 10.0),
            end: BorderSide(width: 20.0)
        )
        // In LTR, end maps to right, so inner rect deflated by right:20, top:10
        let innerPath = borderDirectional.getInnerPath(
            Rect.fromLTRB(50.0, 60.0, 110.0, 190.0),
            textDirection: .ltr
        )
        let bounds = innerPath.getBounds()
        // dimensions are EdgeInsetsDirectional(start: 0, top: 10, end: 20, bottom: 0)
        // In LTR: left=start=0, right=end=20
        XCTAssertEqual(bounds.left, 50.0, accuracy: 0.1)
        XCTAssertEqual(bounds.top, 70.0, accuracy: 0.1)
        XCTAssertEqual(bounds.right, 90.0, accuracy: 0.1)
        XCTAssertEqual(bounds.bottom, 190.0, accuracy: 0.1)
    }

    // MARK: - BoxBorder.paintInterior Tests

    /// Test that paintInterior draws a rect.
    func testBoxBorderPaintInterior() {
        let canvas = BoxBorderMockCanvas()
        let border = Border()
        let paint = Paint()
        border.paintInterior(canvas, Rect.fromLTWH(0, 0, 100, 100), paint)
        XCTAssertEqual(canvas.calls.count, 1)
    }

    /// Test that preferPaintInterior returns true for BoxBorder.
    func testBoxBorderPreferPaintInterior() {
        let border = Border()
        XCTAssertTrue(border.preferPaintInterior)
    }
}

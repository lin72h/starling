// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for paintZigZag utility function.
///
/// Since no dedicated Dart test file exists for `paint_utilities.dart`, these tests
/// verify the paintZigZag function behavior using a mock Canvas that records calls.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/paint_utilities.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Mock Canvas for PaintUtilities Tests

/// A mock Canvas that records method calls for verification of paintZigZag behavior.
///
/// Tracks save, restore, translate, rotate, and drawPath calls along with
/// the Path contents to verify zigzag construction.
final class PaintUtilitiesMockCanvas: Canvas {

    // MARK: - Call Tracking

    enum Call: Equatable {
        case save
        case restore
        case translate(dx: Double, dy: Double)
        case rotate(radians: Double)
        case drawPath
    }

    var calls: [Call] = []
    var drawnPath: Path?

    // MARK: - Save/Restore Stack

    func save() {
        calls.append(.save)
    }

    func saveLayer(_ bounds: Rect?, _ paint: Paint) {}

    func restore() {
        calls.append(.restore)
    }

    func restoreToCount(_ count: Int) {}
    func getSaveCount() -> Int { return 1 }

    // MARK: - Transform

    func translate(_ dx: Double, _ dy: Double) {
        calls.append(.translate(dx: dx, dy: dy))
    }

    func scale(_ sx: Double, _ sy: Double?) {}

    func rotate(_ radians: Double) {
        calls.append(.rotate(radians: radians))
    }

    func skew(_ sx: Double, _ sy: Double) {}
    func transform(_ matrix4: [Double]) {}
    func getTransform() -> [Double] { return [Double](repeating: 0, count: 16) }

    // MARK: - Clip

    func clipRect(_ rect: Rect, clipOp: ClipOp, doAntiAlias: Bool) {}
    func clipRRect(_ rrect: RRect, doAntiAlias: Bool) {}
    func clipRSuperellipse(_ rsuperellipse: RSuperellipse, doAntiAlias: Bool) {}
    func clipPath(_ path: Path, doAntiAlias: Bool) {}
    func getLocalClipBounds() -> Rect { return .zero }
    func getDestinationClipBounds() -> Rect { return .zero }

    // MARK: - Drawing Methods

    func drawColor(_ color: Color, _ blendMode: BlendMode) {}
    func drawLine(_ p1: Offset, _ p2: Offset, _ paint: Paint) {}
    func drawPaint(_ paint: Paint) {}
    func drawRect(_ rect: Rect, _ paint: Paint) {}
    func drawRRect(_ rrect: RRect, _ paint: Paint) {}
    func drawDRRect(_ outer: RRect, _ inner: RRect, _ paint: Paint) {}
    func drawRSuperellipse(_ rsuperellipse: RSuperellipse, _ paint: Paint) {}
    func drawOval(_ rect: Rect, _ paint: Paint) {}
    func drawCircle(_ c: Offset, _ radius: Double, _ paint: Paint) {}
    func drawArc(_ rect: Rect, _ startAngle: Double, _ sweepAngle: Double, _ useCenter: Bool, _ paint: Paint) {}

    func drawPath(_ path: Path, _ paint: Paint) {
        calls.append(.drawPath)
        drawnPath = path
    }

    func drawImage(_ image: Image, _ offset: Offset, _ paint: Paint) {}
    func drawImageRect(_ image: Image, _ src: Rect, _ dst: Rect, _ paint: Paint) {}
    func drawImageNine(_ image: Image, _ center: Rect, _ dst: Rect, _ paint: Paint) {}
    func drawPicture(_ picture: any FlutterSwiftBridge.Picture) {}
    func drawParagraph(_ paragraph: any Paragraph, _ offset: Offset) {}
    func drawPoints(_ pointMode: PointMode, _ points: [Offset], _ paint: Paint) {}
    func drawRawPoints(_ pointMode: PointMode, _ points: [Float], _ paint: Paint) {}
    func drawVertices(_ vertices: Vertices, _ blendMode: BlendMode, _ paint: Paint) {}
    func drawAtlas(
        _ atlas: Image,
        _ transforms: [RSTransform],
        _ rects: [Rect],
        _ colors: [Color]?,
        _ blendMode: BlendMode?,
        _ cullRect: Rect?,
        _ paint: Paint
    ) {}
    func drawRawAtlas(
        _ atlas: Image,
        _ rstTransforms: [Float],
        _ rects: [Float],
        _ colors: [Int32]?,
        _ blendMode: BlendMode?,
        _ cullRect: Rect?,
        _ paint: Paint
    ) {}
    func drawShadow(_ path: Path, _ color: Color, _ elevation: Double, _ transparentOccluder: Bool) {}
}

// MARK: - PaintUtilitiesTests

/// Tests for the `paintZigZag` function.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/paint_utilities.dart:9-41`
final class PaintUtilitiesTests: XCTestCase {

    // MARK: - Properties

    var mockCanvas: PaintUtilitiesMockCanvas!
    var paint: Paint!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockCanvas = PaintUtilitiesMockCanvas()
        paint = Paint()
    }

    override func tearDown() {
        mockCanvas = nil
        paint = nil
        super.tearDown()
    }

    // MARK: - Canvas Call Order Tests

    /// Test that paintZigZag calls canvas methods in correct order:
    /// save, translate, rotate, drawPath, restore.
    ///
    /// **Dart Source:** `paint_utilities.dart:26-40`
    func testPaintZigZagCallOrder() {
        let start = Offset(10.0, 20.0)
        let end = Offset(110.0, 20.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 4, width: 10.0)

        // Verify call order: save, translate, rotate, drawPath, restore
        XCTAssertEqual(mockCanvas.calls.count, 5)
        XCTAssertEqual(mockCanvas.calls[0], .save)
        XCTAssertEqual(mockCanvas.calls[1], .translate(dx: 10.0, dy: 20.0))
        // rotate should be called (angle depends on direction)
        if case .rotate = mockCanvas.calls[2] {
            // expected
        } else {
            XCTFail("Expected rotate call at index 2, got \(mockCanvas.calls[2])")
        }
        XCTAssertEqual(mockCanvas.calls[3], .drawPath)
        XCTAssertEqual(mockCanvas.calls[4], .restore)
    }

    /// Test that paintZigZag translates to the start point.
    ///
    /// **Dart Source:** `paint_utilities.dart:27`
    func testPaintZigZagTranslatesToStartPoint() {
        let start = Offset(50.0, 75.0)
        let end = Offset(150.0, 75.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 2, width: 5.0)

        XCTAssertEqual(mockCanvas.calls[1], .translate(dx: 50.0, dy: 75.0))
    }

    /// Test that paintZigZag rotates by the correct angle for a horizontal line.
    ///
    /// **Dart Source:** `paint_utilities.dart:28-29`
    func testPaintZigZagRotationHorizontalLine() {
        let start = Offset(0.0, 0.0)
        let end = Offset(100.0, 0.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 2, width: 5.0)

        // atan2(0, 100) = 0.0 for a horizontal line going right
        XCTAssertEqual(mockCanvas.calls[2], .rotate(radians: 0.0))
    }

    /// Test that paintZigZag rotates by the correct angle for a vertical line.
    ///
    /// **Dart Source:** `paint_utilities.dart:28-29`
    func testPaintZigZagRotationVerticalLine() {
        let start = Offset(0.0, 0.0)
        let end = Offset(0.0, 100.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 2, width: 5.0)

        // atan2(100, 0) = pi/2 for a vertical line going down
        XCTAssertEqual(mockCanvas.calls[2], .rotate(radians: Double.pi / 2.0))
    }

    /// Test that paintZigZag rotates by the correct angle for a diagonal line.
    ///
    /// **Dart Source:** `paint_utilities.dart:28-29`
    func testPaintZigZagRotationDiagonalLine() {
        let start = Offset(0.0, 0.0)
        let end = Offset(100.0, 100.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 2, width: 5.0)

        // atan2(100, 100) = pi/4 for a 45-degree diagonal line
        XCTAssertEqual(mockCanvas.calls[2], .rotate(radians: Double.pi / 4.0))
    }

    // MARK: - Save/Restore Balance Tests

    /// Test that save/restore calls are balanced.
    ///
    /// **Dart Source:** `paint_utilities.dart:26,40`
    func testPaintZigZagSaveRestoreBalance() {
        let start = Offset(0.0, 0.0)
        let end = Offset(100.0, 0.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 3, width: 10.0)

        let saveCount = mockCanvas.calls.filter { $0 == .save }.count
        let restoreCount = mockCanvas.calls.filter { $0 == .restore }.count
        XCTAssertEqual(saveCount, 1, "Should have exactly 1 save call")
        XCTAssertEqual(restoreCount, 1, "Should have exactly 1 restore call")
    }

    // MARK: - drawPath Call Tests

    /// Test that paintZigZag calls drawPath exactly once.
    ///
    /// **Dart Source:** `paint_utilities.dart:39`
    func testPaintZigZagDrawsPathOnce() {
        let start = Offset(0.0, 0.0)
        let end = Offset(100.0, 0.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 5, width: 10.0)

        let drawPathCount = mockCanvas.calls.filter { $0 == .drawPath }.count
        XCTAssertEqual(drawPathCount, 1, "Should call drawPath exactly once")
    }

    // MARK: - Various Zig Counts Tests

    /// Test paintZigZag with a single zig (triangle shape).
    ///
    /// **Dart Source:** `paint_utilities.dart:33-37` - loop body with zigs=1
    func testPaintZigZagSingleZig() {
        let start = Offset(0.0, 0.0)
        let end = Offset(100.0, 0.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 1, width: 10.0)

        // Should still complete without error
        XCTAssertEqual(mockCanvas.calls.count, 5)
        XCTAssertNotNil(mockCanvas.drawnPath)
    }

    /// Test paintZigZag with many zigs.
    ///
    /// **Dart Source:** `paint_utilities.dart:33-37` - loop body with many iterations
    func testPaintZigZagManyZigs() {
        let start = Offset(0.0, 0.0)
        let end = Offset(100.0, 0.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 100, width: 5.0)

        // Should still complete without error
        XCTAssertEqual(mockCanvas.calls.count, 5)
        XCTAssertNotNil(mockCanvas.drawnPath)
    }

    // MARK: - Width Variation Tests

    /// Test paintZigZag with negative width (reversed zigzag polarity).
    ///
    /// **Dart Source:** `paint_utilities.dart:35` - width affects y calculation
    func testPaintZigZagNegativeWidth() {
        let start = Offset(0.0, 0.0)
        let end = Offset(100.0, 0.0)

        // Should not crash; negative width simply reverses the zig direction
        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 4, width: -10.0)

        XCTAssertEqual(mockCanvas.calls.count, 5)
        XCTAssertNotNil(mockCanvas.drawnPath)
    }

    /// Test paintZigZag with zero width (flat line through zigzag points).
    ///
    /// **Dart Source:** `paint_utilities.dart:35` - width=0 means y=0 for all points
    func testPaintZigZagZeroWidth() {
        let start = Offset(0.0, 0.0)
        let end = Offset(100.0, 0.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 4, width: 0.0)

        XCTAssertEqual(mockCanvas.calls.count, 5)
        XCTAssertNotNil(mockCanvas.drawnPath)
    }

    // MARK: - Start/End Coincident Points

    /// Test paintZigZag when start and end are the same point.
    ///
    /// **Dart Source:** `paint_utilities.dart:30-31` - length=0, spacing=0
    func testPaintZigZagCoincidentPoints() {
        let point = Offset(50.0, 50.0)

        // When start == end, length is 0 and spacing is 0
        // All x values will be 0.0 and path.lineTo(0, y) repeatedly
        paintZigZag(mockCanvas, paint: paint, start: point, end: point, zigs: 3, width: 10.0)

        XCTAssertEqual(mockCanvas.calls.count, 5)
        XCTAssertNotNil(mockCanvas.drawnPath)
    }

    // MARK: - Offset Translation Tests

    /// Test that paintZigZag with a non-origin start correctly translates.
    ///
    /// **Dart Source:** `paint_utilities.dart:27-28`
    func testPaintZigZagWithNonOriginStart() {
        let start = Offset(200.0, 300.0)
        let end = Offset(400.0, 300.0)

        paintZigZag(mockCanvas, paint: paint, start: start, end: end, zigs: 5, width: 15.0)

        // Canvas should be translated to start position
        XCTAssertEqual(mockCanvas.calls[1], .translate(dx: 200.0, dy: 300.0))
        // Rotation should be atan2(0, 200) = 0 for horizontal
        XCTAssertEqual(mockCanvas.calls[2], .rotate(radians: 0.0))
    }
}

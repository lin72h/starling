// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for ClipContext.
///
/// Since no dedicated Dart test file exists for `clip.dart`, these tests verify
/// the ClipContext protocol extension behavior using a mock Canvas.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/clip.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Mock Canvas

/// A mock Canvas that records method calls for verification.
///
/// This tracks save/restore calls, clip calls, and saveLayer calls
/// to verify correct ClipContext behavior.
final class MockCanvas: Canvas {

    // MARK: - Call Tracking

    enum Call: Equatable {
        case save
        case restore
        case saveLayer
        case clipPath(doAntiAlias: Bool)
        case clipRRect(doAntiAlias: Bool)
        case clipRSuperellipse(doAntiAlias: Bool)
        case clipRect(doAntiAlias: Bool)
    }

    var calls: [Call] = []

    // MARK: - Save/Restore Stack

    func save() {
        calls.append(.save)
    }

    func saveLayer(_ bounds: Rect?, _ paint: Paint) {
        calls.append(.saveLayer)
    }

    func restore() {
        calls.append(.restore)
    }

    func restoreToCount(_ count: Int) {}
    func getSaveCount() -> Int { return 1 }

    // MARK: - Transform

    func translate(_ dx: Double, _ dy: Double) {}
    func scale(_ sx: Double, _ sy: Double?) {}
    func rotate(_ radians: Double) {}
    func skew(_ sx: Double, _ sy: Double) {}
    func transform(_ matrix4: [Double]) {}
    func getTransform() -> [Double] { return [Double](repeating: 0, count: 16) }

    // MARK: - Clip

    func clipRect(_ rect: Rect, clipOp: ClipOp, doAntiAlias: Bool) {
        calls.append(.clipRect(doAntiAlias: doAntiAlias))
    }

    func clipRRect(_ rrect: RRect, doAntiAlias: Bool) {
        calls.append(.clipRRect(doAntiAlias: doAntiAlias))
    }

    func clipRSuperellipse(_ rsuperellipse: RSuperellipse, doAntiAlias: Bool) {
        calls.append(.clipRSuperellipse(doAntiAlias: doAntiAlias))
    }

    func clipPath(_ path: Path, doAntiAlias: Bool) {
        calls.append(.clipPath(doAntiAlias: doAntiAlias))
    }

    func getLocalClipBounds() -> Rect { return .zero }
    func getDestinationClipBounds() -> Rect { return .zero }

    // MARK: - Drawing Methods (stubs)

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
    func drawPath(_ path: Path, _ paint: Paint) {}
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

// MARK: - Test ClipContext Implementation

/// A concrete implementation of ClipContext for testing.
final class TestClipContext: ClipContext {
    let canvas: Canvas

    init(canvas: Canvas) {
        self.canvas = canvas
    }
}

// MARK: - ClipTests

final class ClipTests: XCTestCase {

    // MARK: - Properties

    var mockCanvas: MockCanvas!
    var clipContext: TestClipContext!

    let testBounds = Rect.fromLTWH(0, 0, 100, 100)

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockCanvas = MockCanvas()
        clipContext = TestClipContext(canvas: mockCanvas)
    }

    override func tearDown() {
        mockCanvas = nil
        clipContext = nil
        super.tearDown()
    }

    // MARK: - clipPathAndPaint Tests

    /// Test clipPathAndPaint with Clip.none.
    /// The canvas should be saved and restored, but no clip call should be made.
    ///
    /// **Dart Source:** `clip.dart:22-24` - Clip.none case
    func testClipPathAndPaintWithNone() {
        var painterCalled = false
        let path = Path()

        clipContext.clipPathAndPaint(
            path,
            clipBehavior: .none,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            // No clip call for .none
            .restore,
        ])
    }

    /// Test clipPathAndPaint with Clip.hardEdge.
    /// The clip should be called with doAntiAlias = false.
    ///
    /// **Dart Source:** `clip.dart:25-26` - Clip.hardEdge case
    func testClipPathAndPaintWithHardEdge() {
        var painterCalled = false
        let path = Path()

        clipContext.clipPathAndPaint(
            path,
            clipBehavior: .hardEdge,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipPath(doAntiAlias: false),
            .restore,
        ])
    }

    /// Test clipPathAndPaint with Clip.antiAlias.
    /// The clip should be called with doAntiAlias = true.
    ///
    /// **Dart Source:** `clip.dart:27-28` - Clip.antiAlias case
    func testClipPathAndPaintWithAntiAlias() {
        var painterCalled = false
        let path = Path()

        clipContext.clipPathAndPaint(
            path,
            clipBehavior: .antiAlias,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipPath(doAntiAlias: true),
            .restore,
        ])
    }

    /// Test clipPathAndPaint with Clip.antiAliasWithSaveLayer.
    /// The clip should be called with doAntiAlias = true, and saveLayer/restore should be added.
    ///
    /// **Dart Source:** `clip.dart:29-36` - Clip.antiAliasWithSaveLayer case
    func testClipPathAndPaintWithAntiAliasWithSaveLayer() {
        var painterCalled = false
        let path = Path()

        clipContext.clipPathAndPaint(
            path,
            clipBehavior: .antiAliasWithSaveLayer,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipPath(doAntiAlias: true),
            .saveLayer,
            .restore,  // restore for saveLayer
            .restore,  // restore for save
        ])
    }

    // MARK: - clipRRectAndPaint Tests

    /// Test clipRRectAndPaint with Clip.none.
    ///
    /// **Dart Source:** `clip.dart:57-64`
    func testClipRRectAndPaintWithNone() {
        var painterCalled = false
        let rrect = RRect(fromRectXY: testBounds, 10, 10)

        clipContext.clipRRectAndPaint(
            rrect,
            clipBehavior: .none,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .restore,
        ])
    }

    /// Test clipRRectAndPaint with Clip.hardEdge.
    ///
    /// **Dart Source:** `clip.dart:57-64`
    func testClipRRectAndPaintWithHardEdge() {
        var painterCalled = false
        let rrect = RRect(fromRectXY: testBounds, 10, 10)

        clipContext.clipRRectAndPaint(
            rrect,
            clipBehavior: .hardEdge,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipRRect(doAntiAlias: false),
            .restore,
        ])
    }

    /// Test clipRRectAndPaint with Clip.antiAlias.
    ///
    /// **Dart Source:** `clip.dart:57-64`
    func testClipRRectAndPaintWithAntiAlias() {
        var painterCalled = false
        let rrect = RRect(fromRectXY: testBounds, 10, 10)

        clipContext.clipRRectAndPaint(
            rrect,
            clipBehavior: .antiAlias,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipRRect(doAntiAlias: true),
            .restore,
        ])
    }

    /// Test clipRRectAndPaint with Clip.antiAliasWithSaveLayer.
    ///
    /// **Dart Source:** `clip.dart:57-64`
    func testClipRRectAndPaintWithAntiAliasWithSaveLayer() {
        var painterCalled = false
        let rrect = RRect(fromRectXY: testBounds, 10, 10)

        clipContext.clipRRectAndPaint(
            rrect,
            clipBehavior: .antiAliasWithSaveLayer,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipRRect(doAntiAlias: true),
            .saveLayer,
            .restore,
            .restore,
        ])
    }

    // MARK: - clipRSuperellipseAndPaint Tests

    /// Test clipRSuperellipseAndPaint with Clip.none.
    ///
    /// **Dart Source:** `clip.dart:71-83`
    func testClipRSuperellipseAndPaintWithNone() {
        var painterCalled = false
        let rse = RSuperellipse(
            left: 0, top: 0, right: 100, bottom: 100,
            tlRadiusX: 10, tlRadiusY: 10,
            trRadiusX: 10, trRadiusY: 10,
            brRadiusX: 10, brRadiusY: 10,
            blRadiusX: 10, blRadiusY: 10
        )

        clipContext.clipRSuperellipseAndPaint(
            rse,
            clipBehavior: .none,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .restore,
        ])
    }

    /// Test clipRSuperellipseAndPaint with Clip.hardEdge.
    ///
    /// **Dart Source:** `clip.dart:71-83`
    func testClipRSuperellipseAndPaintWithHardEdge() {
        var painterCalled = false
        let rse = RSuperellipse(
            left: 0, top: 0, right: 100, bottom: 100,
            tlRadiusX: 10, tlRadiusY: 10,
            trRadiusX: 10, trRadiusY: 10,
            brRadiusX: 10, brRadiusY: 10,
            blRadiusX: 10, blRadiusY: 10
        )

        clipContext.clipRSuperellipseAndPaint(
            rse,
            clipBehavior: .hardEdge,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipRSuperellipse(doAntiAlias: false),
            .restore,
        ])
    }

    /// Test clipRSuperellipseAndPaint with Clip.antiAlias.
    ///
    /// **Dart Source:** `clip.dart:71-83`
    func testClipRSuperellipseAndPaintWithAntiAlias() {
        var painterCalled = false
        let rse = RSuperellipse(
            left: 0, top: 0, right: 100, bottom: 100,
            tlRadiusX: 10, tlRadiusY: 10,
            trRadiusX: 10, trRadiusY: 10,
            brRadiusX: 10, brRadiusY: 10,
            blRadiusX: 10, blRadiusY: 10
        )

        clipContext.clipRSuperellipseAndPaint(
            rse,
            clipBehavior: .antiAlias,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipRSuperellipse(doAntiAlias: true),
            .restore,
        ])
    }

    /// Test clipRSuperellipseAndPaint with Clip.antiAliasWithSaveLayer.
    ///
    /// **Dart Source:** `clip.dart:71-83`
    func testClipRSuperellipseAndPaintWithAntiAliasWithSaveLayer() {
        var painterCalled = false
        let rse = RSuperellipse(
            left: 0, top: 0, right: 100, bottom: 100,
            tlRadiusX: 10, tlRadiusY: 10,
            trRadiusX: 10, trRadiusY: 10,
            brRadiusX: 10, brRadiusY: 10,
            blRadiusX: 10, blRadiusY: 10
        )

        clipContext.clipRSuperellipseAndPaint(
            rse,
            clipBehavior: .antiAliasWithSaveLayer,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipRSuperellipse(doAntiAlias: true),
            .saveLayer,
            .restore,
            .restore,
        ])
    }

    // MARK: - clipRectAndPaint Tests

    /// Test clipRectAndPaint with Clip.none.
    ///
    /// **Dart Source:** `clip.dart:89-96`
    func testClipRectAndPaintWithNone() {
        var painterCalled = false
        let rect = Rect.fromLTWH(10, 10, 50, 50)

        clipContext.clipRectAndPaint(
            rect,
            clipBehavior: .none,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .restore,
        ])
    }

    /// Test clipRectAndPaint with Clip.hardEdge.
    ///
    /// **Dart Source:** `clip.dart:89-96`
    func testClipRectAndPaintWithHardEdge() {
        var painterCalled = false
        let rect = Rect.fromLTWH(10, 10, 50, 50)

        clipContext.clipRectAndPaint(
            rect,
            clipBehavior: .hardEdge,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipRect(doAntiAlias: false),
            .restore,
        ])
    }

    /// Test clipRectAndPaint with Clip.antiAlias.
    ///
    /// **Dart Source:** `clip.dart:89-96`
    func testClipRectAndPaintWithAntiAlias() {
        var painterCalled = false
        let rect = Rect.fromLTWH(10, 10, 50, 50)

        clipContext.clipRectAndPaint(
            rect,
            clipBehavior: .antiAlias,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipRect(doAntiAlias: true),
            .restore,
        ])
    }

    /// Test clipRectAndPaint with Clip.antiAliasWithSaveLayer.
    ///
    /// **Dart Source:** `clip.dart:89-96`
    func testClipRectAndPaintWithAntiAliasWithSaveLayer() {
        var painterCalled = false
        let rect = Rect.fromLTWH(10, 10, 50, 50)

        clipContext.clipRectAndPaint(
            rect,
            clipBehavior: .antiAliasWithSaveLayer,
            bounds: testBounds,
            painter: { painterCalled = true }
        )

        XCTAssertTrue(painterCalled, "Painter should always be called")
        XCTAssertEqual(mockCanvas.calls, [
            .save,
            .clipRect(doAntiAlias: true),
            .saveLayer,
            .restore,
            .restore,
        ])
    }

    // MARK: - Save/Restore Balance Tests

    /// Test that save/restore calls are balanced for Clip.none (1 save, 1 restore).
    ///
    /// **Dart Source:** `clip.dart:21,37` - save() and restore()
    func testSaveRestoreBalanceForNone() {
        let path = Path()

        clipContext.clipPathAndPaint(
            path,
            clipBehavior: .none,
            bounds: testBounds,
            painter: {}
        )

        let saveCount = mockCanvas.calls.filter { $0 == .save }.count
        let restoreCount = mockCanvas.calls.filter { $0 == .restore }.count
        XCTAssertEqual(saveCount, 1, "Should have exactly 1 save call")
        XCTAssertEqual(restoreCount, 1, "Should have exactly 1 restore call")
    }

    /// Test that save/restore calls are balanced for Clip.antiAliasWithSaveLayer
    /// (1 save + 1 saveLayer, 2 restores).
    ///
    /// **Dart Source:** `clip.dart:21,30-31,34-37` - save, saveLayer, and restores
    func testSaveRestoreBalanceForAntiAliasWithSaveLayer() {
        let path = Path()

        clipContext.clipPathAndPaint(
            path,
            clipBehavior: .antiAliasWithSaveLayer,
            bounds: testBounds,
            painter: {}
        )

        let saveCount = mockCanvas.calls.filter { $0 == .save }.count
        let saveLayerCount = mockCanvas.calls.filter { $0 == .saveLayer }.count
        let restoreCount = mockCanvas.calls.filter { $0 == .restore }.count
        XCTAssertEqual(saveCount, 1, "Should have exactly 1 save call")
        XCTAssertEqual(saveLayerCount, 1, "Should have exactly 1 saveLayer call")
        XCTAssertEqual(restoreCount, 2, "Should have exactly 2 restore calls (one for saveLayer, one for save)")
    }

    // MARK: - Painter Always Called Tests

    /// Verify the painter closure is called regardless of clip behavior.
    ///
    /// **Dart Source:** `clip.dart:33` - painter() is always called
    func testPainterAlwaysCalledForAllClipBehaviors() {
        let path = Path()
        let clipBehaviors: [Clip] = [.none, .hardEdge, .antiAlias, .antiAliasWithSaveLayer]

        for behavior in clipBehaviors {
            mockCanvas.calls.removeAll()
            var painterCalled = false

            clipContext.clipPathAndPaint(
                path,
                clipBehavior: behavior,
                bounds: testBounds,
                painter: { painterCalled = true }
            )

            XCTAssertTrue(painterCalled, "Painter should be called for clip behavior: \(behavior)")
        }
    }
}

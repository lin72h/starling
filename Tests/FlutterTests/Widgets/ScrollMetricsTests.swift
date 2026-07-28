// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
import FlutterSwiftBridge

/// Tests for the ScrollMetrics protocol and FixedScrollMetrics class.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/scroll_metrics.dart`
final class ScrollMetricsTests: XCTestCase {

    // MARK: - FixedScrollMetrics Initialization

    func testFixedScrollMetricsInit() {
        let metrics = FixedScrollMetrics(
            minScrollExtent: 0.0,
            maxScrollExtent: 100.0,
            pixels: 50.0,
            viewportDimension: 200.0,
            axisDirection: .down,
            devicePixelRatio: 2.0
        )
        XCTAssertEqual(metrics.minScrollExtent, 0.0)
        XCTAssertEqual(metrics.maxScrollExtent, 100.0)
        XCTAssertEqual(metrics.pixels, 50.0)
        XCTAssertEqual(metrics.viewportDimension, 200.0)
        XCTAssertEqual(metrics.axisDirection, .down)
        XCTAssertEqual(metrics.devicePixelRatio, 2.0)
    }

    func testFixedScrollMetricsHasContentDimensions() {
        let withDimensions = FixedScrollMetrics(
            minScrollExtent: 0.0,
            maxScrollExtent: 100.0,
            pixels: 50.0,
            viewportDimension: 200.0,
            axisDirection: .down,
            devicePixelRatio: 1.0
        )
        XCTAssertTrue(withDimensions.hasContentDimensions)

        let withoutMin = FixedScrollMetrics(
            minScrollExtent: nil,
            maxScrollExtent: 100.0,
            pixels: 50.0,
            viewportDimension: 200.0,
            axisDirection: .down,
            devicePixelRatio: 1.0
        )
        XCTAssertFalse(withoutMin.hasContentDimensions)

        let withoutMax = FixedScrollMetrics(
            minScrollExtent: 0.0,
            maxScrollExtent: nil,
            pixels: 50.0,
            viewportDimension: 200.0,
            axisDirection: .down,
            devicePixelRatio: 1.0
        )
        XCTAssertFalse(withoutMax.hasContentDimensions)
    }

    func testFixedScrollMetricsHasPixels() {
        let withPixels = FixedScrollMetrics(
            minScrollExtent: 0.0,
            maxScrollExtent: 100.0,
            pixels: 50.0,
            viewportDimension: 200.0,
            axisDirection: .down,
            devicePixelRatio: 1.0
        )
        XCTAssertTrue(withPixels.hasPixels)

        let withoutPixels = FixedScrollMetrics(
            minScrollExtent: 0.0,
            maxScrollExtent: 100.0,
            pixels: nil,
            viewportDimension: 200.0,
            axisDirection: .down,
            devicePixelRatio: 1.0
        )
        XCTAssertFalse(withoutPixels.hasPixels)
    }

    func testFixedScrollMetricsHasViewportDimension() {
        let withViewport = FixedScrollMetrics(
            minScrollExtent: 0.0,
            maxScrollExtent: 100.0,
            pixels: 50.0,
            viewportDimension: 200.0,
            axisDirection: .down,
            devicePixelRatio: 1.0
        )
        XCTAssertTrue(withViewport.hasViewportDimension)

        let withoutViewport = FixedScrollMetrics(
            minScrollExtent: 0.0,
            maxScrollExtent: 100.0,
            pixels: 50.0,
            viewportDimension: nil,
            axisDirection: .down,
            devicePixelRatio: 1.0
        )
        XCTAssertFalse(withoutViewport.hasViewportDimension)
    }

    // MARK: - Axis

    func testAxisVerticalDown() {
        let metrics = makeMetrics(axisDirection: .down)
        XCTAssertEqual(metrics.axis, .vertical)
    }

    func testAxisVerticalUp() {
        let metrics = makeMetrics(axisDirection: .up)
        XCTAssertEqual(metrics.axis, .vertical)
    }

    func testAxisHorizontalRight() {
        let metrics = makeMetrics(axisDirection: .right)
        XCTAssertEqual(metrics.axis, .horizontal)
    }

    func testAxisHorizontalLeft() {
        let metrics = makeMetrics(axisDirection: .left)
        XCTAssertEqual(metrics.axis, .horizontal)
    }

    // MARK: - extentBefore, extentInside, extentAfter

    func testExtentsAtStart() {
        // pixels == minScrollExtent: nothing before, everything inside/after
        let metrics = makeMetrics(min: 0, max: 300, pixels: 0, viewport: 200)
        XCTAssertEqual(metrics.extentBefore, 0.0)
        XCTAssertEqual(metrics.extentInside, 200.0)
        XCTAssertEqual(metrics.extentAfter, 300.0)
    }

    func testExtentsInMiddle() {
        // pixels in middle: content before, inside, and after
        let metrics = makeMetrics(min: 0, max: 300, pixels: 100, viewport: 200)
        XCTAssertEqual(metrics.extentBefore, 100.0)
        XCTAssertEqual(metrics.extentInside, 200.0)
        XCTAssertEqual(metrics.extentAfter, 200.0)
    }

    func testExtentsAtEnd() {
        // pixels == maxScrollExtent: everything before, nothing after
        let metrics = makeMetrics(min: 0, max: 300, pixels: 300, viewport: 200)
        XCTAssertEqual(metrics.extentBefore, 300.0)
        XCTAssertEqual(metrics.extentInside, 200.0)
        XCTAssertEqual(metrics.extentAfter, 0.0)
    }

    func testExtentsOverscrollBefore() {
        // pixels < minScrollExtent: overscrolled before start
        let metrics = makeMetrics(min: 0, max: 300, pixels: -50, viewport: 200)
        XCTAssertEqual(metrics.extentBefore, 0.0) // clamped to 0
        XCTAssertEqual(metrics.extentAfter, 350.0)
    }

    func testExtentsOverscrollAfter() {
        // pixels > maxScrollExtent: overscrolled past end
        let metrics = makeMetrics(min: 0, max: 300, pixels: 350, viewport: 200)
        XCTAssertEqual(metrics.extentBefore, 350.0)
        XCTAssertEqual(metrics.extentAfter, 0.0) // clamped to 0
    }

    func testExtentInsideWhenOverscrolledBefore() {
        // Overscrolled before start: extentInside shrinks
        let metrics = makeMetrics(min: 0, max: 300, pixels: -50, viewport: 200)
        // viewportDimension - clamp(min - pixels, 0, vp) - clamp(pixels - max, 0, vp)
        // = 200 - clamp(0 - (-50), 0, 200) - clamp(-50 - 300, 0, 200)
        // = 200 - clamp(50, 0, 200) - clamp(-350, 0, 200)
        // = 200 - 50 - 0 = 150
        XCTAssertEqual(metrics.extentInside, 150.0)
    }

    func testExtentInsideWhenOverscrolledAfter() {
        // Overscrolled after end: extentInside shrinks
        let metrics = makeMetrics(min: 0, max: 300, pixels: 350, viewport: 200)
        // = 200 - clamp(0 - 350, 0, 200) - clamp(350 - 300, 0, 200)
        // = 200 - 0 - 50 = 150
        XCTAssertEqual(metrics.extentInside, 150.0)
    }

    func testExtentInsideNoScrollableContent() {
        // Viewport bigger than content: extentInside == viewportDimension
        let metrics = makeMetrics(min: 0, max: 0, pixels: 0, viewport: 500)
        XCTAssertEqual(metrics.extentInside, 500.0)
        XCTAssertEqual(metrics.extentBefore, 0.0)
        XCTAssertEqual(metrics.extentAfter, 0.0)
    }

    // MARK: - extentTotal

    func testExtentTotal() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: 100, viewport: 200)
        // maxScrollExtent - minScrollExtent + viewportDimension
        // = 300 - 0 + 200 = 500
        XCTAssertEqual(metrics.extentTotal, 500.0)
    }

    func testExtentTotalWithNonZeroMin() {
        let metrics = makeMetrics(min: 50, max: 350, pixels: 100, viewport: 200)
        // = 350 - 50 + 200 = 500
        XCTAssertEqual(metrics.extentTotal, 500.0)
    }

    // MARK: - outOfRange

    func testOutOfRangeWhenInRange() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: 150, viewport: 200)
        XCTAssertFalse(metrics.outOfRange)
    }

    func testOutOfRangeAtMinEdge() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: 0, viewport: 200)
        XCTAssertFalse(metrics.outOfRange) // at edge is still in range
    }

    func testOutOfRangeAtMaxEdge() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: 300, viewport: 200)
        XCTAssertFalse(metrics.outOfRange) // at edge is still in range
    }

    func testOutOfRangeBelowMin() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: -1, viewport: 200)
        XCTAssertTrue(metrics.outOfRange)
    }

    func testOutOfRangeAboveMax() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: 301, viewport: 200)
        XCTAssertTrue(metrics.outOfRange)
    }

    // MARK: - atEdge

    func testAtEdgeAtMin() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: 0, viewport: 200)
        XCTAssertTrue(metrics.atEdge)
    }

    func testAtEdgeAtMax() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: 300, viewport: 200)
        XCTAssertTrue(metrics.atEdge)
    }

    func testAtEdgeInMiddle() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: 150, viewport: 200)
        XCTAssertFalse(metrics.atEdge)
    }

    func testAtEdgeOverscrolled() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: -10, viewport: 200)
        XCTAssertFalse(metrics.atEdge) // overscrolled past min is not "at edge"
    }

    // MARK: - copyWith

    func testCopyWithNoChanges() {
        let original = makeMetrics(min: 0, max: 300, pixels: 100, viewport: 200)
        let copy = original.copyWith()
        XCTAssertEqual(copy.minScrollExtent, 0.0)
        XCTAssertEqual(copy.maxScrollExtent, 300.0)
        XCTAssertEqual(copy.pixels, 100.0)
        XCTAssertEqual(copy.viewportDimension, 200.0)
        XCTAssertEqual(copy.axisDirection, .down)
        XCTAssertEqual(copy.devicePixelRatio, 1.0)
    }

    func testCopyWithChangedPixels() {
        let original = makeMetrics(min: 0, max: 300, pixels: 100, viewport: 200)
        let copy = original.copyWith(pixels: 250.0)
        XCTAssertEqual(copy.pixels, 250.0)
        // Other values unchanged
        XCTAssertEqual(copy.minScrollExtent, 0.0)
        XCTAssertEqual(copy.maxScrollExtent, 300.0)
        XCTAssertEqual(copy.viewportDimension, 200.0)
    }

    func testCopyWithChangedAxisDirection() {
        let original = makeMetrics(min: 0, max: 300, pixels: 100, viewport: 200)
        let copy = original.copyWith(axisDirection: .right)
        XCTAssertEqual(copy.axisDirection, .right)
        XCTAssertEqual(copy.axis, .horizontal)
    }

    func testCopyWithMultipleChanges() {
        let original = makeMetrics(min: 0, max: 300, pixels: 100, viewport: 200)
        let copy = original.copyWith(
            minScrollExtent: 10.0,
            maxScrollExtent: 500.0,
            pixels: 250.0,
            viewportDimension: 400.0,
            axisDirection: .left,
            devicePixelRatio: 3.0
        )
        XCTAssertEqual(copy.minScrollExtent, 10.0)
        XCTAssertEqual(copy.maxScrollExtent, 500.0)
        XCTAssertEqual(copy.pixels, 250.0)
        XCTAssertEqual(copy.viewportDimension, 400.0)
        XCTAssertEqual(copy.axisDirection, .left)
        XCTAssertEqual(copy.devicePixelRatio, 3.0)
    }

    func testCopyWithPreservesNilDimensions() {
        let metrics = FixedScrollMetrics(
            minScrollExtent: nil,
            maxScrollExtent: nil,
            pixels: nil,
            viewportDimension: nil,
            axisDirection: .down,
            devicePixelRatio: 1.0
        )
        let copy = metrics.copyWith()
        XCTAssertFalse(copy.hasContentDimensions)
        XCTAssertFalse(copy.hasPixels)
        XCTAssertFalse(copy.hasViewportDimension)
    }

    // MARK: - Description

    func testDescription() {
        let metrics = makeMetrics(min: 0, max: 300, pixels: 100, viewport: 200)
        let desc = metrics.description
        // Should contain the class name and extent info
        XCTAssertTrue(desc.contains("FixedScrollMetrics"))
        XCTAssertTrue(desc.contains("100.0")) // extentBefore
        XCTAssertTrue(desc.contains("[200.0]")) // extentInside
        XCTAssertTrue(desc.contains("200.0")) // extentAfter
    }

    // MARK: - Non-zero minScrollExtent

    func testNonZeroMinScrollExtent() {
        let metrics = makeMetrics(min: 100, max: 400, pixels: 200, viewport: 150)
        XCTAssertEqual(metrics.extentBefore, 100.0) // 200 - 100
        XCTAssertEqual(metrics.extentInside, 150.0) // viewport
        XCTAssertEqual(metrics.extentAfter, 200.0) // 400 - 200
        XCTAssertEqual(metrics.extentTotal, 450.0) // 400 - 100 + 150
    }

    // MARK: - Edge cases

    func testZeroViewportDimension() {
        let metrics = makeMetrics(min: 0, max: 100, pixels: 50, viewport: 0)
        XCTAssertEqual(metrics.extentBefore, 50.0)
        XCTAssertEqual(metrics.extentInside, 0.0)
        XCTAssertEqual(metrics.extentAfter, 50.0)
        XCTAssertEqual(metrics.extentTotal, 100.0)
    }

    func testEqualMinAndMaxScrollExtent() {
        // No scrollable content
        let metrics = makeMetrics(min: 0, max: 0, pixels: 0, viewport: 500)
        XCTAssertTrue(metrics.atEdge) // pixels == min == max
        XCTAssertFalse(metrics.outOfRange)
        XCTAssertEqual(metrics.extentBefore, 0.0)
        XCTAssertEqual(metrics.extentAfter, 0.0)
        XCTAssertEqual(metrics.extentTotal, 500.0)
    }

    // MARK: - Helpers

    private func makeMetrics(
        min: Double = 0,
        max: Double = 300,
        pixels: Double = 0,
        viewport: Double = 200,
        axisDirection: AxisDirection = .down,
        devicePixelRatio: Double = 1.0
    ) -> FixedScrollMetrics {
        FixedScrollMetrics(
            minScrollExtent: min,
            maxScrollExtent: max,
            pixels: pixels,
            viewportDimension: viewport,
            axisDirection: axisDirection,
            devicePixelRatio: devicePixelRatio
        )
    }
}

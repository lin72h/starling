// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for PerformanceOverlay types.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/performance_overlay_test.dart`

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - PerformanceOverlayOption Tests

final class PerformanceOverlayOptionTests: XCTestCase {

    /// Test that `displayRasterizerStatistics` has raw value 0.
    func testDisplayRasterizerStatisticsRawValue() {
        XCTAssertEqual(PerformanceOverlayOption.displayRasterizerStatistics.rawValue, 0)
    }

    /// Test that `visualizeRasterizerStatistics` has raw value 1.
    func testVisualizeRasterizerStatisticsRawValue() {
        XCTAssertEqual(PerformanceOverlayOption.visualizeRasterizerStatistics.rawValue, 1)
    }

    /// Test that `displayEngineStatistics` has raw value 2.
    func testDisplayEngineStatisticsRawValue() {
        XCTAssertEqual(PerformanceOverlayOption.displayEngineStatistics.rawValue, 2)
    }

    /// Test that `visualizeEngineStatistics` has raw value 3.
    func testVisualizeEngineStatisticsRawValue() {
        XCTAssertEqual(PerformanceOverlayOption.visualizeEngineStatistics.rawValue, 3)
    }

    /// Test that raw values can be used to reconstruct enum cases.
    func testInitFromRawValue() {
        XCTAssertEqual(PerformanceOverlayOption(rawValue: 0), .displayRasterizerStatistics)
        XCTAssertEqual(PerformanceOverlayOption(rawValue: 1), .visualizeRasterizerStatistics)
        XCTAssertEqual(PerformanceOverlayOption(rawValue: 2), .displayEngineStatistics)
        XCTAssertEqual(PerformanceOverlayOption(rawValue: 3), .visualizeEngineStatistics)
        XCTAssertNil(PerformanceOverlayOption(rawValue: 4))
    }
}

// MARK: - RenderPerformanceOverlay Construction Tests

final class RenderPerformanceOverlayConstructionTests: XCTestCase {

    /// Test that RenderPerformanceOverlay can be constructed with default optionsMask of 0.
    ///
    /// **Dart Source:** performance_overlay.dart:67
    func testDefaultConstruction() {
        let overlay = RenderPerformanceOverlay()
        XCTAssertEqual(overlay.optionsMask, 0)
    }

    /// Test that RenderPerformanceOverlay can be constructed with a custom optionsMask.
    ///
    /// **Dart Source:** performance_overlay.dart:67
    func testConstructionWithCustomOptionsMask() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        XCTAssertEqual(overlay.optionsMask, 0xF)
    }

    /// Test construction with a single option bit set.
    func testConstructionWithSingleOption() {
        let mask = 1 << PerformanceOverlayOption.displayRasterizerStatistics.rawValue
        let overlay = RenderPerformanceOverlay(optionsMask: mask)
        XCTAssertEqual(overlay.optionsMask, mask)
    }
}

// MARK: - RenderPerformanceOverlay optionsMask Setter Tests

final class RenderPerformanceOverlayOptionsMaskSetterTests: XCTestCase {

    /// Test that setting optionsMask to a new value triggers markNeedsPaint.
    ///
    /// **Dart Source:** performance_overlay.dart:71-79
    func testOptionsMaskSetterTriggersMarkNeedsPaint() {
        let overlay = RenderPerformanceOverlay()
        overlay.layout(BoxConstraints.tight(Size(200.0, 160.0)))
        overlay.needsPaint = false

        overlay.optionsMask = 0xF
        XCTAssertTrue(overlay.needsPaint, "Setting a new optionsMask should trigger markNeedsPaint")
        XCTAssertEqual(overlay.optionsMask, 0xF)
    }

    /// Test that setting optionsMask to the same value is a no-op.
    ///
    /// **Dart Source:** performance_overlay.dart:74-76 - early return on equal
    func testOptionsMaskSetterNoOpOnSameValue() {
        let overlay = RenderPerformanceOverlay(optionsMask: 5)
        overlay.layout(BoxConstraints.tight(Size(200.0, 160.0)))
        overlay.needsPaint = false

        overlay.optionsMask = 5
        XCTAssertFalse(overlay.needsPaint, "Setting the same optionsMask should not trigger markNeedsPaint")
    }

    /// Test that setting optionsMask from non-zero to zero triggers markNeedsPaint.
    func testOptionsMaskSetterFromNonZeroToZero() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        overlay.layout(BoxConstraints.tight(Size(200.0, 160.0)))
        overlay.needsPaint = false

        overlay.optionsMask = 0
        XCTAssertTrue(overlay.needsPaint, "Changing optionsMask to 0 should trigger markNeedsPaint")
        XCTAssertEqual(overlay.optionsMask, 0)
    }
}

// MARK: - RenderPerformanceOverlay Property Tests

final class RenderPerformanceOverlayPropertyTests: XCTestCase {

    /// Test that sizedByParent returns true.
    ///
    /// **Dart Source:** performance_overlay.dart:82
    func testSizedByParentReturnsTrue() {
        let overlay = RenderPerformanceOverlay()
        XCTAssertTrue(overlay.sizedByParent)
    }

    /// Test that alwaysNeedsCompositing returns true.
    ///
    /// **Dart Source:** performance_overlay.dart:85
    func testAlwaysNeedsCompositingReturnsTrue() {
        let overlay = RenderPerformanceOverlay()
        XCTAssertTrue(overlay.alwaysNeedsCompositing)
    }
}

// MARK: - RenderPerformanceOverlay Intrinsic Dimension Tests

final class RenderPerformanceOverlayIntrinsicTests: XCTestCase {

    /// Test that computeMinIntrinsicWidth always returns 0.0.
    ///
    /// **Dart Source:** performance_overlay.dart:88-90
    func testComputeMinIntrinsicWidthReturnsZero() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        XCTAssertEqual(overlay.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(overlay.computeMinIntrinsicWidth(100.0), 0.0)
        XCTAssertEqual(overlay.computeMinIntrinsicWidth(0.0), 0.0)
    }

    /// Test that computeMaxIntrinsicWidth always returns 0.0.
    ///
    /// **Dart Source:** performance_overlay.dart:93-95
    func testComputeMaxIntrinsicWidthReturnsZero() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        XCTAssertEqual(overlay.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(overlay.computeMaxIntrinsicWidth(100.0), 0.0)
    }

    /// Test _intrinsicHeight with optionsMask = 0.
    /// Even with mask 0, the bitwise OR logic in the Dart source means
    /// the result will be 160.0 (both rows are always included due to OR).
    ///
    /// **Dart Source:** performance_overlay.dart:97-109
    func testIntrinsicHeightWithZeroMask() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0)
        // With the bitwise OR (|) implementation from the Dart source,
        // (0 | (1 << 0)) > 0 is always true, so both rows are included.
        // _intrinsicHeight = 80.0 + 80.0 = 160.0
        let height = overlay.computeMinIntrinsicHeight(0.0)
        XCTAssertEqual(height, 160.0)
    }

    /// Test _intrinsicHeight with all options enabled (mask = 0xF).
    /// Both rows should be active, giving 160.0.
    ///
    /// **Dart Source:** performance_overlay.dart:97-109
    func testIntrinsicHeightWithAllOptions() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        let height = overlay.computeMinIntrinsicHeight(0.0)
        XCTAssertEqual(height, 160.0)
    }

    /// Test _intrinsicHeight with only rasterizer stats enabled (mask = 0x1).
    /// Due to bitwise OR, both rows are always included.
    ///
    /// **Dart Source:** performance_overlay.dart:97-109
    func testIntrinsicHeightWithRasterizerStatsOnly() {
        let mask = 1 << PerformanceOverlayOption.displayRasterizerStatistics.rawValue
        let overlay = RenderPerformanceOverlay(optionsMask: mask)
        // With bitwise OR: both conditions are always true
        let height = overlay.computeMinIntrinsicHeight(0.0)
        XCTAssertEqual(height, 160.0)
    }

    /// Test _intrinsicHeight with only engine stats enabled (mask = 0x4).
    /// Due to bitwise OR, both rows are always included.
    ///
    /// **Dart Source:** performance_overlay.dart:97-109
    func testIntrinsicHeightWithEngineStatsOnly() {
        let mask = 1 << PerformanceOverlayOption.displayEngineStatistics.rawValue
        let overlay = RenderPerformanceOverlay(optionsMask: mask)
        // With bitwise OR: both conditions are always true
        let height = overlay.computeMinIntrinsicHeight(0.0)
        XCTAssertEqual(height, 160.0)
    }

    /// Test computeMinIntrinsicHeight returns the same value as computeMaxIntrinsicHeight.
    ///
    /// **Dart Source:** performance_overlay.dart:112-119
    func testMinAndMaxIntrinsicHeightMatch() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        let minHeight = overlay.computeMinIntrinsicHeight(200.0)
        let maxHeight = overlay.computeMaxIntrinsicHeight(200.0)
        XCTAssertEqual(minHeight, maxHeight)
    }

    /// Test computeMinIntrinsicHeight is independent of the width argument.
    func testIntrinsicHeightIndependentOfWidth() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        let h1 = overlay.computeMinIntrinsicHeight(0.0)
        let h2 = overlay.computeMinIntrinsicHeight(100.0)
        let h3 = overlay.computeMinIntrinsicHeight(.infinity)
        XCTAssertEqual(h1, h2)
        XCTAssertEqual(h2, h3)
    }
}

// MARK: - RenderPerformanceOverlay Dry Layout Tests

final class RenderPerformanceOverlayDryLayoutTests: XCTestCase {

    /// Test computeDryLayout constrains the size correctly.
    /// Width should be maxWidth, height should be clamped _intrinsicHeight.
    ///
    /// **Dart Source:** performance_overlay.dart:122-125
    func testComputeDryLayoutConstrainsSize() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 400.0,
            minHeight: 0.0, maxHeight: 300.0
        )
        let size = overlay.computeDryLayout(constraints)
        // Width: constrain(infinity) -> maxWidth = 400.0
        XCTAssertEqual(size.width, 400.0)
        // Height: constrain(160.0) -> clamp(160.0, 0.0, 300.0) = 160.0
        XCTAssertEqual(size.height, 160.0)
    }

    /// Test computeDryLayout with tight constraints.
    ///
    /// **Dart Source:** performance_overlay.dart:122-125
    func testComputeDryLayoutWithTightConstraints() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        let constraints = BoxConstraints.tight(Size(300.0, 200.0))
        let size = overlay.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 300.0)
        XCTAssertEqual(size.height, 200.0)
    }

    /// Test computeDryLayout where intrinsic height exceeds maxHeight.
    /// The height should be clamped to maxHeight.
    func testComputeDryLayoutHeightClampedToMax() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 400.0,
            minHeight: 0.0, maxHeight: 100.0
        )
        let size = overlay.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 400.0)
        // _intrinsicHeight is 160.0, but maxHeight is 100.0
        XCTAssertEqual(size.height, 100.0)
    }

    /// Test computeDryLayout where minHeight exceeds intrinsic height.
    /// The height should be at least minHeight.
    func testComputeDryLayoutHeightFlooredToMin() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 400.0,
            minHeight: 200.0, maxHeight: 400.0
        )
        let size = overlay.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 400.0)
        // _intrinsicHeight is 160.0, but minHeight is 200.0
        XCTAssertEqual(size.height, 200.0)
    }

    /// Test computeDryLayout with zero maxWidth.
    func testComputeDryLayoutZeroWidth() {
        let overlay = RenderPerformanceOverlay(optionsMask: 0xF)
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 0.0,
            minHeight: 0.0, maxHeight: 300.0
        )
        let size = overlay.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 0.0)
        XCTAssertEqual(size.height, 160.0)
    }
}

// MARK: - PerformanceOverlayLayer Tests

final class PerformanceOverlayLayerTests: XCTestCase {

    /// Test that PerformanceOverlayLayer stores overlayRect and optionsMask.
    func testLayerConstruction() {
        let rect = Rect.fromLTWH(10.0, 20.0, 300.0, 160.0)
        let layer = PerformanceOverlayLayer(overlayRect: rect, optionsMask: 0xF)
        XCTAssertEqual(layer.overlayRect, rect)
        XCTAssertEqual(layer.optionsMask, 0xF)
    }

    /// Test that PerformanceOverlayLayer stores zero optionsMask.
    func testLayerWithZeroMask() {
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 80.0)
        let layer = PerformanceOverlayLayer(overlayRect: rect, optionsMask: 0)
        XCTAssertEqual(layer.optionsMask, 0)
    }
}

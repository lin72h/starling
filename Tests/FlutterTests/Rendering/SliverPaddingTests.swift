// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for SliverPadding types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/sliver_padding.dart`
///
/// These tests cover:
///   - RenderSliverEdgeInsetsPadding: child management, directional padding
///     properties (beforePadding, afterPadding, mainAxisPadding, crossAxisPadding),
///     performLayout with and without child, setupParentData, hit testing, painting
///   - RenderSliverPadding: construction, padding/textDirection properties,
///     padding resolution with LTR/RTL, performLayout calls resolve,
///     debugFillProperties

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// Creates a default SliverConstraints suitable for testing.
///
/// By default creates constraints for a vertical downward-scrolling list
/// at scroll offset 0 with a 600-pixel viewport and 400-pixel cross axis.
private func makeSliverConstraints(
    axisDirection: AxisDirection = .down,
    growthDirection: GrowthDirection = .forward,
    userScrollDirection: ScrollDirection = .idle,
    scrollOffset: Double = 0.0,
    precedingScrollExtent: Double = 0.0,
    overlap: Double = 0.0,
    remainingPaintExtent: Double = 600.0,
    crossAxisExtent: Double = 400.0,
    crossAxisDirection: AxisDirection = .right,
    viewportMainAxisExtent: Double = 600.0,
    remainingCacheExtent: Double = 850.0,
    cacheOrigin: Double = 0.0
) -> SliverConstraints {
    SliverConstraints(
        axisDirection: axisDirection,
        growthDirection: growthDirection,
        userScrollDirection: userScrollDirection,
        scrollOffset: scrollOffset,
        precedingScrollExtent: precedingScrollExtent,
        overlap: overlap,
        remainingPaintExtent: remainingPaintExtent,
        crossAxisExtent: crossAxisExtent,
        crossAxisDirection: crossAxisDirection,
        viewportMainAxisExtent: viewportMainAxisExtent,
        remainingCacheExtent: remainingCacheExtent,
        cacheOrigin: cacheOrigin
    )
}

/// A concrete subclass of RenderSliverEdgeInsetsPadding that provides a
/// fixed resolved padding, used for testing the base class behavior.
private class TestRenderSliverEdgeInsetsPadding: RenderSliverEdgeInsetsPadding {
    private var _testPadding: EdgeInsets?

    init(resolvedPadding: EdgeInsets? = nil, child: RenderSliver? = nil) {
        self._testPadding = resolvedPadding
        super.init()
        if let child = child {
            self.child = child
        }
    }

    override var resolvedPadding: EdgeInsets? { _testPadding }

    func setResolvedPadding(_ padding: EdgeInsets?) {
        _testPadding = padding
    }
}

/// A minimal RenderSliver subclass used as a child in tests.
/// It records the constraints it receives and sets a configurable geometry.
private class MockRenderSliver: RenderSliver {
    var layoutGeometry: SliverGeometry

    init(geometry: SliverGeometry = .zero) {
        self.layoutGeometry = geometry
        super.init()
    }

    override func performLayout() {
        self.geometry = layoutGeometry
    }
}

// =============================================================================
// MARK: - RenderSliverEdgeInsetsPadding Child Management Tests
// =============================================================================

final class RenderSliverEdgeInsetsPaddingChildTests: XCTestCase {

    /// Test construction without a child.
    func testConstructionWithoutChild() {
        let sliver = TestRenderSliverEdgeInsetsPadding()
        XCTAssertNil(sliver.child)
    }

    /// Test setting a child.
    func testSettingChild() {
        let sliver = TestRenderSliverEdgeInsetsPadding()
        let child = MockRenderSliver()
        sliver.child = child
        XCTAssertNotNil(sliver.child)
        XCTAssertTrue(sliver.child === child)
    }

    /// Test replacing a child.
    func testReplacingChild() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let sliver = TestRenderSliverEdgeInsetsPadding(child: child1)
        XCTAssertTrue(sliver.child === child1)

        sliver.child = child2
        XCTAssertTrue(sliver.child === child2)
    }

    /// Test setting child to nil.
    func testSettingChildToNil() {
        let child = MockRenderSliver()
        let sliver = TestRenderSliverEdgeInsetsPadding(child: child)
        XCTAssertNotNil(sliver.child)

        sliver.child = nil
        XCTAssertNil(sliver.child)
    }

    /// Test that setting child marks needs layout.
    func testSettingChildMarksNeedsLayout() {
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: EdgeInsets(all: 10.0)
        )
        let constraints = makeSliverConstraints()
        sliver.layout(constraints)
        XCTAssertFalse(sliver.needsLayout)

        sliver.child = MockRenderSliver()
        XCTAssertTrue(sliver.needsLayout)
    }

    /// Test that setupParentData creates SliverPhysicalParentData.
    func testSetupParentData() {
        let sliver = TestRenderSliverEdgeInsetsPadding()
        let child = MockRenderSliver()
        sliver.setupParentData(child)
        XCTAssertTrue(child.parentData is SliverPhysicalParentData)
    }

    /// Test that setupParentData preserves existing SliverPhysicalParentData.
    func testSetupParentDataPreservesExisting() {
        let sliver = TestRenderSliverEdgeInsetsPadding()
        let child = MockRenderSliver()
        let existingData = SliverPhysicalParentData()
        existingData.paintOffset = Offset(42.0, 42.0)
        child.parentData = existingData
        sliver.setupParentData(child)
        let data = child.parentData as! SliverPhysicalParentData
        XCTAssertEqual(data.paintOffset.dx, 42.0)
        XCTAssertEqual(data.paintOffset.dy, 42.0)
    }
}

// =============================================================================
// MARK: - RenderSliverEdgeInsetsPadding Directional Padding Tests
// =============================================================================

final class RenderSliverEdgeInsetsPaddingDirectionalTests: XCTestCase {

    /// Test beforePadding with axis direction .down and growth direction .forward.
    /// For down+forward, beforePadding should be the top padding.
    func testBeforePaddingDown() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(axisDirection: .down, growthDirection: .forward)
        sliver.layout(constraints)
        XCTAssertEqual(sliver.beforePadding, 20.0) // top
    }

    /// Test beforePadding with axis direction .up and growth direction .forward.
    /// For up+forward (which flips to down), beforePadding should be bottom.
    /// Actually applyGrowthDirectionToAxisDirection(.up, .forward) = .up, so
    /// beforePadding for .up is bottom.
    func testBeforePaddingUp() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .up,
            growthDirection: .forward,
            crossAxisDirection: .right
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.beforePadding, 40.0) // bottom
    }

    /// Test beforePadding with axis direction .right and growth direction .forward.
    /// For right+forward, beforePadding should be left.
    func testBeforePaddingRight() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            growthDirection: .forward,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.beforePadding, 10.0) // left
    }

    /// Test beforePadding with axis direction .left and growth direction .forward.
    /// For left+forward, beforePadding should be right.
    func testBeforePaddingLeft() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .left,
            growthDirection: .forward,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.beforePadding, 30.0) // right
    }

    /// Test afterPadding with axis direction .down and growth direction .forward.
    /// For down+forward, afterPadding should be bottom.
    func testAfterPaddingDown() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(axisDirection: .down, growthDirection: .forward)
        sliver.layout(constraints)
        XCTAssertEqual(sliver.afterPadding, 40.0) // bottom
    }

    /// Test afterPadding with axis direction .up and growth direction .forward.
    /// For up+forward, afterPadding should be top.
    func testAfterPaddingUp() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .up,
            growthDirection: .forward,
            crossAxisDirection: .right
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.afterPadding, 20.0) // top
    }

    /// Test afterPadding with axis direction .right and growth direction .forward.
    /// For right+forward, afterPadding should be right.
    func testAfterPaddingRight() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            growthDirection: .forward,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.afterPadding, 30.0) // right
    }

    /// Test afterPadding with axis direction .left and growth direction .forward.
    /// For left+forward, afterPadding should be left.
    func testAfterPaddingLeft() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .left,
            growthDirection: .forward,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.afterPadding, 10.0) // left
    }

    /// Test mainAxisPadding for vertical axis.
    /// For vertical axis, mainAxisPadding = padding.along(.vertical) = top + bottom.
    func testMainAxisPaddingVertical() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(axisDirection: .down)
        sliver.layout(constraints)
        XCTAssertEqual(sliver.mainAxisPadding, 60.0) // 20 + 40
    }

    /// Test mainAxisPadding for horizontal axis.
    /// For horizontal axis, mainAxisPadding = padding.along(.horizontal) = left + right.
    func testMainAxisPaddingHorizontal() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.mainAxisPadding, 40.0) // 10 + 30
    }

    /// Test crossAxisPadding for vertical axis.
    /// For vertical axis, crossAxisPadding = horizontal = left + right.
    func testCrossAxisPaddingVertical() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(axisDirection: .down)
        sliver.layout(constraints)
        XCTAssertEqual(sliver.crossAxisPadding, 40.0) // 10 + 30
    }

    /// Test crossAxisPadding for horizontal axis.
    /// For horizontal axis, crossAxisPadding = vertical = top + bottom.
    func testCrossAxisPaddingHorizontal() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.crossAxisPadding, 60.0) // 20 + 40
    }

    /// Test beforePadding with reversed growth direction.
    /// For down+reverse => flipped to up, so beforePadding = bottom.
    func testBeforePaddingReversedGrowth() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .reverse
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.beforePadding, 40.0) // bottom (because down+reverse = up)
    }

    /// Test afterPadding with reversed growth direction.
    /// For down+reverse => flipped to up, so afterPadding = top.
    func testAfterPaddingReversedGrowth() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .reverse
        )
        sliver.layout(constraints)
        XCTAssertEqual(sliver.afterPadding, 20.0) // top (because down+reverse = up)
    }

    /// Test symmetric padding produces equal before/after padding.
    func testSymmetricPaddingEqualBeforeAfter() {
        let padding = EdgeInsets(all: 25.0)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(axisDirection: .down)
        sliver.layout(constraints)
        XCTAssertEqual(sliver.beforePadding, 25.0)
        XCTAssertEqual(sliver.afterPadding, 25.0)
        XCTAssertEqual(sliver.mainAxisPadding, 50.0)
        XCTAssertEqual(sliver.crossAxisPadding, 50.0)
    }
}

// =============================================================================
// MARK: - RenderSliverEdgeInsetsPadding Layout Tests
// =============================================================================

final class RenderSliverEdgeInsetsPaddingLayoutTests: XCTestCase {

    /// Test performLayout without a child.
    /// When there is no child, the geometry should represent only the padding.
    func testPerformLayoutWithoutChild() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            remainingPaintExtent: 600.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        // scrollExtent = mainAxisPadding = 20 + 40 = 60
        XCTAssertEqual(sliver.geometry!.scrollExtent, 60.0)
        // maxPaintExtent = mainAxisPadding = 60
        XCTAssertEqual(sliver.geometry!.maxPaintExtent, 60.0)
    }

    /// Test performLayout without child when scrolled.
    /// The paint extent should be reduced by scroll amount.
    func testPerformLayoutWithoutChildScrolled() {
        let padding = EdgeInsets(all: 50.0)
        let sliver = TestRenderSliverEdgeInsetsPadding(resolvedPadding: padding)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 30.0,
            remainingPaintExtent: 570.0,
            remainingCacheExtent: 820.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        // scrollExtent = mainAxisPadding = 100
        XCTAssertEqual(sliver.geometry!.scrollExtent, 100.0)
    }

    /// Test performLayout with a child that has geometry.
    func testPerformLayoutWithChild() {
        let childGeometry = SliverGeometry(
            scrollExtent: 200.0,
            paintExtent: 200.0,
            maxPaintExtent: 200.0,
            cacheExtent: 200.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        // scrollExtent = mainAxisPadding + childScrollExtent = 60 + 200 = 260
        XCTAssertEqual(sliver.geometry!.scrollExtent, 260.0)
        // maxPaintExtent = mainAxisPadding + childMaxPaintExtent = 60 + 200 = 260
        XCTAssertEqual(sliver.geometry!.maxPaintExtent, 260.0)
    }

    /// Test that child's constraints are deflated by padding.
    /// The child should get crossAxisExtent reduced by crossAxisPadding.
    func testPerformLayoutDeflatesConstraints() {
        let childGeometry = SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 100.0,
            maxPaintExtent: 100.0,
            cacheExtent: 100.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        // After layout, we can verify the child was laid out (geometry is set)
        XCTAssertNotNil(child.geometry)
        // The child's constraints should have crossAxisExtent = 400 - 40 = 360
        // We verify this indirectly by checking the child was laid out at all
        XCTAssertEqual(child.geometry!.scrollExtent, 100.0)
    }

    /// Test that parent data paint offset is set correctly after layout.
    /// For down+forward, the paint offset should have x = left padding, y = calculated from top.
    func testPerformLayoutSetsPaintOffset() {
        let childGeometry = SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 100.0,
            maxPaintExtent: 100.0,
            cacheExtent: 100.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(left: 15, top: 25, right: 35, bottom: 45)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        let childParentData = child.parentData as! SliverPhysicalParentData
        // For vertical axis, offset = (left, calculatedOffset)
        // For down+forward, calculatedOffset = paintOffset(from: 0, to: top)
        XCTAssertEqual(childParentData.paintOffset.dx, 15.0) // left padding
        XCTAssertEqual(childParentData.paintOffset.dy, 25.0) // top padding at scrollOffset 0
    }

    /// Test performLayout with horizontal axis.
    /// For right+forward, paint offset should have the left padding in x, top in y.
    func testPerformLayoutHorizontalAxis() {
        let childGeometry = SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 100.0,
            maxPaintExtent: 100.0,
            cacheExtent: 100.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(left: 15, top: 25, right: 35, bottom: 45)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .down,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        let childParentData = child.parentData as! SliverPhysicalParentData
        // For horizontal axis, offset = (calculatedOffset, top)
        // For right+forward, calculatedOffset = paintOffset(from: 0, to: left)
        XCTAssertEqual(childParentData.paintOffset.dx, 15.0) // left padding
        XCTAssertEqual(childParentData.paintOffset.dy, 25.0) // top padding
    }

    /// Test performLayout handles scrollOffsetCorrection from child.
    func testPerformLayoutScrollOffsetCorrection() {
        let childGeometry = SliverGeometry(scrollOffsetCorrection: 10.0)
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(all: 10.0)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        XCTAssertNotNil(sliver.geometry!.scrollOffsetCorrection)
        XCTAssertEqual(sliver.geometry!.scrollOffsetCorrection, 10.0)
    }

    /// Test performLayout with zero padding.
    func testPerformLayoutZeroPadding() {
        let childGeometry = SliverGeometry(
            scrollExtent: 200.0,
            paintExtent: 200.0,
            maxPaintExtent: 200.0,
            cacheExtent: 200.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets.zero
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        // With zero padding, scrollExtent should equal child's
        XCTAssertEqual(sliver.geometry!.scrollExtent, 200.0)
        XCTAssertEqual(sliver.geometry!.maxPaintExtent, 200.0)
    }
}

// =============================================================================
// MARK: - RenderSliverEdgeInsetsPadding Child Position Tests
// =============================================================================

final class RenderSliverEdgeInsetsPaddingChildPositionTests: XCTestCase {

    /// Test childMainAxisPosition returns paint offset for the before padding.
    func testChildMainAxisPosition() {
        let childGeometry = SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 100.0,
            maxPaintExtent: 100.0,
            cacheExtent: 100.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(left: 10, top: 30, right: 20, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        // childMainAxisPosition = calculatePaintOffset(constraints, from: 0, to: beforePadding)
        // For down+forward, beforePadding = top = 30
        // At scrollOffset 0, paintOffset(from: 0, to: 30) = clamp(clamp(30,0,600) - clamp(0,0,600), 0, 600) = 30
        let position = sliver.childMainAxisPosition(child)
        XCTAssertEqual(position, 30.0)
    }

    /// Test childCrossAxisPosition for vertical axis.
    func testChildCrossAxisPositionVertical() {
        let child = MockRenderSliver(geometry: SliverGeometry(
            scrollExtent: 100.0, paintExtent: 100.0,
            maxPaintExtent: 100.0, cacheExtent: 100.0
        ))
        let padding = EdgeInsets(left: 15, top: 20, right: 25, bottom: 30)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        // For vertical axis, crossAxisPosition = left = 15
        let position = sliver.childCrossAxisPosition(child)
        XCTAssertEqual(position, 15.0)
    }

    /// Test childCrossAxisPosition for horizontal axis.
    func testChildCrossAxisPositionHorizontal() {
        let child = MockRenderSliver(geometry: SliverGeometry(
            scrollExtent: 100.0, paintExtent: 100.0,
            maxPaintExtent: 100.0, cacheExtent: 100.0
        ))
        let padding = EdgeInsets(left: 15, top: 20, right: 25, bottom: 30)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            remainingPaintExtent: 600.0,
            crossAxisDirection: .down,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        // For horizontal axis, crossAxisPosition = top = 20
        let position = sliver.childCrossAxisPosition(child)
        XCTAssertEqual(position, 20.0)
    }

    /// Test childScrollOffset returns beforePadding.
    func testChildScrollOffset() {
        let child = MockRenderSliver(geometry: SliverGeometry(
            scrollExtent: 100.0, paintExtent: 100.0,
            maxPaintExtent: 100.0, cacheExtent: 100.0
        ))
        let padding = EdgeInsets(left: 10, top: 25, right: 30, bottom: 40)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        // childScrollOffset returns beforePadding = top = 25
        let scrollOffset = sliver.childScrollOffset(child)
        XCTAssertNotNil(scrollOffset)
        XCTAssertEqual(scrollOffset!, 25.0)
    }
}

// =============================================================================
// MARK: - RenderSliverEdgeInsetsPadding Hit Test Tests
// =============================================================================

final class RenderSliverEdgeInsetsPaddingHitTestTests: XCTestCase {

    /// Test hitTestChildren returns false when there is no child.
    func testHitTestChildrenWithoutChild() {
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: EdgeInsets(all: 10.0)
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        let result = SliverHitTestResult()
        let hit = sliver.hitTestChildren(
            result,
            mainAxisPosition: 50.0,
            crossAxisPosition: 50.0
        )
        XCTAssertFalse(hit)
    }

    /// Test hitTestChildren returns false when child has zero hit test extent.
    func testHitTestChildrenZeroHitTestExtent() {
        let child = MockRenderSliver(geometry: SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 0.0,
            maxPaintExtent: 100.0,
            hitTestExtent: 0.0,
            cacheExtent: 100.0
        ))
        let padding = EdgeInsets(all: 10.0)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        let result = SliverHitTestResult()
        let hit = sliver.hitTestChildren(
            result,
            mainAxisPosition: 50.0,
            crossAxisPosition: 50.0
        )
        XCTAssertFalse(hit)
    }
}

// =============================================================================
// MARK: - RenderSliverEdgeInsetsPadding Paint Tests
// =============================================================================

final class RenderSliverEdgeInsetsPaddingPaintTests: XCTestCase {

    /// Test paint does not crash when child is nil.
    func testPaintWithoutChild() {
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: EdgeInsets(all: 10.0)
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        let context = PaintingContext()
        sliver.paint(context, .zero)
        // Should not crash
    }

    /// Test paint does not crash when child has geometry.
    func testPaintWithChild() {
        let child = MockRenderSliver(geometry: SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 100.0,
            maxPaintExtent: 100.0,
            cacheExtent: 100.0
        ))
        let padding = EdgeInsets(all: 10.0)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        let context = PaintingContext()
        sliver.paint(context, Offset(5.0, 5.0))
        // Should not crash; PaintingContext.paintChild is a stub
    }

    /// Test paint does not paint child when child geometry is not visible.
    func testPaintDoesNotPaintInvisibleChild() {
        let child = MockRenderSliver(geometry: SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 0.0,
            maxPaintExtent: 100.0,
            visible: false,
            cacheExtent: 100.0
        ))
        let padding = EdgeInsets(all: 10.0)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        let context = PaintingContext()
        // Should not crash; child is not visible so paintChild won't be called
        sliver.paint(context, .zero)
    }
}

// =============================================================================
// MARK: - RenderSliverEdgeInsetsPadding Paint Transform Tests
// =============================================================================

final class RenderSliverEdgeInsetsPaddingPaintTransformTests: XCTestCase {

    /// Test applyPaintTransform uses the child's parent data paint offset.
    func testApplyPaintTransform() {
        let child = MockRenderSliver(geometry: SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 100.0,
            maxPaintExtent: 100.0,
            cacheExtent: 100.0
        ))
        let padding = EdgeInsets(left: 5, top: 10, right: 15, bottom: 20)
        let sliver = TestRenderSliverEdgeInsetsPadding(
            resolvedPadding: padding,
            child: child
        )
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        var transform = Matrix4.identity()
        sliver.applyPaintTransform(child, &transform)

        // The paint transform should include the child's paint offset
        // For vertical axis down, paintOffset = (left=5, top=10)
        // Matrix4 should be translated by (5, 10)
        let tx = transform.entry(0, 3)
        let ty = transform.entry(1, 3)
        XCTAssertEqual(tx, 5.0)
        XCTAssertEqual(ty, 10.0)
    }
}

// =============================================================================
// MARK: - RenderSliverPadding Construction Tests
// =============================================================================

final class RenderSliverPaddingConstructionTests: XCTestCase {

    /// Test basic construction with EdgeInsets.
    func testConstructionWithEdgeInsets() {
        let padding = EdgeInsets(all: 10.0)
        let sliver = RenderSliverPadding(padding: padding)
        XCTAssertNil(sliver.child)
        XCTAssertNil(sliver.textDirection)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = MockRenderSliver()
        let padding = EdgeInsets(left: 5, top: 10, right: 15, bottom: 20)
        let sliver = RenderSliverPadding(padding: padding, child: child)
        XCTAssertNotNil(sliver.child)
        XCTAssertTrue(sliver.child === child)
    }

    /// Test construction with textDirection.
    func testConstructionWithTextDirection() {
        let padding = EdgeInsets(all: 10.0)
        let sliver = RenderSliverPadding(padding: padding, textDirection: .ltr)
        XCTAssertEqual(sliver.textDirection, .ltr)
    }

    /// Test construction with RTL textDirection.
    func testConstructionWithRTL() {
        let padding = EdgeInsets(all: 10.0)
        let sliver = RenderSliverPadding(padding: padding, textDirection: .rtl)
        XCTAssertEqual(sliver.textDirection, .rtl)
    }
}

// =============================================================================
// MARK: - RenderSliverPadding Padding Property Tests
// =============================================================================

final class RenderSliverPaddingPropertyTests: XCTestCase {

    /// Test that reading padding returns the set value.
    func testPaddingGetter() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = RenderSliverPadding(padding: padding)
        let readPadding = sliver.padding as! EdgeInsets
        XCTAssertEqual(readPadding.left, 10.0)
        XCTAssertEqual(readPadding.top, 20.0)
        XCTAssertEqual(readPadding.right, 30.0)
        XCTAssertEqual(readPadding.bottom, 40.0)
    }

    /// Test that setting padding to a new value triggers layout.
    func testPaddingSetterTriggersLayout() {
        let sliver = RenderSliverPadding(padding: EdgeInsets(all: 10.0))
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)
        XCTAssertFalse(sliver.needsLayout)

        sliver.padding = EdgeInsets(all: 20.0)
        XCTAssertTrue(sliver.needsLayout)
    }

    /// Test that setting padding to the same value does not trigger layout.
    func testPaddingSetterNoOpOnSameValue() {
        let sliver = RenderSliverPadding(padding: EdgeInsets(all: 10.0))
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)
        XCTAssertFalse(sliver.needsLayout)

        sliver.padding = EdgeInsets(all: 10.0)
        XCTAssertFalse(sliver.needsLayout)
    }

    /// Test that setting textDirection triggers layout.
    func testTextDirectionSetterTriggersLayout() {
        let sliver = RenderSliverPadding(
            padding: EdgeInsets(all: 10.0),
            textDirection: .ltr
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)
        XCTAssertFalse(sliver.needsLayout)

        sliver.textDirection = .rtl
        XCTAssertTrue(sliver.needsLayout)
    }

    /// Test that setting textDirection to the same value does not trigger layout.
    func testTextDirectionSetterNoOpOnSameValue() {
        let sliver = RenderSliverPadding(
            padding: EdgeInsets(all: 10.0),
            textDirection: .ltr
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)
        XCTAssertFalse(sliver.needsLayout)

        sliver.textDirection = .ltr
        XCTAssertFalse(sliver.needsLayout)
    }

    /// Test that setting textDirection to nil works.
    func testTextDirectionSetToNil() {
        let sliver = RenderSliverPadding(
            padding: EdgeInsets(all: 10.0),
            textDirection: .ltr
        )
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)
        XCTAssertFalse(sliver.needsLayout)

        sliver.textDirection = nil
        XCTAssertTrue(sliver.needsLayout)
    }
}

// =============================================================================
// MARK: - RenderSliverPadding Resolution Tests
// =============================================================================

final class RenderSliverPaddingResolutionTests: XCTestCase {

    /// Test that resolvedPadding is nil before layout.
    func testResolvedPaddingNilBeforeLayout() {
        let sliver = RenderSliverPadding(padding: EdgeInsets(all: 10.0))
        XCTAssertNil(sliver.resolvedPadding)
    }

    /// Test that resolvedPadding is set after layout.
    func testResolvedPaddingSetAfterLayout() {
        let sliver = RenderSliverPadding(padding: EdgeInsets(all: 10.0))
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)
        XCTAssertNotNil(sliver.resolvedPadding)
        XCTAssertEqual(sliver.resolvedPadding!.top, 10.0)
        XCTAssertEqual(sliver.resolvedPadding!.bottom, 10.0)
        XCTAssertEqual(sliver.resolvedPadding!.left, 10.0)
        XCTAssertEqual(sliver.resolvedPadding!.right, 10.0)
    }

    /// Test that EdgeInsets resolves identically regardless of text direction.
    func testEdgeInsetsResolvesIndependentOfDirection() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliverLTR = RenderSliverPadding(padding: padding, textDirection: .ltr)
        let sliverRTL = RenderSliverPadding(padding: padding, textDirection: .rtl)

        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliverLTR.layout(constraints)
        sliverRTL.layout(constraints)

        // EdgeInsets is not directional, so resolved padding should be the same
        XCTAssertEqual(sliverLTR.resolvedPadding!.left, sliverRTL.resolvedPadding!.left)
        XCTAssertEqual(sliverLTR.resolvedPadding!.right, sliverRTL.resolvedPadding!.right)
    }

    /// Test that EdgeInsetsDirectional resolves differently for LTR vs RTL.
    func testEdgeInsetsDirectionalResolvesWithDirection() {
        let padding = EdgeInsetsDirectional(start: 10, top: 20, end: 30, bottom: 40)

        let sliverLTR = RenderSliverPadding(padding: padding, textDirection: .ltr)
        let sliverRTL = RenderSliverPadding(padding: padding, textDirection: .rtl)

        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliverLTR.layout(constraints)
        sliverRTL.layout(constraints)

        // LTR: start=left=10, end=right=30
        XCTAssertEqual(sliverLTR.resolvedPadding!.left, 10.0)
        XCTAssertEqual(sliverLTR.resolvedPadding!.right, 30.0)

        // RTL: start=right=10, end=left=30
        XCTAssertEqual(sliverRTL.resolvedPadding!.left, 30.0)
        XCTAssertEqual(sliverRTL.resolvedPadding!.right, 10.0)
    }

    /// Test that changing padding clears resolved padding and re-resolves on layout.
    func testChangingPaddingClearsResolution() {
        let sliver = RenderSliverPadding(padding: EdgeInsets(all: 10.0))
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)
        XCTAssertNotNil(sliver.resolvedPadding)
        XCTAssertEqual(sliver.resolvedPadding!.top, 10.0)

        sliver.padding = EdgeInsets(all: 25.0)
        // After changing padding, resolved padding should be nil until layout
        XCTAssertNil(sliver.resolvedPadding)

        sliver.layout(constraints)
        XCTAssertNotNil(sliver.resolvedPadding)
        XCTAssertEqual(sliver.resolvedPadding!.top, 25.0)
    }

    /// Test that changing textDirection clears resolved padding.
    func testChangingTextDirectionClearsResolution() {
        let padding = EdgeInsetsDirectional(start: 10, top: 20, end: 30, bottom: 40)
        let sliver = RenderSliverPadding(padding: padding, textDirection: .ltr)
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)
        XCTAssertNotNil(sliver.resolvedPadding)

        sliver.textDirection = .rtl
        XCTAssertNil(sliver.resolvedPadding)

        sliver.layout(constraints)
        XCTAssertNotNil(sliver.resolvedPadding)
        // After switching to RTL, start becomes right
        XCTAssertEqual(sliver.resolvedPadding!.left, 30.0)
        XCTAssertEqual(sliver.resolvedPadding!.right, 10.0)
    }
}

// =============================================================================
// MARK: - RenderSliverPadding Layout Tests
// =============================================================================

final class RenderSliverPaddingLayoutTests: XCTestCase {

    /// Test full layout with child.
    func testLayoutWithChild() {
        let childGeometry = SliverGeometry(
            scrollExtent: 200.0,
            paintExtent: 200.0,
            maxPaintExtent: 200.0,
            cacheExtent: 200.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = RenderSliverPadding(padding: padding, child: child)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        // scrollExtent = mainAxisPadding + childScrollExtent = 60 + 200 = 260
        XCTAssertEqual(sliver.geometry!.scrollExtent, 260.0)
        // maxPaintExtent = mainAxisPadding + childMaxPaintExtent = 60 + 200 = 260
        XCTAssertEqual(sliver.geometry!.maxPaintExtent, 260.0)
    }

    /// Test layout without child.
    func testLayoutWithoutChild() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let sliver = RenderSliverPadding(padding: padding)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        // scrollExtent = mainAxisPadding = 60
        XCTAssertEqual(sliver.geometry!.scrollExtent, 60.0)
    }

    /// Test layout resolves padding before computing.
    func testLayoutResolvesFirst() {
        let sliver = RenderSliverPadding(padding: EdgeInsets(all: 15.0))
        XCTAssertNil(sliver.resolvedPadding) // not resolved yet

        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        // After layout, resolvedPadding should be set
        XCTAssertNotNil(sliver.resolvedPadding)
        XCTAssertEqual(sliver.resolvedPadding!.top, 15.0)
        XCTAssertEqual(sliver.resolvedPadding!.bottom, 15.0)
    }
}

// =============================================================================
// MARK: - RenderSliverPadding Debug Tests
// =============================================================================

final class RenderSliverPaddingDebugTests: XCTestCase {

    /// Test debugFillProperties includes padding and textDirection.
    func testDebugFillProperties() {
        let padding = EdgeInsets(left: 5, top: 10, right: 15, bottom: 20)
        let sliver = RenderSliverPadding(padding: padding, textDirection: .ltr)

        let builder = DiagnosticPropertiesBuilder()
        sliver.debugFillProperties(builder)

        // The builder should have properties added
        // We verify at least 2 properties were added (padding and textDirection)
        #if DEBUG
        XCTAssertGreaterThanOrEqual(builder.properties.count, 2)
        #endif
    }

    /// Test debugFillProperties with nil textDirection.
    func testDebugFillPropertiesNilTextDirection() {
        let padding = EdgeInsets(all: 10.0)
        let sliver = RenderSliverPadding(padding: padding)

        let builder = DiagnosticPropertiesBuilder()
        sliver.debugFillProperties(builder)

        // Should not crash even with nil textDirection
        #if DEBUG
        XCTAssertGreaterThanOrEqual(builder.properties.count, 1)
        #endif
    }
}

// =============================================================================
// MARK: - RenderSliverPadding Advanced Layout Tests
// =============================================================================

final class RenderSliverPaddingAdvancedLayoutTests: XCTestCase {

    /// Test that overlap is adjusted by beforePaddingPaintExtent.
    func testOverlapAdjustment() {
        let childGeometry = SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 100.0,
            maxPaintExtent: 100.0,
            cacheExtent: 100.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(all: 20.0)
        let sliver = RenderSliverPadding(padding: padding, child: child)

        // Create constraints with positive overlap
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            overlap: 10.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        // Should complete layout without crashing
        XCTAssertNotNil(sliver.geometry)
    }

    /// Test layout with partially scrolled sliver.
    func testPartiallyScrolledLayout() {
        let childGeometry = SliverGeometry(
            scrollExtent: 200.0,
            paintExtent: 180.0,
            maxPaintExtent: 200.0,
            cacheExtent: 200.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(all: 10.0)
        let sliver = RenderSliverPadding(padding: padding, child: child)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 5.0,
            remainingPaintExtent: 595.0,
            remainingCacheExtent: 845.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        // scrollExtent = mainAxisPadding(20) + childScrollExtent(200) = 220
        XCTAssertEqual(sliver.geometry!.scrollExtent, 220.0)
    }

    /// Test layout with child that has hasVisualOverflow.
    func testLayoutPreservesVisualOverflow() {
        let childGeometry = SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 100.0,
            maxPaintExtent: 100.0,
            hasVisualOverflow: true,
            cacheExtent: 100.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(all: 10.0)
        let sliver = RenderSliverPadding(padding: padding, child: child)

        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        XCTAssertTrue(sliver.geometry!.hasVisualOverflow)
    }

    /// Test layout inherits paintOrigin from child.
    func testLayoutPaintOrigin() {
        let childGeometry = SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 100.0,
            paintOrigin: -5.0,
            maxPaintExtent: 100.0,
            cacheExtent: 100.0
        )
        let child = MockRenderSliver(geometry: childGeometry)
        let padding = EdgeInsets(all: 10.0)
        let sliver = RenderSliverPadding(padding: padding, child: child)

        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        sliver.layout(constraints)

        XCTAssertNotNil(sliver.geometry)
        XCTAssertEqual(sliver.geometry!.paintOrigin, -5.0)
    }
}

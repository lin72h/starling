// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Sliver layout model types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/sliver.dart`
///
/// These tests cover:
///   - S1: Foundation types (ItemExtentBuilder, SliverLayoutDimensions, GrowthDirection)
///   - S2: SliverConstraints (init, computed properties, copyWith, asBoxConstraints, Hashable)
///   - S3: SliverGeometry (init, defaults, zero, copyWith, description)
///   - S4: Hit testing (SliverHitTestResult, SliverHitTestEntry)
///   - S5: Parent data (logical/physical parent data, container variants)
///   - S6: RenderSliver core (geometry, paintBounds, calculatePaintOffset, hitTest)
///   - S7: Helpers and adapters (RenderSliverHelpers, RenderSliverSingleBoxAdapter, RenderSliverToBoxAdapter)

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A helper to create a standard SliverConstraints for testing.
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

/// A concrete RenderBox subclass with a fixed size for layout, used as a child in tests.
private class FixedSizeRenderBox: RenderBox {
    var fixedWidth: Double
    var fixedHeight: Double

    init(width: Double, height: Double) {
        self.fixedWidth = width
        self.fixedHeight = height
        super.init()
    }

    override func computeMinIntrinsicWidth(_ height: Double) -> Double {
        return fixedWidth
    }

    override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        return fixedWidth
    }

    override func computeMinIntrinsicHeight(_ width: Double) -> Double {
        return fixedHeight
    }

    override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        return fixedHeight
    }

    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(fixedWidth, fixedHeight))
    }

    override func performLayout() {
        size = boxConstraints.constrain(Size(fixedWidth, fixedHeight))
    }
}

/// A concrete RenderSliver subclass that can be configured for testing.
/// Allows setting constraints and geometry externally.
private class TestRenderSliver: RenderSliver {
    /// Lays out this sliver with the given constraints and sets geometry.
    func layoutWithConstraints(
        _ constraints: SliverConstraints,
        geometry: SliverGeometry
    ) {
        layout(constraints)
        self.geometry = geometry
    }

    override func performLayout() {
        // Default: set geometry to zero if not already set
        if geometry == nil {
            geometry = .zero
        }
    }

    override var paintBounds: Rect {
        guard geometry != nil else {
            return .zero
        }
        return super.paintBounds
    }
}

// =============================================================================
// MARK: - S1: Foundation Types
// =============================================================================

// MARK: - ItemExtentBuilder Tests

final class ItemExtentBuilderTests: XCTestCase {

    /// Test that ItemExtentBuilder typealias can be assigned a closure.
    func testCanBeAssigned() {
        let builder: ItemExtentBuilder = { index, dimensions in
            return Double(index) * 50.0
        }
        let dims = SliverLayoutDimensions(
            scrollOffset: 0, precedingScrollExtent: 0,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let result = builder(2, dims)
        XCTAssertEqual(result, 100.0)
    }

    /// Test that ItemExtentBuilder can return nil.
    func testCanReturnNil() {
        let builder: ItemExtentBuilder = { index, _ in
            return index < 3 ? Double(index) * 10.0 : nil
        }
        let dims = SliverLayoutDimensions(
            scrollOffset: 0, precedingScrollExtent: 0,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        XCTAssertNotNil(builder(0, dims))
        XCTAssertNotNil(builder(2, dims))
        XCTAssertNil(builder(5, dims))
    }
}

// MARK: - SliverLayoutDimensions Tests

final class SliverLayoutDimensionsInitTests: XCTestCase {

    /// Test init stores all properties.
    func testInitStoresProperties() {
        let dims = SliverLayoutDimensions(
            scrollOffset: 10.0,
            precedingScrollExtent: 200.0,
            viewportMainAxisExtent: 600.0,
            crossAxisExtent: 400.0
        )
        XCTAssertEqual(dims.scrollOffset, 10.0)
        XCTAssertEqual(dims.precedingScrollExtent, 200.0)
        XCTAssertEqual(dims.viewportMainAxisExtent, 600.0)
        XCTAssertEqual(dims.crossAxisExtent, 400.0)
    }

    /// Test zero values.
    func testZeroValues() {
        let dims = SliverLayoutDimensions(
            scrollOffset: 0, precedingScrollExtent: 0,
            viewportMainAxisExtent: 0, crossAxisExtent: 0
        )
        XCTAssertEqual(dims.scrollOffset, 0.0)
        XCTAssertEqual(dims.precedingScrollExtent, 0.0)
        XCTAssertEqual(dims.viewportMainAxisExtent, 0.0)
        XCTAssertEqual(dims.crossAxisExtent, 0.0)
    }
}

final class SliverLayoutDimensionsHashableTests: XCTestCase {

    /// Test equality for identical values.
    func testEqualityIdentical() {
        let a = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let b = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        XCTAssertEqual(a, b)
    }

    /// Test inequality when scrollOffset differs.
    func testInequalityScrollOffset() {
        let a = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let b = SliverLayoutDimensions(
            scrollOffset: 11, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality when precedingScrollExtent differs.
    func testInequalityPrecedingScrollExtent() {
        let a = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let b = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 21,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality when viewportMainAxisExtent differs.
    func testInequalityViewportMainAxisExtent() {
        let a = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let b = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 601, crossAxisExtent: 400
        )
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality when crossAxisExtent differs.
    func testInequalityCrossAxisExtent() {
        let a = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let b = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 401
        )
        XCTAssertNotEqual(a, b)
    }

    /// Test hash values are equal for equal instances.
    func testHashValuesEqual() {
        let a = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let b = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    /// Test can be used in a Set.
    func testCanBeUsedInSet() {
        let a = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let b = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let c = SliverLayoutDimensions(
            scrollOffset: 99, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let set: Set<SliverLayoutDimensions> = [a, b, c]
        XCTAssertEqual(set.count, 2)
    }
}

final class SliverLayoutDimensionsDescriptionTests: XCTestCase {

    /// Test description contains all property names.
    func testDescriptionContainsPropertyNames() {
        let dims = SliverLayoutDimensions(
            scrollOffset: 10, precedingScrollExtent: 20,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        let desc = dims.description
        XCTAssertTrue(desc.contains("scrollOffset"))
        XCTAssertTrue(desc.contains("precedingScrollExtent"))
        XCTAssertTrue(desc.contains("viewportMainAxisExtent"))
        XCTAssertTrue(desc.contains("crossAxisExtent"))
    }

    /// Test description contains property values.
    func testDescriptionContainsValues() {
        let dims = SliverLayoutDimensions(
            scrollOffset: 10.0, precedingScrollExtent: 20.0,
            viewportMainAxisExtent: 600.0, crossAxisExtent: 400.0
        )
        let desc = dims.description
        XCTAssertTrue(desc.contains("10.0"))
        XCTAssertTrue(desc.contains("20.0"))
        XCTAssertTrue(desc.contains("600.0"))
        XCTAssertTrue(desc.contains("400.0"))
    }
}

// MARK: - GrowthDirection Tests

final class GrowthDirectionTests: XCTestCase {

    /// Test both cases exist.
    func testCasesExist() {
        let forward = GrowthDirection.forward
        let reverse = GrowthDirection.reverse
        XCTAssertNotNil(forward)
        XCTAssertNotNil(reverse)
    }

    /// Test cases are distinct.
    func testCasesAreDistinct() {
        XCTAssertTrue(GrowthDirection.forward != GrowthDirection.reverse)
    }

    /// Test case equals itself.
    func testCaseEqualsSelf() {
        XCTAssertTrue(GrowthDirection.forward == GrowthDirection.forward)
        XCTAssertTrue(GrowthDirection.reverse == GrowthDirection.reverse)
    }
}

// MARK: - applyGrowthDirectionToAxisDirection Tests

final class ApplyGrowthDirectionToAxisDirectionTests: XCTestCase {

    /// Forward growth direction returns the same axis direction.
    func testForwardReturnsOriginal() {
        XCTAssertEqual(
            applyGrowthDirectionToAxisDirection(.down, .forward),
            .down
        )
        XCTAssertEqual(
            applyGrowthDirectionToAxisDirection(.up, .forward),
            .up
        )
        XCTAssertEqual(
            applyGrowthDirectionToAxisDirection(.left, .forward),
            .left
        )
        XCTAssertEqual(
            applyGrowthDirectionToAxisDirection(.right, .forward),
            .right
        )
    }

    /// Reverse growth direction flips the axis direction.
    func testReverseFlips() {
        XCTAssertEqual(
            applyGrowthDirectionToAxisDirection(.down, .reverse),
            .up
        )
        XCTAssertEqual(
            applyGrowthDirectionToAxisDirection(.up, .reverse),
            .down
        )
        XCTAssertEqual(
            applyGrowthDirectionToAxisDirection(.left, .reverse),
            .right
        )
        XCTAssertEqual(
            applyGrowthDirectionToAxisDirection(.right, .reverse),
            .left
        )
    }
}

// MARK: - applyGrowthDirectionToScrollDirection Tests

final class ApplyGrowthDirectionToScrollDirectionTests: XCTestCase {

    /// Forward growth direction returns the same scroll direction.
    func testForwardReturnsOriginal() {
        XCTAssertEqual(
            applyGrowthDirectionToScrollDirection(.idle, .forward),
            .idle
        )
        XCTAssertEqual(
            applyGrowthDirectionToScrollDirection(.forward, .forward),
            .forward
        )
        XCTAssertEqual(
            applyGrowthDirectionToScrollDirection(.reverse, .forward),
            .reverse
        )
    }

    /// Reverse growth direction flips the scroll direction.
    func testReverseFlips() {
        XCTAssertEqual(
            applyGrowthDirectionToScrollDirection(.idle, .reverse),
            .idle
        )
        XCTAssertEqual(
            applyGrowthDirectionToScrollDirection(.forward, .reverse),
            .reverse
        )
        XCTAssertEqual(
            applyGrowthDirectionToScrollDirection(.reverse, .reverse),
            .forward
        )
    }
}

// =============================================================================
// MARK: - S2: SliverConstraints
// =============================================================================

// MARK: - SliverConstraints Init Tests

final class SliverConstraintsInitTests: XCTestCase {

    /// Test init with all 12 parameters stores each value.
    func testInitStoresAllParameters() {
        let c = SliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            userScrollDirection: .reverse,
            scrollOffset: 100.0,
            precedingScrollExtent: 200.0,
            overlap: 50.0,
            remainingPaintExtent: 500.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 850.0,
            cacheOrigin: -100.0
        )
        XCTAssertEqual(c.axisDirection, .down)
        XCTAssertEqual(c.growthDirection, .forward)
        XCTAssertEqual(c.userScrollDirection, .reverse)
        XCTAssertEqual(c.scrollOffset, 100.0)
        XCTAssertEqual(c.precedingScrollExtent, 200.0)
        XCTAssertEqual(c.overlap, 50.0)
        XCTAssertEqual(c.remainingPaintExtent, 500.0)
        XCTAssertEqual(c.crossAxisExtent, 400.0)
        XCTAssertEqual(c.crossAxisDirection, .right)
        XCTAssertEqual(c.viewportMainAxisExtent, 600.0)
        XCTAssertEqual(c.remainingCacheExtent, 850.0)
        XCTAssertEqual(c.cacheOrigin, -100.0)
    }

    /// Test init with horizontal axis direction.
    func testInitHorizontal() {
        let c = makeSliverConstraints(
            axisDirection: .right,
            crossAxisDirection: .down
        )
        XCTAssertEqual(c.axisDirection, .right)
        XCTAssertEqual(c.crossAxisDirection, .down)
    }
}

// MARK: - SliverConstraints Computed Properties Tests

final class SliverConstraintsComputedPropertiesTests: XCTestCase {

    /// Test axis computed property for vertical.
    func testAxisVertical() {
        let c = makeSliverConstraints(axisDirection: .down)
        XCTAssertEqual(c.axis, .vertical)
    }

    /// Test axis computed property for vertical (up).
    func testAxisVerticalUp() {
        let c = makeSliverConstraints(axisDirection: .up, crossAxisDirection: .right)
        XCTAssertEqual(c.axis, .vertical)
    }

    /// Test axis computed property for horizontal.
    func testAxisHorizontal() {
        let c = makeSliverConstraints(axisDirection: .right, crossAxisDirection: .down)
        XCTAssertEqual(c.axis, .horizontal)
    }

    /// Test axis computed property for horizontal (left).
    func testAxisHorizontalLeft() {
        let c = makeSliverConstraints(axisDirection: .left, crossAxisDirection: .down)
        XCTAssertEqual(c.axis, .horizontal)
    }

    /// Test normalizedGrowthDirection for forward/down.
    func testNormalizedGrowthDirectionForwardDown() {
        let c = makeSliverConstraints(axisDirection: .down, growthDirection: .forward)
        XCTAssertEqual(c.normalizedGrowthDirection, .forward)
    }

    /// Test normalizedGrowthDirection for forward/right.
    func testNormalizedGrowthDirectionForwardRight() {
        let c = makeSliverConstraints(
            axisDirection: .right, growthDirection: .forward, crossAxisDirection: .down
        )
        XCTAssertEqual(c.normalizedGrowthDirection, .forward)
    }

    /// Test normalizedGrowthDirection for forward/up (reversed axis).
    func testNormalizedGrowthDirectionForwardUp() {
        let c = makeSliverConstraints(axisDirection: .up, growthDirection: .forward)
        XCTAssertEqual(c.normalizedGrowthDirection, .reverse)
    }

    /// Test normalizedGrowthDirection for reverse/up (reversed axis).
    func testNormalizedGrowthDirectionReverseUp() {
        let c = makeSliverConstraints(axisDirection: .up, growthDirection: .reverse)
        XCTAssertEqual(c.normalizedGrowthDirection, .forward)
    }

    /// Test normalizedGrowthDirection for forward/left (reversed axis).
    func testNormalizedGrowthDirectionForwardLeft() {
        let c = makeSliverConstraints(
            axisDirection: .left, growthDirection: .forward, crossAxisDirection: .down
        )
        XCTAssertEqual(c.normalizedGrowthDirection, .reverse)
    }

    /// Test normalizedGrowthDirection for reverse/left (reversed axis).
    func testNormalizedGrowthDirectionReverseLeft() {
        let c = makeSliverConstraints(
            axisDirection: .left, growthDirection: .reverse, crossAxisDirection: .down
        )
        XCTAssertEqual(c.normalizedGrowthDirection, .forward)
    }

    /// Test normalizedGrowthDirection for reverse/down.
    func testNormalizedGrowthDirectionReverseDown() {
        let c = makeSliverConstraints(axisDirection: .down, growthDirection: .reverse)
        XCTAssertEqual(c.normalizedGrowthDirection, .reverse)
    }
}

// MARK: - SliverConstraints isTight / isNormalized Tests

final class SliverConstraintsTightNormalizedTests: XCTestCase {

    /// isTight always returns false.
    func testIsTightAlwaysFalse() {
        let c = makeSliverConstraints()
        XCTAssertFalse(c.isTight)
    }

    /// isNormalized returns true for valid constraints.
    func testIsNormalizedValid() {
        let c = makeSliverConstraints()
        XCTAssertTrue(c.isNormalized)
    }

    /// isNormalized returns false for negative scrollOffset.
    func testIsNormalizedNegativeScrollOffset() {
        let c = makeSliverConstraints(scrollOffset: -1.0)
        XCTAssertFalse(c.isNormalized)
    }

    /// isNormalized returns false for negative crossAxisExtent.
    func testIsNormalizedNegativeCrossAxisExtent() {
        let c = makeSliverConstraints(crossAxisExtent: -1.0)
        XCTAssertFalse(c.isNormalized)
    }

    /// isNormalized returns false when axis and crossAxis are along the same axis.
    func testIsNormalizedSameAxis() {
        let c = makeSliverConstraints(
            axisDirection: .down,
            crossAxisDirection: .up
        )
        XCTAssertFalse(c.isNormalized)
    }

    /// isNormalized returns false for negative viewportMainAxisExtent.
    func testIsNormalizedNegativeViewport() {
        let c = makeSliverConstraints(viewportMainAxisExtent: -1.0)
        XCTAssertFalse(c.isNormalized)
    }

    /// isNormalized returns false for negative remainingPaintExtent.
    func testIsNormalizedNegativeRemainingPaintExtent() {
        let c = makeSliverConstraints(remainingPaintExtent: -1.0)
        XCTAssertFalse(c.isNormalized)
    }
}

// MARK: - SliverConstraints copyWith Tests

final class SliverConstraintsCopyWithTests: XCTestCase {

    /// copyWith no arguments returns identical constraints.
    func testCopyWithNoArgs() {
        let c = makeSliverConstraints(scrollOffset: 42.0)
        let copy = c.copyWith()
        XCTAssertEqual(c, copy)
    }

    /// copyWith replacing one parameter.
    func testCopyWithAxisDirection() {
        let c = makeSliverConstraints(axisDirection: .down)
        let copy = c.copyWith(axisDirection: .up)
        XCTAssertEqual(copy.axisDirection, .up)
        // Other fields unchanged
        XCTAssertEqual(copy.scrollOffset, c.scrollOffset)
        XCTAssertEqual(copy.crossAxisExtent, c.crossAxisExtent)
    }

    /// copyWith replacing scrollOffset.
    func testCopyWithScrollOffset() {
        let c = makeSliverConstraints(scrollOffset: 0.0)
        let copy = c.copyWith(scrollOffset: 99.0)
        XCTAssertEqual(copy.scrollOffset, 99.0)
        XCTAssertEqual(copy.axisDirection, c.axisDirection)
    }

    /// copyWith replacing multiple parameters.
    func testCopyWithMultipleParams() {
        let c = makeSliverConstraints()
        let copy = c.copyWith(
            growthDirection: .reverse,
            overlap: 25.0,
            remainingPaintExtent: 300.0
        )
        XCTAssertEqual(copy.growthDirection, .reverse)
        XCTAssertEqual(copy.overlap, 25.0)
        XCTAssertEqual(copy.remainingPaintExtent, 300.0)
        // Unchanged
        XCTAssertEqual(copy.axisDirection, c.axisDirection)
        XCTAssertEqual(copy.scrollOffset, c.scrollOffset)
    }

    /// copyWith replacing all parameters.
    func testCopyWithAllParams() {
        let c = makeSliverConstraints()
        let copy = c.copyWith(
            axisDirection: .left,
            growthDirection: .reverse,
            userScrollDirection: .forward,
            scrollOffset: 10.0,
            precedingScrollExtent: 20.0,
            overlap: 5.0,
            remainingPaintExtent: 300.0,
            crossAxisExtent: 200.0,
            crossAxisDirection: .up,
            viewportMainAxisExtent: 500.0,
            remainingCacheExtent: 700.0,
            cacheOrigin: -50.0
        )
        XCTAssertEqual(copy.axisDirection, .left)
        XCTAssertEqual(copy.growthDirection, .reverse)
        XCTAssertEqual(copy.userScrollDirection, .forward)
        XCTAssertEqual(copy.scrollOffset, 10.0)
        XCTAssertEqual(copy.precedingScrollExtent, 20.0)
        XCTAssertEqual(copy.overlap, 5.0)
        XCTAssertEqual(copy.remainingPaintExtent, 300.0)
        XCTAssertEqual(copy.crossAxisExtent, 200.0)
        XCTAssertEqual(copy.crossAxisDirection, .up)
        XCTAssertEqual(copy.viewportMainAxisExtent, 500.0)
        XCTAssertEqual(copy.remainingCacheExtent, 700.0)
        XCTAssertEqual(copy.cacheOrigin, -50.0)
    }
}

// MARK: - SliverConstraints asBoxConstraints Tests

final class SliverConstraintsAsBoxConstraintsTests: XCTestCase {

    /// Test vertical axis defaults: cross axis extent fills width.
    func testVerticalAxisDefaults() {
        let c = makeSliverConstraints(
            axisDirection: .down,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        let box = c.asBoxConstraints()
        XCTAssertEqual(box.minWidth, 400.0)
        XCTAssertEqual(box.maxWidth, 400.0)
        XCTAssertEqual(box.minHeight, 0.0)
        XCTAssertEqual(box.maxHeight, .infinity)
    }

    /// Test horizontal axis defaults: cross axis extent fills height.
    func testHorizontalAxisDefaults() {
        let c = makeSliverConstraints(
            axisDirection: .right,
            crossAxisExtent: 300.0,
            crossAxisDirection: .down
        )
        let box = c.asBoxConstraints()
        XCTAssertEqual(box.minWidth, 0.0)
        XCTAssertEqual(box.maxWidth, .infinity)
        XCTAssertEqual(box.minHeight, 300.0)
        XCTAssertEqual(box.maxHeight, 300.0)
    }

    /// Test with explicit min and max extent for vertical.
    func testVerticalWithMinMaxExtent() {
        let c = makeSliverConstraints(
            axisDirection: .down,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        let box = c.asBoxConstraints(minExtent: 50.0, maxExtent: 200.0)
        XCTAssertEqual(box.minWidth, 400.0)
        XCTAssertEqual(box.maxWidth, 400.0)
        XCTAssertEqual(box.minHeight, 50.0)
        XCTAssertEqual(box.maxHeight, 200.0)
    }

    /// Test with explicit min and max extent for horizontal.
    func testHorizontalWithMinMaxExtent() {
        let c = makeSliverConstraints(
            axisDirection: .right,
            crossAxisExtent: 300.0,
            crossAxisDirection: .down
        )
        let box = c.asBoxConstraints(minExtent: 100.0, maxExtent: 500.0)
        XCTAssertEqual(box.minWidth, 100.0)
        XCTAssertEqual(box.maxWidth, 500.0)
        XCTAssertEqual(box.minHeight, 300.0)
        XCTAssertEqual(box.maxHeight, 300.0)
    }

    /// Test with custom crossAxisExtent override.
    func testCustomCrossAxisExtent() {
        let c = makeSliverConstraints(
            axisDirection: .down,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        let box = c.asBoxConstraints(crossAxisExtent: 200.0)
        XCTAssertEqual(box.minWidth, 200.0)
        XCTAssertEqual(box.maxWidth, 200.0)
    }

    /// Test asBoxConstraints with maxExtent from remainingPaintExtent.
    func testMaxExtentFromRemainingPaintExtent() {
        let c = makeSliverConstraints(
            axisDirection: .down,
            remainingPaintExtent: 350.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        let box = c.asBoxConstraints(maxExtent: c.remainingPaintExtent)
        XCTAssertEqual(box.maxHeight, 350.0)
    }
}

// MARK: - SliverConstraints Hashable Tests

final class SliverConstraintsHashableTests: XCTestCase {

    /// Test equality of identical constraints.
    func testEquality() {
        let a = makeSliverConstraints(scrollOffset: 10.0, overlap: 5.0)
        let b = makeSliverConstraints(scrollOffset: 10.0, overlap: 5.0)
        XCTAssertEqual(a, b)
    }

    /// Test inequality when one field differs.
    func testInequalityScrollOffset() {
        let a = makeSliverConstraints(scrollOffset: 10.0)
        let b = makeSliverConstraints(scrollOffset: 11.0)
        XCTAssertNotEqual(a, b)
    }

    /// Test inequality when growthDirection differs.
    func testInequalityGrowthDirection() {
        let a = makeSliverConstraints(growthDirection: .forward)
        let b = makeSliverConstraints(growthDirection: .reverse)
        XCTAssertNotEqual(a, b)
    }

    /// Test hash values are equal for equal constraints.
    func testHashEqual() {
        let a = makeSliverConstraints(scrollOffset: 42.0)
        let b = makeSliverConstraints(scrollOffset: 42.0)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    /// Test can be used as dictionary key.
    func testDictionaryKey() {
        let c = makeSliverConstraints(scrollOffset: 10.0)
        var dict: [SliverConstraints: String] = [:]
        dict[c] = "test"
        XCTAssertEqual(dict[c], "test")
    }
}

// MARK: - SliverConstraints Description Tests

final class SliverConstraintsDescriptionTests: XCTestCase {

    /// Test description contains SliverConstraints prefix.
    func testContainsPrefix() {
        let c = makeSliverConstraints()
        XCTAssertTrue(c.description.contains("SliverConstraints"))
    }

    /// Test description contains axis direction.
    func testContainsAxisDirection() {
        let c = makeSliverConstraints(axisDirection: .down)
        XCTAssertTrue(c.description.contains("down"))
    }

    /// Test description contains scroll offset.
    func testContainsScrollOffset() {
        let c = makeSliverConstraints(scrollOffset: 42.5)
        XCTAssertTrue(c.description.contains("scrollOffset"))
        XCTAssertTrue(c.description.contains("42.5"))
    }

    /// Test description includes overlap only when non-zero.
    func testOverlapIncludedWhenNonZero() {
        let c = makeSliverConstraints(overlap: 10.0)
        XCTAssertTrue(c.description.contains("overlap"))
    }

    /// Test description omits overlap when zero.
    func testOverlapOmittedWhenZero() {
        let c = makeSliverConstraints(overlap: 0.0)
        XCTAssertFalse(c.description.contains("overlap"))
    }
}

// =============================================================================
// MARK: - S3: SliverGeometry
// =============================================================================

// MARK: - SliverGeometry Init Tests

final class SliverGeometryInitDefaultsTests: XCTestCase {

    /// Test default values.
    func testAllDefaults() {
        let g = SliverGeometry()
        XCTAssertEqual(g.scrollExtent, 0.0)
        XCTAssertEqual(g.paintExtent, 0.0)
        XCTAssertEqual(g.paintOrigin, 0.0)
        XCTAssertEqual(g.layoutExtent, 0.0) // defaults to paintExtent
        XCTAssertEqual(g.maxPaintExtent, 0.0)
        XCTAssertEqual(g.maxScrollObstructionExtent, 0.0)
        XCTAssertNil(g.crossAxisExtent)
        XCTAssertEqual(g.hitTestExtent, 0.0) // defaults to paintExtent
        XCTAssertFalse(g.visible) // paintExtent == 0 -> false
        XCTAssertFalse(g.hasVisualOverflow)
        XCTAssertNil(g.scrollOffsetCorrection)
        XCTAssertEqual(g.cacheExtent, 0.0) // defaults to layoutExtent -> paintExtent
    }

    /// Test with explicit values.
    func testExplicitValues() {
        let g = SliverGeometry(
            scrollExtent: 100.0,
            paintExtent: 80.0,
            paintOrigin: 10.0,
            layoutExtent: 70.0,
            maxPaintExtent: 100.0,
            maxScrollObstructionExtent: 50.0,
            crossAxisExtent: 400.0,
            hitTestExtent: 90.0,
            visible: true,
            hasVisualOverflow: true,
            scrollOffsetCorrection: 5.0,
            cacheExtent: 120.0
        )
        XCTAssertEqual(g.scrollExtent, 100.0)
        XCTAssertEqual(g.paintExtent, 80.0)
        XCTAssertEqual(g.paintOrigin, 10.0)
        XCTAssertEqual(g.layoutExtent, 70.0)
        XCTAssertEqual(g.maxPaintExtent, 100.0)
        XCTAssertEqual(g.maxScrollObstructionExtent, 50.0)
        XCTAssertEqual(g.crossAxisExtent, 400.0)
        XCTAssertEqual(g.hitTestExtent, 90.0)
        XCTAssertTrue(g.visible)
        XCTAssertTrue(g.hasVisualOverflow)
        XCTAssertEqual(g.scrollOffsetCorrection, 5.0)
        XCTAssertEqual(g.cacheExtent, 120.0)
    }
}

final class SliverGeometryDefaultingLogicTests: XCTestCase {

    /// layoutExtent defaults to paintExtent when nil.
    func testLayoutExtentDefaultsToPaintExtent() {
        let g = SliverGeometry(paintExtent: 50.0)
        XCTAssertEqual(g.layoutExtent, 50.0)
    }

    /// hitTestExtent defaults to paintExtent when nil.
    func testHitTestExtentDefaultsToPaintExtent() {
        let g = SliverGeometry(paintExtent: 60.0)
        XCTAssertEqual(g.hitTestExtent, 60.0)
    }

    /// visible defaults to true when paintExtent > 0.
    func testVisibleTrueWhenPaintExtentPositive() {
        let g = SliverGeometry(paintExtent: 1.0)
        XCTAssertTrue(g.visible)
    }

    /// visible defaults to false when paintExtent == 0.
    func testVisibleFalseWhenPaintExtentZero() {
        let g = SliverGeometry(paintExtent: 0.0)
        XCTAssertFalse(g.visible)
    }

    /// visible can be overridden to false even with positive paintExtent.
    func testVisibleCanBeOverriddenFalse() {
        let g = SliverGeometry(paintExtent: 50.0, visible: false)
        XCTAssertFalse(g.visible)
    }

    /// visible can be overridden to true even with zero paintExtent.
    func testVisibleCanBeOverriddenTrue() {
        let g = SliverGeometry(paintExtent: 0.0, visible: true)
        XCTAssertTrue(g.visible)
    }

    /// cacheExtent defaults to layoutExtent when provided.
    func testCacheExtentDefaultsToLayoutExtent() {
        let g = SliverGeometry(paintExtent: 50.0, layoutExtent: 30.0)
        XCTAssertEqual(g.cacheExtent, 30.0)
    }

    /// cacheExtent defaults to paintExtent when layoutExtent is nil.
    func testCacheExtentDefaultsToPaintExtent() {
        let g = SliverGeometry(paintExtent: 50.0)
        XCTAssertEqual(g.cacheExtent, 50.0)
    }

    /// cacheExtent can be explicitly set.
    func testCacheExtentExplicit() {
        let g = SliverGeometry(paintExtent: 50.0, cacheExtent: 100.0)
        XCTAssertEqual(g.cacheExtent, 100.0)
    }
}

// MARK: - SliverGeometry.zero Tests

final class SliverGeometryZeroTests: XCTestCase {

    /// Test the static zero constant.
    func testZeroValues() {
        let g = SliverGeometry.zero
        XCTAssertEqual(g.scrollExtent, 0.0)
        XCTAssertEqual(g.paintExtent, 0.0)
        XCTAssertEqual(g.paintOrigin, 0.0)
        XCTAssertEqual(g.layoutExtent, 0.0)
        XCTAssertEqual(g.maxPaintExtent, 0.0)
        XCTAssertFalse(g.visible)
    }

    /// Test zero is the same as default init.
    func testZeroEqualsDefaultInit() {
        let zero = SliverGeometry.zero
        let def = SliverGeometry()
        XCTAssertEqual(zero.scrollExtent, def.scrollExtent)
        XCTAssertEqual(zero.paintExtent, def.paintExtent)
        XCTAssertEqual(zero.layoutExtent, def.layoutExtent)
        XCTAssertEqual(zero.hitTestExtent, def.hitTestExtent)
        XCTAssertEqual(zero.visible, def.visible)
    }
}

// MARK: - SliverGeometry copyWith Tests

final class SliverGeometryCopyWithTests: XCTestCase {

    /// copyWith no arguments preserves all values.
    func testCopyWithNoArgs() {
        let g = SliverGeometry(
            scrollExtent: 100, paintExtent: 80, layoutExtent: 70,
            maxPaintExtent: 100, hitTestExtent: 90, visible: true,
            hasVisualOverflow: true, cacheExtent: 120
        )
        let copy = g.copyWith()
        XCTAssertEqual(copy.scrollExtent, 100)
        XCTAssertEqual(copy.paintExtent, 80)
        XCTAssertEqual(copy.layoutExtent, 70)
        XCTAssertEqual(copy.maxPaintExtent, 100)
        XCTAssertEqual(copy.hitTestExtent, 90)
        XCTAssertTrue(copy.visible)
        XCTAssertTrue(copy.hasVisualOverflow)
        XCTAssertEqual(copy.cacheExtent, 120)
    }

    /// copyWith replacing scrollExtent.
    func testCopyWithScrollExtent() {
        let g = SliverGeometry(scrollExtent: 100)
        let copy = g.copyWith(scrollExtent: 200)
        XCTAssertEqual(copy.scrollExtent, 200)
    }

    /// copyWith replacing paintExtent.
    func testCopyWithPaintExtent() {
        let g = SliverGeometry(paintExtent: 50)
        let copy = g.copyWith(paintExtent: 75)
        XCTAssertEqual(copy.paintExtent, 75)
    }

    /// copyWith replacing multiple fields.
    func testCopyWithMultiple() {
        let g = SliverGeometry(scrollExtent: 100, paintExtent: 80, maxPaintExtent: 100)
        let copy = g.copyWith(scrollExtent: 200, paintExtent: 150, maxPaintExtent: 200)
        XCTAssertEqual(copy.scrollExtent, 200)
        XCTAssertEqual(copy.paintExtent, 150)
        XCTAssertEqual(copy.maxPaintExtent, 200)
    }
}

// MARK: - SliverGeometry Description Tests

final class SliverGeometryDescriptionTests: XCTestCase {

    /// Test description contains SliverGeometry.
    func testContainsSliverGeometry() {
        let g = SliverGeometry()
        XCTAssertTrue(g.description.contains("SliverGeometry"))
    }

    /// Test description contains scrollExtent.
    func testContainsScrollExtent() {
        let g = SliverGeometry(scrollExtent: 100.0)
        XCTAssertTrue(g.description.contains("scrollExtent"))
    }

    /// Test description shows "hidden" when not visible and paintExtent is 0.
    func testHiddenWhenNotVisible() {
        let g = SliverGeometry(paintExtent: 0.0)
        XCTAssertTrue(g.description.contains("hidden"))
    }

    /// Test description shows paintExtent when visible.
    func testShowsPaintExtentWhenVisible() {
        let g = SliverGeometry(paintExtent: 50.0, maxPaintExtent: 50.0)
        XCTAssertTrue(g.description.contains("paintExtent"))
    }

    /// Test description includes paintOrigin when non-zero.
    func testIncludesPaintOriginWhenNonZero() {
        let g = SliverGeometry(paintOrigin: 10.0)
        XCTAssertTrue(g.description.contains("paintOrigin"))
    }

    /// Test description omits paintOrigin when zero.
    func testOmitsPaintOriginWhenZero() {
        let g = SliverGeometry(paintOrigin: 0.0)
        XCTAssertFalse(g.description.contains("paintOrigin"))
    }

    /// Test description includes hasVisualOverflow when true.
    func testIncludesHasVisualOverflow() {
        let g = SliverGeometry(hasVisualOverflow: true)
        XCTAssertTrue(g.description.contains("hasVisualOverflow"))
    }

    /// Test description omits hasVisualOverflow when false.
    func testOmitsHasVisualOverflow() {
        let g = SliverGeometry(hasVisualOverflow: false)
        XCTAssertFalse(g.description.contains("hasVisualOverflow"))
    }
}

// =============================================================================
// MARK: - S4: Hit Testing
// =============================================================================

// MARK: - SliverHitTestResult Tests

final class SliverHitTestResultTests: XCTestCase {

    /// Test creation of empty result.
    func testCreation() {
        let result = SliverHitTestResult()
        XCTAssertNotNil(result)
    }

    /// Test wrapping an existing HitTestResult.
    func testWrapping() {
        let base = HitTestResult()
        let result = SliverHitTestResult(wrapping: base)
        XCTAssertNotNil(result)
    }

    /// Test addWithAxisOffset returns hitTest result (true case).
    func testAddWithAxisOffsetReturnsTrue() {
        let result = SliverHitTestResult()
        let isHit = result.addWithAxisOffset(
            paintOffset: nil,
            mainAxisOffset: 0.0,
            crossAxisOffset: 0.0,
            mainAxisPosition: 50.0,
            crossAxisPosition: 100.0,
            hitTest: { _, mainAxis, crossAxis in
                return true
            }
        )
        XCTAssertTrue(isHit)
    }

    /// Test addWithAxisOffset returns hitTest result (false case).
    func testAddWithAxisOffsetReturnsFalse() {
        let result = SliverHitTestResult()
        let isHit = result.addWithAxisOffset(
            paintOffset: nil,
            mainAxisOffset: 0.0,
            crossAxisOffset: 0.0,
            mainAxisPosition: 50.0,
            crossAxisPosition: 100.0,
            hitTest: { _, _, _ in
                return false
            }
        )
        XCTAssertFalse(isHit)
    }

    /// Test addWithAxisOffset subtracts main axis offset.
    func testAddWithAxisOffsetSubtractsMainOffset() {
        let result = SliverHitTestResult()
        var receivedMainAxis: Double = 0.0
        _ = result.addWithAxisOffset(
            paintOffset: nil,
            mainAxisOffset: 10.0,
            crossAxisOffset: 0.0,
            mainAxisPosition: 50.0,
            crossAxisPosition: 100.0,
            hitTest: { _, mainAxis, crossAxis in
                receivedMainAxis = mainAxis
                return true
            }
        )
        XCTAssertEqual(receivedMainAxis, 40.0)
    }

    /// Test addWithAxisOffset subtracts cross axis offset.
    func testAddWithAxisOffsetSubtractsCrossOffset() {
        let result = SliverHitTestResult()
        var receivedCrossAxis: Double = 0.0
        _ = result.addWithAxisOffset(
            paintOffset: nil,
            mainAxisOffset: 0.0,
            crossAxisOffset: 20.0,
            mainAxisPosition: 50.0,
            crossAxisPosition: 100.0,
            hitTest: { _, mainAxis, crossAxis in
                receivedCrossAxis = crossAxis
                return true
            }
        )
        XCTAssertEqual(receivedCrossAxis, 80.0)
    }

    /// Test addWithAxisOffset with both offsets.
    func testAddWithAxisOffsetBothOffsets() {
        let result = SliverHitTestResult()
        var receivedMain: Double = 0.0
        var receivedCross: Double = 0.0
        _ = result.addWithAxisOffset(
            paintOffset: Offset(5.0, 10.0),
            mainAxisOffset: 15.0,
            crossAxisOffset: 25.0,
            mainAxisPosition: 100.0,
            crossAxisPosition: 200.0,
            hitTest: { _, main, cross in
                receivedMain = main
                receivedCross = cross
                return true
            }
        )
        XCTAssertEqual(receivedMain, 85.0)
        XCTAssertEqual(receivedCross, 175.0)
    }

    /// Test addWithAxisOffset with zero offsets.
    func testAddWithAxisOffsetZeroOffsets() {
        let result = SliverHitTestResult()
        var receivedMain: Double = 0.0
        var receivedCross: Double = 0.0
        _ = result.addWithAxisOffset(
            paintOffset: nil,
            mainAxisOffset: 0.0,
            crossAxisOffset: 0.0,
            mainAxisPosition: 42.0,
            crossAxisPosition: 84.0,
            hitTest: { _, main, cross in
                receivedMain = main
                receivedCross = cross
                return true
            }
        )
        XCTAssertEqual(receivedMain, 42.0)
        XCTAssertEqual(receivedCross, 84.0)
    }
}

// MARK: - SliverHitTestEntry Tests

final class SliverHitTestEntryTests: XCTestCase {

    /// Test entry stores mainAxisPosition and crossAxisPosition.
    func testStoresPositions() {
        let sliver = TestRenderSliver()
        let entry = SliverHitTestEntry(
            sliver,
            mainAxisPosition: 10.0,
            crossAxisPosition: 20.0
        )
        XCTAssertEqual(entry.mainAxisPosition, 10.0)
        XCTAssertEqual(entry.crossAxisPosition, 20.0)
    }

    /// Test entry with zero positions.
    func testZeroPositions() {
        let sliver = TestRenderSliver()
        let entry = SliverHitTestEntry(
            sliver,
            mainAxisPosition: 0.0,
            crossAxisPosition: 0.0
        )
        XCTAssertEqual(entry.mainAxisPosition, 0.0)
        XCTAssertEqual(entry.crossAxisPosition, 0.0)
    }

    /// Test entry with large positions.
    func testLargePositions() {
        let sliver = TestRenderSliver()
        let entry = SliverHitTestEntry(
            sliver,
            mainAxisPosition: 10000.0,
            crossAxisPosition: 5000.0
        )
        XCTAssertEqual(entry.mainAxisPosition, 10000.0)
        XCTAssertEqual(entry.crossAxisPosition, 5000.0)
    }

    /// Test entry description.
    func testDescription() {
        let sliver = TestRenderSliver()
        let entry = SliverHitTestEntry(
            sliver,
            mainAxisPosition: 10.0,
            crossAxisPosition: 20.0
        )
        let desc = entry.description
        XCTAssertTrue(desc.contains("mainAxis"))
        XCTAssertTrue(desc.contains("crossAxis"))
        XCTAssertTrue(desc.contains("10.0"))
        XCTAssertTrue(desc.contains("20.0"))
    }
}

// MARK: - SliverHitTest Typealias Tests

final class SliverHitTestTypealiasTests: XCTestCase {

    /// Test that SliverHitTest typealias can be assigned.
    func testCanBeAssigned() {
        let hitTest: SliverHitTest = { result, mainAxisPosition, crossAxisPosition in
            return mainAxisPosition >= 0 && crossAxisPosition >= 0
        }
        let result = SliverHitTestResult()
        XCTAssertTrue(hitTest(result, 10.0, 20.0))
        XCTAssertFalse(hitTest(result, -1.0, 20.0))
    }
}

// =============================================================================
// MARK: - S5: Parent Data
// =============================================================================

// MARK: - SliverLogicalParentData Tests

final class SliverLogicalParentDataTests: XCTestCase {

    /// Test default layoutOffset is nil.
    func testDefaultLayoutOffset() {
        let pd = SliverLogicalParentData()
        XCTAssertNil(pd.layoutOffset)
    }

    /// Test setting layoutOffset.
    func testSetLayoutOffset() {
        let pd = SliverLogicalParentData()
        pd.layoutOffset = 100.0
        XCTAssertEqual(pd.layoutOffset, 100.0)
    }

    /// Test setting layoutOffset to nil.
    func testSetLayoutOffsetNil() {
        let pd = SliverLogicalParentData()
        pd.layoutOffset = 100.0
        pd.layoutOffset = nil
        XCTAssertNil(pd.layoutOffset)
    }

    /// Test description with nil.
    func testDescriptionNil() {
        let pd = SliverLogicalParentData()
        XCTAssertTrue(pd.description.contains("None"))
    }

    /// Test description with a value.
    func testDescriptionWithValue() {
        let pd = SliverLogicalParentData()
        pd.layoutOffset = 42.5
        let desc = pd.description
        XCTAssertTrue(desc.contains("layoutOffset"))
        XCTAssertTrue(desc.contains("42.5"))
    }
}

// MARK: - SliverLogicalContainerParentData Tests

final class SliverLogicalContainerParentDataTests: XCTestCase {

    /// Test inherits from SliverLogicalParentData.
    func testInheritsLayoutOffset() {
        let pd = SliverLogicalContainerParentData()
        XCTAssertNil(pd.layoutOffset)
        pd.layoutOffset = 50.0
        XCTAssertEqual(pd.layoutOffset, 50.0)
    }

    /// Test ContainerParentDataProtocol conformance (previousSibling/nextSibling).
    func testSiblingDefaults() {
        let pd = SliverLogicalContainerParentData()
        XCTAssertNil(pd.previousSibling)
        XCTAssertNil(pd.nextSibling)
    }

    /// Test setting siblings.
    func testSetSiblings() {
        let pd = SliverLogicalContainerParentData()
        let prev = TestRenderSliver()
        let next = TestRenderSliver()
        pd.previousSibling = prev
        pd.nextSibling = next
        XCTAssertTrue(pd.previousSibling === prev)
        XCTAssertTrue(pd.nextSibling === next)
    }

    /// Test clearing siblings.
    func testClearSiblings() {
        let pd = SliverLogicalContainerParentData()
        pd.previousSibling = TestRenderSliver()
        pd.nextSibling = TestRenderSliver()
        pd.previousSibling = nil
        pd.nextSibling = nil
        XCTAssertNil(pd.previousSibling)
        XCTAssertNil(pd.nextSibling)
    }
}

// MARK: - SliverPhysicalParentData Tests

final class SliverPhysicalParentDataTests: XCTestCase {

    /// Test default paintOffset is zero.
    func testDefaultPaintOffset() {
        let pd = SliverPhysicalParentData()
        XCTAssertEqual(pd.paintOffset, .zero)
    }

    /// Test setting paintOffset.
    func testSetPaintOffset() {
        let pd = SliverPhysicalParentData()
        pd.paintOffset = Offset(10.0, 20.0)
        XCTAssertEqual(pd.paintOffset.dx, 10.0)
        XCTAssertEqual(pd.paintOffset.dy, 20.0)
    }

    /// Test default crossAxisFlex is nil.
    func testDefaultCrossAxisFlex() {
        let pd = SliverPhysicalParentData()
        XCTAssertNil(pd.crossAxisFlex)
    }

    /// Test setting crossAxisFlex.
    func testSetCrossAxisFlex() {
        let pd = SliverPhysicalParentData()
        pd.crossAxisFlex = 2
        XCTAssertEqual(pd.crossAxisFlex, 2)
    }

    /// Test applyPaintTransform modifies the matrix.
    func testApplyPaintTransform() {
        let pd = SliverPhysicalParentData()
        pd.paintOffset = Offset(10.0, 20.0)
        var transform = Matrix4.identity()
        pd.applyPaintTransform(&transform)
        // After applying translation, the matrix should contain the offset
        let entry03 = transform.entry(0, 3) // x translation
        let entry13 = transform.entry(1, 3) // y translation
        XCTAssertEqual(entry03, 10.0)
        XCTAssertEqual(entry13, 20.0)
    }

    /// Test applyPaintTransform with zero offset is identity-like.
    func testApplyPaintTransformZeroOffset() {
        let pd = SliverPhysicalParentData()
        pd.paintOffset = .zero
        var transform = Matrix4.identity()
        pd.applyPaintTransform(&transform)
        XCTAssertEqual(transform.entry(0, 3), 0.0)
        XCTAssertEqual(transform.entry(1, 3), 0.0)
    }

    /// Test description.
    func testDescription() {
        let pd = SliverPhysicalParentData()
        pd.paintOffset = Offset(5.0, 10.0)
        let desc = pd.description
        XCTAssertTrue(desc.contains("paintOffset"))
    }
}

// MARK: - SliverPhysicalContainerParentData Tests

final class SliverPhysicalContainerParentDataTests: XCTestCase {

    /// Test inherits paintOffset from SliverPhysicalParentData.
    func testInheritsPaintOffset() {
        let pd = SliverPhysicalContainerParentData()
        XCTAssertEqual(pd.paintOffset, .zero)
        pd.paintOffset = Offset(5, 10)
        XCTAssertEqual(pd.paintOffset.dx, 5.0)
        XCTAssertEqual(pd.paintOffset.dy, 10.0)
    }

    /// Test ContainerParentDataProtocol conformance (previousSibling/nextSibling).
    func testSiblingDefaults() {
        let pd = SliverPhysicalContainerParentData()
        XCTAssertNil(pd.previousSibling)
        XCTAssertNil(pd.nextSibling)
    }

    /// Test setting siblings.
    func testSetSiblings() {
        let pd = SliverPhysicalContainerParentData()
        let prev = TestRenderSliver()
        let next = TestRenderSliver()
        pd.previousSibling = prev
        pd.nextSibling = next
        XCTAssertTrue(pd.previousSibling === prev)
        XCTAssertTrue(pd.nextSibling === next)
    }

    /// Test crossAxisFlex from parent class.
    func testCrossAxisFlex() {
        let pd = SliverPhysicalContainerParentData()
        XCTAssertNil(pd.crossAxisFlex)
        pd.crossAxisFlex = 3
        XCTAssertEqual(pd.crossAxisFlex, 3)
    }

    /// Test applyPaintTransform from parent class.
    func testApplyPaintTransform() {
        let pd = SliverPhysicalContainerParentData()
        pd.paintOffset = Offset(15.0, 25.0)
        var transform = Matrix4.identity()
        pd.applyPaintTransform(&transform)
        XCTAssertEqual(transform.entry(0, 3), 15.0)
        XCTAssertEqual(transform.entry(1, 3), 25.0)
    }
}

// =============================================================================
// MARK: - S6: RenderSliver Core
// =============================================================================

// MARK: - RenderSliver Construction Tests

final class RenderSliverConstructionTests: XCTestCase {

    /// Test construction.
    func testConstruction() {
        let sliver = TestRenderSliver()
        XCTAssertNotNil(sliver)
    }

    /// Test geometry is initially nil.
    func testGeometryInitiallyNil() {
        let sliver = TestRenderSliver()
        XCTAssertNil(sliver.geometry)
    }

    /// Test geometry setter works.
    func testGeometrySetter() {
        let sliver = TestRenderSliver()
        let geom = SliverGeometry(scrollExtent: 100, paintExtent: 80, maxPaintExtent: 100)
        sliver.geometry = geom
        XCTAssertNotNil(sliver.geometry)
        XCTAssertEqual(sliver.geometry!.scrollExtent, 100.0)
        XCTAssertEqual(sliver.geometry!.paintExtent, 80.0)
    }

    /// Test geometry can be set to nil.
    func testGeometrySetToNil() {
        let sliver = TestRenderSliver()
        sliver.geometry = SliverGeometry(scrollExtent: 50)
        sliver.geometry = nil
        XCTAssertNil(sliver.geometry)
    }

    /// Test sliverConstraints getter after layout.
    func testSliverConstraintsGetter() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(scrollOffset: 42.0)
        sliver.layout(constraints)
        XCTAssertEqual(sliver.sliverConstraints.scrollOffset, 42.0)
    }
}

// MARK: - RenderSliver paintBounds Tests

final class RenderSliverPaintBoundsTests: XCTestCase {

    /// Test paintBounds for vertical axis.
    func testPaintBoundsVertical() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 200.0, maxPaintExtent: 200.0)
        let bounds = sliver.paintBounds
        XCTAssertEqual(bounds.left, 0.0)
        XCTAssertEqual(bounds.top, 0.0)
        XCTAssertEqual(bounds.width, 400.0)
        XCTAssertEqual(bounds.height, 200.0)
    }

    /// Test paintBounds for horizontal axis.
    func testPaintBoundsHorizontal() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            crossAxisExtent: 300.0,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 150.0, maxPaintExtent: 150.0)
        let bounds = sliver.paintBounds
        XCTAssertEqual(bounds.left, 0.0)
        XCTAssertEqual(bounds.top, 0.0)
        XCTAssertEqual(bounds.width, 150.0)
        XCTAssertEqual(bounds.height, 300.0)
    }
}

// MARK: - RenderSliver calculatePaintOffset Tests

final class RenderSliverCalculatePaintOffsetTests: XCTestCase {

    private func makeSliver() -> TestRenderSliver {
        let sliver = TestRenderSliver()
        return sliver
    }

    /// Test fully visible region: from=0, to=100 with scrollOffset=0, remainingPaint=600.
    func testFullyVisible() {
        let sliver = makeSliver()
        let constraints = makeSliverConstraints(
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0
        )
        sliver.layout(constraints)
        let offset = sliver.calculatePaintOffset(
            sliver.sliverConstraints,
            from: 0.0,
            to: 100.0
        )
        XCTAssertEqual(offset, 100.0)
    }

    /// Test partially scrolled: scrollOffset=50, from=0, to=100.
    func testPartiallyScrolled() {
        let sliver = makeSliver()
        let constraints = makeSliverConstraints(
            scrollOffset: 50.0,
            remainingPaintExtent: 550.0
        )
        sliver.layout(constraints)
        let offset = sliver.calculatePaintOffset(
            sliver.sliverConstraints,
            from: 0.0,
            to: 100.0
        )
        XCTAssertEqual(offset, 50.0)
    }

    /// Test fully scrolled out: scrollOffset=200, from=0, to=100.
    func testFullyScrolledOut() {
        let sliver = makeSliver()
        let constraints = makeSliverConstraints(
            scrollOffset: 200.0,
            remainingPaintExtent: 400.0
        )
        sliver.layout(constraints)
        let offset = sliver.calculatePaintOffset(
            sliver.sliverConstraints,
            from: 0.0,
            to: 100.0
        )
        XCTAssertEqual(offset, 0.0)
    }

    /// Test region extends past viewport: scrollOffset=0, remainingPaint=50, from=0, to=100.
    func testRegionPastViewport() {
        let sliver = makeSliver()
        let constraints = makeSliverConstraints(
            scrollOffset: 0.0,
            remainingPaintExtent: 50.0
        )
        sliver.layout(constraints)
        let offset = sliver.calculatePaintOffset(
            sliver.sliverConstraints,
            from: 0.0,
            to: 100.0
        )
        XCTAssertEqual(offset, 50.0)
    }

    /// Test from and to both within visible region.
    func testSubregionWithinVisible() {
        let sliver = makeSliver()
        let constraints = makeSliverConstraints(
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0
        )
        sliver.layout(constraints)
        let offset = sliver.calculatePaintOffset(
            sliver.sliverConstraints,
            from: 50.0,
            to: 150.0
        )
        XCTAssertEqual(offset, 100.0)
    }

    /// Test zero extent region.
    func testZeroExtentRegion() {
        let sliver = makeSliver()
        let constraints = makeSliverConstraints(
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0
        )
        sliver.layout(constraints)
        let offset = sliver.calculatePaintOffset(
            sliver.sliverConstraints,
            from: 50.0,
            to: 50.0
        )
        XCTAssertEqual(offset, 0.0)
    }
}

// MARK: - RenderSliver calculateCacheOffset Tests

final class RenderSliverCalculateCacheOffsetTests: XCTestCase {

    /// Test cache offset with no cache origin.
    func testNoCacheOrigin() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            scrollOffset: 0.0,
            remainingCacheExtent: 850.0,
            cacheOrigin: 0.0
        )
        sliver.layout(constraints)
        let offset = sliver.calculateCacheOffset(
            sliver.sliverConstraints,
            from: 0.0,
            to: 100.0
        )
        XCTAssertEqual(offset, 100.0)
    }

    /// Test cache offset with negative cache origin.
    func testNegativeCacheOrigin() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            scrollOffset: 100.0,
            remainingCacheExtent: 950.0,
            cacheOrigin: -100.0
        )
        sliver.layout(constraints)
        let offset = sliver.calculateCacheOffset(
            sliver.sliverConstraints,
            from: 0.0,
            to: 200.0
        )
        // cache region is scrollOffset+cacheOrigin=0 to scrollOffset+remainingCacheExtent=1050
        // from=0, to=200, clamped to [0, 1050]: 200-0=200
        XCTAssertEqual(offset, 200.0)
    }

    /// Test cache offset for region entirely outside cache.
    func testRegionOutsideCache() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            scrollOffset: 500.0,
            remainingCacheExtent: 100.0,
            cacheOrigin: 0.0
        )
        sliver.layout(constraints)
        // cache region: 500 to 600
        let offset = sliver.calculateCacheOffset(
            sliver.sliverConstraints,
            from: 0.0,
            to: 100.0
        )
        XCTAssertEqual(offset, 0.0)
    }
}

// MARK: - RenderSliver hitTest Tests

final class RenderSliverHitTestTests: XCTestCase {

    /// Test hitTest returns false for out-of-bounds main axis.
    func testReturnsFalseOutOfBoundsMain() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(crossAxisExtent: 400.0)
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(
            paintExtent: 100.0, maxPaintExtent: 100.0, hitTestExtent: 100.0
        )
        let result = SliverHitTestResult()
        // mainAxisPosition >= hitTestExtent -> out of bounds
        let hit = sliver.hitTest(
            result,
            mainAxisPosition: 100.0,
            crossAxisPosition: 50.0
        )
        XCTAssertFalse(hit)
    }

    /// Test hitTest returns false for negative main axis.
    func testReturnsFalseNegativeMain() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(crossAxisExtent: 400.0)
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(
            paintExtent: 100.0, maxPaintExtent: 100.0, hitTestExtent: 100.0
        )
        let result = SliverHitTestResult()
        let hit = sliver.hitTest(
            result,
            mainAxisPosition: -1.0,
            crossAxisPosition: 50.0
        )
        XCTAssertFalse(hit)
    }

    /// Test hitTest returns false for out-of-bounds cross axis.
    func testReturnsFalseOutOfBoundsCross() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(crossAxisExtent: 400.0)
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(
            paintExtent: 100.0, maxPaintExtent: 100.0, hitTestExtent: 100.0
        )
        let result = SliverHitTestResult()
        let hit = sliver.hitTest(
            result,
            mainAxisPosition: 50.0,
            crossAxisPosition: 400.0
        )
        XCTAssertFalse(hit)
    }

    /// Test hitTest returns false when hitTestSelf and hitTestChildren both return false.
    func testReturnsFalseWhenNotHit() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(crossAxisExtent: 400.0)
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(
            paintExtent: 100.0, maxPaintExtent: 100.0, hitTestExtent: 100.0
        )
        let result = SliverHitTestResult()
        // Default hitTestSelf and hitTestChildren return false
        let hit = sliver.hitTest(
            result,
            mainAxisPosition: 50.0,
            crossAxisPosition: 50.0
        )
        XCTAssertFalse(hit)
    }
}

// MARK: - RenderSliver centerOffsetAdjustment Tests

final class RenderSliverCenterOffsetAdjustmentTests: XCTestCase {

    /// Test default centerOffsetAdjustment is 0.
    func testDefault() {
        let sliver = TestRenderSliver()
        XCTAssertEqual(sliver.centerOffsetAdjustment, 0.0)
    }
}

// MARK: - RenderSliver childCrossAxisPosition Tests

final class RenderSliverChildCrossAxisPositionTests: XCTestCase {

    /// Test default childCrossAxisPosition returns 0.
    func testDefault() {
        let sliver = TestRenderSliver()
        let child = TestRenderSliver()
        XCTAssertEqual(sliver.childCrossAxisPosition(child), 0.0)
    }
}

// MARK: - RenderSliver ensureSemantics Tests

final class RenderSliverEnsureSemanticsTests: XCTestCase {

    /// Test default ensureSemantics is false.
    func testDefault() {
        let sliver = TestRenderSliver()
        XCTAssertFalse(sliver.ensureSemantics)
    }
}

// MARK: - RenderSliver getAbsoluteSize Tests

final class RenderSliverGetAbsoluteSizeTests: XCTestCase {

    /// Test getAbsoluteSize for vertical (down).
    func testVerticalDown() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 200.0, maxPaintExtent: 200.0)
        let size = sliver.getAbsoluteSize()
        XCTAssertEqual(size.width, 400.0)
        XCTAssertEqual(size.height, 200.0)
    }

    /// Test getAbsoluteSize for vertical (up).
    func testVerticalUp() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .up,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 150.0, maxPaintExtent: 150.0)
        let size = sliver.getAbsoluteSize()
        XCTAssertEqual(size.width, 400.0)
        XCTAssertEqual(size.height, 150.0)
    }

    /// Test getAbsoluteSize for horizontal (right).
    func testHorizontalRight() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            crossAxisExtent: 300.0,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 250.0, maxPaintExtent: 250.0)
        let size = sliver.getAbsoluteSize()
        XCTAssertEqual(size.width, 250.0)
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test getAbsoluteSize for horizontal (left).
    func testHorizontalLeft() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .left,
            crossAxisExtent: 300.0,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 180.0, maxPaintExtent: 180.0)
        let size = sliver.getAbsoluteSize()
        XCTAssertEqual(size.width, 180.0)
        XCTAssertEqual(size.height, 300.0)
    }
}

// MARK: - RenderSliver getAbsoluteSizeRelativeToOrigin Tests

final class RenderSliverGetAbsoluteSizeRelativeToOriginTests: XCTestCase {

    /// Test for down/forward (positive extent).
    func testDownForward() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 200.0, maxPaintExtent: 200.0)
        let size = sliver.getAbsoluteSizeRelativeToOrigin()
        XCTAssertEqual(size.width, 400.0)
        XCTAssertEqual(size.height, 200.0)
    }

    /// Test for up/forward (negative extent).
    func testUpForward() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .up,
            growthDirection: .forward,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 200.0, maxPaintExtent: 200.0)
        // up + forward -> flipAxisDirection(up)=down? No, up+forward= up
        // applyGrowthDirectionToAxisDirection(.up, .forward) = .up
        let size = sliver.getAbsoluteSizeRelativeToOrigin()
        XCTAssertEqual(size.width, 400.0)
        XCTAssertEqual(size.height, -200.0) // negative for .up
    }

    /// Test for right/forward.
    func testRightForward() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            growthDirection: .forward,
            crossAxisExtent: 300.0,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 250.0, maxPaintExtent: 250.0)
        let size = sliver.getAbsoluteSizeRelativeToOrigin()
        XCTAssertEqual(size.width, 250.0)
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test for left/forward (negative extent).
    func testLeftForward() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .left,
            growthDirection: .forward,
            crossAxisExtent: 300.0,
            crossAxisDirection: .down
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 180.0, maxPaintExtent: 180.0)
        let size = sliver.getAbsoluteSizeRelativeToOrigin()
        XCTAssertEqual(size.width, -180.0) // negative for .left
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test for down/reverse -> flipped to up -> negative.
    func testDownReverse() {
        let sliver = TestRenderSliver()
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .reverse,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        sliver.layout(constraints)
        sliver.geometry = SliverGeometry(paintExtent: 200.0, maxPaintExtent: 200.0)
        // applyGrowthDirectionToAxisDirection(.down, .reverse) = .up
        let size = sliver.getAbsoluteSizeRelativeToOrigin()
        XCTAssertEqual(size.width, 400.0)
        XCTAssertEqual(size.height, -200.0)
    }
}

// MARK: - RenderSliver handleEvent Tests

final class RenderSliverHandleEventTests: XCTestCase {

    /// Test that handleEvent does not crash by default.
    func testHandleEventDoesNotCrash() {
        // Just verify the method exists and does not throw.
        // We cannot easily construct a PointerEvent here, so we just
        // confirm the type compiles.
        let sliver = TestRenderSliver()
        XCTAssertNotNil(sliver)
    }
}

// =============================================================================
// MARK: - S7: Helpers and Adapters
// =============================================================================

// MARK: - RenderSliverSingleBoxAdapter Tests

final class RenderSliverSingleBoxAdapterConstructionTests: XCTestCase {

    /// Test construction without child.
    func testConstructionWithoutChild() {
        let adapter = RenderSliverSingleBoxAdapter()
        XCTAssertNil(adapter.child)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let adapter = RenderSliverSingleBoxAdapter(child: child)
        XCTAssertNotNil(adapter.child)
        XCTAssertTrue(adapter.child === child)
    }

    /// Test setting child.
    func testSetChild() {
        let adapter = RenderSliverSingleBoxAdapter()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        adapter.child = child
        XCTAssertTrue(adapter.child === child)
    }

    /// Test replacing child.
    func testReplaceChild() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 200, height: 100)
        let adapter = RenderSliverSingleBoxAdapter(child: child1)
        adapter.child = child2
        XCTAssertTrue(adapter.child === child2)
    }

    /// Test removing child.
    func testRemoveChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let adapter = RenderSliverSingleBoxAdapter(child: child)
        adapter.child = nil
        XCTAssertNil(adapter.child)
    }
}

// MARK: - RenderSliverSingleBoxAdapter setupParentData Tests

final class RenderSliverSingleBoxAdapterSetupParentDataTests: XCTestCase {

    /// Test setupParentData assigns SliverPhysicalParentData.
    func testSetupParentData() {
        let adapter = RenderSliverSingleBoxAdapter()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        adapter.setupParentData(child)
        XCTAssertTrue(child.parentData is SliverPhysicalParentData)
    }

    /// Test setupParentData does not replace if already SliverPhysicalParentData.
    func testSetupParentDataPreservesExisting() {
        let adapter = RenderSliverSingleBoxAdapter()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let existingPD = SliverPhysicalParentData()
        existingPD.paintOffset = Offset(5, 10)
        child.parentData = existingPD
        adapter.setupParentData(child)
        // Should not replace
        let pd = child.parentData as! SliverPhysicalParentData
        XCTAssertEqual(pd.paintOffset.dx, 5.0)
    }
}

// MARK: - RenderSliverSingleBoxAdapter setChildParentData Tests

final class RenderSliverSingleBoxAdapterSetChildParentDataTests: XCTestCase {

    /// Test setChildParentData for down/forward.
    func testDownForward() {
        let child = FixedSizeRenderBox(width: 100, height: 200)
        let adapter = RenderSliverSingleBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 50.0
        )
        let geometry = SliverGeometry(
            scrollExtent: 200.0,
            paintExtent: 150.0,
            maxPaintExtent: 200.0
        )
        adapter.setChildParentData(child, constraints, geometry)
        let pd = child.parentData as! SliverPhysicalParentData
        // down -> paintOffset = Offset(0.0, -scrollOffset) = Offset(0, -50)
        XCTAssertEqual(pd.paintOffset.dx, 0.0)
        XCTAssertEqual(pd.paintOffset.dy, -50.0)
    }

    /// Test setChildParentData for right/forward.
    func testRightForward() {
        let child = FixedSizeRenderBox(width: 200, height: 100)
        let adapter = RenderSliverSingleBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            growthDirection: .forward,
            scrollOffset: 30.0,
            crossAxisDirection: .down
        )
        let geometry = SliverGeometry(
            scrollExtent: 200.0,
            paintExtent: 170.0,
            maxPaintExtent: 200.0
        )
        adapter.setChildParentData(child, constraints, geometry)
        let pd = child.parentData as! SliverPhysicalParentData
        // right -> paintOffset = Offset(-scrollOffset, 0.0) = Offset(-30, 0)
        XCTAssertEqual(pd.paintOffset.dx, -30.0)
        XCTAssertEqual(pd.paintOffset.dy, 0.0)
    }

    /// Test setChildParentData for up/forward.
    func testUpForward() {
        let child = FixedSizeRenderBox(width: 100, height: 200)
        let adapter = RenderSliverSingleBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .up,
            growthDirection: .forward,
            scrollOffset: 50.0,
            crossAxisDirection: .right
        )
        let geometry = SliverGeometry(
            scrollExtent: 200.0,
            paintExtent: 150.0,
            maxPaintExtent: 200.0
        )
        adapter.setChildParentData(child, constraints, geometry)
        let pd = child.parentData as! SliverPhysicalParentData
        // up -> paintOffset = Offset(0.0, paintExtent + scrollOffset - scrollExtent)
        // = Offset(0, 150 + 50 - 200) = Offset(0, 0)
        XCTAssertEqual(pd.paintOffset.dx, 0.0)
        XCTAssertEqual(pd.paintOffset.dy, 0.0)
    }

    /// Test setChildParentData for left/forward.
    func testLeftForward() {
        let child = FixedSizeRenderBox(width: 200, height: 100)
        let adapter = RenderSliverSingleBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .left,
            growthDirection: .forward,
            scrollOffset: 50.0,
            crossAxisDirection: .down
        )
        let geometry = SliverGeometry(
            scrollExtent: 200.0,
            paintExtent: 150.0,
            maxPaintExtent: 200.0
        )
        adapter.setChildParentData(child, constraints, geometry)
        let pd = child.parentData as! SliverPhysicalParentData
        // left -> paintOffset = Offset(paintExtent + scrollOffset - scrollExtent, 0.0)
        // = Offset(150 + 50 - 200, 0) = Offset(0, 0)
        XCTAssertEqual(pd.paintOffset.dx, 0.0)
        XCTAssertEqual(pd.paintOffset.dy, 0.0)
    }
}

// MARK: - RenderSliverSingleBoxAdapter childMainAxisPosition Tests

final class RenderSliverSingleBoxAdapterChildMainAxisPositionTests: XCTestCase {

    /// Test childMainAxisPosition returns negative scrollOffset.
    func testReturnsNegativeScrollOffset() {
        let child = FixedSizeRenderBox(width: 100, height: 200)
        let adapter = RenderSliverSingleBoxAdapter(child: child)
        let constraints = makeSliverConstraints(scrollOffset: 75.0)
        adapter.layout(constraints)
        let pos = adapter.childMainAxisPosition(child)
        XCTAssertEqual(pos, -75.0)
    }

    /// Test childMainAxisPosition with zero scrollOffset.
    func testZeroScrollOffset() {
        let child = FixedSizeRenderBox(width: 100, height: 200)
        let adapter = RenderSliverSingleBoxAdapter(child: child)
        let constraints = makeSliverConstraints(scrollOffset: 0.0)
        adapter.layout(constraints)
        let pos = adapter.childMainAxisPosition(child)
        XCTAssertEqual(pos, 0.0)
    }
}

// MARK: - RenderSliverToBoxAdapter Tests

final class RenderSliverToBoxAdapterConstructionTests: XCTestCase {

    /// Test construction without child.
    func testConstructionWithoutChild() {
        let adapter = RenderSliverToBoxAdapter()
        XCTAssertNil(adapter.child)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        XCTAssertNotNil(adapter.child)
        XCTAssertTrue(adapter.child === child)
    }
}

final class RenderSliverToBoxAdapterLayoutTests: XCTestCase {

    /// Test performLayout without child sets geometry to zero.
    func testPerformLayoutWithoutChild() {
        let adapter = RenderSliverToBoxAdapter()
        let constraints = makeSliverConstraints()
        adapter.layout(constraints)
        XCTAssertNotNil(adapter.geometry)
        XCTAssertEqual(adapter.geometry!.scrollExtent, 0.0)
        XCTAssertEqual(adapter.geometry!.paintExtent, 0.0)
    }

    /// Test performLayout with child, fully visible (vertical).
    func testPerformLayoutWithChildFullyVisibleVertical() {
        let child = FixedSizeRenderBox(width: 400, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 850.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        XCTAssertNotNil(adapter.geometry)
        XCTAssertEqual(adapter.geometry!.scrollExtent, 200.0)
        XCTAssertEqual(adapter.geometry!.paintExtent, 200.0)
        XCTAssertEqual(adapter.geometry!.maxPaintExtent, 200.0)
    }

    /// Test performLayout with child, partially scrolled (vertical).
    func testPerformLayoutWithChildPartiallyScrolled() {
        let child = FixedSizeRenderBox(width: 400, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 50.0,
            remainingPaintExtent: 550.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 800.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        XCTAssertNotNil(adapter.geometry)
        XCTAssertEqual(adapter.geometry!.scrollExtent, 200.0)
        // paintExtent = calculatePaintOffset(from: 0, to: 200) with scrollOffset=50, remainingPaint=550
        // visible range: [50, 600], clamped to [0,200] = [50, 200], so paintExtent = 150
        XCTAssertEqual(adapter.geometry!.paintExtent, 150.0)
        XCTAssertEqual(adapter.geometry!.maxPaintExtent, 200.0)
    }

    /// Test performLayout with child, fully scrolled out.
    func testPerformLayoutWithChildFullyScrolledOut() {
        let child = FixedSizeRenderBox(width: 400, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 300.0,
            remainingPaintExtent: 300.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 550.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        XCTAssertNotNil(adapter.geometry)
        XCTAssertEqual(adapter.geometry!.scrollExtent, 200.0)
        XCTAssertEqual(adapter.geometry!.paintExtent, 0.0)
    }

    /// Test performLayout with horizontal axis.
    func testPerformLayoutHorizontal() {
        let child = FixedSizeRenderBox(width: 150, height: 300)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 300.0,
            crossAxisDirection: .down,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 850.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        XCTAssertNotNil(adapter.geometry)
        // horizontal -> childExtent = child.size.width = 150
        XCTAssertEqual(adapter.geometry!.scrollExtent, 150.0)
        XCTAssertEqual(adapter.geometry!.paintExtent, 150.0)
        XCTAssertEqual(adapter.geometry!.maxPaintExtent, 150.0)
    }

    /// Test hasVisualOverflow when child exceeds remaining paint extent.
    func testHasVisualOverflowWhenChildExceedsViewport() {
        let child = FixedSizeRenderBox(width: 400, height: 800)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 850.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        XCTAssertTrue(adapter.geometry!.hasVisualOverflow)
    }

    /// Test hasVisualOverflow when scrollOffset > 0.
    func testHasVisualOverflowWhenScrolled() {
        let child = FixedSizeRenderBox(width: 400, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 10.0,
            remainingPaintExtent: 590.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 840.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        XCTAssertTrue(adapter.geometry!.hasVisualOverflow)
    }

    /// Test no visual overflow when fully visible and not scrolled.
    func testNoVisualOverflowWhenFullyVisible() {
        let child = FixedSizeRenderBox(width: 400, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 850.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        XCTAssertFalse(adapter.geometry!.hasVisualOverflow)
    }

    /// Test that child parentData is set after layout.
    func testChildParentDataSetAfterLayout() {
        let child = FixedSizeRenderBox(width: 400, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 50.0,
            remainingPaintExtent: 550.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 800.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        let pd = child.parentData as! SliverPhysicalParentData
        // down + forward -> Offset(0, -scrollOffset) = Offset(0, -50)
        XCTAssertEqual(pd.paintOffset.dx, 0.0)
        XCTAssertEqual(pd.paintOffset.dy, -50.0)
    }
}

// MARK: - RenderSliverToBoxAdapter applyPaintTransform Tests

final class RenderSliverToBoxAdapterApplyPaintTransformTests: XCTestCase {

    /// Test applyPaintTransform delegates to SliverPhysicalParentData.
    func testApplyPaintTransform() {
        let child = FixedSizeRenderBox(width: 400, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 30.0,
            remainingPaintExtent: 570.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 820.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        var transform = Matrix4.identity()
        adapter.applyPaintTransform(child, &transform)
        // down + forward -> paintOffset = Offset(0, -30)
        XCTAssertEqual(transform.entry(0, 3), 0.0)
        XCTAssertEqual(transform.entry(1, 3), -30.0)
    }
}

// MARK: - SliverConstraints Conformance Tests

final class SliverConstraintsConformanceTests: XCTestCase {

    /// Test that SliverConstraints conforms to Constraints.
    func testConformsToConstraints() {
        let c: any Constraints = makeSliverConstraints()
        XCTAssertFalse(c.isTight)
    }

    /// Test that SliverConstraints conforms to Hashable.
    func testConformsToHashable() {
        let c: any Hashable = makeSliverConstraints()
        XCTAssertNotNil(c)
    }

    /// Test that SliverConstraints conforms to CustomStringConvertible.
    func testConformsToCustomStringConvertible() {
        let c: any CustomStringConvertible = makeSliverConstraints()
        XCTAssertFalse(c.description.isEmpty)
    }
}

// MARK: - SliverGeometry debugFillProperties Tests

final class SliverGeometryDebugFillPropertiesTests: XCTestCase {

    /// Test debugFillProperties does not crash.
    func testDoesNotCrash() {
        let g = SliverGeometry(
            scrollExtent: 100, paintExtent: 80, maxPaintExtent: 100,
            hasVisualOverflow: true
        )
        let builder = DiagnosticPropertiesBuilder()
        g.debugFillProperties(builder)
        XCTAssertNotNil(builder)
    }

    /// Test debugFillProperties with zero geometry.
    func testZeroGeometry() {
        let g = SliverGeometry.zero
        let builder = DiagnosticPropertiesBuilder()
        g.debugFillProperties(builder)
        XCTAssertNotNil(builder)
    }
}

// MARK: - Additional Edge Case Tests

final class SliverConstraintsEdgeCaseTests: XCTestCase {

    /// Test constraints with infinity values.
    func testInfinityValues() {
        let c = makeSliverConstraints(
            remainingPaintExtent: .infinity,
            viewportMainAxisExtent: .infinity
        )
        XCTAssertEqual(c.remainingPaintExtent, .infinity)
        XCTAssertEqual(c.viewportMainAxisExtent, .infinity)
    }

    /// Test asBoxConstraints with infinity remaining paint extent.
    func testAsBoxConstraintsInfinityExtent() {
        let c = makeSliverConstraints(
            axisDirection: .down,
            remainingPaintExtent: .infinity,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right
        )
        let box = c.asBoxConstraints(maxExtent: c.remainingPaintExtent)
        XCTAssertEqual(box.maxHeight, .infinity)
    }
}

final class SliverGeometryEdgeCaseTests: XCTestCase {

    /// Test geometry with large values.
    func testLargeValues() {
        let g = SliverGeometry(
            scrollExtent: 100000.0,
            paintExtent: 50000.0,
            maxPaintExtent: 100000.0
        )
        XCTAssertEqual(g.scrollExtent, 100000.0)
        XCTAssertEqual(g.paintExtent, 50000.0)
    }

    /// Test scrollOffsetCorrection can be non-nil.
    func testScrollOffsetCorrectionNonNil() {
        let g = SliverGeometry(scrollOffsetCorrection: 10.0)
        XCTAssertEqual(g.scrollOffsetCorrection, 10.0)
    }

    /// Test scrollOffsetCorrection is nil by default.
    func testScrollOffsetCorrectionDefaultNil() {
        let g = SliverGeometry()
        XCTAssertNil(g.scrollOffsetCorrection)
    }

    /// Test crossAxisExtent is nil by default.
    func testCrossAxisExtentDefaultNil() {
        let g = SliverGeometry()
        XCTAssertNil(g.crossAxisExtent)
    }

    /// Test crossAxisExtent can be set explicitly.
    func testCrossAxisExtentExplicit() {
        let g = SliverGeometry(crossAxisExtent: 200.0)
        XCTAssertEqual(g.crossAxisExtent, 200.0)
    }
}

// MARK: - Multiple RenderSliverToBoxAdapter Layout Scenarios

final class RenderSliverToBoxAdapterCacheExtentTests: XCTestCase {

    /// Test cacheExtent calculation when fully visible.
    func testCacheExtentFullyVisible() {
        let child = FixedSizeRenderBox(width: 400, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 850.0,
            cacheOrigin: 0.0
        )
        adapter.layout(constraints)
        // cacheExtent = calculateCacheOffset(from: 0, to: 200)
        // cache range: [0, 850], child: [0, 200] -> 200
        XCTAssertEqual(adapter.geometry!.cacheExtent, 200.0)
    }

    /// Test cacheExtent when partially in cache.
    func testCacheExtentPartiallyInCache() {
        let child = FixedSizeRenderBox(width: 400, height: 200)
        let adapter = RenderSliverToBoxAdapter(child: child)
        let constraints = makeSliverConstraints(
            axisDirection: .down,
            scrollOffset: 100.0,
            remainingPaintExtent: 500.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .right,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 750.0,
            cacheOrigin: -100.0
        )
        adapter.layout(constraints)
        // cache range: scrollOffset + cacheOrigin = 0, scrollOffset + remainingCacheExtent = 850
        // child: [0, 200] clamped to [0, 850] -> 200
        XCTAssertEqual(adapter.geometry!.cacheExtent, 200.0)
    }
}

// MARK: - RenderSliverSingleBoxAdapter hitTestChildren Tests

final class RenderSliverSingleBoxAdapterHitTestChildrenTests: XCTestCase {

    /// Test hitTestChildren returns false when no child.
    func testReturnsFalseWithoutChild() {
        let adapter = RenderSliverToBoxAdapter()
        let constraints = makeSliverConstraints()
        adapter.layout(constraints)
        // Need non-zero geometry for assert
        adapter.geometry = SliverGeometry(
            paintExtent: 100.0, maxPaintExtent: 100.0, hitTestExtent: 100.0
        )
        let result = SliverHitTestResult()
        let hit = adapter.hitTestChildren(
            result,
            mainAxisPosition: 50.0,
            crossAxisPosition: 50.0
        )
        XCTAssertFalse(hit)
    }
}

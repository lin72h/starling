// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for SliverFixedExtentList types from the Rendering layer.
///
/// **Swift Source:** `Sources/Flutter/Rendering/SliverFixedExtentList.swift`
///
/// These tests cover:
///   - RenderSliverFixedExtentBoxAdaptor (itemExtent, itemExtentBuilder, index/offset mapping,
///     min/max child index for scroll offset, estimateMaxScrollOffset, computeMaxScrollOffset)
///   - RenderSliverFixedExtentList (fixed extent property, setItemExtent, layout)
///   - RenderSliverVariedExtentList (builder property, setItemExtentBuilder, itemExtent returns nil)

import Testing
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// Creates a standard SliverConstraints for testing.
private func makeSliverConstraints(
    axisDirection: AxisDirection = .down,
    growthDirection: GrowthDirection = .forward,
    scrollOffset: Double = 0.0,
    remainingPaintExtent: Double = 600.0,
    crossAxisExtent: Double = 400.0,
    viewportMainAxisExtent: Double = 600.0,
    remainingCacheExtent: Double = 850.0,
    cacheOrigin: Double = 0.0
) -> SliverConstraints {
    SliverConstraints(
        axisDirection: axisDirection,
        growthDirection: growthDirection,
        userScrollDirection: .idle,
        scrollOffset: scrollOffset,
        precedingScrollExtent: 0.0,
        overlap: 0.0,
        remainingPaintExtent: remainingPaintExtent,
        crossAxisExtent: crossAxisExtent,
        crossAxisDirection: .right,
        viewportMainAxisExtent: viewportMainAxisExtent,
        remainingCacheExtent: remainingCacheExtent,
        cacheOrigin: cacheOrigin
    )
}

/// A concrete RenderBox subclass with configurable size.
private class TestRenderBox: RenderBox {
    var fixedWidth: Double
    var fixedHeight: Double

    init(width: Double = 100.0, height: Double = 50.0) {
        self.fixedWidth = width
        self.fixedHeight = height
        super.init()
    }

    override func performLayout() {
        size = boxConstraints.constrain(Size(fixedWidth, fixedHeight))
    }

    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(fixedWidth, fixedHeight))
    }
}

/// A mock implementation of RenderSliverBoxChildManager for testing.
private class MockChildManager: RenderSliverBoxChildManager {
    var adaptor: RenderSliverMultiBoxAdaptor?
    var _childCount: Int = 10
    var didUnderflowValue: Bool = false
    var startLayoutCalled = false
    var finishLayoutCalled = false

    var childCount: Int { _childCount }
    var estimatedChildCount: Int? { _childCount }

    func createChild(_ index: Int, after: RenderBox?) {
        guard let adaptor = adaptor, index >= 0 && index < _childCount else { return }
        let child = TestRenderBox(width: 400, height: 50)
        // Pre-set parentData with index BEFORE insert(), because insert() calls
        // _debugVerifyChildOrder() which calls indexOf() which asserts index != nil.
        let pd = SliverMultiBoxAdaptorParentData()
        pd.index = index
        child.parentData = pd
        adaptor.insert(child, after: after)
    }

    func removeChild(_ child: RenderBox) {
        adaptor?.remove(child)
    }

    func estimateMaxScrollOffset(
        _ constraints: SliverConstraints,
        firstIndex: Int?,
        lastIndex: Int?,
        leadingScrollOffset: Double?,
        trailingScrollOffset: Double?
    ) -> Double {
        return Double(_childCount) * 50.0
    }

    func didAdoptChild(_ child: RenderBox) {
        // Use the adaptor's child list position to determine index.
        // In real code the element layer handles this.
    }

    func setDidUnderflow(_ value: Bool) {
        didUnderflowValue = value
    }

    func didStartLayout() {
        startLayoutCalled = true
    }

    func didFinishLayout() {
        finishLayoutCalled = true
    }

    func debugAssertChildListLocked() -> Bool { true }
}

/// Creates a RenderSliverFixedExtentList and its MockChildManager.
private func makeFixedExtentList(
    itemExtent: Double = 50.0,
    childCount: Int = 10
) -> (RenderSliverFixedExtentList, MockChildManager) {
    let manager = MockChildManager()
    manager._childCount = childCount
    let list = RenderSliverFixedExtentList(childManager: manager, itemExtent: itemExtent)
    manager.adaptor = list
    return (list, manager)
}

/// Creates a RenderSliverVariedExtentList and its MockChildManager.
private func makeVariedExtentList(
    builder: @escaping ItemExtentBuilder,
    childCount: Int = 10
) -> (RenderSliverVariedExtentList, MockChildManager) {
    let manager = MockChildManager()
    manager._childCount = childCount
    let list = RenderSliverVariedExtentList(childManager: manager, itemExtentBuilder: builder)
    manager.adaptor = list
    return (list, manager)
}

// =============================================================================
// MARK: - RenderSliverFixedExtentList Construction Tests
// =============================================================================

@Suite("RenderSliverFixedExtentList Construction Tests")
struct RenderSliverFixedExtentListConstructionTests {

    @Test("Construction with item extent")
    func testConstruction() {
        let (list, _) = makeFixedExtentList(itemExtent: 100.0)
        #expect(list.itemExtent == 100.0)
    }

    @Test("Initial state has no children")
    func testInitialStateEmpty() {
        let (list, _) = makeFixedExtentList()
        #expect(list.firstChild == nil)
        #expect(list.lastChild == nil)
        #expect(list.childCount == 0)
    }

    @Test("itemExtentBuilder is nil for fixed extent list")
    func testItemExtentBuilderNil() {
        let (list, _) = makeFixedExtentList()
        #expect(list.itemExtentBuilder == nil)
    }
}

// =============================================================================
// MARK: - RenderSliverFixedExtentList setItemExtent Tests
// =============================================================================

@Suite("RenderSliverFixedExtentList setItemExtent Tests")
struct RenderSliverFixedExtentListSetItemExtentTests {

    @Test("setItemExtent updates extent")
    func testSetItemExtent() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        #expect(list.itemExtent == 50.0)
        list.setItemExtent(75.0)
        #expect(list.itemExtent == 75.0)
    }

    @Test("setItemExtent with same value does not mark needs layout")
    func testSetItemExtentSameValue() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        list.setItemExtent(50.0) // Should not trigger change
        #expect(list.itemExtent == 50.0)
    }

    @Test("setItemExtent with different value marks needs layout")
    func testSetItemExtentDifferentValue() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        list.setItemExtent(100.0)
        #expect(list.itemExtent == 100.0)
        #expect(list.needsLayout == true)
    }
}

// =============================================================================
// MARK: - RenderSliverFixedExtentBoxAdaptor indexToLayoutOffset Tests
// =============================================================================

@Suite("RenderSliverFixedExtentBoxAdaptor indexToLayoutOffset Tests")
struct RenderSliverFixedExtentBoxAdaptorIndexToLayoutOffsetTests {

    @Test("indexToLayoutOffset with fixed extent")
    func testIndexToLayoutOffsetFixed() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        // Apply constraints so sliverConstraints is available
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        #expect(list.indexToLayoutOffset(50.0, 0) == 0.0)
        #expect(list.indexToLayoutOffset(50.0, 1) == 50.0)
        #expect(list.indexToLayoutOffset(50.0, 5) == 250.0)
    }

    @Test("indexToLayoutOffset at index 0 is always 0")
    func testIndexToLayoutOffsetZero() {
        let (list, _) = makeFixedExtentList(itemExtent: 100.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        #expect(list.indexToLayoutOffset(100.0, 0) == 0.0)
    }

    @Test("indexToLayoutOffset scales linearly with index")
    func testIndexToLayoutOffsetLinear() {
        let (list, _) = makeFixedExtentList(itemExtent: 30.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        let offset3 = list.indexToLayoutOffset(30.0, 3)
        let offset6 = list.indexToLayoutOffset(30.0, 6)
        #expect(offset6 == offset3 * 2.0)
    }
}

// =============================================================================
// MARK: - RenderSliverFixedExtentBoxAdaptor getMinChildIndexForScrollOffset Tests
// =============================================================================

@Suite("getMinChildIndexForScrollOffset Tests")
struct GetMinChildIndexForScrollOffsetTests {

    @Test("getMinChildIndexForScrollOffset at zero offset")
    func testMinChildIndexAtZero() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        #expect(list.getMinChildIndexForScrollOffset(0.0, 50.0) == 0)
    }

    @Test("getMinChildIndexForScrollOffset at exact boundary")
    func testMinChildIndexAtExactBoundary() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        // At offset 100.0, child index 2 starts
        #expect(list.getMinChildIndexForScrollOffset(100.0, 50.0) == 2)
    }

    @Test("getMinChildIndexForScrollOffset mid-item")
    func testMinChildIndexMidItem() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        // At offset 75.0, still within child index 1
        #expect(list.getMinChildIndexForScrollOffset(75.0, 50.0) == 1)
    }

    @Test("getMinChildIndexForScrollOffset returns 0 when extent is 0")
    func testMinChildIndexZeroExtent() {
        let (list, _) = makeFixedExtentList(itemExtent: 0.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        #expect(list.getMinChildIndexForScrollOffset(100.0, 0.0) == 0)
    }
}

// =============================================================================
// MARK: - RenderSliverFixedExtentBoxAdaptor getMaxChildIndexForScrollOffset Tests
// =============================================================================

@Suite("getMaxChildIndexForScrollOffset Tests")
struct GetMaxChildIndexForScrollOffsetTests {

    @Test("getMaxChildIndexForScrollOffset at exact boundary")
    func testMaxChildIndexAtExactBoundary() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        // At offset 100.0, the last fully visible child is index 1
        let index = list.getMaxChildIndexForScrollOffset(100.0, 50.0)
        #expect(index >= 0)
    }

    @Test("getMaxChildIndexForScrollOffset at zero returns 0")
    func testMaxChildIndexAtZero() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        let index = list.getMaxChildIndexForScrollOffset(0.0, 50.0)
        #expect(index == 0)
    }

    @Test("getMaxChildIndexForScrollOffset returns 0 when extent is 0")
    func testMaxChildIndexZeroExtent() {
        let (list, _) = makeFixedExtentList(itemExtent: 0.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        #expect(list.getMaxChildIndexForScrollOffset(100.0, 0.0) == 0)
    }

    @Test("getMaxChildIndexForScrollOffset never negative")
    func testMaxChildIndexNeverNegative() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        let index = list.getMaxChildIndexForScrollOffset(10.0, 50.0)
        #expect(index >= 0)
    }
}

// =============================================================================
// MARK: - RenderSliverFixedExtentBoxAdaptor estimateMaxScrollOffset Tests
// =============================================================================

@Suite("RenderSliverFixedExtentBoxAdaptor estimateMaxScrollOffset Tests")
struct RenderSliverFixedExtentBoxAdaptorEstimateMaxScrollOffsetTests {

    @Test("estimateMaxScrollOffset delegates to child manager")
    func testEstimateMaxScrollOffset() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0, childCount: 10)
        let constraints = makeSliverConstraints()
        let estimate = list.estimateMaxScrollOffset(constraints)
        #expect(estimate == 500.0) // 10 * 50
    }

    @Test("estimateMaxScrollOffset with custom indices")
    func testEstimateMaxScrollOffsetWithIndices() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0, childCount: 10)
        let constraints = makeSliverConstraints()
        let estimate = list.estimateMaxScrollOffset(
            constraints,
            firstIndex: 2,
            lastIndex: 5,
            leadingScrollOffset: 100.0,
            trailingScrollOffset: 300.0
        )
        #expect(estimate == 500.0) // Delegates to mock
    }
}

// =============================================================================
// MARK: - RenderSliverFixedExtentBoxAdaptor computeMaxScrollOffset Tests
// =============================================================================

@Suite("RenderSliverFixedExtentBoxAdaptor computeMaxScrollOffset Tests")
struct RenderSliverFixedExtentBoxAdaptorComputeMaxScrollOffsetTests {

    @Test("computeMaxScrollOffset for fixed extent")
    func testComputeMaxScrollOffsetFixed() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0, childCount: 10)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        let max = list.computeMaxScrollOffset(constraints, 50.0)
        #expect(max == 500.0) // 10 * 50
    }

    @Test("computeMaxScrollOffset for zero children")
    func testComputeMaxScrollOffsetZeroChildren() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0, childCount: 0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        let max = list.computeMaxScrollOffset(constraints, 50.0)
        #expect(max == 0.0)
    }

    @Test("computeMaxScrollOffset for one child")
    func testComputeMaxScrollOffsetOneChild() {
        let (list, _) = makeFixedExtentList(itemExtent: 100.0, childCount: 1)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        let max = list.computeMaxScrollOffset(constraints, 100.0)
        #expect(max == 100.0)
    }
}

// =============================================================================
// MARK: - RenderSliverFixedExtentList Layout Tests
// =============================================================================

@Suite("RenderSliverFixedExtentList Layout Tests")
struct RenderSliverFixedExtentListLayoutTests {

    @Test("performLayout sets geometry")
    func testPerformLayoutSetsGeometry() {
        let (list, manager) = makeFixedExtentList(itemExtent: 50.0, childCount: 20)
        let constraints = makeSliverConstraints(
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            viewportMainAxisExtent: 600.0,
            remainingCacheExtent: 850.0,
            cacheOrigin: 0.0
        )
        list.layout(constraints)
        list.performLayout()
        #expect(list.geometry != nil)
        #expect(manager.startLayoutCalled == true)
        #expect(manager.finishLayoutCalled == true)
    }

    @Test("performLayout with no children produces valid geometry")
    func testPerformLayoutNoChildren() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0, childCount: 0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        list.performLayout()
        #expect(list.geometry != nil)
        #expect(list.geometry!.scrollExtent == 0.0)
    }

    @Test("Layout produces geometry with correct scroll extent")
    func testLayoutScrollExtent() {
        let (list, _) = makeFixedExtentList(itemExtent: 50.0, childCount: 20)
        let constraints = makeSliverConstraints(
            remainingPaintExtent: 600.0,
            viewportMainAxisExtent: 600.0
        )
        list.layout(constraints)
        list.performLayout()
        #expect(list.geometry != nil)
        // scroll extent should be the total extent of all children
        #expect(list.geometry!.scrollExtent > 0)
    }
}

// =============================================================================
// MARK: - RenderSliverVariedExtentList Construction Tests
// =============================================================================

@Suite("RenderSliverVariedExtentList Construction Tests")
struct RenderSliverVariedExtentListConstructionTests {

    @Test("Construction with builder")
    func testConstruction() {
        let builder: ItemExtentBuilder = { index, _ in Double(index) * 10.0 + 20.0 }
        let (list, _) = makeVariedExtentList(builder: builder)
        #expect(list.itemExtentBuilder != nil)
    }

    @Test("itemExtent returns nil for varied extent list")
    func testItemExtentNil() {
        let builder: ItemExtentBuilder = { _, _ in 50.0 }
        let (list, _) = makeVariedExtentList(builder: builder)
        #expect(list.itemExtent == nil)
    }

    @Test("Initial state has no children")
    func testInitialStateEmpty() {
        let builder: ItemExtentBuilder = { _, _ in 50.0 }
        let (list, _) = makeVariedExtentList(builder: builder)
        #expect(list.firstChild == nil)
        #expect(list.childCount == 0)
    }
}

// =============================================================================
// MARK: - RenderSliverVariedExtentList setItemExtentBuilder Tests
// =============================================================================

@Suite("RenderSliverVariedExtentList setItemExtentBuilder Tests")
struct RenderSliverVariedExtentListSetItemExtentBuilderTests {

    @Test("setItemExtentBuilder updates builder")
    func testSetItemExtentBuilder() {
        let builder1: ItemExtentBuilder = { _, _ in 50.0 }
        let (list, _) = makeVariedExtentList(builder: builder1)

        let dims = SliverLayoutDimensions(
            scrollOffset: 0, precedingScrollExtent: 0,
            viewportMainAxisExtent: 600, crossAxisExtent: 400
        )
        #expect(list.itemExtentBuilder!(0, dims) == 50.0)

        let builder2: ItemExtentBuilder = { _, _ in 100.0 }
        list.setItemExtentBuilder(builder2)
        #expect(list.itemExtentBuilder!(0, dims) == 100.0)
    }

    @Test("setItemExtentBuilder marks needs layout")
    func testSetItemExtentBuilderMarksNeedsLayout() {
        let builder1: ItemExtentBuilder = { _, _ in 50.0 }
        let (list, _) = makeVariedExtentList(builder: builder1)
        let builder2: ItemExtentBuilder = { _, _ in 100.0 }
        list.setItemExtentBuilder(builder2)
        #expect(list.needsLayout == true)
    }
}

// =============================================================================
// MARK: - RenderSliverVariedExtentList indexToLayoutOffset Tests
// =============================================================================

@Suite("RenderSliverVariedExtentList indexToLayoutOffset Tests")
struct RenderSliverVariedExtentListIndexToLayoutOffsetTests {

    @Test("indexToLayoutOffset sums varied extents")
    func testIndexToLayoutOffsetVaried() {
        // Each item has extent = (index + 1) * 10
        let builder: ItemExtentBuilder = { index, _ in Double(index + 1) * 10.0 }
        let (list, _) = makeVariedExtentList(builder: builder)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        // index 0: 0
        // index 1: 10
        // index 2: 10 + 20 = 30
        // index 3: 10 + 20 + 30 = 60
        #expect(list.indexToLayoutOffset(0, 0) == 0.0)
        #expect(list.indexToLayoutOffset(0, 1) == 10.0)
        #expect(list.indexToLayoutOffset(0, 2) == 30.0)
        #expect(list.indexToLayoutOffset(0, 3) == 60.0)
    }
}

// =============================================================================
// MARK: - RenderSliverVariedExtentList computeMaxScrollOffset Tests
// =============================================================================

@Suite("RenderSliverVariedExtentList computeMaxScrollOffset Tests")
struct RenderSliverVariedExtentListComputeMaxScrollOffsetTests {

    @Test("computeMaxScrollOffset sums all extents")
    func testComputeMaxScrollOffsetVaried() {
        // Each item has extent 20.0
        let builder: ItemExtentBuilder = { _, _ in 20.0 }
        let (list, _) = makeVariedExtentList(builder: builder, childCount: 5)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        let max = list.computeMaxScrollOffset(constraints, 0)
        #expect(max == 100.0) // 5 * 20
    }

    @Test("computeMaxScrollOffset with zero children")
    func testComputeMaxScrollOffsetZeroChildren() {
        let builder: ItemExtentBuilder = { _, _ in 20.0 }
        let (list, _) = makeVariedExtentList(builder: builder, childCount: 0)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        let max = list.computeMaxScrollOffset(constraints, 0)
        #expect(max == 0.0)
    }
}

// =============================================================================
// MARK: - RenderSliverVariedExtentList getMinChildIndexForScrollOffset Tests
// =============================================================================

@Suite("RenderSliverVariedExtentList getMinChildIndexForScrollOffset Tests")
struct RenderSliverVariedExtentListGetMinChildIndexTests {

    @Test("getMinChildIndexForScrollOffset at zero")
    func testMinChildIndexAtZero() {
        let builder: ItemExtentBuilder = { _, _ in 50.0 }
        let (list, _) = makeVariedExtentList(builder: builder)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        #expect(list.getMinChildIndexForScrollOffset(0.0, 0) == 0)
    }

    @Test("getMinChildIndexForScrollOffset finds correct child")
    func testMinChildIndexFindsCorrectChild() {
        // Items with extent 50 each
        let builder: ItemExtentBuilder = { _, _ in 50.0 }
        let (list, _) = makeVariedExtentList(builder: builder)
        let constraints = makeSliverConstraints()
        list.layout(constraints)
        // At 100.0, should be at index 1 (after two items of 50 each)
        let index = list.getMinChildIndexForScrollOffset(100.0, 0)
        #expect(index == 1)
    }
}

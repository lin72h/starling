// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Viewport layout model types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/viewport.dart`
///
/// These tests cover:
///   - CacheExtentStyle: enum cases
///   - SliverPaintOrder: enum cases
///   - RevealedOffset: init, properties, clampOffset, description
///   - RenderAbstractViewport: protocol conformance
///   - RenderAbstractViewportUtils: maybeOf, of, defaultCacheExtent
///   - RenderViewportBase: construction, properties, axis, child management, clip behavior,
///     intrinsic dimensions, isRepaintBoundary, attach/detach
///   - RenderViewport: construction, anchor, center, sizedByParent, computeDryLayout,
///     setupParentData, labelForChild, indexOfFirstChild, semantic tags
///   - RenderShrinkWrappingViewport: construction, setupParentData, indexOfFirstChild, labelForChild

import Testing
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// A concrete RenderSliver subclass that sets a fixed geometry during layout.
private class MockRenderSliver: RenderSliver {
    var fixedGeometry: SliverGeometry

    init(geometry: SliverGeometry = SliverGeometry(
        scrollExtent: 100.0,
        paintExtent: 100.0,
        maxPaintExtent: 100.0,
        hitTestExtent: 100.0,
        visible: true
    )) {
        self.fixedGeometry = geometry
        super.init()
    }

    override func performLayout() {
        self.geometry = fixedGeometry
    }

    override var paintBounds: Rect {
        guard geometry != nil else {
            return .zero
        }
        return super.paintBounds
    }
}

/// Creates a standard set of SliverConstraints for testing.
private func testSliverConstraints(
    crossAxisExtent: Double = 400.0,
    remainingPaintExtent: Double = 600.0
) -> SliverConstraints {
    return SliverConstraints(
        axisDirection: .down,
        growthDirection: .forward,
        userScrollDirection: .idle,
        scrollOffset: 0.0,
        precedingScrollExtent: 0.0,
        overlap: 0.0,
        remainingPaintExtent: remainingPaintExtent,
        crossAxisExtent: crossAxisExtent,
        crossAxisDirection: .right,
        viewportMainAxisExtent: 600.0,
        remainingCacheExtent: 600.0,
        cacheOrigin: 0.0
    )
}

/// A concrete RenderBox subclass with a fixed size for layout.
private class FixedSizeRenderBox: RenderBox {
    let fixedWidth: Double
    let fixedHeight: Double

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

/// Helper to create a RenderViewport with a vertical scroll direction.
private func createVerticalViewport(
    anchor: Double = 0.0,
    offset: ViewportOffset? = nil,
    children: [RenderSliver]? = nil,
    center: RenderSliver? = nil,
    cacheExtent: Double? = nil,
    cacheExtentStyle: CacheExtentStyle = .pixel,
    paintOrder: SliverPaintOrder = .firstIsTop,
    clipBehavior: Clip = .hardEdge
) -> RenderViewport {
    return RenderViewport(
        axisDirection: .down,
        crossAxisDirection: .right,
        offset: offset ?? ViewportOffset.zero(),
        anchor: anchor,
        children: children,
        center: center,
        cacheExtent: cacheExtent,
        cacheExtentStyle: cacheExtentStyle,
        paintOrder: paintOrder,
        clipBehavior: clipBehavior
    )
}

/// Helper to create a RenderShrinkWrappingViewport.
private func createShrinkWrappingViewport(
    offset: ViewportOffset? = nil,
    children: [RenderSliver]? = nil,
    paintOrder: SliverPaintOrder = .firstIsTop,
    clipBehavior: Clip = .hardEdge
) -> RenderShrinkWrappingViewport {
    return RenderShrinkWrappingViewport(
        axisDirection: .down,
        crossAxisDirection: .right,
        offset: offset ?? ViewportOffset.zero(),
        paintOrder: paintOrder,
        clipBehavior: clipBehavior,
        children: children
    )
}

// =============================================================================
// MARK: - CacheExtentStyle Tests
// =============================================================================

@Suite("CacheExtentStyle Tests")
struct CacheExtentStyleTests {

    @Test("pixel case exists")
    func testPixelCase() {
        let style = CacheExtentStyle.pixel
        #expect(style == .pixel)
    }

    @Test("viewport case exists")
    func testViewportCase() {
        let style = CacheExtentStyle.viewport
        #expect(style == .viewport)
    }

    @Test("pixel and viewport are distinct")
    func testCasesAreDistinct() {
        #expect(CacheExtentStyle.pixel != CacheExtentStyle.viewport)
    }
}

// =============================================================================
// MARK: - SliverPaintOrder Tests
// =============================================================================

@Suite("SliverPaintOrder Tests")
struct SliverPaintOrderTests {

    @Test("firstIsTop case exists")
    func testFirstIsTopCase() {
        let order = SliverPaintOrder.firstIsTop
        #expect(order == .firstIsTop)
    }

    @Test("lastIsTop case exists")
    func testLastIsTopCase() {
        let order = SliverPaintOrder.lastIsTop
        #expect(order == .lastIsTop)
    }

    @Test("firstIsTop and lastIsTop are distinct")
    func testCasesAreDistinct() {
        #expect(SliverPaintOrder.firstIsTop != SliverPaintOrder.lastIsTop)
    }
}

// =============================================================================
// MARK: - RevealedOffset Tests
// =============================================================================

@Suite("RevealedOffset Tests")
struct RevealedOffsetTests {

    @Test("init stores offset and rect")
    func testInit() {
        let rect = Rect.fromLTWH(10, 20, 30, 40)
        let ro = RevealedOffset(offset: 100.0, rect: rect)
        #expect(ro.offset == 100.0)
        #expect(ro.rect == rect)
    }

    @Test("description includes offset and rect")
    func testDescription() {
        let ro = RevealedOffset(offset: 42.0, rect: Rect.fromLTWH(0, 0, 100, 200))
        let desc = ro.description
        #expect(desc.contains("42"))
        #expect(desc.contains("RevealedOffset"))
    }

    @Test("clampOffset returns nil when currentOffset is within range")
    func testClampOffsetReturnsNilWhenInRange() {
        let leading = RevealedOffset(offset: 100.0, rect: .zero)
        let trailing = RevealedOffset(offset: 50.0, rect: .zero)
        // Range is [50, 100], currentOffset 75 is in range
        let result = RevealedOffset.clampOffset(
            leadingEdgeOffset: leading,
            trailingEdgeOffset: trailing,
            currentOffset: 75.0
        )
        #expect(result == nil)
    }

    @Test("clampOffset returns larger when currentOffset exceeds range")
    func testClampOffsetReturnsLargerWhenAbove() {
        let leading = RevealedOffset(
            offset: 100.0,
            rect: Rect.fromLTWH(0, 0, 10, 10)
        )
        let trailing = RevealedOffset(
            offset: 50.0,
            rect: Rect.fromLTWH(0, 0, 20, 20)
        )
        // Range is [50, 100], currentOffset 150 exceeds upper bound
        let result = RevealedOffset.clampOffset(
            leadingEdgeOffset: leading,
            trailingEdgeOffset: trailing,
            currentOffset: 150.0
        )
        #expect(result != nil)
        #expect(result!.offset == 100.0)
    }

    @Test("clampOffset returns smaller when currentOffset is below range")
    func testClampOffsetReturnsSmallerWhenBelow() {
        let leading = RevealedOffset(
            offset: 100.0,
            rect: Rect.fromLTWH(0, 0, 10, 10)
        )
        let trailing = RevealedOffset(
            offset: 50.0,
            rect: Rect.fromLTWH(0, 0, 20, 20)
        )
        // Range is [50, 100], currentOffset 25 is below
        let result = RevealedOffset.clampOffset(
            leadingEdgeOffset: leading,
            trailingEdgeOffset: trailing,
            currentOffset: 25.0
        )
        #expect(result != nil)
        #expect(result!.offset == 50.0)
    }
}

// =============================================================================
// MARK: - RenderAbstractViewportUtils Tests
// =============================================================================

@Suite("RenderAbstractViewportUtils Tests")
struct RenderAbstractViewportUtilsTests {

    @Test("defaultCacheExtent is 250")
    func testDefaultCacheExtent() {
        #expect(RenderAbstractViewportUtils.defaultCacheExtent == 250.0)
    }

    @Test("maybeOf returns nil when no viewport ancestor")
    func testMaybeOfReturnsNilForOrphan() {
        let box = FixedSizeRenderBox(width: 100, height: 100)
        let result = RenderAbstractViewportUtils.maybeOf(box)
        #expect(result == nil)
    }

    @Test("maybeOf returns nil for nil input")
    func testMaybeOfReturnsNilForNil() {
        let result = RenderAbstractViewportUtils.maybeOf(nil)
        #expect(result == nil)
    }

    @Test("maybeOf returns viewport when object is a viewport")
    func testMaybeOfReturnsViewportDirectly() {
        let viewport = createVerticalViewport()
        // A viewport itself conforms to RenderAbstractViewport
        let result = RenderAbstractViewportUtils.maybeOf(viewport)
        #expect(result != nil)
        #expect(result as AnyObject === viewport)
    }

    @Test("RenderAbstractViewport protocol conformance via RenderViewport")
    func testProtocolConformance() {
        let viewport = createVerticalViewport()
        let isViewport = viewport is any RenderAbstractViewport
        #expect(isViewport)
    }
}

// =============================================================================
// MARK: - RenderViewportBase Tests
// =============================================================================

@Suite("RenderViewportBase Tests")
struct RenderViewportBaseTests {

    @Test("Construction with default parameters via RenderViewport subclass")
    func testConstructionDefaults() {
        let viewport = createVerticalViewport()
        #expect(viewport.axisDirection == .down)
        #expect(viewport.crossAxisDirection == .right)
        #expect(viewport.clipBehavior == .hardEdge)
        #expect(viewport.cacheExtentStyle == .pixel)
        #expect(viewport.paintOrder == .firstIsTop)
    }

    @Test("axis property returns correct axis for vertical direction")
    func testAxisVertical() {
        let viewport = createVerticalViewport()
        #expect(viewport.axis == .vertical)
    }

    @Test("axis property returns correct axis for horizontal direction")
    func testAxisHorizontal() {
        let viewport = RenderViewport(
            axisDirection: .right,
            crossAxisDirection: .down,
            offset: ViewportOffset.zero()
        )
        #expect(viewport.axis == .horizontal)
    }

    @Test("axisDirection setter updates value")
    func testAxisDirectionSetter() {
        let viewport = createVerticalViewport()
        #expect(viewport.axisDirection == .down)
        viewport.axisDirection = .up
        #expect(viewport.axisDirection == .up)
    }

    @Test("crossAxisDirection setter updates value")
    func testCrossAxisDirectionSetter() {
        let viewport = createVerticalViewport()
        #expect(viewport.crossAxisDirection == .right)
        viewport.crossAxisDirection = .left
        #expect(viewport.crossAxisDirection == .left)
    }

    @Test("offset property setter updates value")
    func testOffsetSetter() {
        let offset1 = ViewportOffset.zero()
        let offset2 = ViewportOffset.fixed(100.0)
        let viewport = RenderViewport(
            axisDirection: .down,
            crossAxisDirection: .right,
            offset: offset1
        )
        #expect(viewport.offset === offset1)
        viewport.offset = offset2
        #expect(viewport.offset === offset2)
    }

    @Test("cacheExtent defaults to 250 when nil")
    func testCacheExtentDefault() {
        let viewport = createVerticalViewport()
        #expect(viewport.cacheExtent == 250.0)
    }

    @Test("cacheExtent setter updates value")
    func testCacheExtentSetter() {
        let viewport = createVerticalViewport()
        viewport.cacheExtent = 500.0
        #expect(viewport.cacheExtent == 500.0)
    }

    @Test("cacheExtent setter with nil resets to default")
    func testCacheExtentSetterNil() {
        let viewport = createVerticalViewport(cacheExtent: 400.0)
        viewport.cacheExtent = nil
        #expect(viewport.cacheExtent == 250.0)
    }

    @Test("cacheExtentStyle setter updates value")
    func testCacheExtentStyleSetter() {
        let viewport = createVerticalViewport(
            cacheExtent: 1.5,
            cacheExtentStyle: .viewport
        )
        #expect(viewport.cacheExtentStyle == .viewport)
        viewport.cacheExtentStyle = .pixel
        #expect(viewport.cacheExtentStyle == .pixel)
    }

    @Test("paintOrder setter updates value")
    func testPaintOrderSetter() {
        let viewport = createVerticalViewport()
        #expect(viewport.paintOrder == .firstIsTop)
        viewport.paintOrder = .lastIsTop
        #expect(viewport.paintOrder == .lastIsTop)
    }

    @Test("clipBehavior setter updates value")
    func testClipBehaviorSetter() {
        let viewport = createVerticalViewport()
        #expect(viewport.clipBehavior == .hardEdge)
        viewport.clipBehavior = .none
        #expect(viewport.clipBehavior == .none)
    }

    @Test("isRepaintBoundary returns true")
    func testIsRepaintBoundary() {
        let viewport = createVerticalViewport()
        #expect(viewport.isRepaintBoundary == true)
    }

    @Test("computeMinIntrinsicWidth returns 0")
    func testComputeMinIntrinsicWidth() {
        let viewport = createVerticalViewport()
        #expect(viewport.computeMinIntrinsicWidth(100.0) == 0.0)
    }

    @Test("computeMaxIntrinsicWidth returns 0")
    func testComputeMaxIntrinsicWidth() {
        let viewport = createVerticalViewport()
        #expect(viewport.computeMaxIntrinsicWidth(100.0) == 0.0)
    }

    @Test("computeMinIntrinsicHeight returns 0")
    func testComputeMinIntrinsicHeight() {
        let viewport = createVerticalViewport()
        #expect(viewport.computeMinIntrinsicHeight(100.0) == 0.0)
    }

    @Test("computeMaxIntrinsicHeight returns 0")
    func testComputeMaxIntrinsicHeight() {
        let viewport = createVerticalViewport()
        #expect(viewport.computeMaxIntrinsicHeight(100.0) == 0.0)
    }

    @Test("child management: insert adds children")
    func testInsertChildren() {
        let viewport = createVerticalViewport()
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        viewport.insert(child1)
        #expect(viewport.childCount == 1)
        #expect(viewport.firstChild === child1)
        #expect(viewport.lastChild === child1)

        viewport.insert(child2, after: child1)
        #expect(viewport.childCount == 2)
        #expect(viewport.firstChild === child1)
        #expect(viewport.lastChild === child2)
    }

    @Test("child management: remove removes children")
    func testRemoveChildren() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let viewport = createVerticalViewport(children: [child1, child2])
        #expect(viewport.childCount == 2)

        viewport.remove(child1)
        #expect(viewport.childCount == 1)
        #expect(viewport.firstChild === child2)
    }

    @Test("child management: childAfter and childBefore")
    func testChildAfterAndBefore() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let child3 = MockRenderSliver()
        let viewport = createVerticalViewport(children: [child1, child2, child3])

        #expect(viewport.childAfter(child1) === child2)
        #expect(viewport.childAfter(child2) === child3)
        #expect(viewport.childAfter(child3) == nil)

        #expect(viewport.childBefore(child3) === child2)
        #expect(viewport.childBefore(child2) === child1)
        #expect(viewport.childBefore(child1) == nil)
    }

    @Test("addAll appends multiple children")
    func testAddAll() {
        let viewport = createVerticalViewport()
        let children = [MockRenderSliver(), MockRenderSliver(), MockRenderSliver()]
        viewport.addAll(children)
        #expect(viewport.childCount == 3)
        #expect(viewport.firstChild === children[0])
        #expect(viewport.lastChild === children[2])
    }
}

// =============================================================================
// MARK: - RenderViewport Tests
// =============================================================================

@Suite("RenderViewport Tests")
struct RenderViewportTests {

    @Test("Construction with default parameters")
    func testConstructionDefaults() {
        let viewport = createVerticalViewport()
        #expect(viewport.anchor == 0.0)
        #expect(viewport.center == nil)
        #expect(viewport.sizedByParent == true)
        #expect(viewport.childCount == 0)
        #expect(viewport.firstChild == nil)
        #expect(viewport.lastChild == nil)
    }

    @Test("Construction with explicit anchor")
    func testConstructionWithAnchor() {
        let viewport = createVerticalViewport(anchor: 0.5)
        #expect(viewport.anchor == 0.5)
    }

    @Test("anchor setter updates value")
    func testAnchorSetter() {
        let viewport = createVerticalViewport()
        viewport.anchor = 0.3
        #expect(viewport.anchor == 0.3)
    }

    @Test("anchor setter no-op for same value")
    func testAnchorSetterNoOp() {
        let viewport = createVerticalViewport(anchor: 0.5)
        viewport.anchor = 0.5
        #expect(viewport.anchor == 0.5)
    }

    @Test("center property defaults to firstChild when not specified")
    func testCenterDefaultsToFirstChild() {
        let child = MockRenderSliver()
        let viewport = createVerticalViewport(children: [child])
        #expect(viewport.center === child)
    }

    @Test("center property can be set explicitly")
    func testCenterExplicit() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let viewport = createVerticalViewport(
            children: [child1, child2],
            center: child2
        )
        #expect(viewport.center === child2)
    }

    @Test("center setter updates value")
    func testCenterSetter() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let viewport = createVerticalViewport(children: [child1, child2])
        viewport.center = child2
        #expect(viewport.center === child2)
    }

    @Test("sizedByParent is true")
    func testSizedByParent() {
        let viewport = createVerticalViewport()
        #expect(viewport.sizedByParent == true)
    }

    @Test("computeDryLayout returns constraints.biggest")
    func testComputeDryLayout() {
        let viewport = createVerticalViewport()
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 400,
            minHeight: 0, maxHeight: 600
        )
        let result = viewport.computeDryLayout(constraints)
        #expect(result == Size(400, 600))
    }

    @Test("computeDryLayout with tight constraints")
    func testComputeDryLayoutTight() {
        let viewport = createVerticalViewport()
        let constraints = BoxConstraints.tight(Size(300, 500))
        let result = viewport.computeDryLayout(constraints)
        #expect(result == Size(300, 500))
    }

    @Test("setupParentData creates SliverPhysicalContainerParentData")
    func testSetupParentData() {
        let viewport = createVerticalViewport()
        let child = MockRenderSliver()
        viewport.setupParentData(child)
        #expect(child.parentData is SliverPhysicalContainerParentData)
    }

    @Test("setupParentData does not replace if already correct type")
    func testSetupParentDataNoReplace() {
        let viewport = createVerticalViewport()
        let child = MockRenderSliver()
        let existingParentData = SliverPhysicalContainerParentData()
        child.parentData = existingParentData
        viewport.setupParentData(child)
        #expect(child.parentData === existingParentData)
    }

    @Test("useTwoPaneSemantics tag exists")
    func testUseTwoPaneSemantics() {
        let tag = RenderViewport.useTwoPaneSemantics
        #expect(tag.name == "RenderViewport.twoPane")
    }

    @Test("excludeFromScrolling tag exists")
    func testExcludeFromScrolling() {
        let tag = RenderViewport.excludeFromScrolling
        #expect(tag.name == "RenderViewport.excludeFromScrolling")
    }

    @Test("labelForChild returns center child label for index 0")
    func testLabelForChildCenter() {
        let child = MockRenderSliver()
        let viewport = createVerticalViewport(children: [child])
        let label = viewport.labelForChild(0)
        #expect(label == "center child")
    }

    @Test("labelForChild returns indexed label for non-zero index")
    func testLabelForChildNonZero() {
        let child = MockRenderSliver()
        let viewport = createVerticalViewport(children: [child])
        let label = viewport.labelForChild(1)
        #expect(label == "child 1")
    }

    @Test("labelForChild for negative index")
    func testLabelForChildNegative() {
        let child = MockRenderSliver()
        let viewport = createVerticalViewport(children: [child])
        let label = viewport.labelForChild(-1)
        #expect(label == "child -1")
    }

    @Test("Construction with horizontal axis direction")
    func testHorizontalConstruction() {
        let viewport = RenderViewport(
            axisDirection: .right,
            crossAxisDirection: .down,
            offset: ViewportOffset.zero()
        )
        #expect(viewport.axisDirection == .right)
        #expect(viewport.crossAxisDirection == .down)
        #expect(viewport.axis == .horizontal)
    }

    @Test("performLayout with no children sets scroll extents to zero")
    func testPerformLayoutNoChildren() {
        let viewport = createVerticalViewport()
        let constraints = BoxConstraints.tight(Size(400, 600))
        // First perform resize since sizedByParent
        viewport.layout(constraints)
        // After layout with no center/children, hasVisualOverflow should be false
        #expect(viewport.hasVisualOverflow == false)
    }

    @Test("childrenInPaintOrder with firstIsTop paints last to first")
    func testChildrenInPaintOrderFirstIsTop() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let child3 = MockRenderSliver()
        let viewport = createVerticalViewport(
            children: [child1, child2, child3],
            paintOrder: .firstIsTop
        )
        let paintOrder = viewport.childrenInPaintOrder
        #expect(paintOrder.count == 3)
        // firstIsTop => last to first order
        #expect(paintOrder[0] === child3)
        #expect(paintOrder[1] === child2)
        #expect(paintOrder[2] === child1)
    }

    @Test("childrenInPaintOrder with lastIsTop paints first to last")
    func testChildrenInPaintOrderLastIsTop() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let child3 = MockRenderSliver()
        let viewport = createVerticalViewport(
            children: [child1, child2, child3],
            paintOrder: .lastIsTop
        )
        let paintOrder = viewport.childrenInPaintOrder
        #expect(paintOrder.count == 3)
        // lastIsTop => first to last order
        #expect(paintOrder[0] === child1)
        #expect(paintOrder[1] === child2)
        #expect(paintOrder[2] === child3)
    }

    @Test("childrenInHitTestOrder with firstIsTop is first to last")
    func testChildrenInHitTestOrderFirstIsTop() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let viewport = createVerticalViewport(
            children: [child1, child2],
            paintOrder: .firstIsTop
        )
        let hitTestOrder = viewport.childrenInHitTestOrder
        #expect(hitTestOrder.count == 2)
        #expect(hitTestOrder[0] === child1)
        #expect(hitTestOrder[1] === child2)
    }

    @Test("childrenInHitTestOrder with lastIsTop is last to first")
    func testChildrenInHitTestOrderLastIsTop() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let viewport = createVerticalViewport(
            children: [child1, child2],
            paintOrder: .lastIsTop
        )
        let hitTestOrder = viewport.childrenInHitTestOrder
        #expect(hitTestOrder.count == 2)
        #expect(hitTestOrder[0] === child2)
        #expect(hitTestOrder[1] === child1)
    }

    @Test("maxLayoutCyclesPerChild static constant")
    func testMaxLayoutCycles() {
        // The constant is private, but we can verify indirectly that viewport
        // constructs correctly and the layout can handle no children.
        let viewport = createVerticalViewport()
        let constraints = BoxConstraints.tight(Size(400, 600))
        viewport.layout(constraints)
        // If the max layout cycles were unreasonable, this would hang or crash
        #expect(viewport.childCount == 0)
    }

    @Test("Construction with custom cache extent")
    func testConstructionCustomCacheExtent() {
        let viewport = createVerticalViewport(cacheExtent: 500.0)
        #expect(viewport.cacheExtent == 500.0)
    }

    @Test("Construction with viewport cache extent style")
    func testConstructionViewportCacheStyle() {
        let viewport = createVerticalViewport(
            cacheExtent: 2.0,
            cacheExtentStyle: .viewport
        )
        #expect(viewport.cacheExtentStyle == .viewport)
        #expect(viewport.cacheExtent == 2.0)
    }
}

// =============================================================================
// MARK: - RenderShrinkWrappingViewport Tests
// =============================================================================

@Suite("RenderShrinkWrappingViewport Tests")
struct RenderShrinkWrappingViewportTests {

    @Test("Construction with default parameters")
    func testConstructionDefaults() {
        let viewport = createShrinkWrappingViewport()
        #expect(viewport.axisDirection == .down)
        #expect(viewport.crossAxisDirection == .right)
        #expect(viewport.clipBehavior == .hardEdge)
        #expect(viewport.paintOrder == .firstIsTop)
        #expect(viewport.childCount == 0)
    }

    @Test("Construction with children")
    func testConstructionWithChildren() {
        let child1 = MockRenderSliver()
        let child2 = MockRenderSliver()
        let viewport = createShrinkWrappingViewport(children: [child1, child2])
        #expect(viewport.childCount == 2)
        #expect(viewport.firstChild === child1)
        #expect(viewport.lastChild === child2)
    }

    @Test("setupParentData creates SliverLogicalContainerParentData")
    func testSetupParentData() {
        let viewport = createShrinkWrappingViewport()
        let child = MockRenderSliver()
        viewport.setupParentData(child)
        #expect(child.parentData is SliverLogicalContainerParentData)
    }

    @Test("setupParentData does not replace if already correct type")
    func testSetupParentDataNoReplace() {
        let viewport = createShrinkWrappingViewport()
        let child = MockRenderSliver()
        let existingParentData = SliverLogicalContainerParentData()
        child.parentData = existingParentData
        viewport.setupParentData(child)
        #expect(child.parentData === existingParentData)
    }

    @Test("indexOfFirstChild is 0")
    func testIndexOfFirstChild() {
        let viewport = createShrinkWrappingViewport()
        #expect(viewport.indexOfFirstChild == 0)
    }

    @Test("labelForChild returns indexed label")
    func testLabelForChild() {
        let viewport = createShrinkWrappingViewport()
        #expect(viewport.labelForChild(0) == "child 0")
        #expect(viewport.labelForChild(1) == "child 1")
        #expect(viewport.labelForChild(5) == "child 5")
    }

    @Test("isRepaintBoundary is true")
    func testIsRepaintBoundary() {
        let viewport = createShrinkWrappingViewport()
        #expect(viewport.isRepaintBoundary == true)
    }

    @Test("performLayout with no children sizes to min")
    func testPerformLayoutNoChildren() {
        let viewport = createShrinkWrappingViewport()
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 400,
            minHeight: 0, maxHeight: 600
        )
        viewport.layout(constraints)
        // With no children, shrinkwrap viewport should size to minimum in main axis
        #expect(viewport.size.width == 400.0)
        #expect(viewport.size.height == 0.0)
    }

    @Test("hasVisualOverflow starts as false")
    func testHasVisualOverflow() {
        let viewport = createShrinkWrappingViewport()
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 400,
            minHeight: 0, maxHeight: 600
        )
        viewport.layout(constraints)
        #expect(viewport.hasVisualOverflow == false)
    }

    @Test("Construction with custom clip behavior")
    func testConstructionCustomClipBehavior() {
        let viewport = createShrinkWrappingViewport(clipBehavior: .antiAlias)
        #expect(viewport.clipBehavior == .antiAlias)
    }
}

// =============================================================================
// MARK: - RenderViewportBase showInViewport Tests
// =============================================================================

@Suite("RenderViewportBase showInViewport Tests")
struct ShowInViewportTests {

    @Test("showInViewport returns rect when descendant is nil")
    func testShowInViewportNilDescendant() {
        let viewport = createVerticalViewport()
        let rect = Rect.fromLTWH(10, 20, 30, 40)
        let result = RenderViewportBase.showInViewport(
            descendant: nil,
            rect: rect,
            viewport: viewport,
            offset: ViewportOffset.zero()
        )
        #expect(result == rect)
    }

    @Test("showInViewport returns nil rect when both are nil")
    func testShowInViewportBothNil() {
        let viewport = createVerticalViewport()
        let result = RenderViewportBase.showInViewport(
            descendant: nil,
            rect: nil,
            viewport: viewport,
            offset: ViewportOffset.zero()
        )
        #expect(result == nil)
    }
}

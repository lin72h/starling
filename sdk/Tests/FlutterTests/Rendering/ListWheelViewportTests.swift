// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for ListWheelViewport rendering types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/list_wheel_viewport.dart`
///
/// These tests cover:
///   - ListWheelChildManager: protocol requirements
///   - ListWheelParentData: index, transform properties
///   - RenderListWheelViewport: construction with all properties, property setters,
///     sizedByParent, computeDryLayout, child management, intrinsic dimensions,
///     static constants, isRepaintBoundary, setupParentData, index utilities

import Testing
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

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

/// A simple mock ListWheelChildManager for testing.
private class MockListWheelChildManager: ListWheelChildManager {
    var childCount: Int?
    private var _existsIndices: Set<Int>

    init(childCount: Int? = nil, existsIndices: Set<Int>? = nil) {
        self.childCount = childCount
        self._existsIndices = existsIndices ?? Set(0..<(childCount ?? 0))
    }

    func childExistsAt(_ index: Int) -> Bool {
        return _existsIndices.contains(index)
    }

    func createChild(_ index: Int, after: RenderBox?) {
        // No-op in tests
    }

    func removeChild(_ child: RenderBox) {
        // No-op in tests
    }
}

/// Helper to create a RenderListWheelViewport with reasonable defaults.
private func createListWheelViewport(
    childManager: ListWheelChildManager? = nil,
    offset: ViewportOffset? = nil,
    diameterRatio: Double = RenderListWheelViewport.defaultDiameterRatio,
    perspective: Double = RenderListWheelViewport.defaultPerspective,
    offAxisFraction: Double = 0,
    useMagnifier: Bool = false,
    magnification: Double = 1,
    overAndUnderCenterOpacity: Double = 1,
    itemExtent: Double = 50.0,
    squeeze: Double = 1,
    renderChildrenOutsideViewport: Bool = false,
    clipBehavior: Clip = .none,
    children: [RenderBox]? = nil
) -> RenderListWheelViewport {
    return RenderListWheelViewport(
        childManager: childManager ?? MockListWheelChildManager(childCount: 10),
        offset: offset ?? ViewportOffset.zero(),
        diameterRatio: diameterRatio,
        perspective: perspective,
        offAxisFraction: offAxisFraction,
        useMagnifier: useMagnifier,
        magnification: magnification,
        overAndUnderCenterOpacity: overAndUnderCenterOpacity,
        itemExtent: itemExtent,
        squeeze: squeeze,
        renderChildrenOutsideViewport: renderChildrenOutsideViewport,
        clipBehavior: clipBehavior,
        children: children
    )
}

// =============================================================================
// MARK: - ListWheelChildManager Protocol Tests
// =============================================================================

@Suite("ListWheelChildManager Protocol Tests")
struct ListWheelChildManagerTests {

    @Test("childCount returns configured value")
    func testChildCount() {
        let manager = MockListWheelChildManager(childCount: 5)
        #expect(manager.childCount == 5)
    }

    @Test("childCount returns nil when not specified")
    func testChildCountNil() {
        let manager = MockListWheelChildManager(childCount: nil)
        #expect(manager.childCount == nil)
    }

    @Test("childExistsAt returns correct values")
    func testChildExistsAt() {
        let manager = MockListWheelChildManager(
            childCount: nil,
            existsIndices: Set([0, 1, 2, 5])
        )
        #expect(manager.childExistsAt(0) == true)
        #expect(manager.childExistsAt(1) == true)
        #expect(manager.childExistsAt(2) == true)
        #expect(manager.childExistsAt(3) == false)
        #expect(manager.childExistsAt(5) == true)
    }
}

// =============================================================================
// MARK: - ListWheelParentData Tests
// =============================================================================

@Suite("ListWheelParentData Tests")
struct ListWheelParentDataTests {

    @Test("default index is nil")
    func testDefaultIndex() {
        let parentData = ListWheelParentData()
        #expect(parentData.index == nil)
    }

    @Test("index can be set")
    func testSetIndex() {
        let parentData = ListWheelParentData()
        parentData.index = 5
        #expect(parentData.index == 5)
    }

    @Test("default transform is nil")
    func testDefaultTransform() {
        let parentData = ListWheelParentData()
        #expect(parentData.transform == nil)
    }

    @Test("transform can be set")
    func testSetTransform() {
        let parentData = ListWheelParentData()
        let transform = Matrix4.identity()
        parentData.transform = transform
        #expect(parentData.transform != nil)
    }

    @Test("inherits from ContainerBoxParentData")
    func testInheritance() {
        let parentData = ListWheelParentData()
        #expect(parentData is ContainerBoxParentData<RenderBox>)
    }
}

// =============================================================================
// MARK: - RenderListWheelViewport Construction Tests
// =============================================================================

@Suite("RenderListWheelViewport Construction Tests")
struct RenderListWheelViewportConstructionTests {

    @Test("Construction with default parameters")
    func testConstructionDefaults() {
        let viewport = createListWheelViewport()
        #expect(viewport.diameterRatio == RenderListWheelViewport.defaultDiameterRatio)
        #expect(viewport.perspective == RenderListWheelViewport.defaultPerspective)
        #expect(viewport.offAxisFraction == 0.0)
        #expect(viewport.useMagnifier == false)
        #expect(viewport.magnification == 1.0)
        #expect(viewport.overAndUnderCenterOpacity == 1.0)
        #expect(viewport.itemExtent == 50.0)
        #expect(viewport.squeeze == 1.0)
        #expect(viewport.renderChildrenOutsideViewport == false)
        #expect(viewport.clipBehavior == .none)
    }

    @Test("Construction with custom parameters")
    func testConstructionCustom() {
        let viewport = createListWheelViewport(
            diameterRatio: 3.0,
            perspective: 0.005,
            offAxisFraction: 0.2,
            useMagnifier: true,
            magnification: 1.5,
            overAndUnderCenterOpacity: 0.5,
            itemExtent: 80.0,
            squeeze: 1.2,
            renderChildrenOutsideViewport: true,
            clipBehavior: .none
        )
        #expect(viewport.diameterRatio == 3.0)
        #expect(viewport.perspective == 0.005)
        #expect(viewport.offAxisFraction == 0.2)
        #expect(viewport.useMagnifier == true)
        #expect(viewport.magnification == 1.5)
        #expect(viewport.overAndUnderCenterOpacity == 0.5)
        #expect(viewport.itemExtent == 80.0)
        #expect(viewport.squeeze == 1.2)
        #expect(viewport.renderChildrenOutsideViewport == true)
    }

    @Test("Construction with children")
    func testConstructionWithChildren() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let viewport = createListWheelViewport(children: [child1, child2])
        #expect(viewport.childCount == 2)
        #expect(viewport.firstChild === child1)
        #expect(viewport.lastChild === child2)
    }
}

// =============================================================================
// MARK: - RenderListWheelViewport Property Setters Tests
// =============================================================================

@Suite("RenderListWheelViewport Property Setters Tests")
struct RenderListWheelViewportPropertySettersTests {

    @Test("diameterRatio setter updates value")
    func testDiameterRatioSetter() {
        let viewport = createListWheelViewport()
        viewport.diameterRatio = 3.0
        #expect(viewport.diameterRatio == 3.0)
    }

    @Test("diameterRatio setter no-op for same value")
    func testDiameterRatioSetterNoOp() {
        let viewport = createListWheelViewport(diameterRatio: 2.0)
        viewport.diameterRatio = 2.0
        #expect(viewport.diameterRatio == 2.0)
    }

    @Test("perspective setter updates value")
    func testPerspectiveSetter() {
        let viewport = createListWheelViewport()
        viewport.perspective = 0.005
        #expect(viewport.perspective == 0.005)
    }

    @Test("perspective setter no-op for same value")
    func testPerspectiveSetterNoOp() {
        let viewport = createListWheelViewport(perspective: 0.003)
        viewport.perspective = 0.003
        #expect(viewport.perspective == 0.003)
    }

    @Test("offAxisFraction setter updates value")
    func testOffAxisFractionSetter() {
        let viewport = createListWheelViewport()
        viewport.offAxisFraction = 0.5
        #expect(viewport.offAxisFraction == 0.5)
    }

    @Test("offAxisFraction setter no-op for same value")
    func testOffAxisFractionSetterNoOp() {
        let viewport = createListWheelViewport(offAxisFraction: 0.0)
        viewport.offAxisFraction = 0.0
        #expect(viewport.offAxisFraction == 0.0)
    }

    @Test("useMagnifier setter updates value")
    func testUseMagnifierSetter() {
        let viewport = createListWheelViewport()
        viewport.useMagnifier = true
        #expect(viewport.useMagnifier == true)
    }

    @Test("useMagnifier setter no-op for same value")
    func testUseMagnifierSetterNoOp() {
        let viewport = createListWheelViewport(useMagnifier: false)
        viewport.useMagnifier = false
        #expect(viewport.useMagnifier == false)
    }

    @Test("magnification setter updates value")
    func testMagnificationSetter() {
        let viewport = createListWheelViewport()
        viewport.magnification = 2.0
        #expect(viewport.magnification == 2.0)
    }

    @Test("magnification setter no-op for same value")
    func testMagnificationSetterNoOp() {
        let viewport = createListWheelViewport(magnification: 1.0)
        viewport.magnification = 1.0
        #expect(viewport.magnification == 1.0)
    }

    @Test("overAndUnderCenterOpacity setter updates value")
    func testOverAndUnderCenterOpacitySetter() {
        let viewport = createListWheelViewport()
        viewport.overAndUnderCenterOpacity = 0.5
        #expect(viewport.overAndUnderCenterOpacity == 0.5)
    }

    @Test("overAndUnderCenterOpacity setter no-op for same value")
    func testOverAndUnderCenterOpacitySetterNoOp() {
        let viewport = createListWheelViewport(overAndUnderCenterOpacity: 1.0)
        viewport.overAndUnderCenterOpacity = 1.0
        #expect(viewport.overAndUnderCenterOpacity == 1.0)
    }

    @Test("itemExtent setter updates value")
    func testItemExtentSetter() {
        let viewport = createListWheelViewport()
        viewport.itemExtent = 100.0
        #expect(viewport.itemExtent == 100.0)
    }

    @Test("itemExtent setter no-op for same value")
    func testItemExtentSetterNoOp() {
        let viewport = createListWheelViewport(itemExtent: 50.0)
        viewport.itemExtent = 50.0
        #expect(viewport.itemExtent == 50.0)
    }

    @Test("squeeze setter updates value")
    func testSqueezeSetter() {
        let viewport = createListWheelViewport()
        viewport.squeeze = 2.0
        #expect(viewport.squeeze == 2.0)
    }

    @Test("squeeze setter no-op for same value")
    func testSqueezeSetterNoOp() {
        let viewport = createListWheelViewport(squeeze: 1.0)
        viewport.squeeze = 1.0
        #expect(viewport.squeeze == 1.0)
    }

    @Test("renderChildrenOutsideViewport setter updates value")
    func testRenderChildrenOutsideViewportSetter() {
        let viewport = createListWheelViewport(clipBehavior: .none)
        viewport.renderChildrenOutsideViewport = true
        #expect(viewport.renderChildrenOutsideViewport == true)
    }

    @Test("renderChildrenOutsideViewport setter no-op for same value")
    func testRenderChildrenOutsideViewportSetterNoOp() {
        let viewport = createListWheelViewport(renderChildrenOutsideViewport: false)
        viewport.renderChildrenOutsideViewport = false
        #expect(viewport.renderChildrenOutsideViewport == false)
    }

    @Test("clipBehavior setter updates value")
    func testClipBehaviorSetter() {
        let viewport = createListWheelViewport()
        viewport.clipBehavior = .hardEdge
        #expect(viewport.clipBehavior == .hardEdge)
    }

    @Test("clipBehavior setter no-op for same value")
    func testClipBehaviorSetterNoOp() {
        let viewport = createListWheelViewport(clipBehavior: .none)
        viewport.clipBehavior = .none
        #expect(viewport.clipBehavior == .none)
    }

    @Test("offset setter updates value")
    func testOffsetSetter() {
        let offset1 = ViewportOffset.zero()
        let offset2 = ViewportOffset.fixed(100.0)
        let viewport = createListWheelViewport(offset: offset1)
        #expect(viewport.offset === offset1)
        viewport.offset = offset2
        #expect(viewport.offset === offset2)
    }

    @Test("offset setter no-op for same instance")
    func testOffsetSetterNoOp() {
        let offset = ViewportOffset.zero()
        let viewport = createListWheelViewport(offset: offset)
        viewport.offset = offset
        #expect(viewport.offset === offset)
    }
}

// =============================================================================
// MARK: - RenderListWheelViewport sizedByParent and Layout Tests
// =============================================================================

@Suite("RenderListWheelViewport sizedByParent and Layout Tests")
struct RenderListWheelViewportSizedByParentTests {

    @Test("sizedByParent is true")
    func testSizedByParent() {
        let viewport = createListWheelViewport()
        #expect(viewport.sizedByParent == true)
    }

    @Test("computeDryLayout returns constraints.biggest")
    func testComputeDryLayout() {
        let viewport = createListWheelViewport()
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 300,
            minHeight: 0, maxHeight: 500
        )
        let result = viewport.computeDryLayout(constraints)
        #expect(result == Size(300, 500))
    }

    @Test("computeDryLayout with tight constraints")
    func testComputeDryLayoutTight() {
        let viewport = createListWheelViewport()
        let constraints = BoxConstraints.tight(Size(200, 400))
        let result = viewport.computeDryLayout(constraints)
        #expect(result == Size(200, 400))
    }
}

// =============================================================================
// MARK: - RenderListWheelViewport Child Management Tests
// =============================================================================

@Suite("RenderListWheelViewport Child Management Tests")
struct RenderListWheelViewportChildManagementTests {

    @Test("insert adds child")
    func testInsert() {
        let viewport = createListWheelViewport()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        viewport.insert(child)
        #expect(viewport.childCount == 1)
        #expect(viewport.firstChild === child)
        #expect(viewport.lastChild === child)
    }

    @Test("insert multiple children in order")
    func testInsertMultiple() {
        let viewport = createListWheelViewport()
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let child3 = FixedSizeRenderBox(width: 100, height: 50)
        viewport.insert(child1)
        viewport.insert(child2, after: child1)
        viewport.insert(child3, after: child2)
        #expect(viewport.childCount == 3)
        #expect(viewport.firstChild === child1)
        #expect(viewport.lastChild === child3)
    }

    @Test("remove removes child")
    func testRemove() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let viewport = createListWheelViewport(children: [child1, child2])
        #expect(viewport.childCount == 2)

        viewport.remove(child1)
        #expect(viewport.childCount == 1)
        #expect(viewport.firstChild === child2)
    }

    @Test("childAfter returns next sibling")
    func testChildAfter() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let viewport = createListWheelViewport(children: [child1, child2])

        #expect(viewport.childAfter(child1) === child2)
        #expect(viewport.childAfter(child2) == nil)
    }

    @Test("childBefore returns previous sibling")
    func testChildBefore() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let viewport = createListWheelViewport(children: [child1, child2])

        #expect(viewport.childBefore(child2) === child1)
        #expect(viewport.childBefore(child1) == nil)
    }

    @Test("addAll appends multiple children")
    func testAddAll() {
        let viewport = createListWheelViewport()
        let children = [
            FixedSizeRenderBox(width: 100, height: 50),
            FixedSizeRenderBox(width: 100, height: 50),
            FixedSizeRenderBox(width: 100, height: 50),
        ]
        viewport.addAll(children)
        #expect(viewport.childCount == 3)
        #expect(viewport.firstChild === children[0])
        #expect(viewport.lastChild === children[2])
    }

    @Test("remove last child leaves empty list")
    func testRemoveLastChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let viewport = createListWheelViewport(children: [child])
        viewport.remove(child)
        #expect(viewport.childCount == 0)
        #expect(viewport.firstChild == nil)
        #expect(viewport.lastChild == nil)
    }
}

// =============================================================================
// MARK: - RenderListWheelViewport Static Constants Tests
// =============================================================================

@Suite("RenderListWheelViewport Static Constants Tests")
struct RenderListWheelViewportStaticConstantsTests {

    @Test("defaultDiameterRatio is 2.0")
    func testDefaultDiameterRatio() {
        #expect(RenderListWheelViewport.defaultDiameterRatio == 2.0)
    }

    @Test("defaultPerspective is 0.003")
    func testDefaultPerspective() {
        #expect(RenderListWheelViewport.defaultPerspective == 0.003)
    }

    @Test("diameterRatioZeroMessage is non-empty")
    func testDiameterRatioZeroMessage() {
        let message = RenderListWheelViewport.diameterRatioZeroMessage
        #expect(!message.isEmpty)
        #expect(message.contains("diameterRatio"))
    }

    @Test("perspectiveTooHighMessage is non-empty")
    func testPerspectiveTooHighMessage() {
        let message = RenderListWheelViewport.perspectiveTooHighMessage
        #expect(!message.isEmpty)
        #expect(message.contains("perspective"))
    }

    @Test("clipBehaviorAndRenderChildrenOutsideViewportConflict is non-empty")
    func testClipBehaviorConflictMessage() {
        let message = RenderListWheelViewport.clipBehaviorAndRenderChildrenOutsideViewportConflict
        #expect(!message.isEmpty)
        #expect(message.contains("renderChildrenOutsideViewport"))
    }
}

// =============================================================================
// MARK: - RenderListWheelViewport Miscellaneous Tests
// =============================================================================

@Suite("RenderListWheelViewport Miscellaneous Tests")
struct RenderListWheelViewportMiscTests {

    @Test("isRepaintBoundary is true")
    func testIsRepaintBoundary() {
        let viewport = createListWheelViewport()
        #expect(viewport.isRepaintBoundary == true)
    }

    @Test("setupParentData creates ListWheelParentData")
    func testSetupParentData() {
        let viewport = createListWheelViewport()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        viewport.setupParentData(child)
        #expect(child.parentData is ListWheelParentData)
    }

    @Test("setupParentData does not replace if already correct type")
    func testSetupParentDataNoReplace() {
        let viewport = createListWheelViewport()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let existingParentData = ListWheelParentData()
        child.parentData = existingParentData
        viewport.setupParentData(child)
        #expect(child.parentData === existingParentData)
    }

    @Test("childManager is accessible")
    func testChildManagerAccessible() {
        let manager = MockListWheelChildManager(childCount: 5)
        let viewport = createListWheelViewport(childManager: manager)
        #expect(viewport.childManager === manager)
    }

    @Test("indexOf returns correct index from parentData")
    func testIndexOf() {
        let viewport = createListWheelViewport()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        viewport.insert(child)
        let parentData = child.parentData as! ListWheelParentData
        parentData.index = 3
        #expect(viewport.indexOf(child) == 3)
    }

    @Test("scrollOffsetToIndex converts correctly")
    func testScrollOffsetToIndex() {
        let viewport = createListWheelViewport(itemExtent: 50.0)
        #expect(viewport.scrollOffsetToIndex(0.0) == 0)
        #expect(viewport.scrollOffsetToIndex(49.0) == 0)
        #expect(viewport.scrollOffsetToIndex(50.0) == 1)
        #expect(viewport.scrollOffsetToIndex(100.0) == 2)
        #expect(viewport.scrollOffsetToIndex(125.0) == 2)
    }

    @Test("indexToScrollOffset converts correctly")
    func testIndexToScrollOffset() {
        let viewport = createListWheelViewport(itemExtent: 50.0)
        #expect(viewport.indexToScrollOffset(0) == 0.0)
        #expect(viewport.indexToScrollOffset(1) == 50.0)
        #expect(viewport.indexToScrollOffset(2) == 100.0)
        #expect(viewport.indexToScrollOffset(5) == 250.0)
    }

    @Test("RenderListWheelViewport conforms to RenderAbstractViewport")
    func testRenderAbstractViewportConformance() {
        let viewport = createListWheelViewport()
        #expect(viewport is any RenderAbstractViewport)
    }
}

// =============================================================================
// MARK: - RenderListWheelViewport Intrinsic Dimension Tests
// =============================================================================

@Suite("RenderListWheelViewport Intrinsic Dimension Tests")
struct RenderListWheelViewportIntrinsicTests {

    @Test("computeMinIntrinsicWidth with no children returns 0")
    func testMinIntrinsicWidthNoChildren() {
        let viewport = createListWheelViewport()
        #expect(viewport.computeMinIntrinsicWidth(100.0) == 0.0)
    }

    @Test("computeMaxIntrinsicWidth with no children returns 0")
    func testMaxIntrinsicWidthNoChildren() {
        let viewport = createListWheelViewport()
        #expect(viewport.computeMaxIntrinsicWidth(100.0) == 0.0)
    }

    @Test("computeMinIntrinsicHeight with childCount returns count * itemExtent")
    func testMinIntrinsicHeightWithCount() {
        let manager = MockListWheelChildManager(childCount: 5)
        let viewport = createListWheelViewport(
            childManager: manager,
            itemExtent: 40.0
        )
        #expect(viewport.computeMinIntrinsicHeight(100.0) == 200.0)
    }

    @Test("computeMaxIntrinsicHeight with childCount returns count * itemExtent")
    func testMaxIntrinsicHeightWithCount() {
        let manager = MockListWheelChildManager(childCount: 5)
        let viewport = createListWheelViewport(
            childManager: manager,
            itemExtent: 40.0
        )
        #expect(viewport.computeMaxIntrinsicHeight(100.0) == 200.0)
    }

    @Test("computeMinIntrinsicHeight with nil childCount returns 0")
    func testMinIntrinsicHeightNilCount() {
        let manager = MockListWheelChildManager(childCount: nil)
        let viewport = createListWheelViewport(
            childManager: manager,
            itemExtent: 40.0
        )
        #expect(viewport.computeMinIntrinsicHeight(100.0) == 0.0)
    }

    @Test("computeMaxIntrinsicHeight with nil childCount returns 0")
    func testMaxIntrinsicHeightNilCount() {
        let manager = MockListWheelChildManager(childCount: nil)
        let viewport = createListWheelViewport(
            childManager: manager,
            itemExtent: 40.0
        )
        #expect(viewport.computeMaxIntrinsicHeight(100.0) == 0.0)
    }

    @Test("computeMinIntrinsicWidth with children returns max child width")
    func testMinIntrinsicWidthWithChildren() {
        let child1 = FixedSizeRenderBox(width: 80, height: 50)
        let child2 = FixedSizeRenderBox(width: 120, height: 50)
        let viewport = createListWheelViewport(children: [child1, child2])
        #expect(viewport.computeMinIntrinsicWidth(100.0) == 120.0)
    }

    @Test("computeMaxIntrinsicWidth with children returns max child width")
    func testMaxIntrinsicWidthWithChildren() {
        let child1 = FixedSizeRenderBox(width: 80, height: 50)
        let child2 = FixedSizeRenderBox(width: 120, height: 50)
        let viewport = createListWheelViewport(children: [child1, child2])
        #expect(viewport.computeMaxIntrinsicWidth(100.0) == 120.0)
    }
}

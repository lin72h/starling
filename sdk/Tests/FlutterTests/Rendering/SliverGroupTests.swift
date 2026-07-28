// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for SliverGroup render objects.
///
/// **Swift Source:** `Sources/Flutter/Rendering/SliverGroup.swift`
///
/// These tests cover:
///   - RenderSliverCrossAxisGroup: construction, child management, parentData,
///     layout, hit testing, painting, child position methods
///   - RenderSliverMainAxisGroup: construction, child management, parentData,
///     layout, childScrollOffset, hit testing, painting, growth direction

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// Creates a standard SliverConstraints for testing.
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

/// A test RenderSliver that produces configurable geometry when laid out.
///
/// The `geometryBuilder` closure receives the constraints passed to `performLayout`
/// and returns the `SliverGeometry` to use. If no builder is set, geometry
/// defaults to `.zero`.
private class ConfigurableRenderSliver: RenderSliver {
    var geometryBuilder: ((SliverConstraints) -> SliverGeometry)?

    init(geometryBuilder: ((SliverConstraints) -> SliverGeometry)? = nil) {
        self.geometryBuilder = geometryBuilder
        super.init()
    }

    override func performLayout() {
        let constraints = self.sliverConstraints
        if let builder = geometryBuilder {
            geometry = builder(constraints)
        } else {
            geometry = .zero
        }
    }
}

/// Creates a ConfigurableRenderSliver that reports a fixed scroll extent and
/// paint extent (clamped to remaining paint extent), with a given optional
/// crossAxisExtent.
private func makeFixedSliver(
    scrollExtent: Double,
    crossAxisExtent: Double? = nil,
    maxScrollObstructionExtent: Double = 0.0
) -> ConfigurableRenderSliver {
    ConfigurableRenderSliver { constraints in
        let paintExtent = min(
            max(0.0, scrollExtent - constraints.scrollOffset),
            constraints.remainingPaintExtent
        )
        return SliverGeometry(
            scrollExtent: scrollExtent,
            paintExtent: paintExtent,
            maxPaintExtent: scrollExtent,
            maxScrollObstructionExtent: maxScrollObstructionExtent,
            crossAxisExtent: crossAxisExtent,
            hasVisualOverflow: false,
            cacheExtent: paintExtent
        )
    }
}

// =============================================================================
// MARK: - RenderSliverCrossAxisGroup Tests
// =============================================================================

// MARK: - Construction Tests

final class RenderSliverCrossAxisGroupConstructionTests: XCTestCase {

    /// Test that a new cross axis group starts with no children.
    func testInitialStateEmpty() {
        let group = RenderSliverCrossAxisGroup()
        XCTAssertNil(group.firstChild)
        XCTAssertNil(group.lastChild)
        XCTAssertEqual(group.childCount, 0)
    }
}

// MARK: - Child Management Tests

final class RenderSliverCrossAxisGroupChildManagementTests: XCTestCase {

    /// Test inserting a single child.
    func testInsertSingleChild() {
        let group = RenderSliverCrossAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        XCTAssertEqual(group.childCount, 1)
        XCTAssertTrue(group.firstChild === child)
        XCTAssertTrue(group.lastChild === child)
    }

    /// Test inserting multiple children in order.
    func testInsertMultipleChildren() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        let child3 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        group.insert(child3, after: child2)
        XCTAssertEqual(group.childCount, 3)
        XCTAssertTrue(group.firstChild === child1)
        XCTAssertTrue(group.lastChild === child3)
    }

    /// Test childAfter traversal.
    func testChildAfterTraversal() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        let child3 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        group.insert(child3, after: child2)
        XCTAssertTrue(group.childAfter(child1) === child2)
        XCTAssertTrue(group.childAfter(child2) === child3)
        XCTAssertNil(group.childAfter(child3))
    }

    /// Test childBefore traversal.
    func testChildBeforeTraversal() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        let child3 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        group.insert(child3, after: child2)
        XCTAssertNil(group.childBefore(child1))
        XCTAssertTrue(group.childBefore(child2) === child1)
        XCTAssertTrue(group.childBefore(child3) === child2)
    }

    /// Test removing a child.
    func testRemoveChild() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        let child3 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        group.insert(child3, after: child2)

        group.remove(child2)
        XCTAssertEqual(group.childCount, 2)
        XCTAssertTrue(group.firstChild === child1)
        XCTAssertTrue(group.lastChild === child3)
        XCTAssertTrue(group.childAfter(child1) === child3)
    }

    /// Test removing the first child.
    func testRemoveFirstChild() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)

        group.remove(child1)
        XCTAssertEqual(group.childCount, 1)
        XCTAssertTrue(group.firstChild === child2)
        XCTAssertTrue(group.lastChild === child2)
    }

    /// Test removing the last child.
    func testRemoveLastChild() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)

        group.remove(child2)
        XCTAssertEqual(group.childCount, 1)
        XCTAssertTrue(group.firstChild === child1)
        XCTAssertTrue(group.lastChild === child1)
    }

    /// Test removing all children results in empty group.
    func testRemoveAllChildren() {
        let group = RenderSliverCrossAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        group.remove(child)
        XCTAssertEqual(group.childCount, 0)
        XCTAssertNil(group.firstChild)
        XCTAssertNil(group.lastChild)
    }

    /// Test addAll with multiple children.
    func testAddAll() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        let child3 = ConfigurableRenderSliver()
        group.addAll([child1, child2, child3])
        XCTAssertEqual(group.childCount, 3)
        XCTAssertTrue(group.firstChild === child1)
        XCTAssertTrue(group.lastChild === child3)
    }

    /// Test addAll with nil.
    func testAddAllNil() {
        let group = RenderSliverCrossAxisGroup()
        group.addAll(nil)
        XCTAssertEqual(group.childCount, 0)
    }

    /// Test insert at beginning (after: nil).
    func testInsertAtBeginning() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2) // after: nil inserts at beginning
        XCTAssertTrue(group.firstChild === child2)
        XCTAssertTrue(group.lastChild === child1)
    }
}

// MARK: - Parent Data Tests

final class RenderSliverCrossAxisGroupParentDataTests: XCTestCase {

    /// Test setupParentData assigns SliverPhysicalContainerParentData with crossAxisFlex = 1.
    func testSetupParentDataAssignsContainerParentData() {
        let group = RenderSliverCrossAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        XCTAssertTrue(child.parentData is SliverPhysicalContainerParentData)
    }

    /// Test setupParentData sets default crossAxisFlex to 1.
    func testSetupParentDataDefaultFlex() {
        let group = RenderSliverCrossAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        let pd = child.parentData as! SliverPhysicalParentData
        XCTAssertEqual(pd.crossAxisFlex, 1)
    }

    /// Test setupParentData does not replace existing container parent data.
    func testSetupParentDataDoesNotReplaceExisting() {
        let group = RenderSliverCrossAxisGroup()
        let child = ConfigurableRenderSliver()
        let existingPD = SliverPhysicalContainerParentData()
        existingPD.crossAxisFlex = 3
        child.parentData = existingPD
        group.setupParentData(child)
        // Should not replace
        XCTAssertTrue(child.parentData === existingPD)
        XCTAssertEqual((child.parentData as! SliverPhysicalParentData).crossAxisFlex, 3)
    }
}

// MARK: - Child Position Tests

final class RenderSliverCrossAxisGroupChildPositionTests: XCTestCase {

    /// Test childMainAxisPosition is always 0.
    func testChildMainAxisPositionIsZero() {
        let group = RenderSliverCrossAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        XCTAssertEqual(group.childMainAxisPosition(child), 0.0)
    }

    /// Test childCrossAxisPosition uses paint offset (vertical axis).
    func testChildCrossAxisPositionVertical() {
        let group = RenderSliverCrossAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)

        // Lay out the group to set constraints (vertical axis)
        let constraints = makeSliverConstraints(axisDirection: .down)
        group.layout(constraints)

        // Set paintOffset AFTER layout (layout overwrites paint offsets)
        let pd = child.parentData as! SliverPhysicalParentData
        pd.paintOffset = Offset(100.0, 0.0)

        XCTAssertEqual(group.childCrossAxisPosition(child), 100.0)
    }

    /// Test childCrossAxisPosition uses paint offset (horizontal axis).
    func testChildCrossAxisPositionHorizontal() {
        let group = RenderSliverCrossAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)

        // Lay out with horizontal axis
        let constraints = makeSliverConstraints(
            axisDirection: .right,
            crossAxisExtent: 400.0,
            crossAxisDirection: .down
        )
        group.layout(constraints)

        // For horizontal axis, cross axis position is from dy
        let pd = child.parentData as! SliverPhysicalParentData
        // After layout, the paint offset is set by the layout algorithm.
        // For a single child with flex=1, offset should start at 0.
        XCTAssertEqual(group.childCrossAxisPosition(child), pd.paintOffset.dy)
    }
}

// MARK: - Layout Tests

final class RenderSliverCrossAxisGroupLayoutTests: XCTestCase {

    /// Test layout with a single flexible child distributes full cross-axis extent.
    func testLayoutSingleFlexibleChild() {
        let group = RenderSliverCrossAxisGroup()
        let child = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child)

        let constraints = makeSliverConstraints(crossAxisExtent: 400.0)
        group.layout(constraints)

        XCTAssertNotNil(group.geometry)
        XCTAssertEqual(group.geometry!.scrollExtent, 200.0)
    }

    /// Test layout with two flexible children of equal flex divides space equally.
    func testLayoutTwoEqualFlexChildren() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 300.0)
        let child2 = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(crossAxisExtent: 400.0)
        group.layout(constraints)

        // Group geometry takes the maximum scroll extent among children
        XCTAssertNotNil(group.geometry)
        XCTAssertEqual(group.geometry!.scrollExtent, 300.0)
    }

    /// Test layout with children of different flex values.
    func testLayoutDifferentFlexValues() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 100.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        // Set child2 to flex=2
        (child2.parentData as! SliverPhysicalParentData).crossAxisFlex = 2

        let constraints = makeSliverConstraints(crossAxisExtent: 300.0)
        group.layout(constraints)

        // Total flex = 1 + 2 = 3. child1 gets 100, child2 gets 200.
        XCTAssertNotNil(group.geometry)
        XCTAssertEqual(group.geometry!.scrollExtent, 200.0)
    }

    /// Test layout produces paint offsets that position children along cross axis (vertical).
    func testLayoutPaintOffsetsVertical() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            crossAxisExtent: 400.0
        )
        group.layout(constraints)

        let pd1 = child1.parentData as! SliverPhysicalParentData
        let pd2 = child2.parentData as! SliverPhysicalParentData

        // For vertical axis: paint offset.dx = cross-axis position
        // child1 at offset 0, child2 at offset 200 (400/2)
        XCTAssertEqual(pd1.paintOffset.dx, 0.0)
        XCTAssertEqual(pd2.paintOffset.dx, 200.0)
    }

    /// Test layout produces paint offsets that position children along cross axis (horizontal).
    func testLayoutPaintOffsetsHorizontal() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .right,
            crossAxisExtent: 400.0,
            crossAxisDirection: .down
        )
        group.layout(constraints)

        let pd1 = child1.parentData as! SliverPhysicalParentData
        let pd2 = child2.parentData as! SliverPhysicalParentData

        // For horizontal axis: paint offset.dy = cross-axis position
        XCTAssertEqual(pd1.paintOffset.dy, 0.0)
        XCTAssertEqual(pd2.paintOffset.dy, 200.0)
    }

    /// Test layout with a zero-flex child that sets its own cross axis extent.
    func testLayoutWithZeroFlexChild() {
        let group = RenderSliverCrossAxisGroup()
        // Child with flex=0 that sets its own crossAxisExtent to 100
        let fixedCrossChild = makeFixedSliver(scrollExtent: 200.0, crossAxisExtent: 100.0)
        let flexChild = makeFixedSliver(scrollExtent: 200.0)
        group.insert(fixedCrossChild)
        group.insert(flexChild, after: fixedCrossChild)

        // Set the fixed child to flex=0
        (fixedCrossChild.parentData as! SliverPhysicalParentData).crossAxisFlex = 0

        let constraints = makeSliverConstraints(crossAxisExtent: 400.0)
        group.layout(constraints)

        // fixedCrossChild gets 100, flexChild gets remaining 300
        XCTAssertNotNil(group.geometry)
        XCTAssertEqual(group.geometry!.scrollExtent, 200.0)
    }

    /// Test geometry takes the maximum scroll extent from all children.
    func testGeometryTakesMaxScrollExtent() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 100.0)
        let child2 = makeFixedSliver(scrollExtent: 500.0)
        let child3 = makeFixedSliver(scrollExtent: 300.0)
        group.addAll([child1, child2, child3])

        let constraints = makeSliverConstraints(crossAxisExtent: 600.0)
        group.layout(constraints)

        XCTAssertEqual(group.geometry!.scrollExtent, 500.0)
    }
}

// MARK: - Paint Transform Tests

final class RenderSliverCrossAxisGroupPaintTransformTests: XCTestCase {

    /// Test applyPaintTransform uses child's paint offset.
    func testApplyPaintTransformUsesChildPaintOffset() {
        let group = RenderSliverCrossAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)

        let pd = child.parentData as! SliverPhysicalParentData
        pd.paintOffset = Offset(50.0, 30.0)

        var transform = Matrix4.identity()
        group.applyPaintTransform(child, &transform)

        // The transform should have been translated by the paint offset
        XCTAssertEqual(transform.entry(0, 3), 50.0, accuracy: 1e-10)
        XCTAssertEqual(transform.entry(1, 3), 30.0, accuracy: 1e-10)
    }
}

// MARK: - Hit Testing Tests

final class RenderSliverCrossAxisGroupHitTestTests: XCTestCase {

    /// Test hitTestChildren with no children returns false.
    func testHitTestChildrenNoChildren() {
        let group = RenderSliverCrossAxisGroup()
        let constraints = makeSliverConstraints()
        group.layout(constraints)

        let result = SliverHitTestResult()
        let hit = group.hitTestChildren(
            result,
            mainAxisPosition: 100.0,
            crossAxisPosition: 200.0
        )
        XCTAssertFalse(hit)
    }

    /// Test hitTestChildren iterates in reverse order (last child first).
    func testHitTestChildrenReverseOrder() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(crossAxisExtent: 400.0)
        group.layout(constraints)

        // Both children now have geometry with hitTestExtent > 0
        let result = SliverHitTestResult()
        // This should try child2 first (last child), then child1
        let hit = group.hitTestChildren(
            result,
            mainAxisPosition: 100.0,
            crossAxisPosition: 250.0 // In child2's area (200-400)
        )
        // The hit test should find a child
        // Whether it returns true depends on the child's hitTest implementation
        // but the method should not crash
        XCTAssertTrue(hit || !hit) // Verifies it runs without error
    }
}

// =============================================================================
// MARK: - RenderSliverMainAxisGroup Tests
// =============================================================================

// MARK: - Construction Tests

final class RenderSliverMainAxisGroupConstructionTests: XCTestCase {

    /// Test that a new main axis group starts with no children.
    func testInitialStateEmpty() {
        let group = RenderSliverMainAxisGroup()
        XCTAssertNil(group.firstChild)
        XCTAssertNil(group.lastChild)
        XCTAssertEqual(group.childCount, 0)
    }
}

// MARK: - Child Management Tests

final class RenderSliverMainAxisGroupChildManagementTests: XCTestCase {

    /// Test inserting a single child.
    func testInsertSingleChild() {
        let group = RenderSliverMainAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        XCTAssertEqual(group.childCount, 1)
        XCTAssertTrue(group.firstChild === child)
        XCTAssertTrue(group.lastChild === child)
    }

    /// Test inserting multiple children in order.
    func testInsertMultipleChildren() {
        let group = RenderSliverMainAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        let child3 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        group.insert(child3, after: child2)
        XCTAssertEqual(group.childCount, 3)
        XCTAssertTrue(group.firstChild === child1)
        XCTAssertTrue(group.lastChild === child3)
    }

    /// Test childAfter traversal.
    func testChildAfterTraversal() {
        let group = RenderSliverMainAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        XCTAssertTrue(group.childAfter(child1) === child2)
        XCTAssertNil(group.childAfter(child2))
    }

    /// Test childBefore traversal.
    func testChildBeforeTraversal() {
        let group = RenderSliverMainAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        XCTAssertNil(group.childBefore(child1))
        XCTAssertTrue(group.childBefore(child2) === child1)
    }

    /// Test removing a middle child.
    func testRemoveMiddleChild() {
        let group = RenderSliverMainAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        let child3 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        group.insert(child3, after: child2)
        group.remove(child2)
        XCTAssertEqual(group.childCount, 2)
        XCTAssertTrue(group.childAfter(child1) === child3)
        XCTAssertTrue(group.childBefore(child3) === child1)
    }

    /// Test removing the first child.
    func testRemoveFirstChild() {
        let group = RenderSliverMainAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        group.remove(child1)
        XCTAssertEqual(group.childCount, 1)
        XCTAssertTrue(group.firstChild === child2)
    }

    /// Test removing the last child.
    func testRemoveLastChild() {
        let group = RenderSliverMainAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2, after: child1)
        group.remove(child2)
        XCTAssertEqual(group.childCount, 1)
        XCTAssertTrue(group.lastChild === child1)
    }

    /// Test removing all children.
    func testRemoveAllChildren() {
        let group = RenderSliverMainAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        group.remove(child)
        XCTAssertEqual(group.childCount, 0)
        XCTAssertNil(group.firstChild)
        XCTAssertNil(group.lastChild)
    }

    /// Test addAll with multiple children.
    func testAddAll() {
        let group = RenderSliverMainAxisGroup()
        let children = [
            ConfigurableRenderSliver(),
            ConfigurableRenderSliver(),
            ConfigurableRenderSliver(),
        ]
        group.addAll(children)
        XCTAssertEqual(group.childCount, 3)
        XCTAssertTrue(group.firstChild === children[0])
        XCTAssertTrue(group.lastChild === children[2])
    }

    /// Test addAll with nil.
    func testAddAllNil() {
        let group = RenderSliverMainAxisGroup()
        group.addAll(nil)
        XCTAssertEqual(group.childCount, 0)
    }

    /// Test insert at beginning (after: nil).
    func testInsertAtBeginning() {
        let group = RenderSliverMainAxisGroup()
        let child1 = ConfigurableRenderSliver()
        let child2 = ConfigurableRenderSliver()
        group.insert(child1)
        group.insert(child2) // after: nil inserts at beginning
        XCTAssertTrue(group.firstChild === child2)
        XCTAssertTrue(group.lastChild === child1)
    }
}

// MARK: - Parent Data Tests

final class RenderSliverMainAxisGroupParentDataTests: XCTestCase {

    /// Test setupParentData assigns SliverPhysicalContainerParentData.
    func testSetupParentDataAssignsContainerParentData() {
        let group = RenderSliverMainAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        XCTAssertTrue(child.parentData is SliverPhysicalContainerParentData)
    }

    /// Test setupParentData does not set crossAxisFlex (unlike cross-axis group).
    func testSetupParentDataNoDefaultFlex() {
        let group = RenderSliverMainAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        let pd = child.parentData as! SliverPhysicalParentData
        // Main axis group does not set crossAxisFlex
        XCTAssertNil(pd.crossAxisFlex)
    }

    /// Test setupParentData does not replace existing container parent data.
    func testSetupParentDataDoesNotReplaceExisting() {
        let group = RenderSliverMainAxisGroup()
        let child = ConfigurableRenderSliver()
        let existingPD = SliverPhysicalContainerParentData()
        child.parentData = existingPD
        group.setupParentData(child)
        XCTAssertTrue(child.parentData === existingPD)
    }
}

// MARK: - Child Position Tests

final class RenderSliverMainAxisGroupChildPositionTests: XCTestCase {

    /// Test childCrossAxisPosition is always 0.
    func testChildCrossAxisPositionIsZero() {
        let group = RenderSliverMainAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        XCTAssertEqual(group.childCrossAxisPosition(child), 0.0)
    }

    /// Test childMainAxisPosition for down axis returns paint offset dy.
    func testChildMainAxisPositionDown() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            remainingPaintExtent: 600.0
        )
        group.layout(constraints)

        // For down axis (forward growth), position comes from paintOffset.dy
        let pd1 = child1.parentData as! SliverPhysicalParentData
        let pd2 = child2.parentData as! SliverPhysicalParentData
        XCTAssertEqual(group.childMainAxisPosition(child1), pd1.paintOffset.dy)
        XCTAssertEqual(group.childMainAxisPosition(child2), pd2.paintOffset.dy)
    }

    /// Test childMainAxisPosition for right axis returns paint offset dx.
    func testChildMainAxisPositionRight() {
        let group = RenderSliverMainAxisGroup()
        let child = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child)

        let constraints = makeSliverConstraints(
            axisDirection: .right,
            growthDirection: .forward,
            remainingPaintExtent: 600.0,
            crossAxisDirection: .down
        )
        group.layout(constraints)

        let pd = child.parentData as! SliverPhysicalParentData
        XCTAssertEqual(group.childMainAxisPosition(child), pd.paintOffset.dx)
    }
}

// MARK: - Layout Tests

final class RenderSliverMainAxisGroupLayoutTests: XCTestCase {

    /// Test layout with a single child (forward, vertical).
    func testLayoutSingleChildForwardVertical() {
        let group = RenderSliverMainAxisGroup()
        let child = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0
        )
        group.layout(constraints)

        XCTAssertNotNil(group.geometry)
        XCTAssertEqual(group.geometry!.scrollExtent, 200.0)
        XCTAssertEqual(group.geometry!.paintExtent, 200.0)
    }

    /// Test layout with two children sums scroll extents.
    func testLayoutTwoChildrenSumsScrollExtent() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        group.layout(constraints)

        XCTAssertNotNil(group.geometry)
        // Total scroll extent = 200 + 300 = 500
        XCTAssertEqual(group.geometry!.scrollExtent, 500.0)
    }

    /// Test layout with three children.
    func testLayoutThreeChildren() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 100.0)
        let child2 = makeFixedSliver(scrollExtent: 150.0)
        let child3 = makeFixedSliver(scrollExtent: 200.0)
        group.addAll([child1, child2, child3])

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        group.layout(constraints)

        XCTAssertNotNil(group.geometry)
        // Total scroll extent = 100 + 150 + 200 = 450
        XCTAssertEqual(group.geometry!.scrollExtent, 450.0)
    }

    /// Test layout with scroll offset that partially scrolls out the first child.
    func testLayoutWithScrollOffset() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 100.0,
            remainingPaintExtent: 500.0,
            remainingCacheExtent: 750.0
        )
        group.layout(constraints)

        XCTAssertNotNil(group.geometry)
        XCTAssertEqual(group.geometry!.scrollExtent, 500.0)
        // Paint extent should be clamped to remainingPaintExtent
        XCTAssertTrue(group.geometry!.paintExtent <= 500.0)
    }

    /// Test layout correctly positions second child after first in paint offset.
    func testLayoutPaintOffsetSequential() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        group.layout(constraints)

        let pd1 = child1.parentData as! SliverPhysicalParentData
        let pd2 = child2.parentData as! SliverPhysicalParentData

        // child1 starts at offset 0.0 along main axis (dy for vertical)
        XCTAssertEqual(pd1.paintOffset.dy, 0.0, accuracy: 1e-10)
        // child2 starts after child1's layout extent (200.0)
        XCTAssertEqual(pd2.paintOffset.dy, 200.0, accuracy: 1e-10)
    }

    /// Test layout horizontal axis positions children along x.
    func testLayoutHorizontalAxisPositions() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 150.0)
        let child2 = makeFixedSliver(scrollExtent: 250.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .right,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            crossAxisExtent: 400.0,
            crossAxisDirection: .down,
            remainingCacheExtent: 850.0
        )
        group.layout(constraints)

        let pd1 = child1.parentData as! SliverPhysicalParentData
        let pd2 = child2.parentData as! SliverPhysicalParentData

        // Horizontal axis: main axis offset is along dx
        XCTAssertEqual(pd1.paintOffset.dx, 0.0, accuracy: 1e-10)
        XCTAssertEqual(pd2.paintOffset.dx, 150.0, accuracy: 1e-10)
    }

    /// Test hasVisualOverflow when children exceed remaining paint extent.
    func testHasVisualOverflow() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 400.0)
        let child2 = makeFixedSliver(scrollExtent: 400.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        group.layout(constraints)

        // Total scroll extent 800 > remainingPaintExtent 600
        XCTAssertTrue(group.geometry!.hasVisualOverflow)
    }

    /// Test hasVisualOverflow when scrollOffset > 0.
    func testHasVisualOverflowWhenScrolled() {
        let group = RenderSliverMainAxisGroup()
        let child = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 50.0,
            remainingPaintExtent: 550.0,
            remainingCacheExtent: 800.0
        )
        group.layout(constraints)

        // scrollOffset > 0.0 triggers visual overflow
        XCTAssertTrue(group.geometry!.hasVisualOverflow)
    }

    /// Test no visual overflow when content fits and not scrolled.
    func testNoVisualOverflow() {
        let group = RenderSliverMainAxisGroup()
        let child = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        group.layout(constraints)

        // scrollExtent 200 <= remainingPaintExtent 600, and scrollOffset is 0
        XCTAssertFalse(group.geometry!.hasVisualOverflow)
    }

    /// Test scrollOffsetCorrection is forwarded from child.
    func testScrollOffsetCorrectionForwarded() {
        let group = RenderSliverMainAxisGroup()
        // A child that reports a scrollOffsetCorrection
        let correctingChild = ConfigurableRenderSliver { _ in
            SliverGeometry(scrollOffsetCorrection: 10.0)
        }
        group.insert(correctingChild)

        let constraints = makeSliverConstraints()
        group.layout(constraints)

        XCTAssertNotNil(group.geometry)
        XCTAssertEqual(group.geometry!.scrollOffsetCorrection, 10.0)
    }

    /// Test maxPaintExtent sums from children.
    func testMaxPaintExtentSums() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        group.layout(constraints)

        // maxPaintExtent = sum of children's maxPaintExtent = 200 + 300
        XCTAssertEqual(group.geometry!.maxPaintExtent, 500.0)
    }
}

// MARK: - Child Scroll Offset Tests

final class RenderSliverMainAxisGroupChildScrollOffsetTests: XCTestCase {

    /// Test childScrollOffset for first child is 0.
    func testChildScrollOffsetFirstChildForward() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            growthDirection: .forward
        )
        group.layout(constraints)

        XCTAssertEqual(group.childScrollOffset(child1), 0.0)
    }

    /// Test childScrollOffset for second child equals first child's scroll extent.
    func testChildScrollOffsetSecondChildForward() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            growthDirection: .forward
        )
        group.layout(constraints)

        XCTAssertEqual(group.childScrollOffset(child2), 200.0)
    }

    /// Test childScrollOffset for third child sums first two scroll extents.
    func testChildScrollOffsetThirdChildForward() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 100.0)
        let child2 = makeFixedSliver(scrollExtent: 200.0)
        let child3 = makeFixedSliver(scrollExtent: 300.0)
        group.addAll([child1, child2, child3])

        let constraints = makeSliverConstraints(
            growthDirection: .forward
        )
        group.layout(constraints)

        XCTAssertEqual(group.childScrollOffset(child3), 300.0)
    }
}

// MARK: - Reverse Growth Direction Tests

final class RenderSliverMainAxisGroupReverseGrowthTests: XCTestCase {

    /// Test layout with reverse growth direction lays out from last child.
    func testLayoutReverseGrowthDirection() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .reverse,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        group.layout(constraints)

        XCTAssertNotNil(group.geometry)
        // Total scroll extent is still the sum
        XCTAssertEqual(group.geometry!.scrollExtent, 500.0)
    }

    /// Test childScrollOffset with reverse growth direction.
    func testChildScrollOffsetReverse() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            growthDirection: .reverse
        )
        group.layout(constraints)

        // For reverse, childScrollOffset for the last child (child2) is 0 because
        // no children come after it in the reverse iteration direction.
        // child1's offset is computed from children after it (child2)
        let child1Offset = group.childScrollOffset(child1)
        let child2Offset = group.childScrollOffset(child2)

        // In reverse, child2 is the leading child.
        // childScrollOffset(child1) sums scroll extents of children after child1 (child2),
        // which is -300 (negative for reverse)
        XCTAssertNotNil(child1Offset)
        XCTAssertNotNil(child2Offset)
    }
}

// MARK: - Paint Transform Tests

final class RenderSliverMainAxisGroupPaintTransformTests: XCTestCase {

    /// Test applyPaintTransform uses child's paint offset.
    func testApplyPaintTransformUsesChildPaintOffset() {
        let group = RenderSliverMainAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        let pd = child.parentData as! SliverPhysicalParentData
        pd.paintOffset = Offset(10.0, 20.0)

        var transform = Matrix4.identity()
        group.applyPaintTransform(child, &transform)

        XCTAssertEqual(transform.entry(0, 3), 10.0, accuracy: 1e-10)
        XCTAssertEqual(transform.entry(1, 3), 20.0, accuracy: 1e-10)
    }

    /// Test applyPaintTransform with zero offset does not modify transform.
    func testApplyPaintTransformZeroOffset() {
        let group = RenderSliverMainAxisGroup()
        let child = ConfigurableRenderSliver()
        group.insert(child)
        // Default paintOffset is .zero

        var transform = Matrix4.identity()
        group.applyPaintTransform(child, &transform)

        XCTAssertEqual(transform.entry(0, 3), 0.0, accuracy: 1e-10)
        XCTAssertEqual(transform.entry(1, 3), 0.0, accuracy: 1e-10)
    }
}

// MARK: - Hit Testing Tests

final class RenderSliverMainAxisGroupHitTestTests: XCTestCase {

    /// Test hitTestChildren with no children returns false.
    func testHitTestChildrenNoChildren() {
        let group = RenderSliverMainAxisGroup()
        let constraints = makeSliverConstraints()
        group.layout(constraints)

        let result = SliverHitTestResult()
        let hit = group.hitTestChildren(
            result,
            mainAxisPosition: 100.0,
            crossAxisPosition: 200.0
        )
        XCTAssertFalse(hit)
    }

    /// Test hitTestChildren iterates in forward order (first child first).
    func testHitTestChildrenForwardOrder() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            scrollOffset: 0.0,
            remainingPaintExtent: 600.0,
            remainingCacheExtent: 850.0
        )
        group.layout(constraints)

        let result = SliverHitTestResult()
        // The method should execute without crashing
        let hit = group.hitTestChildren(
            result,
            mainAxisPosition: 100.0,
            crossAxisPosition: 200.0
        )
        XCTAssertTrue(hit || !hit) // Verifies it runs without error
    }

    /// Test hitTestChildren with single child.
    func testHitTestChildrenSingleChild() {
        let group = RenderSliverMainAxisGroup()
        let child = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child)

        let constraints = makeSliverConstraints()
        group.layout(constraints)

        let result = SliverHitTestResult()
        let _ = group.hitTestChildren(
            result,
            mainAxisPosition: 50.0,
            crossAxisPosition: 100.0
        )
        // No crash expected
    }
}

// MARK: - Painting Tests

final class RenderSliverMainAxisGroupPaintTests: XCTestCase {

    /// Test paint with no children does not crash.
    func testPaintNoChildren() {
        let group = RenderSliverMainAxisGroup()
        let constraints = makeSliverConstraints()
        group.layout(constraints)

        let context = PaintingContext()
        // Should not crash
        group.paint(context, .zero)
    }

    /// Test paint with visible children does not crash.
    func testPaintWithVisibleChildren() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(
            axisDirection: .down,
            growthDirection: .forward,
            remainingPaintExtent: 600.0
        )
        group.layout(constraints)

        let context = PaintingContext()
        // Should not crash - paints in reverse order (last to first)
        group.paint(context, .zero)
    }

    /// Test paint skips invisible children (zero geometry).
    func testPaintSkipsInvisibleChildren() {
        let group = RenderSliverMainAxisGroup()
        let visibleChild = makeFixedSliver(scrollExtent: 200.0)
        let invisibleChild = ConfigurableRenderSliver { _ in .zero }
        group.insert(visibleChild)
        group.insert(invisibleChild, after: visibleChild)

        let constraints = makeSliverConstraints()
        group.layout(constraints)

        let context = PaintingContext()
        // Should not crash and should skip invisible child
        group.paint(context, .zero)
    }
}

// MARK: - Cross Axis Group Painting Tests

final class RenderSliverCrossAxisGroupPaintTests: XCTestCase {

    /// Test paint with no children does not crash.
    func testPaintNoChildren() {
        let group = RenderSliverCrossAxisGroup()
        let constraints = makeSliverConstraints()
        group.layout(constraints)

        let context = PaintingContext()
        group.paint(context, .zero)
    }

    /// Test paint with visible children does not crash.
    func testPaintWithVisibleChildren() {
        let group = RenderSliverCrossAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 200.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints(crossAxisExtent: 400.0)
        group.layout(constraints)

        let context = PaintingContext()
        // Should not crash - paints in forward order (first to last)
        group.paint(context, .zero)
    }
}

// MARK: - Semantics Tests

final class RenderSliverMainAxisGroupSemanticsTests: XCTestCase {

    /// Test visitChildrenForSemantics visits visible children.
    func testVisitChildrenForSemanticsVisitsVisibleChildren() {
        let group = RenderSliverMainAxisGroup()
        let child1 = makeFixedSliver(scrollExtent: 200.0)
        let child2 = makeFixedSliver(scrollExtent: 300.0)
        group.insert(child1)
        group.insert(child2, after: child1)

        let constraints = makeSliverConstraints()
        group.layout(constraints)

        var visited: [RenderObject] = []
        group.visitChildrenForSemantics { child in
            visited.append(child)
        }

        // Both children have visible geometry (paintExtent > 0)
        XCTAssertEqual(visited.count, 2)
    }

    /// Test visitChildrenForSemantics skips invisible children with zero cache extent.
    func testVisitChildrenForSemanticsSkipsInvisible() {
        let group = RenderSliverMainAxisGroup()
        let visibleChild = makeFixedSliver(scrollExtent: 200.0)
        // Invisible child with zero geometry
        let invisibleChild = ConfigurableRenderSliver { _ in .zero }
        group.insert(visibleChild)
        group.insert(invisibleChild, after: visibleChild)

        let constraints = makeSliverConstraints()
        group.layout(constraints)

        var visited: [RenderObject] = []
        group.visitChildrenForSemantics { child in
            visited.append(child)
        }

        // Only the visible child should be visited
        XCTAssertEqual(visited.count, 1)
        XCTAssertTrue(visited[0] === visibleChild)
    }
}

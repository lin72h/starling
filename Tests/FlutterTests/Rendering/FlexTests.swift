// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Flex layout types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/flex.dart`
///
/// These tests cover:
///   - FlexFit enum values
///   - MainAxisSize enum values
///   - MainAxisAlignment enum values and distributeSpace
///   - CrossAxisAlignment enum values and getChildCrossAxisOffset
///   - FlexParentData default values
///   - RenderFlex construction and default properties
///   - Property setters (markNeedsLayout on change, no-op on same value)
///   - Horizontal layout with fixed children
///   - Vertical layout with fixed children
///   - Flex children with flex factor distribution (tight vs loose)
///   - MainAxisAlignment positioning (start, end, center, spaceBetween, spaceAround, spaceEvenly)
///   - CrossAxisAlignment positioning (start, end, center, stretch)
///   - MainAxisSize min vs max behavior
///   - Spacing between children
///   - Intrinsic dimensions
///   - Overflow detection
///   - Direction/TextDirection (horizontal + RTL, vertical + up)

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A concrete RenderBox subclass with configurable intrinsic dimensions
/// and a fixed size for layout, used as a child in tests.
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

/// Helper to lay out a RenderFlex with given constraints.
private func layoutFlex(
    _ flex: RenderFlex,
    constraints: BoxConstraints = BoxConstraints(
        minWidth: 0, maxWidth: 800, minHeight: 0, maxHeight: 600
    )
) {
    flex.layout(constraints)
}

/// Helper to get the offset of a child in a RenderFlex after layout.
private func childOffset(_ child: RenderBox) -> Offset {
    let parentData = child.parentData as! FlexParentData
    return parentData.offset
}

/// Helper to add children in order to a RenderFlex.
///
/// Uses manual `insert` calls to ensure correct linked-list ordering,
/// tracking the previously inserted child to pass as the `after` parameter.
private func addChildrenInOrder(_ flex: RenderFlex, _ children: [RenderBox]) {
    guard !children.isEmpty else { return }
    flex.insert(children[0])
    var prev = children[0]
    for i in 1..<children.count {
        flex.insert(children[i], after: prev)
        prev = children[i]
    }
}

/// Helper to create a RenderFlex with properly ordered children.
private func createFlex(
    children: [RenderBox] = [],
    direction: Axis = .horizontal,
    mainAxisAlignment: MainAxisAlignment = .start,
    mainAxisSize: MainAxisSize = .max,
    crossAxisAlignment: CrossAxisAlignment = .center,
    textDirection: TextDirection? = nil,
    verticalDirection: VerticalDirection = .down,
    textBaseline: TextBaseline? = nil,
    clipBehavior: Clip = .none,
    spacing: Double = 0.0
) -> RenderFlex {
    let flex = RenderFlex(
        direction: direction,
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        textDirection: textDirection,
        verticalDirection: verticalDirection,
        textBaseline: textBaseline,
        clipBehavior: clipBehavior,
        spacing: spacing
    )
    addChildrenInOrder(flex, children)
    return flex
}

// MARK: - FlexFit Enum Tests

final class FlexFitEnumTests: XCTestCase {

    /// Test that both FlexFit cases exist and are distinct.
    func testCasesExist() {
        let tight = FlexFit.tight
        let loose = FlexFit.loose
        XCTAssertNotNil(tight)
        XCTAssertNotNil(loose)
    }

    /// Test that tight and loose are different values.
    func testCasesAreDistinct() {
        XCTAssertTrue(FlexFit.tight != FlexFit.loose)
    }
}

// MARK: - MainAxisSize Enum Tests

final class MainAxisSizeEnumTests: XCTestCase {

    /// Test that both MainAxisSize cases exist.
    func testCasesExist() {
        let minCase = MainAxisSize.min
        let maxCase = MainAxisSize.max
        XCTAssertNotNil(minCase)
        XCTAssertNotNil(maxCase)
    }

    /// Test that min and max are distinct.
    func testCasesAreDistinct() {
        XCTAssertTrue(MainAxisSize.min != MainAxisSize.max)
    }
}

// MARK: - MainAxisAlignment Enum Tests

final class MainAxisAlignmentEnumTests: XCTestCase {

    /// Test that all six MainAxisAlignment cases exist.
    func testAllCasesExist() {
        let start = MainAxisAlignment.start
        let end = MainAxisAlignment.end
        let center = MainAxisAlignment.center
        let spaceBetween = MainAxisAlignment.spaceBetween
        let spaceAround = MainAxisAlignment.spaceAround
        let spaceEvenly = MainAxisAlignment.spaceEvenly
        XCTAssertNotNil(start)
        XCTAssertNotNil(end)
        XCTAssertNotNil(center)
        XCTAssertNotNil(spaceBetween)
        XCTAssertNotNil(spaceAround)
        XCTAssertNotNil(spaceEvenly)
    }

    /// Test distributeSpace for .start (not flipped): leading = 0, between = spacing.
    func testDistributeSpaceStart() {
        let (leading, between) = MainAxisAlignment.start.distributeSpace(
            freeSpace: 100, itemCount: 3, flipped: false, spacing: 0
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 0.0)
    }

    /// Test distributeSpace for .start (flipped): leading = freeSpace.
    func testDistributeSpaceStartFlipped() {
        let (leading, between) = MainAxisAlignment.start.distributeSpace(
            freeSpace: 100, itemCount: 3, flipped: true, spacing: 0
        )
        XCTAssertEqual(leading, 100.0)
        XCTAssertEqual(between, 0.0)
    }

    /// Test distributeSpace for .end (not flipped) behaves like .start(flipped).
    func testDistributeSpaceEnd() {
        let (leading, between) = MainAxisAlignment.end.distributeSpace(
            freeSpace: 100, itemCount: 3, flipped: false, spacing: 0
        )
        XCTAssertEqual(leading, 100.0)
        XCTAssertEqual(between, 0.0)
    }

    /// Test distributeSpace for .end (flipped) behaves like .start(not flipped).
    func testDistributeSpaceEndFlipped() {
        let (leading, between) = MainAxisAlignment.end.distributeSpace(
            freeSpace: 100, itemCount: 3, flipped: true, spacing: 0
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 0.0)
    }

    /// Test distributeSpace for .center: leading = freeSpace/2.
    func testDistributeSpaceCenter() {
        let (leading, between) = MainAxisAlignment.center.distributeSpace(
            freeSpace: 100, itemCount: 3, flipped: false, spacing: 0
        )
        XCTAssertEqual(leading, 50.0)
        XCTAssertEqual(between, 0.0)
    }

    /// Test distributeSpace for .spaceBetween with multiple items.
    func testDistributeSpaceSpaceBetween() {
        let (leading, between) = MainAxisAlignment.spaceBetween.distributeSpace(
            freeSpace: 100, itemCount: 3, flipped: false, spacing: 0
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 50.0)  // 100 / (3 - 1) = 50
    }

    /// Test distributeSpace for .spaceBetween with single item falls back to .start.
    func testDistributeSpaceSpaceBetweenSingleItem() {
        let (leading, between) = MainAxisAlignment.spaceBetween.distributeSpace(
            freeSpace: 100, itemCount: 1, flipped: false, spacing: 0
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 0.0)
    }

    /// Test distributeSpace for .spaceAround with items.
    func testDistributeSpaceSpaceAround() {
        let (leading, between) = MainAxisAlignment.spaceAround.distributeSpace(
            freeSpace: 120, itemCount: 3, flipped: false, spacing: 0
        )
        // leading = 120 / 3 / 2 = 20, between = 120 / 3 = 40
        XCTAssertEqual(leading, 20.0)
        XCTAssertEqual(between, 40.0)
    }

    /// Test distributeSpace for .spaceAround with zero items falls back to .start.
    func testDistributeSpaceSpaceAroundZeroItems() {
        let (leading, between) = MainAxisAlignment.spaceAround.distributeSpace(
            freeSpace: 100, itemCount: 0, flipped: false, spacing: 0
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 0.0)
    }

    /// Test distributeSpace for .spaceEvenly.
    func testDistributeSpaceSpaceEvenly() {
        let (leading, between) = MainAxisAlignment.spaceEvenly.distributeSpace(
            freeSpace: 120, itemCount: 3, flipped: false, spacing: 0
        )
        // leading = 120 / (3 + 1) = 30, between = 120 / (3 + 1) = 30
        XCTAssertEqual(leading, 30.0)
        XCTAssertEqual(between, 30.0)
    }

    /// Test that distributeSpace incorporates spacing into between-space.
    func testDistributeSpaceWithSpacing() {
        let (leading, between) = MainAxisAlignment.start.distributeSpace(
            freeSpace: 100, itemCount: 3, flipped: false, spacing: 10
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 10.0)
    }

    /// Test distributeSpace for .spaceBetween with spacing added.
    func testDistributeSpaceSpaceBetweenWithSpacing() {
        let (leading, between) = MainAxisAlignment.spaceBetween.distributeSpace(
            freeSpace: 100, itemCount: 3, flipped: false, spacing: 5
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 55.0)  // 100 / 2 + 5 = 55
    }
}

// MARK: - CrossAxisAlignment Enum Tests

final class CrossAxisAlignmentEnumTests: XCTestCase {

    /// Test that all five CrossAxisAlignment cases exist.
    func testAllCasesExist() {
        let start = CrossAxisAlignment.start
        let end = CrossAxisAlignment.end
        let center = CrossAxisAlignment.center
        let stretch = CrossAxisAlignment.stretch
        let baseline = CrossAxisAlignment.baseline
        XCTAssertNotNil(start)
        XCTAssertNotNil(end)
        XCTAssertNotNil(center)
        XCTAssertNotNil(stretch)
        XCTAssertNotNil(baseline)
    }

    /// Test getChildCrossAxisOffset for .start (not flipped): returns 0.
    func testCrossAxisOffsetStart() {
        let offset = CrossAxisAlignment.start.getChildCrossAxisOffset(50.0, false)
        XCTAssertEqual(offset, 0.0)
    }

    /// Test getChildCrossAxisOffset for .start (flipped): returns freeSpace.
    func testCrossAxisOffsetStartFlipped() {
        let offset = CrossAxisAlignment.start.getChildCrossAxisOffset(50.0, true)
        XCTAssertEqual(offset, 50.0)
    }

    /// Test getChildCrossAxisOffset for .end (not flipped): returns freeSpace.
    func testCrossAxisOffsetEnd() {
        let offset = CrossAxisAlignment.end.getChildCrossAxisOffset(50.0, false)
        XCTAssertEqual(offset, 50.0)
    }

    /// Test getChildCrossAxisOffset for .end (flipped): returns 0.
    func testCrossAxisOffsetEndFlipped() {
        let offset = CrossAxisAlignment.end.getChildCrossAxisOffset(50.0, true)
        XCTAssertEqual(offset, 0.0)
    }

    /// Test getChildCrossAxisOffset for .center: returns freeSpace / 2.
    func testCrossAxisOffsetCenter() {
        let offset = CrossAxisAlignment.center.getChildCrossAxisOffset(50.0, false)
        XCTAssertEqual(offset, 25.0)
    }

    /// Test getChildCrossAxisOffset for .stretch: returns 0.
    func testCrossAxisOffsetStretch() {
        let offset = CrossAxisAlignment.stretch.getChildCrossAxisOffset(50.0, false)
        XCTAssertEqual(offset, 0.0)
    }

    /// Test getChildCrossAxisOffset for .baseline: returns 0.
    func testCrossAxisOffsetBaseline() {
        let offset = CrossAxisAlignment.baseline.getChildCrossAxisOffset(50.0, false)
        XCTAssertEqual(offset, 0.0)
    }
}

// MARK: - FlexParentData Tests

final class FlexParentDataTests: XCTestCase {

    /// Test default values of FlexParentData.
    func testDefaultValues() {
        let parentData = FlexParentData()
        XCTAssertNil(parentData.flex)
        XCTAssertNil(parentData.fit)
    }

    /// Test that flex and fit can be set.
    func testSetFlexAndFit() {
        let parentData = FlexParentData()
        parentData.flex = 2
        parentData.fit = .tight
        XCTAssertEqual(parentData.flex, 2)
        XCTAssertEqual(parentData.fit, .tight)
    }

    /// Test that FlexParentData is a subclass of ContainerBoxParentData.
    func testIsContainerBoxParentData() {
        let parentData = FlexParentData()
        XCTAssertTrue(
            parentData is ContainerBoxParentData<RenderBox>,
            "FlexParentData should be a ContainerBoxParentData<RenderBox>"
        )
    }

    /// Test that sibling pointers default to nil.
    func testSiblingPointersDefaultToNil() {
        let parentData = FlexParentData()
        XCTAssertNil(parentData.previousSibling)
        XCTAssertNil(parentData.nextSibling)
    }

    /// Test that offset defaults to zero.
    func testOffsetDefaultsToZero() {
        let parentData = FlexParentData()
        XCTAssertEqual(parentData.offset.dx, 0.0)
        XCTAssertEqual(parentData.offset.dy, 0.0)
    }
}

// MARK: - RenderFlex Construction Tests

final class RenderFlexConstructionTests: XCTestCase {

    /// Test default construction values.
    func testDefaultConstruction() {
        let flex = RenderFlex()
        XCTAssertEqual(flex.direction, .horizontal)
        XCTAssertEqual(flex.mainAxisAlignment, .start)
        XCTAssertEqual(flex.mainAxisSize, .max)
        XCTAssertEqual(flex.crossAxisAlignment, .center)
        XCTAssertNil(flex.textDirection)
        XCTAssertEqual(flex.verticalDirection, .down)
        XCTAssertNil(flex.textBaseline)
        XCTAssertEqual(flex.clipBehavior, .none)
        XCTAssertEqual(flex.spacing, 0.0)
        XCTAssertNil(flex.firstChild)
        XCTAssertNil(flex.lastChild)
        XCTAssertEqual(flex.childCount, 0)
    }

    /// Test construction with custom properties.
    func testCustomConstruction() {
        let flex = RenderFlex(
            direction: .vertical,
            mainAxisAlignment: .center,
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            textDirection: .rtl,
            verticalDirection: .up,
            clipBehavior: .hardEdge,
            spacing: 10.0
        )
        XCTAssertEqual(flex.direction, .vertical)
        XCTAssertEqual(flex.mainAxisAlignment, .center)
        XCTAssertEqual(flex.mainAxisSize, .min)
        XCTAssertEqual(flex.crossAxisAlignment, .stretch)
        XCTAssertEqual(flex.textDirection, .rtl)
        XCTAssertEqual(flex.verticalDirection, .up)
        XCTAssertEqual(flex.clipBehavior, .hardEdge)
        XCTAssertEqual(flex.spacing, 10.0)
    }

    /// Test construction with children.
    func testConstructionWithChildren() {
        let child1 = FixedSizeRenderBox(width: 50, height: 50)
        let child2 = FixedSizeRenderBox(width: 60, height: 60)
        let flex = createFlex(children: [child1, child2])
        XCTAssertEqual(flex.childCount, 2)
        XCTAssertTrue(flex.firstChild === child1)
        XCTAssertTrue(flex.childAfter(child1) === child2)
        XCTAssertNil(flex.childAfter(child2))
    }

    /// Test setupParentData installs FlexParentData.
    func testSetupParentData() {
        let flex = RenderFlex()
        let child = RenderBox()
        flex.setupParentData(child)
        XCTAssertTrue(child.parentData is FlexParentData)
    }

    /// Test that existing FlexParentData is not replaced.
    func testSetupParentDataPreservesExisting() {
        let flex = RenderFlex()
        let child = RenderBox()
        let existingData = FlexParentData()
        existingData.flex = 3
        child.parentData = existingData
        flex.setupParentData(child)
        let data = child.parentData as! FlexParentData
        XCTAssertEqual(data.flex, 3)
    }
}

// MARK: - RenderFlex Child Management Tests

final class RenderFlexChildManagementTests: XCTestCase {

    /// Test inserting children.
    func testInsertChildren() {
        let flex = RenderFlex()
        let child1 = FixedSizeRenderBox(width: 50, height: 50)
        let child2 = FixedSizeRenderBox(width: 60, height: 60)

        flex.insert(child1)
        XCTAssertEqual(flex.childCount, 1)
        XCTAssertTrue(flex.firstChild === child1)
        XCTAssertTrue(flex.lastChild === child1)

        flex.insert(child2, after: child1)
        XCTAssertEqual(flex.childCount, 2)
        XCTAssertTrue(flex.firstChild === child1)
        XCTAssertTrue(flex.childAfter(child1) === child2)
        XCTAssertNil(flex.childAfter(child2))
    }

    /// Test removing a child.
    func testRemoveChild() {
        let child1 = FixedSizeRenderBox(width: 50, height: 50)
        let child2 = FixedSizeRenderBox(width: 60, height: 60)
        let flex = createFlex(children: [child1, child2])
        XCTAssertEqual(flex.childCount, 2)

        flex.remove(child1)
        XCTAssertEqual(flex.childCount, 1)
        XCTAssertTrue(flex.firstChild === child2)
    }

    /// Test childAfter and childBefore navigation.
    func testChildNavigation() {
        let child1 = FixedSizeRenderBox(width: 50, height: 50)
        let child2 = FixedSizeRenderBox(width: 60, height: 60)
        let child3 = FixedSizeRenderBox(width: 70, height: 70)
        let flex = createFlex(children: [child1, child2, child3])

        XCTAssertTrue(flex.childAfter(child1) === child2)
        XCTAssertTrue(flex.childAfter(child2) === child3)
        XCTAssertNil(flex.childAfter(child3))

        XCTAssertNil(flex.childBefore(child1))
        XCTAssertTrue(flex.childBefore(child2) === child1)
        XCTAssertTrue(flex.childBefore(child3) === child2)
    }

    /// Test addAll with nil does not crash.
    func testAddAllNil() {
        let flex = RenderFlex()
        flex.addAll(nil)
        XCTAssertEqual(flex.childCount, 0)
    }

    /// Test addAll with empty array.
    func testAddAllEmpty() {
        let flex = RenderFlex()
        flex.addAll([])
        XCTAssertEqual(flex.childCount, 0)
    }
}

// MARK: - RenderFlex Property Setter Tests

final class RenderFlexPropertySetterTests: XCTestCase {

    /// Test that setting direction triggers markNeedsLayout.
    func testDirectionSetterTriggersLayout() {
        let flex = RenderFlex(direction: .horizontal)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.direction = .vertical
        XCTAssertTrue(flex.needsLayout)
        XCTAssertEqual(flex.direction, .vertical)
    }

    /// Test that setting direction to the same value is a no-op.
    func testDirectionSetterNoOp() {
        let flex = RenderFlex(direction: .horizontal)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.direction = .horizontal
        XCTAssertFalse(flex.needsLayout)
    }

    /// Test that setting mainAxisAlignment triggers markNeedsLayout.
    func testMainAxisAlignmentSetterTriggersLayout() {
        let flex = RenderFlex(mainAxisAlignment: .start)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.mainAxisAlignment = .center
        XCTAssertTrue(flex.needsLayout)
        XCTAssertEqual(flex.mainAxisAlignment, .center)
    }

    /// Test that setting mainAxisAlignment to the same value is a no-op.
    func testMainAxisAlignmentSetterNoOp() {
        let flex = RenderFlex(mainAxisAlignment: .start)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.mainAxisAlignment = .start
        XCTAssertFalse(flex.needsLayout)
    }

    /// Test that setting mainAxisSize triggers markNeedsLayout.
    func testMainAxisSizeSetterTriggersLayout() {
        let flex = RenderFlex(mainAxisSize: .max)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.mainAxisSize = .min
        XCTAssertTrue(flex.needsLayout)
        XCTAssertEqual(flex.mainAxisSize, .min)
    }

    /// Test that setting mainAxisSize to the same value is a no-op.
    func testMainAxisSizeSetterNoOp() {
        let flex = RenderFlex(mainAxisSize: .max)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.mainAxisSize = .max
        XCTAssertFalse(flex.needsLayout)
    }

    /// Test that setting crossAxisAlignment triggers markNeedsLayout.
    func testCrossAxisAlignmentSetterTriggersLayout() {
        let flex = RenderFlex(crossAxisAlignment: .center)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.crossAxisAlignment = .start
        XCTAssertTrue(flex.needsLayout)
        XCTAssertEqual(flex.crossAxisAlignment, .start)
    }

    /// Test that setting crossAxisAlignment to the same value is a no-op.
    func testCrossAxisAlignmentSetterNoOp() {
        let flex = RenderFlex(crossAxisAlignment: .center)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.crossAxisAlignment = .center
        XCTAssertFalse(flex.needsLayout)
    }

    /// Test that setting textDirection triggers markNeedsLayout.
    func testTextDirectionSetterTriggersLayout() {
        let flex = RenderFlex(textDirection: .ltr)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.textDirection = .rtl
        XCTAssertTrue(flex.needsLayout)
        XCTAssertEqual(flex.textDirection, .rtl)
    }

    /// Test that setting textDirection to the same value is a no-op.
    func testTextDirectionSetterNoOp() {
        let flex = RenderFlex(textDirection: .ltr)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.textDirection = .ltr
        XCTAssertFalse(flex.needsLayout)
    }

    /// Test that setting verticalDirection triggers markNeedsLayout.
    func testVerticalDirectionSetterTriggersLayout() {
        let flex = RenderFlex(verticalDirection: .down)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.verticalDirection = .up
        XCTAssertTrue(flex.needsLayout)
        XCTAssertEqual(flex.verticalDirection, .up)
    }

    /// Test that setting verticalDirection to the same value is a no-op.
    func testVerticalDirectionSetterNoOp() {
        let flex = RenderFlex(verticalDirection: .down)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.verticalDirection = .down
        XCTAssertFalse(flex.needsLayout)
    }

    /// Test that setting textBaseline triggers markNeedsLayout.
    func testTextBaselineSetterTriggersLayout() {
        let flex = RenderFlex(textBaseline: .alphabetic)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.textBaseline = .ideographic
        XCTAssertTrue(flex.needsLayout)
        XCTAssertEqual(flex.textBaseline, .ideographic)
    }

    /// Test that setting textBaseline to the same value is a no-op.
    func testTextBaselineSetterNoOp() {
        let flex = RenderFlex(textBaseline: .alphabetic)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.textBaseline = .alphabetic
        XCTAssertFalse(flex.needsLayout)
    }

    /// Test that setting clipBehavior triggers markNeedsPaint.
    func testClipBehaviorSetterTriggersPaint() {
        let flex = RenderFlex(clipBehavior: .none)
        layoutFlex(flex)
        flex.needsPaint = false

        flex.clipBehavior = .hardEdge
        XCTAssertTrue(flex.needsPaint)
        XCTAssertEqual(flex.clipBehavior, .hardEdge)
    }

    /// Test that setting clipBehavior to the same value is a no-op.
    func testClipBehaviorSetterNoOp() {
        let flex = RenderFlex(clipBehavior: .none)
        layoutFlex(flex)
        flex.needsPaint = false

        flex.clipBehavior = .none
        XCTAssertFalse(flex.needsPaint)
    }

    /// Test that setting spacing triggers markNeedsLayout.
    func testSpacingSetterTriggersLayout() {
        let flex = RenderFlex(spacing: 0.0)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.spacing = 10.0
        XCTAssertTrue(flex.needsLayout)
        XCTAssertEqual(flex.spacing, 10.0)
    }

    /// Test that setting spacing to the same value is a no-op.
    func testSpacingSetterNoOp() {
        let flex = RenderFlex(spacing: 10.0)
        layoutFlex(flex)
        XCTAssertFalse(flex.needsLayout)

        flex.spacing = 10.0
        XCTAssertFalse(flex.needsLayout)
    }
}

// MARK: - RenderFlex Horizontal Layout Tests

final class RenderFlexHorizontalLayoutTests: XCTestCase {

    /// Test horizontal layout with no children sizes to max.
    func testHorizontalLayoutNoChildren() {
        let flex = RenderFlex(direction: .horizontal, mainAxisSize: .max)
        layoutFlex(flex)
        XCTAssertEqual(flex.size.width, 800.0)
        XCTAssertEqual(flex.size.height, 0.0)
    }

    /// Test horizontal layout with fixed children.
    func testHorizontalLayoutFixedChildren() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 80)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .center
        )
        layoutFlex(flex)

        // Size: width = 800 (max), height = 80 (max of children cross axis)
        XCTAssertEqual(flex.size.width, 800.0)
        XCTAssertEqual(flex.size.height, 80.0)

        // child1 at (0, 15) centered: (80-50)/2 = 15
        let offset1 = childOffset(child1)
        XCTAssertEqual(offset1.dx, 0.0)
        XCTAssertEqual(offset1.dy, 15.0)

        // child2 at (100, 0) centered: (80-80)/2 = 0
        let offset2 = childOffset(child2)
        XCTAssertEqual(offset2.dx, 100.0)
        XCTAssertEqual(offset2.dy, 0.0)
    }

    /// Test horizontal layout with three children and default alignment.
    func testHorizontalLayoutThreeChildren() {
        let child1 = FixedSizeRenderBox(width: 100, height: 40)
        let child2 = FixedSizeRenderBox(width: 100, height: 60)
        let child3 = FixedSizeRenderBox(width: 100, height: 40)
        let flex = createFlex(
            children: [child1, child2, child3],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .center
        )
        layoutFlex(flex)

        XCTAssertEqual(flex.size.width, 800.0)
        XCTAssertEqual(flex.size.height, 60.0)

        // child1 at x=0, y=(60-40)/2 = 10
        XCTAssertEqual(childOffset(child1).dx, 0.0)
        XCTAssertEqual(childOffset(child1).dy, 10.0)

        // child2 at x=100, y=(60-60)/2 = 0
        XCTAssertEqual(childOffset(child2).dx, 100.0)
        XCTAssertEqual(childOffset(child2).dy, 0.0)

        // child3 at x=200, y=(60-40)/2 = 10
        XCTAssertEqual(childOffset(child3).dx, 200.0)
        XCTAssertEqual(childOffset(child3).dy, 10.0)
    }
}

// MARK: - RenderFlex Vertical Layout Tests

final class RenderFlexVerticalLayoutTests: XCTestCase {

    /// Test vertical layout with no children.
    func testVerticalLayoutNoChildren() {
        let flex = RenderFlex(direction: .vertical, mainAxisSize: .max)
        layoutFlex(flex)
        XCTAssertEqual(flex.size.width, 0.0)
        XCTAssertEqual(flex.size.height, 600.0)
    }

    /// Test vertical layout with fixed children.
    func testVerticalLayoutFixedChildren() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 80)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .center
        )
        layoutFlex(flex)

        // Size: width = 150 (max cross), height = 600 (max main)
        XCTAssertEqual(flex.size.width, 150.0)
        XCTAssertEqual(flex.size.height, 600.0)

        // child1 at (25, 0) centered: (150-100)/2 = 25
        let offset1 = childOffset(child1)
        XCTAssertEqual(offset1.dx, 25.0)
        XCTAssertEqual(offset1.dy, 0.0)

        // child2 at (0, 50) centered: (150-150)/2 = 0
        let offset2 = childOffset(child2)
        XCTAssertEqual(offset2.dx, 0.0)
        XCTAssertEqual(offset2.dy, 50.0)
    }

    /// Test vertical layout with three children.
    func testVerticalLayoutThreeChildren() {
        let child1 = FixedSizeRenderBox(width: 60, height: 100)
        let child2 = FixedSizeRenderBox(width: 80, height: 100)
        let child3 = FixedSizeRenderBox(width: 60, height: 100)
        let flex = createFlex(
            children: [child1, child2, child3],
            direction: .vertical,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .center
        )
        layoutFlex(flex)

        XCTAssertEqual(flex.size.width, 80.0)
        XCTAssertEqual(flex.size.height, 600.0)

        // child1 at x=(80-60)/2=10, y=0
        XCTAssertEqual(childOffset(child1).dx, 10.0)
        XCTAssertEqual(childOffset(child1).dy, 0.0)

        // child2 at x=0, y=100
        XCTAssertEqual(childOffset(child2).dx, 0.0)
        XCTAssertEqual(childOffset(child2).dy, 100.0)

        // child3 at x=10, y=200
        XCTAssertEqual(childOffset(child3).dx, 10.0)
        XCTAssertEqual(childOffset(child3).dy, 200.0)
    }
}

// MARK: - RenderFlex Flex Children Tests

final class RenderFlexFlexChildrenTests: XCTestCase {

    /// Helper to set up a flex child with given flex factor and fit.
    private func setFlexOnChild(_ child: RenderBox, flex: Int, fit: FlexFit = .tight) {
        let parentData = child.parentData as! FlexParentData
        parentData.flex = flex
        parentData.fit = fit
    }

    /// Test flex factor distribution with tight fit.
    func testFlexFactorDistributionTight() {
        let child1 = FixedSizeRenderBox(width: 0, height: 50)
        let child2 = FixedSizeRenderBox(width: 0, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max
        )
        setFlexOnChild(child1, flex: 1)
        setFlexOnChild(child2, flex: 2)

        layoutFlex(flex, constraints: BoxConstraints.tight(Size(300, 100)))

        // Total flex = 3, space = 300
        // child1 gets 100, child2 gets 200
        XCTAssertEqual(child1.size.width, 100.0, accuracy: 0.001)
        XCTAssertEqual(child2.size.width, 200.0, accuracy: 0.001)
    }

    /// Test flex factor distribution with loose fit.
    func testFlexFactorDistributionLoose() {
        let child1 = FixedSizeRenderBox(width: 50, height: 50)
        let child2 = FixedSizeRenderBox(width: 80, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max
        )
        setFlexOnChild(child1, flex: 1, fit: .loose)
        setFlexOnChild(child2, flex: 2, fit: .loose)

        layoutFlex(flex, constraints: BoxConstraints.tight(Size(300, 100)))

        // With loose fit, child sizes to its natural size constrained by max extent
        // child1 max extent = 100, but it prefers 50, so it gets 50
        // child2 max extent = 200, but it prefers 80, so it gets 80
        XCTAssertEqual(child1.size.width, 50.0)
        XCTAssertEqual(child2.size.width, 80.0)
    }

    /// Test mix of flex and non-flex children.
    func testMixedFlexAndNonFlex() {
        let fixed = FixedSizeRenderBox(width: 100, height: 50)
        let flexible = FixedSizeRenderBox(width: 0, height: 50)
        let flex = createFlex(
            children: [fixed, flexible],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max
        )
        setFlexOnChild(flexible, flex: 1)

        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        // fixed gets 100, flexible gets remaining 300
        XCTAssertEqual(fixed.size.width, 100.0)
        XCTAssertEqual(flexible.size.width, 300.0)

        // fixed at x=0, flexible at x=100
        XCTAssertEqual(childOffset(fixed).dx, 0.0)
        XCTAssertEqual(childOffset(flexible).dx, 100.0)
    }

    /// Test flex with equal flex factors.
    func testEqualFlexFactors() {
        let child1 = FixedSizeRenderBox(width: 0, height: 50)
        let child2 = FixedSizeRenderBox(width: 0, height: 50)
        let child3 = FixedSizeRenderBox(width: 0, height: 50)
        let flex = createFlex(
            children: [child1, child2, child3],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max
        )
        setFlexOnChild(child1, flex: 1)
        setFlexOnChild(child2, flex: 1)
        setFlexOnChild(child3, flex: 1)

        layoutFlex(flex, constraints: BoxConstraints.tight(Size(300, 100)))

        XCTAssertEqual(child1.size.width, 100.0, accuracy: 0.001)
        XCTAssertEqual(child2.size.width, 100.0, accuracy: 0.001)
        XCTAssertEqual(child3.size.width, 100.0, accuracy: 0.001)
    }

    /// Test vertical flex distribution.
    func testVerticalFlexDistribution() {
        let child1 = FixedSizeRenderBox(width: 50, height: 0)
        let child2 = FixedSizeRenderBox(width: 50, height: 0)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisAlignment: .start,
            mainAxisSize: .max
        )
        setFlexOnChild(child1, flex: 1)
        setFlexOnChild(child2, flex: 3)

        layoutFlex(flex, constraints: BoxConstraints.tight(Size(100, 400)))

        // Total flex = 4, space = 400
        // child1 gets 100, child2 gets 300
        XCTAssertEqual(child1.size.height, 100.0, accuracy: 0.001)
        XCTAssertEqual(child2.size.height, 300.0, accuracy: 0.001)
    }
}

// MARK: - MainAxisAlignment Layout Tests

final class MainAxisAlignmentLayoutTests: XCTestCase {

    /// Helper to create a horizontal flex with 2 children (100w each) in a 400-wide container.
    private func createFlexWithAlignment(_ alignment: MainAxisAlignment) -> (RenderFlex, RenderBox, RenderBox) {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: alignment,
            mainAxisSize: .max
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))
        return (flex, child1, child2)
    }

    /// Test MainAxisAlignment.start positions children at the start.
    func testMainAxisAlignmentStart() {
        let (_, child1, child2) = createFlexWithAlignment(.start)
        // freeSpace = 200, start => leading=0
        XCTAssertEqual(childOffset(child1).dx, 0.0)
        XCTAssertEqual(childOffset(child2).dx, 100.0)
    }

    /// Test MainAxisAlignment.end positions children at the end.
    func testMainAxisAlignmentEnd() {
        let (_, child1, child2) = createFlexWithAlignment(.end)
        // freeSpace = 200, end => leading=200
        XCTAssertEqual(childOffset(child1).dx, 200.0)
        XCTAssertEqual(childOffset(child2).dx, 300.0)
    }

    /// Test MainAxisAlignment.center positions children in the center.
    func testMainAxisAlignmentCenter() {
        let (_, child1, child2) = createFlexWithAlignment(.center)
        // freeSpace = 200, center => leading=100
        XCTAssertEqual(childOffset(child1).dx, 100.0)
        XCTAssertEqual(childOffset(child2).dx, 200.0)
    }

    /// Test MainAxisAlignment.spaceBetween distributes space between children.
    func testMainAxisAlignmentSpaceBetween() {
        let (_, child1, child2) = createFlexWithAlignment(.spaceBetween)
        // freeSpace = 200, spaceBetween => leading=0, between = 200/(2-1) = 200
        XCTAssertEqual(childOffset(child1).dx, 0.0)
        XCTAssertEqual(childOffset(child2).dx, 300.0)  // 0 + 100 + 200 = 300
    }

    /// Test MainAxisAlignment.spaceAround distributes space around children.
    func testMainAxisAlignmentSpaceAround() {
        let (_, child1, child2) = createFlexWithAlignment(.spaceAround)
        // freeSpace = 200, spaceAround => leading = 200/2/2 = 50, between = 200/2 = 100
        XCTAssertEqual(childOffset(child1).dx, 50.0)
        XCTAssertEqual(childOffset(child2).dx, 250.0)  // 50 + 100 + 100 = 250
    }

    /// Test MainAxisAlignment.spaceEvenly distributes space evenly.
    func testMainAxisAlignmentSpaceEvenly() {
        let (_, child1, child2) = createFlexWithAlignment(.spaceEvenly)
        // freeSpace = 200, spaceEvenly => leading = 200/3 = 66.667, between = 200/3 = 66.667
        let expectedLeading = 200.0 / 3.0
        let expectedBetween = 200.0 / 3.0
        XCTAssertEqual(childOffset(child1).dx, expectedLeading, accuracy: 0.001)
        XCTAssertEqual(childOffset(child2).dx, expectedLeading + 100.0 + expectedBetween, accuracy: 0.001)
    }
}

// MARK: - CrossAxisAlignment Layout Tests

final class CrossAxisAlignmentLayoutTests: XCTestCase {

    /// Test CrossAxisAlignment.start places children at the start of cross axis.
    func testCrossAxisAlignmentStart() {
        let child1 = FixedSizeRenderBox(width: 100, height: 30)
        let child2 = FixedSizeRenderBox(width: 100, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .start
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        // Cross axis = vertical, start => y = 0 for both
        XCTAssertEqual(childOffset(child1).dy, 0.0)
        XCTAssertEqual(childOffset(child2).dy, 0.0)
    }

    /// Test CrossAxisAlignment.end places children at the end of cross axis.
    func testCrossAxisAlignmentEnd() {
        let child1 = FixedSizeRenderBox(width: 100, height: 30)
        let child2 = FixedSizeRenderBox(width: 100, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .end
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        // With tight constraints, cross axis = 100
        // end => freeSpace = 100-30 = 70 for child1, 100-60 = 40 for child2
        XCTAssertEqual(childOffset(child1).dy, 70.0)
        XCTAssertEqual(childOffset(child2).dy, 40.0)
    }

    /// Test CrossAxisAlignment.center places children in center of cross axis.
    func testCrossAxisAlignmentCenter() {
        let child1 = FixedSizeRenderBox(width: 100, height: 30)
        let child2 = FixedSizeRenderBox(width: 100, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .center
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        // center => freeSpace / 2
        // child1: (100-30)/2 = 35
        // child2: (100-60)/2 = 20
        XCTAssertEqual(childOffset(child1).dy, 35.0)
        XCTAssertEqual(childOffset(child2).dy, 20.0)
    }

    /// Test CrossAxisAlignment.stretch forces children to fill cross axis.
    func testCrossAxisAlignmentStretch() {
        let child1 = FixedSizeRenderBox(width: 100, height: 30)
        let child2 = FixedSizeRenderBox(width: 100, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .stretch
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        // stretch => children are given tight height = 100
        XCTAssertEqual(child1.size.height, 100.0)
        XCTAssertEqual(child2.size.height, 100.0)
        XCTAssertEqual(childOffset(child1).dy, 0.0)
        XCTAssertEqual(childOffset(child2).dy, 0.0)
    }

    /// Test CrossAxisAlignment.start in vertical direction.
    func testCrossAxisAlignmentStartVertical() {
        let child1 = FixedSizeRenderBox(width: 60, height: 100)
        let child2 = FixedSizeRenderBox(width: 80, height: 100)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .start
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(200, 400)))

        // cross axis = horizontal, start => x = 0
        XCTAssertEqual(childOffset(child1).dx, 0.0)
        XCTAssertEqual(childOffset(child2).dx, 0.0)
    }

    /// Test CrossAxisAlignment.end in vertical direction.
    func testCrossAxisAlignmentEndVertical() {
        let child1 = FixedSizeRenderBox(width: 60, height: 100)
        let child2 = FixedSizeRenderBox(width: 80, height: 100)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .end
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(200, 400)))

        // cross axis = horizontal, end => freeSpace = 200-60 = 140 for child1
        XCTAssertEqual(childOffset(child1).dx, 140.0)
        XCTAssertEqual(childOffset(child2).dx, 120.0)  // 200-80 = 120
    }

    /// Test CrossAxisAlignment.stretch in vertical direction.
    func testCrossAxisAlignmentStretchVertical() {
        let child1 = FixedSizeRenderBox(width: 60, height: 100)
        let child2 = FixedSizeRenderBox(width: 80, height: 100)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .stretch
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(200, 400)))

        // stretch in vertical => tight width = 200
        XCTAssertEqual(child1.size.width, 200.0)
        XCTAssertEqual(child2.size.width, 200.0)
    }
}

// MARK: - MainAxisSize Tests

final class MainAxisSizeLayoutTests: XCTestCase {

    /// Test mainAxisSize.max: flex takes maximum available space on main axis.
    func testMainAxisSizeMax() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child],
            direction: .horizontal,
            mainAxisSize: .max
        )
        layoutFlex(flex, constraints: BoxConstraints(
            minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 300
        ))

        XCTAssertEqual(flex.size.width, 500.0)
    }

    /// Test mainAxisSize.min: flex takes minimum space needed for children.
    func testMainAxisSizeMin() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child],
            direction: .horizontal,
            mainAxisSize: .min
        )
        layoutFlex(flex, constraints: BoxConstraints(
            minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 300
        ))

        XCTAssertEqual(flex.size.width, 100.0)
    }

    /// Test mainAxisSize.min with multiple children.
    func testMainAxisSizeMinMultipleChildren() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisSize: .min
        )
        layoutFlex(flex, constraints: BoxConstraints(
            minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 300
        ))

        XCTAssertEqual(flex.size.width, 250.0)
    }

    /// Test mainAxisSize.max vertical.
    func testMainAxisSizeMaxVertical() {
        let child = FixedSizeRenderBox(width: 50, height: 100)
        let flex = createFlex(
            children: [child],
            direction: .vertical,
            mainAxisSize: .max
        )
        layoutFlex(flex, constraints: BoxConstraints(
            minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 500
        ))

        XCTAssertEqual(flex.size.height, 500.0)
    }

    /// Test mainAxisSize.min vertical.
    func testMainAxisSizeMinVertical() {
        let child = FixedSizeRenderBox(width: 50, height: 100)
        let flex = createFlex(
            children: [child],
            direction: .vertical,
            mainAxisSize: .min
        )
        layoutFlex(flex, constraints: BoxConstraints(
            minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 500
        ))

        XCTAssertEqual(flex.size.height, 100.0)
    }

    /// Test mainAxisSize.min respects minWidth constraint.
    func testMainAxisSizeMinRespectsMinConstraint() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let flex = createFlex(
            children: [child],
            direction: .horizontal,
            mainAxisSize: .min
        )
        layoutFlex(flex, constraints: BoxConstraints(
            minWidth: 200, maxWidth: 500, minHeight: 0, maxHeight: 300
        ))

        // Wants to be 50 (child size) but constrained to at least 200
        XCTAssertEqual(flex.size.width, 200.0)
    }
}

// MARK: - Spacing Tests

final class RenderFlexSpacingTests: XCTestCase {

    /// Test horizontal spacing between children.
    func testHorizontalSpacing() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let child3 = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child1, child2, child3],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            spacing: 20.0
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(500, 100)))

        XCTAssertEqual(childOffset(child1).dx, 0.0)
        XCTAssertEqual(childOffset(child2).dx, 120.0)  // 100 + 20
        XCTAssertEqual(childOffset(child3).dx, 240.0)  // 120 + 100 + 20
    }

    /// Test vertical spacing between children.
    func testVerticalSpacing() {
        let child1 = FixedSizeRenderBox(width: 50, height: 100)
        let child2 = FixedSizeRenderBox(width: 50, height: 100)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            spacing: 30.0
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(100, 500)))

        XCTAssertEqual(childOffset(child1).dy, 0.0)
        XCTAssertEqual(childOffset(child2).dy, 130.0)  // 100 + 30
    }

    /// Test spacing with mainAxisSize.min includes spacing in total size.
    func testSpacingWithMinMainAxisSize() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisSize: .min,
            spacing: 20.0
        )
        layoutFlex(flex, constraints: BoxConstraints(
            minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 300
        ))

        // min size = 100 + 20 + 100 = 220
        XCTAssertEqual(flex.size.width, 220.0)
    }

    /// Test spacing with single child has no effect on layout.
    func testSpacingWithSingleChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .min,
            spacing: 20.0
        )
        layoutFlex(flex, constraints: BoxConstraints(
            minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 300
        ))

        // Spacing is between children; with 1 child, spacing * (count-1) = 0
        XCTAssertEqual(flex.size.width, 100.0)
        XCTAssertEqual(childOffset(child).dx, 0.0)
    }
}

// MARK: - Intrinsic Dimension Tests

final class RenderFlexIntrinsicTests: XCTestCase {

    /// Test horizontal flex min intrinsic width sums children widths plus spacing.
    func testHorizontalMinIntrinsicWidth() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            spacing: 10.0
        )
        // For horizontal direction, min intrinsic width = sum of children min widths + spacing
        // = 100 + 150 + 10 = 260
        let result = flex.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(result, 260.0)
    }

    /// Test horizontal flex max intrinsic width sums children widths plus spacing.
    func testHorizontalMaxIntrinsicWidth() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            spacing: 10.0
        )
        let result = flex.computeMaxIntrinsicWidth(.infinity)
        XCTAssertEqual(result, 260.0)
    }

    /// Test horizontal flex min intrinsic height is max of children heights.
    func testHorizontalMinIntrinsicHeight() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal
        )
        let result = flex.computeMinIntrinsicHeight(.infinity)
        XCTAssertEqual(result, 60.0)
    }

    /// Test horizontal flex max intrinsic height is max of children heights.
    func testHorizontalMaxIntrinsicHeight() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal
        )
        let result = flex.computeMaxIntrinsicHeight(.infinity)
        XCTAssertEqual(result, 60.0)
    }

    /// Test vertical flex min intrinsic height sums children heights plus spacing.
    func testVerticalMinIntrinsicHeight() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            spacing: 5.0
        )
        // Main axis = vertical, min intrinsic height = 50 + 60 + 5 = 115
        let result = flex.computeMinIntrinsicHeight(.infinity)
        XCTAssertEqual(result, 115.0)
    }

    /// Test vertical flex min intrinsic width is max of children widths.
    func testVerticalMinIntrinsicWidth() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 60)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical
        )
        let result = flex.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(result, 150.0)
    }

    /// Test intrinsic dimensions with single child returns child size (no spacing added).
    func testIntrinsicDimensionsSingleChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child],
            direction: .horizontal,
            spacing: 10.0
        )
        // inflexibleSpace = 10 * (1-1) = 0, plus child width = 100
        let result = flex.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(result, 100.0)
    }
}

// MARK: - Overflow Detection Tests

final class RenderFlexOverflowTests: XCTestCase {

    /// Test no overflow when children fit.
    func testNoOverflow() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisSize: .max
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))
        XCTAssertFalse(flex._hasOverflow)
        XCTAssertEqual(flex._overflow, 0.0)
    }

    /// Test overflow detected when children exceed container.
    func testOverflowDetected() {
        let child1 = FixedSizeRenderBox(width: 300, height: 50)
        let child2 = FixedSizeRenderBox(width: 300, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisSize: .max
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        // Children total = 600, container = 400, overflow = 200
        XCTAssertTrue(flex._hasOverflow)
        XCTAssertEqual(flex._overflow, 200.0)
    }

    /// Test vertical overflow.
    func testVerticalOverflow() {
        let child1 = FixedSizeRenderBox(width: 50, height: 300)
        let child2 = FixedSizeRenderBox(width: 50, height: 400)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisSize: .max
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(100, 500)))

        // Children total = 700, container = 500, overflow = 200
        XCTAssertTrue(flex._hasOverflow)
        XCTAssertEqual(flex._overflow, 200.0)
    }

    /// Test overflow with spacing.
    func testOverflowWithSpacing() {
        let child1 = FixedSizeRenderBox(width: 200, height: 50)
        let child2 = FixedSizeRenderBox(width: 200, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisSize: .max,
            spacing: 50.0
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        // Children total = 200 + 200 + 50 (spacing) = 450, container = 400, overflow = 50
        XCTAssertTrue(flex._hasOverflow)
        XCTAssertEqual(flex._overflow, 50.0)
    }

    /// Test no overflow when exactly fitting.
    func testNoOverflowExactFit() {
        let child1 = FixedSizeRenderBox(width: 200, height: 50)
        let child2 = FixedSizeRenderBox(width: 200, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisSize: .max
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        XCTAssertFalse(flex._hasOverflow)
    }
}

// MARK: - Direction and TextDirection Tests

final class RenderFlexDirectionTests: XCTestCase {

    /// Test horizontal + RTL layout reverses child order.
    func testHorizontalRTL() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            textDirection: .rtl
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        // RTL flips the main axis: _flipMainAxis = true
        // .start with flipped=true => leadingSpace = freeSpace = 200
        // Visual order: starts from lastChild going backward
        // topLeftChild = lastChild = child2 (since addChildrenInOrder sets child2 as last)
        // child2 at x=200, child1 at x=200+100+0=300
        XCTAssertEqual(childOffset(child2).dx, 200.0)
        XCTAssertEqual(childOffset(child1).dx, 300.0)
    }

    /// Test horizontal + LTR (default) for comparison.
    func testHorizontalLTR() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            textDirection: .ltr
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        XCTAssertEqual(childOffset(child1).dx, 0.0)
        XCTAssertEqual(childOffset(child2).dx, 100.0)
    }

    /// Test vertical + up reverses child order.
    func testVerticalUp() {
        let child1 = FixedSizeRenderBox(width: 50, height: 100)
        let child2 = FixedSizeRenderBox(width: 50, height: 100)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            verticalDirection: .up
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(100, 400)))

        // verticalDirection.up => _flipMainAxis = true
        // .start with flipped=true => leadingSpace = freeSpace = 200
        // Visual order: starts from lastChild (child2)
        // child2 at y=200, child1 at y=200+100+0=300
        XCTAssertEqual(childOffset(child2).dy, 200.0)
        XCTAssertEqual(childOffset(child1).dy, 300.0)
    }

    /// Test vertical + down (default).
    func testVerticalDown() {
        let child1 = FixedSizeRenderBox(width: 50, height: 100)
        let child2 = FixedSizeRenderBox(width: 50, height: 100)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            verticalDirection: .down
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(100, 400)))

        XCTAssertEqual(childOffset(child1).dy, 0.0)
        XCTAssertEqual(childOffset(child2).dy, 100.0)
    }

    /// Test horizontal with RTL + verticalDirection.up affects cross axis.
    func testHorizontalRTLCrossStart() {
        let child = FixedSizeRenderBox(width: 100, height: 30)
        let flex = createFlex(
            children: [child],
            direction: .horizontal,
            mainAxisAlignment: .start,
            mainAxisSize: .max,
            crossAxisAlignment: .start,
            textDirection: .rtl,
            verticalDirection: .up
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(400, 100)))

        // vertical direction = up => _flipCrossAxis = true (for horizontal direction)
        // crossAxisAlignment.start with flipCross = true => freeSpace (100-30=70)
        XCTAssertEqual(childOffset(child).dy, 70.0)
    }

    /// Test _flipMainAxis with no children returns false.
    func testFlipMainAxisNoChildren() {
        let flex = RenderFlex(direction: .horizontal, textDirection: .rtl)
        XCTAssertFalse(flex._flipMainAxis)
    }

    /// Test _flipCrossAxis with no children returns false.
    func testFlipCrossAxisNoChildren() {
        let flex = RenderFlex(direction: .horizontal, verticalDirection: .up)
        XCTAssertFalse(flex._flipCrossAxis)
    }
}

// MARK: - DryLayout Tests

final class RenderFlexDryLayoutTests: XCTestCase {

    /// Test computeDryLayout horizontal with fixed children.
    func testDryLayoutHorizontal() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 80)
        let flex = createFlex(
            children: [child1, child2],
            direction: .horizontal,
            mainAxisSize: .max
        )
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 800, minHeight: 0, maxHeight: 600
        )
        let size = flex.computeDryLayout(constraints)

        // main axis (width) = max = 800, cross axis (height) = max(50, 80) = 80
        XCTAssertEqual(size.width, 800.0)
        XCTAssertEqual(size.height, 80.0)
    }

    /// Test computeDryLayout vertical.
    func testDryLayoutVertical() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 150, height: 80)
        let flex = createFlex(
            children: [child1, child2],
            direction: .vertical,
            mainAxisSize: .max
        )
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 800, minHeight: 0, maxHeight: 600
        )
        let size = flex.computeDryLayout(constraints)

        // main axis (height) = max = 600, cross axis (width) = max(100, 150) = 150
        XCTAssertEqual(size.width, 150.0)
        XCTAssertEqual(size.height, 600.0)
    }

    /// Test computeDryLayout with mainAxisSize.min.
    func testDryLayoutMainAxisMin() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let flex = createFlex(
            children: [child],
            direction: .horizontal,
            mainAxisSize: .min
        )
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 800, minHeight: 0, maxHeight: 600
        )
        let size = flex.computeDryLayout(constraints)

        XCTAssertEqual(size.width, 100.0)
        XCTAssertEqual(size.height, 50.0)
    }

    /// Test computeDryLayout with no children.
    func testDryLayoutNoChildren() {
        let flex = RenderFlex(direction: .horizontal, mainAxisSize: .max)
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 800, minHeight: 0, maxHeight: 600
        )
        let size = flex.computeDryLayout(constraints)

        XCTAssertEqual(size.width, 800.0)
        XCTAssertEqual(size.height, 0.0)
    }
}

// MARK: - Internal Helper Tests

final class FlexAxisSizeTests: XCTestCase {

    /// Test FlexAxisSize.empty.
    func testEmpty() {
        let empty = FlexAxisSize.empty
        XCTAssertEqual(empty.mainAxisExtent, 0.0)
        XCTAssertEqual(empty.crossAxisExtent, 0.0)
    }

    /// Test FlexAxisSize initialization from Size for horizontal direction.
    func testInitFromSizeHorizontal() {
        let size = Size(100, 50)
        let axisSize = FlexAxisSize(from: size, direction: .horizontal)
        XCTAssertEqual(axisSize.mainAxisExtent, 100.0)  // width
        XCTAssertEqual(axisSize.crossAxisExtent, 50.0)   // height
    }

    /// Test FlexAxisSize initialization from Size for vertical direction.
    func testInitFromSizeVertical() {
        let size = Size(100, 50)
        let axisSize = FlexAxisSize(from: size, direction: .vertical)
        XCTAssertEqual(axisSize.mainAxisExtent, 50.0)   // height (flipped)
        XCTAssertEqual(axisSize.crossAxisExtent, 100.0)  // width (flipped)
    }

    /// Test FlexAxisSize.toSize for horizontal direction.
    func testToSizeHorizontal() {
        let axisSize = FlexAxisSize(mainAxisExtent: 200, crossAxisExtent: 100)
        let size = axisSize.toSize(.horizontal)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 100.0)
    }

    /// Test FlexAxisSize.toSize for vertical direction.
    func testToSizeVertical() {
        let axisSize = FlexAxisSize(mainAxisExtent: 200, crossAxisExtent: 100)
        let size = axisSize.toSize(.vertical)
        XCTAssertEqual(size.width, 100.0)
        XCTAssertEqual(size.height, 200.0)
    }

    /// Test FlexAxisSize addition sums main and maxes cross.
    func testAddition() {
        let a = FlexAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        let b = FlexAxisSize(mainAxisExtent: 150, crossAxisExtent: 80)
        let result = a + b
        XCTAssertEqual(result.mainAxisExtent, 250.0)
        XCTAssertEqual(result.crossAxisExtent, 80.0)
    }

    /// Test FlexAxisSize equality.
    func testEquality() {
        let a = FlexAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        let b = FlexAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        let c = FlexAxisSize(mainAxisExtent: 100, crossAxisExtent: 60)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - AscentDescent Tests

final class AscentDescentTests: XCTestCase {

    /// Test AscentDescent.none has no baseline offset.
    func testNone() {
        let ad = AscentDescent.none
        XCTAssertNil(ad.baselineOffset)
        XCTAssertNil(ad.ascentDescent)
    }

    /// Test AscentDescent with valid baseline offset.
    func testWithBaseline() {
        let ad = AscentDescent(baselineOffset: 20, crossSize: 30)
        XCTAssertEqual(ad.baselineOffset, 20.0)
        XCTAssertNotNil(ad.ascentDescent)
        XCTAssertEqual(ad.ascentDescent?.ascent, 20.0)
        XCTAssertEqual(ad.ascentDescent?.descent, 10.0)  // 30 - 20
    }

    /// Test AscentDescent with nil baseline offset.
    func testWithNilBaseline() {
        let ad = AscentDescent(baselineOffset: nil, crossSize: 30)
        XCTAssertNil(ad.baselineOffset)
        XCTAssertNil(ad.ascentDescent)
    }

    /// Test AscentDescent addition with both having values.
    func testAdditionBothPresent() {
        let a = AscentDescent(baselineOffset: 20, crossSize: 30)
        let b = AscentDescent(baselineOffset: 25, crossSize: 35)
        let result = a + b
        XCTAssertEqual(result.ascentDescent?.ascent, 25.0)   // max(20, 25)
        XCTAssertEqual(result.ascentDescent?.descent, 10.0)  // max(10, 10)
    }

    /// Test AscentDescent addition with left nil returns right.
    func testAdditionLeftNil() {
        let a = AscentDescent.none
        let b = AscentDescent(baselineOffset: 20, crossSize: 30)
        let result = a + b
        XCTAssertEqual(result.baselineOffset, 20.0)
    }

    /// Test AscentDescent addition with right nil returns left.
    func testAdditionRightNil() {
        let a = AscentDescent(baselineOffset: 20, crossSize: 30)
        let b = AscentDescent.none
        let result = a + b
        XCTAssertEqual(result.baselineOffset, 20.0)
    }

    /// Test AscentDescent addition with both nil returns none.
    func testAdditionBothNil() {
        let result = AscentDescent.none + AscentDescent.none
        XCTAssertNil(result.baselineOffset)
    }
}

// MARK: - RenderFlex Helper Method Tests

final class RenderFlexHelperMethodTests: XCTestCase {

    /// Test _getMainSize for horizontal direction returns width.
    func testGetMainSizeHorizontal() {
        let flex = RenderFlex(direction: .horizontal)
        XCTAssertEqual(flex._getMainSize(Size(100, 50)), 100.0)
    }

    /// Test _getMainSize for vertical direction returns height.
    func testGetMainSizeVertical() {
        let flex = RenderFlex(direction: .vertical)
        XCTAssertEqual(flex._getMainSize(Size(100, 50)), 50.0)
    }

    /// Test _getCrossSize for horizontal direction returns height.
    func testGetCrossSizeHorizontal() {
        let flex = RenderFlex(direction: .horizontal)
        XCTAssertEqual(flex._getCrossSize(Size(100, 50)), 50.0)
    }

    /// Test _getCrossSize for vertical direction returns width.
    func testGetCrossSizeVertical() {
        let flex = RenderFlex(direction: .vertical)
        XCTAssertEqual(flex._getCrossSize(Size(100, 50)), 100.0)
    }

    /// Test _getFlex returns 0 for inflexible child.
    func testGetFlexInflexible() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let _ = createFlex(children: [child])
        XCTAssertEqual(RenderFlex._getFlex(child), 0)
    }

    /// Test _getFlex returns the flex value when set.
    func testGetFlexWithValue() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let _ = createFlex(children: [child])
        let parentData = child.parentData as! FlexParentData
        parentData.flex = 3
        XCTAssertEqual(RenderFlex._getFlex(child), 3)
    }

    /// Test _getFit returns .tight by default.
    func testGetFitDefault() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let _ = createFlex(children: [child])
        XCTAssertEqual(RenderFlex._getFit(child), .tight)
    }

    /// Test _getFit returns the set fit value.
    func testGetFitWithValue() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let _ = createFlex(children: [child])
        let parentData = child.parentData as! FlexParentData
        parentData.fit = .loose
        XCTAssertEqual(RenderFlex._getFit(child), .loose)
    }

    /// Test _isBaselineAligned returns true for horizontal + baseline.
    func testIsBaselineAlignedHorizontalBaseline() {
        let flex = RenderFlex(direction: .horizontal, crossAxisAlignment: .baseline)
        XCTAssertTrue(flex._isBaselineAligned)
    }

    /// Test _isBaselineAligned returns false for vertical + baseline.
    func testIsBaselineAlignedVerticalBaseline() {
        let flex = RenderFlex(direction: .vertical, crossAxisAlignment: .baseline)
        XCTAssertFalse(flex._isBaselineAligned)
    }

    /// Test _isBaselineAligned returns false for non-baseline alignments.
    func testIsBaselineAlignedNonBaseline() {
        let flex = RenderFlex(direction: .horizontal, crossAxisAlignment: .center)
        XCTAssertFalse(flex._isBaselineAligned)
    }
}

// MARK: - RenderFlex Constraints Helpers Tests

final class RenderFlexConstraintsHelpersTests: XCTestCase {

    /// Test _constraintsForNonFlexChild horizontal without stretch.
    func testNonFlexConstraintsHorizontalNoStretch() {
        let flex = RenderFlex(direction: .horizontal, crossAxisAlignment: .center)
        let parentConstraints = BoxConstraints(
            minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 200
        )
        let childConstraints = flex._constraintsForNonFlexChild(parentConstraints)

        // horizontal, no stretch: BoxConstraints(maxHeight: 200)
        XCTAssertEqual(childConstraints.minWidth, 0.0)
        XCTAssertEqual(childConstraints.maxWidth, .infinity)
        XCTAssertEqual(childConstraints.minHeight, 0.0)
        XCTAssertEqual(childConstraints.maxHeight, 200.0)
    }

    /// Test _constraintsForNonFlexChild horizontal with stretch.
    func testNonFlexConstraintsHorizontalStretch() {
        let flex = RenderFlex(direction: .horizontal, crossAxisAlignment: .stretch)
        let parentConstraints = BoxConstraints(
            minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 200
        )
        let childConstraints = flex._constraintsForNonFlexChild(parentConstraints)

        // horizontal, stretch: BoxConstraints.tightFor(height: 200)
        XCTAssertEqual(childConstraints.minHeight, 200.0)
        XCTAssertEqual(childConstraints.maxHeight, 200.0)
    }

    /// Test _constraintsForNonFlexChild vertical without stretch.
    func testNonFlexConstraintsVerticalNoStretch() {
        let flex = RenderFlex(direction: .vertical, crossAxisAlignment: .center)
        let parentConstraints = BoxConstraints(
            minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 200
        )
        let childConstraints = flex._constraintsForNonFlexChild(parentConstraints)

        // vertical, no stretch: BoxConstraints(maxWidth: 400)
        XCTAssertEqual(childConstraints.minWidth, 0.0)
        XCTAssertEqual(childConstraints.maxWidth, 400.0)
        XCTAssertEqual(childConstraints.minHeight, 0.0)
        XCTAssertEqual(childConstraints.maxHeight, .infinity)
    }

    /// Test _constraintsForNonFlexChild vertical with stretch.
    func testNonFlexConstraintsVerticalStretch() {
        let flex = RenderFlex(direction: .vertical, crossAxisAlignment: .stretch)
        let parentConstraints = BoxConstraints(
            minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 200
        )
        let childConstraints = flex._constraintsForNonFlexChild(parentConstraints)

        // vertical, stretch: BoxConstraints.tightFor(width: 400)
        XCTAssertEqual(childConstraints.minWidth, 400.0)
        XCTAssertEqual(childConstraints.maxWidth, 400.0)
    }

    /// Test _constraintsForFlexChild with tight fit horizontal.
    func testFlexConstraintsTightHorizontal() {
        let child = FixedSizeRenderBox(width: 0, height: 50)
        let flex = createFlex(children: [child], direction: .horizontal, crossAxisAlignment: .center)
        let parentData = child.parentData as! FlexParentData
        parentData.flex = 1
        parentData.fit = .tight

        let parentConstraints = BoxConstraints(
            minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 200
        )
        let childConstraints = flex._constraintsForFlexChild(child, parentConstraints, 150.0)

        // tight: minWidth = maxChildExtent = 150, maxWidth = 150
        XCTAssertEqual(childConstraints.minWidth, 150.0)
        XCTAssertEqual(childConstraints.maxWidth, 150.0)
        XCTAssertEqual(childConstraints.minHeight, 0.0)
        XCTAssertEqual(childConstraints.maxHeight, 200.0)
    }

    /// Test _constraintsForFlexChild with loose fit horizontal.
    func testFlexConstraintsLooseHorizontal() {
        let child = FixedSizeRenderBox(width: 0, height: 50)
        let flex = createFlex(children: [child], direction: .horizontal, crossAxisAlignment: .center)
        let parentData = child.parentData as! FlexParentData
        parentData.flex = 1
        parentData.fit = .loose

        let parentConstraints = BoxConstraints(
            minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 200
        )
        let childConstraints = flex._constraintsForFlexChild(child, parentConstraints, 150.0)

        // loose: minWidth = 0, maxWidth = 150
        XCTAssertEqual(childConstraints.minWidth, 0.0)
        XCTAssertEqual(childConstraints.maxWidth, 150.0)
    }

    /// Test _constraintsForFlexChild vertical with stretch.
    func testFlexConstraintsVerticalStretch() {
        let child = FixedSizeRenderBox(width: 50, height: 0)
        let flex = createFlex(children: [child], direction: .vertical, crossAxisAlignment: .stretch)
        let parentData = child.parentData as! FlexParentData
        parentData.flex = 1
        parentData.fit = .tight

        let parentConstraints = BoxConstraints(
            minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 200
        )
        let childConstraints = flex._constraintsForFlexChild(child, parentConstraints, 100.0)

        // vertical, tight, stretch:
        // minWidth = maxWidth = 400 (stretch), minHeight = maxHeight = 100 (tight)
        XCTAssertEqual(childConstraints.minWidth, 400.0)
        XCTAssertEqual(childConstraints.maxWidth, 400.0)
        XCTAssertEqual(childConstraints.minHeight, 100.0)
        XCTAssertEqual(childConstraints.maxHeight, 100.0)
    }
}

// MARK: - Dispose Tests

final class RenderFlexDisposeTests: XCTestCase {

    /// Test dispose does not crash.
    func testDisposeDoesNotCrash() {
        let flex = createFlex(
            children: [FixedSizeRenderBox(width: 50, height: 50)],
            direction: .horizontal
        )
        layoutFlex(flex, constraints: BoxConstraints.tight(Size(200, 100)))
        flex.dispose()
    }
}

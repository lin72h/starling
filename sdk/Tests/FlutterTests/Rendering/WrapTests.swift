// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Wrap layout types from the Rendering layer.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/wrap_test.dart`

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A concrete RenderBox subclass that implements performLayout by sizing
/// itself to a fixed size constrained by the parent constraints.
/// Used as a child of RenderWrap in tests.
private class TestRenderBox: RenderBox {
    let fixedSize: Size
    init(size: Size = Size(100, 100)) {
        self.fixedSize = size
        super.init()
    }
    override func performLayout() {
        size = boxConstraints.constrain(fixedSize)
    }
    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        constraints.constrain(fixedSize)
    }
    override func computeMinIntrinsicWidth(_ height: Double) -> Double {
        return fixedSize.width
    }
    override func computeMaxIntrinsicWidth(_ height: Double) -> Double {
        return fixedSize.width
    }
    override func computeMinIntrinsicHeight(_ width: Double) -> Double {
        return fixedSize.height
    }
    override func computeMaxIntrinsicHeight(_ width: Double) -> Double {
        return fixedSize.height
    }
}

// MARK: - WrapAlignment Enum Tests

final class WrapAlignmentEnumTests: XCTestCase {

    /// Test that all 6 cases exist.
    func testAllCasesExist() {
        let start = WrapAlignment.start
        let end = WrapAlignment.end
        let center = WrapAlignment.center
        let spaceBetween = WrapAlignment.spaceBetween
        let spaceAround = WrapAlignment.spaceAround
        let spaceEvenly = WrapAlignment.spaceEvenly
        XCTAssertNotNil(start)
        XCTAssertNotNil(end)
        XCTAssertNotNil(center)
        XCTAssertNotNil(spaceBetween)
        XCTAssertNotNil(spaceAround)
        XCTAssertNotNil(spaceEvenly)
    }

    /// Test distributeSpace for .start (not flipped).
    func testDistributeSpaceStart() {
        let (leading, between) = WrapAlignment.start.distributeSpace(
            freeSpace: 100,
            itemSpacing: 10,
            itemCount: 3,
            flipped: false
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 10.0)
    }

    /// Test distributeSpace for .start (flipped).
    func testDistributeSpaceStartFlipped() {
        let (leading, between) = WrapAlignment.start.distributeSpace(
            freeSpace: 100,
            itemSpacing: 10,
            itemCount: 3,
            flipped: true
        )
        XCTAssertEqual(leading, 100.0)
        XCTAssertEqual(between, 10.0)
    }

    /// Test distributeSpace for .end (not flipped) is same as .start flipped.
    func testDistributeSpaceEnd() {
        let (leading, between) = WrapAlignment.end.distributeSpace(
            freeSpace: 100,
            itemSpacing: 10,
            itemCount: 3,
            flipped: false
        )
        XCTAssertEqual(leading, 100.0)
        XCTAssertEqual(between, 10.0)
    }

    /// Test distributeSpace for .end (flipped) is same as .start not flipped.
    func testDistributeSpaceEndFlipped() {
        let (leading, between) = WrapAlignment.end.distributeSpace(
            freeSpace: 100,
            itemSpacing: 10,
            itemCount: 3,
            flipped: true
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 10.0)
    }

    /// Test distributeSpace for .center.
    func testDistributeSpaceCenter() {
        let (leading, between) = WrapAlignment.center.distributeSpace(
            freeSpace: 100,
            itemSpacing: 10,
            itemCount: 3,
            flipped: false
        )
        XCTAssertEqual(leading, 50.0)
        XCTAssertEqual(between, 10.0)
    }

    /// Test distributeSpace for .spaceBetween with multiple items.
    func testDistributeSpaceSpaceBetween() {
        let (leading, between) = WrapAlignment.spaceBetween.distributeSpace(
            freeSpace: 100,
            itemSpacing: 10,
            itemCount: 3,
            flipped: false
        )
        XCTAssertEqual(leading, 0.0)
        // between = freeSpace / (count - 1) + spacing = 100/2 + 10 = 60
        XCTAssertEqual(between, 60.0)
    }

    /// Test distributeSpace for .spaceBetween with single item falls back to .start.
    func testDistributeSpaceSpaceBetweenSingleItem() {
        let (leading, between) = WrapAlignment.spaceBetween.distributeSpace(
            freeSpace: 100,
            itemSpacing: 10,
            itemCount: 1,
            flipped: false
        )
        XCTAssertEqual(leading, 0.0)
        XCTAssertEqual(between, 10.0)
    }

    /// Test distributeSpace for .spaceAround.
    func testDistributeSpaceSpaceAround() {
        let (leading, between) = WrapAlignment.spaceAround.distributeSpace(
            freeSpace: 120,
            itemSpacing: 0,
            itemCount: 3,
            flipped: false
        )
        XCTAssertEqual(leading, 20.0)
        XCTAssertEqual(between, 40.0)
    }

    /// Test distributeSpace for .spaceEvenly.
    func testDistributeSpaceSpaceEvenly() {
        let (leading, between) = WrapAlignment.spaceEvenly.distributeSpace(
            freeSpace: 120,
            itemSpacing: 0,
            itemCount: 3,
            flipped: false
        )
        XCTAssertEqual(leading, 30.0)
        XCTAssertEqual(between, 30.0)
    }

    /// Test distributeSpace for .spaceEvenly with spacing.
    func testDistributeSpaceSpaceEvenlyWithSpacing() {
        let (leading, between) = WrapAlignment.spaceEvenly.distributeSpace(
            freeSpace: 80,
            itemSpacing: 5,
            itemCount: 2,
            flipped: false
        )
        XCTAssertEqual(leading, 80.0 / 3.0, accuracy: 1e-10)
        XCTAssertEqual(between, 80.0 / 3.0 + 5, accuracy: 1e-10)
    }
}

// MARK: - WrapCrossAlignment Enum Tests

final class WrapCrossAlignmentEnumTests: XCTestCase {

    /// Test that all 3 cases exist.
    func testAllCasesExist() {
        let start = WrapCrossAlignment.start
        let end = WrapCrossAlignment.end
        let center = WrapCrossAlignment.center
        XCTAssertNotNil(start)
        XCTAssertNotNil(end)
        XCTAssertNotNil(center)
    }

    /// Test flipped property: start <-> end, center stays.
    func testFlippedStartBecomesEnd() {
        XCTAssertEqual(WrapCrossAlignment.start.flipped, .end)
    }

    func testFlippedEndBecomesStart() {
        XCTAssertEqual(WrapCrossAlignment.end.flipped, .start)
    }

    func testFlippedCenterStaysCenter() {
        XCTAssertEqual(WrapCrossAlignment.center.flipped, .center)
    }

    /// Test alignment property values.
    func testAlignmentValues() {
        XCTAssertEqual(WrapCrossAlignment.start.alignment, 0.0)
        XCTAssertEqual(WrapCrossAlignment.center.alignment, 0.5)
        XCTAssertEqual(WrapCrossAlignment.end.alignment, 1.0)
    }
}

// MARK: - WrapAxisSize Struct Tests

final class WrapAxisSizeTests: XCTestCase {

    /// Test basic construction.
    func testConstruction() {
        let axisSize = WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        XCTAssertEqual(axisSize.mainAxisExtent, 100.0)
        XCTAssertEqual(axisSize.crossAxisExtent, 50.0)
    }

    /// Test empty constant.
    func testEmptyConstant() {
        let empty = WrapAxisSize.empty
        XCTAssertEqual(empty.mainAxisExtent, 0.0)
        XCTAssertEqual(empty.crossAxisExtent, 0.0)
    }

    /// Test init(from:direction:) for horizontal direction.
    func testInitFromSizeHorizontal() {
        let size = Size(200, 100)
        let axisSize = WrapAxisSize(from: size, direction: .horizontal)
        XCTAssertEqual(axisSize.mainAxisExtent, 200.0)
        XCTAssertEqual(axisSize.crossAxisExtent, 100.0)
    }

    /// Test init(from:direction:) for vertical direction.
    func testInitFromSizeVertical() {
        let size = Size(200, 100)
        let axisSize = WrapAxisSize(from: size, direction: .vertical)
        XCTAssertEqual(axisSize.mainAxisExtent, 100.0)
        XCTAssertEqual(axisSize.crossAxisExtent, 200.0)
    }

    /// Test toSize for horizontal direction.
    func testToSizeHorizontal() {
        let axisSize = WrapAxisSize(mainAxisExtent: 200, crossAxisExtent: 100)
        let size = axisSize.toSize(.horizontal)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 100.0)
    }

    /// Test toSize for vertical direction.
    func testToSizeVertical() {
        let axisSize = WrapAxisSize(mainAxisExtent: 200, crossAxisExtent: 100)
        let size = axisSize.toSize(.vertical)
        XCTAssertEqual(size.width, 100.0)
        XCTAssertEqual(size.height, 200.0)
    }

    /// Test + operator: sums mainAxis, takes max of crossAxis.
    func testAddOperator() {
        let a = WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        let b = WrapAxisSize(mainAxisExtent: 80, crossAxisExtent: 60)
        let result = a + b
        XCTAssertEqual(result.mainAxisExtent, 180.0)
        XCTAssertEqual(result.crossAxisExtent, 60.0)
    }

    /// Test - operator: subtracts component-wise.
    func testSubtractOperator() {
        let a = WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        let b = WrapAxisSize(mainAxisExtent: 30, crossAxisExtent: 20)
        let result = a - b
        XCTAssertEqual(result.mainAxisExtent, 70.0)
        XCTAssertEqual(result.crossAxisExtent, 30.0)
    }

    /// Test flipped property swaps axes.
    func testFlipped() {
        let axisSize = WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        let flipped = axisSize.flipped
        XCTAssertEqual(flipped.mainAxisExtent, 50.0)
        XCTAssertEqual(flipped.crossAxisExtent, 100.0)
    }

    /// Test Equatable conformance.
    func testEquatable() {
        let a = WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        let b = WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        let c = WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 60)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// Test applyConstraints for horizontal direction.
    func testApplyConstraintsHorizontal() {
        let axisSize = WrapAxisSize(mainAxisExtent: 500, crossAxisExtent: 300)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 150)
        let constrained = axisSize.applyConstraints(constraints, direction: .horizontal)
        XCTAssertEqual(constrained.mainAxisExtent, 200.0)
        XCTAssertEqual(constrained.crossAxisExtent, 150.0)
    }

    /// Test applyConstraints for vertical direction.
    func testApplyConstraintsVertical() {
        let axisSize = WrapAxisSize(mainAxisExtent: 500, crossAxisExtent: 300)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 150)
        let constrained = axisSize.applyConstraints(constraints, direction: .vertical)
        XCTAssertEqual(constrained.mainAxisExtent, 150.0)
        XCTAssertEqual(constrained.crossAxisExtent, 200.0)
    }

    /// Test applyConstraints where values are within bounds.
    func testApplyConstraintsWithinBounds() {
        let axisSize = WrapAxisSize(mainAxisExtent: 50, crossAxisExtent: 30)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 150)
        let constrained = axisSize.applyConstraints(constraints, direction: .horizontal)
        XCTAssertEqual(constrained.mainAxisExtent, 50.0)
        XCTAssertEqual(constrained.crossAxisExtent, 30.0)
    }
}

// MARK: - WrapRunMetrics Struct Tests

final class WrapRunMetricsTests: XCTestCase {

    /// Test construction with leadingChild and axisSize.
    func testConstruction() {
        let child = TestRenderBox()
        let axisSize = WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        let run = WrapRunMetrics(leadingChild: child, axisSize: axisSize)
        XCTAssertTrue(run.leadingChild === child)
        XCTAssertEqual(run.axisSize, axisSize)
        XCTAssertEqual(run.childCount, 1)
    }

    /// Test mainAxisExtent computed property.
    func testMainAxisExtent() {
        let child = TestRenderBox()
        let run = WrapRunMetrics(
            leadingChild: child,
            axisSize: WrapAxisSize(mainAxisExtent: 120, crossAxisExtent: 40)
        )
        XCTAssertEqual(run.mainAxisExtent, 120.0)
    }

    /// Test crossAxisExtent computed property.
    func testCrossAxisExtent() {
        let child = TestRenderBox()
        let run = WrapRunMetrics(
            leadingChild: child,
            axisSize: WrapAxisSize(mainAxisExtent: 120, crossAxisExtent: 40)
        )
        XCTAssertEqual(run.crossAxisExtent, 40.0)
    }

    /// Test tryAddingNewChild when the child fits in the current run.
    func testTryAddingNewChildFits() {
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        var run = WrapRunMetrics(
            leadingChild: child1,
            axisSize: WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        )
        let childSize = WrapAxisSize(mainAxisExtent: 80, crossAxisExtent: 60)
        let newRun = run.tryAddingNewChild(
            child2,
            childSize: childSize,
            flipMainAxis: false,
            spacing: 10,
            maxMainExtent: 300
        )
        XCTAssertNil(newRun)
        XCTAssertEqual(run.childCount, 2)
        XCTAssertEqual(run.mainAxisExtent, 190.0)
        XCTAssertEqual(run.crossAxisExtent, 60.0)
    }

    /// Test tryAddingNewChild when the child does not fit (starts new run).
    func testTryAddingNewChildDoesNotFit() {
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        var run = WrapRunMetrics(
            leadingChild: child1,
            axisSize: WrapAxisSize(mainAxisExtent: 200, crossAxisExtent: 50)
        )
        let childSize = WrapAxisSize(mainAxisExtent: 150, crossAxisExtent: 40)
        let newRun = run.tryAddingNewChild(
            child2,
            childSize: childSize,
            flipMainAxis: false,
            spacing: 10,
            maxMainExtent: 300
        )
        XCTAssertNotNil(newRun)
        XCTAssertTrue(newRun!.leadingChild === child2)
        XCTAssertEqual(newRun!.axisSize, childSize)
        XCTAssertEqual(run.childCount, 1)
    }

    /// Test tryAddingNewChild with flipMainAxis updates leadingChild.
    func testTryAddingNewChildWithFlipMainAxis() {
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        var run = WrapRunMetrics(
            leadingChild: child1,
            axisSize: WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        )
        let childSize = WrapAxisSize(mainAxisExtent: 80, crossAxisExtent: 40)
        let newRun = run.tryAddingNewChild(
            child2,
            childSize: childSize,
            flipMainAxis: true,
            spacing: 10,
            maxMainExtent: 300
        )
        XCTAssertNil(newRun)
        XCTAssertTrue(run.leadingChild === child2)
    }

    /// Test tryAddingNewChild without flipMainAxis does not change leadingChild.
    func testTryAddingNewChildWithoutFlipMainAxis() {
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        var run = WrapRunMetrics(
            leadingChild: child1,
            axisSize: WrapAxisSize(mainAxisExtent: 100, crossAxisExtent: 50)
        )
        let childSize = WrapAxisSize(mainAxisExtent: 80, crossAxisExtent: 40)
        let _ = run.tryAddingNewChild(
            child2,
            childSize: childSize,
            flipMainAxis: false,
            spacing: 10,
            maxMainExtent: 300
        )
        XCTAssertTrue(run.leadingChild === child1)
    }
}

// MARK: - WrapParentData Tests

final class WrapParentDataTests: XCTestCase {

    /// Test that WrapParentData can be created.
    func testCreation() {
        let parentData = WrapParentData()
        XCTAssertNotNil(parentData)
    }

    /// Test that WrapParentData inherits from ContainerBoxParentData.
    func testInheritsFromContainerBoxParentData() {
        let parentData = WrapParentData()
        XCTAssertTrue(parentData is ContainerBoxParentData<RenderBox>)
    }

    /// Test that sibling pointers default to nil.
    func testSiblingPointersDefaultToNil() {
        let parentData = WrapParentData()
        XCTAssertNil(parentData.previousSibling)
        XCTAssertNil(parentData.nextSibling)
    }

    /// Test that offset defaults to zero.
    func testOffsetDefaultsToZero() {
        let parentData = WrapParentData()
        XCTAssertEqual(parentData.offset, Offset.zero)
    }
}

// MARK: - RenderWrap Construction Tests

final class RenderWrapConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let wrap = RenderWrap()
        XCTAssertEqual(wrap.direction, .horizontal)
        XCTAssertEqual(wrap.alignment, .start)
        XCTAssertEqual(wrap.spacing, 0.0)
        XCTAssertEqual(wrap.runAlignment, .start)
        XCTAssertEqual(wrap.runSpacing, 0.0)
        XCTAssertEqual(wrap.crossAxisAlignment, .start)
        XCTAssertEqual(wrap.verticalDirection, .down)
        XCTAssertEqual(wrap.clipBehavior, .none)
        XCTAssertEqual(wrap.childCount, 0)
        XCTAssertNil(wrap.firstChild)
        XCTAssertNil(wrap.lastChild)
    }

    /// Test construction with custom parameters.
    func testConstructionWithCustomParameters() {
        let wrap = RenderWrap(
            direction: .vertical,
            alignment: .center,
            spacing: 10,
            runAlignment: .spaceEvenly,
            runSpacing: 5,
            crossAxisAlignment: .end,
            textDirection: .rtl,
            verticalDirection: .up,
            clipBehavior: .hardEdge
        )
        XCTAssertEqual(wrap.direction, .vertical)
        XCTAssertEqual(wrap.alignment, .center)
        XCTAssertEqual(wrap.spacing, 10.0)
        XCTAssertEqual(wrap.runAlignment, .spaceEvenly)
        XCTAssertEqual(wrap.runSpacing, 5.0)
        XCTAssertEqual(wrap.crossAxisAlignment, .end)
        XCTAssertEqual(wrap.textDirection, .rtl)
        XCTAssertEqual(wrap.verticalDirection, .up)
        XCTAssertEqual(wrap.clipBehavior, .hardEdge)
    }

    /// Test construction with children.
    func testConstructionWithChildren() {
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let wrap = RenderWrap(children: [child1, child2])
        XCTAssertEqual(wrap.childCount, 2)
        XCTAssertNotNil(wrap.firstChild)
        XCTAssertNotNil(wrap.lastChild)
    }
}

// MARK: - RenderWrap Property Setter Tests

final class RenderWrapPropertySetterTests: XCTestCase {

    /// Test that setting direction triggers markNeedsLayout.
    func testDirectionSetterTriggersLayout() {
        let wrap = RenderWrap(direction: .horizontal)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.direction = .vertical
        XCTAssertTrue(wrap.needsLayout)
    }

    /// Test that setting direction to the same value does not trigger layout.
    func testDirectionSetterNoOpOnSameValue() {
        let wrap = RenderWrap(direction: .horizontal)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.direction = .horizontal
        XCTAssertFalse(wrap.needsLayout)
    }

    /// Test that setting alignment triggers markNeedsLayout.
    func testAlignmentSetterTriggersLayout() {
        let wrap = RenderWrap(alignment: .start)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.alignment = .center
        XCTAssertTrue(wrap.needsLayout)
    }

    /// Test that setting alignment to the same value does not trigger layout.
    func testAlignmentSetterNoOpOnSameValue() {
        let wrap = RenderWrap(alignment: .start)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.alignment = .start
        XCTAssertFalse(wrap.needsLayout)
    }

    /// Test that setting spacing triggers markNeedsLayout.
    func testSpacingSetterTriggersLayout() {
        let wrap = RenderWrap(spacing: 0)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.spacing = 10
        XCTAssertTrue(wrap.needsLayout)
    }

    /// Test that setting spacing to the same value does not trigger layout.
    func testSpacingSetterNoOpOnSameValue() {
        let wrap = RenderWrap(spacing: 10)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.spacing = 10
        XCTAssertFalse(wrap.needsLayout)
    }

    /// Test that setting runAlignment triggers markNeedsLayout.
    func testRunAlignmentSetterTriggersLayout() {
        let wrap = RenderWrap(runAlignment: .start)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.runAlignment = .center
        XCTAssertTrue(wrap.needsLayout)
    }

    /// Test that setting runSpacing triggers markNeedsLayout.
    func testRunSpacingSetterTriggersLayout() {
        let wrap = RenderWrap(runSpacing: 0)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.runSpacing = 5
        XCTAssertTrue(wrap.needsLayout)
    }

    /// Test that setting crossAxisAlignment triggers markNeedsLayout.
    func testCrossAxisAlignmentSetterTriggersLayout() {
        let wrap = RenderWrap(crossAxisAlignment: .start)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.crossAxisAlignment = .end
        XCTAssertTrue(wrap.needsLayout)
    }

    /// Test that setting textDirection triggers markNeedsLayout.
    func testTextDirectionSetterTriggersLayout() {
        let wrap = RenderWrap(textDirection: .ltr)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.textDirection = .rtl
        XCTAssertTrue(wrap.needsLayout)
    }

    /// Test that setting textDirection to same value does not trigger layout.
    func testTextDirectionSetterNoOpOnSameValue() {
        let wrap = RenderWrap(textDirection: .ltr)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.textDirection = .ltr
        XCTAssertFalse(wrap.needsLayout)
    }

    /// Test that setting verticalDirection triggers markNeedsLayout.
    func testVerticalDirectionSetterTriggersLayout() {
        let wrap = RenderWrap(verticalDirection: .down)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(wrap.needsLayout)

        wrap.verticalDirection = .up
        XCTAssertTrue(wrap.needsLayout)
    }

    /// Test that setting clipBehavior triggers markNeedsPaint.
    func testClipBehaviorSetterTriggersPaint() {
        let wrap = RenderWrap(clipBehavior: .none)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        wrap.needsPaint = false

        wrap.clipBehavior = .hardEdge
        XCTAssertTrue(wrap.needsPaint)
    }

    /// Test that setting clipBehavior to same value does not trigger paint.
    func testClipBehaviorSetterNoOpOnSameValue() {
        let wrap = RenderWrap(clipBehavior: .none)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        wrap.needsPaint = false

        wrap.clipBehavior = .none
        XCTAssertFalse(wrap.needsPaint)
    }
}

// MARK: - RenderWrap setupParentData Tests

final class RenderWrapSetupParentDataTests: XCTestCase {

    /// Test that setupParentData creates WrapParentData.
    func testSetupParentDataCreatesWrapParentData() {
        let wrap = RenderWrap()
        let child = TestRenderBox()
        wrap.setupParentData(child)
        XCTAssertTrue(child.parentData is WrapParentData)
    }

    /// Test that setupParentData does not replace existing WrapParentData.
    func testSetupParentDataPreservesExistingWrapParentData() {
        let wrap = RenderWrap()
        let child = TestRenderBox()
        let existingData = WrapParentData()
        existingData.offset = Offset(42, 42)
        child.parentData = existingData
        wrap.setupParentData(child)
        XCTAssertTrue(child.parentData === existingData)
        XCTAssertEqual((child.parentData as! WrapParentData).offset, Offset(42, 42))
    }
}

// MARK: - RenderWrap Child Management Tests

final class RenderWrapChildManagementTests: XCTestCase {

    /// Test childCount, firstChild, lastChild with no children.
    func testEmptyState() {
        let wrap = RenderWrap()
        XCTAssertEqual(wrap.childCount, 0)
        XCTAssertNil(wrap.firstChild)
        XCTAssertNil(wrap.lastChild)
    }

    /// Test insert (prepend) and remove.
    func testInsertAndRemove() {
        let wrap = RenderWrap()
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()

        wrap.insert(child1)
        XCTAssertEqual(wrap.childCount, 1)
        XCTAssertTrue(wrap.firstChild === child1)
        XCTAssertTrue(wrap.lastChild === child1)

        // Insert without after: prepends child2 before child1
        wrap.insert(child2)
        XCTAssertEqual(wrap.childCount, 2)
        XCTAssertTrue(wrap.firstChild === child2)
        XCTAssertTrue(wrap.lastChild === child1)

        wrap.remove(child2)
        XCTAssertEqual(wrap.childCount, 1)
        XCTAssertTrue(wrap.firstChild === child1)
        XCTAssertTrue(wrap.lastChild === child1)

        wrap.remove(child1)
        XCTAssertEqual(wrap.childCount, 0)
        XCTAssertNil(wrap.firstChild)
        XCTAssertNil(wrap.lastChild)
    }

    /// Test addAll with nil does nothing.
    func testAddAllWithNil() {
        let wrap = RenderWrap()
        wrap.addAll(nil)
        XCTAssertEqual(wrap.childCount, 0)
    }

    /// Test addAll populates children and updates childCount.
    func testAddAll() {
        let wrap = RenderWrap()
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let child3 = TestRenderBox()
        wrap.addAll([child1, child2, child3])
        XCTAssertEqual(wrap.childCount, 3)
        XCTAssertNotNil(wrap.firstChild)
        XCTAssertNotNil(wrap.lastChild)
    }

    /// Test childAfter and childBefore navigation using prepend-based insertion.
    func testChildNavigation() {
        let wrap = RenderWrap()
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let child3 = TestRenderBox()

        // Prepend in reverse order to build child1 -> child2 -> child3
        wrap.insert(child3)
        wrap.insert(child2)
        wrap.insert(child1)

        XCTAssertTrue(wrap.firstChild === child1)
        XCTAssertTrue(wrap.childAfter(child1) === child2)
        XCTAssertTrue(wrap.childAfter(child2) === child3)
        XCTAssertNil(wrap.childAfter(child3))

        XCTAssertNil(wrap.childBefore(child1))
        XCTAssertTrue(wrap.childBefore(child2) === child1)
        XCTAssertTrue(wrap.childBefore(child3) === child2)
    }

    /// Test insert with after parameter establishes correct linked-list order.
    func testInsertAfter() {
        let wrap = RenderWrap()
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let child3 = TestRenderBox()

        wrap.insert(child1)
        wrap.insert(child3, after: child1)
        wrap.insert(child2, after: child1)

        // Order should be: child1 -> child2 -> child3
        XCTAssertTrue(wrap.firstChild === child1)
        XCTAssertTrue(wrap.childAfter(child1) === child2)
        XCTAssertTrue(wrap.childAfter(child2) === child3)
        XCTAssertNil(wrap.childAfter(child3))
    }

    /// Test childCount updates correctly.
    func testChildCountUpdates() {
        let wrap = RenderWrap()
        XCTAssertEqual(wrap.childCount, 0)

        let child1 = TestRenderBox()
        wrap.insert(child1)
        XCTAssertEqual(wrap.childCount, 1)

        let child2 = TestRenderBox()
        wrap.insert(child2)
        XCTAssertEqual(wrap.childCount, 2)

        wrap.remove(child1)
        XCTAssertEqual(wrap.childCount, 1)

        wrap.remove(child2)
        XCTAssertEqual(wrap.childCount, 0)
    }
}

// MARK: - RenderWrap Helper Method Tests

final class RenderWrapHelperMethodTests: XCTestCase {

    /// Test _getMainAxisExtent for horizontal direction.
    func testGetMainAxisExtentHorizontal() {
        let wrap = RenderWrap(direction: .horizontal)
        let size = Size(200, 100)
        XCTAssertEqual(wrap._getMainAxisExtent(size), 200.0)
    }

    /// Test _getMainAxisExtent for vertical direction.
    func testGetMainAxisExtentVertical() {
        let wrap = RenderWrap(direction: .vertical)
        let size = Size(200, 100)
        XCTAssertEqual(wrap._getMainAxisExtent(size), 100.0)
    }

    /// Test _getCrossAxisExtent for horizontal direction.
    func testGetCrossAxisExtentHorizontal() {
        let wrap = RenderWrap(direction: .horizontal)
        let size = Size(200, 100)
        XCTAssertEqual(wrap._getCrossAxisExtent(size), 100.0)
    }

    /// Test _getCrossAxisExtent for vertical direction.
    func testGetCrossAxisExtentVertical() {
        let wrap = RenderWrap(direction: .vertical)
        let size = Size(200, 100)
        XCTAssertEqual(wrap._getCrossAxisExtent(size), 200.0)
    }

    /// Test _getOffset for horizontal direction.
    func testGetOffsetHorizontal() {
        let wrap = RenderWrap(direction: .horizontal)
        let offset = wrap._getOffset(10, 20)
        XCTAssertEqual(offset.dx, 10.0)
        XCTAssertEqual(offset.dy, 20.0)
    }

    /// Test _getOffset for vertical direction.
    func testGetOffsetVertical() {
        let wrap = RenderWrap(direction: .vertical)
        let offset = wrap._getOffset(10, 20)
        XCTAssertEqual(offset.dx, 20.0)
        XCTAssertEqual(offset.dy, 10.0)
    }
}

// MARK: - RenderWrap _areAxesFlipped Tests

final class RenderWrapAreAxesFlippedTests: XCTestCase {

    /// Test horizontal LTR, down: nothing flipped.
    func testHorizontalLTRDown() {
        let wrap = RenderWrap(direction: .horizontal, textDirection: .ltr, verticalDirection: .down)
        let (flipMain, flipCross) = wrap._areAxesFlipped
        XCTAssertFalse(flipMain)
        XCTAssertFalse(flipCross)
    }

    /// Test horizontal RTL, down: main flipped, cross not.
    func testHorizontalRTLDown() {
        let wrap = RenderWrap(direction: .horizontal, textDirection: .rtl, verticalDirection: .down)
        let (flipMain, flipCross) = wrap._areAxesFlipped
        XCTAssertTrue(flipMain)
        XCTAssertFalse(flipCross)
    }

    /// Test horizontal LTR, up: main not flipped, cross flipped.
    func testHorizontalLTRUp() {
        let wrap = RenderWrap(direction: .horizontal, textDirection: .ltr, verticalDirection: .up)
        let (flipMain, flipCross) = wrap._areAxesFlipped
        XCTAssertFalse(flipMain)
        XCTAssertTrue(flipCross)
    }

    /// Test horizontal RTL, up: both flipped.
    func testHorizontalRTLUp() {
        let wrap = RenderWrap(direction: .horizontal, textDirection: .rtl, verticalDirection: .up)
        let (flipMain, flipCross) = wrap._areAxesFlipped
        XCTAssertTrue(flipMain)
        XCTAssertTrue(flipCross)
    }

    /// Test vertical LTR, down: nothing flipped.
    func testVerticalLTRDown() {
        let wrap = RenderWrap(direction: .vertical, textDirection: .ltr, verticalDirection: .down)
        let (flipMain, flipCross) = wrap._areAxesFlipped
        XCTAssertFalse(flipMain)
        XCTAssertFalse(flipCross)
    }

    /// Test vertical RTL, down: main not flipped, cross flipped.
    func testVerticalRTLDown() {
        let wrap = RenderWrap(direction: .vertical, textDirection: .rtl, verticalDirection: .down)
        let (flipMain, flipCross) = wrap._areAxesFlipped
        XCTAssertFalse(flipMain)
        XCTAssertTrue(flipCross)
    }

    /// Test vertical LTR, up: main flipped, cross not flipped.
    func testVerticalLTRUp() {
        let wrap = RenderWrap(direction: .vertical, textDirection: .ltr, verticalDirection: .up)
        let (flipMain, flipCross) = wrap._areAxesFlipped
        XCTAssertTrue(flipMain)
        XCTAssertFalse(flipCross)
    }

    /// Test vertical RTL, up: both flipped.
    func testVerticalRTLUp() {
        let wrap = RenderWrap(direction: .vertical, textDirection: .rtl, verticalDirection: .up)
        let (flipMain, flipCross) = wrap._areAxesFlipped
        XCTAssertTrue(flipMain)
        XCTAssertTrue(flipCross)
    }

    /// Test default textDirection (nil) falls back to LTR.
    func testDefaultTextDirectionFallsBackToLTR() {
        let wrap = RenderWrap(direction: .horizontal, verticalDirection: .down)
        let (flipMain, flipCross) = wrap._areAxesFlipped
        XCTAssertFalse(flipMain)
        XCTAssertFalse(flipCross)
    }
}

// MARK: - RenderWrap Intrinsic Dimensions Tests

final class RenderWrapIntrinsicDimensionTests: XCTestCase {

    /// Test computeMinIntrinsicWidth for horizontal wrap returns max of children's min widths.
    func testMinIntrinsicWidthHorizontal() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(120, 60))
        let wrap = RenderWrap(children: [child1, child2], direction: .horizontal)
        let width = wrap.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(width, 120.0)
    }

    /// Test computeMaxIntrinsicWidth for horizontal wrap returns sum of children's max widths.
    func testMaxIntrinsicWidthHorizontal() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(120, 60))
        let wrap = RenderWrap(children: [child1, child2], direction: .horizontal)
        let width = wrap.computeMaxIntrinsicWidth(.infinity)
        XCTAssertEqual(width, 200.0)
    }

    /// Test computeMinIntrinsicHeight for vertical wrap returns max of children's min heights.
    func testMinIntrinsicHeightVertical() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(120, 70))
        let wrap = RenderWrap(children: [child1, child2], direction: .vertical)
        let height = wrap.computeMinIntrinsicHeight(.infinity)
        XCTAssertEqual(height, 70.0)
    }

    /// Test computeMaxIntrinsicHeight for vertical wrap returns sum of children's max heights.
    func testMaxIntrinsicHeightVertical() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(120, 70))
        let wrap = RenderWrap(children: [child1, child2], direction: .vertical)
        let height = wrap.computeMaxIntrinsicHeight(.infinity)
        XCTAssertEqual(height, 120.0)
    }

    /// Test intrinsic dimensions with no children.
    func testIntrinsicDimensionsNoChildren() {
        let wrap = RenderWrap(direction: .horizontal)
        XCTAssertEqual(wrap.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(wrap.computeMaxIntrinsicWidth(.infinity), 0.0)

        let wrapV = RenderWrap(direction: .vertical)
        XCTAssertEqual(wrapV.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(wrapV.computeMaxIntrinsicHeight(.infinity), 0.0)
    }

    /// Test computeMinIntrinsicHeight for horizontal wrap uses dry layout.
    /// Using same-height children to avoid ordering sensitivity.
    func testMinIntrinsicHeightHorizontalUsesDryLayout() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(80, 50))
        let wrap = RenderWrap(children: [child1, child2], direction: .horizontal)
        // With maxWidth=200, both children fit in one row (80+80=160 < 200)
        // So height = max(50, 50) = 50
        let height = wrap.computeMinIntrinsicHeight(200)
        XCTAssertEqual(height, 50.0)
    }

    /// Test computeMinIntrinsicWidth for vertical wrap uses dry layout.
    /// Using same-width children to avoid ordering sensitivity.
    func testMinIntrinsicWidthVerticalUsesDryLayout() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(80, 60))
        let wrap = RenderWrap(children: [child1, child2], direction: .vertical)
        // With maxHeight=200, both children fit in one column (50+60=110 < 200)
        // So width = max(80, 80) = 80
        let width = wrap.computeMinIntrinsicWidth(200)
        XCTAssertEqual(width, 80.0)
    }
}

// MARK: - RenderWrap Dry Layout Tests

final class RenderWrapDryLayoutTests: XCTestCase {

    /// Test computeDryLayout with no children returns smallest.
    func testDryLayoutNoChildren() {
        let wrap = RenderWrap()
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 10, maxHeight: 200)
        let result = wrap.computeDryLayout(constraints)
        XCTAssertEqual(result, Size(10, 10))
    }

    /// Test computeDryLayout with single child.
    func testDryLayoutSingleChild() {
        let child = TestRenderBox(size: Size(80, 60))
        let wrap = RenderWrap(children: [child], direction: .horizontal)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let result = wrap.computeDryLayout(constraints)
        XCTAssertEqual(result, Size(80, 60))
    }

    /// Test computeDryLayout with same-sized children that fit in a single row.
    func testDryLayoutSingleRow() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(60, 50))
        let wrap = RenderWrap(children: [child1, child2], direction: .horizontal)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let result = wrap.computeDryLayout(constraints)
        // Both fit: mainAxis = 80 + 60 = 140, crossAxis = max(50, 50) = 50
        XCTAssertEqual(result, Size(140, 50))
    }

    /// Test computeDryLayout with same-sized children that wrap to a second row.
    func testDryLayoutMultipleRows() {
        // Use same-sized children to avoid ordering sensitivity
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(80, 50))
        let child3 = TestRenderBox(size: Size(80, 50))
        let wrap = RenderWrap(children: [child1, child2, child3], direction: .horizontal)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 500)
        let result = wrap.computeDryLayout(constraints)
        // Two children fit per row (80+80=160<=200), one in second row
        // Row 1: 160 wide, 50 high. Row 2: 80 wide, 50 high.
        // Total: max(160, 80) = 160, 50 + 50 = 100
        XCTAssertEqual(result, Size(160, 100))
    }

    /// Test computeDryLayout with spacing between children.
    func testDryLayoutWithSpacing() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(80, 50))
        let child3 = TestRenderBox(size: Size(80, 50))
        let wrap = RenderWrap(children: [child1, child2, child3], direction: .horizontal, spacing: 10)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 500)
        let result = wrap.computeDryLayout(constraints)
        // Row 1: 80 + 10 + 80 = 170 <= 200
        // Row 2: 80 alone (170 + 10 + 80 = 260 > 200)
        // Total: max(170, 80) = 170, 50 + 50 = 100
        XCTAssertEqual(result, Size(170, 100))
    }

    /// Test computeDryLayout with runSpacing between runs.
    func testDryLayoutWithRunSpacing() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(80, 50))
        let child3 = TestRenderBox(size: Size(80, 50))
        let wrap = RenderWrap(
            children: [child1, child2, child3],
            direction: .horizontal,
            spacing: 10,
            runSpacing: 20
        )
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 500)
        let result = wrap.computeDryLayout(constraints)
        // Row 1: 170, Row 2: 80
        // Total: max(170, 80) = 170, 50 + 20 + 50 = 120
        XCTAssertEqual(result, Size(170, 120))
    }

    /// Test computeDryLayout vertical direction with same-width children.
    func testDryLayoutVertical() {
        let child1 = TestRenderBox(size: Size(80, 50))
        let child2 = TestRenderBox(size: Size(80, 70))
        let wrap = RenderWrap(children: [child1, child2], direction: .vertical)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 200)
        let result = wrap.computeDryLayout(constraints)
        // Both fit in one column: mainAxis(height) = 50 + 70 = 120, crossAxis(width) = max(80, 80) = 80
        XCTAssertEqual(result, Size(80, 120))
    }
}

// MARK: - RenderWrap performLayout Tests

final class RenderWrapPerformLayoutTests: XCTestCase {

    /// Test empty wrap layout returns constraints.smallest.
    func testEmptyWrapLayout() {
        let wrap = RenderWrap()
        wrap.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(wrap.size, Size(0, 0))
    }

    /// Test single child layout positions child at origin with default alignment.
    func testSingleChildLayout() {
        let child = TestRenderBox(size: Size(80, 60))
        let wrap = RenderWrap(children: [child], direction: .horizontal, textDirection: .ltr)
        wrap.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(wrap.size, Size(80, 60))
        let pd = child.parentData as! WrapParentData
        XCTAssertEqual(pd.offset, Offset(0, 0))
    }

    /// Test that each child in separate runs gets positioned correctly.
    /// (Each child is too wide to share a row.)
    func testEachChildInSeparateRun() {
        let child1 = TestRenderBox(size: Size(150, 50))
        let child2 = TestRenderBox(size: Size(150, 60))
        let wrap = RenderWrap(
            children: [child1, child2],
            direction: .horizontal,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 500))

        // Each child alone: 150 <= 200, but 150+150=300 > 200
        // Row 1: child1(150x50)
        // Row 2: child2(150x60)
        XCTAssertEqual(wrap.size.width, 150.0)
        XCTAssertEqual(wrap.size.height, 110.0) // 50 + 60

        let pd1 = child1.parentData as! WrapParentData
        XCTAssertEqual(pd1.offset, Offset(0, 0))

        let pd2 = child2.parentData as! WrapParentData
        XCTAssertEqual(pd2.offset.dx, 0.0)
        XCTAssertEqual(pd2.offset.dy, 50.0)
    }

    /// Test horizontal wrap with runSpacing between runs.
    func testHorizontalWrapWithRunSpacing() {
        let child1 = TestRenderBox(size: Size(150, 50))
        let child2 = TestRenderBox(size: Size(150, 60))
        let wrap = RenderWrap(
            children: [child1, child2],
            direction: .horizontal,
            runSpacing: 20,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 500))

        // Row 1: child1(150) <= 200
        // Row 2: child2(150) (150 + 150 = 300 > 200)
        XCTAssertEqual(wrap.size.height, 130.0) // 50 + 20 + 60

        let pd2 = child2.parentData as! WrapParentData
        XCTAssertEqual(pd2.offset.dy, 70.0) // 50 + 20
    }

    /// Test layout with WrapAlignment.center using single child per run.
    func testLayoutWithCenterAlignment() {
        let child1 = TestRenderBox(size: Size(60, 50))
        let wrap = RenderWrap(
            children: [child1],
            direction: .horizontal,
            alignment: .center,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints.tight(Size(200, 200)))

        // Main axis free space = 200 - 60 = 140, center => leading = 70
        let pd1 = child1.parentData as! WrapParentData
        XCTAssertEqual(pd1.offset.dx, 70.0)
    }

    /// Test layout with WrapAlignment.end using single child per run.
    func testLayoutWithEndAlignment() {
        let child1 = TestRenderBox(size: Size(60, 50))
        let wrap = RenderWrap(
            children: [child1],
            direction: .horizontal,
            alignment: .end,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints.tight(Size(200, 200)))

        // Main axis free space = 200 - 60 = 140, end => leading = 140
        let pd1 = child1.parentData as! WrapParentData
        XCTAssertEqual(pd1.offset.dx, 140.0)
    }

    /// Test layout with WrapAlignment.spaceBetween using single child.
    /// For a single child, spaceBetween falls back to start.
    func testLayoutWithSpaceBetweenSingleChild() {
        let child = TestRenderBox(size: Size(60, 50))
        let wrap = RenderWrap(
            children: [child],
            direction: .horizontal,
            alignment: .spaceBetween,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints.tight(Size(200, 200)))

        // Single child: falls back to .start => leading = 0
        let pd = child.parentData as! WrapParentData
        XCTAssertEqual(pd.offset.dx, 0.0)
    }

    /// Test layout with WrapAlignment.spaceAround using single child.
    func testLayoutWithSpaceAroundSingleChild() {
        let child = TestRenderBox(size: Size(60, 50))
        let wrap = RenderWrap(
            children: [child],
            direction: .horizontal,
            alignment: .spaceAround,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints.tight(Size(200, 200)))

        // Free space = 140, count=1
        // leading = 140 / 1 / 2 = 70
        let pd = child.parentData as! WrapParentData
        XCTAssertEqual(pd.offset.dx, 70.0)
    }

    /// Test layout with WrapAlignment.spaceEvenly using single child.
    func testLayoutWithSpaceEvenlySingleChild() {
        let child = TestRenderBox(size: Size(60, 50))
        let wrap = RenderWrap(
            children: [child],
            direction: .horizontal,
            alignment: .spaceEvenly,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints.tight(Size(200, 200)))

        // Free space = 140, count=1
        // leading = 140 / (1 + 1) = 70
        let pd = child.parentData as! WrapParentData
        XCTAssertEqual(pd.offset.dx, 70.0)
    }

    /// Test vertical wrap layout with children in separate columns.
    func testVerticalWrapSeparateColumns() {
        let child1 = TestRenderBox(size: Size(80, 120))
        let child2 = TestRenderBox(size: Size(90, 130))
        let wrap = RenderWrap(
            children: [child1, child2],
            direction: .vertical,
            textDirection: .ltr,
            verticalDirection: .down
        )
        wrap.layout(BoxConstraints(minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 150))

        // Column 1: child1(h=120) <= 150
        // Column 2: child2(h=130) (120 + 130 = 250 > 150)
        XCTAssertEqual(wrap.size.height, 130.0) // max(120, 130) constrained
        XCTAssertEqual(wrap.size.width, 170.0)  // 80 + 90

        let pd1 = child1.parentData as! WrapParentData
        XCTAssertEqual(pd1.offset, Offset(0, 0))

        let pd2 = child2.parentData as! WrapParentData
        XCTAssertEqual(pd2.offset.dx, 80.0)
        XCTAssertEqual(pd2.offset.dy, 0.0)
    }

    /// Test that tight constraints constrain the wrap size.
    func testTightConstraints() {
        let child = TestRenderBox(size: Size(50, 50))
        let wrap = RenderWrap(children: [child], direction: .horizontal, textDirection: .ltr)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertEqual(wrap.size, Size(200, 200))
    }
}

// MARK: - RenderWrap runAlignment Tests

final class RenderWrapRunAlignmentTests: XCTestCase {

    /// Test runAlignment .center positions runs in the center of the cross axis.
    func testRunAlignmentCenter() {
        let child1 = TestRenderBox(size: Size(150, 40))
        let child2 = TestRenderBox(size: Size(150, 50))
        let wrap = RenderWrap(
            children: [child1, child2],
            direction: .horizontal,
            runAlignment: .center,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints.tight(Size(200, 200)))

        // Two runs (each 150 <= 200 but 150+150 > 200): row1 (h=40), row2 (h=50)
        // Total cross = 40 + 50 = 90
        // Free cross space = 200 - 90 = 110
        // .center => runLeadingSpace = 55
        let pd1 = child1.parentData as! WrapParentData
        XCTAssertEqual(pd1.offset.dy, 55.0)

        let pd2 = child2.parentData as! WrapParentData
        XCTAssertEqual(pd2.offset.dy, 95.0) // 55 + 40
    }

    /// Test runAlignment .end positions runs at the end of the cross axis.
    func testRunAlignmentEnd() {
        let child1 = TestRenderBox(size: Size(150, 40))
        let child2 = TestRenderBox(size: Size(150, 50))
        let wrap = RenderWrap(
            children: [child1, child2],
            direction: .horizontal,
            runAlignment: .end,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints.tight(Size(200, 200)))

        // Free cross space = 110
        // .end => leading = 110
        let pd1 = child1.parentData as! WrapParentData
        XCTAssertEqual(pd1.offset.dy, 110.0)

        let pd2 = child2.parentData as! WrapParentData
        XCTAssertEqual(pd2.offset.dy, 150.0) // 110 + 40
    }

    /// Test runAlignment .spaceEvenly distributes runs evenly.
    func testRunAlignmentSpaceEvenly() {
        let child1 = TestRenderBox(size: Size(150, 40))
        let child2 = TestRenderBox(size: Size(150, 50))
        let wrap = RenderWrap(
            children: [child1, child2],
            direction: .horizontal,
            runAlignment: .spaceEvenly,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints.tight(Size(200, 210)))

        // Two runs: row1 (h=40), row2 (h=50)
        // Total cross = 90
        // Free space = 210 - 90 = 120
        // .spaceEvenly: leading = 120 / (2 + 1) = 40, between = 40
        let pd1 = child1.parentData as! WrapParentData
        XCTAssertEqual(pd1.offset.dy, 40.0)

        let pd2 = child2.parentData as! WrapParentData
        XCTAssertEqual(pd2.offset.dy, 120.0) // 40 + 40 + 40
    }

    /// Test runAlignment .spaceBetween distributes space between runs.
    func testRunAlignmentSpaceBetween() {
        let child1 = TestRenderBox(size: Size(150, 40))
        let child2 = TestRenderBox(size: Size(150, 50))
        let wrap = RenderWrap(
            children: [child1, child2],
            direction: .horizontal,
            runAlignment: .spaceBetween,
            textDirection: .ltr
        )
        wrap.layout(BoxConstraints.tight(Size(200, 200)))

        // Two runs: row1 (h=40), row2 (h=50)
        // Free space = 200 - 90 = 110
        // .spaceBetween with 2 items: between = 110 / (2-1) + 0 = 110
        let pd1 = child1.parentData as! WrapParentData
        XCTAssertEqual(pd1.offset.dy, 0.0) // leading = 0

        let pd2 = child2.parentData as! WrapParentData
        XCTAssertEqual(pd2.offset.dy, 150.0) // 0 + 40 + 110
    }
}

// MARK: - RenderWrap verticalDirection Tests

final class RenderWrapVerticalDirectionTests: XCTestCase {

    /// Test layout with verticalDirection .up reverses cross-axis layout.
    func testLayoutWithVerticalDirectionUp() {
        let child1 = TestRenderBox(size: Size(150, 50))
        let child2 = TestRenderBox(size: Size(150, 60))
        let wrap = RenderWrap(
            children: [child1, child2],
            direction: .horizontal,
            textDirection: .ltr,
            verticalDirection: .up
        )
        wrap.layout(BoxConstraints.tight(Size(200, 200)))

        // Two rows: child1 (150<=200), child2 (150, 150+150>200)
        // verticalDirection .up => flipCrossAxis=true
        // crossAxisFreeSpace = 200 - (50 + 60) = 90
        // runAlignment=.start with flipped=true => runLeadingSpace = 90
        // runs reversed: [child2_run, child1_run]
        // child2: crossOffset = 90
        // child1: crossOffset = 90 + 60 = 150
        let pd1 = child1.parentData as! WrapParentData
        let pd2 = child2.parentData as! WrapParentData
        XCTAssertEqual(pd2.offset.dy, 90.0)
        XCTAssertEqual(pd1.offset.dy, 150.0)
    }
}

// MARK: - RenderWrap Dispose Tests

final class RenderWrapDisposeTests: XCTestCase {

    /// Test dispose does not crash.
    func testDispose() {
        let wrap = RenderWrap()
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        wrap.dispose()
    }

    /// Test dispose on fresh RenderWrap works.
    func testDisposeOnFreshWrap() {
        let wrap = RenderWrap()
        wrap.dispose()
    }

    /// Test dispose after layout with children does not crash.
    func testDisposeAfterLayoutWithChildren() {
        let child = TestRenderBox(size: Size(100, 100))
        let wrap = RenderWrap(children: [child])
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        wrap.dispose()
    }
}

// MARK: - RenderWrap Constrained Layout Tests

final class RenderWrapConstrainedLayoutTests: XCTestCase {

    /// Test that tight constraints constrain the wrap size.
    func testTightConstraints() {
        let child = TestRenderBox(size: Size(50, 50))
        let wrap = RenderWrap(children: [child], direction: .horizontal, textDirection: .ltr)
        wrap.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertEqual(wrap.size, Size(200, 200))
    }

    /// Test that children exceeding constraints result in constrained size.
    func testChildrenExceedConstraints() {
        let child1 = TestRenderBox(size: Size(150, 100))
        let child2 = TestRenderBox(size: Size(150, 100))
        let wrap = RenderWrap(children: [child1, child2], direction: .horizontal, textDirection: .ltr)
        wrap.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 150))
        // Two rows: mainAxis = max(150, 150) = 150, crossAxis = 100 + 100 = 200 => constrained to 150
        XCTAssertEqual(wrap.size.width, 150.0)
        XCTAssertEqual(wrap.size.height, 150.0)
    }

    /// Test that minWidth and minHeight are respected.
    func testMinConstraintsRespected() {
        let child = TestRenderBox(size: Size(30, 20))
        let wrap = RenderWrap(children: [child], direction: .horizontal, textDirection: .ltr)
        wrap.layout(BoxConstraints(minWidth: 100, maxWidth: 200, minHeight: 80, maxHeight: 200))
        XCTAssertGreaterThanOrEqual(wrap.size.width, 100.0)
        XCTAssertGreaterThanOrEqual(wrap.size.height, 80.0)
    }
}

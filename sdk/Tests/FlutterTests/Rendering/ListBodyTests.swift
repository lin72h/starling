// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for ListBody types from the Rendering layer.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/list_body_test.dart`
///
/// These tests cover:
///   - ListBodyParentData basic instantiation
///   - RenderListBody construction with default axisDirection (.down)
///   - axisDirection setter triggering markNeedsLayout
///   - mainAxis computed property
///   - performLayout with all four axis directions
///   - Intrinsic dimensions (cross axis uses max, main axis uses sum)
///   - computeDryLayout matching performLayout sizing
///   - No children case (empty layout)
///   - setupParentData installs ListBodyParentData

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A concrete `RenderBox` subclass with configurable intrinsic dimensions
/// and a fixed size for layout, used as a child of `RenderListBody` in tests.
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

// MARK: - ListBodyParentData Tests

final class ListBodyParentDataTests: XCTestCase {

    /// Test that `ListBodyParentData` can be instantiated.
    func testBasicInstantiation() {
        let parentData = ListBodyParentData()
        XCTAssertNotNil(parentData)
    }

    /// Test that sibling pointers default to nil.
    func testSiblingPointersDefaultToNil() {
        let parentData = ListBodyParentData()
        XCTAssertNil(parentData.previousSibling)
        XCTAssertNil(parentData.nextSibling)
    }

    /// Test that offset defaults to zero.
    func testOffsetDefaultsToZero() {
        let parentData = ListBodyParentData()
        XCTAssertEqual(parentData.offset.dx, 0.0)
        XCTAssertEqual(parentData.offset.dy, 0.0)
    }

    /// Test that ListBodyParentData is a subclass of ContainerBoxParentData.
    func testIsContainerBoxParentData() {
        let parentData = ListBodyParentData()
        XCTAssertTrue(
            parentData is ContainerBoxParentData<RenderBox>,
            "ListBodyParentData should be a ContainerBoxParentData<RenderBox>"
        )
    }
}

// MARK: - RenderListBody Construction Tests

final class RenderListBodyConstructionTests: XCTestCase {

    /// Test default construction with axisDirection = .down.
    func testDefaultConstruction() {
        let listBody = RenderListBody()
        XCTAssertEqual(listBody.axisDirection, .down)
        XCTAssertEqual(listBody.childCount, 0)
        XCTAssertNil(listBody.firstChild)
        XCTAssertNil(listBody.lastChild)
    }

    /// Test construction with a custom axisDirection.
    func testConstructionWithCustomAxisDirection() {
        let listBody = RenderListBody(axisDirection: .right)
        XCTAssertEqual(listBody.axisDirection, .right)
    }

    /// Test construction with children.
    func testConstructionWithChildren() {
        let child1 = RenderBox()
        let child2 = RenderBox()
        let listBody = RenderListBody(children: [child1, child2])
        XCTAssertEqual(listBody.childCount, 2)
        XCTAssertNotNil(listBody.firstChild)
        XCTAssertNotNil(listBody.lastChild)
        XCTAssertTrue(listBody.firstChild === child1)
        // Verify the second child is reachable via childAfter.
        XCTAssertTrue(listBody.childAfter(child1) === child2)
    }

    /// Test construction with nil children.
    func testConstructionWithNilChildren() {
        let listBody = RenderListBody(children: nil)
        XCTAssertEqual(listBody.childCount, 0)
    }

    /// Test construction with all four axis directions.
    func testConstructionWithAllAxisDirections() {
        let directions: [AxisDirection] = [.up, .down, .left, .right]
        for direction in directions {
            let listBody = RenderListBody(axisDirection: direction)
            XCTAssertEqual(
                listBody.axisDirection, direction,
                "Expected axisDirection to be \(direction)"
            )
        }
    }
}

// MARK: - axisDirection Setter Tests

final class RenderListBodyAxisDirectionSetterTests: XCTestCase {

    /// Test that setting axisDirection to a different value triggers markNeedsLayout.
    func testAxisDirectionSetterTriggersLayout() {
        let listBody = RenderListBody(axisDirection: .down)
        // Layout with unbounded main axis (height) and bounded cross axis (width).
        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: .infinity)
        )
        XCTAssertFalse(listBody.needsLayout)

        listBody.axisDirection = .right
        XCTAssertTrue(listBody.needsLayout, "Changing axisDirection should trigger markNeedsLayout")
        XCTAssertEqual(listBody.axisDirection, .right)
    }

    /// Test that setting axisDirection to the same value does NOT trigger layout.
    func testAxisDirectionSetterNoOpOnSameValue() {
        let listBody = RenderListBody(axisDirection: .down)
        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: .infinity)
        )
        XCTAssertFalse(listBody.needsLayout)

        listBody.axisDirection = .down
        XCTAssertFalse(listBody.needsLayout, "Setting same axisDirection should not trigger markNeedsLayout")
    }
}

// MARK: - mainAxis Computed Property Tests

final class RenderListBodyMainAxisTests: XCTestCase {

    /// Test that mainAxis returns .vertical for .down.
    func testMainAxisVerticalForDown() {
        let listBody = RenderListBody(axisDirection: .down)
        XCTAssertEqual(listBody.mainAxis, .vertical)
    }

    /// Test that mainAxis returns .vertical for .up.
    func testMainAxisVerticalForUp() {
        let listBody = RenderListBody(axisDirection: .up)
        XCTAssertEqual(listBody.mainAxis, .vertical)
    }

    /// Test that mainAxis returns .horizontal for .right.
    func testMainAxisHorizontalForRight() {
        let listBody = RenderListBody(axisDirection: .right)
        XCTAssertEqual(listBody.mainAxis, .horizontal)
    }

    /// Test that mainAxis returns .horizontal for .left.
    func testMainAxisHorizontalForLeft() {
        let listBody = RenderListBody(axisDirection: .left)
        XCTAssertEqual(listBody.mainAxis, .horizontal)
    }
}

// MARK: - performLayout .down Tests

final class RenderListBodyPerformLayoutDownTests: XCTestCase {

    /// Test performLayout with .down stacks children vertically with accumulating offsets.
    func testPerformLayoutDown() {
        let child1 = FixedSizeRenderBox(width: 100, height: 30)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let child3 = FixedSizeRenderBox(width: 100, height: 20)
        let listBody = RenderListBody(axisDirection: .down)
        // Insert children manually to ensure correct linked-list order.
        listBody.insert(child1)
        listBody.insert(child2, after: child1)
        listBody.insert(child3, after: child2)

        // Unbounded height (main axis), bounded width (cross axis).
        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: .infinity)
        )

        // Size should be cross-axis width constrained, main-axis sum of children heights.
        XCTAssertEqual(listBody.size.width, 100.0)
        XCTAssertEqual(listBody.size.height, 100.0)  // 30 + 50 + 20

        // Child offsets should accumulate vertically.
        let pd1 = child1.parentData as! ListBodyParentData
        XCTAssertEqual(pd1.offset.dx, 0.0)
        XCTAssertEqual(pd1.offset.dy, 0.0)

        let pd2 = child2.parentData as! ListBodyParentData
        XCTAssertEqual(pd2.offset.dx, 0.0)
        XCTAssertEqual(pd2.offset.dy, 30.0)

        let pd3 = child3.parentData as! ListBodyParentData
        XCTAssertEqual(pd3.offset.dx, 0.0)
        XCTAssertEqual(pd3.offset.dy, 80.0)  // 30 + 50
    }

    /// Test children are laid out with tight cross-axis width constraint.
    func testPerformLayoutDownChildConstraints() {
        let child = FixedSizeRenderBox(width: 200, height: 40)
        let listBody = RenderListBody(
            children: [child],
            axisDirection: .down
        )

        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: 150, minHeight: 0, maxHeight: .infinity)
        )

        // Child should be constrained to cross-axis width of 150.
        XCTAssertEqual(child.size.width, 150.0)
        XCTAssertEqual(child.size.height, 40.0)
    }
}

// MARK: - performLayout .right Tests

final class RenderListBodyPerformLayoutRightTests: XCTestCase {

    /// Test performLayout with .right stacks children horizontally.
    func testPerformLayoutRight() {
        let child1 = FixedSizeRenderBox(width: 40, height: 100)
        let child2 = FixedSizeRenderBox(width: 60, height: 100)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .right
        )

        // Unbounded width (main axis), bounded height (cross axis).
        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 100)
        )

        XCTAssertEqual(listBody.size.width, 100.0)  // 40 + 60
        XCTAssertEqual(listBody.size.height, 100.0)

        let pd1 = child1.parentData as! ListBodyParentData
        XCTAssertEqual(pd1.offset.dx, 0.0)
        XCTAssertEqual(pd1.offset.dy, 0.0)

        let pd2 = child2.parentData as! ListBodyParentData
        XCTAssertEqual(pd2.offset.dx, 40.0)
        XCTAssertEqual(pd2.offset.dy, 0.0)
    }
}

// MARK: - performLayout .up Tests

final class RenderListBodyPerformLayoutUpTests: XCTestCase {

    /// Test performLayout with .up reverses vertical layout.
    func testPerformLayoutUp() {
        let child1 = FixedSizeRenderBox(width: 100, height: 30)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let child3 = FixedSizeRenderBox(width: 100, height: 20)
        let listBody = RenderListBody(axisDirection: .up)
        // Insert children manually to ensure correct linked-list order.
        listBody.insert(child1)
        listBody.insert(child2, after: child1)
        listBody.insert(child3, after: child2)

        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: .infinity)
        )

        // Total height = 30 + 50 + 20 = 100
        XCTAssertEqual(listBody.size.width, 100.0)
        XCTAssertEqual(listBody.size.height, 100.0)

        // For .up, first child in list gets the highest offset (bottom of stack),
        // and last child gets offset near 0 (top).
        // position accumulates each child's height:
        //   child1: position = 30, offset.dy = 100 - 30 = 70
        //   child2: position = 80, offset.dy = 100 - 80 = 20
        //   child3: position = 100, offset.dy = 100 - 100 = 0
        let pd1 = child1.parentData as! ListBodyParentData
        XCTAssertEqual(pd1.offset.dx, 0.0)
        XCTAssertEqual(pd1.offset.dy, 70.0)

        let pd2 = child2.parentData as! ListBodyParentData
        XCTAssertEqual(pd2.offset.dx, 0.0)
        XCTAssertEqual(pd2.offset.dy, 20.0)

        let pd3 = child3.parentData as! ListBodyParentData
        XCTAssertEqual(pd3.offset.dx, 0.0)
        XCTAssertEqual(pd3.offset.dy, 0.0)
    }
}

// MARK: - performLayout .left Tests

final class RenderListBodyPerformLayoutLeftTests: XCTestCase {

    /// Test performLayout with .left reverses horizontal layout.
    func testPerformLayoutLeft() {
        let child1 = FixedSizeRenderBox(width: 40, height: 100)
        let child2 = FixedSizeRenderBox(width: 60, height: 100)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .left
        )

        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 100)
        )

        // Total width = 40 + 60 = 100
        XCTAssertEqual(listBody.size.width, 100.0)
        XCTAssertEqual(listBody.size.height, 100.0)

        // For .left:
        //   child1: position = 40, offset.dx = 100 - 40 = 60
        //   child2: position = 100, offset.dx = 100 - 100 = 0
        let pd1 = child1.parentData as! ListBodyParentData
        XCTAssertEqual(pd1.offset.dx, 60.0)
        XCTAssertEqual(pd1.offset.dy, 0.0)

        let pd2 = child2.parentData as! ListBodyParentData
        XCTAssertEqual(pd2.offset.dx, 0.0)
        XCTAssertEqual(pd2.offset.dy, 0.0)
    }
}

// MARK: - Intrinsic Dimensions Tests

final class RenderListBodyIntrinsicDimensionsTests: XCTestCase {

    /// Test that vertical axis (main=vertical) uses sum for height and max for width.
    func testIntrinsicsVerticalAxis() {
        let child1 = FixedSizeRenderBox(width: 80, height: 30)
        let child2 = FixedSizeRenderBox(width: 120, height: 50)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .down
        )

        // Cross axis (width): max of children = max(80, 120) = 120
        XCTAssertEqual(listBody.computeMinIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(listBody.computeMaxIntrinsicWidth(.infinity), 120.0)

        // Main axis (height): sum of children = 30 + 50 = 80
        XCTAssertEqual(listBody.computeMinIntrinsicHeight(.infinity), 80.0)
        XCTAssertEqual(listBody.computeMaxIntrinsicHeight(.infinity), 80.0)
    }

    /// Test that horizontal axis (main=horizontal) uses sum for width and max for height.
    func testIntrinsicsHorizontalAxis() {
        let child1 = FixedSizeRenderBox(width: 40, height: 80)
        let child2 = FixedSizeRenderBox(width: 60, height: 120)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .right
        )

        // Main axis (width): sum of children = 40 + 60 = 100
        XCTAssertEqual(listBody.computeMinIntrinsicWidth(.infinity), 100.0)
        XCTAssertEqual(listBody.computeMaxIntrinsicWidth(.infinity), 100.0)

        // Cross axis (height): max of children = max(80, 120) = 120
        XCTAssertEqual(listBody.computeMinIntrinsicHeight(.infinity), 120.0)
        XCTAssertEqual(listBody.computeMaxIntrinsicHeight(.infinity), 120.0)
    }

    /// Test intrinsics with .up (still vertical main axis).
    func testIntrinsicsUpDirection() {
        let child1 = FixedSizeRenderBox(width: 50, height: 25)
        let child2 = FixedSizeRenderBox(width: 100, height: 75)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .up
        )

        // Cross axis (width): max = 100
        XCTAssertEqual(listBody.computeMinIntrinsicWidth(.infinity), 100.0)
        // Main axis (height): sum = 25 + 75 = 100
        XCTAssertEqual(listBody.computeMinIntrinsicHeight(.infinity), 100.0)
    }

    /// Test intrinsics with .left (still horizontal main axis).
    func testIntrinsicsLeftDirection() {
        let child1 = FixedSizeRenderBox(width: 40, height: 60)
        let child2 = FixedSizeRenderBox(width: 60, height: 90)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .left
        )

        // Main axis (width): sum = 40 + 60 = 100
        XCTAssertEqual(listBody.computeMinIntrinsicWidth(.infinity), 100.0)
        // Cross axis (height): max = 90
        XCTAssertEqual(listBody.computeMinIntrinsicHeight(.infinity), 90.0)
    }

    /// Test intrinsics with no children returns 0.
    func testIntrinsicsNoChildren() {
        let listBody = RenderListBody(axisDirection: .down)
        XCTAssertEqual(listBody.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(listBody.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(listBody.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(listBody.computeMaxIntrinsicHeight(.infinity), 0.0)
    }

    /// Test intrinsics with no children and horizontal axis.
    func testIntrinsicsNoChildrenHorizontal() {
        let listBody = RenderListBody(axisDirection: .right)
        XCTAssertEqual(listBody.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(listBody.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(listBody.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(listBody.computeMaxIntrinsicHeight(.infinity), 0.0)
    }
}

// MARK: - computeDryLayout Tests

final class RenderListBodyDryLayoutTests: XCTestCase {

    /// Test that computeDryLayout matches performLayout sizing for .down.
    func testDryLayoutMatchesPerformLayoutDown() {
        let child1 = FixedSizeRenderBox(width: 100, height: 30)
        let child2 = FixedSizeRenderBox(width: 100, height: 50)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .down
        )

        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: .infinity
        )
        let drySize = listBody.computeDryLayout(constraints)
        XCTAssertEqual(drySize.width, 100.0)
        XCTAssertEqual(drySize.height, 80.0)  // 30 + 50

        // Now perform actual layout and confirm sizes match.
        listBody.layout(constraints)
        XCTAssertEqual(listBody.size.width, drySize.width)
        XCTAssertEqual(listBody.size.height, drySize.height)
    }

    /// Test that computeDryLayout matches performLayout sizing for .right.
    func testDryLayoutMatchesPerformLayoutRight() {
        let child1 = FixedSizeRenderBox(width: 40, height: 100)
        let child2 = FixedSizeRenderBox(width: 60, height: 100)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .right
        )

        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 100
        )
        let drySize = listBody.computeDryLayout(constraints)
        XCTAssertEqual(drySize.width, 100.0)  // 40 + 60
        XCTAssertEqual(drySize.height, 100.0)

        listBody.layout(constraints)
        XCTAssertEqual(listBody.size.width, drySize.width)
        XCTAssertEqual(listBody.size.height, drySize.height)
    }

    /// Test that computeDryLayout matches performLayout sizing for .up.
    func testDryLayoutMatchesPerformLayoutUp() {
        let child1 = FixedSizeRenderBox(width: 100, height: 25)
        let child2 = FixedSizeRenderBox(width: 100, height: 75)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .up
        )

        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: .infinity
        )
        let drySize = listBody.computeDryLayout(constraints)
        XCTAssertEqual(drySize.width, 100.0)
        XCTAssertEqual(drySize.height, 100.0)  // 25 + 75

        listBody.layout(constraints)
        XCTAssertEqual(listBody.size.width, drySize.width)
        XCTAssertEqual(listBody.size.height, drySize.height)
    }

    /// Test that computeDryLayout matches performLayout sizing for .left.
    func testDryLayoutMatchesPerformLayoutLeft() {
        let child1 = FixedSizeRenderBox(width: 30, height: 100)
        let child2 = FixedSizeRenderBox(width: 70, height: 100)
        let listBody = RenderListBody(
            children: [child1, child2],
            axisDirection: .left
        )

        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 100
        )
        let drySize = listBody.computeDryLayout(constraints)
        XCTAssertEqual(drySize.width, 100.0)  // 30 + 70
        XCTAssertEqual(drySize.height, 100.0)

        listBody.layout(constraints)
        XCTAssertEqual(listBody.size.width, drySize.width)
        XCTAssertEqual(listBody.size.height, drySize.height)
    }

    /// Test computeDryLayout with no children.
    func testDryLayoutNoChildren() {
        let listBody = RenderListBody(axisDirection: .down)
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: .infinity
        )
        let drySize = listBody.computeDryLayout(constraints)
        XCTAssertEqual(drySize.width, 200.0)
        XCTAssertEqual(drySize.height, 0.0)
    }

    /// Test computeDryLayout with no children and horizontal axis.
    func testDryLayoutNoChildrenHorizontal() {
        let listBody = RenderListBody(axisDirection: .right)
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 150
        )
        let drySize = listBody.computeDryLayout(constraints)
        XCTAssertEqual(drySize.width, 0.0)
        XCTAssertEqual(drySize.height, 150.0)
    }
}

// MARK: - No Children Tests

final class RenderListBodyNoChildrenTests: XCTestCase {

    /// Test performLayout with no children for vertical axis.
    func testPerformLayoutNoChildrenVertical() {
        let listBody = RenderListBody(axisDirection: .down)
        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: .infinity)
        )
        XCTAssertEqual(listBody.size.width, 200.0)
        XCTAssertEqual(listBody.size.height, 0.0)
    }

    /// Test performLayout with no children for horizontal axis.
    func testPerformLayoutNoChildrenHorizontal() {
        let listBody = RenderListBody(axisDirection: .right)
        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 150)
        )
        XCTAssertEqual(listBody.size.width, 0.0)
        XCTAssertEqual(listBody.size.height, 150.0)
    }

    /// Test performLayout with no children for .up direction.
    func testPerformLayoutNoChildrenUp() {
        let listBody = RenderListBody(axisDirection: .up)
        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: .infinity)
        )
        XCTAssertEqual(listBody.size.width, 100.0)
        XCTAssertEqual(listBody.size.height, 0.0)
    }

    /// Test performLayout with no children for .left direction.
    func testPerformLayoutNoChildrenLeft() {
        let listBody = RenderListBody(axisDirection: .left)
        listBody.layout(
            BoxConstraints(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 80)
        )
        XCTAssertEqual(listBody.size.width, 0.0)
        XCTAssertEqual(listBody.size.height, 80.0)
    }
}

// MARK: - setupParentData Tests

final class RenderListBodySetupParentDataTests: XCTestCase {

    /// Test that setupParentData installs ListBodyParentData.
    func testSetupParentDataInstallsListBodyParentData() {
        let listBody = RenderListBody()
        let child = RenderBox()
        listBody.setupParentData(child)
        XCTAssertTrue(
            child.parentData is ListBodyParentData,
            "setupParentData should install ListBodyParentData"
        )
    }

    /// Test that setupParentData does not replace existing ListBodyParentData.
    func testSetupParentDataPreservesExisting() {
        let listBody = RenderListBody()
        let child = RenderBox()
        let existingParentData = ListBodyParentData()
        existingParentData.offset = Offset(42.0, 99.0)
        child.parentData = existingParentData
        listBody.setupParentData(child)
        let pd = child.parentData as! ListBodyParentData
        XCTAssertEqual(
            pd.offset.dx, 42.0,
            "setupParentData should not replace existing ListBodyParentData"
        )
        XCTAssertEqual(
            pd.offset.dy, 99.0,
            "setupParentData should not replace existing ListBodyParentData"
        )
    }

    /// Test that inserting a child via insert() sets up ListBodyParentData.
    func testInsertSetsUpParentData() {
        let listBody = RenderListBody()
        let child = RenderBox()
        listBody.insert(child)
        XCTAssertTrue(
            child.parentData is ListBodyParentData,
            "Inserting a child should set up ListBodyParentData"
        )
        XCTAssertEqual(listBody.childCount, 1)
    }

    /// Test that setupParentData replaces non-ListBodyParentData.
    func testSetupParentDataReplacesNonListBodyParentData() {
        let listBody = RenderListBody()
        let child = RenderBox()
        // Set generic ParentData first.
        child.parentData = ParentData()
        listBody.setupParentData(child)
        XCTAssertTrue(
            child.parentData is ListBodyParentData,
            "setupParentData should replace non-ListBodyParentData with ListBodyParentData"
        )
    }
}

// MARK: - Child Management Tests

final class RenderListBodyChildManagementTests: XCTestCase {

    /// Test insert and remove children.
    func testInsertAndRemoveChildren() {
        let listBody = RenderListBody()
        let child1 = RenderBox()
        let child2 = RenderBox()

        // Insert child1 (prepend, no after).
        listBody.insert(child1)
        XCTAssertEqual(listBody.childCount, 1)
        XCTAssertTrue(listBody.firstChild === child1)
        XCTAssertTrue(listBody.lastChild === child1)

        // Insert child2 after child1.
        listBody.insert(child2, after: child1)
        XCTAssertEqual(listBody.childCount, 2)
        XCTAssertTrue(listBody.firstChild === child1)
        XCTAssertTrue(listBody.childAfter(child1) === child2)

        // Remove child1 (firstChild).
        listBody.remove(child1)
        XCTAssertEqual(listBody.childCount, 1)
        XCTAssertTrue(listBody.firstChild === child2)

        // Remove child2.
        listBody.remove(child2)
        XCTAssertEqual(listBody.childCount, 0)
        XCTAssertNil(listBody.firstChild)
    }

    /// Test childAfter and childBefore navigation.
    func testChildNavigation() {
        let listBody = RenderListBody()
        let child1 = RenderBox()
        let child2 = RenderBox()
        let child3 = RenderBox()

        listBody.insert(child1)
        listBody.insert(child2, after: child1)
        listBody.insert(child3, after: child2)

        XCTAssertTrue(listBody.firstChild === child1)
        XCTAssertTrue(listBody.childAfter(child1) === child2)
        XCTAssertTrue(listBody.childAfter(child2) === child3)
        XCTAssertNil(listBody.childAfter(child3))

        XCTAssertNil(listBody.childBefore(child1))
        XCTAssertTrue(listBody.childBefore(child2) === child1)
        XCTAssertTrue(listBody.childBefore(child3) === child2)
    }

    /// Test addAll adds all children to the list.
    func testAddAll() {
        let listBody = RenderListBody()
        let children = [RenderBox(), RenderBox(), RenderBox()]
        listBody.addAll(children)
        XCTAssertEqual(listBody.childCount, 3)
        XCTAssertTrue(listBody.firstChild === children[0])
    }

    /// Test addAll with nil does nothing.
    func testAddAllWithNil() {
        let listBody = RenderListBody()
        listBody.addAll(nil)
        XCTAssertEqual(listBody.childCount, 0)
    }
}

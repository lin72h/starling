// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for CustomLayout types.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/custom_layout_test.dart`

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A concrete subclass of `MultiChildLayoutDelegate` for testing.
///
/// Records calls to `performLayout` and `shouldRelayout`, and allows
/// configuring `shouldRelayout` behavior.
private class TestMultiChildLayoutDelegate: MultiChildLayoutDelegate {
    var performLayoutCalled = false
    var performLayoutSize: Size?
    var shouldRelayoutResult: Bool

    init(relayout: (any Listenable)? = nil, shouldRelayoutResult: Bool = false) {
        self.shouldRelayoutResult = shouldRelayoutResult
        super.init(relayout: relayout)
    }

    override func performLayout(_ size: Size) {
        performLayoutCalled = true
        performLayoutSize = size
    }

    override func shouldRelayout(_ oldDelegate: MultiChildLayoutDelegate) -> Bool {
        return shouldRelayoutResult
    }
}

/// A delegate subclass that overrides `getSize` to return a fixed size.
private class FixedSizeDelegate: MultiChildLayoutDelegate {
    let fixedSize: Size
    let shouldRelayoutResult: Bool

    init(fixedSize: Size, shouldRelayoutResult: Bool = false, relayout: (any Listenable)? = nil) {
        self.fixedSize = fixedSize
        self.shouldRelayoutResult = shouldRelayoutResult
        super.init(relayout: relayout)
    }

    override func getSize(_ constraints: BoxConstraints) -> Size {
        return fixedSize
    }

    override func performLayout(_ size: Size) {
        // No children to lay out in tests.
    }

    override func shouldRelayout(_ oldDelegate: MultiChildLayoutDelegate) -> Bool {
        return shouldRelayoutResult
    }
}

// MARK: - MultiChildLayoutParentData Tests

final class MultiChildLayoutParentDataTests: XCTestCase {

    /// Test that `id` property defaults to nil.
    func testIdDefaultsToNil() {
        let parentData = MultiChildLayoutParentData()
        XCTAssertNil(parentData.id)
    }

    /// Test that `id` property can be set and read back.
    func testIdCanBeSet() {
        let parentData = MultiChildLayoutParentData()
        parentData.id = "testId"
        XCTAssertEqual(parentData.id, "testId")
    }

    /// Test that `id` property accepts integer keys.
    func testIdAcceptsIntegerKey() {
        let parentData = MultiChildLayoutParentData()
        parentData.id = 42
        XCTAssertEqual(parentData.id, 42)
    }

    /// Test that `description` includes the id when set.
    func testDescriptionIncludesId() {
        let parentData = MultiChildLayoutParentData()
        parentData.id = "myChild"
        let desc = parentData.description
        XCTAssertTrue(desc.contains("id="), "Description should contain 'id=', got: \(desc)")
        XCTAssertTrue(desc.contains("myChild"), "Description should contain the id value, got: \(desc)")
    }

    /// Test that `description` includes nil when id is not set.
    func testDescriptionWithNilId() {
        let parentData = MultiChildLayoutParentData()
        let desc = parentData.description
        XCTAssertTrue(desc.contains("id="), "Description should contain 'id=', got: \(desc)")
        XCTAssertTrue(desc.contains("nil"), "Description should contain 'nil' for unset id, got: \(desc)")
    }

    /// Test that `description` includes the offset from BoxParentData.
    func testDescriptionIncludesOffset() {
        let parentData = MultiChildLayoutParentData()
        parentData.offset = Offset(10.0, 20.0)
        parentData.id = "child1"
        let desc = parentData.description
        XCTAssertTrue(desc.contains("offset"), "Description should contain offset info, got: \(desc)")
    }

    /// Test that parent data inherits `ContainerBoxParentData` sibling pointers.
    func testSiblingPointersDefaultToNil() {
        let parentData = MultiChildLayoutParentData()
        XCTAssertNil(parentData.previousSibling)
        XCTAssertNil(parentData.nextSibling)
    }
}

// MARK: - MultiChildLayoutDelegate Tests

final class MultiChildLayoutDelegateTests: XCTestCase {

    /// Test that the default `getSize` returns `constraints.biggest`.
    func testGetSizeDefaultReturnsBiggest() {
        let delegate = TestMultiChildLayoutDelegate()
        let constraints = BoxConstraints(
            minWidth: 10.0, maxWidth: 200.0,
            minHeight: 20.0, maxHeight: 300.0
        )
        let size = delegate.getSize(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test that `getSize` with tight constraints returns the tight size.
    func testGetSizeWithTightConstraints() {
        let delegate = TestMultiChildLayoutDelegate()
        let constraints = BoxConstraints.tight(Size(50.0, 75.0))
        let size = delegate.getSize(constraints)
        XCTAssertEqual(size.width, 50.0)
        XCTAssertEqual(size.height, 75.0)
    }

    /// Test that a custom `getSize` override works.
    func testCustomGetSizeOverride() {
        let delegate = FixedSizeDelegate(fixedSize: Size(100.0, 150.0))
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 500.0,
            minHeight: 0.0, maxHeight: 500.0
        )
        let size = delegate.getSize(constraints)
        XCTAssertEqual(size.width, 100.0)
        XCTAssertEqual(size.height, 150.0)
    }

    /// Test that `shouldRelayout` returns the configured value.
    func testShouldRelayoutReturnsFalse() {
        let delegate = TestMultiChildLayoutDelegate(shouldRelayoutResult: false)
        let oldDelegate = TestMultiChildLayoutDelegate()
        XCTAssertFalse(delegate.shouldRelayout(oldDelegate))
    }

    /// Test that `shouldRelayout` returns true when configured.
    func testShouldRelayoutReturnsTrue() {
        let delegate = TestMultiChildLayoutDelegate(shouldRelayoutResult: true)
        let oldDelegate = TestMultiChildLayoutDelegate()
        XCTAssertTrue(delegate.shouldRelayout(oldDelegate))
    }

    /// Test that `relayout` is nil by default.
    func testRelayoutDefaultsToNil() {
        let delegate = TestMultiChildLayoutDelegate()
        XCTAssertNil(delegate.relayout)
    }

    /// Test that `relayout` stores the provided listenable.
    func testRelayoutStoresListenable() {
        let notifier = ChangeNotifier()
        let delegate = TestMultiChildLayoutDelegate(relayout: notifier)
        XCTAssertNotNil(delegate.relayout)
    }

    /// Test that `description` returns a meaningful string.
    func testDescription() {
        let delegate = TestMultiChildLayoutDelegate()
        let desc = delegate.description
        XCTAssertTrue(
            desc.contains("TestMultiChildLayoutDelegate") || desc.contains("MultiChildLayoutDelegate"),
            "Description should contain class name, got: \(desc)"
        )
    }
}

// MARK: - RenderCustomMultiChildLayoutBox Tests

final class RenderCustomMultiChildLayoutBoxTests: XCTestCase {

    /// Test basic construction with a delegate.
    func testConstruction() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        XCTAssertTrue(renderBox.delegate === delegate)
        XCTAssertEqual(renderBox.childCount, 0)
        XCTAssertNil(renderBox.firstChild)
        XCTAssertNil(renderBox.lastChild)
    }

    /// Test construction with children.
    func testConstructionWithChildren() {
        let delegate = TestMultiChildLayoutDelegate()
        let child1 = RenderBox()
        let child2 = RenderBox()
        let renderBox = RenderCustomMultiChildLayoutBox(
            children: [child1, child2],
            delegate: delegate
        )
        XCTAssertEqual(renderBox.childCount, 2)
        XCTAssertNotNil(renderBox.firstChild)
        XCTAssertNotNil(renderBox.lastChild)
    }

    /// Test that `setupParentData` sets `MultiChildLayoutParentData`.
    func testSetupParentData() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let child = RenderBox()
        renderBox.setupParentData(child)
        XCTAssertTrue(
            child.parentData is MultiChildLayoutParentData,
            "setupParentData should set MultiChildLayoutParentData"
        )
    }

    /// Test that `setupParentData` does not replace existing `MultiChildLayoutParentData`.
    func testSetupParentDataPreservesExisting() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let child = RenderBox()
        let existingParentData = MultiChildLayoutParentData()
        existingParentData.id = "preserved"
        child.parentData = existingParentData
        renderBox.setupParentData(child)
        let pd = child.parentData as! MultiChildLayoutParentData
        XCTAssertEqual(pd.id, "preserved", "setupParentData should not replace existing MultiChildLayoutParentData")
    }

    /// Test that setting the delegate property to the same instance does not trigger markNeedsLayout.
    func testDelegateSetterSameInstance() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        // Force needsLayout to false so we can detect if it changes.
        renderBox.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        XCTAssertFalse(renderBox.needsLayout)

        // Setting the same delegate instance should be a no-op.
        renderBox.delegate = delegate
        XCTAssertFalse(renderBox.needsLayout, "Setting same delegate should not mark needs layout")
    }

    /// Test that setting a different delegate where shouldRelayout returns true triggers markNeedsLayout.
    func testDelegateSetterTriggersRelayoutWhenShouldRelayoutTrue() {
        let oldDelegate = TestMultiChildLayoutDelegate(shouldRelayoutResult: false)
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: oldDelegate)
        renderBox.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        XCTAssertFalse(renderBox.needsLayout)

        let newDelegate = TestMultiChildLayoutDelegate(shouldRelayoutResult: true)
        renderBox.delegate = newDelegate
        XCTAssertTrue(renderBox.needsLayout, "Setting delegate with shouldRelayout=true should mark needs layout")
    }

    /// Test that setting a different delegate where shouldRelayout returns false
    /// does not trigger markNeedsLayout (when same type).
    func testDelegateSetterNoRelayoutWhenShouldRelayoutFalse() {
        let oldDelegate = TestMultiChildLayoutDelegate(shouldRelayoutResult: false)
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: oldDelegate)
        renderBox.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        XCTAssertFalse(renderBox.needsLayout)

        let newDelegate = TestMultiChildLayoutDelegate(shouldRelayoutResult: false)
        renderBox.delegate = newDelegate
        XCTAssertFalse(
            renderBox.needsLayout,
            "Setting delegate with shouldRelayout=false (same type) should not mark needs layout"
        )
    }

    /// Test that setting a delegate of a different type always triggers markNeedsLayout.
    func testDelegateSetterDifferentTypeTriggersRelayout() {
        let oldDelegate = TestMultiChildLayoutDelegate(shouldRelayoutResult: false)
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: oldDelegate)
        renderBox.layout(BoxConstraints.tight(Size(100.0, 100.0)))
        XCTAssertFalse(renderBox.needsLayout)

        let newDelegate = FixedSizeDelegate(fixedSize: Size(50.0, 50.0), shouldRelayoutResult: false)
        renderBox.delegate = newDelegate
        XCTAssertTrue(
            renderBox.needsLayout,
            "Setting delegate of different type should mark needs layout"
        )
    }

    // MARK: - Intrinsic Dimensions

    /// Test `computeMinIntrinsicWidth` with a fixed-size delegate.
    func testComputeMinIntrinsicWidthWithFixedSize() {
        let delegate = FixedSizeDelegate(fixedSize: Size(120.0, 80.0))
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let width = renderBox.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(width, 120.0)
    }

    /// Test `computeMaxIntrinsicWidth` with a fixed-size delegate.
    func testComputeMaxIntrinsicWidthWithFixedSize() {
        let delegate = FixedSizeDelegate(fixedSize: Size(120.0, 80.0))
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let width = renderBox.computeMaxIntrinsicWidth(.infinity)
        XCTAssertEqual(width, 120.0)
    }

    /// Test `computeMinIntrinsicHeight` with a fixed-size delegate.
    func testComputeMinIntrinsicHeightWithFixedSize() {
        let delegate = FixedSizeDelegate(fixedSize: Size(120.0, 80.0))
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let height = renderBox.computeMinIntrinsicHeight(.infinity)
        XCTAssertEqual(height, 80.0)
    }

    /// Test `computeMaxIntrinsicHeight` with a fixed-size delegate.
    func testComputeMaxIntrinsicHeightWithFixedSize() {
        let delegate = FixedSizeDelegate(fixedSize: Size(120.0, 80.0))
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let height = renderBox.computeMaxIntrinsicHeight(.infinity)
        XCTAssertEqual(height, 80.0)
    }

    /// Test intrinsic dimensions return 0.0 when delegate's getSize returns infinite.
    func testIntrinsicDimensionsReturnZeroWhenInfinite() {
        // The default delegate returns constraints.biggest, which will be infinite
        // for unconstrained dimensions.
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        XCTAssertEqual(renderBox.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(renderBox.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(renderBox.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(renderBox.computeMaxIntrinsicHeight(.infinity), 0.0)
    }

    /// Test intrinsic width when a specific height is given.
    func testIntrinsicWidthWithSpecificHeight() {
        let delegate = FixedSizeDelegate(fixedSize: Size(200.0, 100.0))
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        // tightForFinite(height: 100) creates tight height=100, unconstrained width
        // The delegate ignores constraints and returns fixed size,
        // but _getSize constrains the delegate's result.
        // With tightForFinite(height: 100): minWidth=0, maxWidth=inf, minHeight=100, maxHeight=100
        // constrain(Size(200, 100)) => Size(clamp(200, 0, inf), clamp(100, 100, 100)) => Size(200, 100)
        let width = renderBox.computeMinIntrinsicWidth(100.0)
        XCTAssertEqual(width, 200.0)
    }

    /// Test intrinsic height when a specific width is given.
    func testIntrinsicHeightWithSpecificWidth() {
        let delegate = FixedSizeDelegate(fixedSize: Size(200.0, 100.0))
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let height = renderBox.computeMinIntrinsicHeight(200.0)
        XCTAssertEqual(height, 100.0)
    }

    // MARK: - Dry Layout

    /// Test `computeDryLayout` returns the delegate's constrained size.
    func testComputeDryLayout() {
        let delegate = FixedSizeDelegate(fixedSize: Size(150.0, 100.0))
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 200.0,
            minHeight: 0.0, maxHeight: 200.0
        )
        let size = renderBox.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 150.0)
        XCTAssertEqual(size.height, 100.0)
    }

    /// Test `computeDryLayout` constrains the delegate's size to the given constraints.
    func testComputeDryLayoutConstrainsSize() {
        let delegate = FixedSizeDelegate(fixedSize: Size(500.0, 500.0))
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 200.0,
            minHeight: 0.0, maxHeight: 300.0
        )
        let size = renderBox.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 200.0, "Width should be clamped to maxWidth")
        XCTAssertEqual(size.height, 300.0, "Height should be clamped to maxHeight")
    }

    // MARK: - Child Management

    /// Test inserting and removing children using prepend (nil `after`).
    func testInsertAndRemoveChildren() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let child1 = RenderBox()
        let child2 = RenderBox()

        // Insert without `after:` prepends to the front.
        renderBox.insert(child1)
        XCTAssertEqual(renderBox.childCount, 1)
        XCTAssertTrue(renderBox.firstChild === child1)
        XCTAssertTrue(renderBox.lastChild === child1)

        // Prepend child2: child2 -> child1
        renderBox.insert(child2)
        XCTAssertEqual(renderBox.childCount, 2)
        XCTAssertTrue(renderBox.firstChild === child2)
        XCTAssertTrue(renderBox.lastChild === child1)

        // Remove child2 (firstChild): child1 remains
        renderBox.remove(child2)
        XCTAssertEqual(renderBox.childCount, 1)
        XCTAssertTrue(renderBox.firstChild === child1)
        XCTAssertTrue(renderBox.lastChild === child1)

        renderBox.remove(child1)
        XCTAssertEqual(renderBox.childCount, 0)
        XCTAssertNil(renderBox.firstChild)
        XCTAssertNil(renderBox.lastChild)
    }

    /// Test `childAfter` and `childBefore` navigation.
    /// Children are prepended, so inserting c3, c2, c1 in that order gives
    /// the linked list: c1 -> c2 -> c3.
    func testChildNavigaton() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let child1 = RenderBox()
        let child2 = RenderBox()
        let child3 = RenderBox()

        // Prepend in reverse order to get child1 -> child2 -> child3.
        renderBox.insert(child3)
        renderBox.insert(child2)
        renderBox.insert(child1)

        XCTAssertTrue(renderBox.firstChild === child1)
        XCTAssertTrue(renderBox.childAfter(child1) === child2)
        XCTAssertTrue(renderBox.childAfter(child2) === child3)
        XCTAssertNil(renderBox.childAfter(child3))

        XCTAssertNil(renderBox.childBefore(child1))
        XCTAssertTrue(renderBox.childBefore(child2) === child1)
        XCTAssertTrue(renderBox.childBefore(child3) === child2)
    }

    /// Test `addAll` adds all children to the list.
    func testAddAll() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let children = [RenderBox(), RenderBox(), RenderBox()]

        renderBox.addAll(children)
        XCTAssertEqual(renderBox.childCount, 3)
        XCTAssertTrue(renderBox.firstChild === children[0])
    }

    /// Test `addAll` with nil does nothing.
    func testAddAllWithNil() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        renderBox.addAll(nil)
        XCTAssertEqual(renderBox.childCount, 0)
    }

    // MARK: - Attach / Detach

    /// Test attach and detach with pipeline owner.
    func testAttachDetach() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let owner = PipelineOwner()

        XCTAssertFalse(renderBox.attached)

        renderBox.attach(owner)
        XCTAssertTrue(renderBox.attached)

        renderBox.detach()
        XCTAssertFalse(renderBox.attached)
    }

    // MARK: - performLayout Integration

    /// Test that `performLayout` calls the delegate's `performLayout`.
    func testPerformLayoutCallsDelegate() {
        let delegate = TestMultiChildLayoutDelegate()
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let constraints = BoxConstraints.tight(Size(200.0, 300.0))
        renderBox.layout(constraints)

        XCTAssertTrue(delegate.performLayoutCalled, "Delegate's performLayout should have been called")
        XCTAssertEqual(renderBox.size.width, 200.0)
        XCTAssertEqual(renderBox.size.height, 300.0)
    }

    /// Test that `performLayout` passes the correct size to the delegate.
    func testPerformLayoutPassesCorrectSize() {
        let delegate = FixedSizeDelegate(fixedSize: Size(150.0, 100.0))
        let renderBox = RenderCustomMultiChildLayoutBox(delegate: delegate)
        let constraints = BoxConstraints(
            minWidth: 0.0, maxWidth: 200.0,
            minHeight: 0.0, maxHeight: 200.0
        )
        renderBox.layout(constraints)
        XCTAssertEqual(renderBox.size.width, 150.0)
        XCTAssertEqual(renderBox.size.height, 100.0)
    }
}

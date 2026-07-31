// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Flow layout types from the Rendering layer.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/flow_test.dart`

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A concrete RenderBox subclass that implements performLayout by sizing
/// itself to the constraints. Used as a child of RenderFlow in tests.
private class TestRenderBox: RenderBox {
    override func performLayout() {
        size = boxConstraints.constrain(Size(boxConstraints.maxWidth, boxConstraints.maxHeight))
    }

    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(constraints.maxWidth, constraints.maxHeight))
    }
}

/// A concrete subclass of `FlowDelegate` for testing.
///
/// Records calls to `paintChildren` and `shouldRepaint`, and allows
/// configuring `shouldRepaint` and `shouldRelayout` return values.
private class TestFlowDelegate: FlowDelegate {
    var paintChildrenCalled = false
    var shouldRepaintResult = false
    var shouldRelayoutResult = false
    var customSize: Size?
    var childConstraints: BoxConstraints?
    var lastPaintingContext: (any FlowPaintingContext)?

    init(
        repaint: (any Listenable)? = nil,
        shouldRepaintResult: Bool = false,
        shouldRelayoutResult: Bool = false,
        customSize: Size? = nil,
        childConstraints: BoxConstraints? = nil
    ) {
        self.shouldRepaintResult = shouldRepaintResult
        self.shouldRelayoutResult = shouldRelayoutResult
        self.customSize = customSize
        self.childConstraints = childConstraints
        super.init(repaint: repaint)
    }

    override func getSize(_ constraints: BoxConstraints) -> Size {
        return customSize ?? super.getSize(constraints)
    }

    override func getConstraintsForChild(_ i: Int, _ constraints: BoxConstraints) -> BoxConstraints {
        return childConstraints ?? super.getConstraintsForChild(i, constraints)
    }

    override func paintChildren(_ context: any FlowPaintingContext) {
        paintChildrenCalled = true
        lastPaintingContext = context
    }

    override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool {
        return shouldRepaintResult
    }

    override func shouldRelayout(_ oldDelegate: FlowDelegate) -> Bool {
        return shouldRelayoutResult
    }
}

/// A second delegate subclass with a different type, for testing delegate type changes.
private class AltFlowDelegate: FlowDelegate {
    override func paintChildren(_ context: any FlowPaintingContext) {
        // no-op
    }

    override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool {
        return false
    }
}

/// A delegate that paints all children with identity transforms.
private class PaintAllDelegate: FlowDelegate {
    override func paintChildren(_ context: any FlowPaintingContext) {
        for i in 0..<context.childCount {
            context.paintChild(i, transform: Matrix4.identity(), opacity: 1.0)
        }
    }

    override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool {
        return true
    }
}

// MARK: - FlowPaintingContext Protocol Tests

final class FlowPaintingContextProtocolTests: XCTestCase {

    /// Test that FlowPaintingContext requires `size`, `childCount`, `getChildSize`, and `paintChild`.
    ///
    /// We verify this by confirming RenderFlow conforms to the protocol and exposes the required API.
    func testRenderFlowConformsToFlowPaintingContext() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        // RenderFlow is a FlowPaintingContext
        let context: any FlowPaintingContext = renderFlow
        XCTAssertNotNil(context)
    }
}

// MARK: - FlowDelegate Tests

final class FlowDelegateTests: XCTestCase {

    /// Test that the default `getSize` returns `constraints.biggest`.
    ///
    /// **Dart Source:** `flow.dart:80`
    func testGetSizeDefaultReturnsBiggest() {
        let delegate = TestFlowDelegate()
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        XCTAssertEqual(delegate.getSize(constraints), constraints.biggest)
    }

    /// Test that the default `getConstraintsForChild` returns the same constraints.
    ///
    /// **Dart Source:** `flow.dart:95`
    func testGetConstraintsForChildDefaultReturnsConstraints() {
        let delegate = TestFlowDelegate()
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 300)
        let childConstraints = delegate.getConstraintsForChild(0, constraints)
        XCTAssertEqual(childConstraints.minWidth, constraints.minWidth)
        XCTAssertEqual(childConstraints.maxWidth, constraints.maxWidth)
        XCTAssertEqual(childConstraints.minHeight, constraints.minHeight)
        XCTAssertEqual(childConstraints.maxHeight, constraints.maxHeight)
    }

    /// Test that the default `shouldRelayout` returns false.
    ///
    /// **Dart Source:** `flow.dart:119`
    func testShouldRelayoutDefaultReturnsFalse() {
        let delegate = TestFlowDelegate()
        let oldDelegate = TestFlowDelegate()
        XCTAssertFalse(delegate.shouldRelayout(oldDelegate))
    }

    /// Test that a subclass can override `shouldRepaint`.
    ///
    /// **Dart Source:** `flow.dart:134`
    func testShouldRepaintSubclassOverride() {
        let delegate = TestFlowDelegate(shouldRepaintResult: true)
        let oldDelegate = TestFlowDelegate()
        XCTAssertTrue(delegate.shouldRepaint(oldDelegate))
    }

    /// Test that a subclass can override `shouldRepaint` to return false.
    func testShouldRepaintSubclassOverrideFalse() {
        let delegate = TestFlowDelegate(shouldRepaintResult: false)
        let oldDelegate = TestFlowDelegate()
        XCTAssertFalse(delegate.shouldRepaint(oldDelegate))
    }

    /// Test that a subclass can override `paintChildren`.
    ///
    /// **Dart Source:** `flow.dart:113`
    func testPaintChildrenSubclassOverride() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        // Calling paint invokes delegate.paintChildren
        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)
        XCTAssertTrue(delegate.paintChildrenCalled)
    }

    /// Test custom delegate with `repaint` listenable.
    ///
    /// **Dart Source:** `flow.dart:66-68`
    func testDelegateWithRepaintListenable() {
        let notifier = ChangeNotifier()
        let delegate = TestFlowDelegate(repaint: notifier)
        XCTAssertNotNil(delegate.repaint)
    }

    /// Test delegate with nil repaint.
    func testDelegateWithNilRepaint() {
        let delegate = TestFlowDelegate()
        XCTAssertNil(delegate.repaint)
    }

    /// Test custom `getSize` override.
    func testCustomGetSizeOverride() {
        let delegate = TestFlowDelegate(customSize: Size(50, 60))
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        XCTAssertEqual(delegate.getSize(constraints), Size(50, 60))
    }

    /// Test custom `getConstraintsForChild` override.
    func testCustomGetConstraintsForChildOverride() {
        let childConstraints = BoxConstraints.tight(Size(30, 40))
        let delegate = TestFlowDelegate(childConstraints: childConstraints)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        let result = delegate.getConstraintsForChild(0, constraints)
        XCTAssertEqual(result.minWidth, 30)
        XCTAssertEqual(result.maxWidth, 30)
        XCTAssertEqual(result.minHeight, 40)
        XCTAssertEqual(result.maxHeight, 40)
    }
}

// MARK: - FlowParentData Tests

final class FlowParentDataTests: XCTestCase {

    /// Test that FlowParentData can be created.
    func testCreation() {
        let parentData = FlowParentData()
        XCTAssertNotNil(parentData)
    }

    /// Test that `_transform` is initially nil.
    ///
    /// **Dart Source:** `flow.dart:152`
    func testTransformInitiallyNil() {
        let parentData = FlowParentData()
        XCTAssertNil(parentData._transform)
    }

    /// Test that FlowParentData inherits from ContainerBoxParentData.
    func testInheritsFromContainerBoxParentData() {
        let parentData = FlowParentData()
        XCTAssertTrue(parentData is ContainerBoxParentData<RenderBox>)
    }

    /// Test that sibling pointers default to nil.
    func testSiblingPointersDefaultToNil() {
        let parentData = FlowParentData()
        XCTAssertNil(parentData.previousSibling)
        XCTAssertNil(parentData.nextSibling)
    }

    /// Test that offset defaults to zero.
    func testOffsetDefaultsToZero() {
        let parentData = FlowParentData()
        XCTAssertEqual(parentData.offset, Offset.zero)
    }
}

// MARK: - RenderFlow Construction Tests

final class RenderFlowConstructionTests: XCTestCase {

    /// Test basic construction with a delegate.
    ///
    /// **Dart Source:** `flow.dart:188-195`
    func testBasicConstruction() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        XCTAssertTrue(renderFlow.delegate === delegate)
        XCTAssertEqual(renderFlow.clipBehavior, .hardEdge)
        XCTAssertEqual(renderFlow.childCount, 0)
        XCTAssertNil(renderFlow.firstChild)
        XCTAssertNil(renderFlow.lastChild)
    }

    /// Test construction with custom clipBehavior.
    func testConstructionWithClipBehavior() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate, clipBehavior: .antiAlias)
        XCTAssertEqual(renderFlow.clipBehavior, .antiAlias)
    }

    /// Test construction with children.
    func testConstructionWithChildren() {
        let delegate = TestFlowDelegate()
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let renderFlow = RenderFlow(children: [child1, child2], delegate: delegate)
        XCTAssertEqual(renderFlow.childCount, 2)
        XCTAssertNotNil(renderFlow.firstChild)
        XCTAssertNotNil(renderFlow.lastChild)
    }

    /// Test that isRepaintBoundary returns true.
    ///
    /// **Dart Source:** `flow.dart:267`
    func testIsRepaintBoundary() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        XCTAssertTrue(renderFlow.isRepaintBoundary)
    }
}

// MARK: - RenderFlow setupParentData Tests

final class RenderFlowSetupParentDataTests: XCTestCase {

    /// Test that setupParentData creates FlowParentData for a child without parent data.
    ///
    /// **Dart Source:** `flow.dart:198-205`
    func testSetupParentDataCreatesFlowParentData() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        let child = TestRenderBox()
        renderFlow.setupParentData(child)
        XCTAssertTrue(child.parentData is FlowParentData)
    }

    /// Test that setupParentData resets transform on existing FlowParentData.
    func testSetupParentDataResetsTransform() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        let child = TestRenderBox()
        let parentData = FlowParentData()
        parentData._transform = Matrix4.identity()
        child.parentData = parentData
        renderFlow.setupParentData(child)
        let pd = child.parentData as! FlowParentData
        XCTAssertNil(pd._transform)
    }
}

// MARK: - RenderFlow Delegate Setter Tests

final class RenderFlowDelegateSetterTests: XCTestCase {

    /// Test that setting the same delegate instance is a no-op.
    ///
    /// **Dart Source:** `flow.dart:208-234`
    func testSameDelegateInstanceNoOp() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(renderFlow.needsLayout)
        renderFlow.needsPaint = false

        renderFlow.delegate = delegate
        XCTAssertFalse(renderFlow.needsLayout, "Same delegate instance should not trigger layout")
        XCTAssertFalse(renderFlow.needsPaint, "Same delegate instance should not trigger paint")
    }

    /// Test that setting a delegate of a different type triggers markNeedsLayout.
    ///
    /// **Dart Source:** `flow.dart:213-215`
    func testDifferentDelegateTypeTriggersMarkNeedsLayout() {
        let oldDelegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: oldDelegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(renderFlow.needsLayout)

        let newDelegate = AltFlowDelegate()
        renderFlow.delegate = newDelegate
        XCTAssertTrue(renderFlow.needsLayout, "Different delegate type should trigger layout")
    }

    /// Test that same type with shouldRelayout=true triggers markNeedsLayout.
    ///
    /// **Dart Source:** `flow.dart:213-215`
    func testSameTypeWithShouldRelayoutTriggersLayout() {
        let oldDelegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: oldDelegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(renderFlow.needsLayout)

        let newDelegate = TestFlowDelegate(shouldRelayoutResult: true)
        renderFlow.delegate = newDelegate
        XCTAssertTrue(renderFlow.needsLayout, "shouldRelayout=true should trigger layout")
    }

    /// Test that same type with shouldRepaint=true triggers markNeedsPaint.
    ///
    /// **Dart Source:** `flow.dart:216-218`
    func testSameTypeWithShouldRepaintTriggersPaint() {
        let oldDelegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: oldDelegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(renderFlow.needsLayout)
        renderFlow.needsPaint = false

        let newDelegate = TestFlowDelegate(
            shouldRepaintResult: true,
            shouldRelayoutResult: false
        )
        renderFlow.delegate = newDelegate
        XCTAssertFalse(renderFlow.needsLayout, "shouldRelayout=false should not trigger layout")
        XCTAssertTrue(renderFlow.needsPaint, "shouldRepaint=true should trigger paint")
    }

    /// Test that same type with neither shouldRelayout nor shouldRepaint changes nothing.
    func testSameTypeNoRelayoutNorRepaint() {
        let oldDelegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: oldDelegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(renderFlow.needsLayout)
        renderFlow.needsPaint = false

        let newDelegate = TestFlowDelegate(
            shouldRepaintResult: false,
            shouldRelayoutResult: false
        )
        renderFlow.delegate = newDelegate
        XCTAssertFalse(renderFlow.needsLayout)
        XCTAssertFalse(renderFlow.needsPaint)
    }
}

// MARK: - RenderFlow ClipBehavior Tests

final class RenderFlowClipBehaviorTests: XCTestCase {

    /// Test clipBehavior property getter.
    func testClipBehaviorGetter() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate, clipBehavior: .antiAliasWithSaveLayer)
        XCTAssertEqual(renderFlow.clipBehavior, .antiAliasWithSaveLayer)
    }

    /// Test clipBehavior setter triggers markNeedsPaint.
    func testClipBehaviorSetterTriggersPaint() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        renderFlow.needsPaint = false

        renderFlow.clipBehavior = .antiAlias
        XCTAssertTrue(renderFlow.needsPaint, "Changing clipBehavior should trigger paint")
        XCTAssertEqual(renderFlow.clipBehavior, .antiAlias)
    }

    /// Test clipBehavior setter does nothing when set to the same value.
    func testClipBehaviorSetterNoOpOnSameValue() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate, clipBehavior: .hardEdge)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        renderFlow.needsPaint = false

        renderFlow.clipBehavior = .hardEdge
        XCTAssertFalse(renderFlow.needsPaint, "Same clipBehavior should not trigger paint")
    }
}

// MARK: - RenderFlow Intrinsic Dimensions Tests

final class RenderFlowIntrinsicDimensionTests: XCTestCase {

    /// Test computeMinIntrinsicWidth with finite delegate size.
    ///
    /// **Dart Source:** `flow.dart:274-280`
    func testComputeMinIntrinsicWidth() {
        let delegate = TestFlowDelegate(customSize: Size(150, 100))
        let renderFlow = RenderFlow(delegate: delegate)
        let width = renderFlow.computeMinIntrinsicWidth(200)
        XCTAssertEqual(width, 150.0)
    }

    /// Test computeMaxIntrinsicWidth with finite delegate size.
    ///
    /// **Dart Source:** `flow.dart:283-289`
    func testComputeMaxIntrinsicWidth() {
        let delegate = TestFlowDelegate(customSize: Size(150, 100))
        let renderFlow = RenderFlow(delegate: delegate)
        let width = renderFlow.computeMaxIntrinsicWidth(200)
        XCTAssertEqual(width, 150.0)
    }

    /// Test computeMinIntrinsicHeight with finite delegate size.
    ///
    /// **Dart Source:** `flow.dart:292-298`
    func testComputeMinIntrinsicHeight() {
        let delegate = TestFlowDelegate(customSize: Size(150, 100))
        let renderFlow = RenderFlow(delegate: delegate)
        let height = renderFlow.computeMinIntrinsicHeight(200)
        XCTAssertEqual(height, 100.0)
    }

    /// Test computeMaxIntrinsicHeight with finite delegate size.
    ///
    /// **Dart Source:** `flow.dart:300-307`
    func testComputeMaxIntrinsicHeight() {
        let delegate = TestFlowDelegate(customSize: Size(150, 100))
        let renderFlow = RenderFlow(delegate: delegate)
        let height = renderFlow.computeMaxIntrinsicHeight(200)
        XCTAssertEqual(height, 100.0)
    }

    /// Test intrinsic dimensions return 0.0 when delegate returns infinite (default).
    func testIntrinsicDimensionsReturnZeroWhenInfinite() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        XCTAssertEqual(renderFlow.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(renderFlow.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(renderFlow.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(renderFlow.computeMaxIntrinsicHeight(.infinity), 0.0)
    }
}

// MARK: - RenderFlow Dry Layout Tests

final class RenderFlowDryLayoutTests: XCTestCase {

    /// Test computeDryLayout returns the constrained delegate size.
    ///
    /// **Dart Source:** `flow.dart:309-313`
    func testComputeDryLayout() {
        let delegate = TestFlowDelegate(customSize: Size(150, 100))
        let renderFlow = RenderFlow(delegate: delegate)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = renderFlow.computeDryLayout(constraints)
        XCTAssertEqual(size, Size(150, 100))
    }

    /// Test computeDryLayout constrains oversize delegate result.
    func testComputeDryLayoutConstrainsOversizeResult() {
        let delegate = TestFlowDelegate(customSize: Size(500, 500))
        let renderFlow = RenderFlow(delegate: delegate)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        let size = renderFlow.computeDryLayout(constraints)
        XCTAssertEqual(size, Size(200, 300))
    }

    /// Test computeDryLayout with default delegate (biggest).
    func testComputeDryLayoutDefault() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 300)
        let size = renderFlow.computeDryLayout(constraints)
        XCTAssertEqual(size, Size(400, 300))
    }
}

// MARK: - RenderFlow performLayout Tests

final class RenderFlowPerformLayoutTests: XCTestCase {

    /// Test that performLayout sets the size correctly.
    ///
    /// **Dart Source:** `flow.dart:316-331`
    func testPerformLayoutSetsSize() {
        let delegate = TestFlowDelegate(customSize: Size(150, 100))
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(renderFlow.size, Size(150, 100))
    }

    /// Test that children are laid out with delegate constraints.
    func testPerformLayoutChildrenGetDelegateConstraints() {
        let childConstraints = BoxConstraints.tight(Size(50, 50))
        let delegate = TestFlowDelegate(childConstraints: childConstraints)
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        // After layout, child should have been laid out with the delegate's constraints
        XCTAssertEqual(child.size, Size(50, 50))
    }

    /// Test that children's offsets are set to zero.
    func testPerformLayoutChildrenOffsetsSetToZero() {
        let delegate = TestFlowDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        let childParentData = child.parentData as! FlowParentData
        XCTAssertEqual(childParentData.offset, .zero)
    }

    /// Test that _randomAccessChildren is populated during layout.
    func testPerformLayoutPopulatesRandomAccessChildren() {
        let delegate = TestFlowDelegate()
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let renderFlow = RenderFlow(children: [child1, child2], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertEqual(renderFlow._randomAccessChildren.count, 2)
    }

    /// Test performLayout with no children.
    func testPerformLayoutNoChildren() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertEqual(renderFlow.size, Size(100, 100))
        XCTAssertEqual(renderFlow._randomAccessChildren.count, 0)
    }

    /// Test performLayout with multiple children.
    func testPerformLayoutMultipleChildren() {
        let childConstraints = BoxConstraints.tight(Size(30, 40))
        let delegate = TestFlowDelegate(childConstraints: childConstraints)
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let child3 = TestRenderBox()
        let renderFlow = RenderFlow(children: [child1, child2, child3], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertEqual(renderFlow._randomAccessChildren.count, 3)
        XCTAssertEqual(child1.size, Size(30, 40))
        XCTAssertEqual(child2.size, Size(30, 40))
        XCTAssertEqual(child3.size, Size(30, 40))
    }
}

// MARK: - RenderFlow Child Management Tests

final class RenderFlowChildManagementTests: XCTestCase {

    /// Test childCount, firstChild, lastChild with no children.
    func testEmptyState() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        XCTAssertEqual(renderFlow.childCount, 0)
        XCTAssertNil(renderFlow.firstChild)
        XCTAssertNil(renderFlow.lastChild)
    }

    /// Test insert (prepend) and remove.
    func testInsertPrependAndRemove() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()

        // Insert without `after:` prepends to the front
        renderFlow.insert(child1)
        XCTAssertEqual(renderFlow.childCount, 1)
        XCTAssertTrue(renderFlow.firstChild === child1)
        XCTAssertTrue(renderFlow.lastChild === child1)

        // Prepend child2: child2 -> child1
        renderFlow.insert(child2)
        XCTAssertEqual(renderFlow.childCount, 2)
        XCTAssertTrue(renderFlow.firstChild === child2)
        XCTAssertTrue(renderFlow.lastChild === child1)

        // Remove child2 (firstChild): child1 remains
        renderFlow.remove(child2)
        XCTAssertEqual(renderFlow.childCount, 1)
        XCTAssertTrue(renderFlow.firstChild === child1)
        XCTAssertTrue(renderFlow.lastChild === child1)

        renderFlow.remove(child1)
        XCTAssertEqual(renderFlow.childCount, 0)
        XCTAssertNil(renderFlow.firstChild)
        XCTAssertNil(renderFlow.lastChild)
    }

    /// Test addAll with nil does nothing.
    func testAddAllWithNil() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.addAll(nil)
        XCTAssertEqual(renderFlow.childCount, 0)
    }

    /// Test childAfter navigation with prepended children.
    /// Prepending c3, c2, c1 in that order gives: c1 -> c2 -> c3.
    func testChildNavigation() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let child3 = TestRenderBox()

        // Prepend in reverse order to build child1 -> child2 -> child3
        renderFlow.insert(child3)
        renderFlow.insert(child2)
        renderFlow.insert(child1)

        XCTAssertTrue(renderFlow.firstChild === child1)
        XCTAssertTrue(renderFlow.childAfter(child1) === child2)
        XCTAssertTrue(renderFlow.childAfter(child2) === child3)
        XCTAssertNil(renderFlow.childAfter(child3))

        XCTAssertNil(renderFlow.childBefore(child1))
        XCTAssertTrue(renderFlow.childBefore(child2) === child1)
        XCTAssertTrue(renderFlow.childBefore(child3) === child2)
    }

    /// Test insert prepending (without after).
    func testInsertPrepend() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()

        renderFlow.insert(child1)
        renderFlow.insert(child2)  // prepends before child1

        XCTAssertTrue(renderFlow.firstChild === child2)
        XCTAssertTrue(renderFlow.lastChild === child1)
    }

    /// Test childCount updates correctly.
    func testChildCountUpdates() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        XCTAssertEqual(renderFlow.childCount, 0)

        let child1 = TestRenderBox()
        renderFlow.insert(child1)
        XCTAssertEqual(renderFlow.childCount, 1)

        let child2 = TestRenderBox()
        renderFlow.insert(child2)
        XCTAssertEqual(renderFlow.childCount, 2)

        renderFlow.remove(child1)
        XCTAssertEqual(renderFlow.childCount, 1)

        renderFlow.remove(child2)
        XCTAssertEqual(renderFlow.childCount, 0)
    }

    /// Test that construction with children list passes children to the flow.
    func testConstructionWithChildrenSetsCount() {
        let delegate = TestFlowDelegate()
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let child3 = TestRenderBox()
        let renderFlow = RenderFlow(children: [child1, child2, child3], delegate: delegate)
        XCTAssertEqual(renderFlow.childCount, 3)
        XCTAssertNotNil(renderFlow.firstChild)
    }
}

// MARK: - RenderFlow getChildSize Tests

final class RenderFlowGetChildSizeTests: XCTestCase {

    /// Test getChildSize returns correct sizes.
    ///
    /// **Dart Source:** `flow.dart:344-349`
    func testGetChildSizeReturnsCorrectSize() {
        let delegate = TestFlowDelegate()
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let renderFlow = RenderFlow(children: [child1, child2], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        // After layout with tight(100,100) constraints and default delegate
        // returning the same constraints to children, children should be 100x100.
        let size0 = renderFlow.getChildSize(0)
        let size1 = renderFlow.getChildSize(1)
        XCTAssertNotNil(size0)
        XCTAssertNotNil(size1)
        XCTAssertEqual(size0, Size(100, 100))
        XCTAssertEqual(size1, Size(100, 100))
    }

    /// Test getChildSize returns nil for out-of-range index.
    func testGetChildSizeReturnsNilForOutOfRange() {
        let delegate = TestFlowDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        XCTAssertNil(renderFlow.getChildSize(-1))
        XCTAssertNil(renderFlow.getChildSize(1))
        XCTAssertNil(renderFlow.getChildSize(100))
    }

    /// Test getChildSize with custom child constraints.
    func testGetChildSizeWithCustomConstraints() {
        let childConstraints = BoxConstraints.tight(Size(30, 40))
        let delegate = TestFlowDelegate(childConstraints: childConstraints)
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let size = renderFlow.getChildSize(0)
        XCTAssertEqual(size, Size(30, 40))
    }

    /// Test getChildSize with no children returns nil.
    func testGetChildSizeNoChildren() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        XCTAssertNil(renderFlow.getChildSize(0))
    }
}

// MARK: - RenderFlow Paint Tests

final class RenderFlowPaintTests: XCTestCase {

    /// Test that paint calls delegate's paintChildren.
    ///
    /// **Dart Source:** `flow.dart:391-405, 408-417`
    func testPaintCallsDelegatePaintChildren() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)
        XCTAssertTrue(delegate.paintChildrenCalled)
    }

    /// Test that paintChild sets the child's _transform.
    func testPaintChildSetsTransform() {
        let delegate = PaintAllDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        let childParentData = child.parentData as! FlowParentData
        XCTAssertNotNil(childParentData._transform)
    }

    /// Test that paintChild with nil transform sets identity.
    func testPaintChildWithNilTransformSetsIdentity() {
        // Create a delegate that paints with nil transform
        class NilTransformDelegate: FlowDelegate {
            override func paintChildren(_ context: any FlowPaintingContext) {
                for i in 0..<context.childCount {
                    context.paintChild(i, transform: nil, opacity: 1.0)
                }
            }
            override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool { return false }
        }
        let delegate = NilTransformDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        let childParentData = child.parentData as! FlowParentData
        XCTAssertNotNil(childParentData._transform)
        // nil transform becomes identity
        XCTAssertEqual(childParentData._transform, Matrix4.identity())
    }

    /// Test that paintChild with opacity 0 stores the transform but doesn't crash.
    func testPaintChildWithZeroOpacity() {
        class ZeroOpacityDelegate: FlowDelegate {
            override func paintChildren(_ context: any FlowPaintingContext) {
                for i in 0..<context.childCount {
                    context.paintChild(i, transform: Matrix4.identity(), opacity: 0.0)
                }
            }
            override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool { return false }
        }
        let delegate = ZeroOpacityDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        let childParentData = child.parentData as! FlowParentData
        // Even with opacity 0, transform should be set (for hit testing)
        XCTAssertNotNil(childParentData._transform)
    }

    /// Test that _paintWithDelegate clears previous transforms.
    func testPaintClearsPreviousTransforms() {
        let delegate = TestFlowDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        // Set a transform on the child manually
        let childParentData = child.parentData as! FlowParentData
        childParentData._transform = Matrix4.identity()

        // Paint (TestFlowDelegate doesn't paint any children)
        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        // After paint, transforms should be cleared since delegate doesn't paint the child
        XCTAssertNil(childParentData._transform)
    }

    /// Test paint with partial opacity (between 0 and 1).
    func testPaintChildWithPartialOpacity() {
        class HalfOpacityDelegate: FlowDelegate {
            override func paintChildren(_ context: any FlowPaintingContext) {
                for i in 0..<context.childCount {
                    context.paintChild(i, transform: Matrix4.identity(), opacity: 0.5)
                }
            }
            override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool { return false }
        }
        let delegate = HalfOpacityDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        let childParentData = child.parentData as! FlowParentData
        XCTAssertNotNil(childParentData._transform)
        XCTAssertEqual(childParentData._transform, Matrix4.identity())
    }

    /// Test that painting context receives the RenderFlow as the FlowPaintingContext.
    func testPaintingContextReceivedByDelegate() {
        let delegate = TestFlowDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        XCTAssertNotNil(delegate.lastPaintingContext)
        // Verify the painting context provides the correct size and childCount
        XCTAssertEqual(delegate.lastPaintingContext?.size, Size(100, 100))
        XCTAssertEqual(delegate.lastPaintingContext?.childCount, 1)
    }
}

// MARK: - RenderFlow Hit Testing Tests

final class RenderFlowHitTestTests: XCTestCase {

    /// Test hitTestChildren returns false with no children.
    func testHitTestChildrenNoChildren() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        let result = BoxHitTestResult()
        let hit = renderFlow.hitTestChildren(result, position: Offset(50, 50))
        XCTAssertFalse(hit)
    }

    /// Test hitTestChildren returns false when no children were painted.
    func testHitTestChildrenNonePainted() {
        let delegate = TestFlowDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        // TestFlowDelegate doesn't actually paint children
        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        let result = BoxHitTestResult()
        let hit = renderFlow.hitTestChildren(result, position: Offset(50, 50))
        XCTAssertFalse(hit)
    }
}

// MARK: - RenderFlow applyPaintTransform Tests

final class RenderFlowApplyPaintTransformTests: XCTestCase {

    /// Test that paintChild stores the transform in the child's parent data.
    ///
    /// The applyPaintTransform method multiplies the stored transform. We verify
    /// the transform storage here since calling applyPaintTransform directly
    /// requires parent to be set (via adoptChild, not yet available in stubs).
    ///
    /// **Dart Source:** `flow.dart:456-462`
    func testPaintChildStoresTransformForApplyPaintTransform() {
        let delegate = PaintAllDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        // Paint to set transforms
        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        // The child was painted with identity transform, verify it is stored
        let childParentData = child.parentData as! FlowParentData
        XCTAssertNotNil(childParentData._transform)
        XCTAssertEqual(childParentData._transform, Matrix4.identity())
    }

    /// Test that unpainted child has nil transform (no transform to apply).
    func testUnpaintedChildHasNilTransform() {
        let delegate = TestFlowDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        // Paint without painting the child (TestFlowDelegate doesn't paint children)
        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        // No child transform was set
        let childParentData = child.parentData as! FlowParentData
        XCTAssertNil(childParentData._transform)
    }

    /// Test that a translation transform is stored correctly for applyPaintTransform.
    func testTranslationTransformStoredForApplyPaintTransform() {
        class TranslatingDelegate: FlowDelegate {
            override func paintChildren(_ context: any FlowPaintingContext) {
                var transform = Matrix4.identity()
                transform.translate(10.0, 20.0)
                for i in 0..<context.childCount {
                    context.paintChild(i, transform: transform, opacity: 1.0)
                }
            }
            override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool { return true }
        }

        let delegate = TranslatingDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        // Verify the transform was stored
        let childPD = child.parentData as! FlowParentData
        XCTAssertNotNil(childPD._transform)

        // Verify the stored transform is the translation matrix
        var expected = Matrix4.identity()
        expected.translate(10.0, 20.0)
        XCTAssertEqual(childPD._transform, expected)
    }
}

// MARK: - RenderFlow Dispose Tests

final class RenderFlowDisposeTests: XCTestCase {

    /// Test that dispose can be called without error.
    ///
    /// **Dart Source:** `flow.dart:422-425`
    func testDispose() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))
        // Should not crash
        renderFlow.dispose()
    }

    /// Test that dispose on a newly constructed RenderFlow works.
    func testDisposeOnFreshRenderFlow() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        // Should not crash even without layout
        renderFlow.dispose()
    }
}

// MARK: - RenderFlow Attach/Detach Tests

final class RenderFlowAttachDetachTests: XCTestCase {

    /// Test attach and detach work correctly.
    func testAttachDetach() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        let owner = PipelineOwner()

        XCTAssertFalse(renderFlow.attached)

        renderFlow.attach(owner)
        XCTAssertTrue(renderFlow.attached)

        renderFlow.detach()
        XCTAssertFalse(renderFlow.attached)
    }

    /// Test that attach adds repaint listener when delegate has a repaint listenable.
    ///
    /// **Dart Source:** `flow.dart:249-253`
    func testAttachAddsRepaintListener() {
        let notifier = ChangeNotifier()
        let delegate = TestFlowDelegate(repaint: notifier)
        let renderFlow = RenderFlow(delegate: delegate)
        let owner = PipelineOwner()

        XCTAssertFalse(notifier.hasListeners)
        renderFlow.attach(owner)
        XCTAssertTrue(notifier.hasListeners, "Attach should add a listener to the repaint listenable")
    }

    /// Test that detach removes repaint listener.
    ///
    /// **Dart Source:** `flow.dart:255-259`
    func testDetachRemovesRepaintListener() {
        let notifier = ChangeNotifier()
        let delegate = TestFlowDelegate(repaint: notifier)
        let renderFlow = RenderFlow(delegate: delegate)
        let owner = PipelineOwner()

        renderFlow.attach(owner)
        XCTAssertTrue(notifier.hasListeners)

        renderFlow.detach()
        XCTAssertFalse(notifier.hasListeners, "Detach should remove the listener from the repaint listenable")
    }

    /// Test attach without repaint listenable does not crash.
    func testAttachWithoutRepaintListenable() {
        let delegate = TestFlowDelegate()
        let renderFlow = RenderFlow(delegate: delegate)
        let owner = PipelineOwner()

        // Should not crash
        renderFlow.attach(owner)
        XCTAssertTrue(renderFlow.attached)
        renderFlow.detach()
        XCTAssertFalse(renderFlow.attached)
    }

    /// Test that delegate setter updates repaint listener when attached.
    ///
    /// **Dart Source:** `flow.dart:220-223`
    func testDelegateSetterUpdatesRepaintListenerWhenAttached() {
        let notifier1 = ChangeNotifier()
        let notifier2 = ChangeNotifier()
        let delegate1 = TestFlowDelegate(repaint: notifier1)
        let delegate2 = TestFlowDelegate(repaint: notifier2, shouldRepaintResult: true)
        let renderFlow = RenderFlow(delegate: delegate1)
        let owner = PipelineOwner()

        renderFlow.attach(owner)
        XCTAssertTrue(notifier1.hasListeners)
        XCTAssertFalse(notifier2.hasListeners)

        renderFlow.delegate = delegate2
        XCTAssertFalse(notifier1.hasListeners, "Old delegate's listener should be removed")
        XCTAssertTrue(notifier2.hasListeners, "New delegate's listener should be added")
    }

    /// Test that attach/detach cycle can be repeated.
    func testRepeatedAttachDetach() {
        let notifier = ChangeNotifier()
        let delegate = TestFlowDelegate(repaint: notifier)
        let renderFlow = RenderFlow(delegate: delegate)
        let owner = PipelineOwner()

        renderFlow.attach(owner)
        XCTAssertTrue(notifier.hasListeners)
        renderFlow.detach()
        XCTAssertFalse(notifier.hasListeners)

        renderFlow.attach(owner)
        XCTAssertTrue(notifier.hasListeners)
        renderFlow.detach()
        XCTAssertFalse(notifier.hasListeners)
    }
}

// MARK: - FlowPaintingContext Default Extensions Tests

final class FlowPaintingContextDefaultExtensionsTests: XCTestCase {

    /// Test the default parameter convenience methods on FlowPaintingContext.
    ///
    /// **Dart Source:** `flow.dart:49`
    func testDefaultParameterExtensions() {
        // We verify that the convenience methods exist and compile.
        // We test via the PaintAllDelegate which calls paintChild with all params.
        let delegate = PaintAllDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        // This invokes paintChild(0, transform:, opacity:) via the delegate
        renderFlow.paint(context, .zero)

        let childParentData = child.parentData as! FlowParentData
        XCTAssertNotNil(childParentData._transform)
    }

    /// Test the convenience paintChild(_ i:) overload (no transform, full opacity).
    func testPaintChildConvenienceNoArgs() {
        class DefaultArgsDelegate: FlowDelegate {
            override func paintChildren(_ context: any FlowPaintingContext) {
                for i in 0..<context.childCount {
                    context.paintChild(i)
                }
            }
            override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool { return false }
        }
        let delegate = DefaultArgsDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        let childParentData = child.parentData as! FlowParentData
        // paintChild(i) calls paintChild(i, transform: nil, opacity: 1.0)
        // which sets transform to identity
        XCTAssertNotNil(childParentData._transform)
        XCTAssertEqual(childParentData._transform, Matrix4.identity())
    }

    /// Test the convenience paintChild(_ i:, transform:) overload (transform only, full opacity).
    func testPaintChildConvenienceTransformOnly() {
        class TransformOnlyDelegate: FlowDelegate {
            override func paintChildren(_ context: any FlowPaintingContext) {
                for i in 0..<context.childCount {
                    context.paintChild(i, transform: Matrix4.identity())
                }
            }
            override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool { return false }
        }
        let delegate = TransformOnlyDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        let childParentData = child.parentData as! FlowParentData
        XCTAssertNotNil(childParentData._transform)
        XCTAssertEqual(childParentData._transform, Matrix4.identity())
    }

    /// Test the convenience paintChild(_ i:, opacity:) overload (no transform, custom opacity).
    func testPaintChildConvenienceOpacityOnly() {
        class OpacityOnlyDelegate: FlowDelegate {
            override func paintChildren(_ context: any FlowPaintingContext) {
                for i in 0..<context.childCount {
                    context.paintChild(i, opacity: 0.5)
                }
            }
            override func shouldRepaint(_ oldDelegate: FlowDelegate) -> Bool { return false }
        }
        let delegate = OpacityOnlyDelegate()
        let child = TestRenderBox()
        let renderFlow = RenderFlow(children: [child], delegate: delegate)
        renderFlow.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderFlow.paint(context, .zero)

        let childParentData = child.parentData as! FlowParentData
        // paintChild(i, opacity: 0.5) calls paintChild(i, transform: nil, opacity: 0.5)
        // nil transform becomes identity
        XCTAssertNotNil(childParentData._transform)
        XCTAssertEqual(childParentData._transform, Matrix4.identity())
    }
}

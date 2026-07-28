// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Stack layout types from the Rendering layer.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/stack_test.dart`

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A concrete RenderBox subclass that implements performLayout by sizing
/// itself to a fixed size constrained by the parent constraints.
/// Used as a child of RenderStack in tests.
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
        return constraints.constrain(fixedSize)
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

/// A TestRenderBox that reports itself as hittable (hitTestSelf returns true).
/// Used for hit testing scenarios where we need the child to register a hit.
private class HittableTestRenderBox: TestRenderBox {
    override func hitTestSelf(_ position: Offset) -> Bool {
        return true
    }
}

// MARK: - RelativeRect Construction Tests

final class RelativeRectConstructionTests: XCTestCase {

    /// Test that `fill` constant has all zeros.
    func testFillConstant() {
        let fill = RelativeRect.fill
        XCTAssertEqual(fill.left, 0.0)
        XCTAssertEqual(fill.top, 0.0)
        XCTAssertEqual(fill.right, 0.0)
        XCTAssertEqual(fill.bottom, 0.0)
    }

    /// Test `fromLTRB` factory method.
    func testFromLTRB() {
        let rect = RelativeRect.fromLTRB(10, 20, 30, 40)
        XCTAssertEqual(rect.left, 10.0)
        XCTAssertEqual(rect.top, 20.0)
        XCTAssertEqual(rect.right, 30.0)
        XCTAssertEqual(rect.bottom, 40.0)
    }

    /// Test `fromSize` factory method.
    ///
    /// Given a Rect and a container Size, the RelativeRect should have
    /// left = rect.left, top = rect.top,
    /// right = container.width - rect.right,
    /// bottom = container.height - rect.bottom.
    func testFromSize() {
        let innerRect = Rect.fromLTRB(10, 20, 80, 70)
        let containerSize = Size(100, 100)
        let rel = RelativeRect.fromSize(innerRect, containerSize)
        XCTAssertEqual(rel.left, 10.0)
        XCTAssertEqual(rel.top, 20.0)
        XCTAssertEqual(rel.right, 20.0)   // 100 - 80
        XCTAssertEqual(rel.bottom, 30.0)  // 100 - 70
    }

    /// Test `fromRect` factory method.
    ///
    /// Given a Rect and a container Rect, the RelativeRect should be
    /// computed relative to the container's edges.
    func testFromRect() {
        let innerRect = Rect.fromLTRB(110, 120, 180, 170)
        let containerRect = Rect.fromLTRB(100, 100, 200, 200)
        let rel = RelativeRect.fromRect(innerRect, containerRect)
        XCTAssertEqual(rel.left, 10.0)    // 110 - 100
        XCTAssertEqual(rel.top, 20.0)     // 120 - 100
        XCTAssertEqual(rel.right, 20.0)   // 200 - 180
        XCTAssertEqual(rel.bottom, 30.0)  // 200 - 170
    }

    /// Test `fromDirectional` with LTR text direction.
    func testFromDirectionalLTR() {
        let rel = RelativeRect.fromDirectional(
            textDirection: .ltr,
            start: 10, top: 20, end: 30, bottom: 40
        )
        // LTR: start -> left, end -> right
        XCTAssertEqual(rel.left, 10.0)
        XCTAssertEqual(rel.top, 20.0)
        XCTAssertEqual(rel.right, 30.0)
        XCTAssertEqual(rel.bottom, 40.0)
    }

    /// Test `fromDirectional` with RTL text direction.
    func testFromDirectionalRTL() {
        let rel = RelativeRect.fromDirectional(
            textDirection: .rtl,
            start: 10, top: 20, end: 30, bottom: 40
        )
        // RTL: start -> right, end -> left
        XCTAssertEqual(rel.left, 30.0)
        XCTAssertEqual(rel.top, 20.0)
        XCTAssertEqual(rel.right, 10.0)
        XCTAssertEqual(rel.bottom, 40.0)
    }
}

// MARK: - RelativeRect Methods Tests

final class RelativeRectMethodsTests: XCTestCase {

    /// Test `shift` method moves left/top by offset and right/bottom in reverse.
    func testShift() {
        let rect = RelativeRect.fromLTRB(10, 20, 30, 40)
        let shifted = rect.shift(Offset(5, 10))
        XCTAssertEqual(shifted.left, 15.0)   // 10 + 5
        XCTAssertEqual(shifted.top, 30.0)    // 20 + 10
        XCTAssertEqual(shifted.right, 25.0)  // 30 - 5
        XCTAssertEqual(shifted.bottom, 30.0) // 40 - 10
    }

    /// Test `inflate` method moves all edges outward by the delta.
    func testInflate() {
        let rect = RelativeRect.fromLTRB(10, 20, 30, 40)
        let inflated = rect.inflate(5)
        XCTAssertEqual(inflated.left, 5.0)    // 10 - 5
        XCTAssertEqual(inflated.top, 15.0)    // 20 - 5
        XCTAssertEqual(inflated.right, 25.0)  // 30 - 5
        XCTAssertEqual(inflated.bottom, 35.0) // 40 - 5
    }

    /// Test `deflate` method moves all edges inward by the delta.
    func testDeflate() {
        let rect = RelativeRect.fromLTRB(10, 20, 30, 40)
        let deflated = rect.deflate(5)
        XCTAssertEqual(deflated.left, 15.0)   // 10 + 5
        XCTAssertEqual(deflated.top, 25.0)    // 20 + 5
        XCTAssertEqual(deflated.right, 35.0)  // 30 + 5
        XCTAssertEqual(deflated.bottom, 45.0) // 40 + 5
    }

    /// Test `intersect` method returns the max of each edge.
    func testIntersect() {
        let a = RelativeRect.fromLTRB(10, 20, 30, 40)
        let b = RelativeRect.fromLTRB(15, 5, 25, 50)
        let result = a.intersect(b)
        XCTAssertEqual(result.left, 15.0)
        XCTAssertEqual(result.top, 20.0)
        XCTAssertEqual(result.right, 30.0)
        XCTAssertEqual(result.bottom, 50.0)
    }

    /// Test `toRect` converts to a Rect in the container's coordinate space.
    func testToRect() {
        let rect = RelativeRect.fromLTRB(10, 20, 30, 40)
        let container = Rect.fromLTWH(0, 0, 200, 300)
        let result = rect.toRect(container)
        XCTAssertEqual(result.left, 10.0)
        XCTAssertEqual(result.top, 20.0)
        XCTAssertEqual(result.right, 170.0)   // 200 - 30
        XCTAssertEqual(result.bottom, 260.0)  // 300 - 40
    }

    /// Test `toSize` converts to a Size based on the container size.
    func testToSize() {
        let rect = RelativeRect.fromLTRB(10, 20, 30, 40)
        let containerSize = Size(200, 300)
        let result = rect.toSize(containerSize)
        XCTAssertEqual(result.width, 160.0)   // 200 - 10 - 30
        XCTAssertEqual(result.height, 240.0)  // 300 - 20 - 40
    }

    /// Test `hasInsets` returns true when any edge is positive.
    func testHasInsetsTrue() {
        let rect = RelativeRect.fromLTRB(1, 0, 0, 0)
        XCTAssertTrue(rect.hasInsets)
    }

    /// Test `hasInsets` returns false when all edges are zero or negative.
    func testHasInsetsFalse() {
        let rect = RelativeRect.fromLTRB(0, 0, 0, 0)
        XCTAssertFalse(rect.hasInsets)

        let rectNeg = RelativeRect.fromLTRB(-1, -2, -3, -4)
        XCTAssertFalse(rectNeg.hasInsets)
    }
}

// MARK: - RelativeRect Lerp Tests

final class RelativeRectLerpTests: XCTestCase {

    /// Test lerp with both nil returns nil.
    func testLerpBothNil() {
        let result = RelativeRect.lerp(nil, nil, 0.5)
        XCTAssertNil(result)
    }

    /// Test lerp with a nil interpolates from fill.
    func testLerpANil() {
        let b = RelativeRect.fromLTRB(10, 20, 30, 40)
        let result = RelativeRect.lerp(nil, b, 0.5)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.left, 5.0)    // 10 * 0.5
        XCTAssertEqual(result!.top, 10.0)    // 20 * 0.5
        XCTAssertEqual(result!.right, 15.0)  // 30 * 0.5
        XCTAssertEqual(result!.bottom, 20.0) // 40 * 0.5
    }

    /// Test lerp with b nil interpolates toward fill.
    func testLerpBNil() {
        let a = RelativeRect.fromLTRB(10, 20, 30, 40)
        let result = RelativeRect.lerp(a, nil, 0.5)
        XCTAssertNotNil(result)
        let k = 0.5 // 1.0 - 0.5
        XCTAssertEqual(result!.left, 10 * k)
        XCTAssertEqual(result!.top, 20 * k)
        XCTAssertEqual(result!.right, 30 * k)
        XCTAssertEqual(result!.bottom, 40 * k)
    }

    /// Test lerp with both non-nil values.
    func testLerpBothNonNil() {
        let a = RelativeRect.fromLTRB(0, 0, 0, 0)
        let b = RelativeRect.fromLTRB(10, 20, 30, 40)
        let result = RelativeRect.lerp(a, b, 0.5)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.left, 5.0)
        XCTAssertEqual(result!.top, 10.0)
        XCTAssertEqual(result!.right, 15.0)
        XCTAssertEqual(result!.bottom, 20.0)
    }

    /// Test lerp with identical values returns the same value.
    func testLerpIdentical() {
        let a = RelativeRect.fromLTRB(10, 20, 30, 40)
        let result = RelativeRect.lerp(a, a, 0.5)
        XCTAssertEqual(result, a)
    }

    /// Test lerp at t=0 returns a.
    func testLerpAtZero() {
        let a = RelativeRect.fromLTRB(10, 20, 30, 40)
        let b = RelativeRect.fromLTRB(50, 60, 70, 80)
        let result = RelativeRect.lerp(a, b, 0.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.left, 10.0)
        XCTAssertEqual(result!.top, 20.0)
        XCTAssertEqual(result!.right, 30.0)
        XCTAssertEqual(result!.bottom, 40.0)
    }

    /// Test lerp at t=1 returns b.
    func testLerpAtOne() {
        let a = RelativeRect.fromLTRB(10, 20, 30, 40)
        let b = RelativeRect.fromLTRB(50, 60, 70, 80)
        let result = RelativeRect.lerp(a, b, 1.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.left, 50.0)
        XCTAssertEqual(result!.top, 60.0)
        XCTAssertEqual(result!.right, 70.0)
        XCTAssertEqual(result!.bottom, 80.0)
    }
}

// MARK: - RelativeRect Equatable and Description Tests

final class RelativeRectEqualityTests: XCTestCase {

    /// Test Equatable conformance.
    func testEquatable() {
        let a = RelativeRect.fromLTRB(10, 20, 30, 40)
        let b = RelativeRect.fromLTRB(10, 20, 30, 40)
        let c = RelativeRect.fromLTRB(10, 20, 30, 41)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// Test CustomStringConvertible description.
    func testDescription() {
        let rect = RelativeRect.fromLTRB(1.0, 2.0, 3.0, 4.0)
        let desc = rect.description
        XCTAssertEqual(desc, "RelativeRect.fromLTRB(1.0, 2.0, 3.0, 4.0)")
    }

    /// Test fill description.
    func testFillDescription() {
        let desc = RelativeRect.fill.description
        XCTAssertEqual(desc, "RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0)")
    }
}

// MARK: - StackParentData Tests

final class StackParentDataTests: XCTestCase {

    /// Test default values are all nil.
    func testDefaultValues() {
        let pd = StackParentData()
        XCTAssertNil(pd.top)
        XCTAssertNil(pd.right)
        XCTAssertNil(pd.bottom)
        XCTAssertNil(pd.left)
        XCTAssertNil(pd.width)
        XCTAssertNil(pd.height)
    }

    /// Test `isPositioned` returns false when all values are nil.
    func testIsPositionedFalseWhenAllNil() {
        let pd = StackParentData()
        XCTAssertFalse(pd.isPositioned)
    }

    /// Test `isPositioned` returns true when only `top` is set.
    func testIsPositionedTrueWithTopOnly() {
        let pd = StackParentData()
        pd.top = 10.0
        XCTAssertTrue(pd.isPositioned)
    }

    /// Test `isPositioned` returns true when only `left` is set.
    func testIsPositionedTrueWithLeftOnly() {
        let pd = StackParentData()
        pd.left = 5.0
        XCTAssertTrue(pd.isPositioned)
    }

    /// Test `isPositioned` returns true when only `width` is set.
    func testIsPositionedTrueWithWidthOnly() {
        let pd = StackParentData()
        pd.width = 50.0
        XCTAssertTrue(pd.isPositioned)
    }

    /// Test `isPositioned` returns true when only `height` is set.
    func testIsPositionedTrueWithHeightOnly() {
        let pd = StackParentData()
        pd.height = 60.0
        XCTAssertTrue(pd.isPositioned)
    }

    /// Test `isPositioned` returns true when all values are set.
    func testIsPositionedTrueWithAllSet() {
        let pd = StackParentData()
        pd.top = 10
        pd.right = 20
        pd.bottom = 30
        pd.left = 40
        pd.width = 50
        pd.height = 60
        XCTAssertTrue(pd.isPositioned)
    }

    /// Test `rect` getter returns a RelativeRect from the position values.
    func testRectGetter() {
        let pd = StackParentData()
        pd.left = 10
        pd.top = 20
        pd.right = 30
        pd.bottom = 40
        let rect = pd.rect
        XCTAssertEqual(rect, RelativeRect.fromLTRB(10, 20, 30, 40))
    }

    /// Test `rect` setter sets all position values.
    func testRectSetter() {
        let pd = StackParentData()
        pd.rect = RelativeRect.fromLTRB(10, 20, 30, 40)
        XCTAssertEqual(pd.left, 10.0)
        XCTAssertEqual(pd.top, 20.0)
        XCTAssertEqual(pd.right, 30.0)
        XCTAssertEqual(pd.bottom, 40.0)
    }

    /// Test `positionedChildConstraints` with both left and right set.
    func testPositionedChildConstraintsWithLeftAndRight() {
        let pd = StackParentData()
        pd.left = 10
        pd.right = 20
        let constraints = pd.positionedChildConstraints(Size(200, 300))
        // width = 200 - 20 - 10 = 170
        XCTAssertEqual(constraints.minWidth, 170.0)
        XCTAssertEqual(constraints.maxWidth, 170.0)
        // height is unconstrained (only left/right set)
        XCTAssertEqual(constraints.minHeight, 0.0)
        XCTAssertEqual(constraints.maxHeight, .infinity)
    }

    /// Test `positionedChildConstraints` with both top and bottom set.
    func testPositionedChildConstraintsWithTopAndBottom() {
        let pd = StackParentData()
        pd.top = 10
        pd.bottom = 20
        let constraints = pd.positionedChildConstraints(Size(200, 300))
        // width is unconstrained (only top/bottom set)
        XCTAssertEqual(constraints.minWidth, 0.0)
        XCTAssertEqual(constraints.maxWidth, .infinity)
        // height = 300 - 20 - 10 = 270
        XCTAssertEqual(constraints.minHeight, 270.0)
        XCTAssertEqual(constraints.maxHeight, 270.0)
    }

    /// Test `positionedChildConstraints` with explicit width.
    func testPositionedChildConstraintsWithExplicitWidth() {
        let pd = StackParentData()
        pd.left = 10
        pd.width = 50
        let constraints = pd.positionedChildConstraints(Size(200, 300))
        // Only left + width (no right) so width = 50
        XCTAssertEqual(constraints.minWidth, 50.0)
        XCTAssertEqual(constraints.maxWidth, 50.0)
    }

    /// Test `positionedChildConstraints` with explicit height.
    func testPositionedChildConstraintsWithExplicitHeight() {
        let pd = StackParentData()
        pd.top = 10
        pd.height = 80
        let constraints = pd.positionedChildConstraints(Size(200, 300))
        // Only top + height (no bottom) so height = 80
        XCTAssertEqual(constraints.minHeight, 80.0)
        XCTAssertEqual(constraints.maxHeight, 80.0)
    }

    /// Test description when not positioned.
    func testDescriptionNotPositioned() {
        let pd = StackParentData()
        XCTAssertTrue(pd.description.contains("not positioned"))
    }

    /// Test description when positioned.
    func testDescriptionPositioned() {
        let pd = StackParentData()
        pd.top = 10
        pd.left = 20
        let desc = pd.description
        XCTAssertTrue(desc.contains("top="))
        XCTAssertTrue(desc.contains("left="))
        XCTAssertFalse(desc.contains("not positioned"))
    }
}

// MARK: - StackFit Enum Tests

final class StackFitTests: XCTestCase {

    /// Test that all three cases exist.
    func testAllCasesExist() {
        let loose = StackFit.loose
        let expand = StackFit.expand
        let passthrough = StackFit.passthrough
        XCTAssertNotNil(loose)
        XCTAssertNotNil(expand)
        XCTAssertNotNil(passthrough)
    }

    /// Test that the cases are distinct.
    func testCasesAreDistinct() {
        XCTAssertTrue(StackFit.loose != StackFit.expand)
        XCTAssertTrue(StackFit.loose != StackFit.passthrough)
        XCTAssertTrue(StackFit.expand != StackFit.passthrough)
    }
}

// MARK: - RenderStack Construction Tests

final class RenderStackConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let stack = RenderStack()
        XCTAssertEqual(stack.childCount, 0)
        XCTAssertNil(stack.firstChild)
        XCTAssertNil(stack.lastChild)
        XCTAssertEqual(stack.clipBehavior, .hardEdge)
        XCTAssertNil(stack.textDirection)
    }

    /// Test construction with custom parameters.
    func testConstructionWithCustomParameters() {
        let stack = RenderStack(
            alignment: Alignment.center,
            textDirection: .ltr,
            fit: .expand,
            clipBehavior: .antiAlias
        )
        XCTAssertEqual(stack.clipBehavior, .antiAlias)
        XCTAssertEqual(stack.textDirection, .ltr)
    }

    /// Test construction with children.
    func testConstructionWithChildren() {
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let stack = RenderStack(children: [child1, child2], textDirection: .ltr)
        XCTAssertEqual(stack.childCount, 2)
        XCTAssertNotNil(stack.firstChild)
        XCTAssertNotNil(stack.lastChild)
    }
}

// MARK: - RenderStack Child Management Tests

final class RenderStackChildManagementTests: XCTestCase {

    /// Test insert (prepend) and remove.
    func testInsertPrependAndRemove() {
        let stack = RenderStack(textDirection: .ltr)
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()

        // Insert without `after:` prepends to the front
        stack.insert(child1)
        XCTAssertEqual(stack.childCount, 1)
        XCTAssertTrue(stack.firstChild === child1)
        XCTAssertTrue(stack.lastChild === child1)

        // Prepend child2: child2 -> child1
        stack.insert(child2)
        XCTAssertEqual(stack.childCount, 2)
        XCTAssertTrue(stack.firstChild === child2)
        XCTAssertTrue(stack.lastChild === child1)

        // Remove child2 (firstChild): child1 remains
        stack.remove(child2)
        XCTAssertEqual(stack.childCount, 1)
        XCTAssertTrue(stack.firstChild === child1)
        XCTAssertTrue(stack.lastChild === child1)

        stack.remove(child1)
        XCTAssertEqual(stack.childCount, 0)
        XCTAssertNil(stack.firstChild)
        XCTAssertNil(stack.lastChild)
    }

    /// Test addAll populates children.
    func testAddAll() {
        let stack = RenderStack(textDirection: .ltr)
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let child3 = TestRenderBox()
        stack.addAll([child1, child2, child3])
        XCTAssertEqual(stack.childCount, 3)
        // addAll calls insert(child, after: lastChild) for each.
        // First child is prepended (after=nil), subsequent are inserted after lastChild.
        XCTAssertNotNil(stack.firstChild)
        XCTAssertNotNil(stack.lastChild)
    }

    /// Test addAll with nil does nothing.
    func testAddAllNil() {
        let stack = RenderStack(textDirection: .ltr)
        stack.addAll(nil)
        XCTAssertEqual(stack.childCount, 0)
    }

    /// Test child navigation with prepended children.
    /// Prepending c3, c2, c1 in that order gives: c1 -> c2 -> c3.
    func testChildNavigation() {
        let stack = RenderStack(textDirection: .ltr)
        let child1 = TestRenderBox()
        let child2 = TestRenderBox()
        let child3 = TestRenderBox()

        // Prepend in reverse order to build child1 -> child2 -> child3
        stack.insert(child3)
        stack.insert(child2)
        stack.insert(child1)

        XCTAssertTrue(stack.firstChild === child1)
        XCTAssertTrue(stack.childAfter(child1) === child2)
        XCTAssertTrue(stack.childAfter(child2) === child3)
        XCTAssertNil(stack.childAfter(child3))

        XCTAssertNil(stack.childBefore(child1))
        XCTAssertTrue(stack.childBefore(child2) === child1)
        XCTAssertTrue(stack.childBefore(child3) === child2)
    }
}

// MARK: - RenderStack setupParentData Tests

final class RenderStackSetupParentDataTests: XCTestCase {

    /// Test that setupParentData creates StackParentData.
    func testSetupParentDataCreatesStackParentData() {
        let stack = RenderStack(textDirection: .ltr)
        let child = TestRenderBox()
        stack.setupParentData(child)
        XCTAssertTrue(child.parentData is StackParentData)
    }

    /// Test that setupParentData does not replace existing StackParentData.
    func testSetupParentDataPreservesExistingStackParentData() {
        let stack = RenderStack(textDirection: .ltr)
        let child = TestRenderBox()
        let existingData = StackParentData()
        existingData.top = 42.0
        child.parentData = existingData
        stack.setupParentData(child)
        // Should still be the same instance since it's already StackParentData
        XCTAssertTrue(child.parentData === existingData)
        XCTAssertEqual((child.parentData as! StackParentData).top, 42.0)
    }
}

// MARK: - RenderStack Property Setter Tests

final class RenderStackPropertySetterTests: XCTestCase {

    /// Test that setting `fit` triggers markNeedsLayout.
    func testFitSetterTriggersLayout() {
        let stack = RenderStack(textDirection: .ltr, fit: .loose)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(stack.needsLayout)

        stack.fit = .expand
        XCTAssertTrue(stack.needsLayout)
    }

    /// Test that setting `fit` to the same value does not trigger layout.
    func testFitSetterNoOpOnSameValue() {
        let stack = RenderStack(textDirection: .ltr, fit: .loose)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(stack.needsLayout)

        stack.fit = .loose
        XCTAssertFalse(stack.needsLayout)
    }

    /// Test that setting `clipBehavior` triggers markNeedsPaint.
    func testClipBehaviorSetterTriggersPaint() {
        let stack = RenderStack(textDirection: .ltr)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        stack.needsPaint = false

        stack.clipBehavior = .antiAlias
        XCTAssertTrue(stack.needsPaint)
    }

    /// Test that setting `clipBehavior` to the same value does not trigger paint.
    func testClipBehaviorSetterNoOpOnSameValue() {
        let stack = RenderStack(textDirection: .ltr, clipBehavior: .hardEdge)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        stack.needsPaint = false

        stack.clipBehavior = .hardEdge
        XCTAssertFalse(stack.needsPaint)
    }

    /// Test that setting `textDirection` triggers layout.
    func testTextDirectionSetterTriggersLayout() {
        let stack = RenderStack(textDirection: .ltr)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(stack.needsLayout)

        stack.textDirection = .rtl
        XCTAssertTrue(stack.needsLayout)
    }

    /// Test that setting `textDirection` to the same value does not trigger layout.
    func testTextDirectionSetterNoOpOnSameValue() {
        let stack = RenderStack(textDirection: .ltr)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(stack.needsLayout)

        stack.textDirection = .ltr
        XCTAssertFalse(stack.needsLayout)
    }

    /// Test that setting `alignment` triggers layout.
    func testAlignmentSetterTriggersLayout() {
        let stack = RenderStack(alignment: Alignment.topLeft, textDirection: .ltr)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(stack.needsLayout)

        stack.alignment = Alignment.center
        XCTAssertTrue(stack.needsLayout)
    }
}

// MARK: - RenderStack Intrinsic Dimensions Tests

final class RenderStackIntrinsicDimensionTests: XCTestCase {

    /// Test that intrinsic dimensions only consider non-positioned children.
    func testIntrinsicDimensionsIgnorePositionedChildren() {
        let stack = RenderStack(textDirection: .ltr)

        // Add a non-positioned child with fixed size 100x100
        let nonPositioned = TestRenderBox(size: Size(100, 100))
        stack.insert(nonPositioned)

        // Add a positioned child with fixed size 200x200
        let positioned = TestRenderBox(size: Size(200, 200))
        stack.insert(positioned, after: nonPositioned)
        let pd = positioned.parentData as! StackParentData
        pd.top = 0
        pd.left = 0

        // Intrinsic dimensions should come from the non-positioned child only
        XCTAssertEqual(stack.computeMinIntrinsicWidth(0), 100.0)
        XCTAssertEqual(stack.computeMaxIntrinsicWidth(0), 100.0)
        XCTAssertEqual(stack.computeMinIntrinsicHeight(0), 100.0)
        XCTAssertEqual(stack.computeMaxIntrinsicHeight(0), 100.0)
    }

    /// Test intrinsic dimensions with no children.
    func testIntrinsicDimensionsNoChildren() {
        let stack = RenderStack(textDirection: .ltr)
        XCTAssertEqual(stack.computeMinIntrinsicWidth(0), 0.0)
        XCTAssertEqual(stack.computeMaxIntrinsicWidth(0), 0.0)
        XCTAssertEqual(stack.computeMinIntrinsicHeight(0), 0.0)
        XCTAssertEqual(stack.computeMaxIntrinsicHeight(0), 0.0)
    }

    /// Test intrinsic dimensions returns max of non-positioned children.
    func testIntrinsicDimensionsReturnsMax() {
        let stack = RenderStack(textDirection: .ltr)
        let child1 = TestRenderBox(size: Size(50, 80))
        let child2 = TestRenderBox(size: Size(100, 60))
        stack.addAll([child1, child2])

        XCTAssertEqual(stack.computeMinIntrinsicWidth(0), 100.0)
        XCTAssertEqual(stack.computeMaxIntrinsicWidth(0), 100.0)
        XCTAssertEqual(stack.computeMinIntrinsicHeight(0), 80.0)
        XCTAssertEqual(stack.computeMaxIntrinsicHeight(0), 80.0)
    }
}

// MARK: - RenderStack computeDryLayout Tests

final class RenderStackDryLayoutTests: XCTestCase {

    /// Test computeDryLayout with no children returns biggest if finite.
    func testDryLayoutNoChildrenFiniteConstraints() {
        let stack = RenderStack(textDirection: .ltr)
        let constraints = BoxConstraints.tight(Size(200, 300))
        let result = stack.computeDryLayout(constraints)
        XCTAssertEqual(result, Size(200, 300))
    }

    /// Test computeDryLayout with non-positioned child.
    func testDryLayoutWithNonPositionedChild() {
        let child = TestRenderBox(size: Size(100, 80))
        let stack = RenderStack(children: [child], textDirection: .ltr, fit: .loose)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let result = stack.computeDryLayout(constraints)
        XCTAssertEqual(result, Size(100, 80))
    }

    /// Test computeDryLayout with StackFit.expand.
    func testDryLayoutWithExpandFit() {
        let child = TestRenderBox(size: Size(100, 80))
        let stack = RenderStack(children: [child], textDirection: .ltr, fit: .expand)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        let result = stack.computeDryLayout(constraints)
        // expand tightens to biggest, so child should be 200x300
        XCTAssertEqual(result, Size(200, 300))
    }

    /// Test computeDryLayout with StackFit.passthrough.
    func testDryLayoutWithPassthroughFit() {
        let child = TestRenderBox(size: Size(100, 80))
        let stack = RenderStack(children: [child], textDirection: .ltr, fit: .passthrough)
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 50, maxHeight: 200)
        let result = stack.computeDryLayout(constraints)
        // passthrough passes constraints directly, child wants 100x80 but min is 50x50
        XCTAssertEqual(result, Size(100, 80))
    }
}

// MARK: - RenderStack performLayout Tests

final class RenderStackPerformLayoutTests: XCTestCase {

    /// Test performLayout with non-positioned children.
    func testPerformLayoutNonPositionedChildren() {
        let child1 = TestRenderBox(size: Size(100, 80))
        let child2 = TestRenderBox(size: Size(60, 120))
        let stack = RenderStack(
            children: [child1, child2],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            fit: .loose
        )
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)
        stack.layout(constraints)

        // Stack size is max of children: 100 x 120
        XCTAssertEqual(stack.size, Size(100, 120))

        // With topLeft alignment, non-positioned children are at (0,0)
        let pd1 = child1.parentData as! StackParentData
        XCTAssertEqual(pd1.offset, Offset(0, 0))

        let pd2 = child2.parentData as! StackParentData
        XCTAssertEqual(pd2.offset, Offset(0, 0))
    }

    /// Test performLayout with center alignment.
    func testPerformLayoutCenterAlignment() {
        let child = TestRenderBox(size: Size(60, 40))
        let stack = RenderStack(
            children: [child],
            alignment: Alignment.center,
            textDirection: .ltr,
            fit: .loose
        )
        let constraints = BoxConstraints.tight(Size(200, 200))
        stack.layout(constraints)

        // Stack size is constrained to 200x200 (tight), child is 60x40
        // Center alignment: offset = ((200-60)/2, (200-40)/2) = (70, 80)
        let pd = child.parentData as! StackParentData
        XCTAssertEqual(pd.offset.dx, 70.0)
        XCTAssertEqual(pd.offset.dy, 80.0)
    }

    /// Test performLayout with positioned child using left and top.
    func testPerformLayoutPositionedChildLeftTop() {
        let nonPositioned = TestRenderBox(size: Size(200, 200))
        let positioned = TestRenderBox(size: Size(50, 50))

        let stack = RenderStack(
            children: [nonPositioned, positioned],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            fit: .loose
        )

        // Configure positioned child
        let pd = positioned.parentData as! StackParentData
        pd.left = 10
        pd.top = 20

        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)
        stack.layout(constraints)

        // Stack should be sized by the non-positioned child: 200x200
        XCTAssertEqual(stack.size, Size(200, 200))

        // Positioned child offset should be (10, 20)
        XCTAssertEqual(pd.offset, Offset(10, 20))
    }

    /// Test performLayout with positioned child using left and right.
    func testPerformLayoutPositionedChildLeftRight() {
        let nonPositioned = TestRenderBox(size: Size(200, 200))
        let positioned = TestRenderBox(size: Size(50, 50))

        let stack = RenderStack(
            children: [nonPositioned, positioned],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            fit: .loose
        )

        // Set left and right to constrain width
        let pd = positioned.parentData as! StackParentData
        pd.left = 10
        pd.right = 20
        pd.top = 5

        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)
        stack.layout(constraints)

        // width should be 200 - 10 - 20 = 170
        XCTAssertEqual(positioned.size.width, 170.0)
        XCTAssertEqual(pd.offset.dx, 10.0)
        XCTAssertEqual(pd.offset.dy, 5.0)
    }

    /// Test performLayout with positioned child using right only.
    func testPerformLayoutPositionedChildRightOnly() {
        let nonPositioned = TestRenderBox(size: Size(200, 200))
        let positioned = TestRenderBox(size: Size(50, 50))

        let stack = RenderStack(
            children: [nonPositioned, positioned],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            fit: .loose
        )

        // Set only right; child positioned from right edge
        let pd = positioned.parentData as! StackParentData
        pd.right = 20
        pd.top = 0

        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)
        stack.layout(constraints)

        // x = stackWidth - right - childWidth = 200 - 20 - 50 = 130
        XCTAssertEqual(pd.offset.dx, 130.0)
    }

    /// Test performLayout with positioned child using bottom only.
    func testPerformLayoutPositionedChildBottomOnly() {
        let nonPositioned = TestRenderBox(size: Size(200, 200))
        let positioned = TestRenderBox(size: Size(50, 50))

        let stack = RenderStack(
            children: [nonPositioned, positioned],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            fit: .loose
        )

        // Set only bottom; child positioned from bottom edge
        let pd = positioned.parentData as! StackParentData
        pd.left = 0
        pd.bottom = 10

        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)
        stack.layout(constraints)

        // y = stackHeight - bottom - childHeight = 200 - 10 - 50 = 140
        XCTAssertEqual(pd.offset.dy, 140.0)
    }
}

// MARK: - RenderStack layoutPositionedChild Tests

final class RenderStackLayoutPositionedChildTests: XCTestCase {

    /// Test layoutPositionedChild with left and top.
    func testLayoutPositionedChildLeftTop() {
        let child = TestRenderBox(size: Size(50, 50))
        let stack = RenderStack(textDirection: .ltr)
        stack.insert(child)
        let pd = child.parentData as! StackParentData
        pd.left = 10
        pd.top = 20

        let overflow = RenderStack.layoutPositionedChild(
            child, pd, Size(200, 200), Alignment.topLeft
        )

        XCTAssertFalse(overflow)
        XCTAssertEqual(pd.offset, Offset(10, 20))
        XCTAssertEqual(child.size, Size(50, 50))
    }

    /// Test layoutPositionedChild with left and right constrains width.
    func testLayoutPositionedChildLeftRight() {
        let child = TestRenderBox(size: Size(50, 50))
        let stack = RenderStack(textDirection: .ltr)
        stack.insert(child)
        let pd = child.parentData as! StackParentData
        pd.left = 10
        pd.right = 20

        let overflow = RenderStack.layoutPositionedChild(
            child, pd, Size(200, 200), Alignment.topLeft
        )

        // Width should be constrained to 200 - 10 - 20 = 170
        XCTAssertEqual(child.size.width, 170.0)
        XCTAssertEqual(pd.offset.dx, 10.0)
        XCTAssertFalse(overflow)
    }

    /// Test layoutPositionedChild reports overflow when child extends beyond bounds.
    func testLayoutPositionedChildOverflow() {
        let child = TestRenderBox(size: Size(150, 150))
        let stack = RenderStack(textDirection: .ltr)
        stack.insert(child)
        let pd = child.parentData as! StackParentData
        pd.left = 100  // 100 + 150 = 250 > 200

        let overflow = RenderStack.layoutPositionedChild(
            child, pd, Size(200, 200), Alignment.topLeft
        )

        XCTAssertTrue(overflow)
    }

    /// Test layoutPositionedChild with explicit width.
    func testLayoutPositionedChildExplicitWidth() {
        let child = TestRenderBox(size: Size(100, 100))
        let stack = RenderStack(textDirection: .ltr)
        stack.insert(child)
        let pd = child.parentData as! StackParentData
        pd.left = 10
        pd.width = 80

        let _ = RenderStack.layoutPositionedChild(
            child, pd, Size(200, 200), Alignment.topLeft
        )

        XCTAssertEqual(child.size.width, 80.0)
        XCTAssertEqual(pd.offset.dx, 10.0)
    }

    /// Test layoutPositionedChild with explicit height.
    func testLayoutPositionedChildExplicitHeight() {
        let child = TestRenderBox(size: Size(100, 100))
        let stack = RenderStack(textDirection: .ltr)
        stack.insert(child)
        let pd = child.parentData as! StackParentData
        pd.top = 10
        pd.height = 60

        let _ = RenderStack.layoutPositionedChild(
            child, pd, Size(200, 200), Alignment.topLeft
        )

        XCTAssertEqual(child.size.height, 60.0)
        XCTAssertEqual(pd.offset.dy, 10.0)
    }
}

// MARK: - RenderStack hitTestChildren Tests

final class RenderStackHitTestChildrenTests: XCTestCase {

    /// Test hitTestChildren delegates to defaultHitTestChildren.
    func testHitTestChildrenNoChildren() {
        let stack = RenderStack(textDirection: .ltr)
        stack.layout(BoxConstraints.tight(Size(200, 200)))

        let result = BoxHitTestResult()
        let hit = stack.hitTestChildren(result, position: Offset(100, 100))
        XCTAssertFalse(hit)
    }

    /// Test hitTestChildren with a hittable child at the hit position.
    func testHitTestChildrenWithChild() {
        let child = HittableTestRenderBox(size: Size(100, 100))
        let stack = RenderStack(
            children: [child],
            alignment: Alignment.topLeft,
            textDirection: .ltr
        )
        stack.layout(BoxConstraints.tight(Size(200, 200)))

        // Child is at (0,0) with size 100x100, so (50,50) should hit
        let result = BoxHitTestResult()
        let hit = stack.hitTestChildren(result, position: Offset(50, 50))
        XCTAssertTrue(hit)
    }

    /// Test hitTestChildren misses when position is outside child.
    func testHitTestChildrenMiss() {
        let child = HittableTestRenderBox(size: Size(100, 100))
        let stack = RenderStack(
            children: [child],
            alignment: Alignment.topLeft,
            textDirection: .ltr
        )
        stack.layout(BoxConstraints.tight(Size(200, 200)))

        // Child is at (0,0) with size 100x100, so (150,150) should miss
        let result = BoxHitTestResult()
        let hit = stack.hitTestChildren(result, position: Offset(150, 150))
        XCTAssertFalse(hit)
    }
}

// MARK: - RenderStack clipBehavior Tests

final class RenderStackClipBehaviorTests: XCTestCase {

    /// Test clipBehavior getter returns the value set during construction.
    func testClipBehaviorGetter() {
        let stack = RenderStack(textDirection: .ltr, clipBehavior: .antiAliasWithSaveLayer)
        XCTAssertEqual(stack.clipBehavior, .antiAliasWithSaveLayer)
    }

    /// Test clipBehavior setter.
    func testClipBehaviorSetter() {
        let stack = RenderStack(textDirection: .ltr)
        XCTAssertEqual(stack.clipBehavior, .hardEdge)
        stack.clipBehavior = .none
        XCTAssertEqual(stack.clipBehavior, .none)
    }
}

// MARK: - RenderStack dispose Tests

final class RenderStackDisposeTests: XCTestCase {

    /// Test dispose does not crash.
    func testDispose() {
        let stack = RenderStack(textDirection: .ltr)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        stack.dispose()
    }

    /// Test dispose on fresh stack.
    func testDisposeOnFreshStack() {
        let stack = RenderStack(textDirection: .ltr)
        stack.dispose()
    }
}

// MARK: - RenderIndexedStack Tests

final class RenderIndexedStackTests: XCTestCase {

    /// Test construction with default index.
    func testDefaultConstruction() {
        let stack = RenderIndexedStack(textDirection: .ltr)
        XCTAssertEqual(stack.index, 0)
    }

    /// Test construction with custom index.
    func testConstructionWithCustomIndex() {
        let stack = RenderIndexedStack(textDirection: .ltr, index: 2)
        XCTAssertEqual(stack.index, 2)
    }

    /// Test construction with nil index.
    func testConstructionWithNilIndex() {
        let stack = RenderIndexedStack(textDirection: .ltr, index: nil)
        XCTAssertNil(stack.index)
    }

    /// Test index property setter.
    func testIndexSetter() {
        let stack = RenderIndexedStack(textDirection: .ltr, index: 0)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(stack.needsLayout)

        stack.index = 1
        XCTAssertTrue(stack.needsLayout)
        XCTAssertEqual(stack.index, 1)
    }

    /// Test index setter with same value is no-op.
    func testIndexSetterNoOpOnSameValue() {
        let stack = RenderIndexedStack(textDirection: .ltr, index: 0)
        stack.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(stack.needsLayout)

        stack.index = 0
        XCTAssertFalse(stack.needsLayout)
    }
}

// MARK: - RenderIndexedStack hitTestChildren Tests

final class RenderIndexedStackHitTestTests: XCTestCase {

    /// Test hitTestChildren only tests the displayed child.
    func testHitTestChildrenOnlyTestsDisplayedChild() {
        let child0 = HittableTestRenderBox(size: Size(200, 200))
        let child1 = HittableTestRenderBox(size: Size(200, 200))
        let stack = RenderIndexedStack(
            children: [child0, child1],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            index: 0
        )
        stack.layout(BoxConstraints.tight(Size(200, 200)))

        // Hit test at center; should only test child0 (index 0)
        let result = BoxHitTestResult()
        let hit = stack.hitTestChildren(result, position: Offset(100, 100))
        XCTAssertTrue(hit)
    }

    /// Test hitTestChildren returns false when index is nil.
    func testHitTestChildrenNilIndex() {
        let child = HittableTestRenderBox(size: Size(200, 200))
        let stack = RenderIndexedStack(
            children: [child],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            index: nil
        )
        stack.layout(BoxConstraints.tight(Size(200, 200)))

        let result = BoxHitTestResult()
        let hit = stack.hitTestChildren(result, position: Offset(100, 100))
        XCTAssertFalse(hit)
    }

    /// Test hitTestChildren returns false when no children.
    func testHitTestChildrenNoChildren() {
        let stack = RenderIndexedStack(textDirection: .ltr, index: 0)
        stack.layout(BoxConstraints.tight(Size(200, 200)))

        let result = BoxHitTestResult()
        let hit = stack.hitTestChildren(result, position: Offset(100, 100))
        XCTAssertFalse(hit)
    }
}

// MARK: - RenderIndexedStack paintStack Tests

final class RenderIndexedStackPaintTests: XCTestCase {

    /// Test paintStack does nothing when index is nil.
    func testPaintStackNilIndex() {
        let child = TestRenderBox(size: Size(100, 100))
        let stack = RenderIndexedStack(
            children: [child],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            index: nil
        )
        stack.layout(BoxConstraints.tight(Size(200, 200)))

        let context = PaintingContext()
        // Should not crash; simply returns early
        stack.paintStack(context, .zero)
    }

    /// Test paintStack with valid index does not crash.
    func testPaintStackWithValidIndex() {
        let child0 = TestRenderBox(size: Size(100, 100))
        let child1 = TestRenderBox(size: Size(100, 100))
        let stack = RenderIndexedStack(
            children: [child0, child1],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            index: 1
        )
        stack.layout(BoxConstraints.tight(Size(200, 200)))

        let context = PaintingContext()
        // Should paint only child1
        stack.paintStack(context, .zero)
    }

    /// Test paintStack with index 0.
    func testPaintStackFirstChild() {
        let child0 = TestRenderBox(size: Size(100, 100))
        let child1 = TestRenderBox(size: Size(100, 100))
        let stack = RenderIndexedStack(
            children: [child0, child1],
            alignment: Alignment.topLeft,
            textDirection: .ltr,
            index: 0
        )
        stack.layout(BoxConstraints.tight(Size(200, 200)))

        let context = PaintingContext()
        // Should paint only child0
        stack.paintStack(context, .zero)
    }
}

// MARK: - RenderStack _computeSize with StackFit Tests

final class RenderStackComputeSizeTests: XCTestCase {

    /// Test _computeSize via computeDryLayout with StackFit.loose.
    ///
    /// With .loose, the constraints are loosened so children can be any size
    /// from 0 up to the max constraint.
    func testComputeSizeLoose() {
        let child = TestRenderBox(size: Size(80, 60))
        let stack = RenderStack(children: [child], textDirection: .ltr, fit: .loose)
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 50, maxHeight: 200)
        let result = stack.computeDryLayout(constraints)
        // Child wants 80x60. With loose, min is 0, so child gets 80x60.
        // But stack's min is 50, so result is max(50, 80) x max(50, 60) = 80x60
        XCTAssertEqual(result, Size(80, 60))
    }

    /// Test _computeSize via computeDryLayout with StackFit.expand.
    ///
    /// With .expand, constraints are tightened to the biggest allowed size.
    func testComputeSizeExpand() {
        let child = TestRenderBox(size: Size(80, 60))
        let stack = RenderStack(children: [child], textDirection: .ltr, fit: .expand)
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 50, maxHeight: 200)
        let result = stack.computeDryLayout(constraints)
        // With expand, child is given tight(200, 200), so child constrains to 200x200
        XCTAssertEqual(result, Size(200, 200))
    }

    /// Test _computeSize via computeDryLayout with StackFit.passthrough.
    ///
    /// With .passthrough, constraints are passed directly to children.
    func testComputeSizePassthrough() {
        let child = TestRenderBox(size: Size(80, 60))
        let stack = RenderStack(children: [child], textDirection: .ltr, fit: .passthrough)
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 50, maxHeight: 200)
        let result = stack.computeDryLayout(constraints)
        // With passthrough, child is given (50..200, 50..200), child wants 80x60 so constrains to 80x60
        XCTAssertEqual(result, Size(80, 60))
    }

    /// Test _computeSize with only positioned children returns biggest/smallest.
    func testComputeSizeOnlyPositionedChildren() {
        let child = TestRenderBox(size: Size(100, 100))
        let stack = RenderStack(children: [child], textDirection: .ltr)
        let pd = child.parentData as! StackParentData
        pd.left = 0
        pd.top = 0

        let constraints = BoxConstraints.tight(Size(200, 200))
        let result = stack.computeDryLayout(constraints)
        // No non-positioned children, biggest is finite, so returns biggest
        XCTAssertEqual(result, Size(200, 200))
    }

    /// Test _computeSize with no children returns biggest when finite.
    func testComputeSizeNoChildrenFinite() {
        let stack = RenderStack(textDirection: .ltr)
        let constraints = BoxConstraints.tight(Size(200, 200))
        let result = stack.computeDryLayout(constraints)
        XCTAssertEqual(result, Size(200, 200))
    }

    /// Test _computeSize with no children and unbounded constraints returns smallest.
    func testComputeSizeNoChildrenUnbounded() {
        let stack = RenderStack(textDirection: .ltr)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        let result = stack.computeDryLayout(constraints)
        XCTAssertEqual(result, Size(0, 0))
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for ProxyBox types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/proxy_box.dart`
///
/// These tests cover:
///   - RenderProxyBox: basic proxy behavior, child forwarding, intrinsics, layout, hit testing
///   - HitTestBehavior / RenderProxyBoxWithHitTestBehavior: behavior modes, hit test self
///   - RenderConstrainedBox: additional constraints enforcement
///   - RenderLimitedBox: limits in unbounded environments
///   - RenderAspectRatio: aspect ratio enforcement
///   - RenderIntrinsicWidth: intrinsic width sizing with step
///   - RenderIntrinsicHeight: intrinsic height sizing
///   - RenderIgnoreBaseline: baseline ignoring
///   - RenderOpacity: opacity values, alpha, layer management
///   - RenderAnimatedOpacity: animated opacity protocol
///   - RenderShaderMask: shader callback, blend mode
///   - RenderBackdropFilter: backdrop filter, enabled state
///   - CustomClipper / ShapeBorderClipper: custom clip delegate
///   - RenderClipRect / RenderClipRRect / RenderClipOval / RenderClipPath: clipping
///   - RenderPhysicalModel / RenderPhysicalShape: physical model rendering
///   - RenderDecoratedBox: decoration painting
///   - RenderTransform: matrix transformations
///   - RenderFittedBox: box fitting
///   - RenderFractionalTranslation: fractional translation
///   - RenderPointerListener: pointer event callbacks
///   - RenderMouseRegion: mouse hover/enter/exit
///   - RenderRepaintBoundary: repaint isolation
///   - RenderIgnorePointer: hit test bypass
///   - RenderOffstage: offstage behavior
///   - RenderAbsorbPointer: pointer absorption
///   - RenderMetaData: metadata storage
///   - RenderSemanticsGestureHandler: semantics gestures
///   - RenderSemanticsAnnotations: semantics annotations
///   - RenderBlockSemantics / RenderMergeSemantics / RenderExcludeSemantics / RenderIndexedSemantics
///   - RenderLeaderLayer / RenderFollowerLayer: layer linking
///   - RenderAnnotatedRegion: annotated region

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

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

/// A minimal CustomClipper<Rect> subclass for testing.
private class TestRectClipper: CustomClipper<Rect> {
    let clipRect: Rect

    init(clipRect: Rect) {
        self.clipRect = clipRect
        super.init()
    }

    override func getClip(_ size: Size) -> Rect {
        return clipRect
    }

    override func shouldReclip(_ oldClipper: CustomClipper<Rect>) -> Bool {
        guard let old = oldClipper as? TestRectClipper else { return true }
        return old.clipRect != clipRect
    }
}

/// A minimal CustomClipper<RRect> subclass for testing.
private class TestRRectClipper: CustomClipper<RRect> {
    let clipRRect: RRect

    init(clipRRect: RRect) {
        self.clipRRect = clipRRect
        super.init()
    }

    override func getClip(_ size: Size) -> RRect {
        return clipRRect
    }

    override func shouldReclip(_ oldClipper: CustomClipper<RRect>) -> Bool {
        return true
    }
}

/// A minimal CustomClipper<Path> subclass for testing.
private class TestPathClipper: CustomClipper<Path> {
    override func getClip(_ size: Size) -> Path {
        let path = Path()
        path.addRect(Offset.zero & size)
        return path
    }

    override func shouldReclip(_ oldClipper: CustomClipper<Path>) -> Bool {
        return true
    }
}

/// A simple concrete ImageFilter for testing purposes.
private struct TestImageFilter: ImageFilter {
    var sigmaX: Double = 1.0
    var sigmaY: Double = 1.0
    var shortDescription: String { "TestImageFilter(\(sigmaX), \(sigmaY))" }
    var description: String { shortDescription }
    func toNativeImageFilter() -> NativeImageFilter {
        fatalError("Not implemented for testing")
    }
}

// MARK: - RenderProxyBox Construction Tests

final class RenderProxyBoxConstructionTests: XCTestCase {

    /// Test that RenderProxyBox can be constructed without a child.
    func testConstructionWithoutChild() {
        let box = RenderProxyBox()
        XCTAssertNil(box.child)
    }

    /// Test that RenderProxyBox can be constructed with a child.
    func testConstructionWithChild() {
        let child = RenderBox()
        let box = RenderProxyBox(child: child)
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
    }

    /// Test that child can be replaced.
    func testReplacingChild() {
        let child1 = FixedSizeRenderBox(width: 50, height: 50)
        let child2 = FixedSizeRenderBox(width: 80, height: 80)
        let box = RenderProxyBox(child: child1)
        XCTAssertTrue(box.child === child1)
        box.child = child2
        XCTAssertTrue(box.child === child2)
    }

    /// Test that child can be set to nil.
    func testSettingChildToNil() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = RenderProxyBox(child: child)
        XCTAssertNotNil(box.child)
        box.child = nil
        XCTAssertNil(box.child)
    }

    /// Test that setupParentData creates plain ParentData.
    func testSetupParentData() {
        let box = RenderProxyBox()
        let child = RenderBox()
        box.setupParentData(child)
        XCTAssertNotNil(child.parentData)
        XCTAssertTrue(child.parentData is ParentData)
    }
}

// MARK: - RenderProxyBox Intrinsic Tests

final class RenderProxyBoxIntrinsicTests: XCTestCase {

    /// Test intrinsic dimensions delegate to child.
    func testIntrinsicDimensionsDelegateToChild() {
        let child = FixedSizeRenderBox(width: 120, height: 80)
        let box = RenderProxyBox(child: child)
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 80.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 80.0)
    }

    /// Test intrinsic dimensions return 0 without child.
    func testIntrinsicDimensionsWithoutChild() {
        let box = RenderProxyBox()
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 0.0)
    }
}

// MARK: - RenderProxyBox Layout Tests

final class RenderProxyBoxLayoutTests: XCTestCase {

    /// Test layout with child delegates to child's size.
    func testLayoutWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderProxyBox(child: child)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 50.0)
    }

    /// Test layout without child sizes to constraints.smallest.
    func testLayoutWithoutChild() {
        let box = RenderProxyBox()
        box.layout(BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 200))
        XCTAssertEqual(box.size.width, 10.0)
        XCTAssertEqual(box.size.height, 20.0)
    }

    /// Test computeDryLayout with child.
    func testDryLayoutWithChild() {
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let box = RenderProxyBox(child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 80.0)
        XCTAssertEqual(size.height, 60.0)
    }

    /// Test computeDryLayout without child.
    func testDryLayoutWithoutChild() {
        let box = RenderProxyBox()
        let constraints = BoxConstraints(minWidth: 5, maxWidth: 200, minHeight: 15, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 5.0)
        XCTAssertEqual(size.height, 15.0)
    }
}

// MARK: - RenderProxyBox Hit Testing

final class RenderProxyBoxHitTestTests: XCTestCase {

    /// Test hitTestChildren returns false without child.
    func testHitTestChildrenWithoutChild() {
        let box = RenderProxyBox()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        let result = BoxHitTestResult()
        XCTAssertFalse(box.hitTestChildren(result, position: Offset(50, 50)))
    }
}

// MARK: - HitTestBehavior Tests

final class HitTestBehaviorTests: XCTestCase {

    /// Test all three cases exist and are distinct.
    func testCasesExist() {
        let defer_ = HitTestBehavior.deferToChild
        let opaque = HitTestBehavior.opaque
        let translucent = HitTestBehavior.translucent
        XCTAssertNotNil(defer_)
        XCTAssertNotNil(opaque)
        XCTAssertNotNil(translucent)
        XCTAssertTrue(defer_ != opaque)
        XCTAssertTrue(opaque != translucent)
        XCTAssertTrue(defer_ != translucent)
    }
}

// MARK: - RenderProxyBoxWithHitTestBehavior Tests

final class RenderProxyBoxWithHitTestBehaviorTests: XCTestCase {

    /// Test default construction with deferToChild behavior.
    func testDefaultConstruction() {
        let box = RenderProxyBoxWithHitTestBehavior()
        XCTAssertEqual(box.behavior, .deferToChild)
        XCTAssertNil(box.child)
    }

    /// Test construction with opaque behavior.
    func testConstructionWithOpaqueBehavior() {
        let box = RenderProxyBoxWithHitTestBehavior(behavior: .opaque)
        XCTAssertEqual(box.behavior, .opaque)
    }

    /// Test hitTestSelf returns true for opaque.
    func testHitTestSelfOpaque() {
        let box = RenderProxyBoxWithHitTestBehavior(behavior: .opaque)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertTrue(box.hitTestSelf(Offset(50, 50)))
    }

    /// Test hitTestSelf returns false for deferToChild.
    func testHitTestSelfDeferToChild() {
        let box = RenderProxyBoxWithHitTestBehavior(behavior: .deferToChild)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.hitTestSelf(Offset(50, 50)))
    }

    /// Test hitTestSelf returns false for translucent.
    func testHitTestSelfTranslucent() {
        let box = RenderProxyBoxWithHitTestBehavior(behavior: .translucent)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.hitTestSelf(Offset(50, 50)))
    }
}

// MARK: - RenderConstrainedBox Construction Tests

final class RenderConstrainedBoxConstructionTests: XCTestCase {

    /// Test construction with additional constraints.
    func testConstruction() {
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 30, maxHeight: 150)
        let box = RenderConstrainedBox(additionalConstraints: constraints)
        XCTAssertNil(box.child)
        XCTAssertEqual(box.additionalConstraints.minWidth, 50.0)
        XCTAssertEqual(box.additionalConstraints.maxWidth, 200.0)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 30, maxHeight: 150)
        let box = RenderConstrainedBox(child: child, additionalConstraints: constraints)
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
    }
}

// MARK: - RenderConstrainedBox Property Tests

final class RenderConstrainedBoxPropertyTests: XCTestCase {

    /// Test that setting additionalConstraints triggers layout.
    func testAdditionalConstraintsSetterTriggersLayout() {
        let box = RenderConstrainedBox(additionalConstraints: BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 30, maxHeight: 150))
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300))
        XCTAssertFalse(box.needsLayout)
        box.additionalConstraints = BoxConstraints(minWidth: 100, maxWidth: 250, minHeight: 50, maxHeight: 200)
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting additionalConstraints to same value does not trigger layout.
    func testAdditionalConstraintsSetterNoOpOnSameValue() {
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 30, maxHeight: 150)
        let box = RenderConstrainedBox(additionalConstraints: constraints)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300))
        XCTAssertFalse(box.needsLayout)
        box.additionalConstraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 30, maxHeight: 150)
        XCTAssertFalse(box.needsLayout)
    }
}

// MARK: - RenderConstrainedBox Intrinsic Tests

final class RenderConstrainedBoxIntrinsicTests: XCTestCase {

    /// Test tight width constraints return the constrained width.
    func testTightWidthIntrinsics() {
        let box = RenderConstrainedBox(
            additionalConstraints: BoxConstraints.tightFor(width: 100)
        )
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 100.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 100.0)
    }

    /// Test tight height constraints return the constrained height.
    func testTightHeightIntrinsics() {
        let box = RenderConstrainedBox(
            additionalConstraints: BoxConstraints.tightFor(height: 80)
        )
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 80.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 80.0)
    }

    /// Test bounded constraints constrain the child's intrinsics.
    func testBoundedConstraintsWithChild() {
        let child = FixedSizeRenderBox(width: 30, height: 20)
        let box = RenderConstrainedBox(
            child: child,
            additionalConstraints: BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 40, maxHeight: 150)
        )
        // Child intrinsic width is 30, but min is 50, so constrained to 50
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 50.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 50.0)
        // Child intrinsic height is 20, but min is 40, so constrained to 40
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 40.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 40.0)
    }
}

// MARK: - RenderConstrainedBox Layout Tests

final class RenderConstrainedBoxLayoutTests: XCTestCase {

    /// Test layout without child sizes to enforced constraint.
    func testLayoutWithoutChild() {
        let box = RenderConstrainedBox(
            additionalConstraints: BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 40, maxHeight: 150)
        )
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300))
        // enforce(outer) creates combined constraints, then constrain(Size.zero)
        XCTAssertEqual(box.size.width, 50.0)
        XCTAssertEqual(box.size.height, 40.0)
    }

    /// Test layout with child enforces additional constraints.
    func testLayoutWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 80)
        let box = RenderConstrainedBox(
            child: child,
            additionalConstraints: BoxConstraints(minWidth: 150, maxWidth: 300, minHeight: 100, maxHeight: 200)
        )
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: 400))
        // Child wants 100x80, but additional constraints enforce min 150x100
        XCTAssertEqual(box.size.width, 150.0)
        XCTAssertEqual(box.size.height, 100.0)
    }

    /// Test computeDryLayout without child.
    func testDryLayoutWithoutChild() {
        let box = RenderConstrainedBox(
            additionalConstraints: BoxConstraints(minWidth: 60, maxWidth: 200, minHeight: 40, maxHeight: 150)
        )
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 60.0)
        XCTAssertEqual(size.height, 40.0)
    }
}

// MARK: - RenderLimitedBox Construction Tests

final class RenderLimitedBoxConstructionTests: XCTestCase {

    /// Test default construction with infinity limits.
    func testDefaultConstruction() {
        let box = RenderLimitedBox()
        XCTAssertNil(box.child)
        XCTAssertEqual(box.maxWidth, .infinity)
        XCTAssertEqual(box.maxHeight, .infinity)
    }

    /// Test construction with custom limits.
    func testConstructionWithLimits() {
        let box = RenderLimitedBox(maxWidth: 100, maxHeight: 50)
        XCTAssertEqual(box.maxWidth, 100.0)
        XCTAssertEqual(box.maxHeight, 50.0)
    }
}

// MARK: - RenderLimitedBox Property Tests

final class RenderLimitedBoxPropertyTests: XCTestCase {

    /// Test that setting maxWidth triggers layout.
    func testMaxWidthSetterTriggersLayout() {
        let box = RenderLimitedBox(maxWidth: 100)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)
        box.maxWidth = 150
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting maxWidth to same value does not trigger layout.
    func testMaxWidthSetterNoOpOnSameValue() {
        let box = RenderLimitedBox(maxWidth: 100)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)
        box.maxWidth = 100
        XCTAssertFalse(box.needsLayout)
    }

    /// Test that setting maxHeight triggers layout.
    func testMaxHeightSetterTriggersLayout() {
        let box = RenderLimitedBox(maxHeight: 100)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)
        box.maxHeight = 150
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting maxHeight to same value does not trigger layout.
    func testMaxHeightSetterNoOpOnSameValue() {
        let box = RenderLimitedBox(maxHeight: 100)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)
        box.maxHeight = 100
        XCTAssertFalse(box.needsLayout)
    }
}

// MARK: - RenderLimitedBox Layout Tests

final class RenderLimitedBoxLayoutTests: XCTestCase {

    /// Test that limits are applied in unbounded environment.
    func testLimitsInUnboundedWidth() {
        let child = FixedSizeRenderBox(width: 200, height: 200)
        let box = RenderLimitedBox(child: child, maxWidth: 100, maxHeight: 80)
        // Unbounded: maxWidth = infinity
        box.layout(BoxConstraints(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity))
        // Child should be constrained by the limited box's maxWidth/maxHeight
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 80.0)
    }

    /// Test that limits are NOT applied in bounded environment.
    func testLimitsIgnoredInBoundedEnvironment() {
        let child = FixedSizeRenderBox(width: 150, height: 120)
        let box = RenderLimitedBox(child: child, maxWidth: 100, maxHeight: 80)
        // Bounded environment
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        // Bounded, so limits are NOT applied, child sizes normally
        XCTAssertEqual(box.size.width, 150.0)
        XCTAssertEqual(box.size.height, 120.0)
    }

    /// Test layout without child.
    func testLayoutWithoutChild() {
        let box = RenderLimitedBox(maxWidth: 100, maxHeight: 80)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity))
        // No child: constrain(Size.zero) with limited constraints
        XCTAssertEqual(box.size.width, 0.0)
        XCTAssertEqual(box.size.height, 0.0)
    }
}

// MARK: - RenderAspectRatio Construction Tests

final class RenderAspectRatioConstructionTests: XCTestCase {

    /// Test construction with aspect ratio.
    func testConstruction() {
        let box = RenderAspectRatio(aspectRatio: 2.0)
        XCTAssertNil(box.child)
        XCTAssertEqual(box.aspectRatio, 2.0)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderAspectRatio(child: child, aspectRatio: 16.0 / 9.0)
        XCTAssertNotNil(box.child)
    }
}

// MARK: - RenderAspectRatio Property Tests

final class RenderAspectRatioPropertyTests: XCTestCase {

    /// Test that setting aspectRatio triggers layout.
    func testAspectRatioSetterTriggersLayout() {
        let box = RenderAspectRatio(aspectRatio: 2.0)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)
        box.aspectRatio = 1.5
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting aspectRatio to same value does not trigger layout.
    func testAspectRatioSetterNoOpOnSameValue() {
        let box = RenderAspectRatio(aspectRatio: 2.0)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)
        box.aspectRatio = 2.0
        XCTAssertFalse(box.needsLayout)
    }
}

// MARK: - RenderAspectRatio Intrinsic Tests

final class RenderAspectRatioIntrinsicTests: XCTestCase {

    /// Test min intrinsic width with finite height.
    func testMinIntrinsicWidthFiniteHeight() {
        let box = RenderAspectRatio(aspectRatio: 2.0)
        // width = height * aspectRatio = 100 * 2 = 200
        XCTAssertEqual(box.computeMinIntrinsicWidth(100.0), 200.0)
    }

    /// Test max intrinsic width with finite height.
    func testMaxIntrinsicWidthFiniteHeight() {
        let box = RenderAspectRatio(aspectRatio: 0.5)
        // width = height * aspectRatio = 100 * 0.5 = 50
        XCTAssertEqual(box.computeMaxIntrinsicWidth(100.0), 50.0)
    }

    /// Test min intrinsic height with finite width.
    func testMinIntrinsicHeightFiniteWidth() {
        let box = RenderAspectRatio(aspectRatio: 2.0)
        // height = width / aspectRatio = 200 / 2 = 100
        XCTAssertEqual(box.computeMinIntrinsicHeight(200.0), 100.0)
    }

    /// Test max intrinsic height with finite width.
    func testMaxIntrinsicHeightFiniteWidth() {
        let box = RenderAspectRatio(aspectRatio: 4.0)
        // height = width / aspectRatio = 200 / 4 = 50
        XCTAssertEqual(box.computeMaxIntrinsicHeight(200.0), 50.0)
    }

    /// Test intrinsic width with infinite height falls back to child.
    func testIntrinsicWidthInfiniteHeightNoChild() {
        let box = RenderAspectRatio(aspectRatio: 2.0)
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 0.0)
    }
}

// MARK: - RenderAspectRatio Layout Tests

final class RenderAspectRatioLayoutTests: XCTestCase {

    /// Test layout with 2:1 aspect ratio.
    func testLayoutWith2to1AspectRatio() {
        let box = RenderAspectRatio(aspectRatio: 2.0)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        // width = 200, height = 200 / 2 = 100
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 100.0)
    }

    /// Test layout with 1:2 aspect ratio.
    func testLayoutWith1to2AspectRatio() {
        let box = RenderAspectRatio(aspectRatio: 0.5)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        // width = 200, height = 200 / 0.5 = 400, but capped to 200
        // height = 200, width = 200 * 0.5 = 100
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 200.0)
    }

    /// Test tight constraints return the tight size.
    func testTightConstraints() {
        let box = RenderAspectRatio(aspectRatio: 2.0)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 100.0)
    }
}

// MARK: - RenderIntrinsicWidth Construction Tests

final class RenderIntrinsicWidthConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderIntrinsicWidth()
        XCTAssertNil(box.child)
        XCTAssertNil(box.stepWidth)
        XCTAssertNil(box.stepHeight)
    }

    /// Test construction with step values.
    func testConstructionWithSteps() {
        let box = RenderIntrinsicWidth(stepWidth: 10.0, stepHeight: 20.0)
        XCTAssertEqual(box.stepWidth, 10.0)
        XCTAssertEqual(box.stepHeight, 20.0)
    }
}

// MARK: - RenderIntrinsicWidth Property Tests

final class RenderIntrinsicWidthPropertyTests: XCTestCase {

    /// Test that setting stepWidth triggers layout.
    func testStepWidthSetterTriggersLayout() {
        let box = RenderIntrinsicWidth()
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)
        box.stepWidth = 10.0
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting stepWidth to same value does not trigger layout.
    func testStepWidthSetterNoOpOnSameValue() {
        let box = RenderIntrinsicWidth(stepWidth: 10.0)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)
        box.stepWidth = 10.0
        XCTAssertFalse(box.needsLayout)
    }

    /// Test that setting stepHeight triggers layout.
    func testStepHeightSetterTriggersLayout() {
        let box = RenderIntrinsicWidth()
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)
        box.stepHeight = 20.0
        XCTAssertTrue(box.needsLayout)
    }
}

// MARK: - RenderIntrinsicWidth Intrinsic Tests

final class RenderIntrinsicWidthIntrinsicTests: XCTestCase {

    /// Test that min intrinsic width equals max intrinsic width.
    func testMinEqualsMaxIntrinsicWidth() {
        let child = FixedSizeRenderBox(width: 75, height: 50)
        let box = RenderIntrinsicWidth(child: child)
        let min = box.computeMinIntrinsicWidth(.infinity)
        let max = box.computeMaxIntrinsicWidth(.infinity)
        XCTAssertEqual(min, max)
    }

    /// Test step applied to max intrinsic width.
    func testStepAppliedToMaxIntrinsicWidth() {
        let child = FixedSizeRenderBox(width: 75, height: 50)
        let box = RenderIntrinsicWidth(stepWidth: 50.0, child: child)
        // 75 / 50 = 1.5, rounded up = 2, 2 * 50 = 100
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 100.0)
    }

    /// Test without child returns 0.
    func testWithoutChildReturnsZero() {
        let box = RenderIntrinsicWidth(stepWidth: 10.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 0.0)
    }
}

// MARK: - RenderIntrinsicWidth Layout Tests

final class RenderIntrinsicWidthLayoutTests: XCTestCase {

    /// Test layout without child returns smallest.
    func testLayoutWithoutChild() {
        let box = RenderIntrinsicWidth()
        box.layout(BoxConstraints(minWidth: 5, maxWidth: 200, minHeight: 10, maxHeight: 200))
        XCTAssertEqual(box.size.width, 5.0)
        XCTAssertEqual(box.size.height, 10.0)
    }

    /// Test layout with child sizes to child's intrinsic width.
    func testLayoutWithChild() {
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let box = RenderIntrinsicWidth(child: child)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(box.size.width, 80.0)
        XCTAssertEqual(box.size.height, 60.0)
    }
}

// MARK: - RenderIntrinsicHeight Construction Tests

final class RenderIntrinsicHeightConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderIntrinsicHeight()
        XCTAssertNil(box.child)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderIntrinsicHeight(child: child)
        XCTAssertNotNil(box.child)
    }
}

// MARK: - RenderIntrinsicHeight Intrinsic Tests

final class RenderIntrinsicHeightIntrinsicTests: XCTestCase {

    /// Test that min intrinsic height equals max intrinsic height.
    func testMinEqualsMaxIntrinsicHeight() {
        let child = FixedSizeRenderBox(width: 100, height: 75)
        let box = RenderIntrinsicHeight(child: child)
        let min = box.computeMinIntrinsicHeight(.infinity)
        let max = box.computeMaxIntrinsicHeight(.infinity)
        XCTAssertEqual(min, max)
    }

    /// Test without child returns 0.
    func testWithoutChildReturnsZero() {
        let box = RenderIntrinsicHeight()
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 0.0)
    }
}

// MARK: - RenderIntrinsicHeight Layout Tests

final class RenderIntrinsicHeightLayoutTests: XCTestCase {

    /// Test layout without child returns smallest.
    func testLayoutWithoutChild() {
        let box = RenderIntrinsicHeight()
        box.layout(BoxConstraints(minWidth: 5, maxWidth: 200, minHeight: 10, maxHeight: 200))
        XCTAssertEqual(box.size.width, 5.0)
        XCTAssertEqual(box.size.height, 10.0)
    }

    /// Test layout with child sizes to child's intrinsic height.
    func testLayoutWithChild() {
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let box = RenderIntrinsicHeight(child: child)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(box.size.width, 80.0)
        XCTAssertEqual(box.size.height, 60.0)
    }
}

// MARK: - RenderIgnoreBaseline Tests

final class RenderIgnoreBaselineTests: XCTestCase {

    /// Test construction.
    func testConstruction() {
        let box = RenderIgnoreBaseline()
        XCTAssertNil(box.child)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderIgnoreBaseline(child: child)
        XCTAssertNotNil(box.child)
    }

    /// Test computeDistanceToActualBaseline always returns nil.
    func testBaselineAlwaysNil() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderIgnoreBaseline(child: child)
        XCTAssertNil(box.computeDistanceToActualBaseline(.alphabetic))
        XCTAssertNil(box.computeDistanceToActualBaseline(.ideographic))
    }

    /// Test computeDryBaseline always returns nil.
    func testDryBaselineAlwaysNil() {
        let box = RenderIgnoreBaseline()
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        XCTAssertNil(box.computeDryBaseline(constraints, .alphabetic))
        XCTAssertNil(box.computeDryBaseline(constraints, .ideographic))
    }
}

// MARK: - RenderOpacity Construction Tests

final class RenderOpacityConstructionTests: XCTestCase {

    /// Test default construction with full opacity.
    func testDefaultConstruction() {
        let box = RenderOpacity()
        XCTAssertEqual(box.opacity, 1.0)
        XCTAssertFalse(box.alwaysIncludeSemantics)
        XCTAssertNil(box.child)
    }

    /// Test construction with custom opacity.
    func testConstructionWithOpacity() {
        let box = RenderOpacity(opacity: 0.5)
        XCTAssertEqual(box.opacity, 0.5)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderOpacity(child: child)
        XCTAssertNotNil(box.child)
    }

    /// Test construction with alwaysIncludeSemantics.
    func testConstructionWithAlwaysIncludeSemantics() {
        let box = RenderOpacity(alwaysIncludeSemantics: true)
        XCTAssertTrue(box.alwaysIncludeSemantics)
    }
}

// MARK: - RenderOpacity Property Tests

final class RenderOpacityPropertyTests: XCTestCase {

    /// Test that setting opacity to same value is no-op.
    func testOpacitySetterNoOpOnSameValue() {
        let box = RenderOpacity(opacity: 0.5)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.opacity = 0.5
        XCTAssertFalse(box.needsPaint)
    }

    /// Test that setting opacity to different value triggers paint.
    func testOpacitySetterTriggersPaint() {
        let box = RenderOpacity(opacity: 0.5)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.opacity = 0.8
        XCTAssertTrue(box.needsPaint)
    }

    /// Test that setting alwaysIncludeSemantics to same value is no-op.
    func testAlwaysIncludeSemanticsNoOp() {
        let box = RenderOpacity(alwaysIncludeSemantics: true)
        XCTAssertTrue(box.alwaysIncludeSemantics)
        box.alwaysIncludeSemantics = true
        XCTAssertTrue(box.alwaysIncludeSemantics)
    }

    /// Test alwaysNeedsCompositing with child and non-zero opacity.
    func testAlwaysNeedsCompositingWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderOpacity(opacity: 0.5, child: child)
        XCTAssertTrue(box.alwaysNeedsCompositing)
    }

    /// Test alwaysNeedsCompositing is false without child.
    func testAlwaysNeedsCompositingWithoutChild() {
        let box = RenderOpacity(opacity: 0.5)
        XCTAssertFalse(box.alwaysNeedsCompositing)
    }

    /// Test alwaysNeedsCompositing is false with opacity 0.
    func testAlwaysNeedsCompositingZeroOpacity() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderOpacity(opacity: 0.0, child: child)
        XCTAssertFalse(box.alwaysNeedsCompositing)
    }

    /// Test paintsChild returns false for zero opacity.
    func testPaintsChildFalseForZeroOpacity() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderOpacity(opacity: 0.0, child: child)
        XCTAssertFalse(box.paintsChild(child))
    }

    /// Test paintsChild returns true for non-zero opacity.
    func testPaintsChildTrueForNonZeroOpacity() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderOpacity(opacity: 0.5, child: child)
        XCTAssertTrue(box.paintsChild(child))
    }
}

// MARK: - RenderAnimatedOpacity Construction Tests

final class RenderAnimatedOpacityConstructionTests: XCTestCase {

    /// Test construction with an animation.
    func testConstruction() {
        let anim = AlwaysStoppedAnimation<Double>( 0.5)
        let box = RenderAnimatedOpacity(opacity: anim)
        XCTAssertTrue(box.opacity === anim)
        XCTAssertFalse(box.alwaysIncludeSemantics)
        XCTAssertNil(box.child)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let anim = AlwaysStoppedAnimation<Double>( 1.0)
        let box = RenderAnimatedOpacity(opacity: anim, child: child)
        XCTAssertNotNil(box.child)
    }

    /// Test animatedAlpha is computed on construction.
    func testAnimatedAlphaComputedOnConstruction() {
        let anim = AlwaysStoppedAnimation<Double>( 1.0)
        let box = RenderAnimatedOpacity(opacity: anim)
        XCTAssertNotNil(box.animatedAlpha)
        XCTAssertEqual(box.animatedAlpha, 255)
    }

    /// Test animatedAlpha for zero opacity.
    func testAnimatedAlphaZeroOpacity() {
        let anim = AlwaysStoppedAnimation<Double>( 0.0)
        let box = RenderAnimatedOpacity(opacity: anim)
        XCTAssertEqual(box.animatedAlpha, 0)
    }
}

// MARK: - RenderAnimatedOpacity Property Tests

final class RenderAnimatedOpacityPropertyTests: XCTestCase {

    /// Test isRepaintBoundary with child and non-zero alpha.
    func testIsRepaintBoundaryWithChildNonZeroAlpha() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let anim = AlwaysStoppedAnimation<Double>( 0.5)
        let box = RenderAnimatedOpacity(opacity: anim, child: child)
        // currentlyIsRepaintBoundary should be set after _updateOpacity
        XCTAssertTrue(box.isRepaintBoundary)
    }

    /// Test isRepaintBoundary is false without child.
    func testIsRepaintBoundaryWithoutChild() {
        let anim = AlwaysStoppedAnimation<Double>( 0.5)
        let box = RenderAnimatedOpacity(opacity: anim)
        XCTAssertFalse(box.isRepaintBoundary)
    }

    /// Test setting alwaysIncludeSemantics.
    func testAlwaysIncludeSemanticsSetter() {
        let anim = AlwaysStoppedAnimation<Double>( 0.5)
        let box = RenderAnimatedOpacity(opacity: anim, alwaysIncludeSemantics: false)
        XCTAssertFalse(box.alwaysIncludeSemantics)
        box.alwaysIncludeSemantics = true
        XCTAssertTrue(box.alwaysIncludeSemantics)
    }
}

// MARK: - RenderShaderMask Construction Tests

final class RenderShaderMaskConstructionTests: XCTestCase {

    /// Test construction with shader callback.
    func testConstruction() {
        let box = RenderShaderMask(shaderCallback: { _ in Shader() })
        XCTAssertEqual(box.blendMode, .modulate)
        XCTAssertNil(box.child)
    }

    /// Test construction with custom blend mode.
    func testConstructionWithBlendMode() {
        let box = RenderShaderMask(shaderCallback: { _ in Shader() }, blendMode: .srcOver)
        XCTAssertEqual(box.blendMode, .srcOver)
    }
}

// MARK: - RenderShaderMask Property Tests

final class RenderShaderMaskPropertyTests: XCTestCase {

    /// Test that setting blendMode to same value is no-op.
    func testBlendModeSetterNoOpOnSameValue() {
        let box = RenderShaderMask(shaderCallback: { _ in Shader() }, blendMode: .modulate)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.blendMode = .modulate
        XCTAssertFalse(box.needsPaint)
    }

    /// Test that setting blendMode to different value triggers paint.
    func testBlendModeSetterTriggersPaint() {
        let box = RenderShaderMask(shaderCallback: { _ in Shader() }, blendMode: .modulate)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.blendMode = .srcOver
        XCTAssertTrue(box.needsPaint)
    }

    /// Test shaderCallback setter triggers paint.
    func testShaderCallbackSetterTriggersPaint() {
        let box = RenderShaderMask(shaderCallback: { _ in Shader() })
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.shaderCallback = { _ in Shader() }
        XCTAssertTrue(box.needsPaint)
    }

    /// Test alwaysNeedsCompositing with child.
    func testAlwaysNeedsCompositingWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderShaderMask(child: child, shaderCallback: { _ in Shader() })
        XCTAssertTrue(box.alwaysNeedsCompositing)
    }

    /// Test alwaysNeedsCompositing without child.
    func testAlwaysNeedsCompositingWithoutChild() {
        let box = RenderShaderMask(shaderCallback: { _ in Shader() })
        XCTAssertFalse(box.alwaysNeedsCompositing)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderShaderMask(shaderCallback: { _ in Shader() })
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderBackdropFilter Construction Tests

final class RenderBackdropFilterConstructionTests: XCTestCase {

    /// Test construction with filter.
    func testConstruction() {
        let filter = TestImageFilter()
        let box = RenderBackdropFilter(filter: filter)
        XCTAssertTrue(box.enabled)
        XCTAssertEqual(box.blendMode, .srcOver)
        XCTAssertNil(box.child)
    }

    /// Test construction with custom parameters.
    func testConstructionWithParameters() {
        let filter = TestImageFilter()
        let box = RenderBackdropFilter(filter: filter, blendMode: .multiply, enabled: false)
        XCTAssertFalse(box.enabled)
        XCTAssertEqual(box.blendMode, .multiply)
    }
}

// MARK: - RenderBackdropFilter Property Tests

final class RenderBackdropFilterPropertyTests: XCTestCase {

    /// Test enabled setter triggers paint.
    func testEnabledSetterTriggersPaint() {
        let filter = TestImageFilter()
        let box = RenderBackdropFilter(filter: filter, enabled: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.enabled = false
        XCTAssertTrue(box.needsPaint)
    }

    /// Test enabled setter no-op on same value.
    func testEnabledSetterNoOpOnSameValue() {
        let filter = TestImageFilter()
        let box = RenderBackdropFilter(filter: filter, enabled: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.enabled = true
        XCTAssertFalse(box.needsPaint)
    }

    /// Test blendMode setter triggers paint.
    func testBlendModeSetterTriggersPaint() {
        let filter = TestImageFilter()
        let box = RenderBackdropFilter(filter: filter, blendMode: .srcOver)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.blendMode = .multiply
        XCTAssertTrue(box.needsPaint)
    }

    /// Test blendMode setter no-op on same value.
    func testBlendModeSetterNoOpOnSameValue() {
        let filter = TestImageFilter()
        let box = RenderBackdropFilter(filter: filter, blendMode: .srcOver)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.blendMode = .srcOver
        XCTAssertFalse(box.needsPaint)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let filter = TestImageFilter()
        let box = RenderBackdropFilter(filter: filter)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - CustomClipper Tests

final class CustomClipperTests: XCTestCase {

    /// Test getApproximateClipRect defaults to size rect.
    func testGetApproximateClipRectDefault() {
        let clipper = TestRectClipper(clipRect: Rect.fromLTWH(10, 10, 80, 80))
        let rect = clipper.getApproximateClipRect(Size(100, 100))
        XCTAssertEqual(rect.left, 0.0)
        XCTAssertEqual(rect.top, 0.0)
        XCTAssertEqual(rect.width, 100.0)
        XCTAssertEqual(rect.height, 100.0)
    }

    /// Test getClip returns the configured clip.
    func testGetClipReturnsConfiguredValue() {
        let clipRect = Rect.fromLTWH(10, 20, 30, 40)
        let clipper = TestRectClipper(clipRect: clipRect)
        let result = clipper.getClip(Size(100, 100))
        XCTAssertEqual(result.left, 10.0)
        XCTAssertEqual(result.top, 20.0)
        XCTAssertEqual(result.width, 30.0)
        XCTAssertEqual(result.height, 40.0)
    }

    /// Test shouldReclip returns false for same clip.
    func testShouldReclipFalseForSameClip() {
        let clipRect = Rect.fromLTWH(10, 20, 30, 40)
        let clipper1 = TestRectClipper(clipRect: clipRect)
        let clipper2 = TestRectClipper(clipRect: clipRect)
        XCTAssertFalse(clipper1.shouldReclip(clipper2))
    }

    /// Test shouldReclip returns true for different clip.
    func testShouldReclipTrueForDifferentClip() {
        let clipper1 = TestRectClipper(clipRect: Rect.fromLTWH(10, 20, 30, 40))
        let clipper2 = TestRectClipper(clipRect: Rect.fromLTWH(15, 25, 35, 45))
        XCTAssertTrue(clipper1.shouldReclip(clipper2))
    }
}

// MARK: - RenderClipRect Construction Tests

final class RenderClipRectConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderClipRect()
        XCTAssertNil(box.child)
        XCTAssertNil(box.clipper)
        XCTAssertEqual(box.clipBehavior, .antiAlias)
    }

    /// Test construction with clipper.
    func testConstructionWithClipper() {
        let clipper = TestRectClipper(clipRect: Rect.fromLTWH(10, 10, 80, 80))
        let box = RenderClipRect(clipper: clipper)
        XCTAssertNotNil(box.clipper)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderClipRect(child: child)
        XCTAssertNotNil(box.child)
    }
}

// MARK: - RenderClipRect Property Tests

final class RenderClipRectPropertyTests: XCTestCase {

    /// Test clipBehavior setter triggers paint.
    func testClipBehaviorSetterTriggersPaint() {
        let box = RenderClipRect(clipBehavior: .antiAlias)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.clipBehavior = .hardEdge
        XCTAssertTrue(box.needsPaint)
    }

    /// Test clipBehavior setter no-op on same value.
    func testClipBehaviorSetterNoOpOnSameValue() {
        let box = RenderClipRect(clipBehavior: .antiAlias)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.clipBehavior = .antiAlias
        XCTAssertFalse(box.needsPaint)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderClipRect()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderClipRRect Construction Tests

final class RenderClipRRectConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderClipRRect()
        XCTAssertNil(box.child)
        XCTAssertNil(box.clipper)
        XCTAssertEqual(box.clipBehavior, .antiAlias)
    }

    /// Test construction with border radius.
    func testConstructionWithBorderRadius() {
        let box = RenderClipRRect(borderRadius: BorderRadius.circular(10.0))
        XCTAssertNotNil(box)
    }

    /// Test construction with text direction.
    func testConstructionWithTextDirection() {
        let box = RenderClipRRect(textDirection: .ltr)
        XCTAssertEqual(box.textDirection, .ltr)
    }
}

// MARK: - RenderClipRRect Property Tests

final class RenderClipRRectPropertyTests: XCTestCase {

    /// Test borderRadius setter triggers clip invalidation.
    func testBorderRadiusSetterTriggersClipUpdate() {
        let box = RenderClipRRect(borderRadius: BorderRadius.circular(5.0))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.borderRadius = BorderRadius.circular(10.0)
        XCTAssertTrue(box.needsPaint)
    }

    /// Test borderRadius setter no-op on same value.
    func testBorderRadiusSetterNoOpOnSameValue() {
        let box = RenderClipRRect(borderRadius: BorderRadius.circular(5.0))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.borderRadius = BorderRadius.circular(5.0)
        XCTAssertFalse(box.needsPaint)
    }

    /// Test textDirection setter triggers clip update.
    func testTextDirectionSetterTriggersClipUpdate() {
        let box = RenderClipRRect(textDirection: .ltr)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.textDirection = .rtl
        XCTAssertTrue(box.needsPaint)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderClipRRect()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderClipOval Construction Tests

final class RenderClipOvalConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderClipOval()
        XCTAssertNil(box.child)
        XCTAssertEqual(box.clipBehavior, .antiAlias)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 100)
        let box = RenderClipOval(child: child)
        XCTAssertNotNil(box.child)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderClipOval()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderClipPath Construction Tests

final class RenderClipPathConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderClipPath()
        XCTAssertNil(box.child)
        XCTAssertEqual(box.clipBehavior, .antiAlias)
    }

    /// Test construction with clipper.
    func testConstructionWithClipper() {
        let clipper = TestPathClipper()
        let box = RenderClipPath(clipper: clipper)
        XCTAssertNotNil(box.clipper)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderClipPath()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderCustomClip Property Tests

final class RenderCustomClipPropertyTests: XCTestCase {

    /// Test describeApproximatePaintClip returns nil for .none.
    func testDescribeApproximatePaintClipNone() {
        let box = RenderClipRect(clipBehavior: .none)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        let child = RenderBox()
        XCTAssertNil(box.describeApproximatePaintClip(child))
    }

    /// Test describeApproximatePaintClip returns rect for other behaviors.
    func testDescribeApproximatePaintClipHardEdge() {
        let box = RenderClipRect(clipBehavior: .hardEdge)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        let child = RenderBox()
        let clip = box.describeApproximatePaintClip(child)
        XCTAssertNotNil(clip)
        XCTAssertEqual(clip!.width, 100.0)
        XCTAssertEqual(clip!.height, 100.0)
    }
}

// MARK: - RenderPhysicalModel Construction Tests

final class RenderPhysicalModelConstructionTests: XCTestCase {

    /// Test construction with required color.
    func testConstruction() {
        let box = RenderPhysicalModel(color: Color(0xFF0000FF))
        XCTAssertNil(box.child)
        XCTAssertEqual(box.shape, .rectangle)
        XCTAssertEqual(box.elevation, 0.0)
        XCTAssertEqual(box.clipBehavior, .none)
    }

    /// Test construction with custom parameters.
    func testConstructionWithParameters() {
        let box = RenderPhysicalModel(
            shape: .circle,
            clipBehavior: .antiAlias,
            elevation: 4.0,
            color: Color(0xFFFF0000),
            shadowColor: Color(0x80000000)
        )
        XCTAssertEqual(box.shape, .circle)
        XCTAssertEqual(box.elevation, 4.0)
        XCTAssertEqual(box.clipBehavior, .antiAlias)
    }
}

// MARK: - RenderPhysicalModel Property Tests

final class RenderPhysicalModelPropertyTests: XCTestCase {

    /// Test shape setter triggers paint.
    func testShapeSetterTriggersClipUpdate() {
        let box = RenderPhysicalModel(shape: .rectangle, color: Color(0xFF0000FF))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.shape = .circle
        XCTAssertTrue(box.needsPaint)
    }

    /// Test shape setter no-op on same value.
    func testShapeSetterNoOpOnSameValue() {
        let box = RenderPhysicalModel(shape: .rectangle, color: Color(0xFF0000FF))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.shape = .rectangle
        XCTAssertFalse(box.needsPaint)
    }

    /// Test borderRadius setter triggers paint.
    func testBorderRadiusSetterTriggersClipUpdate() {
        let box = RenderPhysicalModel(color: Color(0xFF0000FF))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.borderRadius = BorderRadius.circular(10.0)
        XCTAssertTrue(box.needsPaint)
    }

    /// Test elevation setter triggers paint.
    func testElevationSetterTriggersPaint() {
        let box = RenderPhysicalModel(elevation: 0.0, color: Color(0xFF0000FF))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.elevation = 4.0
        XCTAssertTrue(box.needsPaint)
    }

    /// Test elevation setter no-op on same value.
    func testElevationSetterNoOpOnSameValue() {
        let box = RenderPhysicalModel(elevation: 4.0, color: Color(0xFF0000FF))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.elevation = 4.0
        XCTAssertFalse(box.needsPaint)
    }

    /// Test color setter triggers paint.
    func testColorSetterTriggersPaint() {
        let box = RenderPhysicalModel(color: Color(0xFF0000FF))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.color = Color(0xFFFF0000)
        XCTAssertTrue(box.needsPaint)
    }

    /// Test shadowColor setter triggers paint.
    func testShadowColorSetterTriggersPaint() {
        let box = RenderPhysicalModel(color: Color(0xFF0000FF))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.shadowColor = Color(0x80000000)
        XCTAssertTrue(box.needsPaint)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderPhysicalModel(color: Color(0xFF0000FF))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderPhysicalShape Construction Tests

final class RenderPhysicalShapeConstructionTests: XCTestCase {

    /// Test construction with clipper and color.
    func testConstruction() {
        let clipper = TestPathClipper()
        let box = RenderPhysicalShape(clipper: clipper, color: Color(0xFF0000FF))
        XCTAssertNil(box.child)
        XCTAssertEqual(box.elevation, 0.0)
        XCTAssertEqual(box.clipBehavior, .none)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let clipper = TestPathClipper()
        let box = RenderPhysicalShape(clipper: clipper, color: Color(0xFF0000FF))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - DecorationPosition Tests

final class DecorationPositionTests: XCTestCase {

    /// Test both cases exist.
    func testCasesExist() {
        let bg = DecorationPosition.background
        let fg = DecorationPosition.foreground
        XCTAssertNotNil(bg)
        XCTAssertNotNil(fg)
        XCTAssertTrue(bg != fg)
    }
}

// MARK: - RenderDecoratedBox Construction Tests

final class RenderDecoratedBoxConstructionTests: XCTestCase {

    /// Test construction with decoration.
    func testConstruction() {
        let decoration = BoxDecoration()
        let box = RenderDecoratedBox(decoration: decoration)
        XCTAssertNil(box.child)
        XCTAssertEqual(box.position, .background)
    }

    /// Test construction with foreground position.
    func testConstructionWithForegroundPosition() {
        let decoration = BoxDecoration()
        let box = RenderDecoratedBox(decoration: decoration, position: .foreground)
        XCTAssertEqual(box.position, .foreground)
    }
}

// MARK: - RenderDecoratedBox Property Tests

final class RenderDecoratedBoxPropertyTests: XCTestCase {

    /// Test position setter triggers paint.
    func testPositionSetterTriggersPaint() {
        let decoration = BoxDecoration()
        let box = RenderDecoratedBox(decoration: decoration, position: .background)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.position = .foreground
        XCTAssertTrue(box.needsPaint)
    }

    /// Test position setter no-op on same value.
    func testPositionSetterNoOpOnSameValue() {
        let decoration = BoxDecoration()
        let box = RenderDecoratedBox(decoration: decoration, position: .background)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.position = .background
        XCTAssertFalse(box.needsPaint)
    }

    /// Test decoration setter triggers paint.
    func testDecorationSetterTriggersPaint() {
        let decoration = BoxDecoration()
        let box = RenderDecoratedBox(decoration: decoration)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.decoration = BoxDecoration(color: Color(0xFFFF0000))
        XCTAssertTrue(box.needsPaint)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let decoration = BoxDecoration()
        let box = RenderDecoratedBox(decoration: decoration)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderTransform Construction Tests

final class RenderTransformConstructionTests: XCTestCase {

    /// Test construction with identity transform.
    func testConstruction() {
        let box = RenderTransform(transform: Matrix4.identity())
        XCTAssertNil(box.child)
        XCTAssertTrue(box.transformHitTests)
        XCTAssertNil(box.filterQuality)
    }

    /// Test construction with custom parameters.
    func testConstructionWithParameters() {
        let transform = Matrix4.translationValues(10, 20, 0)
        let box = RenderTransform(
            transform: transform,
            origin: Offset(50, 50),
            textDirection: .ltr,
            transformHitTests: false
        )
        XCTAssertNotNil(box.origin)
        XCTAssertEqual(box.origin!.dx, 50.0)
        XCTAssertEqual(box.origin!.dy, 50.0)
        XCTAssertFalse(box.transformHitTests)
    }
}

// MARK: - RenderTransform Property Tests

final class RenderTransformPropertyTests: XCTestCase {

    /// Test origin setter triggers paint.
    func testOriginSetterTriggersPaint() {
        let box = RenderTransform(transform: Matrix4.identity())
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.origin = Offset(10, 20)
        XCTAssertTrue(box.needsPaint)
    }

    /// Test origin setter no-op on same value.
    func testOriginSetterNoOpOnSameValue() {
        let box = RenderTransform(transform: Matrix4.identity(), origin: Offset(10, 20))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.origin = Offset(10, 20)
        XCTAssertFalse(box.needsPaint)
    }

    /// Test textDirection setter triggers paint.
    func testTextDirectionSetterTriggersPaint() {
        let box = RenderTransform(transform: Matrix4.identity(), textDirection: .ltr)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.textDirection = .rtl
        XCTAssertTrue(box.needsPaint)
    }

    /// Test transform setter triggers paint.
    func testTransformSetterTriggersPaint() {
        let box = RenderTransform(transform: Matrix4.identity())
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.transform = Matrix4.translationValues(10, 0, 0)
        XCTAssertTrue(box.needsPaint)
    }

    /// Test filterQuality setter triggers paint.
    func testFilterQualitySetterTriggersPaint() {
        let box = RenderTransform(transform: Matrix4.identity())
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.filterQuality = .medium
        XCTAssertTrue(box.needsPaint)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderTransform(transform: Matrix4.identity())
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderFittedBox Construction Tests

final class RenderFittedBoxConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderFittedBox()
        XCTAssertNil(box.child)
        XCTAssertEqual(box.fit, .contain)
        XCTAssertEqual(box.clipBehavior, .none)
    }

    /// Test construction with custom fit.
    func testConstructionWithFit() {
        let box = RenderFittedBox(fit: .cover)
        XCTAssertEqual(box.fit, .cover)
    }

    /// Test construction with clip behavior.
    func testConstructionWithClipBehavior() {
        let box = RenderFittedBox(clipBehavior: .hardEdge)
        XCTAssertEqual(box.clipBehavior, .hardEdge)
    }
}

// MARK: - RenderFittedBox Property Tests

final class RenderFittedBoxPropertyTests: XCTestCase {

    /// Test fit setter triggers appropriate update.
    func testFitSetterTriggersPaint() {
        let box = RenderFittedBox(fit: .contain)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.fit = .cover
        XCTAssertTrue(box.needsPaint)
    }

    /// Test fit setter no-op on same value.
    func testFitSetterNoOpOnSameValue() {
        let box = RenderFittedBox(fit: .contain)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.fit = .contain
        XCTAssertFalse(box.needsPaint)
    }

    /// Test scaleDown fit triggers layout.
    func testScaleDownFitTriggersLayout() {
        let box = RenderFittedBox(fit: .contain)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)
        box.fit = .scaleDown
        XCTAssertTrue(box.needsLayout)
    }

    /// Test clipBehavior setter triggers paint.
    func testClipBehaviorSetterTriggersPaint() {
        let box = RenderFittedBox(clipBehavior: .none)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.clipBehavior = .hardEdge
        XCTAssertTrue(box.needsPaint)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderFittedBox()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderFittedBox Layout Tests

final class RenderFittedBoxLayoutTests: XCTestCase {

    /// Test layout without child returns smallest.
    func testLayoutWithoutChild() {
        let box = RenderFittedBox()
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(box.size.width, 0.0)
        XCTAssertEqual(box.size.height, 0.0)
    }

    /// Test dry layout without child.
    func testDryLayoutWithoutChild() {
        let box = RenderFittedBox()
        let size = box.computeDryLayout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(size.width, 0.0)
        XCTAssertEqual(size.height, 0.0)
    }
}

// MARK: - RenderFractionalTranslation Construction Tests

final class RenderFractionalTranslationConstructionTests: XCTestCase {

    /// Test construction with translation.
    func testConstruction() {
        let box = RenderFractionalTranslation(translation: Offset(0.25, 0.5))
        XCTAssertNil(box.child)
        XCTAssertEqual(box.translation.dx, 0.25)
        XCTAssertEqual(box.translation.dy, 0.5)
        XCTAssertTrue(box.transformHitTests)
    }

    /// Test construction with transformHitTests disabled.
    func testConstructionWithTransformHitTestsDisabled() {
        let box = RenderFractionalTranslation(translation: Offset(0, 0), transformHitTests: false)
        XCTAssertFalse(box.transformHitTests)
    }
}

// MARK: - RenderFractionalTranslation Property Tests

final class RenderFractionalTranslationPropertyTests: XCTestCase {

    /// Test translation setter triggers paint.
    func testTranslationSetterTriggersPaint() {
        let box = RenderFractionalTranslation(translation: Offset(0, 0))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.translation = Offset(0.5, 0.5)
        XCTAssertTrue(box.needsPaint)
    }

    /// Test translation setter no-op on same value.
    func testTranslationSetterNoOpOnSameValue() {
        let box = RenderFractionalTranslation(translation: Offset(0.5, 0.5))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.translation = Offset(0.5, 0.5)
        XCTAssertFalse(box.needsPaint)
    }
}

// MARK: - RenderPointerListener Construction Tests

final class RenderPointerListenerConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderPointerListener()
        XCTAssertNil(box.child)
        XCTAssertNil(box.onPointerDown)
        XCTAssertNil(box.onPointerMove)
        XCTAssertNil(box.onPointerUp)
        XCTAssertNil(box.onPointerCancel)
        XCTAssertNil(box.onPointerSignal)
        XCTAssertEqual(box.behavior, .deferToChild)
    }

    /// Test construction with callbacks.
    func testConstructionWithCallbacks() {
        var called = false
        let box = RenderPointerListener(
            onPointerDown: { _ in called = true },
            behavior: .opaque
        )
        XCTAssertNotNil(box.onPointerDown)
        XCTAssertEqual(box.behavior, .opaque)
        // The callback is stored but not invoked yet
        XCTAssertFalse(called)
    }

    /// Test computeSizeForNoChild returns biggest.
    func testComputeSizeForNoChild() {
        let box = RenderPointerListener()
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 300)
        let size = box.computeSizeForNoChild(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 300.0)
    }
}

// MARK: - RenderMouseRegion Construction Tests

final class RenderMouseRegionConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderMouseRegion()
        XCTAssertNil(box.child)
        XCTAssertNil(box.onEnter)
        XCTAssertNil(box.onHover)
        XCTAssertNil(box.onExit)
        XCTAssertTrue(box.opaque)
        XCTAssertTrue(box.validForMouseTracker)
    }

    /// Test construction with custom parameters.
    func testConstructionWithParameters() {
        let box = RenderMouseRegion(
            onEnter: { _ in },
            onHover: { _ in },
            onExit: { _ in },
            opaque: false,
            hitTestBehavior: .translucent
        )
        XCTAssertNotNil(box.onEnter)
        XCTAssertNotNil(box.onHover)
        XCTAssertNotNil(box.onExit)
        XCTAssertFalse(box.opaque)
        XCTAssertEqual(box.behavior, .translucent)
    }

    /// Test computeSizeForNoChild returns biggest.
    func testComputeSizeForNoChild() {
        let box = RenderMouseRegion()
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 300)
        let size = box.computeSizeForNoChild(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 300.0)
    }
}

// MARK: - RenderMouseRegion Property Tests

final class RenderMouseRegionPropertyTests: XCTestCase {

    /// Test opaque setter triggers paint.
    func testOpaqueSetterTriggersPaint() {
        let box = RenderMouseRegion(opaque: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.opaque = false
        XCTAssertTrue(box.needsPaint)
    }

    /// Test opaque setter no-op on same value.
    func testOpaqueSetterNoOpOnSameValue() {
        let box = RenderMouseRegion(opaque: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.opaque = true
        XCTAssertFalse(box.needsPaint)
    }

    /// Test attach sets validForMouseTracker.
    func testAttachSetsValidForMouseTracker() {
        let box = RenderMouseRegion()
        let owner = PipelineOwner()
        box.attach(owner)
        XCTAssertTrue(box.validForMouseTracker)
    }

    /// Test detach clears validForMouseTracker.
    func testDetachClearsValidForMouseTracker() {
        let box = RenderMouseRegion()
        let owner = PipelineOwner()
        box.attach(owner)
        box.detach()
        XCTAssertFalse(box.validForMouseTracker)
    }
}

// MARK: - RenderRepaintBoundary Tests

final class RenderRepaintBoundaryTests: XCTestCase {

    /// Test construction.
    func testConstruction() {
        let box = RenderRepaintBoundary()
        XCTAssertNil(box.child)
        XCTAssertTrue(box.isRepaintBoundary)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRepaintBoundary(child: child)
        XCTAssertNotNil(box.child)
    }

    /// Test isRepaintBoundary is always true.
    func testIsRepaintBoundaryAlwaysTrue() {
        let box = RenderRepaintBoundary()
        XCTAssertTrue(box.isRepaintBoundary)
    }

    /// Test debug metrics initial values.
    func testDebugMetricsInitialValues() {
        let box = RenderRepaintBoundary()
        XCTAssertEqual(box.debugSymmetricPaintCount, 0)
        XCTAssertEqual(box.debugAsymmetricPaintCount, 0)
    }

    /// Test debugResetMetrics resets counts.
    func testDebugResetMetrics() {
        let box = RenderRepaintBoundary()
        box.debugSymmetricPaintCount = 10
        box.debugAsymmetricPaintCount = 5
        box.debugResetMetrics()
        XCTAssertEqual(box.debugSymmetricPaintCount, 0)
        XCTAssertEqual(box.debugAsymmetricPaintCount, 0)
    }

    /// Test offscreenBufferPixelRatio default.
    func testOffscreenBufferPixelRatioDefault() {
        let box = RenderRepaintBoundary()
        XCTAssertEqual(box.offscreenBufferPixelRatio, 1.0)
    }
}

// MARK: - RenderIgnorePointer Construction Tests

final class RenderIgnorePointerConstructionTests: XCTestCase {

    /// Test default construction with ignoring=true.
    func testDefaultConstruction() {
        let box = RenderIgnorePointer()
        XCTAssertTrue(box.ignoring)
        XCTAssertNil(box.child)
    }

    /// Test construction with ignoring=false.
    func testConstructionNotIgnoring() {
        let box = RenderIgnorePointer(ignoring: false)
        XCTAssertFalse(box.ignoring)
    }
}

// MARK: - RenderIgnorePointer Property Tests

final class RenderIgnorePointerPropertyTests: XCTestCase {

    /// Test ignoring setter triggers paint.
    func testIgnoringSetterTriggersPaint() {
        let box = RenderIgnorePointer(ignoring: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.ignoring = false
        XCTAssertTrue(box.needsPaint)
    }

    /// Test ignoring setter no-op on same value.
    func testIgnoringSetterNoOpOnSameValue() {
        let box = RenderIgnorePointer(ignoring: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.ignoring = true
        XCTAssertFalse(box.needsPaint)
    }

    /// Test hitTest returns false when ignoring.
    func testHitTestReturnsFalseWhenIgnoring() {
        let box = RenderIgnorePointer(ignoring: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        let result = BoxHitTestResult()
        XCTAssertFalse(box.hitTest(result, position: Offset(50, 50)))
    }
}

// MARK: - RenderOffstage Construction Tests

final class RenderOffstageConstructionTests: XCTestCase {

    /// Test default construction with offstage=true.
    func testDefaultConstruction() {
        let box = RenderOffstage()
        XCTAssertTrue(box.offstage)
        XCTAssertNil(box.child)
    }

    /// Test construction with offstage=false.
    func testConstructionNotOffstage() {
        let box = RenderOffstage(offstage: false)
        XCTAssertFalse(box.offstage)
    }
}

// MARK: - RenderOffstage Property Tests

final class RenderOffstagePropertyTests: XCTestCase {

    /// Test offstage setter triggers layout.
    func testOffstageSetterTriggersLayout() {
        let box = RenderOffstage(offstage: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)
        box.offstage = false
        XCTAssertTrue(box.needsLayout)
    }

    /// Test offstage setter no-op on same value.
    func testOffstageSetterNoOpOnSameValue() {
        let box = RenderOffstage(offstage: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)
        box.offstage = true
        XCTAssertFalse(box.needsLayout)
    }

    /// Test sizedByParent when offstage.
    func testSizedByParentWhenOffstage() {
        let box = RenderOffstage(offstage: true)
        XCTAssertTrue(box.sizedByParent)
    }

    /// Test sizedByParent when not offstage.
    func testSizedByParentWhenNotOffstage() {
        let box = RenderOffstage(offstage: false)
        XCTAssertFalse(box.sizedByParent)
    }
}

// MARK: - RenderOffstage Intrinsic Tests

final class RenderOffstageIntrinsicTests: XCTestCase {

    /// Test intrinsics return 0 when offstage.
    func testIntrinsicsZeroWhenOffstage() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderOffstage(offstage: true, child: child)
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 0.0)
    }

    /// Test intrinsics delegate to child when not offstage.
    func testIntrinsicsDelegateWhenNotOffstage() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderOffstage(offstage: false, child: child)
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 100.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 100.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 50.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 50.0)
    }
}

// MARK: - RenderOffstage Layout Tests

final class RenderOffstageLayoutTests: XCTestCase {

    /// Test dry layout returns smallest when offstage.
    func testDryLayoutReturnsSmallestWhenOffstage() {
        let box = RenderOffstage(offstage: true)
        let size = box.computeDryLayout(BoxConstraints(minWidth: 5, maxWidth: 200, minHeight: 10, maxHeight: 200))
        XCTAssertEqual(size.width, 5.0)
        XCTAssertEqual(size.height, 10.0)
    }

    /// Test hitTest returns false when offstage.
    func testHitTestReturnsFalseWhenOffstage() {
        let box = RenderOffstage(offstage: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        let result = BoxHitTestResult()
        XCTAssertFalse(box.hitTest(result, position: Offset(50, 50)))
    }

    /// Test baseline returns nil when offstage.
    func testBaselineNilWhenOffstage() {
        let box = RenderOffstage(offstage: true)
        XCTAssertNil(box.computeDistanceToActualBaseline(.alphabetic))
    }
}

// MARK: - RenderAbsorbPointer Construction Tests

final class RenderAbsorbPointerConstructionTests: XCTestCase {

    /// Test default construction with absorbing=true.
    func testDefaultConstruction() {
        let box = RenderAbsorbPointer()
        XCTAssertTrue(box.absorbing)
        XCTAssertNil(box.child)
    }

    /// Test construction with absorbing=false.
    func testConstructionNotAbsorbing() {
        let box = RenderAbsorbPointer(absorbing: false)
        XCTAssertFalse(box.absorbing)
    }
}

// MARK: - RenderAbsorbPointer Property Tests

final class RenderAbsorbPointerPropertyTests: XCTestCase {

    /// Test absorbing setter triggers paint.
    func testAbsorbingSetterTriggersPaint() {
        let box = RenderAbsorbPointer(absorbing: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.absorbing = false
        XCTAssertTrue(box.needsPaint)
    }

    /// Test absorbing setter no-op on same value.
    func testAbsorbingSetterNoOpOnSameValue() {
        let box = RenderAbsorbPointer(absorbing: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.absorbing = true
        XCTAssertFalse(box.needsPaint)
    }

    /// Test hitTest absorbs when position within bounds.
    func testHitTestAbsorbsWhenWithinBounds() {
        let box = RenderAbsorbPointer(absorbing: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        let result = BoxHitTestResult()
        XCTAssertTrue(box.hitTest(result, position: Offset(50, 50)))
    }

    /// Test hitTest does not absorb outside bounds.
    func testHitTestDoesNotAbsorbOutsideBounds() {
        let box = RenderAbsorbPointer(absorbing: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        let result = BoxHitTestResult()
        XCTAssertFalse(box.hitTest(result, position: Offset(150, 150)))
    }
}

// MARK: - RenderMetaData Tests

final class RenderMetaDataTests: XCTestCase {

    /// Test construction with metadata.
    func testConstruction() {
        let box = RenderMetaData(metaData: "test value")
        XCTAssertNotNil(box.metaData)
        XCTAssertEqual(box.metaData as? String, "test value")
        XCTAssertNil(box.child)
    }

    /// Test construction without metadata.
    func testConstructionWithoutMetaData() {
        let box = RenderMetaData()
        XCTAssertNil(box.metaData)
    }

    /// Test setting metadata.
    func testSettingMetaData() {
        let box = RenderMetaData()
        box.metaData = 42
        XCTAssertEqual(box.metaData as? Int, 42)
    }

    /// Test setting metadata to nil.
    func testSettingMetaDataToNil() {
        let box = RenderMetaData(metaData: "test")
        box.metaData = nil
        XCTAssertNil(box.metaData)
    }
}

// MARK: - RenderSemanticsGestureHandler Construction Tests

final class RenderSemanticsGestureHandlerConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderSemanticsGestureHandler()
        XCTAssertNil(box.child)
        XCTAssertNil(box.onTap)
        XCTAssertNil(box.onLongPress)
        XCTAssertNil(box.onHorizontalDragUpdate)
        XCTAssertNil(box.onVerticalDragUpdate)
        XCTAssertEqual(box.scrollFactor, 0.8)
    }

    /// Test construction with callbacks.
    func testConstructionWithCallbacks() {
        let box = RenderSemanticsGestureHandler(
            onTap: {},
            onLongPress: {},
            scrollFactor: 0.5
        )
        XCTAssertNotNil(box.onTap)
        XCTAssertNotNil(box.onLongPress)
        XCTAssertEqual(box.scrollFactor, 0.5)
    }
}

// MARK: - RenderSemanticsGestureHandler Property Tests

final class RenderSemanticsGestureHandlerPropertyTests: XCTestCase {

    /// Test validActions setter.
    func testValidActionsSetter() {
        let box = RenderSemanticsGestureHandler()
        XCTAssertNil(box.validActions)
        box.validActions = [.tap, .longPress]
        XCTAssertNotNil(box.validActions)
        XCTAssertEqual(box.validActions!.count, 2)
    }

    /// Test setting onTap.
    func testOnTapSetter() {
        let box = RenderSemanticsGestureHandler()
        XCTAssertNil(box.onTap)
        box.onTap = {}
        XCTAssertNotNil(box.onTap)
    }

    /// Test setting onLongPress.
    func testOnLongPressSetter() {
        let box = RenderSemanticsGestureHandler()
        XCTAssertNil(box.onLongPress)
        box.onLongPress = {}
        XCTAssertNotNil(box.onLongPress)
    }
}

// MARK: - RenderSemanticsAnnotations Construction Tests

final class RenderSemanticsAnnotationsConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderSemanticsAnnotations()
        XCTAssertNil(box.child)
        XCTAssertFalse(box.container)
        XCTAssertFalse(box.explicitChildNodes)
        XCTAssertFalse(box.excludeSemantics)
        XCTAssertFalse(box.blockUserActions)
    }

    /// Test construction with custom parameters.
    func testConstructionWithParameters() {
        let box = RenderSemanticsAnnotations(
            container: true,
            explicitChildNodes: true,
            excludeSemantics: true,
            blockUserActions: true
        )
        XCTAssertTrue(box.container)
        XCTAssertTrue(box.explicitChildNodes)
        XCTAssertTrue(box.excludeSemantics)
        XCTAssertTrue(box.blockUserActions)
    }
}

// MARK: - RenderSemanticsAnnotations Property Tests

final class RenderSemanticsAnnotationsPropertyTests: XCTestCase {

    /// Test container setter.
    func testContainerSetter() {
        let box = RenderSemanticsAnnotations(container: false)
        box.container = true
        XCTAssertTrue(box.container)
    }

    /// Test explicitChildNodes setter.
    func testExplicitChildNodesSetter() {
        let box = RenderSemanticsAnnotations(explicitChildNodes: false)
        box.explicitChildNodes = true
        XCTAssertTrue(box.explicitChildNodes)
    }

    /// Test excludeSemantics setter.
    func testExcludeSemanticsSetter() {
        let box = RenderSemanticsAnnotations(excludeSemantics: false)
        box.excludeSemantics = true
        XCTAssertTrue(box.excludeSemantics)
    }

    /// Test blockUserActions setter.
    func testBlockUserActionsSetter() {
        let box = RenderSemanticsAnnotations(blockUserActions: false)
        box.blockUserActions = true
        XCTAssertTrue(box.blockUserActions)
    }
}

// MARK: - RenderBlockSemantics Tests

final class RenderBlockSemanticsTests: XCTestCase {

    /// Test default construction with blocking=true.
    func testDefaultConstruction() {
        let box = RenderBlockSemantics()
        XCTAssertTrue(box.blocking)
    }

    /// Test construction with blocking=false.
    func testConstructionNotBlocking() {
        let box = RenderBlockSemantics(blocking: false)
        XCTAssertFalse(box.blocking)
    }

    /// Test blocking setter.
    func testBlockingSetter() {
        let box = RenderBlockSemantics(blocking: true)
        box.blocking = false
        XCTAssertFalse(box.blocking)
    }

    /// Test blocking setter no-op on same value.
    func testBlockingSetterNoOpOnSameValue() {
        let box = RenderBlockSemantics(blocking: true)
        box.blocking = true
        XCTAssertTrue(box.blocking)
    }

    /// Test describeSemanticsConfiguration sets blocking.
    func testDescribeSemanticsConfiguration() {
        let box = RenderBlockSemantics(blocking: true)
        let config = SemanticsConfiguration()
        box.describeSemanticsConfiguration(config)
        XCTAssertTrue(config.isBlockingSemanticsOfPreviouslyPaintedNodes)
    }
}

// MARK: - RenderMergeSemantics Tests

final class RenderMergeSemanticsTests: XCTestCase {

    /// Test construction.
    func testConstruction() {
        let box = RenderMergeSemantics()
        XCTAssertNil(box.child)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderMergeSemantics(child: child)
        XCTAssertNotNil(box.child)
    }

    /// Test describeSemanticsConfiguration.
    func testDescribeSemanticsConfiguration() {
        let box = RenderMergeSemantics()
        let config = SemanticsConfiguration()
        box.describeSemanticsConfiguration(config)
        XCTAssertTrue(config.isSemanticBoundary)
        XCTAssertTrue(config.isMergingSemanticsOfDescendants)
    }
}

// MARK: - RenderExcludeSemantics Tests

final class RenderExcludeSemanticsTests: XCTestCase {

    /// Test default construction with excluding=true.
    func testDefaultConstruction() {
        let box = RenderExcludeSemantics()
        XCTAssertTrue(box.excluding)
    }

    /// Test construction with excluding=false.
    func testConstructionNotExcluding() {
        let box = RenderExcludeSemantics(excluding: false)
        XCTAssertFalse(box.excluding)
    }

    /// Test excluding setter.
    func testExcludingSetter() {
        let box = RenderExcludeSemantics(excluding: true)
        box.excluding = false
        XCTAssertFalse(box.excluding)
    }

    /// Test excluding setter no-op on same value.
    func testExcludingSetterNoOpOnSameValue() {
        let box = RenderExcludeSemantics(excluding: true)
        box.excluding = true
        XCTAssertTrue(box.excluding)
    }

    /// Test visitChildrenForSemantics skips when excluding.
    func testVisitChildrenSkipsWhenExcluding() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderExcludeSemantics(child: child, excluding: true)
        var visited = false
        box.visitChildrenForSemantics { _ in visited = true }
        XCTAssertFalse(visited)
    }

    /// Test visitChildrenForSemantics visits when not excluding.
    func testVisitChildrenVisitsWhenNotExcluding() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderExcludeSemantics(child: child, excluding: false)
        var visited = false
        box.visitChildrenForSemantics { _ in visited = true }
        XCTAssertTrue(visited)
    }
}

// MARK: - RenderIndexedSemantics Tests

final class RenderIndexedSemanticsTests: XCTestCase {

    /// Test construction with index.
    func testConstruction() {
        let box = RenderIndexedSemantics(index: 5)
        XCTAssertEqual(box.index, 5)
        XCTAssertNil(box.child)
    }

    /// Test index setter.
    func testIndexSetter() {
        let box = RenderIndexedSemantics(index: 5)
        box.index = 10
        XCTAssertEqual(box.index, 10)
    }

    /// Test index setter no-op on same value.
    func testIndexSetterNoOpOnSameValue() {
        let box = RenderIndexedSemantics(index: 5)
        box.index = 5
        XCTAssertEqual(box.index, 5)
    }

    /// Test describeSemanticsConfiguration sets index.
    func testDescribeSemanticsConfiguration() {
        let box = RenderIndexedSemantics(index: 7)
        let config = SemanticsConfiguration()
        box.describeSemanticsConfiguration(config)
        XCTAssertEqual(config.indexInParent, 7)
    }
}

// MARK: - RenderLeaderLayer Construction Tests

final class RenderLeaderLayerConstructionTests: XCTestCase {

    /// Test construction with link.
    func testConstruction() {
        let link = LayerLink()
        let box = RenderLeaderLayer(link: link)
        XCTAssertTrue(box.link === link)
        XCTAssertNil(box.child)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let link = LayerLink()
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderLeaderLayer(link: link, child: child)
        XCTAssertNotNil(box.child)
    }
}

// MARK: - RenderLeaderLayer Property Tests

final class RenderLeaderLayerPropertyTests: XCTestCase {

    /// Test link setter triggers paint.
    func testLinkSetterTriggersPaint() {
        let link1 = LayerLink()
        let link2 = LayerLink()
        let box = RenderLeaderLayer(link: link1)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.link = link2
        XCTAssertTrue(box.needsPaint)
    }

    /// Test link setter no-op on same instance.
    func testLinkSetterNoOpOnSameInstance() {
        let link = LayerLink()
        let box = RenderLeaderLayer(link: link)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.link = link
        XCTAssertFalse(box.needsPaint)
    }

    /// Test alwaysNeedsCompositing is true.
    func testAlwaysNeedsCompositing() {
        let link = LayerLink()
        let box = RenderLeaderLayer(link: link)
        XCTAssertTrue(box.alwaysNeedsCompositing)
    }

    /// Test performLayout sets leaderSize on link.
    func testPerformLayoutSetsLeaderSize() {
        let link = LayerLink()
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let box = RenderLeaderLayer(link: link, child: child)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertNotNil(link.leaderSize)
        XCTAssertEqual(link.leaderSize!.width, 80.0)
        XCTAssertEqual(link.leaderSize!.height, 60.0)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let link = LayerLink()
        let box = RenderLeaderLayer(link: link)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - RenderFollowerLayer Construction Tests

final class RenderFollowerLayerConstructionTests: XCTestCase {

    /// Test construction with link.
    func testConstruction() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link)
        XCTAssertTrue(box.link === link)
        XCTAssertTrue(box.showWhenUnlinked)
        XCTAssertEqual(box.offset, .zero)
        XCTAssertEqual(box.leaderAnchor, .topLeft)
        XCTAssertEqual(box.followerAnchor, .topLeft)
        XCTAssertNil(box.child)
    }

    /// Test construction with custom parameters.
    func testConstructionWithParameters() {
        let link = LayerLink()
        let box = RenderFollowerLayer(
            link: link,
            showWhenUnlinked: false,
            offset: Offset(10, 20),
            leaderAnchor: .center,
            followerAnchor: .bottomRight
        )
        XCTAssertFalse(box.showWhenUnlinked)
        XCTAssertEqual(box.offset.dx, 10.0)
        XCTAssertEqual(box.offset.dy, 20.0)
        XCTAssertEqual(box.leaderAnchor, .center)
        XCTAssertEqual(box.followerAnchor, .bottomRight)
    }
}

// MARK: - RenderFollowerLayer Property Tests

final class RenderFollowerLayerPropertyTests: XCTestCase {

    /// Test link setter triggers paint.
    func testLinkSetterTriggersPaint() {
        let link1 = LayerLink()
        let link2 = LayerLink()
        let box = RenderFollowerLayer(link: link1)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.link = link2
        XCTAssertTrue(box.needsPaint)
    }

    /// Test showWhenUnlinked setter triggers paint.
    func testShowWhenUnlinkedSetterTriggersPaint() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link, showWhenUnlinked: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.showWhenUnlinked = false
        XCTAssertTrue(box.needsPaint)
    }

    /// Test offset setter triggers paint.
    func testOffsetSetterTriggersPaint() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.offset = Offset(10, 20)
        XCTAssertTrue(box.needsPaint)
    }

    /// Test offset setter no-op on same value.
    func testOffsetSetterNoOpOnSameValue() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link, offset: Offset(10, 20))
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.offset = Offset(10, 20)
        XCTAssertFalse(box.needsPaint)
    }

    /// Test leaderAnchor setter triggers paint.
    func testLeaderAnchorSetterTriggersPaint() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.leaderAnchor = .center
        XCTAssertTrue(box.needsPaint)
    }

    /// Test followerAnchor setter triggers paint.
    func testFollowerAnchorSetterTriggersPaint() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.followerAnchor = .center
        XCTAssertTrue(box.needsPaint)
    }

    /// Test alwaysNeedsCompositing is true.
    func testAlwaysNeedsCompositing() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link)
        XCTAssertTrue(box.alwaysNeedsCompositing)
    }

    /// Test sizedByParent is false.
    func testSizedByParentFalse() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link)
        XCTAssertFalse(box.sizedByParent)
    }

    /// Test getCurrentTransform returns identity when no follower layer.
    func testGetCurrentTransformReturnsIdentity() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link)
        let transform = box.getCurrentTransform()
        XCTAssertEqual(transform, Matrix4.identity())
    }

    /// Test hitTest returns false when unlinked and showWhenUnlinked is false.
    func testHitTestReturnsFalseWhenUnlinkedAndHidden() {
        let link = LayerLink()
        let box = RenderFollowerLayer(link: link, showWhenUnlinked: false)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        let result = BoxHitTestResult()
        XCTAssertFalse(box.hitTest(result, position: Offset(50, 50)))
    }
}

// MARK: - RenderAnnotatedRegion Construction Tests

final class RenderAnnotatedRegionConstructionTests: XCTestCase {

    /// Test construction with value.
    func testConstruction() {
        let box = RenderAnnotatedRegion<String>(value: "test", sized: true)
        XCTAssertEqual(box.value, "test")
        XCTAssertTrue(box.sized)
        XCTAssertNil(box.child)
    }

    /// Test construction with sized=false.
    func testConstructionUnsized() {
        let box = RenderAnnotatedRegion<Int>(value: 42, sized: false)
        XCTAssertEqual(box.value, 42)
        XCTAssertFalse(box.sized)
    }
}

// MARK: - RenderAnnotatedRegion Property Tests

final class RenderAnnotatedRegionPropertyTests: XCTestCase {

    /// Test value setter triggers paint.
    func testValueSetterTriggersPaint() {
        let box = RenderAnnotatedRegion<String>(value: "hello", sized: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.value = "world"
        XCTAssertTrue(box.needsPaint)
        XCTAssertEqual(box.value, "world")
    }

    /// Test sized setter triggers paint.
    func testSizedSetterTriggersPaint() {
        let box = RenderAnnotatedRegion<String>(value: "test", sized: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.sized = false
        XCTAssertTrue(box.needsPaint)
    }

    /// Test sized setter no-op on same value.
    func testSizedSetterNoOpOnSameValue() {
        let box = RenderAnnotatedRegion<String>(value: "test", sized: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false
        box.sized = true
        XCTAssertFalse(box.needsPaint)
    }

    /// Test alwaysNeedsCompositing is true.
    func testAlwaysNeedsCompositing() {
        let box = RenderAnnotatedRegion<String>(value: "test", sized: true)
        XCTAssertTrue(box.alwaysNeedsCompositing)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderAnnotatedRegion<String>(value: "test", sized: true)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

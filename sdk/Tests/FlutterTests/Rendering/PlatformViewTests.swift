// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for PlatformView rendering types from the Rendering layer.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/platform_view_test.dart`

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A minimal concrete PlatformViewController for testing.
private class StubPlatformViewController: PlatformViewController {
    let viewId: Int
    var dispatchedEvents: [PointerEvent] = []

    init(viewId: Int) {
        self.viewId = viewId
    }

    func dispatchPointerEvent(_ event: PointerEvent) {
        dispatchedEvents.append(event)
    }
}

/// A concrete RenderBox subclass for testing parent data setup.
private class TestRenderBox: RenderBox {
    override func performLayout() {
        size = boxConstraints.constrain(Size(boxConstraints.maxWidth, boxConstraints.maxHeight))
    }

    override func computeDryLayout(_ constraints: BoxConstraints) -> Size {
        return constraints.constrain(Size(constraints.maxWidth, constraints.maxHeight))
    }
}

// MARK: - PlatformViewHitTestBehavior Tests

final class PlatformViewHitTestBehaviorTests: XCTestCase {

    /// Test that all three cases of PlatformViewHitTestBehavior exist.
    func testAllCasesExist() {
        let opaque = PlatformViewHitTestBehavior.opaque
        let translucent = PlatformViewHitTestBehavior.translucent
        let transparent = PlatformViewHitTestBehavior.transparent

        XCTAssertNotNil(opaque)
        XCTAssertNotNil(translucent)
        XCTAssertNotNil(transparent)
    }

    /// Test that the three cases are distinct.
    func testCasesAreDistinct() {
        XCTAssertNotEqual(
            PlatformViewHitTestBehavior.opaque,
            PlatformViewHitTestBehavior.translucent
        )
        XCTAssertNotEqual(
            PlatformViewHitTestBehavior.opaque,
            PlatformViewHitTestBehavior.transparent
        )
        XCTAssertNotEqual(
            PlatformViewHitTestBehavior.translucent,
            PlatformViewHitTestBehavior.transparent
        )
    }

    /// Test Sendable conformance by assigning across isolation boundaries.
    func testSendableConformance() {
        let behavior: PlatformViewHitTestBehavior = .opaque
        let _: Sendable = behavior
        XCTAssertEqual(behavior, .opaque)
    }
}

// MARK: - PlatformViewState Tests

final class PlatformViewStateTests: XCTestCase {

    /// Test that all three internal PlatformViewState cases exist.
    func testAllCasesExist() {
        let uninitialized = PlatformViewState.uninitialized
        let resizing = PlatformViewState.resizing
        let ready = PlatformViewState.ready

        XCTAssertNotNil(uninitialized)
        XCTAssertNotNil(resizing)
        XCTAssertNotNil(ready)
    }

    /// Test that the three cases are distinct.
    func testCasesAreDistinct() {
        XCTAssertNotEqual(PlatformViewState.uninitialized, PlatformViewState.resizing)
        XCTAssertNotEqual(PlatformViewState.uninitialized, PlatformViewState.ready)
        XCTAssertNotEqual(PlatformViewState.resizing, PlatformViewState.ready)
    }
}

// MARK: - PlatformViewController Protocol Tests

final class PlatformViewControllerProtocolTests: XCTestCase {

    /// Test that a stub can conform to PlatformViewController.
    func testStubConformance() {
        let controller = StubPlatformViewController(viewId: 42)
        let pc: PlatformViewController = controller
        XCTAssertEqual(pc.viewId, 42)
    }

    /// Test the default dispatchPointerEvent is a no-op on AndroidViewController.
    func testDefaultDispatchPointerEventIsNoOp() {
        let controller = AndroidViewController(viewId: 1)
        let event = PointerDownEvent(pointer: 0, position: .zero)
        // Should not crash - default implementation is a no-op.
        controller.dispatchPointerEvent(event)
    }

    /// Test custom dispatchPointerEvent implementation on stub.
    func testCustomDispatchPointerEvent() {
        let controller = StubPlatformViewController(viewId: 5)
        let event = PointerDownEvent(pointer: 1, position: Offset(10, 20))
        controller.dispatchPointerEvent(event)
        XCTAssertEqual(controller.dispatchedEvents.count, 1)
        XCTAssertEqual(controller.dispatchedEvents[0].pointer, 1)
    }
}

// MARK: - AndroidViewController Tests

final class AndroidViewControllerTests: XCTestCase {

    /// Test creation with a view ID.
    func testCreation() {
        let controller = AndroidViewController(viewId: 7)
        XCTAssertEqual(controller.viewId, 7)
    }

    /// Test that textureId is initially nil.
    func testTextureIdInitiallyNil() {
        let controller = AndroidViewController(viewId: 1)
        XCTAssertNil(controller.textureId)
    }

    /// Test that isCreated is initially false.
    func testIsCreatedInitiallyFalse() {
        let controller = AndroidViewController(viewId: 1)
        XCTAssertFalse(controller.isCreated)
    }

    /// Test that pointTransformer is initially nil.
    func testPointTransformerInitiallyNil() {
        let controller = AndroidViewController(viewId: 1)
        XCTAssertNil(controller.pointTransformer)
    }

    /// Test setting pointTransformer.
    func testPointTransformerSetter() {
        let controller = AndroidViewController(viewId: 1)
        controller.pointTransformer = { offset in
            return Offset(offset.dx * 2, offset.dy * 2)
        }
        XCTAssertNotNil(controller.pointTransformer)
        let result = controller.pointTransformer!(Offset(5, 10))
        XCTAssertEqual(result.dx, 10)
        XCTAssertEqual(result.dy, 20)
    }

    /// Test addOnPlatformViewCreatedListener does not crash.
    func testAddOnPlatformViewCreatedListener() {
        let controller = AndroidViewController(viewId: 1)
        var called = false
        controller.addOnPlatformViewCreatedListener { _ in
            called = true
        }
        // Listener is stored but not invoked yet (no platform view created).
        XCTAssertFalse(called)
    }

    /// Test removeOnPlatformViewCreatedListener does not crash.
    func testRemoveOnPlatformViewCreatedListener() {
        let controller = AndroidViewController(viewId: 1)
        controller.removeOnPlatformViewCreatedListener { _ in }
        // Should not crash (stub no-op).
    }

    /// Test setSize returns the given size.
    func testSetSize() async {
        let controller = AndroidViewController(viewId: 1)
        let result = await controller.setSize(Size(100, 200))
        XCTAssertEqual(result, Size(100, 200))
    }

    /// Test setOffset does not crash.
    func testSetOffset() async {
        let controller = AndroidViewController(viewId: 1)
        // Should not crash (stub no-op).
        await controller.setOffset(Offset(50, 60))
    }

    /// Test conforms to PlatformViewController protocol.
    func testConformsToPlatformViewController() {
        let controller = AndroidViewController(viewId: 3)
        let pc: PlatformViewController = controller
        XCTAssertEqual(pc.viewId, 3)
    }
}

// MARK: - DarwinPlatformViewController Protocol Tests

final class DarwinPlatformViewControllerTests: XCTestCase {

    /// Test UiKitViewController conforms to DarwinPlatformViewController.
    func testUiKitConformance() {
        let controller = UiKitViewController(viewId: 10)
        let darwin: DarwinPlatformViewController = controller
        XCTAssertEqual(darwin.id, 10)
    }

    /// Test AppKitViewController conforms to DarwinPlatformViewController.
    func testAppKitConformance() {
        let controller = AppKitViewController(viewId: 20)
        let darwin: DarwinPlatformViewController = controller
        XCTAssertEqual(darwin.id, 20)
    }
}

// MARK: - UiKitViewController Tests

final class UiKitViewControllerTests: XCTestCase {

    /// Test creation.
    func testCreation() {
        let controller = UiKitViewController(viewId: 42)
        XCTAssertEqual(controller.viewId, 42)
        XCTAssertEqual(controller.id, 42)
    }

    /// Test that viewId and id return the same value.
    func testViewIdEqualsId() {
        let controller = UiKitViewController(viewId: 99)
        XCTAssertEqual(controller.viewId, controller.id)
    }

    /// Test acceptGesture does not crash.
    func testAcceptGesture() {
        let controller = UiKitViewController(viewId: 1)
        controller.acceptGesture()
        // No crash means success for the stub.
    }

    /// Test rejectGesture does not crash.
    func testRejectGesture() {
        let controller = UiKitViewController(viewId: 1)
        controller.rejectGesture()
        // No crash means success for the stub.
    }
}

// MARK: - AppKitViewController Tests

final class AppKitViewControllerTests: XCTestCase {

    /// Test creation.
    func testCreation() {
        let controller = AppKitViewController(viewId: 77)
        XCTAssertEqual(controller.viewId, 77)
        XCTAssertEqual(controller.id, 77)
    }

    /// Test that viewId and id return the same value.
    func testViewIdEqualsId() {
        let controller = AppKitViewController(viewId: 55)
        XCTAssertEqual(controller.viewId, controller.id)
    }

    /// Test acceptGesture does not crash.
    func testAcceptGesture() {
        let controller = AppKitViewController(viewId: 1)
        controller.acceptGesture()
    }

    /// Test rejectGesture does not crash.
    func testRejectGesture() {
        let controller = AppKitViewController(viewId: 1)
        controller.rejectGesture()
    }
}

// MARK: - PlatformViewRenderBox Construction Tests

final class PlatformViewRenderBoxConstructionTests: XCTestCase {

    /// Test basic construction with a stub controller.
    func testBasicConstruction() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.controller === controller)
        XCTAssertEqual(renderBox.hitTestBehavior, .opaque)
    }

    /// Test construction with translucent hit test behavior.
    func testConstructionWithTranslucent() {
        let controller = StubPlatformViewController(viewId: 2)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .translucent,
            gestureRecognizers: []
        )
        XCTAssertEqual(renderBox.hitTestBehavior, .translucent)
    }

    /// Test construction with transparent hit test behavior.
    func testConstructionWithTransparent() {
        let controller = StubPlatformViewController(viewId: 3)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .transparent,
            gestureRecognizers: []
        )
        XCTAssertEqual(renderBox.hitTestBehavior, .transparent)
    }
}

// MARK: - PlatformViewRenderBox sizedByParent Tests

final class PlatformViewRenderBoxSizedByParentTests: XCTestCase {

    /// Test sizedByParent returns true.
    func testSizedByParentReturnsTrue() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.sizedByParent)
    }
}

// MARK: - PlatformViewRenderBox alwaysNeedsCompositing Tests

final class PlatformViewRenderBoxCompositingTests: XCTestCase {

    /// Test alwaysNeedsCompositing returns true.
    func testAlwaysNeedsCompositing() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.alwaysNeedsCompositing)
    }

    /// Test isRepaintBoundary returns true.
    func testIsRepaintBoundary() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.isRepaintBoundary)
    }
}

// MARK: - PlatformViewRenderBox computeDryLayout Tests

final class PlatformViewRenderBoxDryLayoutTests: XCTestCase {

    /// Test computeDryLayout returns constraints.biggest.
    func testComputeDryLayout() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        let drySize = renderBox.computeDryLayout(constraints)
        XCTAssertEqual(drySize, constraints.biggest)
    }

    /// Test computeDryLayout with tight constraints.
    func testComputeDryLayoutTight() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        let constraints = BoxConstraints.tight(Size(150, 250))
        let drySize = renderBox.computeDryLayout(constraints)
        XCTAssertEqual(drySize, Size(150, 250))
    }
}

// MARK: - PlatformViewRenderBox hitTest Tests

final class PlatformViewRenderBoxHitTestTests: XCTestCase {

    /// Test hitTest with opaque behavior returns true for position inside bounds.
    func testHitTestOpaqueInsideBounds() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let result = BoxHitTestResult()
        let hit = renderBox.hitTest(result, position: Offset(50, 50))
        XCTAssertTrue(hit, "Opaque should return true for position inside bounds")
    }

    /// Test hitTest with opaque behavior returns false for position outside bounds.
    func testHitTestOpaqueOutsideBounds() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let result = BoxHitTestResult()
        let hit = renderBox.hitTest(result, position: Offset(150, 150))
        XCTAssertFalse(hit, "Opaque should return false for position outside bounds")
    }

    /// Test hitTest with translucent behavior returns false (adds entry but doesn't absorb).
    func testHitTestTranslucentInsideBounds() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .translucent,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let result = BoxHitTestResult()
        let hit = renderBox.hitTest(result, position: Offset(50, 50))
        XCTAssertFalse(hit, "Translucent should return false (doesn't absorb hits)")
    }

    /// Test hitTest with transparent behavior returns false and doesn't add entry.
    func testHitTestTransparentInsideBounds() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .transparent,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let result = BoxHitTestResult()
        let hit = renderBox.hitTest(result, position: Offset(50, 50))
        XCTAssertFalse(hit, "Transparent should return false")
    }

    /// Test hitTestSelf with opaque returns true.
    func testHitTestSelfOpaque() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.hitTestSelf(Offset(50, 50)))
    }

    /// Test hitTestSelf with translucent returns true.
    func testHitTestSelfTranslucent() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .translucent,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.hitTestSelf(Offset(50, 50)))
    }

    /// Test hitTestSelf with transparent returns false.
    func testHitTestSelfTransparent() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .transparent,
            gestureRecognizers: []
        )
        XCTAssertFalse(renderBox.hitTestSelf(Offset(50, 50)))
    }
}

// MARK: - PlatformViewRenderBox Controller Setter Tests

final class PlatformViewRenderBoxControllerSetterTests: XCTestCase {

    /// Test setting the same controller instance is a no-op.
    func testSameControllerIsNoOp() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.needsPaint = false

        renderBox.controller = controller
        XCTAssertFalse(renderBox.needsPaint, "Same controller instance should not trigger paint")
    }

    /// Test setting a different controller triggers markNeedsPaint.
    func testDifferentControllerTriggersPaint() {
        let controller1 = StubPlatformViewController(viewId: 1)
        let controller2 = StubPlatformViewController(viewId: 2)
        let renderBox = PlatformViewRenderBox(
            controller: controller1,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.needsPaint = false

        renderBox.controller = controller2
        XCTAssertTrue(renderBox.needsPaint, "Different controller should trigger paint")
        XCTAssertTrue(renderBox.controller === controller2)
    }
}

// MARK: - PlatformViewRenderBox Dispose Tests

final class PlatformViewRenderBoxDisposeTests: XCTestCase {

    /// Test that dispose can be called without error.
    func testDispose() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        // Should not crash.
        renderBox.dispose()
    }

    /// Test that dispose on a newly created PlatformViewRenderBox works.
    func testDisposeOnNewRenderBox() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        // Should not crash even without layout.
        renderBox.dispose()
    }
}

// MARK: - PlatformViewRenderBox Paint Tests

final class PlatformViewRenderBoxPaintTests: XCTestCase {

    /// Test that paint can be invoked without crashing.
    func testPaintDoesNotCrash() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        let context = PaintingContext(ContainerLayer(), Rect.zero)
        // Should not crash; creates a PlatformViewLayer internally.
        renderBox.paint(context, .zero)
    }
}

// MARK: - RenderAndroidView Tests

final class RenderAndroidViewConstructionTests: XCTestCase {

    /// Test basic construction.
    func testBasicConstruction() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(viewController: controller)
        XCTAssertTrue(renderBox.viewController === controller)
        XCTAssertEqual(renderBox.clipBehavior, .hardEdge)
    }

    /// Test construction with custom clip behavior.
    func testConstructionWithClipBehavior() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(
            viewController: controller,
            clipBehavior: .antiAlias
        )
        XCTAssertEqual(renderBox.clipBehavior, .antiAlias)
    }

    /// Test construction with hit test behavior.
    func testConstructionWithHitTestBehavior() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(
            viewController: controller,
            hitTestBehavior: .translucent
        )
        XCTAssertEqual(renderBox.hitTestBehavior, .translucent)
    }

    /// Test viewController property getter.
    func testViewControllerGetter() {
        let controller = AndroidViewController(viewId: 5)
        let renderBox = RenderAndroidView(viewController: controller)
        XCTAssertTrue(renderBox.viewController === controller)
        XCTAssertEqual(renderBox.viewController.viewId, 5)
    }
}

// MARK: - RenderAndroidView Clip Behavior Tests

final class RenderAndroidViewClipBehaviorTests: XCTestCase {

    /// Test clipBehavior getter.
    func testClipBehaviorGetter() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(
            viewController: controller,
            clipBehavior: .antiAliasWithSaveLayer
        )
        XCTAssertEqual(renderBox.clipBehavior, .antiAliasWithSaveLayer)
    }

    /// Test clipBehavior setter triggers markNeedsPaint.
    func testClipBehaviorSetterTriggersPaint() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(viewController: controller)
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.needsPaint = false

        renderBox.clipBehavior = .antiAlias
        XCTAssertTrue(renderBox.needsPaint, "Changing clipBehavior should trigger paint")
        XCTAssertEqual(renderBox.clipBehavior, .antiAlias)
    }

    /// Test clipBehavior setter does nothing when set to the same value.
    func testClipBehaviorSetterSameValueNoOp() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(
            viewController: controller,
            clipBehavior: .hardEdge
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.needsPaint = false

        renderBox.clipBehavior = .hardEdge
        XCTAssertFalse(renderBox.needsPaint, "Same clipBehavior should not trigger paint")
    }
}

// MARK: - RenderAndroidView Layout Tests

final class RenderAndroidViewLayoutTests: XCTestCase {

    /// Test sizedByParent returns true.
    func testSizedByParent() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(viewController: controller)
        XCTAssertTrue(renderBox.sizedByParent)
    }

    /// Test computeDryLayout returns constraints.biggest.
    func testComputeDryLayout() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(viewController: controller)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        let drySize = renderBox.computeDryLayout(constraints)
        XCTAssertEqual(drySize, constraints.biggest)
    }

    /// Test performResize triggers _sizePlatformView.
    func testPerformResize() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(viewController: controller)
        renderBox.layout(BoxConstraints.tight(Size(200, 300)))
        XCTAssertEqual(renderBox.size, Size(200, 300))
    }
}

// MARK: - RenderAndroidView Paint Tests

final class RenderAndroidViewPaintTests: XCTestCase {

    /// Test paint with no texture ID does not crash.
    func testPaintNoTextureId() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(viewController: controller)
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        // textureId is nil, so paint should return early.
        renderBox.paint(context, .zero)
        // No crash means success.
    }
}

// MARK: - RenderAndroidView Dispose Tests

final class RenderAndroidViewDisposeTests: XCTestCase {

    /// Test dispose can be called.
    func testDispose() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(viewController: controller)
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.dispose()
        // No crash means success.
    }

    /// Test dispose on a fresh RenderAndroidView.
    func testDisposeOnFreshRenderBox() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(viewController: controller)
        renderBox.dispose()
    }
}

// MARK: - RenderAndroidView ViewController Setter Tests

final class RenderAndroidViewControllerSetterTests: XCTestCase {

    /// Test setting the same controller is a no-op.
    func testSameControllerIsNoOp() {
        let controller = AndroidViewController(viewId: 1)
        let renderBox = RenderAndroidView(viewController: controller)
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.needsPaint = false

        renderBox.viewController = controller
        XCTAssertFalse(renderBox.needsPaint, "Same controller should not trigger paint")
    }

    /// Test setting a different controller triggers updates.
    func testDifferentControllerTriggersUpdate() {
        let controller1 = AndroidViewController(viewId: 1)
        let controller2 = AndroidViewController(viewId: 2)
        let renderBox = RenderAndroidView(viewController: controller1)
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.needsPaint = false

        renderBox.viewController = controller2
        XCTAssertTrue(renderBox.viewController === controller2)
        // The new controller should have its pointTransformer set.
        XCTAssertNotNil(controller2.pointTransformer)
    }
}

// MARK: - RenderDarwinPlatformView Tests

final class RenderDarwinPlatformViewTests: XCTestCase {

    /// Test construction with generic parameter UiKitViewController.
    func testConstructionWithUiKitViewController() {
        let controller = UiKitViewController(viewId: 10)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.viewController === controller)
        XCTAssertEqual(renderBox.viewController.viewId, 10)
    }

    /// Test construction with generic parameter AppKitViewController.
    func testConstructionWithAppKitViewController() {
        let controller = AppKitViewController(viewId: 20)
        let renderBox = RenderDarwinPlatformView<AppKitViewController>(
            viewController: controller,
            hitTestBehavior: .translucent,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.viewController === controller)
        XCTAssertEqual(renderBox.viewController.viewId, 20)
    }

    /// Test viewController setter.
    func testViewControllerSetter() {
        let controller1 = UiKitViewController(viewId: 1)
        let controller2 = UiKitViewController(viewId: 2)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller1,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.needsPaint = false

        renderBox.viewController = controller2
        XCTAssertTrue(renderBox.viewController === controller2)
        XCTAssertTrue(renderBox.needsPaint, "Changing viewController should trigger paint")
    }

    /// Test viewController setter with same instance is a no-op.
    func testViewControllerSetterSameInstance() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.needsPaint = false

        renderBox.viewController = controller
        XCTAssertFalse(renderBox.needsPaint, "Same controller should not trigger paint")
    }

    /// Test hitTestBehavior getter and setter.
    func testHitTestBehaviorGetterSetter() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertEqual(renderBox.hitTestBehavior, .opaque)

        renderBox.hitTestBehavior = .translucent
        XCTAssertEqual(renderBox.hitTestBehavior, .translucent)

        renderBox.hitTestBehavior = .transparent
        XCTAssertEqual(renderBox.hitTestBehavior, .transparent)
    }

    /// Test sizedByParent returns true.
    func testSizedByParent() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.sizedByParent)
    }

    /// Test alwaysNeedsCompositing returns true.
    func testAlwaysNeedsCompositing() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.alwaysNeedsCompositing)
    }

    /// Test isRepaintBoundary returns true.
    func testIsRepaintBoundary() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.isRepaintBoundary)
    }

    /// Test computeDryLayout returns constraints.biggest.
    func testComputeDryLayout() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 400)
        let drySize = renderBox.computeDryLayout(constraints)
        XCTAssertEqual(drySize, constraints.biggest)
    }

    /// Test hitTest with opaque behavior.
    func testHitTestOpaque() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let result = BoxHitTestResult()
        let hit = renderBox.hitTest(result, position: Offset(50, 50))
        XCTAssertTrue(hit, "Opaque should return true inside bounds")
    }

    /// Test hitTest with translucent behavior.
    func testHitTestTranslucent() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .translucent,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let result = BoxHitTestResult()
        let hit = renderBox.hitTest(result, position: Offset(50, 50))
        XCTAssertFalse(hit, "Translucent should return false (doesn't absorb)")
    }

    /// Test hitTest with transparent behavior.
    func testHitTestTransparent() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .transparent,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let result = BoxHitTestResult()
        let hit = renderBox.hitTest(result, position: Offset(50, 50))
        XCTAssertFalse(hit, "Transparent should return false")
    }

    /// Test hitTest outside bounds returns false regardless of behavior.
    func testHitTestOutsideBounds() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let result = BoxHitTestResult()
        let hit = renderBox.hitTest(result, position: Offset(200, 200))
        XCTAssertFalse(hit, "Should return false for position outside bounds")
    }

    /// Test hitTestSelf returns true for non-transparent.
    func testHitTestSelfNonTransparent() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.hitTestSelf(Offset(50, 50)))
    }

    /// Test hitTestSelf returns false for transparent.
    func testHitTestSelfTransparent() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .transparent,
            gestureRecognizers: []
        )
        XCTAssertFalse(renderBox.hitTestSelf(Offset(50, 50)))
    }

    /// Test paint does not crash.
    func testPaintDoesNotCrash() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderDarwinPlatformView<UiKitViewController>(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))

        let context = PaintingContext(ContainerLayer(), Rect.zero)
        renderBox.paint(context, .zero)
        // No crash means success.
    }
}

// MARK: - RenderUiKitView Tests

final class RenderUiKitViewTests: XCTestCase {

    /// Test construction.
    func testConstruction() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderUiKitView(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.viewController === controller)
    }

    // NOTE: testGestureRecognizerSetup removed — handleEvent triggers
    // GestureBinding.instance which requires a running Flutter engine.

    /// Test that dispose cleans up gesture recognizer.
    func testDispose() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderUiKitView(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.dispose()
        // No crash means success.
    }

    /// Test that non-PointerDownEvent is ignored.
    func testNonPointerDownEventIgnored() {
        let controller = UiKitViewController(viewId: 1)
        let renderBox = RenderUiKitView(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        let hoverEvent = PointerHoverEvent(position: Offset(50, 50))
        let entry = BoxHitTestEntry(AnyHitTestTarget(renderBox), Offset(50, 50))
        // Should not crash - hover events are ignored.
        renderBox.handleEvent(hoverEvent, entry: entry)
    }
}

// MARK: - RenderAppKitView Tests

final class RenderAppKitViewTests: XCTestCase {

    /// Test construction.
    func testConstruction() {
        let controller = AppKitViewController(viewId: 1)
        let renderBox = RenderAppKitView(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.viewController === controller)
    }

    /// Test that sizedByParent returns true (inherited).
    func testSizedByParent() {
        let controller = AppKitViewController(viewId: 1)
        let renderBox = RenderAppKitView(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertTrue(renderBox.sizedByParent)
    }

    /// Test layout.
    func testLayout() {
        let controller = AppKitViewController(viewId: 1)
        let renderBox = RenderAppKitView(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        renderBox.layout(BoxConstraints.tight(Size(200, 300)))
        XCTAssertEqual(renderBox.size, Size(200, 300))
    }

    /// Test updateGestureRecognizers is a no-op for macOS.
    func testUpdateGestureRecognizersIsNoOp() {
        let controller = AppKitViewController(viewId: 1)
        let renderBox = RenderAppKitView(
            viewController: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        // Calling updateGestureRecognizers should not crash.
        renderBox.updateGestureRecognizers([])
    }
}

// MARK: - PlatformViewGestureRecognizer Tests

final class PlatformViewGestureRecognizerTests: XCTestCase {

    /// Test creation.
    func testCreation() {
        var events: [PointerEvent] = []
        let recognizer = PlatformViewGestureRecognizer(
            { event in events.append(event) },
            []
        )
        XCTAssertNotNil(recognizer)
        XCTAssertTrue(recognizer.cachedEvents.isEmpty)
        XCTAssertTrue(recognizer.forwardedPointers.isEmpty)
        XCTAssertTrue(events.isEmpty)
    }

    /// Test that pointer events are cached before gesture is resolved.
    func testPointerEventCaching() {
        var events: [PointerEvent] = []
        let recognizer = PlatformViewGestureRecognizer(
            { event in events.append(event) },
            []
        )

        // Simulate caching an event for pointer 1.
        let event = PointerDownEvent(pointer: 1, position: Offset(10, 20))
        recognizer.handleEvent(event)

        // The event should be cached, not forwarded.
        XCTAssertTrue(events.isEmpty, "Events should be cached, not forwarded yet")
        XCTAssertEqual(recognizer.cachedEvents[1]?.count, 1)
    }

    /// Test that accepting a gesture flushes cached events.
    func testAcceptGestureFlushesCache() {
        var events: [PointerEvent] = []
        let recognizer = PlatformViewGestureRecognizer(
            { event in events.append(event) },
            []
        )

        // Cache an event.
        let event = PointerDownEvent(pointer: 1, position: Offset(10, 20))
        recognizer.handleEvent(event)
        XCTAssertEqual(events.count, 0)

        // Accept the gesture for pointer 1.
        recognizer.acceptGesture(1)

        // Cached events should have been flushed to the handler.
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].pointer, 1)
        XCTAssertTrue(recognizer.forwardedPointers.contains(1))
    }

    /// Test that rejecting a gesture clears the cache.
    func testRejectGestureClearsCache() {
        var events: [PointerEvent] = []
        let recognizer = PlatformViewGestureRecognizer(
            { event in events.append(event) },
            []
        )

        // Cache an event.
        let event = PointerDownEvent(pointer: 2, position: Offset(10, 20))
        recognizer.handleEvent(event)
        XCTAssertEqual(recognizer.cachedEvents[2]?.count, 1)

        // Reject the gesture.
        recognizer.rejectGesture(2)

        // Cache should be cleared.
        XCTAssertNil(recognizer.cachedEvents[2])
        XCTAssertTrue(events.isEmpty, "Rejected gesture should not forward events")
    }

    /// Test that after acceptance, events are forwarded immediately.
    func testForwardingModeAfterAcceptance() {
        var events: [PointerEvent] = []
        let recognizer = PlatformViewGestureRecognizer(
            { event in events.append(event) },
            []
        )

        // Accept gesture for pointer 3.
        recognizer.acceptGesture(3)
        XCTAssertTrue(recognizer.forwardedPointers.contains(3))

        // Now handle an event for pointer 3 - should forward immediately.
        let event = PointerDownEvent(pointer: 3, position: Offset(10, 20))
        recognizer.handleEvent(event)
        XCTAssertEqual(events.count, 1, "Events for forwarded pointers should be dispatched immediately")
    }

    /// Test reset clears forwarded pointers and cached events.
    func testReset() {
        var events: [PointerEvent] = []
        let recognizer = PlatformViewGestureRecognizer(
            { event in events.append(event) },
            []
        )

        // Set up some state.
        recognizer.forwardedPointers.insert(1)
        recognizer.cachedEvents[2] = [PointerDownEvent(pointer: 2)]

        recognizer.reset()

        XCTAssertTrue(recognizer.forwardedPointers.isEmpty, "Reset should clear forwarded pointers")
        XCTAssertTrue(recognizer.cachedEvents.isEmpty, "Reset should clear cached events")
    }

    /// Test that gestureRecognizerFactories is stored.
    func testGestureRecognizerFactoriesStored() {
        let recognizer = PlatformViewGestureRecognizer(
            { _ in },
            []
        )
        XCTAssertTrue(recognizer.gestureRecognizerFactories.isEmpty)
    }
}

// MARK: - PlatformViewLayer Tests

final class PlatformViewLayerTests: XCTestCase {

    /// Test creation.
    func testCreation() {
        let layer = PlatformViewLayer(
            rect: Rect.fromLTWH(0, 0, 100, 200),
            viewId: 42
        )
        XCTAssertEqual(layer.viewId, 42)
        XCTAssertEqual(layer.rect, Rect.fromLTWH(0, 0, 100, 200))
    }

    /// Test findAnnotations returns false (leaf layer).
    func testFindAnnotationsReturnsFalse() {
        let layer = PlatformViewLayer(
            rect: Rect.fromLTWH(0, 0, 100, 200),
            viewId: 1
        )
        let result = AnnotationResult<Int>()
        let found = layer.findAnnotations(result, Offset(50, 100), onlyFirst: true)
        XCTAssertFalse(found, "PlatformViewLayer should never contain annotations")
    }
}

// MARK: - Factory Helper Functions Tests

final class FactoryTypesSetEqualsTests: XCTestCase {

    /// Test both nil returns true.
    func testBothNilReturnsTrue() {
        let result = factoryTypesSetEquals(nil, nil)
        XCTAssertTrue(result)
    }

    /// Test one nil one non-nil returns false.
    func testOneNilReturnsFalse() {
        let emptySet: Set<Factory<OneSequenceGestureRecognizer>> = []
        XCTAssertFalse(factoryTypesSetEquals(nil, emptySet))
        XCTAssertFalse(factoryTypesSetEquals(emptySet, nil))
    }

    /// Test two empty sets returns true.
    func testTwoEmptySetsReturnsTrue() {
        let a: Set<Factory<OneSequenceGestureRecognizer>> = []
        let b: Set<Factory<OneSequenceGestureRecognizer>> = []
        XCTAssertTrue(factoryTypesSetEquals(a, b))
    }

    /// Test sets with same factory types returns true.
    func testSameTypesReturnsTrue() {
        let factory1 = Factory<OneSequenceGestureRecognizer> {
            OneSequenceGestureRecognizer()
        }
        let factory2 = Factory<OneSequenceGestureRecognizer> {
            OneSequenceGestureRecognizer()
        }
        let a: Set<Factory<OneSequenceGestureRecognizer>> = [factory1]
        let b: Set<Factory<OneSequenceGestureRecognizer>> = [factory2]
        XCTAssertTrue(factoryTypesSetEquals(a, b))
    }
}

// MARK: - Factory Hashable Conformance Tests

final class FactoryHashableTests: XCTestCase {

    /// Test Factory Equatable conformance.
    func testFactoryEquatable() {
        let factory1 = Factory<OneSequenceGestureRecognizer> {
            OneSequenceGestureRecognizer()
        }
        let factory2 = Factory<OneSequenceGestureRecognizer> {
            OneSequenceGestureRecognizer()
        }
        // Same type => equal
        XCTAssertEqual(factory1, factory2)
    }

    /// Test Factory Hashable conformance allows storage in a Set.
    func testFactoryHashable() {
        let factory1 = Factory<OneSequenceGestureRecognizer> {
            OneSequenceGestureRecognizer()
        }
        let factory2 = Factory<OneSequenceGestureRecognizer> {
            OneSequenceGestureRecognizer()
        }
        // Since they have the same type, they should be deduplicated in a Set.
        let set: Set<Factory<OneSequenceGestureRecognizer>> = [factory1, factory2]
        XCTAssertEqual(set.count, 1)
    }
}

// MARK: - PlatformViewRenderBox Attach/Detach Tests

final class PlatformViewRenderBoxAttachDetachTests: XCTestCase {

    /// Test attach and detach work correctly.
    func testAttachDetach() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        let owner = PipelineOwner()

        XCTAssertFalse(renderBox.attached)

        renderBox.attach(owner)
        XCTAssertTrue(renderBox.attached)

        renderBox.detach()
        XCTAssertFalse(renderBox.attached)
    }

    /// Test repeated attach/detach cycles.
    func testRepeatedAttachDetach() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        let owner = PipelineOwner()

        renderBox.attach(owner)
        XCTAssertTrue(renderBox.attached)
        renderBox.detach()
        XCTAssertFalse(renderBox.attached)

        renderBox.attach(owner)
        XCTAssertTrue(renderBox.attached)
        renderBox.detach()
        XCTAssertFalse(renderBox.attached)
    }
}

// MARK: - PlatformViewRenderBox hitTestBehavior Setter Tests

final class PlatformViewRenderBoxHitTestBehaviorSetterTests: XCTestCase {

    /// Test hitTestBehavior setter.
    func testHitTestBehaviorSetter() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        XCTAssertEqual(renderBox.hitTestBehavior, .opaque)

        renderBox.hitTestBehavior = .translucent
        XCTAssertEqual(renderBox.hitTestBehavior, .translucent)

        renderBox.hitTestBehavior = .transparent
        XCTAssertEqual(renderBox.hitTestBehavior, .transparent)
    }

    /// Test hitTestBehavior setter triggers markNeedsPaint when attached.
    func testHitTestBehaviorSetterTriggersPaintWhenAttached() {
        let controller = StubPlatformViewController(viewId: 1)
        let renderBox = PlatformViewRenderBox(
            controller: controller,
            hitTestBehavior: .opaque,
            gestureRecognizers: []
        )
        let owner = PipelineOwner()
        renderBox.attach(owner)
        renderBox.layout(BoxConstraints.tight(Size(100, 100)))
        renderBox.needsPaint = false

        renderBox.hitTestBehavior = .translucent
        XCTAssertTrue(renderBox.needsPaint, "Changing hitTestBehavior when attached should trigger paint")

        renderBox.detach()
    }
}

// MARK: - PlatformViewRenderBox HandleEvent Tests
// NOTE: handleEvent tests require GestureBinding to be fully initialized
// (addPointer → gestureArena.add → GestureBinding.instance), which is not
// available in unit tests without a running Flutter engine. These tests are
// skipped until a test binding infrastructure is available.

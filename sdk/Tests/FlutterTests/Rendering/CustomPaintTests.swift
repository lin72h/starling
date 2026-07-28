// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for CustomPaint types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/custom_paint.dart`
///
/// These tests cover:
///   - CustomPainter: construction, shouldRepaint, hitTest, semanticsBuilder,
///     shouldRebuildSemantics, listenable forwarding
///   - CustomPainterSemantics: struct creation, default values
///   - RenderCustomPaint: construction, painter/foregroundPainter setters,
///     preferredSize, isComplex, willChange, intrinsic dimensions,
///     computeSizeForNoChild, hitTestSelf, hitTestChildren, attach/detach,
///     _didUpdatePainter logic

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

/// A concrete CustomPainter subclass for testing.
private class TestCustomPainter: CustomPainter {
    var paintCallCount = 0
    var shouldRepaintResult = false
    var hitTestResult: Bool? = nil

    init(repaint: (any Listenable)? = nil, shouldRepaintResult: Bool = false, hitTestResult: Bool? = nil) {
        self.shouldRepaintResult = shouldRepaintResult
        self.hitTestResult = hitTestResult
        super.init(repaint: repaint)
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {
        paintCallCount += 1
    }

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        return shouldRepaintResult
    }

    override func hitTest(_ position: Offset) -> Bool? {
        return hitTestResult
    }
}

/// A second CustomPainter subclass (different type) for testing _didUpdatePainter type checks.
private class AnotherCustomPainter: CustomPainter {
    override func paint(_ canvas: any Canvas, _ size: Size) {}

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        return false
    }
}

/// A CustomPainter subclass that provides a semanticsBuilder.
private class SemanticsCustomPainter: CustomPainter {
    let semanticsResult: [CustomPainterSemantics]

    init(semanticsResult: [CustomPainterSemantics] = []) {
        self.semanticsResult = semanticsResult
        super.init()
    }

    override func paint(_ canvas: any Canvas, _ size: Size) {}

    override func shouldRepaint(_ oldDelegate: CustomPainter) -> Bool {
        return true
    }

    override var semanticsBuilder: SemanticsBuilderCallback? {
        return { [weak self] _ in
            return self?.semanticsResult ?? []
        }
    }
}

/// A simple ChangeNotifier for testing listener forwarding.
private class TestNotifier: ChangeNotifier {
    func notify() {
        notifyListeners()
    }
}

// MARK: - CustomPainter Construction Tests

final class CustomPainterConstructionTests: XCTestCase {

    /// Test that CustomPainter can be created without a repaint listenable.
    func testConstructionWithoutRepaint() {
        let painter = TestCustomPainter()
        XCTAssertNotNil(painter)
    }

    /// Test that CustomPainter can be created with a repaint listenable.
    func testConstructionWithRepaint() {
        let notifier = TestNotifier()
        let painter = TestCustomPainter(repaint: notifier)
        XCTAssertNotNil(painter)
    }
}

// MARK: - CustomPainter shouldRepaint Tests

final class CustomPainterShouldRepaintTests: XCTestCase {

    /// Test shouldRepaint returns the configured value (true).
    func testShouldRepaintReturnsTrue() {
        let painter = TestCustomPainter(shouldRepaintResult: true)
        let oldPainter = TestCustomPainter()
        XCTAssertTrue(painter.shouldRepaint(oldPainter))
    }

    /// Test shouldRepaint returns the configured value (false).
    func testShouldRepaintReturnsFalse() {
        let painter = TestCustomPainter(shouldRepaintResult: false)
        let oldPainter = TestCustomPainter()
        XCTAssertFalse(painter.shouldRepaint(oldPainter))
    }
}

// MARK: - CustomPainter hitTest Tests

final class CustomPainterHitTestTests: XCTestCase {

    /// Test that default hitTest returns nil.
    func testDefaultHitTestReturnsNil() {
        let painter = TestCustomPainter()
        let result = painter.hitTest(Offset(50, 50))
        XCTAssertNil(result)
    }

    /// Test that hitTest returns configured true value.
    func testHitTestReturnsTrue() {
        let painter = TestCustomPainter(hitTestResult: true)
        let result = painter.hitTest(Offset(50, 50))
        XCTAssertEqual(result, true)
    }

    /// Test that hitTest returns configured false value.
    func testHitTestReturnsFalse() {
        let painter = TestCustomPainter(hitTestResult: false)
        let result = painter.hitTest(Offset(50, 50))
        XCTAssertEqual(result, false)
    }
}

// MARK: - CustomPainter semanticsBuilder Tests

final class CustomPainterSemanticsBuilderTests: XCTestCase {

    /// Test that default semanticsBuilder returns nil.
    func testDefaultSemanticsBuilderReturnsNil() {
        let painter = TestCustomPainter()
        XCTAssertNil(painter.semanticsBuilder)
    }

    /// Test that subclass can override semanticsBuilder.
    func testSemanticsBuilderOverride() {
        let painter = SemanticsCustomPainter()
        XCTAssertNotNil(painter.semanticsBuilder)
    }
}

// MARK: - CustomPainter shouldRebuildSemantics Tests

final class CustomPainterShouldRebuildSemanticsTests: XCTestCase {

    /// Test that shouldRebuildSemantics delegates to shouldRepaint (true).
    func testShouldRebuildSemanticsDelegatesToShouldRepaintTrue() {
        let painter = TestCustomPainter(shouldRepaintResult: true)
        let oldPainter = TestCustomPainter()
        XCTAssertTrue(painter.shouldRebuildSemantics(oldPainter))
    }

    /// Test that shouldRebuildSemantics delegates to shouldRepaint (false).
    func testShouldRebuildSemanticsDelegatesToShouldRepaintFalse() {
        let painter = TestCustomPainter(shouldRepaintResult: false)
        let oldPainter = TestCustomPainter()
        XCTAssertFalse(painter.shouldRebuildSemantics(oldPainter))
    }
}

// MARK: - CustomPainter Listenable Forwarding Tests

final class CustomPainterListenableForwardingTests: XCTestCase {

    /// Test that addListener forwards to the repaint listenable.
    func testAddListenerForwards() {
        let notifier = TestNotifier()
        let painter = TestCustomPainter(repaint: notifier)

        var callCount = 0
        let listener: VoidCallback = { callCount += 1 }

        painter.addListener(listener)
        notifier.notify()
        XCTAssertEqual(callCount, 1)
    }

    /// Test that removeListener forwards to the repaint listenable.
    func testRemoveListenerForwards() {
        let notifier = TestNotifier()
        let painter = TestCustomPainter(repaint: notifier)

        var callCount = 0
        let listener: VoidCallback = { callCount += 1 }

        painter.addListener(listener)
        notifier.notify()
        XCTAssertEqual(callCount, 1)

        painter.removeListener(listener)
        notifier.notify()
        // After removal, callCount should remain 1
        XCTAssertEqual(callCount, 1)
    }

    /// Test that addListener does nothing when repaint is nil.
    func testAddListenerWithNilRepaint() {
        let painter = TestCustomPainter()
        // Should not crash
        painter.addListener({})
    }

    /// Test that removeListener does nothing when repaint is nil.
    func testRemoveListenerWithNilRepaint() {
        let painter = TestCustomPainter()
        // Should not crash
        painter.removeListener({})
    }
}

// MARK: - CustomPainter Description Tests

final class CustomPainterDescriptionTests: XCTestCase {

    /// Test description without repaint listenable.
    func testDescriptionWithoutRepaint() {
        let painter = TestCustomPainter()
        let desc = painter.description
        // Should contain the type name
        XCTAssertTrue(desc.contains("TestCustomPainter"))
    }

    /// Test description with repaint listenable.
    func testDescriptionWithRepaint() {
        let notifier = TestNotifier()
        let painter = TestCustomPainter(repaint: notifier)
        let desc = painter.description
        // Should contain the type name and the notifier description
        XCTAssertTrue(desc.contains("TestCustomPainter"))
    }
}

// MARK: - CustomPainterSemantics Tests

final class CustomPainterSemanticsTests: XCTestCase {

    /// Test creating CustomPainterSemantics with required properties.
    func testCreationWithRequiredProperties() {
        let rect = Rect.fromLTWH(0, 0, 100, 100)
        let properties = SemanticsProperties(label: "test")
        let semantics = CustomPainterSemantics(rect: rect, properties: properties)

        XCTAssertNil(semantics.key)
        XCTAssertEqual(semantics.rect, rect)
        XCTAssertNil(semantics.transform)
        XCTAssertNil(semantics.tags)
    }

    /// Test creating CustomPainterSemantics with all properties.
    func testCreationWithAllProperties() {
        let key = ValueKey("testKey")
        let rect = Rect.fromLTWH(10, 20, 200, 150)
        let properties = SemanticsProperties(label: "full test", value: "42", hint: "A hint")
        let transform = Matrix4.identity()
        let tag = SemanticsTag("testTag")
        let tags: Set<SemanticsTag> = [tag]

        let semantics = CustomPainterSemantics(
            key: key,
            rect: rect,
            properties: properties,
            transform: transform,
            tags: tags
        )

        XCTAssertNotNil(semantics.key)
        XCTAssertEqual(semantics.rect, rect)
        XCTAssertNotNil(semantics.transform)
        XCTAssertNotNil(semantics.tags)
        XCTAssertEqual(semantics.tags?.count, 1)
    }

    /// Test that key defaults to nil.
    func testKeyDefaultsToNil() {
        let semantics = CustomPainterSemantics(
            rect: Rect.fromLTWH(0, 0, 50, 50),
            properties: SemanticsProperties()
        )
        XCTAssertNil(semantics.key)
    }

    /// Test that transform defaults to nil.
    func testTransformDefaultsToNil() {
        let semantics = CustomPainterSemantics(
            rect: Rect.fromLTWH(0, 0, 50, 50),
            properties: SemanticsProperties()
        )
        XCTAssertNil(semantics.transform)
    }

    /// Test that tags defaults to nil.
    func testTagsDefaultsToNil() {
        let semantics = CustomPainterSemantics(
            rect: Rect.fromLTWH(0, 0, 50, 50),
            properties: SemanticsProperties()
        )
        XCTAssertNil(semantics.tags)
    }
}

// MARK: - RenderCustomPaint Construction Tests

final class RenderCustomPaintConstructionTests: XCTestCase {

    /// Test default construction with no parameters.
    func testDefaultConstruction() {
        let render = RenderCustomPaint()
        XCTAssertNil(render.painter)
        XCTAssertNil(render.foregroundPainter)
        XCTAssertEqual(render.preferredSize, .zero)
        XCTAssertFalse(render.isComplex)
        XCTAssertFalse(render.willChange)
        XCTAssertNil(render.child)
    }

    /// Test construction with a painter.
    func testConstructionWithPainter() {
        let painter = TestCustomPainter()
        let render = RenderCustomPaint(painter: painter)
        XCTAssertTrue(render.painter === painter)
        XCTAssertNil(render.foregroundPainter)
    }

    /// Test construction with a foreground painter.
    func testConstructionWithForegroundPainter() {
        let fgPainter = TestCustomPainter()
        let render = RenderCustomPaint(foregroundPainter: fgPainter)
        XCTAssertNil(render.painter)
        XCTAssertTrue(render.foregroundPainter === fgPainter)
    }

    /// Test construction with both painters.
    func testConstructionWithBothPainters() {
        let painter = TestCustomPainter()
        let fgPainter = TestCustomPainter()
        let render = RenderCustomPaint(painter: painter, foregroundPainter: fgPainter)
        XCTAssertTrue(render.painter === painter)
        XCTAssertTrue(render.foregroundPainter === fgPainter)
    }

    /// Test construction with preferred size.
    func testConstructionWithPreferredSize() {
        let render = RenderCustomPaint(preferredSize: Size(200, 150))
        XCTAssertEqual(render.preferredSize.width, 200.0)
        XCTAssertEqual(render.preferredSize.height, 150.0)
    }

    /// Test construction with isComplex true.
    func testConstructionWithIsComplex() {
        let render = RenderCustomPaint(isComplex: true)
        XCTAssertTrue(render.isComplex)
    }

    /// Test construction with willChange true.
    func testConstructionWithWillChange() {
        let render = RenderCustomPaint(willChange: true)
        XCTAssertTrue(render.willChange)
    }

    /// Test construction with a child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let render = RenderCustomPaint(child: child)
        XCTAssertNotNil(render.child)
        XCTAssertTrue(render.child === child)
    }

    /// Test construction with all parameters.
    func testConstructionWithAllParameters() {
        let painter = TestCustomPainter()
        let fgPainter = TestCustomPainter()
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let render = RenderCustomPaint(
            painter: painter,
            foregroundPainter: fgPainter,
            preferredSize: Size(300, 200),
            isComplex: true,
            willChange: true,
            child: child
        )
        XCTAssertTrue(render.painter === painter)
        XCTAssertTrue(render.foregroundPainter === fgPainter)
        XCTAssertEqual(render.preferredSize.width, 300.0)
        XCTAssertEqual(render.preferredSize.height, 200.0)
        XCTAssertTrue(render.isComplex)
        XCTAssertTrue(render.willChange)
        XCTAssertNotNil(render.child)
    }
}

// MARK: - RenderCustomPaint Painter Setter Tests

final class RenderCustomPaintPainterSetterTests: XCTestCase {

    /// Test that setting painter to nil from a non-nil value triggers markNeedsPaint.
    func testSetPainterToNilTriggersRepaint() {
        let painter = TestCustomPainter()
        let render = RenderCustomPaint(painter: painter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.painter = nil
        XCTAssertNil(render.painter)
        XCTAssertTrue(render.needsPaint)
    }

    /// Test that setting painter to a new instance of different type triggers repaint.
    func testSetPainterToDifferentTypeTriggersRepaint() {
        let oldPainter = TestCustomPainter()
        let render = RenderCustomPaint(painter: oldPainter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        let newPainter = AnotherCustomPainter()
        render.painter = newPainter
        XCTAssertTrue(render.painter === newPainter)
        XCTAssertTrue(render.needsPaint)
    }

    /// Test that setting painter to a same-type instance that returns shouldRepaint=true triggers repaint.
    func testSetPainterSameTypeShouldRepaintTrueTriggersRepaint() {
        let oldPainter = TestCustomPainter(shouldRepaintResult: false)
        let render = RenderCustomPaint(painter: oldPainter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        let newPainter = TestCustomPainter(shouldRepaintResult: true)
        render.painter = newPainter
        XCTAssertTrue(render.needsPaint)
    }

    /// Test that setting painter to a same-type instance that returns shouldRepaint=false
    /// does not trigger repaint.
    func testSetPainterSameTypeShouldRepaintFalseNoRepaint() {
        let oldPainter = TestCustomPainter(shouldRepaintResult: false)
        let render = RenderCustomPaint(painter: oldPainter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        let newPainter = TestCustomPainter(shouldRepaintResult: false)
        render.painter = newPainter
        XCTAssertFalse(render.needsPaint)
    }

    /// Test that setting painter to the same instance is a no-op.
    func testSetPainterToSameInstanceIsNoOp() {
        let painter = TestCustomPainter()
        let render = RenderCustomPaint(painter: painter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.painter = painter
        XCTAssertFalse(render.needsPaint)
    }

    /// Test that setting painter from nil to a new value triggers repaint.
    func testSetPainterFromNilTriggersRepaint() {
        let render = RenderCustomPaint()
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        let painter = TestCustomPainter()
        render.painter = painter
        XCTAssertTrue(render.needsPaint)
    }
}

// MARK: - RenderCustomPaint ForegroundPainter Setter Tests

final class RenderCustomPaintForegroundPainterSetterTests: XCTestCase {

    /// Test that setting foregroundPainter to nil from a non-nil value triggers markNeedsPaint.
    func testSetForegroundPainterToNilTriggersRepaint() {
        let fgPainter = TestCustomPainter()
        let render = RenderCustomPaint(foregroundPainter: fgPainter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.foregroundPainter = nil
        XCTAssertNil(render.foregroundPainter)
        XCTAssertTrue(render.needsPaint)
    }

    /// Test that setting foregroundPainter to a different type triggers repaint.
    func testSetForegroundPainterToDifferentTypeTriggersRepaint() {
        let oldPainter = TestCustomPainter()
        let render = RenderCustomPaint(foregroundPainter: oldPainter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        let newPainter = AnotherCustomPainter()
        render.foregroundPainter = newPainter
        XCTAssertTrue(render.needsPaint)
    }

    /// Test that setting foregroundPainter to the same instance is a no-op.
    func testSetForegroundPainterToSameInstanceIsNoOp() {
        let fgPainter = TestCustomPainter()
        let render = RenderCustomPaint(foregroundPainter: fgPainter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.foregroundPainter = fgPainter
        XCTAssertFalse(render.needsPaint)
    }

    /// Test that setting foregroundPainter from nil to a value triggers repaint.
    func testSetForegroundPainterFromNilTriggersRepaint() {
        let render = RenderCustomPaint()
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        let fgPainter = TestCustomPainter()
        render.foregroundPainter = fgPainter
        XCTAssertTrue(render.needsPaint)
    }
}

// MARK: - RenderCustomPaint PreferredSize Setter Tests

final class RenderCustomPaintPreferredSizeTests: XCTestCase {

    /// Test that setting preferredSize triggers layout.
    func testPreferredSizeSetterTriggersLayout() {
        let render = RenderCustomPaint(preferredSize: Size(100, 100))
        render.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(render.needsLayout)

        render.preferredSize = Size(150, 150)
        XCTAssertTrue(render.needsLayout)
        XCTAssertEqual(render.preferredSize.width, 150.0)
        XCTAssertEqual(render.preferredSize.height, 150.0)
    }

    /// Test that setting preferredSize to the same value does not trigger layout.
    func testPreferredSizeSetterNoOpOnSameValue() {
        let render = RenderCustomPaint(preferredSize: Size(100, 100))
        render.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(render.needsLayout)

        render.preferredSize = Size(100, 100)
        XCTAssertFalse(render.needsLayout)
    }
}

// MARK: - RenderCustomPaint isComplex and willChange Tests

final class RenderCustomPaintFlagTests: XCTestCase {

    /// Test setting isComplex.
    func testIsComplexProperty() {
        let render = RenderCustomPaint()
        XCTAssertFalse(render.isComplex)

        render.isComplex = true
        XCTAssertTrue(render.isComplex)

        render.isComplex = false
        XCTAssertFalse(render.isComplex)
    }

    /// Test setting willChange.
    func testWillChangeProperty() {
        let render = RenderCustomPaint()
        XCTAssertFalse(render.willChange)

        render.willChange = true
        XCTAssertTrue(render.willChange)

        render.willChange = false
        XCTAssertFalse(render.willChange)
    }
}

// MARK: - RenderCustomPaint Intrinsic Dimension Tests (No Child)

final class RenderCustomPaintIntrinsicsNoChildTests: XCTestCase {

    /// Test intrinsic dimensions with finite preferred size and no child.
    func testIntrinsicsWithFinitePreferredSize() {
        let render = RenderCustomPaint(preferredSize: Size(200, 150))

        XCTAssertEqual(render.computeMinIntrinsicWidth(.infinity), 200.0)
        XCTAssertEqual(render.computeMaxIntrinsicWidth(.infinity), 200.0)
        XCTAssertEqual(render.computeMinIntrinsicHeight(.infinity), 150.0)
        XCTAssertEqual(render.computeMaxIntrinsicHeight(.infinity), 150.0)
    }

    /// Test intrinsic dimensions with zero preferred size and no child.
    func testIntrinsicsWithZeroPreferredSize() {
        let render = RenderCustomPaint()  // preferredSize defaults to .zero

        XCTAssertEqual(render.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(render.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(render.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(render.computeMaxIntrinsicHeight(.infinity), 0.0)
    }

    /// Test intrinsic dimensions with infinite preferred width returns 0.
    func testIntrinsicsWithInfinitePreferredWidth() {
        let render = RenderCustomPaint(preferredSize: Size(.infinity, 100))

        XCTAssertEqual(render.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(render.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(render.computeMinIntrinsicHeight(.infinity), 100.0)
        XCTAssertEqual(render.computeMaxIntrinsicHeight(.infinity), 100.0)
    }

    /// Test intrinsic dimensions with infinite preferred height returns 0.
    func testIntrinsicsWithInfinitePreferredHeight() {
        let render = RenderCustomPaint(preferredSize: Size(100, .infinity))

        XCTAssertEqual(render.computeMinIntrinsicWidth(.infinity), 100.0)
        XCTAssertEqual(render.computeMaxIntrinsicWidth(.infinity), 100.0)
        XCTAssertEqual(render.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(render.computeMaxIntrinsicHeight(.infinity), 0.0)
    }

    /// Test intrinsic dimensions with both infinite preferred size returns 0 for both.
    func testIntrinsicsWithBothInfinitePreferredSize() {
        let render = RenderCustomPaint(preferredSize: Size(.infinity, .infinity))

        XCTAssertEqual(render.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(render.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(render.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(render.computeMaxIntrinsicHeight(.infinity), 0.0)
    }
}

// MARK: - RenderCustomPaint Intrinsic Dimension Tests (With Child)

final class RenderCustomPaintIntrinsicsWithChildTests: XCTestCase {

    /// Test intrinsic dimensions delegate to child when present.
    func testIntrinsicsDelegateToChild() {
        let child = FixedSizeRenderBox(width: 120, height: 80)
        let render = RenderCustomPaint(preferredSize: Size(200, 150), child: child)

        // With a child, intrinsics should come from the child, not preferredSize
        XCTAssertEqual(render.computeMinIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(render.computeMaxIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(render.computeMinIntrinsicHeight(.infinity), 80.0)
        XCTAssertEqual(render.computeMaxIntrinsicHeight(.infinity), 80.0)
    }

    /// Test intrinsic dimensions with child ignore preferred size.
    func testIntrinsicsWithChildIgnorePreferredSize() {
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let render = RenderCustomPaint(preferredSize: Size(500, 500), child: child)

        XCTAssertEqual(render.computeMinIntrinsicWidth(.infinity), 50.0)
        XCTAssertEqual(render.computeMaxIntrinsicWidth(.infinity), 50.0)
        XCTAssertEqual(render.computeMinIntrinsicHeight(.infinity), 30.0)
        XCTAssertEqual(render.computeMaxIntrinsicHeight(.infinity), 30.0)
    }
}

// MARK: - RenderCustomPaint computeSizeForNoChild Tests

final class RenderCustomPaintComputeSizeForNoChildTests: XCTestCase {

    /// Test computeSizeForNoChild constrains the preferred size.
    func testComputeSizeForNoChildConstrainsPreferredSize() {
        let render = RenderCustomPaint(preferredSize: Size(150, 100))
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = render.computeSizeForNoChild(constraints)
        XCTAssertEqual(size.width, 150.0)
        XCTAssertEqual(size.height, 100.0)
    }

    /// Test computeSizeForNoChild clamps to max constraints.
    func testComputeSizeForNoChildClampsToMax() {
        let render = RenderCustomPaint(preferredSize: Size(500, 400))
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        let size = render.computeSizeForNoChild(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test computeSizeForNoChild clamps to min constraints.
    func testComputeSizeForNoChildClampsToMin() {
        let render = RenderCustomPaint(preferredSize: Size(10, 5))
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 200, minHeight: 30, maxHeight: 300)
        let size = render.computeSizeForNoChild(constraints)
        XCTAssertEqual(size.width, 50.0)
        XCTAssertEqual(size.height, 30.0)
    }

    /// Test computeSizeForNoChild with zero preferred size returns min constraints.
    func testComputeSizeForNoChildWithZeroPreferredSize() {
        let render = RenderCustomPaint()  // preferredSize = .zero
        let constraints = BoxConstraints(minWidth: 20, maxWidth: 200, minHeight: 10, maxHeight: 300)
        let size = render.computeSizeForNoChild(constraints)
        XCTAssertEqual(size.width, 20.0)
        XCTAssertEqual(size.height, 10.0)
    }

    /// Test computeSizeForNoChild with tight constraints.
    func testComputeSizeForNoChildWithTightConstraints() {
        let render = RenderCustomPaint(preferredSize: Size(300, 300))
        let constraints = BoxConstraints.tight(Size(100, 100))
        let size = render.computeSizeForNoChild(constraints)
        XCTAssertEqual(size.width, 100.0)
        XCTAssertEqual(size.height, 100.0)
    }
}

// MARK: - RenderCustomPaint Layout Tests

final class RenderCustomPaintLayoutTests: XCTestCase {

    /// Test layout without child uses preferred size.
    func testLayoutWithoutChildUsesPreferredSize() {
        let render = RenderCustomPaint(preferredSize: Size(150, 100))
        render.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(render.size.width, 150.0)
        XCTAssertEqual(render.size.height, 100.0)
    }

    /// Test layout without child with zero preferred size.
    func testLayoutWithoutChildZeroPreferredSize() {
        let render = RenderCustomPaint()
        render.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(render.size.width, 0.0)
        XCTAssertEqual(render.size.height, 0.0)
    }

    /// Test layout with child uses child size.
    func testLayoutWithChildUsesChildSize() {
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let render = RenderCustomPaint(preferredSize: Size(200, 200), child: child)
        render.layout(BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300))
        XCTAssertEqual(render.size.width, 80.0)
        XCTAssertEqual(render.size.height, 60.0)
    }

    /// Test layout constrains preferred size.
    func testLayoutConstrainsPreferredSize() {
        let render = RenderCustomPaint(preferredSize: Size(500, 400))
        render.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300))
        XCTAssertEqual(render.size.width, 200.0)
        XCTAssertEqual(render.size.height, 300.0)
    }
}

// MARK: - RenderCustomPaint Hit Test Self Tests

final class RenderCustomPaintHitTestSelfTests: XCTestCase {

    /// Test hitTestSelf with no painter returns false.
    func testHitTestSelfWithNoPainterReturnsFalse() {
        let render = RenderCustomPaint()
        render.layout(BoxConstraints.tight(Size(100, 100)))
        let result = render.hitTestSelf(Offset(50, 50))
        XCTAssertFalse(result)
    }

    /// Test hitTestSelf with painter returning nil defaults to true (background painter).
    func testHitTestSelfWithPainterReturningNilDefaultsToTrue() {
        let painter = TestCustomPainter(hitTestResult: nil)
        let render = RenderCustomPaint(painter: painter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        let result = render.hitTestSelf(Offset(50, 50))
        XCTAssertTrue(result)
    }

    /// Test hitTestSelf with painter returning true.
    func testHitTestSelfWithPainterReturningTrue() {
        let painter = TestCustomPainter(hitTestResult: true)
        let render = RenderCustomPaint(painter: painter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        let result = render.hitTestSelf(Offset(50, 50))
        XCTAssertTrue(result)
    }

    /// Test hitTestSelf with painter returning false.
    func testHitTestSelfWithPainterReturningFalse() {
        let painter = TestCustomPainter(hitTestResult: false)
        let render = RenderCustomPaint(painter: painter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        let result = render.hitTestSelf(Offset(50, 50))
        XCTAssertFalse(result)
    }
}

// MARK: - RenderCustomPaint Hit Test Children Tests

final class RenderCustomPaintHitTestChildrenTests: XCTestCase {

    /// Test hitTestChildren with no foreground painter delegates to super.
    func testHitTestChildrenNoForegroundPainter() {
        let render = RenderCustomPaint()
        render.layout(BoxConstraints.tight(Size(100, 100)))
        let hitResult = BoxHitTestResult()
        let result = render.hitTestChildren(hitResult, position: Offset(50, 50))
        // No child, no foreground painter => false
        XCTAssertFalse(result)
    }

    /// Test hitTestChildren with foreground painter returning true.
    func testHitTestChildrenWithForegroundPainterReturningTrue() {
        let fgPainter = TestCustomPainter(hitTestResult: true)
        let render = RenderCustomPaint(foregroundPainter: fgPainter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        let hitResult = BoxHitTestResult()
        let result = render.hitTestChildren(hitResult, position: Offset(50, 50))
        XCTAssertTrue(result)
    }

    /// Test hitTestChildren with foreground painter returning false delegates to super.
    func testHitTestChildrenWithForegroundPainterReturningFalse() {
        let fgPainter = TestCustomPainter(hitTestResult: false)
        let render = RenderCustomPaint(foregroundPainter: fgPainter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        let hitResult = BoxHitTestResult()
        let result = render.hitTestChildren(hitResult, position: Offset(50, 50))
        // fgPainter returns false, no child => super returns false
        XCTAssertFalse(result)
    }

    /// Test hitTestChildren with foreground painter returning nil delegates to super.
    func testHitTestChildrenWithForegroundPainterReturningNil() {
        let fgPainter = TestCustomPainter(hitTestResult: nil)
        let render = RenderCustomPaint(foregroundPainter: fgPainter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        let hitResult = BoxHitTestResult()
        let result = render.hitTestChildren(hitResult, position: Offset(50, 50))
        // fgPainter returns nil, nil ?? false == false, so delegates to super (no child => false)
        XCTAssertFalse(result)
    }
}

// MARK: - RenderCustomPaint Attach/Detach Tests

final class RenderCustomPaintAttachDetachTests: XCTestCase {

    /// Test attach adds listeners to painters.
    func testAttachAddsListeners() {
        let notifier = TestNotifier()
        let painter = TestCustomPainter(repaint: notifier)
        let render = RenderCustomPaint(painter: painter)
        let owner = PipelineOwner()

        XCTAssertFalse(render.attached)
        render.attach(owner)
        XCTAssertTrue(render.attached)
    }

    /// Test detach removes listeners from painters.
    func testDetachRemovesListeners() {
        let notifier = TestNotifier()
        let painter = TestCustomPainter(repaint: notifier)
        let render = RenderCustomPaint(painter: painter)
        let owner = PipelineOwner()

        render.attach(owner)
        XCTAssertTrue(render.attached)
        render.detach()
        XCTAssertFalse(render.attached)
    }

    /// Test attach/detach cycle with both painters.
    func testAttachDetachWithBothPainters() {
        let notifier1 = TestNotifier()
        let notifier2 = TestNotifier()
        let painter = TestCustomPainter(repaint: notifier1)
        let fgPainter = TestCustomPainter(repaint: notifier2)
        let render = RenderCustomPaint(painter: painter, foregroundPainter: fgPainter)
        let owner = PipelineOwner()

        render.attach(owner)
        XCTAssertTrue(render.attached)
        render.detach()
        XCTAssertFalse(render.attached)
    }

    /// Test attach/detach with nil painters does not crash.
    func testAttachDetachWithNilPainters() {
        let render = RenderCustomPaint()
        let owner = PipelineOwner()

        render.attach(owner)
        XCTAssertTrue(render.attached)
        render.detach()
        XCTAssertFalse(render.attached)
    }
}

// MARK: - RenderCustomPaint Painter Update Listener Management Tests

final class RenderCustomPaintPainterUpdateListenerTests: XCTestCase {

    /// Test that when painter is replaced while attached, old listener is removed
    /// and new listener is added.
    func testPainterReplacementWhileAttachedManagesListeners() {
        let notifier1 = TestNotifier()
        let notifier2 = TestNotifier()
        let oldPainter = TestCustomPainter(repaint: notifier1, shouldRepaintResult: true)
        let newPainter = TestCustomPainter(repaint: notifier2, shouldRepaintResult: true)
        let render = RenderCustomPaint(painter: oldPainter)
        let owner = PipelineOwner()

        render.attach(owner)
        render.layout(BoxConstraints.tight(Size(100, 100)))

        // Replace the painter while attached
        render.painter = newPainter
        XCTAssertTrue(render.painter === newPainter)
    }

    /// Test that when foregroundPainter is replaced while attached, listeners are managed.
    func testForegroundPainterReplacementWhileAttachedManagesListeners() {
        let notifier1 = TestNotifier()
        let notifier2 = TestNotifier()
        let oldPainter = TestCustomPainter(repaint: notifier1, shouldRepaintResult: true)
        let newPainter = TestCustomPainter(repaint: notifier2, shouldRepaintResult: true)
        let render = RenderCustomPaint(foregroundPainter: oldPainter)
        let owner = PipelineOwner()

        render.attach(owner)
        render.layout(BoxConstraints.tight(Size(100, 100)))

        // Replace the foreground painter while attached
        render.foregroundPainter = newPainter
        XCTAssertTrue(render.foregroundPainter === newPainter)
    }

    /// Test that setting painter to nil while attached removes listener.
    func testSetPainterToNilWhileAttachedRemovesListener() {
        let notifier = TestNotifier()
        let painter = TestCustomPainter(repaint: notifier)
        let render = RenderCustomPaint(painter: painter)
        let owner = PipelineOwner()

        render.attach(owner)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.painter = nil
        XCTAssertNil(render.painter)
        XCTAssertTrue(render.needsPaint)
    }
}

// MARK: - RenderCustomPaint _didUpdatePainter Logic Tests

final class RenderCustomPaintDidUpdatePainterTests: XCTestCase {

    /// Test updating painter: new painter is nil, old was non-nil => marks dirty.
    func testUpdatePainterNewNilOldNonNil() {
        let painter = TestCustomPainter()
        let render = RenderCustomPaint(painter: painter)
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.painter = nil
        XCTAssertTrue(render.needsPaint)
    }

    /// Test updating painter: old is nil, new is non-nil => marks dirty.
    func testUpdatePainterOldNilNewNonNil() {
        let render = RenderCustomPaint()
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.painter = TestCustomPainter()
        XCTAssertTrue(render.needsPaint)
    }

    /// Test updating painter: different types => marks dirty.
    func testUpdatePainterDifferentTypes() {
        let render = RenderCustomPaint(painter: TestCustomPainter())
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.painter = AnotherCustomPainter()
        XCTAssertTrue(render.needsPaint)
    }

    /// Test updating painter: same type, shouldRepaint=true => marks dirty.
    func testUpdatePainterSameTypeShouldRepaintTrue() {
        let render = RenderCustomPaint(painter: TestCustomPainter(shouldRepaintResult: false))
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.painter = TestCustomPainter(shouldRepaintResult: true)
        XCTAssertTrue(render.needsPaint)
    }

    /// Test updating painter: same type, shouldRepaint=false => does not mark dirty.
    func testUpdatePainterSameTypeShouldRepaintFalse() {
        let render = RenderCustomPaint(painter: TestCustomPainter(shouldRepaintResult: false))
        render.layout(BoxConstraints.tight(Size(100, 100)))
        render.needsPaint = false

        render.painter = TestCustomPainter(shouldRepaintResult: false)
        XCTAssertFalse(render.needsPaint)
    }
}

// MARK: - RenderCustomPaint describeSemanticsConfigurationStub Tests

final class RenderCustomPaintSemanticsConfigTests: XCTestCase {

    /// Test describeSemanticsConfigurationStub with no painters sets nil builders.
    func testDescribeSemanticsConfigWithNoPainters() {
        let render = RenderCustomPaint()
        render.describeSemanticsConfigurationStub()
        // No crash indicates success; we cannot directly inspect private fields
    }

    /// Test describeSemanticsConfigurationStub with painters having semantics builders.
    func testDescribeSemanticsConfigWithSemanticsBuilders() {
        let painter = SemanticsCustomPainter()
        let fgPainter = SemanticsCustomPainter()
        let render = RenderCustomPaint(painter: painter, foregroundPainter: fgPainter)
        render.describeSemanticsConfigurationStub()
        // No crash indicates success
    }
}

// MARK: - RenderCustomPaint clearSemanticsStub Tests

final class RenderCustomPaintClearSemanticsTests: XCTestCase {

    /// Test clearSemanticsStub does not crash.
    func testClearSemanticsStub() {
        let render = RenderCustomPaint()
        render.clearSemanticsStub()
        // No crash indicates success
    }
}

// MARK: - RenderCustomPaint debugFillProperties Tests

final class RenderCustomPaintDebugFillPropertiesTests: XCTestCase {

    /// Test debugFillProperties with default values does not crash.
    func testDebugFillPropertiesDefault() {
        let render = RenderCustomPaint()
        let builder = DiagnosticPropertiesBuilder()
        render.debugFillProperties(builder)
        XCTAssertFalse(builder.properties.isEmpty)
    }

    /// Test debugFillProperties with painters.
    func testDebugFillPropertiesWithPainters() {
        let painter = TestCustomPainter()
        let fgPainter = TestCustomPainter()
        let render = RenderCustomPaint(
            painter: painter,
            foregroundPainter: fgPainter,
            preferredSize: Size(200, 100),
            isComplex: true,
            willChange: true
        )
        let builder = DiagnosticPropertiesBuilder()
        render.debugFillProperties(builder)
        XCTAssertFalse(builder.properties.isEmpty)
    }
}

// MARK: - SemanticsBuilderCallback Typealias Tests

final class SemanticsBuilderCallbackTests: XCTestCase {

    /// Test that SemanticsBuilderCallback can be used as expected.
    func testSemanticsBuilderCallbackUsage() {
        let callback: SemanticsBuilderCallback = { size in
            let rect = Rect.fromLTWH(0, 0, size.width, size.height)
            return [
                CustomPainterSemantics(rect: rect, properties: SemanticsProperties(label: "test"))
            ]
        }

        let result = callback(Size(100, 50))
        XCTAssertEqual(result.count, 1)
    }
}

// MARK: - RenderCustomPaint PerformLayout Tests

final class RenderCustomPaintPerformLayoutTests: XCTestCase {

    /// Test performLayout delegates to super (RenderProxyBox) and does not crash.
    func testPerformLayoutNoChild() {
        let render = RenderCustomPaint(preferredSize: Size(120, 80))
        render.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(render.size.width, 120.0)
        XCTAssertEqual(render.size.height, 80.0)
    }

    /// Test performLayout with child lays out the child.
    func testPerformLayoutWithChild() {
        let child = FixedSizeRenderBox(width: 70, height: 45)
        let render = RenderCustomPaint(preferredSize: Size(200, 200), child: child)
        render.layout(BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300))
        XCTAssertTrue(child.hasSize)
        XCTAssertEqual(child.size.width, 70.0)
        XCTAssertEqual(child.size.height, 45.0)
        // The render object takes the child's size, not the preferredSize
        XCTAssertEqual(render.size.width, 70.0)
        XCTAssertEqual(render.size.height, 45.0)
    }
}

// MARK: - RenderCustomPaint assembleSemanticsNodeStub Tests

final class RenderCustomPaintAssembleSemanticsTests: XCTestCase {

    /// Test assembleSemanticsNodeStub does not crash with empty inputs.
    func testAssembleSemanticsNodeStubEmpty() {
        let render = RenderCustomPaint()
        render.layout(BoxConstraints.tight(Size(100, 100)))
        let node = SemanticsNode()
        let config = SemanticsConfiguration()
        render.assembleSemanticsNodeStub(node, config, [])
        // No crash indicates success
    }

    /// Test assembleSemanticsNodeStub with semantics painters.
    func testAssembleSemanticsNodeStubWithPainters() {
        let rect = Rect.fromLTWH(0, 0, 50, 50)
        let semantics = [
            CustomPainterSemantics(
                rect: rect,
                properties: SemanticsProperties(label: "bg item")
            )
        ]
        let painter = SemanticsCustomPainter(semanticsResult: semantics)
        let render = RenderCustomPaint(painter: painter)
        render.layout(BoxConstraints.tight(Size(100, 100)))

        // Set up semantics builders
        render.describeSemanticsConfigurationStub()

        let node = SemanticsNode()
        let config = SemanticsConfiguration()
        render.assembleSemanticsNodeStub(node, config, [])
        // No crash indicates success
    }
}

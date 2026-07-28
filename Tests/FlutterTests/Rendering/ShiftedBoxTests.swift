// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for ShiftedBox types from the Rendering layer.
///
/// **Dart Source:** `packages/flutter/lib/src/rendering/shifted_box.dart`
///
/// These tests cover:
///   - RenderPadding: construction, properties, intrinsics, layout
///   - RenderPositionedBox: construction, properties, factors, layout
///   - RenderConstrainedOverflowBox: construction, properties, fit modes
///   - RenderSizedOverflowBox: construction, requestedSize, intrinsics
///   - RenderFractionallySizedOverflowBox: construction, factors, properties
///   - RenderConstraintsTransformBox: construction, transform, clip behavior
///   - SingleChildLayoutDelegate: default behavior, subclass overrides
///   - RenderCustomSingleChildLayoutBox: construction, delegate, layout
///   - RenderBaseline: construction, properties

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

/// A concrete SingleChildLayoutDelegate subclass for testing.
private class TestSingleChildLayoutDelegate: SingleChildLayoutDelegate {
    let fixedSize: Size?
    let fixedConstraints: BoxConstraints?
    let fixedPosition: Offset?
    let relayoutResult: Bool

    init(
        fixedSize: Size? = nil,
        fixedConstraints: BoxConstraints? = nil,
        fixedPosition: Offset? = nil,
        relayoutResult: Bool = true,
        relayout: (any Listenable)? = nil
    ) {
        self.fixedSize = fixedSize
        self.fixedConstraints = fixedConstraints
        self.fixedPosition = fixedPosition
        self.relayoutResult = relayoutResult
        super.init(relayout: relayout)
    }

    override func getSize(_ constraints: BoxConstraints) -> Size {
        if let fixedSize = fixedSize {
            return fixedSize
        }
        return super.getSize(constraints)
    }

    override func getConstraintsForChild(_ constraints: BoxConstraints) -> BoxConstraints {
        if let fixedConstraints = fixedConstraints {
            return fixedConstraints
        }
        return super.getConstraintsForChild(constraints)
    }

    override func getPositionForChild(_ size: Size, _ childSize: Size) -> Offset {
        if let fixedPosition = fixedPosition {
            return fixedPosition
        }
        return super.getPositionForChild(size, childSize)
    }

    override func shouldRelayout(_ oldDelegate: SingleChildLayoutDelegate) -> Bool {
        return relayoutResult
    }
}

// MARK: - RenderShiftedBox Tests

final class RenderShiftedBoxTests: XCTestCase {

    /// Test that RenderShiftedBox can be constructed without a child.
    func testConstructionWithoutChild() {
        let box = RenderShiftedBox()
        XCTAssertNil(box.child)
    }

    /// Test that RenderShiftedBox can be constructed with a child.
    func testConstructionWithChild() {
        let child = RenderBox()
        let box = RenderShiftedBox(child: child)
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
    }

    /// Test that child can be replaced.
    func testReplacingChild() {
        let child1 = FixedSizeRenderBox(width: 50, height: 50)
        let child2 = FixedSizeRenderBox(width: 80, height: 80)
        let box = RenderShiftedBox(child: child1)
        XCTAssertTrue(box.child === child1)

        box.child = child2
        XCTAssertTrue(box.child === child2)
    }

    /// Test that child can be set to nil.
    func testSettingChildToNil() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = RenderShiftedBox(child: child)
        XCTAssertNotNil(box.child)

        box.child = nil
        XCTAssertNil(box.child)
    }

    /// Test that setupParentData creates BoxParentData.
    func testSetupParentData() {
        let box = RenderShiftedBox()
        let child = RenderBox()
        box.setupParentData(child)
        XCTAssertTrue(child.parentData is BoxParentData)
    }

    /// Test intrinsic dimensions delegate to child.
    func testIntrinsicDimensionsDelegateToChild() {
        let child = FixedSizeRenderBox(width: 120, height: 80)
        let box = RenderShiftedBox(child: child)
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 80.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 80.0)
    }

    /// Test intrinsic dimensions return 0 without child.
    func testIntrinsicDimensionsWithoutChild() {
        let box = RenderShiftedBox()
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 0.0)
    }
}

// MARK: - RenderPadding Construction Tests

final class RenderPaddingConstructionTests: XCTestCase {

    /// Test that RenderPadding can be constructed with EdgeInsets padding.
    func testConstructionWithEdgeInsets() {
        let padding = EdgeInsets(all: 10.0)
        let box = RenderPadding(padding: padding)
        XCTAssertNil(box.child)
        XCTAssertNil(box.textDirection)
    }

    /// Test that RenderPadding can be constructed with a child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let padding = EdgeInsets(left: 5, top: 10, right: 15, bottom: 20)
        let box = RenderPadding(padding: padding, child: child)
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
    }

    /// Test that RenderPadding can be constructed with a textDirection.
    func testConstructionWithTextDirection() {
        let padding = EdgeInsets(all: 10.0)
        let box = RenderPadding(padding: padding, textDirection: .ltr)
        XCTAssertEqual(box.textDirection, .ltr)
    }
}

// MARK: - RenderPadding Property Tests

final class RenderPaddingPropertyTests: XCTestCase {

    /// Test that setting padding to a new value triggers layout.
    func testPaddingSetterTriggersLayout() {
        let box = RenderPadding(padding: EdgeInsets(all: 10.0))
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)

        box.padding = EdgeInsets(all: 20.0)
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting padding to the same value does not trigger layout.
    func testPaddingSetterNoOpOnSameValue() {
        let box = RenderPadding(padding: EdgeInsets(all: 10.0))
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)

        box.padding = EdgeInsets(all: 10.0)
        XCTAssertFalse(box.needsLayout)
    }

    /// Test that setting textDirection triggers layout.
    func testTextDirectionSetterTriggersLayout() {
        let box = RenderPadding(padding: EdgeInsets(all: 10.0), textDirection: .ltr)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)

        box.textDirection = .rtl
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting textDirection to the same value does not trigger layout.
    func testTextDirectionSetterNoOpOnSameValue() {
        let box = RenderPadding(padding: EdgeInsets(all: 10.0), textDirection: .ltr)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)

        box.textDirection = .ltr
        XCTAssertFalse(box.needsLayout)
    }
}

// MARK: - RenderPadding Intrinsic Dimension Tests

final class RenderPaddingIntrinsicTests: XCTestCase {

    /// Test that intrinsic dimensions add padding to child dimensions.
    func testIntrinsicDimensionsWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let box = RenderPadding(padding: padding, child: child)

        // horizontal = 10 + 30 = 40, vertical = 20 + 40 = 60
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 140.0)  // 100 + 40
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 140.0)  // 100 + 40
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 110.0) // 50 + 60
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 110.0) // 50 + 60
    }

    /// Test intrinsic dimensions with no child return just padding.
    func testIntrinsicDimensionsWithoutChild() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let box = RenderPadding(padding: padding)

        // horizontal = 40, vertical = 60
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 40.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 40.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 60.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 60.0)
    }

    /// Test intrinsic dimensions with symmetric padding.
    func testIntrinsicDimensionsSymmetricPadding() {
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let padding = EdgeInsets(horizontal: 15, vertical: 25)
        let box = RenderPadding(padding: padding, child: child)

        // horizontal = 15 + 15 = 30, vertical = 25 + 25 = 50
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 110.0)  // 80 + 30
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 110.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 110.0) // 60 + 50
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 110.0)
    }
}

// MARK: - RenderPadding Layout Tests

final class RenderPaddingLayoutTests: XCTestCase {

    /// Test layout without a child sizes to padding only.
    func testLayoutWithoutChild() {
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let box = RenderPadding(padding: padding)

        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        // Size should be constrained padding: (40, 60)
        XCTAssertEqual(box.size.width, 40.0)
        XCTAssertEqual(box.size.height, 60.0)
    }

    /// Test layout with a child includes child size plus padding.
    func testLayoutWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let box = RenderPadding(padding: padding, child: child)

        box.layout(BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300))
        // Size = (10+100+30, 20+50+40) = (140, 110)
        XCTAssertEqual(box.size.width, 140.0)
        XCTAssertEqual(box.size.height, 110.0)
    }

    /// Test layout respects constraints.
    func testLayoutRespectsConstraints() {
        let child = FixedSizeRenderBox(width: 200, height: 200)
        let padding = EdgeInsets(all: 50.0)
        let box = RenderPadding(padding: padding, child: child)

        // maxWidth=250, maxHeight=250. Padding takes 100 each way, leaving 150x150 for child.
        // Child wants 200x200 but gets constrained to 150x150.
        // Result = 150+100 = 250 x 150+100 = 250
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 250, minHeight: 0, maxHeight: 250))
        XCTAssertEqual(box.size.width, 250.0)
        XCTAssertEqual(box.size.height, 250.0)
    }

    /// Test computeDryLayout without child.
    func testDryLayoutWithoutChild() {
        let padding = EdgeInsets(left: 5, top: 10, right: 15, bottom: 20)
        let box = RenderPadding(padding: padding)

        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        // horizontal = 20, vertical = 30
        XCTAssertEqual(size.width, 20.0)
        XCTAssertEqual(size.height, 30.0)
    }

    /// Test computeDryLayout with child.
    func testDryLayoutWithChild() {
        let child = FixedSizeRenderBox(width: 60, height: 40)
        let padding = EdgeInsets(left: 5, top: 10, right: 15, bottom: 20)
        let box = RenderPadding(padding: padding, child: child)

        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        // 60+20=80, 40+30=70
        XCTAssertEqual(size.width, 80.0)
        XCTAssertEqual(size.height, 70.0)
    }

    /// Test that child's parentData offset is set correctly after layout.
    func testChildOffsetAfterLayout() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let padding = EdgeInsets(left: 10, top: 20, right: 30, bottom: 40)
        let box = RenderPadding(padding: padding, child: child)

        box.layout(BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300))

        let childParentData = child.parentData as! BoxParentData
        XCTAssertEqual(childParentData.offset.dx, 10.0)
        XCTAssertEqual(childParentData.offset.dy, 20.0)
    }
}

// MARK: - RenderPositionedBox Construction Tests

final class RenderPositionedBoxConstructionTests: XCTestCase {

    /// Test default construction with center alignment.
    func testDefaultConstruction() {
        let box = RenderPositionedBox()
        XCTAssertNil(box.child)
        XCTAssertNil(box.widthFactor)
        XCTAssertNil(box.heightFactor)
    }

    /// Test construction with custom widthFactor and heightFactor.
    func testConstructionWithFactors() {
        let box = RenderPositionedBox(widthFactor: 2.0, heightFactor: 0.5)
        XCTAssertEqual(box.widthFactor, 2.0)
        XCTAssertEqual(box.heightFactor, 0.5)
    }

    /// Test construction with a child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderPositionedBox(child: child)
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
    }

    /// Test construction with custom alignment.
    func testConstructionWithAlignment() {
        let box = RenderPositionedBox(alignment: Alignment.topLeft)
        XCTAssertNotNil(box)
    }
}

// MARK: - RenderPositionedBox Property Tests

final class RenderPositionedBoxPropertyTests: XCTestCase {

    /// Test that setting widthFactor triggers layout.
    func testWidthFactorSetterTriggersLayout() {
        let box = RenderPositionedBox()
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.widthFactor = 2.0
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.widthFactor, 2.0)
    }

    /// Test that setting widthFactor to the same value does not trigger layout.
    func testWidthFactorSetterNoOpOnSameValue() {
        let box = RenderPositionedBox(widthFactor: 1.5)
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.widthFactor = 1.5
        XCTAssertFalse(box.needsLayout)
    }

    /// Test that setting heightFactor triggers layout.
    func testHeightFactorSetterTriggersLayout() {
        let box = RenderPositionedBox()
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.heightFactor = 0.5
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.heightFactor, 0.5)
    }

    /// Test that setting heightFactor to the same value does not trigger layout.
    func testHeightFactorSetterNoOpOnSameValue() {
        let box = RenderPositionedBox(heightFactor: 0.5)
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.heightFactor = 0.5
        XCTAssertFalse(box.needsLayout)
    }
}

// MARK: - RenderPositionedBox Intrinsic Tests

final class RenderPositionedBoxIntrinsicTests: XCTestCase {

    /// Test intrinsic dimensions with no factors delegate to child.
    func testIntrinsicsWithNoFactors() {
        let child = FixedSizeRenderBox(width: 100, height: 60)
        let box = RenderPositionedBox(child: child)
        // With no factors, multiplied by 1.0
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 100.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 100.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 60.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 60.0)
    }

    /// Test intrinsic dimensions with widthFactor.
    func testIntrinsicsWithWidthFactor() {
        let child = FixedSizeRenderBox(width: 100, height: 60)
        let box = RenderPositionedBox(child: child, widthFactor: 2.0)
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 200.0)  // 100 * 2.0
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 200.0)
    }

    /// Test intrinsic dimensions with heightFactor.
    func testIntrinsicsWithHeightFactor() {
        let child = FixedSizeRenderBox(width: 100, height: 60)
        let box = RenderPositionedBox(child: child, heightFactor: 3.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 180.0)  // 60 * 3.0
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 180.0)
    }

    /// Test intrinsic dimensions without child.
    func testIntrinsicsWithoutChild() {
        let box = RenderPositionedBox()
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 0.0)
    }
}

// MARK: - RenderPositionedBox Layout Tests

final class RenderPositionedBoxLayoutTests: XCTestCase {

    /// Test layout without child and without factors sizes to biggest.
    func testLayoutWithoutChildSizesToBiggest() {
        let box = RenderPositionedBox()
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300))
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 300.0)
    }

    /// Test layout without child but with factors sizes to zero times factor.
    func testLayoutWithoutChildWithFactors() {
        let box = RenderPositionedBox(widthFactor: 2.0, heightFactor: 3.0)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300))
        // No child, shrinkWrapWidth=true (factor), shrinkWrapHeight=true (factor).
        // Size is constrain(0 * 2.0, 0 * 3.0) = constrain(0, 0) = (0, 0)
        XCTAssertEqual(box.size.width, 0.0)
        XCTAssertEqual(box.size.height, 0.0)
    }

    /// Test layout with child and without factors sizes to biggest.
    func testLayoutWithChildNoFactors() {
        let child = FixedSizeRenderBox(width: 60, height: 40)
        let box = RenderPositionedBox(child: child)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300))
        // No factors and finite constraints => sizes to biggest
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 300.0)
    }

    /// Test layout with child and widthFactor.
    func testLayoutWithChildAndWidthFactor() {
        let child = FixedSizeRenderBox(width: 60, height: 40)
        let box = RenderPositionedBox(child: child, widthFactor: 2.0)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300))
        // widthFactor set => shrinkWrapWidth=true, child.width * 2.0 = 120
        // heightFactor nil, constraints finite => shrinkWrapHeight=false => infinity => clamped to 300
        XCTAssertEqual(box.size.width, 120.0)
        XCTAssertEqual(box.size.height, 300.0)
    }

    /// Test layout with child and heightFactor.
    func testLayoutWithChildAndHeightFactor() {
        let child = FixedSizeRenderBox(width: 60, height: 40)
        let box = RenderPositionedBox(child: child, heightFactor: 2.0)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300))
        // widthFactor nil, constraints finite => sizes to 200
        // heightFactor set => shrinkWrapHeight=true, child.height * 2.0 = 80
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 80.0)
    }

    /// Test computeDryLayout with child and factors.
    func testDryLayoutWithFactors() {
        let child = FixedSizeRenderBox(width: 50, height: 30)
        let box = RenderPositionedBox(child: child, widthFactor: 3.0, heightFactor: 2.0)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 500)
        let size = box.computeDryLayout(constraints)
        // shrinkWrapWidth=true, 50*3=150
        // shrinkWrapHeight=true, 30*2=60
        XCTAssertEqual(size.width, 150.0)
        XCTAssertEqual(size.height, 60.0)
    }
}

// MARK: - OverflowBoxFit Tests

final class OverflowBoxFitTests: XCTestCase {

    /// Test that both cases exist and are distinct.
    func testCasesExist() {
        let max = OverflowBoxFit.max
        let deferToChild = OverflowBoxFit.deferToChild
        XCTAssertNotNil(max)
        XCTAssertNotNil(deferToChild)
        XCTAssertTrue(max != deferToChild)
    }
}

// MARK: - RenderConstrainedOverflowBox Construction Tests

final class RenderConstrainedOverflowBoxConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderConstrainedOverflowBox()
        XCTAssertNil(box.child)
        XCTAssertNil(box.minWidth)
        XCTAssertNil(box.maxWidth)
        XCTAssertNil(box.minHeight)
        XCTAssertNil(box.maxHeight)
        XCTAssertEqual(box.fit, .max)
    }

    /// Test construction with custom values.
    func testConstructionWithCustomValues() {
        let box = RenderConstrainedOverflowBox(
            minWidth: 10,
            maxWidth: 200,
            minHeight: 20,
            maxHeight: 300,
            fit: .deferToChild
        )
        XCTAssertEqual(box.minWidth, 10.0)
        XCTAssertEqual(box.maxWidth, 200.0)
        XCTAssertEqual(box.minHeight, 20.0)
        XCTAssertEqual(box.maxHeight, 300.0)
        XCTAssertEqual(box.fit, .deferToChild)
    }
}

// MARK: - RenderConstrainedOverflowBox Property Tests

final class RenderConstrainedOverflowBoxPropertyTests: XCTestCase {

    /// Test that setting minWidth triggers layout.
    func testMinWidthSetterTriggersLayout() {
        let box = RenderConstrainedOverflowBox()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.minWidth = 50.0
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.minWidth, 50.0)
    }

    /// Test that setting minWidth to the same value does not trigger layout.
    func testMinWidthSetterNoOpOnSameValue() {
        let box = RenderConstrainedOverflowBox(minWidth: 50.0)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.minWidth = 50.0
        XCTAssertFalse(box.needsLayout)
    }

    /// Test that setting maxWidth triggers layout.
    func testMaxWidthSetterTriggersLayout() {
        let box = RenderConstrainedOverflowBox()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.maxWidth = 200.0
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting minHeight triggers layout.
    func testMinHeightSetterTriggersLayout() {
        let box = RenderConstrainedOverflowBox()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.minHeight = 30.0
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting maxHeight triggers layout.
    func testMaxHeightSetterTriggersLayout() {
        let box = RenderConstrainedOverflowBox()
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.maxHeight = 400.0
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting fit triggers layout.
    func testFitSetterTriggersLayout() {
        let box = RenderConstrainedOverflowBox(fit: .max)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.fit = .deferToChild
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting fit to the same value does not trigger layout.
    func testFitSetterNoOpOnSameValue() {
        let box = RenderConstrainedOverflowBox(fit: .max)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.fit = .max
        XCTAssertFalse(box.needsLayout)
    }

    /// Test sizedByParent is true for .max fit.
    func testSizedByParentMaxFit() {
        let box = RenderConstrainedOverflowBox(fit: .max)
        XCTAssertTrue(box.sizedByParent)
    }

    /// Test sizedByParent is false for .deferToChild fit.
    func testSizedByParentDeferToChildFit() {
        let box = RenderConstrainedOverflowBox(fit: .deferToChild)
        XCTAssertFalse(box.sizedByParent)
    }
}

// MARK: - RenderConstrainedOverflowBox Layout Tests

final class RenderConstrainedOverflowBoxLayoutTests: XCTestCase {

    /// Test computeDryLayout with .max fit returns constraints.biggest.
    func testDryLayoutMaxFit() {
        let box = RenderConstrainedOverflowBox(fit: .max)
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 300)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test computeDryLayout with .deferToChild fit and no child returns smallest.
    func testDryLayoutDeferToChildNoChild() {
        let box = RenderConstrainedOverflowBox(fit: .deferToChild)
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 300)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 10.0)
        XCTAssertEqual(size.height, 20.0)
    }
}

// MARK: - RenderSizedOverflowBox Construction Tests

final class RenderSizedOverflowBoxConstructionTests: XCTestCase {

    /// Test construction with requestedSize.
    func testConstruction() {
        let box = RenderSizedOverflowBox(requestedSize: Size(150, 100))
        XCTAssertNil(box.child)
        XCTAssertEqual(box.requestedSize.width, 150.0)
        XCTAssertEqual(box.requestedSize.height, 100.0)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let box = RenderSizedOverflowBox(child: child, requestedSize: Size(200, 200))
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
    }
}

// MARK: - RenderSizedOverflowBox Property Tests

final class RenderSizedOverflowBoxPropertyTests: XCTestCase {

    /// Test that setting requestedSize triggers layout.
    func testRequestedSizeSetterTriggersLayout() {
        let box = RenderSizedOverflowBox(requestedSize: Size(100, 100))
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.requestedSize = Size(150, 150)
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting requestedSize to the same value does not trigger layout.
    func testRequestedSizeSetterNoOpOnSameValue() {
        let box = RenderSizedOverflowBox(requestedSize: Size(100, 100))
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.requestedSize = Size(100, 100)
        XCTAssertFalse(box.needsLayout)
    }
}

// MARK: - RenderSizedOverflowBox Intrinsic Tests

final class RenderSizedOverflowBoxIntrinsicTests: XCTestCase {

    /// Test that intrinsic dimensions return the requestedSize dimensions.
    func testIntrinsicDimensionsReturnRequestedSize() {
        let box = RenderSizedOverflowBox(requestedSize: Size(120, 80))
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 80.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 80.0)
    }

    /// Test that intrinsic dimensions return requestedSize even with a child.
    func testIntrinsicDimensionsIgnoreChild() {
        let child = FixedSizeRenderBox(width: 200, height: 200)
        let box = RenderSizedOverflowBox(child: child, requestedSize: Size(50, 50))
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 50.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 50.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 50.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 50.0)
    }
}

// MARK: - RenderSizedOverflowBox Layout Tests

final class RenderSizedOverflowBoxLayoutTests: XCTestCase {

    /// Test computeDryLayout constrains requestedSize.
    func testDryLayoutConstrainsRequestedSize() {
        let box = RenderSizedOverflowBox(requestedSize: Size(150, 100))
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 150.0)
        XCTAssertEqual(size.height, 100.0)
    }

    /// Test computeDryLayout clamps requestedSize to max constraints.
    func testDryLayoutClampsToMaxConstraints() {
        let box = RenderSizedOverflowBox(requestedSize: Size(500, 400))
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test performLayout sizes to constrained requestedSize.
    func testPerformLayoutSizesToRequestedSize() {
        let box = RenderSizedOverflowBox(requestedSize: Size(120, 80))
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(box.size.width, 120.0)
        XCTAssertEqual(box.size.height, 80.0)
    }

    /// Test performLayout with child: child is laid out with original constraints.
    func testPerformLayoutWithChild() {
        let child = FixedSizeRenderBox(width: 60, height: 40)
        let box = RenderSizedOverflowBox(child: child, requestedSize: Size(120, 80))
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        box.layout(constraints)
        // Box sizes to constrained requestedSize
        XCTAssertEqual(box.size.width, 120.0)
        XCTAssertEqual(box.size.height, 80.0)
        // Child is laid out with original constraints
        XCTAssertTrue(child.hasSize)
        XCTAssertEqual(child.size.width, 60.0)
        XCTAssertEqual(child.size.height, 40.0)
    }
}

// MARK: - RenderFractionallySizedOverflowBox Construction Tests

final class RenderFractionallySizedOverflowBoxConstructionTests: XCTestCase {

    /// Test default construction.
    func testDefaultConstruction() {
        let box = RenderFractionallySizedOverflowBox()
        XCTAssertNil(box.child)
        XCTAssertNil(box.widthFactor)
        XCTAssertNil(box.heightFactor)
    }

    /// Test construction with factors.
    func testConstructionWithFactors() {
        let box = RenderFractionallySizedOverflowBox(widthFactor: 0.5, heightFactor: 0.75)
        XCTAssertEqual(box.widthFactor, 0.5)
        XCTAssertEqual(box.heightFactor, 0.75)
    }
}

// MARK: - RenderFractionallySizedOverflowBox Property Tests

final class RenderFractionallySizedOverflowBoxPropertyTests: XCTestCase {

    /// Test that setting widthFactor triggers layout.
    func testWidthFactorSetterTriggersLayout() {
        let box = RenderFractionallySizedOverflowBox()
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.widthFactor = 0.5
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.widthFactor, 0.5)
    }

    /// Test that setting widthFactor to the same value does not trigger layout.
    func testWidthFactorSetterNoOpOnSameValue() {
        let box = RenderFractionallySizedOverflowBox(widthFactor: 0.5)
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.widthFactor = 0.5
        XCTAssertFalse(box.needsLayout)
    }

    /// Test that setting heightFactor triggers layout.
    func testHeightFactorSetterTriggersLayout() {
        let box = RenderFractionallySizedOverflowBox()
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.heightFactor = 0.75
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.heightFactor, 0.75)
    }

    /// Test that setting heightFactor to the same value does not trigger layout.
    func testHeightFactorSetterNoOpOnSameValue() {
        let box = RenderFractionallySizedOverflowBox(heightFactor: 0.75)
        box.layout(BoxConstraints.tight(Size(200, 200)))
        XCTAssertFalse(box.needsLayout)

        box.heightFactor = 0.75
        XCTAssertFalse(box.needsLayout)
    }
}

// MARK: - RenderFractionallySizedOverflowBox Layout Tests

final class RenderFractionallySizedOverflowBoxLayoutTests: XCTestCase {

    /// Test layout with child and width/height factors.
    func testLayoutWithFactors() {
        let child = FixedSizeRenderBox(width: 200, height: 200)
        let box = RenderFractionallySizedOverflowBox(
            child: child, widthFactor: 0.5, heightFactor: 0.75
        )
        let constraints = BoxConstraints.tight(Size(200, 200))
        box.layout(constraints)
        // Inner constraints: width = 200 * 0.5 = 100 (tight), height = 200 * 0.75 = 150 (tight)
        // Child constrained to 100x150
        XCTAssertEqual(child.size.width, 100.0)
        XCTAssertEqual(child.size.height, 150.0)
        // Box constrains child.size to parent constraints => (100, 150) within (200, 200) => (100, 150)
        // Wait, box.size = constraints.constrain(child.size) => tight(200,200).constrain(100,150) => (200,200)
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 200.0)
    }

    /// Test layout without factors passes through constraints.
    func testLayoutWithoutFactors() {
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let box = RenderFractionallySizedOverflowBox(child: child)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        box.layout(constraints)
        // No factors => inner constraints = parent constraints
        // Child gets 80x60 constrained to (0..200, 0..200) = 80x60
        // box.size = constraints.constrain(80, 60) = 80x60
        XCTAssertEqual(child.size.width, 80.0)
        XCTAssertEqual(child.size.height, 60.0)
        XCTAssertEqual(box.size.width, 80.0)
        XCTAssertEqual(box.size.height, 60.0)
    }

    /// Test layout without child.
    func testLayoutWithoutChild() {
        let box = RenderFractionallySizedOverflowBox(widthFactor: 0.5, heightFactor: 0.5)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        box.layout(constraints)
        // No child: inner constraints = tight(100, 100). constrain(Size.zero) = (100, 100)
        // Then constraints.constrain(100, 100) = (100, 100)
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 100.0)
    }
}

// MARK: - RenderConstraintsTransformBox Construction Tests

final class RenderConstraintsTransformBoxConstructionTests: XCTestCase {

    /// Test construction with identity transform.
    func testConstructionWithIdentityTransform() {
        let box = RenderConstraintsTransformBox(
            constraintsTransform: { $0 }
        )
        XCTAssertNil(box.child)
        XCTAssertEqual(box.clipBehavior, .none)
    }

    /// Test construction with custom clip behavior.
    func testConstructionWithClipBehavior() {
        let box = RenderConstraintsTransformBox(
            constraintsTransform: { $0 },
            clipBehavior: .hardEdge
        )
        XCTAssertEqual(box.clipBehavior, .hardEdge)
    }

    /// Test construction with a child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = RenderConstraintsTransformBox(
            constraintsTransform: { $0 },
            child: child
        )
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
    }
}

// MARK: - RenderConstraintsTransformBox Property Tests

final class RenderConstraintsTransformBoxPropertyTests: XCTestCase {

    /// Test that setting clipBehavior triggers markNeedsPaint.
    func testClipBehaviorSetterTriggersPaint() {
        let box = RenderConstraintsTransformBox(
            constraintsTransform: { $0 },
            clipBehavior: .none
        )
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false

        box.clipBehavior = .hardEdge
        XCTAssertTrue(box.needsPaint)
    }

    /// Test that setting clipBehavior to the same value does not trigger paint.
    func testClipBehaviorSetterNoOpOnSameValue() {
        let box = RenderConstraintsTransformBox(
            constraintsTransform: { $0 },
            clipBehavior: .none
        )
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.needsPaint = false

        box.clipBehavior = .none
        XCTAssertFalse(box.needsPaint)
    }
}

// MARK: - RenderConstraintsTransformBox Layout Tests

final class RenderConstraintsTransformBoxLayoutTests: XCTestCase {

    /// Test computeDryLayout with identity transform returns child size.
    func testDryLayoutIdentityTransform() {
        let child = FixedSizeRenderBox(width: 80, height: 60)
        let box = RenderConstraintsTransformBox(
            constraintsTransform: { $0 },
            child: child
        )
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 80.0)
        XCTAssertEqual(size.height, 60.0)
    }

    /// Test computeDryLayout with no child returns smallest.
    func testDryLayoutNoChild() {
        let box = RenderConstraintsTransformBox(constraintsTransform: { $0 })
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 300)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 10.0)
        XCTAssertEqual(size.height, 20.0)
    }

    /// Test layout with unconstrained transform allows overflow.
    func testLayoutWithUnconstrainedTransform() {
        let child = FixedSizeRenderBox(width: 300, height: 300)
        let box = RenderConstraintsTransformBox(
            constraintsTransform: { _ in
                BoxConstraints(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            },
            child: child
        )
        box.layout(BoxConstraints.tight(Size(100, 100)))
        // Box sizes to constraints.constrain(child.size) = constrain(300, 300) with tight(100, 100) = (100, 100)
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 100.0)
        // Child was laid out unconstrained, so it's 300x300
        XCTAssertEqual(child.size.width, 300.0)
        XCTAssertEqual(child.size.height, 300.0)
    }

    /// Test dispose does not crash.
    func testDispose() {
        let box = RenderConstraintsTransformBox(constraintsTransform: { $0 })
        box.layout(BoxConstraints.tight(Size(100, 100)))
        box.dispose()
    }
}

// MARK: - SingleChildLayoutDelegate Tests

final class SingleChildLayoutDelegateTests: XCTestCase {

    /// Test that default getSize returns constraints.biggest.
    func testDefaultGetSizeReturnsBiggest() {
        let delegate = TestSingleChildLayoutDelegate()
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 300)
        let size = delegate.getSize(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test that default getConstraintsForChild returns the given constraints.
    func testDefaultGetConstraintsForChild() {
        let delegate = TestSingleChildLayoutDelegate()
        let constraints = BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 300)
        let childConstraints = delegate.getConstraintsForChild(constraints)
        XCTAssertEqual(childConstraints.minWidth, 10.0)
        XCTAssertEqual(childConstraints.maxWidth, 200.0)
        XCTAssertEqual(childConstraints.minHeight, 20.0)
        XCTAssertEqual(childConstraints.maxHeight, 300.0)
    }

    /// Test that default getPositionForChild returns .zero.
    func testDefaultGetPositionForChild() {
        let delegate = TestSingleChildLayoutDelegate()
        let position = delegate.getPositionForChild(Size(200, 200), Size(50, 50))
        XCTAssertEqual(position.dx, 0.0)
        XCTAssertEqual(position.dy, 0.0)
    }

    /// Test that custom getSize override works.
    func testCustomGetSize() {
        let delegate = TestSingleChildLayoutDelegate(fixedSize: Size(100, 80))
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 500, minHeight: 0, maxHeight: 500)
        let size = delegate.getSize(constraints)
        XCTAssertEqual(size.width, 100.0)
        XCTAssertEqual(size.height, 80.0)
    }

    /// Test that custom getConstraintsForChild override works.
    func testCustomGetConstraintsForChild() {
        let childConstraints = BoxConstraints.tight(Size(50, 50))
        let delegate = TestSingleChildLayoutDelegate(fixedConstraints: childConstraints)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let result = delegate.getConstraintsForChild(constraints)
        XCTAssertEqual(result.minWidth, 50.0)
        XCTAssertEqual(result.maxWidth, 50.0)
        XCTAssertEqual(result.minHeight, 50.0)
        XCTAssertEqual(result.maxHeight, 50.0)
    }

    /// Test that custom getPositionForChild override works.
    func testCustomGetPositionForChild() {
        let delegate = TestSingleChildLayoutDelegate(fixedPosition: Offset(10, 20))
        let position = delegate.getPositionForChild(Size(200, 200), Size(50, 50))
        XCTAssertEqual(position.dx, 10.0)
        XCTAssertEqual(position.dy, 20.0)
    }

    /// Test shouldRelayout returns configured value.
    func testShouldRelayoutTrue() {
        let delegate = TestSingleChildLayoutDelegate(relayoutResult: true)
        let old = TestSingleChildLayoutDelegate()
        XCTAssertTrue(delegate.shouldRelayout(old))
    }

    /// Test shouldRelayout returns false when configured.
    func testShouldRelayoutFalse() {
        let delegate = TestSingleChildLayoutDelegate(relayoutResult: false)
        let old = TestSingleChildLayoutDelegate()
        XCTAssertFalse(delegate.shouldRelayout(old))
    }

    /// Test that relayout defaults to nil.
    func testRelayoutDefaultsToNil() {
        let delegate = TestSingleChildLayoutDelegate()
        XCTAssertNil(delegate._relayout)
    }

    /// Test that relayout stores the provided listenable.
    func testRelayoutStoresListenable() {
        let notifier = ChangeNotifier()
        let delegate = TestSingleChildLayoutDelegate(relayout: notifier)
        XCTAssertNotNil(delegate._relayout)
    }
}

// MARK: - RenderCustomSingleChildLayoutBox Construction Tests

final class RenderCustomSingleChildLayoutBoxConstructionTests: XCTestCase {

    /// Test basic construction with a delegate.
    func testConstruction() {
        let delegate = TestSingleChildLayoutDelegate()
        let box = RenderCustomSingleChildLayoutBox(delegate: delegate)
        XCTAssertTrue(box.delegate === delegate)
        XCTAssertNil(box.child)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let delegate = TestSingleChildLayoutDelegate()
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = RenderCustomSingleChildLayoutBox(child: child, delegate: delegate)
        XCTAssertTrue(box.delegate === delegate)
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
    }
}

// MARK: - RenderCustomSingleChildLayoutBox Delegate Setter Tests

final class RenderCustomSingleChildLayoutBoxDelegateTests: XCTestCase {

    /// Test that setting the delegate to the same instance is a no-op.
    func testDelegateSetterSameInstance() {
        let delegate = TestSingleChildLayoutDelegate(relayoutResult: true)
        let box = RenderCustomSingleChildLayoutBox(delegate: delegate)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.delegate = delegate
        XCTAssertFalse(box.needsLayout, "Setting same delegate should not mark needs layout")
    }

    /// Test that setting a different delegate with shouldRelayout=true triggers layout.
    func testDelegateSetterTriggersRelayoutWhenShouldRelayoutTrue() {
        let oldDelegate = TestSingleChildLayoutDelegate(relayoutResult: false)
        let box = RenderCustomSingleChildLayoutBox(delegate: oldDelegate)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        let newDelegate = TestSingleChildLayoutDelegate(relayoutResult: true)
        box.delegate = newDelegate
        XCTAssertTrue(box.needsLayout, "Setting delegate with shouldRelayout=true should mark needs layout")
    }

    /// Test that setting a different delegate with shouldRelayout=false does not trigger layout.
    func testDelegateSetterNoRelayoutWhenShouldRelayoutFalse() {
        let oldDelegate = TestSingleChildLayoutDelegate(relayoutResult: false)
        let box = RenderCustomSingleChildLayoutBox(delegate: oldDelegate)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        let newDelegate = TestSingleChildLayoutDelegate(relayoutResult: false)
        box.delegate = newDelegate
        XCTAssertFalse(
            box.needsLayout,
            "Setting delegate with shouldRelayout=false (same type) should not mark needs layout"
        )
    }
}

// MARK: - RenderCustomSingleChildLayoutBox Intrinsic Tests

final class RenderCustomSingleChildLayoutBoxIntrinsicTests: XCTestCase {

    /// Test intrinsic dimensions with fixed-size delegate.
    func testIntrinsicDimensionsWithFixedSizeDelegate() {
        let delegate = TestSingleChildLayoutDelegate(fixedSize: Size(120, 80))
        let box = RenderCustomSingleChildLayoutBox(delegate: delegate)
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 120.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 80.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 80.0)
    }

    /// Test intrinsic dimensions return 0 when delegate returns infinite size.
    func testIntrinsicDimensionsReturnZeroWhenInfinite() {
        let delegate = TestSingleChildLayoutDelegate()  // Returns constraints.biggest
        let box = RenderCustomSingleChildLayoutBox(delegate: delegate)
        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 0.0)
    }
}

// MARK: - RenderCustomSingleChildLayoutBox Layout Tests

final class RenderCustomSingleChildLayoutBoxLayoutTests: XCTestCase {

    /// Test computeDryLayout returns delegate's constrained size.
    func testDryLayout() {
        let delegate = TestSingleChildLayoutDelegate(fixedSize: Size(150, 100))
        let box = RenderCustomSingleChildLayoutBox(delegate: delegate)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 150.0)
        XCTAssertEqual(size.height, 100.0)
    }

    /// Test computeDryLayout constrains delegate's size.
    func testDryLayoutConstrainsDelegateSize() {
        let delegate = TestSingleChildLayoutDelegate(fixedSize: Size(500, 500))
        let box = RenderCustomSingleChildLayoutBox(delegate: delegate)
        let constraints = BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 300)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 200.0)
        XCTAssertEqual(size.height, 300.0)
    }

    /// Test performLayout calls delegate and sizes correctly.
    func testPerformLayout() {
        let delegate = TestSingleChildLayoutDelegate(fixedSize: Size(150, 100))
        let box = RenderCustomSingleChildLayoutBox(delegate: delegate)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertEqual(box.size.width, 150.0)
        XCTAssertEqual(box.size.height, 100.0)
    }

    /// Test performLayout with child and delegate position.
    func testPerformLayoutWithChildAndPosition() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let delegate = TestSingleChildLayoutDelegate(
            fixedSize: Size(200, 200),
            fixedPosition: Offset(10, 20)
        )
        let box = RenderCustomSingleChildLayoutBox(child: child, delegate: delegate)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: 300))
        XCTAssertEqual(box.size.width, 200.0)
        XCTAssertEqual(box.size.height, 200.0)
        // Child offset should be set by delegate's getPositionForChild
        let childParentData = child.parentData as! BoxParentData
        XCTAssertEqual(childParentData.offset.dx, 10.0)
        XCTAssertEqual(childParentData.offset.dy, 20.0)
    }
}

// MARK: - RenderCustomSingleChildLayoutBox Attach/Detach Tests

final class RenderCustomSingleChildLayoutBoxAttachDetachTests: XCTestCase {

    /// Test attach and detach with pipeline owner.
    func testAttachDetach() {
        let delegate = TestSingleChildLayoutDelegate()
        let box = RenderCustomSingleChildLayoutBox(delegate: delegate)
        let owner = PipelineOwner()

        XCTAssertFalse(box.attached)
        box.attach(owner)
        XCTAssertTrue(box.attached)
        box.detach()
        XCTAssertFalse(box.attached)
    }
}

// MARK: - RenderBaseline Construction Tests

final class RenderBaselineConstructionTests: XCTestCase {

    /// Test basic construction.
    func testConstruction() {
        let box = RenderBaseline(baseline: 20.0, baselineType: .alphabetic)
        XCTAssertEqual(box.baseline, 20.0)
        XCTAssertEqual(box.baselineType, .alphabetic)
        XCTAssertNil(box.child)
    }

    /// Test construction with child.
    func testConstructionWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderBaseline(child: child, baseline: 30.0, baselineType: .ideographic)
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
        XCTAssertEqual(box.baseline, 30.0)
        XCTAssertEqual(box.baselineType, .ideographic)
    }
}

// MARK: - RenderBaseline Property Tests

final class RenderBaselinePropertyTests: XCTestCase {

    /// Test that setting baseline triggers layout.
    func testBaselineSetterTriggersLayout() {
        let box = RenderBaseline(baseline: 20.0, baselineType: .alphabetic)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)

        box.baseline = 30.0
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.baseline, 30.0)
    }

    /// Test that setting baseline to the same value does not trigger layout.
    func testBaselineSetterNoOpOnSameValue() {
        let box = RenderBaseline(baseline: 20.0, baselineType: .alphabetic)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)

        box.baseline = 20.0
        XCTAssertFalse(box.needsLayout)
    }

    /// Test that setting baselineType triggers layout.
    func testBaselineTypeSetterTriggersLayout() {
        let box = RenderBaseline(baseline: 20.0, baselineType: .alphabetic)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)

        box.baselineType = .ideographic
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.baselineType, .ideographic)
    }

    /// Test that setting baselineType to the same value does not trigger layout.
    func testBaselineTypeSetterNoOpOnSameValue() {
        let box = RenderBaseline(baseline: 20.0, baselineType: .alphabetic)
        box.layout(BoxConstraints(minWidth: 0, maxWidth: 200, minHeight: 0, maxHeight: 200))
        XCTAssertFalse(box.needsLayout)

        box.baselineType = .alphabetic
        XCTAssertFalse(box.needsLayout)
    }
}

// MARK: - RenderBaseline Layout Tests

final class RenderBaselineLayoutTests: XCTestCase {

    /// Test layout without child returns smallest.
    func testLayoutWithoutChild() {
        let box = RenderBaseline(baseline: 20.0, baselineType: .alphabetic)
        box.layout(BoxConstraints(minWidth: 10, maxWidth: 200, minHeight: 20, maxHeight: 200))
        XCTAssertEqual(box.size.width, 10.0)
        XCTAssertEqual(box.size.height, 20.0)
    }

    /// Test computeDryLayout without child returns smallest.
    func testDryLayoutWithoutChild() {
        let box = RenderBaseline(baseline: 20.0, baselineType: .alphabetic)
        let constraints = BoxConstraints(minWidth: 5, maxWidth: 200, minHeight: 15, maxHeight: 200)
        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 5.0)
        XCTAssertEqual(size.height, 15.0)
    }
}

// MARK: - RenderAligningShiftedBox Tests (via RenderPositionedBox)

/// Tests for the alignment and textDirection properties inherited from
/// RenderAligningShiftedBox, tested through the concrete RenderPositionedBox subclass.
final class RenderAligningShiftedBoxTests: XCTestCase {

    /// Test default construction has center alignment.
    func testDefaultAlignment() {
        let box = RenderPositionedBox()
        // resolvedAlignment for default center should be (0, 0)
        let resolved = box.resolvedAlignment
        XCTAssertEqual(resolved.x, 0.0)
        XCTAssertEqual(resolved.y, 0.0)
    }

    /// Test construction with custom alignment.
    func testCustomAlignment() {
        let box = RenderPositionedBox(alignment: Alignment.topLeft)
        let resolved = box.resolvedAlignment
        XCTAssertEqual(resolved.x, -1.0)
        XCTAssertEqual(resolved.y, -1.0)
    }

    /// Test that setting alignment triggers layout.
    func testAlignmentSetterTriggersLayout() {
        let box = RenderPositionedBox(alignment: Alignment.center)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.alignment = Alignment.topLeft
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting alignment to the same value does not trigger layout.
    func testAlignmentSetterNoOpOnSameValue() {
        let box = RenderPositionedBox(alignment: Alignment.center)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.alignment = Alignment.center
        XCTAssertFalse(box.needsLayout)
    }

    /// Test that setting textDirection triggers layout.
    func testTextDirectionSetterTriggersLayout() {
        let box = RenderPositionedBox(textDirection: .ltr)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.textDirection = .rtl
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting textDirection to the same value does not trigger layout.
    func testTextDirectionSetterNoOpOnSameValue() {
        let box = RenderPositionedBox(textDirection: .ltr)
        box.layout(BoxConstraints.tight(Size(100, 100)))
        XCTAssertFalse(box.needsLayout)

        box.textDirection = .ltr
        XCTAssertFalse(box.needsLayout)
    }
}

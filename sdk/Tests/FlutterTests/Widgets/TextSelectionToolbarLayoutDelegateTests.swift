// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import FlutterSwiftBridge
@testable import Flutter

/// Tests for `TextSelectionToolbarLayoutDelegate`.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/text_selection_toolbar_layout_delegate_test.dart`
final class TextSelectionToolbarLayoutDelegateTests: XCTestCase {

    // MARK: - centerOn static method

    func testCenterOnPerfectlyCentered() {
        // position=200, width=100, max=400 => 200 - 50 = 150
        let result = TextSelectionToolbarLayoutDelegate.centerOn(200, 100, 400)
        XCTAssertEqual(result, 150.0)
    }

    func testCenterOnLeftOverflow() {
        // position=30, width=100, max=400 => 30 - 50 < 0 => 0
        let result = TextSelectionToolbarLayoutDelegate.centerOn(30, 100, 400)
        XCTAssertEqual(result, 0.0)
    }

    func testCenterOnRightOverflow() {
        // position=380, width=100, max=400 => 380 + 50 > 400 => 400 - 100 = 300
        let result = TextSelectionToolbarLayoutDelegate.centerOn(380, 100, 400)
        XCTAssertEqual(result, 300.0)
    }

    func testCenterOnExactFit() {
        // position=200, width=400, max=400 => 200 - 200 = 0, but also 200 + 200 > 400 => 400 - 400 = 0
        let result = TextSelectionToolbarLayoutDelegate.centerOn(200, 400, 400)
        XCTAssertEqual(result, 0.0)
    }

    func testCenterOnZeroWidth() {
        // position=200, width=0, max=400 => 200 - 0 = 200
        let result = TextSelectionToolbarLayoutDelegate.centerOn(200, 0, 400)
        XCTAssertEqual(result, 200.0)
    }

    func testCenterOnJustBarelyFitsLeft() {
        // position=50, width=100, max=400 => 50 - 50 = 0, not < 0 => 0.0
        let result = TextSelectionToolbarLayoutDelegate.centerOn(50, 100, 400)
        XCTAssertEqual(result, 0.0)
    }

    func testCenterOnJustBarelyFitsRight() {
        // position=350, width=100, max=400 => 350 + 50 = 400, not > 400 => 350 - 50 = 300
        let result = TextSelectionToolbarLayoutDelegate.centerOn(350, 100, 400)
        XCTAssertEqual(result, 300.0)
    }

    // MARK: - Constructor

    func testDefaultFitsAboveIsNil() {
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 250)
        )
        XCTAssertNil(delegate.fitsAbove)
    }

    func testAllPropertiesStoredCorrectly() {
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(50, 100),
            anchorBelow: Offset(50, 150),
            fitsAbove: true
        )
        XCTAssertEqual(delegate.anchorAbove.dx, 50.0)
        XCTAssertEqual(delegate.anchorAbove.dy, 100.0)
        XCTAssertEqual(delegate.anchorBelow.dx, 50.0)
        XCTAssertEqual(delegate.anchorBelow.dy, 150.0)
        XCTAssertEqual(delegate.fitsAbove, true)
    }

    // MARK: - getConstraintsForChild

    func testGetConstraintsForChildLoosensConstraints() {
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 250)
        )
        let constraints = BoxConstraints(minWidth: 50, maxWidth: 400, minHeight: 30, maxHeight: 300)
        let loosened = delegate.getConstraintsForChild(constraints)
        // loosen() sets minWidth=0, minHeight=0 but keeps max
        XCTAssertEqual(loosened.minWidth, 0.0)
        XCTAssertEqual(loosened.maxWidth, 400.0)
        XCTAssertEqual(loosened.minHeight, 0.0)
        XCTAssertEqual(loosened.maxHeight, 300.0)
    }

    // MARK: - getPositionForChild - fits above (calculated)

    func testGetPositionForChildFitsAboveCalculated() {
        // anchorAbove.dy=200 >= childSize.height=50 => fits above
        // anchor = anchorAbove = (200, 200)
        // x = centerOn(200, 100, 400) = 150
        // y = max(0, 200 - 50) = 150
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(200, 200),
            anchorBelow: Offset(200, 250)
        )
        let position = delegate.getPositionForChild(Size(400, 600), Size(100, 50))
        XCTAssertEqual(position.dx, 150.0)
        XCTAssertEqual(position.dy, 150.0)
    }

    func testGetPositionForChildPositionsAboveUsingAnchorAbove() {
        // anchorAbove.dy=300 >= childSize.height=100 => fits above
        // y = max(0, 300 - 100) = 200
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(150, 300),
            anchorBelow: Offset(150, 350)
        )
        let position = delegate.getPositionForChild(Size(400, 600), Size(80, 100))
        XCTAssertEqual(position.dy, 200.0)
    }

    // MARK: - getPositionForChild - doesn't fit above (calculated)

    func testGetPositionForChildDoesNotFitAboveCalculated() {
        // anchorAbove.dy=30 < childSize.height=50 => doesn't fit above
        // anchor = anchorBelow = (200, 80)
        // x = centerOn(200, 100, 400) = 150
        // y = anchorBelow.dy = 80
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(200, 30),
            anchorBelow: Offset(200, 80)
        )
        let position = delegate.getPositionForChild(Size(400, 600), Size(100, 50))
        XCTAssertEqual(position.dx, 150.0)
        XCTAssertEqual(position.dy, 80.0)
    }

    func testGetPositionForChildUsesAnchorBelowDyAsY() {
        // anchorAbove.dy=20 < childSize.height=100 => doesn't fit above
        // y = anchorBelow.dy = 120
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 20),
            anchorBelow: Offset(100, 120)
        )
        let position = delegate.getPositionForChild(Size(400, 600), Size(80, 100))
        XCTAssertEqual(position.dy, 120.0)
    }

    // MARK: - getPositionForChild - fitsAbove forced true

    func testGetPositionForChildFitsAboveForcedTrue() {
        // fitsAbove=true even though anchorAbove.dy=20 < childSize.height=50
        // anchor = anchorAbove = (200, 20)
        // y = max(0, 20 - 50) = max(0, -30) = 0
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(200, 20),
            anchorBelow: Offset(200, 80),
            fitsAbove: true
        )
        let position = delegate.getPositionForChild(Size(400, 600), Size(100, 50))
        XCTAssertEqual(position.dy, 0.0)
    }

    // MARK: - getPositionForChild - fitsAbove forced false

    func testGetPositionForChildFitsAboveForcedFalse() {
        // fitsAbove=false even though anchorAbove.dy=200 >= childSize.height=50
        // anchor = anchorBelow = (200, 250)
        // y = anchorBelow.dy = 250
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(200, 200),
            anchorBelow: Offset(200, 250),
            fitsAbove: false
        )
        let position = delegate.getPositionForChild(Size(400, 600), Size(100, 50))
        XCTAssertEqual(position.dy, 250.0)
    }

    // MARK: - getPositionForChild - horizontal centering

    func testGetPositionForChildHorizontalCentering() {
        // Toolbar centered horizontally on anchor.dx
        // anchorAbove.dy=200 >= childSize.height=50 => fits above
        // anchor = anchorAbove = (200, 200)
        // x = centerOn(200, 100, 400) = 150
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(200, 200),
            anchorBelow: Offset(200, 250)
        )
        let position = delegate.getPositionForChild(Size(400, 600), Size(100, 50))
        XCTAssertEqual(position.dx, 150.0)
    }

    func testGetPositionForChildClampedLeft() {
        // Near left edge: anchor.dx=30, width=100
        // centerOn(30, 100, 400) => 30 - 50 < 0 => 0
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(30, 200),
            anchorBelow: Offset(30, 250)
        )
        let position = delegate.getPositionForChild(Size(400, 600), Size(100, 50))
        XCTAssertEqual(position.dx, 0.0)
    }

    func testGetPositionForChildClampedRight() {
        // Near right edge: anchor.dx=380, width=100
        // centerOn(380, 100, 400) => 380 + 50 > 400 => 400 - 100 = 300
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(380, 200),
            anchorBelow: Offset(380, 250)
        )
        let position = delegate.getPositionForChild(Size(400, 600), Size(100, 50))
        XCTAssertEqual(position.dx, 300.0)
    }

    // MARK: - shouldRelayout

    func testShouldRelayoutSameParametersReturnsFalse() {
        let delegate1 = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 250),
            fitsAbove: true
        )
        let delegate2 = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 250),
            fitsAbove: true
        )
        XCTAssertFalse(delegate1.shouldRelayout(delegate2))
    }

    func testShouldRelayoutDifferentAnchorAboveReturnsTrue() {
        let delegate1 = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 250)
        )
        let delegate2 = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(150, 200),
            anchorBelow: Offset(100, 250)
        )
        XCTAssertTrue(delegate1.shouldRelayout(delegate2))
    }

    func testShouldRelayoutDifferentAnchorBelowReturnsTrue() {
        let delegate1 = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 250)
        )
        let delegate2 = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 300)
        )
        XCTAssertTrue(delegate1.shouldRelayout(delegate2))
    }

    func testShouldRelayoutDifferentFitsAboveReturnsTrue() {
        let delegate1 = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 250),
            fitsAbove: true
        )
        let delegate2 = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 250),
            fitsAbove: false
        )
        XCTAssertTrue(delegate1.shouldRelayout(delegate2))
    }

    func testShouldRelayoutDifferentDelegateTypeReturnsTrue() {
        let delegate = TextSelectionToolbarLayoutDelegate(
            anchorAbove: Offset(100, 200),
            anchorBelow: Offset(100, 250)
        )
        let otherDelegate = SingleChildLayoutDelegate()
        XCTAssertTrue(delegate.shouldRelayout(otherDelegate))
    }
}

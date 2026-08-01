// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import FlutterSwiftBridge
@testable import Flutter

/// Tests for DesktopTextSelectionToolbarLayoutDelegate migrated from
/// desktop_text_selection_toolbar_layout_delegate.dart.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/desktop_text_selection_toolbar_layout_delegate.dart`
final class DesktopTextSelectionToolbarLayoutDelegateTests: XCTestCase {

    // MARK: - Constructor Tests

    /// Test that anchor is stored correctly.
    func testAnchorIsStoredCorrectly() {
        let anchor = Offset(100.0, 200.0)
        let delegate = DesktopTextSelectionToolbarLayoutDelegate(anchor: anchor)
        XCTAssertEqual(delegate.anchor, anchor)
    }

    // MARK: - getConstraintsForChild Tests

    /// Test that getConstraintsForChild loosens tight constraints
    /// (minWidth/minHeight become 0).
    func testGetConstraintsForChildLoosensConstraints() {
        let delegate = DesktopTextSelectionToolbarLayoutDelegate(anchor: Offset(0.0, 0.0))
        let tight = BoxConstraints(
            minWidth: 100.0,
            maxWidth: 100.0,
            minHeight: 50.0,
            maxHeight: 50.0
        )
        let loosened = delegate.getConstraintsForChild(tight)
        XCTAssertEqual(loosened.minWidth, 0.0)
        XCTAssertEqual(loosened.maxWidth, 100.0)
        XCTAssertEqual(loosened.minHeight, 0.0)
        XCTAssertEqual(loosened.maxHeight, 50.0)
    }

    // MARK: - getPositionForChild Tests

    /// Test that when toolbar fits at anchor, position equals anchor.
    func testGetPositionForChildFitsAtAnchor() {
        let anchor = Offset(100.0, 100.0)
        let delegate = DesktopTextSelectionToolbarLayoutDelegate(anchor: anchor)
        // Parent size 500x500, child size 100x50, anchor at (100, 100).
        // overhang.dx = 100 + 100 - 500 = -300 (no overflow)
        // overhang.dy = 100 + 50 - 500 = -350 (no overflow)
        let position = delegate.getPositionForChild(Size(500.0, 500.0), Size(100.0, 50.0))
        XCTAssertEqual(position.dx, 100.0)
        XCTAssertEqual(position.dy, 100.0)
    }

    /// Test that when child extends past right edge, dx shifts left.
    func testGetPositionForChildOverflowRight() {
        let anchor = Offset(450.0, 100.0)
        let delegate = DesktopTextSelectionToolbarLayoutDelegate(anchor: anchor)
        // Parent size 500x500, child size 100x50, anchor at (450, 100).
        // overhang.dx = 450 + 100 - 500 = 50 (overflow)
        // overhang.dy = 100 + 50 - 500 = -350 (no overflow)
        // result.dx = 450 - 50 = 400
        // result.dy = 100
        let position = delegate.getPositionForChild(Size(500.0, 500.0), Size(100.0, 50.0))
        XCTAssertEqual(position.dx, 400.0)
        XCTAssertEqual(position.dy, 100.0)
    }

    /// Test that when child extends past bottom edge, dy shifts up.
    func testGetPositionForChildOverflowBottom() {
        let anchor = Offset(100.0, 470.0)
        let delegate = DesktopTextSelectionToolbarLayoutDelegate(anchor: anchor)
        // Parent size 500x500, child size 100x50, anchor at (100, 470).
        // overhang.dx = 100 + 100 - 500 = -300 (no overflow)
        // overhang.dy = 470 + 50 - 500 = 20 (overflow)
        // result.dx = 100
        // result.dy = 470 - 20 = 450
        let position = delegate.getPositionForChild(Size(500.0, 500.0), Size(100.0, 50.0))
        XCTAssertEqual(position.dx, 100.0)
        XCTAssertEqual(position.dy, 450.0)
    }

    /// Test that both dx and dy are adjusted when overflow in both directions.
    func testGetPositionForChildOverflowBoth() {
        let anchor = Offset(450.0, 470.0)
        let delegate = DesktopTextSelectionToolbarLayoutDelegate(anchor: anchor)
        // Parent size 500x500, child size 100x50, anchor at (450, 470).
        // overhang.dx = 450 + 100 - 500 = 50 (overflow)
        // overhang.dy = 470 + 50 - 500 = 20 (overflow)
        // result.dx = 450 - 50 = 400
        // result.dy = 470 - 20 = 450
        let position = delegate.getPositionForChild(Size(500.0, 500.0), Size(100.0, 50.0))
        XCTAssertEqual(position.dx, 400.0)
        XCTAssertEqual(position.dy, 450.0)
    }

    /// Test no overflow when anchor at top-left corner with small child.
    func testGetPositionForChildNoOverflowTopLeft() {
        let anchor = Offset(0.0, 0.0)
        let delegate = DesktopTextSelectionToolbarLayoutDelegate(anchor: anchor)
        // Parent size 500x500, child size 50x30, anchor at (0, 0).
        // overhang.dx = 0 + 50 - 500 = -450 (no overflow)
        // overhang.dy = 0 + 30 - 500 = -470 (no overflow)
        let position = delegate.getPositionForChild(Size(500.0, 500.0), Size(50.0, 30.0))
        XCTAssertEqual(position.dx, 0.0)
        XCTAssertEqual(position.dy, 0.0)
    }

    /// Test exact fit: child exactly fills from anchor to edge.
    func testGetPositionForChildExactFit() {
        let anchor = Offset(400.0, 450.0)
        let delegate = DesktopTextSelectionToolbarLayoutDelegate(anchor: anchor)
        // Parent size 500x500, child size 100x50, anchor at (400, 450).
        // overhang.dx = 400 + 100 - 500 = 0 (exactly 0, no overflow)
        // overhang.dy = 450 + 50 - 500 = 0 (exactly 0, no overflow)
        let position = delegate.getPositionForChild(Size(500.0, 500.0), Size(100.0, 50.0))
        XCTAssertEqual(position.dx, 400.0)
        XCTAssertEqual(position.dy, 450.0)
    }

    // MARK: - shouldRelayout Tests

    /// Test that shouldRelayout returns false when anchor is the same.
    func testShouldRelayoutSameAnchorReturnsFalse() {
        let delegate1 = DesktopTextSelectionToolbarLayoutDelegate(anchor: Offset(100.0, 200.0))
        let delegate2 = DesktopTextSelectionToolbarLayoutDelegate(anchor: Offset(100.0, 200.0))
        XCTAssertFalse(delegate1.shouldRelayout(delegate2))
    }

    /// Test that shouldRelayout returns true when anchor is different.
    func testShouldRelayoutDifferentAnchorReturnsTrue() {
        let delegate1 = DesktopTextSelectionToolbarLayoutDelegate(anchor: Offset(100.0, 200.0))
        let delegate2 = DesktopTextSelectionToolbarLayoutDelegate(anchor: Offset(150.0, 250.0))
        XCTAssertTrue(delegate1.shouldRelayout(delegate2))
    }

    /// Test that shouldRelayout returns true when passed a different delegate type.
    func testShouldRelayoutDifferentDelegateTypeReturnsTrue() {
        let delegate = DesktopTextSelectionToolbarLayoutDelegate(anchor: Offset(100.0, 200.0))
        let otherDelegate = MockSingleChildLayoutDelegate()
        XCTAssertTrue(delegate.shouldRelayout(otherDelegate))
    }
}

// MARK: - Mock Helper

/// A minimal SingleChildLayoutDelegate subclass for testing shouldRelayout
/// with a different delegate type.
private class MockSingleChildLayoutDelegate: SingleChildLayoutDelegate {
    override func shouldRelayout(_ oldDelegate: SingleChildLayoutDelegate) -> Bool {
        return false
    }
}

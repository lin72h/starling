// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import FlutterSwiftBridge
@testable import Flutter

/// Tests for `_DragBoundaryDelegateForRect` and `DragBoundary`.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/drag_boundary_test.dart`
final class DragBoundaryTests: XCTestCase {

    // MARK: - Nil boundary: isWithinBoundary

    func testNilBoundaryIsWithinBoundaryAlwaysReturnsTrue() {
        let delegate = _DragBoundaryDelegateForRect(nil)
        let rect = Rect.fromLTWH(100, 200, 50, 50)
        XCTAssertTrue(delegate.isWithinBoundary(rect))
    }

    // MARK: - Nil boundary: nearestPositionWithinBoundary

    func testNilBoundaryNearestPositionReturnsSameRect() {
        let delegate = _DragBoundaryDelegateForRect(nil)
        let rect = Rect.fromLTWH(100, 200, 50, 50)
        let result = delegate.nearestPositionWithinBoundary(rect)
        XCTAssertEqual(result, rect)
    }

    // MARK: - isWithinBoundary with boundary

    func testIsWithinBoundaryInsideReturnsTrue() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(10, 10, 50, 50)
        XCTAssertTrue(delegate.isWithinBoundary(rect))
    }

    func testIsWithinBoundaryOutsideLeftReturnsFalse() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(-10, 10, 50, 50)
        XCTAssertFalse(delegate.isWithinBoundary(rect))
    }

    func testIsWithinBoundaryOutsideRightReturnsFalse() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(160, 10, 50, 50)
        XCTAssertFalse(delegate.isWithinBoundary(rect))
    }

    func testIsWithinBoundaryOutsideTopReturnsFalse() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(10, -10, 50, 50)
        XCTAssertFalse(delegate.isWithinBoundary(rect))
    }

    func testIsWithinBoundaryOutsideBottomReturnsFalse() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(10, 160, 50, 50)
        XCTAssertFalse(delegate.isWithinBoundary(rect))
    }

    func testIsWithinBoundaryExactFitReturnsFalse() {
        // Rect.contains uses strict < for right/bottom edges, so bottomRight
        // at (200,200) is not contained by a boundary whose right/bottom is 200.
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(0, 0, 200, 200)
        XCTAssertFalse(delegate.isWithinBoundary(rect))
    }

    func testIsWithinBoundaryCompletelyOutsideReturnsFalse() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(300, 300, 50, 50)
        XCTAssertFalse(delegate.isWithinBoundary(rect))
    }

    // MARK: - nearestPositionWithinBoundary with boundary

    func testNearestPositionAlreadyInsideReturnsSameRect() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(10, 10, 50, 50)
        let result = delegate.nearestPositionWithinBoundary(rect)
        XCTAssertEqual(result, rect)
    }

    func testNearestPositionClampsFromLeft() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(-20, 10, 50, 50)
        let result = delegate.nearestPositionWithinBoundary(rect)
        XCTAssertEqual(result, Rect.fromLTWH(0, 10, 50, 50))
    }

    func testNearestPositionClampsFromRight() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(180, 10, 50, 50)
        let result = delegate.nearestPositionWithinBoundary(rect)
        XCTAssertEqual(result, Rect.fromLTWH(150, 10, 50, 50))
    }

    func testNearestPositionClampsFromTop() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(10, -30, 50, 50)
        let result = delegate.nearestPositionWithinBoundary(rect)
        XCTAssertEqual(result, Rect.fromLTWH(10, 0, 50, 50))
    }

    func testNearestPositionClampsFromBottom() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(10, 180, 50, 50)
        let result = delegate.nearestPositionWithinBoundary(rect)
        XCTAssertEqual(result, Rect.fromLTWH(10, 150, 50, 50))
    }

    func testNearestPositionClampsCorner() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(-20, -30, 50, 50)
        let result = delegate.nearestPositionWithinBoundary(rect)
        XCTAssertEqual(result, Rect.fromLTWH(0, 0, 50, 50))
    }

    func testNearestPositionPreservesSize() {
        let boundary = Rect.fromLTWH(0, 0, 200, 200)
        let delegate = _DragBoundaryDelegateForRect(boundary)
        let rect = Rect.fromLTWH(-20, -30, 80, 60)
        let result = delegate.nearestPositionWithinBoundary(rect)
        XCTAssertEqual(result.width, 80)
        XCTAssertEqual(result.height, 60)
    }

    // MARK: - DragBoundary.updateShouldNotify

    func testUpdateShouldNotifyAlwaysReturnsTrue() {
        let child = _DummyWidget()
        let dragBoundary = DragBoundary(child: child)
        let oldDragBoundary = DragBoundary(child: child)
        XCTAssertTrue(dragBoundary.updateShouldNotify(oldDragBoundary))
    }
}

/// A minimal dummy widget for testing.
private class _DummyWidget: Widget {
    init() {
        super.init()
    }
}

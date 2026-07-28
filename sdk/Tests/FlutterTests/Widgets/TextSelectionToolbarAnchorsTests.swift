// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import FlutterSwiftBridge
@testable import Flutter

/// Tests for TextSelectionToolbarAnchors struct.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/text_selection_toolbar_anchors_test.dart`
final class TextSelectionToolbarAnchorsTests: XCTestCase {

    // MARK: - Construction with primaryAnchor only

    func testConstructionWithPrimaryAnchorOnly() {
        let anchors = TextSelectionToolbarAnchors(primaryAnchor: Offset(10.0, 20.0))
        XCTAssertEqual(anchors.primaryAnchor, Offset(10.0, 20.0))
        XCTAssertNil(anchors.secondaryAnchor)
    }

    func testConstructionWithPrimaryAnchorZero() {
        let anchors = TextSelectionToolbarAnchors(primaryAnchor: Offset.zero)
        XCTAssertEqual(anchors.primaryAnchor, Offset.zero)
        XCTAssertNil(anchors.secondaryAnchor)
    }

    // MARK: - Construction with both anchors

    func testConstructionWithBothAnchors() {
        let anchors = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(10.0, 20.0),
            secondaryAnchor: Offset(30.0, 40.0)
        )
        XCTAssertEqual(anchors.primaryAnchor, Offset(10.0, 20.0))
        XCTAssertEqual(anchors.secondaryAnchor, Offset(30.0, 40.0))
    }

    func testConstructionWithExplicitNilSecondaryAnchor() {
        let anchors = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(5.0, 15.0),
            secondaryAnchor: nil
        )
        XCTAssertNil(anchors.secondaryAnchor)
    }

    // MARK: - Property Access

    func testPrimaryAnchorPropertyAccess() {
        let offset = Offset(100.5, 200.75)
        let anchors = TextSelectionToolbarAnchors(primaryAnchor: offset)
        XCTAssertEqual(anchors.primaryAnchor.dx, 100.5)
        XCTAssertEqual(anchors.primaryAnchor.dy, 200.75)
    }

    func testSecondaryAnchorPropertyAccess() {
        let offset = Offset(50.0, 60.0)
        let anchors = TextSelectionToolbarAnchors(
            primaryAnchor: Offset.zero,
            secondaryAnchor: offset
        )
        XCTAssertEqual(anchors.secondaryAnchor?.dx, 50.0)
        XCTAssertEqual(anchors.secondaryAnchor?.dy, 60.0)
    }

    // MARK: - Equatable: Equal Instances

    func testEqualInstancesWithSamePrimaryAnchor() {
        let a = TextSelectionToolbarAnchors(primaryAnchor: Offset(10.0, 20.0))
        let b = TextSelectionToolbarAnchors(primaryAnchor: Offset(10.0, 20.0))
        XCTAssertEqual(a, b)
    }

    func testEqualInstancesWithBothAnchors() {
        let a = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(10.0, 20.0),
            secondaryAnchor: Offset(30.0, 40.0)
        )
        let b = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(10.0, 20.0),
            secondaryAnchor: Offset(30.0, 40.0)
        )
        XCTAssertEqual(a, b)
    }

    func testEqualInstancesBothNilSecondaryAnchor() {
        let a = TextSelectionToolbarAnchors(primaryAnchor: Offset(5.0, 5.0))
        let b = TextSelectionToolbarAnchors(primaryAnchor: Offset(5.0, 5.0))
        XCTAssertEqual(a, b)
    }

    // MARK: - Equatable: Different primaryAnchor

    func testNotEqualDifferentPrimaryAnchorDx() {
        let a = TextSelectionToolbarAnchors(primaryAnchor: Offset(10.0, 20.0))
        let b = TextSelectionToolbarAnchors(primaryAnchor: Offset(99.0, 20.0))
        XCTAssertNotEqual(a, b)
    }

    func testNotEqualDifferentPrimaryAnchorDy() {
        let a = TextSelectionToolbarAnchors(primaryAnchor: Offset(10.0, 20.0))
        let b = TextSelectionToolbarAnchors(primaryAnchor: Offset(10.0, 99.0))
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Equatable: Different secondaryAnchor

    func testNotEqualNilVsNonNilSecondaryAnchor() {
        let a = TextSelectionToolbarAnchors(primaryAnchor: Offset(10.0, 20.0))
        let b = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(10.0, 20.0),
            secondaryAnchor: Offset(30.0, 40.0)
        )
        XCTAssertNotEqual(a, b)
    }

    func testNotEqualDifferentSecondaryAnchorValues() {
        let a = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(10.0, 20.0),
            secondaryAnchor: Offset(30.0, 40.0)
        )
        let b = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(10.0, 20.0),
            secondaryAnchor: Offset(50.0, 60.0)
        )
        XCTAssertNotEqual(a, b)
    }

    func testNotEqualNonNilVsNilSecondaryAnchor() {
        let a = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(10.0, 20.0),
            secondaryAnchor: Offset(30.0, 40.0)
        )
        let b = TextSelectionToolbarAnchors(primaryAnchor: Offset(10.0, 20.0))
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Sendable Conformance

    func testSendableConformance() {
        let anchors = TextSelectionToolbarAnchors(primaryAnchor: Offset(1.0, 2.0))
        let _: any Sendable = anchors
        XCTAssertTrue(true) // Compiles = passes
    }

    func testSendableInAsyncContext() {
        let expectation = expectation(description: "async context")
        Task {
            let anchors = TextSelectionToolbarAnchors(
                primaryAnchor: Offset(10.0, 20.0),
                secondaryAnchor: Offset(30.0, 40.0)
            )
            XCTAssertEqual(anchors.primaryAnchor, Offset(10.0, 20.0))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Edge Cases

    func testConstructionWithNegativeOffsets() {
        let anchors = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(-10.0, -20.0),
            secondaryAnchor: Offset(-30.0, -40.0)
        )
        XCTAssertEqual(anchors.primaryAnchor, Offset(-10.0, -20.0))
        XCTAssertEqual(anchors.secondaryAnchor, Offset(-30.0, -40.0))
    }

    func testConstructionWithLargeOffsets() {
        let anchors = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(1e10, 1e10)
        )
        XCTAssertEqual(anchors.primaryAnchor, Offset(1e10, 1e10))
    }

    func testEqualityIsSymmetric() {
        let a = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(10.0, 20.0),
            secondaryAnchor: Offset(30.0, 40.0)
        )
        let b = TextSelectionToolbarAnchors(
            primaryAnchor: Offset(10.0, 20.0),
            secondaryAnchor: Offset(30.0, 40.0)
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(b, a)
    }
}

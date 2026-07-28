// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for basic_types.dart painting types
///
/// **Dart Source:** `packages/flutter/lib/src/painting/basic_types.dart`
///
/// NOTE: No dedicated test file exists at `packages/flutter/test/painting/basic_types_test.dart`
/// These tests are created to verify correct migration of the types.
final class BasicTypesTests: XCTestCase {

    // MARK: - RenderComparison Tests

    /// Test RenderComparison raw values match expected order
    func testRenderComparisonRawValues() {
        XCTAssertEqual(RenderComparison.identical.rawValue, 0)
        XCTAssertEqual(RenderComparison.metadata.rawValue, 1)
        XCTAssertEqual(RenderComparison.paint.rawValue, 2)
        XCTAssertEqual(RenderComparison.layout.rawValue, 3)
    }

    /// Test RenderComparison Comparable behavior
    func testRenderComparisonComparable() {
        // Values should be ordered by cost
        XCTAssertTrue(RenderComparison.identical < RenderComparison.metadata)
        XCTAssertTrue(RenderComparison.metadata < RenderComparison.paint)
        XCTAssertTrue(RenderComparison.paint < RenderComparison.layout)

        // Transitive comparisons
        XCTAssertTrue(RenderComparison.identical < RenderComparison.layout)
        XCTAssertTrue(RenderComparison.metadata < RenderComparison.layout)

        // Equal values should not be less than each other
        XCTAssertFalse(RenderComparison.identical < RenderComparison.identical)
        XCTAssertFalse(RenderComparison.layout < RenderComparison.layout)

        // Reverse comparisons
        XCTAssertFalse(RenderComparison.layout < RenderComparison.identical)
        XCTAssertFalse(RenderComparison.paint < RenderComparison.metadata)
    }

    /// Test RenderComparison Hashable conformance
    func testRenderComparisonHashable() {
        let set: Set<RenderComparison> = [.identical, .metadata, .paint, .layout]
        XCTAssertEqual(set.count, 4)
        XCTAssertTrue(set.contains(.identical))
        XCTAssertTrue(set.contains(.metadata))
        XCTAssertTrue(set.contains(.paint))
        XCTAssertTrue(set.contains(.layout))
    }

    // MARK: - Axis Tests

    /// Test Axis enum cases
    func testAxisCases() {
        let horizontal = Axis.horizontal
        let vertical = Axis.vertical

        XCTAssertNotEqual(horizontal, vertical)
        XCTAssertEqual(horizontal, .horizontal)
        XCTAssertEqual(vertical, .vertical)
    }

    /// Test flipAxis returns the opposite axis
    func testFlipAxis() {
        XCTAssertEqual(flipAxis(.horizontal), .vertical)
        XCTAssertEqual(flipAxis(.vertical), .horizontal)

        // Double flip should return original
        XCTAssertEqual(flipAxis(flipAxis(.horizontal)), .horizontal)
        XCTAssertEqual(flipAxis(flipAxis(.vertical)), .vertical)
    }

    /// Test Axis Hashable conformance
    func testAxisHashable() {
        let set: Set<Axis> = [.horizontal, .vertical]
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(.horizontal))
        XCTAssertTrue(set.contains(.vertical))
    }

    // MARK: - VerticalDirection Tests

    /// Test VerticalDirection enum cases
    func testVerticalDirectionCases() {
        let up = VerticalDirection.up
        let down = VerticalDirection.down

        XCTAssertNotEqual(up, down)
        XCTAssertEqual(up, .up)
        XCTAssertEqual(down, .down)
    }

    /// Test VerticalDirection Hashable conformance
    func testVerticalDirectionHashable() {
        let set: Set<VerticalDirection> = [.up, .down]
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(.up))
        XCTAssertTrue(set.contains(.down))
    }

    // MARK: - AxisDirection Tests

    /// Test AxisDirection enum cases
    func testAxisDirectionCases() {
        let up = AxisDirection.up
        let right = AxisDirection.right
        let down = AxisDirection.down
        let left = AxisDirection.left

        // All cases should be distinct
        XCTAssertNotEqual(up, right)
        XCTAssertNotEqual(up, down)
        XCTAssertNotEqual(up, left)
        XCTAssertNotEqual(right, down)
        XCTAssertNotEqual(right, left)
        XCTAssertNotEqual(down, left)
    }

    /// Test axisDirectionToAxis conversion
    func testAxisDirectionToAxis() {
        // Vertical axis directions
        XCTAssertEqual(axisDirectionToAxis(.up), .vertical)
        XCTAssertEqual(axisDirectionToAxis(.down), .vertical)

        // Horizontal axis directions
        XCTAssertEqual(axisDirectionToAxis(.left), .horizontal)
        XCTAssertEqual(axisDirectionToAxis(.right), .horizontal)
    }

    /// Test textDirectionToAxisDirection conversion
    func testTextDirectionToAxisDirection() {
        XCTAssertEqual(textDirectionToAxisDirection(.ltr), .right)
        XCTAssertEqual(textDirectionToAxisDirection(.rtl), .left)
    }

    /// Test flipAxisDirection returns the opposite direction
    func testFlipAxisDirection() {
        XCTAssertEqual(flipAxisDirection(.up), .down)
        XCTAssertEqual(flipAxisDirection(.down), .up)
        XCTAssertEqual(flipAxisDirection(.left), .right)
        XCTAssertEqual(flipAxisDirection(.right), .left)

        // Double flip should return original
        XCTAssertEqual(flipAxisDirection(flipAxisDirection(.up)), .up)
        XCTAssertEqual(flipAxisDirection(flipAxisDirection(.down)), .down)
        XCTAssertEqual(flipAxisDirection(flipAxisDirection(.left)), .left)
        XCTAssertEqual(flipAxisDirection(flipAxisDirection(.right)), .right)
    }

    /// Test axisDirectionIsReversed
    func testAxisDirectionIsReversed() {
        // Reversed directions (numerically decreasing)
        XCTAssertTrue(axisDirectionIsReversed(.up))
        XCTAssertTrue(axisDirectionIsReversed(.left))

        // Non-reversed directions (numerically increasing)
        XCTAssertFalse(axisDirectionIsReversed(.down))
        XCTAssertFalse(axisDirectionIsReversed(.right))
    }

    /// Test AxisDirection Hashable conformance
    func testAxisDirectionHashable() {
        let set: Set<AxisDirection> = [.up, .right, .down, .left]
        XCTAssertEqual(set.count, 4)
        XCTAssertTrue(set.contains(.up))
        XCTAssertTrue(set.contains(.right))
        XCTAssertTrue(set.contains(.down))
        XCTAssertTrue(set.contains(.left))
    }

    // MARK: - Integration Tests

    /// Test relationship between flipAxisDirection and axisDirectionToAxis
    func testFlipAxisDirectionPreservesAxis() {
        // Flipping should preserve the axis
        XCTAssertEqual(axisDirectionToAxis(flipAxisDirection(.up)), axisDirectionToAxis(.up))
        XCTAssertEqual(axisDirectionToAxis(flipAxisDirection(.down)), axisDirectionToAxis(.down))
        XCTAssertEqual(axisDirectionToAxis(flipAxisDirection(.left)), axisDirectionToAxis(.left))
        XCTAssertEqual(axisDirectionToAxis(flipAxisDirection(.right)), axisDirectionToAxis(.right))
    }

    /// Test relationship between flipAxisDirection and axisDirectionIsReversed
    func testFlipAxisDirectionTogglesReversed() {
        // Flipping should toggle the reversed status
        XCTAssertEqual(axisDirectionIsReversed(flipAxisDirection(.up)), !axisDirectionIsReversed(.up))
        XCTAssertEqual(axisDirectionIsReversed(flipAxisDirection(.down)), !axisDirectionIsReversed(.down))
        XCTAssertEqual(axisDirectionIsReversed(flipAxisDirection(.left)), !axisDirectionIsReversed(.left))
        XCTAssertEqual(axisDirectionIsReversed(flipAxisDirection(.right)), !axisDirectionIsReversed(.right))
    }

    /// Test TextDirection to Axis mapping
    func testTextDirectionToAxis() {
        // TextDirection always maps to horizontal axis
        XCTAssertEqual(axisDirectionToAxis(textDirectionToAxisDirection(.ltr)), .horizontal)
        XCTAssertEqual(axisDirectionToAxis(textDirectionToAxisDirection(.rtl)), .horizontal)
    }
}

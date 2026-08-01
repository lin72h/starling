// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for RenderRotatedBox from the Rendering layer.
///
/// **Dart Test Source:** `packages/flutter/test/rendering/rotated_box_test.dart`
///
/// These tests cover:
///   - Construction with various quarterTurns values
///   - Property setter triggering markNeedsLayout
///   - _isVertical behavior (private, tested indirectly via intrinsics/layout)
///   - Intrinsic dimension swapping for vertical (1, 3) vs horizontal (0, 2) rotations
///   - computeDryLayout size behavior
///   - performLayout size behavior
///   - dispose clearing the transform layer
///   - No-child fallback to constraints.smallest

import XCTest
@testable import Flutter
import FlutterSwiftBridge

// MARK: - Test Helpers

/// A concrete RenderBox subclass with configurable intrinsic dimensions
/// and a fixed size for layout, used as a child of RenderRotatedBox in tests.
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

// MARK: - RenderRotatedBox Construction Tests

final class RenderRotatedBoxConstructionTests: XCTestCase {

    /// Test that RenderRotatedBox can be constructed with quarterTurns = 0.
    ///
    /// **Dart Source:** `rotated_box.dart:26-28`
    func testConstructionWithZeroQuarterTurns() {
        let box = RenderRotatedBox(quarterTurns: 0)
        XCTAssertEqual(box.quarterTurns, 0)
        XCTAssertNil(box.child)
    }

    /// Test that RenderRotatedBox can be constructed with quarterTurns = 1.
    func testConstructionWithOneQuarterTurn() {
        let box = RenderRotatedBox(quarterTurns: 1)
        XCTAssertEqual(box.quarterTurns, 1)
    }

    /// Test that RenderRotatedBox can be constructed with quarterTurns = 2.
    func testConstructionWithTwoQuarterTurns() {
        let box = RenderRotatedBox(quarterTurns: 2)
        XCTAssertEqual(box.quarterTurns, 2)
    }

    /// Test that RenderRotatedBox can be constructed with quarterTurns = 3.
    func testConstructionWithThreeQuarterTurns() {
        let box = RenderRotatedBox(quarterTurns: 3)
        XCTAssertEqual(box.quarterTurns, 3)
    }

    /// Test that RenderRotatedBox can be constructed with a child.
    func testConstructionWithChild() {
        let child = RenderBox()
        let box = RenderRotatedBox(quarterTurns: 1, child: child)
        XCTAssertEqual(box.quarterTurns, 1)
        XCTAssertNotNil(box.child)
        XCTAssertTrue(box.child === child)
    }

    /// Test that RenderRotatedBox can be constructed with negative quarterTurns.
    /// The modulo operation in _isVertical handles this correctly.
    func testConstructionWithNegativeQuarterTurns() {
        let box = RenderRotatedBox(quarterTurns: -1)
        XCTAssertEqual(box.quarterTurns, -1)
    }

    /// Test that RenderRotatedBox can be constructed with large quarterTurns values.
    func testConstructionWithLargeQuarterTurns() {
        let box = RenderRotatedBox(quarterTurns: 100)
        XCTAssertEqual(box.quarterTurns, 100)
    }
}

// MARK: - RenderRotatedBox quarterTurns Setter Tests

final class RenderRotatedBoxQuarterTurnsSetterTests: XCTestCase {

    /// Test that setting quarterTurns to a different value triggers markNeedsLayout.
    ///
    /// **Dart Source:** `rotated_box.dart:31-39`
    func testQuarterTurnsSetterTriggersLayout() {
        let box = RenderRotatedBox(quarterTurns: 0)
        box.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        XCTAssertFalse(box.needsLayout)

        box.quarterTurns = 1
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.quarterTurns, 1)
    }

    /// Test that setting quarterTurns to the same value does NOT trigger layout.
    ///
    /// **Dart Source:** `rotated_box.dart:33-35` - early return on equal
    func testQuarterTurnsSetterNoOpOnSameValue() {
        let box = RenderRotatedBox(quarterTurns: 2)
        box.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        XCTAssertFalse(box.needsLayout)

        box.quarterTurns = 2
        XCTAssertFalse(box.needsLayout)
    }

    /// Test that setting quarterTurns multiple times works correctly.
    func testQuarterTurnsSetterMultipleTimes() {
        let box = RenderRotatedBox(quarterTurns: 0)
        box.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )

        box.quarterTurns = 1
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.quarterTurns, 1)

        // Re-layout to clear the flag
        box.layout(
            BoxConstraints(minWidth: 0, maxWidth: 100, minHeight: 0, maxHeight: 100)
        )
        XCTAssertFalse(box.needsLayout)

        box.quarterTurns = 3
        XCTAssertTrue(box.needsLayout)
        XCTAssertEqual(box.quarterTurns, 3)
    }
}

// MARK: - RenderRotatedBox _isVertical Tests (Indirect)

/// Tests for the private `_isVertical` property, verified indirectly through
/// intrinsic dimension behavior and layout results.
///
/// _isVertical returns true for odd quarterTurns (1, 3) and false for
/// even quarterTurns (0, 2).
final class RenderRotatedBoxIsVerticalTests: XCTestCase {

    /// Test that quarterTurns=0 is NOT vertical (intrinsics don't swap).
    ///
    /// **Dart Source:** `rotated_box.dart:41` - `quarterTurns % 2 != 0`
    func testIsVerticalFalseForZero() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 0, child: child)

        // For non-vertical (0), minIntrinsicWidth should delegate to child's minIntrinsicWidth
        let width = box.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(width, 100.0, "quarterTurns=0 should not swap: width should be child's width")
    }

    /// Test that quarterTurns=1 IS vertical (intrinsics swap).
    func testIsVerticalTrueForOne() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)

        // For vertical (1), minIntrinsicWidth should delegate to child's minIntrinsicHeight
        let width = box.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(width, 50.0, "quarterTurns=1 should swap: width should be child's height")
    }

    /// Test that quarterTurns=2 is NOT vertical (intrinsics don't swap).
    func testIsVerticalFalseForTwo() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 2, child: child)

        let width = box.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(width, 100.0, "quarterTurns=2 should not swap: width should be child's width")
    }

    /// Test that quarterTurns=3 IS vertical (intrinsics swap).
    func testIsVerticalTrueForThree() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 3, child: child)

        let width = box.computeMinIntrinsicWidth(.infinity)
        XCTAssertEqual(width, 50.0, "quarterTurns=3 should swap: width should be child's height")
    }
}

// MARK: - RenderRotatedBox Intrinsic Dimension Tests

final class RenderRotatedBoxIntrinsicTests: XCTestCase {

    // MARK: - Vertical Rotations (1, 3 quarter turns swap width/height)

    /// Test that computeMinIntrinsicWidth swaps to child's minIntrinsicHeight for 1 quarter turn.
    ///
    /// **Dart Source:** `rotated_box.dart:44-49`
    func testMinIntrinsicWidthSwapsForOneQuarterTurn() {
        let child = FixedSizeRenderBox(width: 200, height: 80)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)

        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 80.0)
    }

    /// Test that computeMaxIntrinsicWidth swaps to child's maxIntrinsicHeight for 1 quarter turn.
    ///
    /// **Dart Source:** `rotated_box.dart:52-57`
    func testMaxIntrinsicWidthSwapsForOneQuarterTurn() {
        let child = FixedSizeRenderBox(width: 200, height: 80)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)

        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 80.0)
    }

    /// Test that computeMinIntrinsicHeight swaps to child's minIntrinsicWidth for 1 quarter turn.
    ///
    /// **Dart Source:** `rotated_box.dart:60-65`
    func testMinIntrinsicHeightSwapsForOneQuarterTurn() {
        let child = FixedSizeRenderBox(width: 200, height: 80)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)

        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 200.0)
    }

    /// Test that computeMaxIntrinsicHeight swaps to child's maxIntrinsicWidth for 1 quarter turn.
    ///
    /// **Dart Source:** `rotated_box.dart:68-73`
    func testMaxIntrinsicHeightSwapsForOneQuarterTurn() {
        let child = FixedSizeRenderBox(width: 200, height: 80)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)

        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 200.0)
    }

    /// Test that all intrinsics swap correctly for 3 quarter turns.
    func testIntrinsicsSwapForThreeQuarterTurns() {
        let child = FixedSizeRenderBox(width: 150, height: 60)
        let box = RenderRotatedBox(quarterTurns: 3, child: child)

        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 60.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 60.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 150.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 150.0)
    }

    // MARK: - Horizontal Rotations (0, 2 quarter turns don't swap)

    /// Test that intrinsics don't swap for 0 quarter turns.
    ///
    /// **Dart Source:** `rotated_box.dart:44-73` - non-vertical case
    func testIntrinsicsDontSwapForZeroQuarterTurns() {
        let child = FixedSizeRenderBox(width: 200, height: 80)
        let box = RenderRotatedBox(quarterTurns: 0, child: child)

        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 200.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 200.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 80.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 80.0)
    }

    /// Test that intrinsics don't swap for 2 quarter turns.
    func testIntrinsicsDontSwapForTwoQuarterTurns() {
        let child = FixedSizeRenderBox(width: 200, height: 80)
        let box = RenderRotatedBox(quarterTurns: 2, child: child)

        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 200.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 200.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 80.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 80.0)
    }

    // MARK: - No Child Intrinsics

    /// Test that intrinsics return 0.0 when there is no child.
    func testIntrinsicsReturnZeroWithNoChild() {
        let box = RenderRotatedBox(quarterTurns: 1)

        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 0.0)
    }

    /// Test intrinsics with no child for 0 quarter turns.
    func testIntrinsicsReturnZeroWithNoChildZeroTurns() {
        let box = RenderRotatedBox(quarterTurns: 0)

        XCTAssertEqual(box.computeMinIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicWidth(.infinity), 0.0)
        XCTAssertEqual(box.computeMinIntrinsicHeight(.infinity), 0.0)
        XCTAssertEqual(box.computeMaxIntrinsicHeight(.infinity), 0.0)
    }
}

// MARK: - RenderRotatedBox computeDryLayout Tests

final class RenderRotatedBoxDryLayoutTests: XCTestCase {

    /// Test that computeDryLayout with 0 quarter turns preserves the child size.
    ///
    /// **Dart Source:** `rotated_box.dart:79-85`
    func testDryLayoutZeroQuarterTurnsPreservesSize() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 0, child: child)
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        )

        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 100.0)
        XCTAssertEqual(size.height, 50.0)
    }

    /// Test that computeDryLayout with 1 quarter turn swaps width and height.
    ///
    /// **Dart Source:** `rotated_box.dart:79-85`
    func testDryLayoutOneQuarterTurnSwapsSize() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        )

        let size = box.computeDryLayout(constraints)
        // Child lays out as 50w x 100h (flipped constraints), then swaps to 100w x 50h... wait:
        // _isVertical = true, so constraints are flipped: minW=0,maxW=200,minH=0,maxH=200 -> flipped is same
        // Child gets flipped constraints and lays out to constrain(100, 50) = (100, 50)
        // Wait, flipped constraints swap width/height: (minH=0, maxH=200, minW=0, maxW=200) = same
        // Actually for this test the constraints are symmetric. Let me use asymmetric constraints.
        // But the child still returns (100, 50), and then it's swapped to (50, 100).
        XCTAssertEqual(size.width, 50.0)
        XCTAssertEqual(size.height, 100.0)
    }

    /// Test computeDryLayout with 2 quarter turns preserves size (not vertical).
    func testDryLayoutTwoQuarterTurnsPreservesSize() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 2, child: child)
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        )

        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 100.0)
        XCTAssertEqual(size.height, 50.0)
    }

    /// Test computeDryLayout with 3 quarter turns swaps size (vertical).
    func testDryLayoutThreeQuarterTurnsSwapsSize() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 3, child: child)
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        )

        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 50.0)
        XCTAssertEqual(size.height, 100.0)
    }

    /// Test computeDryLayout with asymmetric constraints and 1 quarter turn.
    /// Constraints are flipped before being passed to the child.
    func testDryLayoutOneQuarterTurnWithAsymmetricConstraints() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)
        // Constraints: width 0..120, height 0..80
        // Flipped for child: width 0..80, height 0..120
        // Child wants (100, 50) constrained to flipped => (80, 50)
        // Result swapped => (50, 80)
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 120,
            minHeight: 0, maxHeight: 80
        )

        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 50.0)
        XCTAssertEqual(size.height, 80.0)
    }

    /// Test computeDryLayout with no child returns constraints.smallest.
    ///
    /// **Dart Source:** `rotated_box.dart:80`
    func testDryLayoutNoChildReturnsSmallest() {
        let box = RenderRotatedBox(quarterTurns: 1)
        let constraints = BoxConstraints(
            minWidth: 10, maxWidth: 100,
            minHeight: 20, maxHeight: 200
        )

        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 10.0)
        XCTAssertEqual(size.height, 20.0)
    }

    /// Test computeDryLayout with no child and zero-min constraints.
    func testDryLayoutNoChildZeroMinConstraints() {
        let box = RenderRotatedBox(quarterTurns: 0)
        let constraints = BoxConstraints(
            minWidth: 0, maxWidth: 100,
            minHeight: 0, maxHeight: 100
        )

        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 0.0)
        XCTAssertEqual(size.height, 0.0)
    }

    /// Test computeDryLayout with tight constraints and no child.
    func testDryLayoutNoChildTightConstraints() {
        let box = RenderRotatedBox(quarterTurns: 2)
        let constraints = BoxConstraints.tight(Size(50.0, 75.0))

        let size = box.computeDryLayout(constraints)
        XCTAssertEqual(size.width, 50.0)
        XCTAssertEqual(size.height, 75.0)
    }
}

// MARK: - RenderRotatedBox performLayout Tests

final class RenderRotatedBoxPerformLayoutTests: XCTestCase {

    /// Test that performLayout sets correct size with 0 quarter turns.
    ///
    /// **Dart Source:** `rotated_box.dart:88-100`
    func testPerformLayoutZeroQuarterTurns() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 0, child: child)

        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        ))

        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 50.0)
    }

    /// Test that performLayout sets correct (swapped) size with 1 quarter turn.
    func testPerformLayoutOneQuarterTurn() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)

        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        ))

        XCTAssertEqual(box.size.width, 50.0)
        XCTAssertEqual(box.size.height, 100.0)
    }

    /// Test that performLayout sets correct size with 2 quarter turns.
    func testPerformLayoutTwoQuarterTurns() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 2, child: child)

        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        ))

        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 50.0)
    }

    /// Test that performLayout sets correct (swapped) size with 3 quarter turns.
    func testPerformLayoutThreeQuarterTurns() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 3, child: child)

        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        ))

        XCTAssertEqual(box.size.width, 50.0)
        XCTAssertEqual(box.size.height, 100.0)
    }

    /// Test that performLayout with no child returns constraints.smallest.
    ///
    /// **Dart Source:** `rotated_box.dart:96-97`
    func testPerformLayoutNoChild() {
        let box = RenderRotatedBox(quarterTurns: 1)

        box.layout(BoxConstraints(
            minWidth: 10, maxWidth: 100,
            minHeight: 20, maxHeight: 200
        ))

        XCTAssertEqual(box.size.width, 10.0)
        XCTAssertEqual(box.size.height, 20.0)
    }

    /// Test that performLayout with no child and zero-min constraints.
    func testPerformLayoutNoChildZeroMin() {
        let box = RenderRotatedBox(quarterTurns: 0)

        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 100,
            minHeight: 0, maxHeight: 100
        ))

        XCTAssertEqual(box.size.width, 0.0)
        XCTAssertEqual(box.size.height, 0.0)
    }

    /// Test that performLayout with loose constraints and a child works correctly.
    func testPerformLayoutLooseConstraints() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)

        // Loose constraints: 0..200 x 0..200
        // Flipped for child (vertical): still 0..200 x 0..200
        // Child constrained: 100x50
        // Swapped result: 50x100
        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 200.0,
            minHeight: 0, maxHeight: 200.0
        ))

        XCTAssertEqual(box.size.width, 50.0)
        XCTAssertEqual(box.size.height, 100.0)
    }

    /// Test that the child also gets laid out during performLayout.
    func testPerformLayoutChildIsLaidOut() {
        let child = FixedSizeRenderBox(width: 80, height: 40)
        let box = RenderRotatedBox(quarterTurns: 0, child: child)

        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        ))

        XCTAssertTrue(child.hasSize)
        XCTAssertEqual(child.size.width, 80.0)
        XCTAssertEqual(child.size.height, 40.0)
    }
}

// MARK: - RenderRotatedBox Dispose Tests

final class RenderRotatedBoxDisposeTests: XCTestCase {

    /// Test that dispose can be called without crashing.
    ///
    /// **Dart Source:** `rotated_box.dart:139-142`
    func testDisposeDoesNotCrash() {
        let box = RenderRotatedBox(quarterTurns: 0)
        // Should not crash
        box.dispose()
    }

    /// Test that dispose can be called on a box with a child.
    func testDisposeWithChild() {
        let child = FixedSizeRenderBox(width: 100, height: 50)
        let box = RenderRotatedBox(quarterTurns: 1, child: child)
        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        ))
        // Should not crash
        box.dispose()
    }

    /// Test that dispose can be called on a box without a child.
    func testDisposeWithoutChild() {
        let box = RenderRotatedBox(quarterTurns: 2)
        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 100,
            minHeight: 0, maxHeight: 100
        ))
        // Should not crash
        box.dispose()
    }
}

// MARK: - RenderRotatedBox No-Child Edge Cases

final class RenderRotatedBoxNoChildTests: XCTestCase {

    /// Test that no child with various quarter turns all return constraints.smallest
    /// from computeDryLayout.
    func testNoChildAllQuarterTurnsReturnSmallest() {
        let constraints = BoxConstraints(
            minWidth: 5, maxWidth: 50,
            minHeight: 10, maxHeight: 100
        )

        for turns in 0...3 {
            let box = RenderRotatedBox(quarterTurns: turns)
            let size = box.computeDryLayout(constraints)
            XCTAssertEqual(
                size.width, 5.0,
                "quarterTurns=\(turns) with no child should return constraints.smallest width"
            )
            XCTAssertEqual(
                size.height, 10.0,
                "quarterTurns=\(turns) with no child should return constraints.smallest height"
            )
        }
    }

    /// Test that no child with various quarter turns all return constraints.smallest
    /// from performLayout.
    func testNoChildPerformLayoutAllQuarterTurns() {
        let constraints = BoxConstraints(
            minWidth: 5, maxWidth: 50,
            minHeight: 10, maxHeight: 100
        )

        for turns in 0...3 {
            let box = RenderRotatedBox(quarterTurns: turns)
            box.layout(constraints)
            XCTAssertEqual(
                box.size.width, 5.0,
                "quarterTurns=\(turns) with no child should set size to constraints.smallest width"
            )
            XCTAssertEqual(
                box.size.height, 10.0,
                "quarterTurns=\(turns) with no child should set size to constraints.smallest height"
            )
        }
    }
}

// MARK: - RenderRotatedBox Child Management Tests

final class RenderRotatedBoxChildManagementTests: XCTestCase {

    /// Test that setting a child triggers markNeedsLayout.
    func testSettingChildTriggersLayout() {
        let box = RenderRotatedBox(quarterTurns: 0)
        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 100,
            minHeight: 0, maxHeight: 100
        ))
        XCTAssertFalse(box.needsLayout)

        box.child = FixedSizeRenderBox(width: 50, height: 50)
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that setting child to nil triggers markNeedsLayout.
    func testSettingChildToNilTriggersLayout() {
        let child = FixedSizeRenderBox(width: 50, height: 50)
        let box = RenderRotatedBox(quarterTurns: 0, child: child)
        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 100,
            minHeight: 0, maxHeight: 100
        ))
        XCTAssertFalse(box.needsLayout)

        box.child = nil
        XCTAssertTrue(box.needsLayout)
    }

    /// Test that replacing the child works correctly.
    func testReplacingChild() {
        let child1 = FixedSizeRenderBox(width: 100, height: 50)
        let child2 = FixedSizeRenderBox(width: 80, height: 40)
        let box = RenderRotatedBox(quarterTurns: 0, child: child1)

        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        ))
        XCTAssertEqual(box.size.width, 100.0)
        XCTAssertEqual(box.size.height, 50.0)

        box.child = child2
        box.layout(BoxConstraints(
            minWidth: 0, maxWidth: 200,
            minHeight: 0, maxHeight: 200
        ))
        XCTAssertEqual(box.size.width, 80.0)
        XCTAssertEqual(box.size.height, 40.0)
    }
}

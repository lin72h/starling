// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for LinearBorder and LinearBorderEdge.
///
/// **Dart Test Source:** `packages/flutter/test/painting/linear_border_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class LinearBorderTests: XCTestCase {

    // MARK: - LinearBorderEdge Tests

    /// **Dart Test:** `linear_border_test.dart:23-26` - "LinearBorderEdge defaults"
    func testLinearBorderEdgeDefaults() {
        let edge = LinearBorderEdge()
        XCTAssertEqual(edge.size, 1.0)
        XCTAssertEqual(edge.alignment, 0.0)
    }

    // MARK: - LinearBorder Defaults Tests

    /// **Dart Test:** `linear_border_test.dart:28-64` - "LinearBorder defaults"
    func testLinearBorderDefaults() {
        // Test LinearBorder.none
        let noneBorder = LinearBorder.none
        XCTAssertEqual(noneBorder.side, BorderSide.none)
        if let dims = noneBorder.dimensions as? EdgeInsetsDirectional {
            XCTAssertEqual(dims, EdgeInsetsDirectional.zero)
        }
        XCTAssertFalse(noneBorder.preferPaintInterior)
        XCTAssertNil(noneBorder.start)
        XCTAssertNil(noneBorder.end)
        XCTAssertNil(noneBorder.top)
        XCTAssertNil(noneBorder.bottom)
    }

    /// **Dart Test:** `linear_border_test.dart:41-45` - "LinearBorder.start() defaults"
    func testLinearBorderStartDefaults() {
        let border = LinearBorder.start()
        XCTAssertEqual(border.side, BorderSide.none)
        XCTAssertEqual(border.start, LinearBorderEdge())
        XCTAssertNil(border.end)
        XCTAssertNil(border.top)
        XCTAssertNil(border.bottom)
    }

    /// **Dart Test:** `linear_border_test.dart:47-51` - "LinearBorder.end() defaults"
    func testLinearBorderEndDefaults() {
        let border = LinearBorder.end()
        XCTAssertEqual(border.side, BorderSide.none)
        XCTAssertNil(border.start)
        XCTAssertEqual(border.end, LinearBorderEdge())
        XCTAssertNil(border.top)
        XCTAssertNil(border.bottom)
    }

    /// **Dart Test:** `linear_border_test.dart:53-57` - "LinearBorder.top() defaults"
    func testLinearBorderTopDefaults() {
        let border = LinearBorder.top()
        XCTAssertEqual(border.side, BorderSide.none)
        XCTAssertNil(border.start)
        XCTAssertNil(border.end)
        XCTAssertEqual(border.top, LinearBorderEdge())
        XCTAssertNil(border.bottom)
    }

    /// **Dart Test:** `linear_border_test.dart:59-63` - "LinearBorder.bottom() defaults"
    func testLinearBorderBottomDefaults() {
        let border = LinearBorder.bottom()
        XCTAssertEqual(border.side, BorderSide.none)
        XCTAssertNil(border.start)
        XCTAssertNil(border.end)
        XCTAssertNil(border.top)
        XCTAssertEqual(border.bottom, LinearBorderEdge())
    }

    // MARK: - copyWith, ==, hashCode Tests

    /// **Dart Test:** `linear_border_test.dart:66-71` - "LinearBorder copyWith, ==, hashCode"
    func testLinearBorderCopyWithEqualityHashCode() {
        // copyWith with no changes returns an equal border
        XCTAssertEqual(LinearBorder.none, LinearBorder.none.copyWith())
        XCTAssertEqual(LinearBorder.none.hashValue, LinearBorder.none.copyWith().hashValue)

        // copyWith with a new side
        let side = BorderSide(color: Color(0xff123456), width: 10.0)
        let borderWithSide: LinearBorder = LinearBorder.none.copyWith(side: side)
        let expectedBorder = LinearBorder(side: side)
        XCTAssertEqual(borderWithSide, expectedBorder)
    }

    // MARK: - Lerp Tests

    /// **Dart Test:** `linear_border_test.dart:73-77` - "LinearBorder lerp identical a,b"
    func testLinearBorderLerpIdentical() {
        // lerp(nil, nil, t) returns nil
        XCTAssertNil(OutlinedBorderStatics.lerp(nil, nil, 0))

        // lerp with identical borders
        let border = LinearBorder.none
        // We can't use Swift's `identical` for value types, but we test equality
        if let result = OutlinedBorderStatics.lerp(border, border, 0.5) as? LinearBorder {
            XCTAssertEqual(result, border)
        } else {
            XCTFail("lerp with identical borders should return LinearBorder")
        }
    }

    /// **Dart Test:** `linear_border_test.dart:79-83` - "LinearBorderEdge.lerp identical a,b"
    func testLinearBorderEdgeLerpIdentical() {
        // lerp(nil, nil, t) returns nil
        XCTAssertNil(LinearBorderEdge.lerp(nil, nil, 0))

        // lerp with equal edges returns the edge
        let edge = LinearBorderEdge()
        let result = LinearBorderEdge.lerp(edge, edge, 0.5)
        XCTAssertEqual(result, edge)
    }

    /// Test LinearBorderEdge lerp with nil values.
    func testLinearBorderEdgeLerpWithNil() {
        let edge = LinearBorderEdge(size: 0.8, alignment: 0.5)

        // lerp from nil to an edge: size goes from 0 to edge.size
        let fromNil = LinearBorderEdge.lerp(nil, edge, 0.5)
        XCTAssertNotNil(fromNil)
        XCTAssertEqual(fromNil!.size, 0.4, accuracy: 1e-10)
        XCTAssertEqual(fromNil!.alignment, 0.5, accuracy: 1e-10)

        // lerp from an edge to nil: size goes from edge.size to 0
        let toNil = LinearBorderEdge.lerp(edge, nil, 0.5)
        XCTAssertNotNil(toNil)
        XCTAssertEqual(toNil!.size, 0.4, accuracy: 1e-10)
        XCTAssertEqual(toNil!.alignment, 0.5, accuracy: 1e-10)
    }

    /// Test LinearBorderEdge lerp between two edges.
    func testLinearBorderEdgeLerpBetweenEdges() {
        let a = LinearBorderEdge(size: 0.2, alignment: -1.0)
        let b = LinearBorderEdge(size: 0.8, alignment: 1.0)

        let mid = LinearBorderEdge.lerp(a, b, 0.5)
        XCTAssertNotNil(mid)
        XCTAssertEqual(mid!.size, 0.5, accuracy: 1e-10)
        XCTAssertEqual(mid!.alignment, 0.0, accuracy: 1e-10)

        let atStart = LinearBorderEdge.lerp(a, b, 0.0)
        XCTAssertNotNil(atStart)
        XCTAssertEqual(atStart!.size, 0.2, accuracy: 1e-10)
        XCTAssertEqual(atStart!.alignment, -1.0, accuracy: 1e-10)

        let atEnd = LinearBorderEdge.lerp(a, b, 1.0)
        XCTAssertNotNil(atEnd)
        XCTAssertEqual(atEnd!.size, 0.8, accuracy: 1e-10)
        XCTAssertEqual(atEnd!.alignment, 1.0, accuracy: 1e-10)
    }

    // MARK: - LinearBorder Lerp Tests

    /// Test lerp between two LinearBorders.
    func testLinearBorderLerpBetweenBorders() {
        let a = LinearBorder(
            side: BorderSide(width: 2.0),
            start: LinearBorderEdge(size: 0.5),
            top: LinearBorderEdge(size: 0.3, alignment: -1.0)
        )
        let b = LinearBorder(
            side: BorderSide(width: 4.0),
            start: LinearBorderEdge(size: 1.0),
            top: LinearBorderEdge(size: 0.7, alignment: 1.0)
        )

        if let mid = ShapeBorderStatics.lerp(a, b, 0.5) as? LinearBorder {
            XCTAssertEqual(mid.side.width, 3.0, accuracy: 1e-10)
            XCTAssertNotNil(mid.start)
            XCTAssertEqual(mid.start!.size, 0.75, accuracy: 1e-10)
            XCTAssertNotNil(mid.top)
            XCTAssertEqual(mid.top!.size, 0.5, accuracy: 1e-10)
            XCTAssertEqual(mid.top!.alignment, 0.0, accuracy: 1e-10)
        } else {
            XCTFail("lerp should return LinearBorder")
        }
    }

    // MARK: - toString Tests

    /// **Dart Test:** `linear_border_test.dart:85-115` - "LinearBorderEdge, LinearBorder toString()"
    func testLinearBorderEdgeDescription() {
        let edge = LinearBorderEdge(size: 0.5, alignment: -0.5)
        XCTAssertEqual(
            edge.description,
            "LinearBorderEdge(size: 0.5, alignment: -0.5)"
        )
    }

    /// **Dart Test:** `linear_border_test.dart:92` - "LinearBorder.none toString"
    func testLinearBorderNoneDescription() {
        XCTAssertEqual(LinearBorder.none.description, "LinearBorder.none")
    }

    /// Test LinearBorderEdge description with defaults.
    func testLinearBorderEdgeDescriptionDefaults() {
        // Default edge (size 1.0, alignment 0.0) should have empty parentheses
        let edge = LinearBorderEdge()
        XCTAssertEqual(edge.description, "LinearBorderEdge()")
    }

    /// Test LinearBorderEdge description with only size non-default.
    func testLinearBorderEdgeDescriptionSizeOnly() {
        let edge = LinearBorderEdge(size: 0.5)
        XCTAssertEqual(edge.description, "LinearBorderEdge(size: 0.5)")
    }

    /// Test LinearBorderEdge description with only alignment non-default.
    func testLinearBorderEdgeDescriptionAlignmentOnly() {
        let edge = LinearBorderEdge(alignment: 0.5)
        XCTAssertEqual(edge.description, "LinearBorderEdge(alignment: 0.5)")
    }

    /// Test LinearBorder description with all edges.
    func testLinearBorderDescriptionAllEdges() {
        let side = BorderSide(color: Color(0xff123456), width: 10.0)
        let border = LinearBorder(
            side: side,
            start: LinearBorderEdge(size: 0, alignment: -0.75),
            end: LinearBorderEdge(size: 0.25, alignment: -0.5),
            top: LinearBorderEdge(size: 0.5, alignment: 0.5),
            bottom: LinearBorderEdge(size: 0.75, alignment: 0.75)
        )
        let desc = border.description
        // The description should contain LinearBorder, side, and all edge names
        XCTAssertTrue(desc.contains("LinearBorder"))
        XCTAssertTrue(desc.contains("side:"))
        XCTAssertTrue(desc.contains("start:"))
        XCTAssertTrue(desc.contains("end:"))
        XCTAssertTrue(desc.contains("top:"))
        XCTAssertTrue(desc.contains("bottom:"))
    }

    // MARK: - Scale Tests

    /// Test that scale returns LinearBorder with scaled side.
    func testLinearBorderScale() {
        let border = LinearBorder(side: BorderSide(width: 4.0))
        if let scaled = border.scale(2.0) as? LinearBorder {
            XCTAssertEqual(scaled.side.width, 8.0, accuracy: 1e-10)
        } else {
            XCTFail("scale should return LinearBorder")
        }
    }

    // MARK: - Dimensions Tests

    /// Test dimensions with various edge combinations.
    func testLinearBorderDimensions() {
        let side = BorderSide(width: 4.0)

        // No edges: zero dimensions
        let noneEdges = LinearBorder(side: side)
        if let dims = noneEdges.dimensions as? EdgeInsetsDirectional {
            XCTAssertEqual(dims.start, 0.0)
            XCTAssertEqual(dims.top, 0.0)
            XCTAssertEqual(dims.end, 0.0)
            XCTAssertEqual(dims.bottom, 0.0)
        }

        // All edges: width on all sides
        let allEdges = LinearBorder(
            side: side,
            start: LinearBorderEdge(),
            end: LinearBorderEdge(),
            top: LinearBorderEdge(),
            bottom: LinearBorderEdge()
        )
        if let dims = allEdges.dimensions as? EdgeInsetsDirectional {
            XCTAssertEqual(dims.start, 4.0)
            XCTAssertEqual(dims.top, 4.0)
            XCTAssertEqual(dims.end, 4.0)
            XCTAssertEqual(dims.bottom, 4.0)
        }

        // Only start edge
        let startOnly = LinearBorder.start(side: side)
        if let dims = startOnly.dimensions as? EdgeInsetsDirectional {
            XCTAssertEqual(dims.start, 4.0)
            XCTAssertEqual(dims.top, 0.0)
            XCTAssertEqual(dims.end, 0.0)
            XCTAssertEqual(dims.bottom, 0.0)
        }
    }

    // MARK: - getOuterPath / getInnerPath Tests

    /// Test that getOuterPath returns a path matching the rect.
    func testLinearBorderGetOuterPath() {
        let border = LinearBorder.start(side: BorderSide(width: 4.0))
        let rect = Rect.fromLTWH(0, 0, 100, 100)
        let outerPath = border.getOuterPath(rect, textDirection: .ltr)
        let bounds = outerPath.getBounds()
        XCTAssertEqual(bounds.left, 0.0, accuracy: 1e-10)
        XCTAssertEqual(bounds.top, 0.0, accuracy: 1e-10)
        XCTAssertEqual(bounds.right, 100.0, accuracy: 1e-10)
        XCTAssertEqual(bounds.bottom, 100.0, accuracy: 1e-10)
    }

    /// Test that getInnerPath returns a path inset by the border dimensions.
    func testLinearBorderGetInnerPath() {
        let border = LinearBorder(
            side: BorderSide(width: 4.0),
            start: LinearBorderEdge(),
            end: LinearBorderEdge(),
            top: LinearBorderEdge(),
            bottom: LinearBorderEdge()
        )
        let rect = Rect.fromLTWH(0, 0, 100, 100)

        // LTR: start=left, end=right
        let innerPath = border.getInnerPath(rect, textDirection: .ltr)
        let bounds = innerPath.getBounds()
        XCTAssertEqual(bounds.left, 4.0, accuracy: 1e-10)
        XCTAssertEqual(bounds.top, 4.0, accuracy: 1e-10)
        XCTAssertEqual(bounds.right, 96.0, accuracy: 1e-10)
        XCTAssertEqual(bounds.bottom, 96.0, accuracy: 1e-10)
    }

    // MARK: - Equality Tests

    /// Test inequality between different borders.
    func testLinearBorderInequality() {
        let border1 = LinearBorder.start()
        let border2 = LinearBorder.end()
        let border3 = LinearBorder(side: BorderSide(width: 2.0))

        XCTAssertNotEqual(border1, border2)
        XCTAssertNotEqual(border1, border3)
        XCTAssertNotEqual(border2, border3)
    }

    /// Test LinearBorderEdge equality.
    func testLinearBorderEdgeEquality() {
        let a = LinearBorderEdge(size: 0.5, alignment: 0.3)
        let b = LinearBorderEdge(size: 0.5, alignment: 0.3)
        let c = LinearBorderEdge(size: 0.6, alignment: 0.3)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// Test LinearBorderEdge hash consistency.
    func testLinearBorderEdgeHash() {
        let a = LinearBorderEdge(size: 0.5, alignment: 0.3)
        let b = LinearBorderEdge(size: 0.5, alignment: 0.3)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - copyWith Tests

    /// Test copyWith replaces specified fields.
    func testLinearBorderCopyWithSpecificFields() {
        let border = LinearBorder(
            side: BorderSide(width: 4.0),
            start: LinearBorderEdge(),
            top: LinearBorderEdge(size: 0.5)
        )

        let newSide = BorderSide(width: 8.0)
        let copied: LinearBorder = border.copyWith(side: newSide)
        XCTAssertEqual(copied.side, newSide)
        XCTAssertEqual(copied.start, border.start)
        XCTAssertEqual(copied.top, border.top)
        XCTAssertNil(copied.end)
        XCTAssertNil(copied.bottom)
    }

    /// Test OutlinedBorder protocol copyWith.
    func testLinearBorderOutlinedBorderCopyWith() {
        let border = LinearBorder.start()
        let newSide = BorderSide(width: 10.0)
        // Use the protocol-level copyWith which returns any OutlinedBorder
        let copied = border.copyWith(side: Optional(newSide)) as! LinearBorder
        XCTAssertEqual(copied.side, newSide)
        XCTAssertEqual(copied.start, border.start)
    }

    // MARK: - preferPaintInterior Test

    /// Test that preferPaintInterior returns false.
    func testLinearBorderPreferPaintInterior() {
        let border = LinearBorder()
        XCTAssertFalse(border.preferPaintInterior)
    }
}

// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import FlutterSwiftBridge

final class RSuperellipseTests: XCTestCase {

    func testCreateRSuperellipse() {
        let shape = RSuperellipse(
            left: 0, top: 0, right: 100, bottom: 100,
            tlRadiusX: 10, tlRadiusY: 10,
            trRadiusX: 10, trRadiusY: 10,
            brRadiusX: 10, brRadiusY: 10,
            blRadiusX: 10, blRadiusY: 10
        )
        XCTAssertNotNil(shape)
    }

    func testContainsPointInsideBounds() {
        let shape = RSuperellipse(
            left: 0, top: 0, right: 100, bottom: 100,
            tlRadiusX: 10, tlRadiusY: 10,
            trRadiusX: 10, trRadiusY: 10,
            brRadiusX: 10, brRadiusY: 10,
            blRadiusX: 10, blRadiusY: 10
        )
        // Center point should be inside
        XCTAssertTrue(shape.contains(Offset(50, 50)))
    }

    func testContainsPointOutsideBounds() {
        let shape = RSuperellipse(
            left: 0, top: 0, right: 100, bottom: 100,
            tlRadiusX: 10, tlRadiusY: 10,
            trRadiusX: 10, trRadiusY: 10,
            brRadiusX: 10, brRadiusY: 10,
            blRadiusX: 10, blRadiusY: 10
        )
        // Point outside bounds should not be contained
        XCTAssertFalse(shape.contains(Offset(150, 150)))
        XCTAssertFalse(shape.contains(Offset(-10, -10)))
    }

    func testContainsPointInCorner() {
        let shape = RSuperellipse(
            left: 0, top: 0, right: 100, bottom: 100,
            tlRadiusX: 20, tlRadiusY: 20,
            trRadiusX: 20, trRadiusY: 20,
            brRadiusX: 20, brRadiusY: 20,
            blRadiusX: 20, blRadiusY: 20
        )
        // Point at corner (within bounds but outside rounded corner)
        XCTAssertFalse(shape.contains(Offset(1, 1)))
    }

    func testZeroRadii() {
        let shape = RSuperellipse(
            left: 0, top: 0, right: 100, bottom: 100,
            tlRadiusX: 0, tlRadiusY: 0,
            trRadiusX: 0, trRadiusY: 0,
            brRadiusX: 0, brRadiusY: 0,
            blRadiusX: 0, blRadiusY: 0
        )
        // Corner should be inside with zero radii
        XCTAssertTrue(shape.contains(Offset(1, 1)))
        XCTAssertTrue(shape.contains(Offset(99, 99)))
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for NotchedShape types.
///
/// **Dart Test Source:** `packages/flutter/test/painting/notched_shapes_test.dart`

import Foundation
import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// A simple ShapeBorder for testing that creates a rectangular path.
///
/// Mimics the behavior of `RoundedRectangleBorder()` with default
/// `BorderRadius.zero`, which produces a simple rectangle path.
private struct RectangleShapeBorder: ShapeBorder {
    var dimensions: any EdgeInsetsGeometry { EdgeInsets.zero }

    func scale(_ t: Double) -> any ShapeBorder { self }
    func lerpFrom(_ a: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? { nil }
    func lerpTo(_ b: (any ShapeBorder)?, _ t: Double) -> (any ShapeBorder)? { nil }

    func getOuterPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        // Mimics RoundedRectangleBorder() which uses addRRect with BorderRadius.zero
        let path = Path()
        path.addRRect(BorderRadius.zero.resolve(textDirection).toRRect(rect))
        return path
    }

    func getInnerPath(_ rect: Rect, textDirection: TextDirection? = nil) -> Path {
        let path = Path()
        path.addRRect(BorderRadius.zero.resolve(textDirection).toRRect(rect))
        return path
    }

    func paintInterior(_ canvas: Canvas, _ rect: Rect, _ paint: Paint, textDirection: TextDirection?) {}
    var preferPaintInterior: Bool { false }
    func paint(_ canvas: Canvas, _ rect: Rect, textDirection: TextDirection?) {}
    var description: String { "RectangleShapeBorder()" }
}

/// Tests whether a path does not contain any point inside a circle.
///
/// Samples points within the circle bounded by `circleBounds` and verifies
/// none are contained in the path.
///
/// **Dart Source:** `notched_shapes_test.dart:123-137`
private func pathDoesNotContainCircle(_ path: Path, _ circleBounds: Rect) -> Bool {
    assert(circleBounds.width == circleBounds.height)
    let radius = circleBounds.width / 2.0

    var theta = 0.0
    while theta <= 2.0 * Double.pi {
        var i = 0.0
        while i < 1.0 {
            let x = i * radius * cos(theta)
            let y = i * radius * sin(theta)
            if path.contains(Offset(x, y) + circleBounds.center) {
                return false
            }
            i += 0.01
        }
        theta += Double.pi / 20.0
    }
    return true
}

/// Tests whether two paths cover the same area by sampling points.
///
/// Samples points in the given area and checks whether containment
/// matches between both paths.
private func pathsCoverSameArea(
    _ path1: Path,
    _ path2: Path,
    in area: Rect,
    sampleSize: Int = 40
) -> Bool {
    let stepX = area.width / Double(sampleSize)
    let stepY = area.height / Double(sampleSize)

    for xi in 0..<sampleSize {
        for yi in 0..<sampleSize {
            let point = Offset(
                area.left + stepX * (Double(xi) + 0.5),
                area.top + stepY * (Double(yi) + 0.5)
            )
            if path1.contains(point) != path2.contains(point) {
                return false
            }
        }
    }
    return true
}

// MARK: - NotchedShapesTests

final class NotchedShapesTests: XCTestCase {

    // MARK: - CircularNotchedRectangle Tests

    /// **Dart Test:** `notched_shapes_test.dart:12-24`
    func testGuestAndHostDontOverlap() {
        let shape = CircularNotchedRectangle()
        let host = Rect.fromLTRB(0.0, 100.0, 300.0, 300.0)
        let guest = Rect.fromLTWH(50.0, 50.0, 10.0, 10.0)

        let actualPath = shape.getOuterPath(host: host, guest: guest)
        let expectedPath = Path()
        expectedPath.addRect(host)

        XCTAssertTrue(
            pathsCoverSameArea(actualPath, expectedPath, in: host.inflate(5.0)),
            "When guest and host don't overlap, path should be a simple rectangle"
        )
    }

    /// **Dart Test:** `notched_shapes_test.dart:26-34`
    func testGuestCenterAboveHost() {
        let shape = CircularNotchedRectangle()
        let host = Rect.fromLTRB(0.0, 100.0, 300.0, 300.0)
        let guest = Rect.fromLTRB(190.0, 85.0, 210.0, 105.0)

        let actualPath = shape.getOuterPath(host: host, guest: guest)

        XCTAssertTrue(
            pathDoesNotContainCircle(actualPath, guest),
            "The path should not contain any point inside the guest circle"
        )
    }

    /// **Dart Test:** `notched_shapes_test.dart:36-44`
    func testGuestCenterBelowHost() {
        let shape = CircularNotchedRectangle()
        let host = Rect.fromLTRB(0.0, 100.0, 300.0, 300.0)
        let guest = Rect.fromLTRB(190.0, 95.0, 210.0, 115.0)

        let actualPath = shape.getOuterPath(host: host, guest: guest)

        XCTAssertTrue(
            pathDoesNotContainCircle(actualPath, guest),
            "The path should not contain any point inside the guest circle"
        )
    }

    /// **Dart Test:** `notched_shapes_test.dart:46-54`
    func testInvertedGuestCenterAboveHost() {
        let shape = CircularNotchedRectangle(inverted: true)
        let host = Rect.fromLTRB(0.0, 100.0, 300.0, 300.0)
        let guest = Rect.fromLTRB(190.0, 285.0, 210.0, 305.0)

        let actualPath = shape.getOuterPath(host: host, guest: guest)

        XCTAssertTrue(
            pathDoesNotContainCircle(actualPath, guest),
            "The inverted path should not contain any point inside the guest circle"
        )
    }

    /// **Dart Test:** `notched_shapes_test.dart:56-64`
    func testInvertedGuestCenterBelowHost() {
        let shape = CircularNotchedRectangle(inverted: true)
        let host = Rect.fromLTRB(0.0, 100.0, 300.0, 300.0)
        let guest = Rect.fromLTRB(190.0, 295.0, 210.0, 315.0)

        let actualPath = shape.getOuterPath(host: host, guest: guest)

        XCTAssertTrue(
            pathDoesNotContainCircle(actualPath, guest),
            "The inverted path should not contain any point inside the guest circle"
        )
    }

    /// **Dart Test:** `notched_shapes_test.dart:66-76`
    func testNoGuestIsOk() {
        let host = Rect.fromLTRB(0.0, 100.0, 300.0, 300.0)
        let actualPath = CircularNotchedRectangle().getOuterPath(host: host, guest: nil)
        let expectedPath = Path()
        expectedPath.addRect(host)

        XCTAssertTrue(
            pathsCoverSameArea(actualPath, expectedPath, in: host.inflate(800.0), sampleSize: 100),
            "When guest is nil, path should be a simple rectangle"
        )
    }

    // MARK: - AutomaticNotchedShape Tests

    /// **Dart Test:** `notched_shapes_test.dart:78-100`
    ///
    /// Host: LTRB(-200, -100, -150, 0)
    /// Guest: LTRB(-175, -110, -75, -10)
    /// Overlap: LTRB(-175, -100, -150, -10)
    /// Result: L-shaped path (host minus overlap)
    func testAutomaticNotchedShapeWithGuest() {
        let shape = AutomaticNotchedShape(
            host: RectangleShapeBorder(),
            guest: RectangleShapeBorder()
        )
        let actualPath = shape.getOuterPath(
            host: Rect.fromLTWH(-200.0, -100.0, 50.0, 100.0),
            guest: Rect.fromLTWH(-175.0, -110.0, 100.0, 100.0)
        )

        // Points that should be in the L-shaped result (host minus guest overlap)
        // Left strip of host: (-200, -100) to (-175, 0)
        XCTAssertTrue(actualPath.contains(Offset(-190.0, -50.0)),
                       "Point in left strip of host should be contained")
        XCTAssertTrue(actualPath.contains(Offset(-185.0, -5.0)),
                       "Point in bottom-left of host should be contained")
        // Bottom-right of host below overlap: (-175, -10) to (-150, 0)
        XCTAssertTrue(actualPath.contains(Offset(-160.0, -5.0)),
                       "Point in bottom-right of host (below overlap) should be contained")

        // Points that should NOT be in the result (in the subtracted overlap region)
        // Overlap region: (-175, -100) to (-150, -10)
        XCTAssertFalse(actualPath.contains(Offset(-160.0, -50.0)),
                        "Point in overlap region should NOT be contained")
        XCTAssertFalse(actualPath.contains(Offset(-165.0, -80.0)),
                        "Point in overlap region should NOT be contained")

        // Points outside both host and guest
        XCTAssertFalse(actualPath.contains(Offset(-300.0, -50.0)),
                        "Point outside host should NOT be contained")
        XCTAssertFalse(actualPath.contains(Offset(0.0, 0.0)),
                        "Point outside host should NOT be contained")
    }

    /// **Dart Test:** `notched_shapes_test.dart:102-119`
    func testAutomaticNotchedShapeNoGuest() {
        let shape = AutomaticNotchedShape(
            host: RectangleShapeBorder(),
            guest: RectangleShapeBorder()
        )
        let actualPath = shape.getOuterPath(
            host: Rect.fromLTWH(-200.0, -100.0, 50.0, 100.0),
            guest: nil
        )

        let expectedPath = Path()
        expectedPath.moveTo(-200.0, -100.0)
        expectedPath.lineTo(-150.0, -100.0)
        expectedPath.lineTo(-150.0, 0.0)
        expectedPath.lineTo(-200.0, 0.0)
        expectedPath.close()

        XCTAssertTrue(
            pathsCoverSameArea(
                actualPath,
                expectedPath,
                in: Rect.fromLTWH(-300.0, -300.0, 600.0, 600.0),
                sampleSize: 100
            ),
            "AutomaticNotchedShape with no guest should return host path"
        )
    }

    // MARK: - Default Property Tests

    /// Verify CircularNotchedRectangle defaults.
    func testCircularNotchedRectangleDefaults() {
        let shape = CircularNotchedRectangle()
        XCTAssertFalse(shape.inverted)
    }

    /// Verify CircularNotchedRectangle inverted property.
    func testCircularNotchedRectangleInverted() {
        let shape = CircularNotchedRectangle(inverted: true)
        XCTAssertTrue(shape.inverted)
    }
}

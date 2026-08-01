// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Migrated from: engine/src/flutter/testing/dart/geometry_test.dart

import Foundation
import Testing

@testable import FlutterSwiftBridge

/// Helper function to check that an RSuperellipse contains a point but not that point
/// offset outward.
///
/// **Dart Source:** `geometry_test.dart:579-593` (checkPointWithOffset helper)
///
/// - Parameters:
///   - rse: The RSuperellipse to test
///   - inPoint: A point expected to be inside the RSuperellipse
///   - outwardOffset: An offset that, when added to inPoint, gives a point outside the RSuperellipse
private func checkPointWithOffset(_ rse: RSuperellipse, _ inPoint: Offset, _ outwardOffset: Offset) {
    #expect(rse.contains(inPoint), "Expected point \(inPoint) to be inside RSuperellipse")
    #expect(
        !rse.contains(inPoint + outwardOffset),
        "Expected point \(inPoint + outwardOffset) to be outside RSuperellipse"
    )
}

@Suite("Geometry Tests")
struct GeometryTests {
    // MARK: - OffsetBase Comparison Operators

    /// **Dart Source:** `geometry_test.dart:15-23` (test 'OffsetBase.>=')
    @Test("OffsetBase.>=")
    func testOffsetBaseGreaterThanOrEqual() {
        #expect(Offset(0, 0) >= Offset(0, -1))
        #expect(Offset(0, 0) >= Offset(-1, 0))
        #expect(Offset(0, 0) >= Offset(-1, -1))
        #expect(Offset(0, 0) >= Offset(0, 0))
        #expect((Offset(0, 0) >= Offset(0, Double.nan)) == false)
        #expect((Offset(0, 0) >= Offset(Double.nan, 0)) == false)
        #expect((Offset(0, 0) >= Offset(10, -10)) == false)
    }

    /// **Dart Source:** `geometry_test.dart:25-32` (test 'OffsetBase.<=')
    @Test("OffsetBase.<=")
    func testOffsetBaseLessThanOrEqual() {
        #expect(Offset(0, 0) <= Offset(0, 1))
        #expect(Offset(0, 0) <= Offset(1, 0))
        #expect(Offset(0, 0) <= Offset(0, 0))
        #expect((Offset(0, 0) <= Offset(0, Double.nan)) == false)
        #expect((Offset(0, 0) <= Offset(Double.nan, 0)) == false)
        #expect((Offset(0, 0) <= Offset(10, -10)) == false)
    }

    /// **Dart Source:** `geometry_test.dart:34-39` (test 'OffsetBase.>')
    @Test("OffsetBase.>")
    func testOffsetBaseGreaterThan() {
        #expect(Offset(0, 0) > Offset(-1, -1))
        #expect((Offset(0, 0) > Offset(0, -1)) == false)
        #expect((Offset(0, 0) > Offset(-1, 0)) == false)
        #expect((Offset(0, 0) > Offset(Double.nan, -1)) == false)
    }

    /// **Dart Source:** `geometry_test.dart:41-46` (test 'OffsetBase.<')
    @Test("OffsetBase.<")
    func testOffsetBaseLessThan() {
        #expect(Offset(0, 0) < Offset(1, 1))
        #expect((Offset(0, 0) < Offset(0, 1)) == false)
        #expect((Offset(0, 0) < Offset(1, 0)) == false)
        #expect((Offset(0, 0) < Offset(Double.nan, 1)) == false)
    }

    // MARK: - OffsetBase Equality

    /// **Dart Source:** `geometry_test.dart:48-52` (test 'OffsetBase.==')
    @Test("OffsetBase.==")
    func testOffsetBaseEquality() {
        #expect(Offset(0, 0) == Offset(0, 0))
        #expect(Offset(0, 0) != Offset(1, 0))
        #expect(Offset(0, 0) != Offset(0, 1))
    }

    // MARK: - Offset Direction

    /// **Dart Source:** `geometry_test.dart:54-64` (test 'Offset.direction')
    @Test("Offset.direction")
    func testOffsetDirection() {
        #expect(Offset(0.0, 0.0).direction == 0.0)
        #expect(Offset(0.0, 1.0).direction == Double.pi / 2.0)
        #expect(Offset(0.0, -1.0).direction == -Double.pi / 2.0)
        #expect(Offset(1.0, 0.0).direction == 0.0)
        #expect(Offset(1.0, 1.0).direction == Double.pi / 4.0)
        #expect(Offset(1.0, -1.0).direction == -Double.pi / 4.0)
        #expect(Offset(-1.0, 0.0).direction == Double.pi)
        #expect(Offset(-1.0, 1.0).direction == Double.pi * 3.0 / 4.0)
        #expect(Offset(-1.0, -1.0).direction == -Double.pi * 3.0 / 4.0)
    }

    /// **Dart Source:** `geometry_test.dart:66-89` (test 'Offset.fromDirection')
    @Test("Offset.fromDirection")
    func testOffsetFromDirection() {
        let tolerance: Double = 1e-12

        // Test with zero direction and zero distance
        #expect(Offset.fromDirection(0.0, 0.0) == Offset(0.0, 0.0))

        // Test pi/2 direction (pointing up)
        let piOver2 = Offset.fromDirection(Double.pi / 2.0)
        #expect(Swift.abs(piOver2.dx) < tolerance)
        #expect(piOver2.dy == 1.0)

        // Test -pi/2 direction (pointing down)
        let negPiOver2 = Offset.fromDirection(-Double.pi / 2.0)
        #expect(Swift.abs(negPiOver2.dx) < tolerance)
        #expect(negPiOver2.dy == -1.0)

        // Test zero direction with default distance (pointing right)
        #expect(Offset.fromDirection(0.0) == Offset(1.0, 0.0))

        // Test pi/4 direction (45 degrees)
        let piOver4 = Offset.fromDirection(Double.pi / 4.0)
        let sqrt2Inv = 1.0 / sqrt(2.0)
        #expect(Swift.abs(piOver4.dx - sqrt2Inv) < tolerance)
        #expect(Swift.abs(piOver4.dy - sqrt2Inv) < tolerance)

        // Test -pi/4 direction (-45 degrees)
        let negPiOver4 = Offset.fromDirection(-Double.pi / 4.0)
        #expect(Swift.abs(negPiOver4.dx - sqrt2Inv) < tolerance)
        #expect(Swift.abs(negPiOver4.dy - (-sqrt2Inv)) < tolerance)

        // Test pi direction (pointing left)
        let pi = Offset.fromDirection(Double.pi)
        #expect(pi.dx == -1.0)
        #expect(Swift.abs(pi.dy) < tolerance)

        // Test 3*pi/4 direction (135 degrees)
        let threePiOver4 = Offset.fromDirection(Double.pi * 3.0 / 4.0)
        #expect(Swift.abs(threePiOver4.dx - (-sqrt2Inv)) < tolerance)
        #expect(Swift.abs(threePiOver4.dy - sqrt2Inv) < tolerance)

        // Test -3*pi/4 direction (-135 degrees)
        let negThreePiOver4 = Offset.fromDirection(-Double.pi * 3.0 / 4.0)
        #expect(Swift.abs(negThreePiOver4.dx - (-sqrt2Inv)) < tolerance)
        #expect(Swift.abs(negThreePiOver4.dy - (-sqrt2Inv)) < tolerance)

        // Test with custom distance
        #expect(Offset.fromDirection(0.0, 2.0) == Offset(2.0, 0.0))

        // Test pi/6 (30 degrees) with distance 2.0
        let piOver6 = Offset.fromDirection(Double.pi / 6.0, 2.0)
        #expect(Swift.abs(piOver6.dx - sqrt(3.0)) < tolerance)
        #expect(Swift.abs(piOver6.dy - 1.0) < tolerance)
    }

    // MARK: - Size Tests

    /// **Dart Source:** `geometry_test.dart:91-97` (test 'Size created from doubles')
    @Test("Size created from doubles")
    func testSizeCreatedFromDoubles() {
        let size = Size(5.0, 7.0)
        #expect(size.width == 5.0)
        #expect(size.height == 7.0)
        #expect(size.shortestSide == 5.0)
        #expect(size.longestSide == 7.0)
    }

    /// **Dart Source:** `geometry_test.dart:99-113` (test 'Size.aspectRatio')
    @Test("Size.aspectRatio")
    func testSizeAspectRatio() {
        // Test zero dimensions
        #expect(Size(0.0, 0.0).aspectRatio == 0.0)
        #expect(Size(-0.0, 0.0).aspectRatio == 0.0)
        #expect(Size(0.0, -0.0).aspectRatio == 0.0)
        #expect(Size(-0.0, -0.0).aspectRatio == 0.0)

        // Test zero width
        #expect(Size(0.0, 1.0).aspectRatio == 0.0)
        // Size(0.0, -1.0) produces -0.0 aspect ratio; in IEEE 754, -0.0 == 0.0
        // but we can check isZero or the specific sign if needed
        let negZeroAspect = Size(0.0, -1.0).aspectRatio
        #expect(negZeroAspect == 0.0 || negZeroAspect.isZero)

        // Test zero height (produces infinity)
        #expect(Size(1.0, 0.0).aspectRatio == Double.infinity)

        // Test unit sizes
        #expect(Size(1.0, 1.0).aspectRatio == 1.0)
        #expect(Size(1.0, -1.0).aspectRatio == -1.0)

        // Test negative width with zero height (produces negative infinity)
        #expect(Size(-1.0, 0.0).aspectRatio == -Double.infinity)

        // Test negative dimensions
        #expect(Size(-1.0, 1.0).aspectRatio == -1.0)
        #expect(Size(-1.0, -1.0).aspectRatio == 1.0)

        // Test non-square ratio
        #expect(Size(3.0, 4.0).aspectRatio == 3.0 / 4.0)
    }

    // MARK: - Rect Tests

    /// **Dart Source:** `geometry_test.dart:115-118` (test 'Rect.toString test')
    @Test("Rect.toString test")
    func testRectToString() {
        let r = Rect.fromLTRB(1.0, 3.0, 5.0, 7.0)
        #expect(String(describing: r) == "Rect.fromLTRB(1.0, 3.0, 5.0, 7.0)")
    }

    /// **Dart Source:** `geometry_test.dart:120-126` (test 'Rect accessors')
    @Test("Rect accessors")
    func testRectAccessors() {
        let r = Rect.fromLTRB(1.0, 3.0, 5.0, 7.0)
        #expect(r.left == 1.0)
        #expect(r.top == 3.0)
        #expect(r.right == 5.0)
        #expect(r.bottom == 7.0)
    }

    /// **Dart Source:** `geometry_test.dart:128-152` (test 'Rect.fromCenter')
    @Test("Rect.fromCenter")
    func testRectFromCenter() {
        // Test with center at (1.0, 3.0), width 5.0, height 7.0
        var rect = Rect.fromCenter(center: Offset(1.0, 3.0), width: 5.0, height: 7.0)
        #expect(rect.left == -1.5)
        #expect(rect.top == -0.5)
        #expect(rect.right == 3.5)
        #expect(rect.bottom == 6.5)

        // Test with zero dimensions at origin
        rect = Rect.fromCenter(center: Offset(0.0, 0.0), width: 0.0, height: 0.0)
        #expect(rect.left == 0.0)
        #expect(rect.top == 0.0)
        #expect(rect.right == 0.0)
        #expect(rect.bottom == 0.0)

        // Test with NaN in center x - left and right become NaN
        rect = Rect.fromCenter(center: Offset(Double.nan, 0.0), width: 0.0, height: 0.0)
        #expect(rect.left.isNaN)
        #expect(rect.top == 0.0)
        #expect(rect.right.isNaN)
        #expect(rect.bottom == 0.0)

        // Test with NaN in center y - top and bottom become NaN
        rect = Rect.fromCenter(center: Offset(0.0, Double.nan), width: 0.0, height: 0.0)
        #expect(rect.left == 0.0)
        #expect(rect.top.isNaN)
        #expect(rect.right == 0.0)
        #expect(rect.bottom.isNaN)
    }

    /// **Dart Source:** `geometry_test.dart:154-162` (test 'Rect created by width and height')
    @Test("Rect created by width and height")
    func testRectCreatedByWidthAndHeight() {
        let r = Rect.fromLTWH(1.0, 3.0, 5.0, 7.0)
        #expect(r.left == 1.0)
        #expect(r.top == 3.0)
        #expect(r.right == 6.0)
        #expect(r.bottom == 10.0)
        #expect(r.shortestSide == 5.0)
        #expect(r.longestSide == 7.0)
    }

    /// **Dart Source:** `geometry_test.dart:164-174` (test 'Rect intersection')
    @Test("Rect intersection")
    func testRectIntersection() {
        let r1 = Rect.fromLTRB(0.0, 0.0, 100.0, 100.0)
        let r2 = Rect.fromLTRB(50.0, 50.0, 200.0, 200.0)

        let r3 = r1.intersect(r2)
        #expect(r3.left == 50.0)
        #expect(r3.top == 50.0)
        #expect(r3.right == 100.0)
        #expect(r3.bottom == 100.0)

        let r4 = r2.intersect(r1)
        #expect(r4 == r3)
    }

    /// **Dart Source:** `geometry_test.dart:176-187` (test 'Rect expandToInclude overlapping rects')
    @Test("Rect expandToInclude overlapping rects")
    func testRectExpandToIncludeOverlapping() {
        let r1 = Rect.fromLTRB(0.0, 0.0, 100.0, 100.0)
        let r2 = Rect.fromLTRB(50.0, 50.0, 200.0, 200.0)

        let r3 = r1.expandToInclude(r2)
        #expect(r3.left == 0.0)
        #expect(r3.top == 0.0)
        #expect(r3.right == 200.0)
        #expect(r3.bottom == 200.0)

        let r4 = r2.expandToInclude(r1)
        #expect(r4 == r3)
    }

    /// **Dart Source:** `geometry_test.dart:189-200` (test 'Rect expandToInclude crossing rects')
    @Test("Rect expandToInclude crossing rects")
    func testRectExpandToIncludeCrossing() {
        // Two crossing (perpendicular) lines that form a cross/plus shape
        let r1 = Rect.fromLTRB(50.0, 0.0, 50.0, 200.0)  // Vertical line
        let r2 = Rect.fromLTRB(0.0, 50.0, 200.0, 50.0)  // Horizontal line

        let r3 = r1.expandToInclude(r2)
        #expect(r3.left == 0.0)
        #expect(r3.top == 0.0)
        #expect(r3.right == 200.0)
        #expect(r3.bottom == 200.0)

        let r4 = r2.expandToInclude(r1)
        #expect(r4 == r3)
    }

    // MARK: - RRect Tests

    /// **Dart Source:** `geometry_test.dart:202-211` (test 'RRect.fromRectXY')
    @Test("RRect.fromRectXY")
    func testRRectFromRectXY() {
        let baseRect = Rect.fromLTWH(1.0, 3.0, 5.0, 7.0)
        let r = RRect(fromRectXY: baseRect, 1.0, 1.0)
        #expect(r.left == 1.0)
        #expect(r.top == 3.0)
        #expect(r.right == 6.0)
        #expect(r.bottom == 10.0)
        #expect(r.shortestSide == 5.0)
        #expect(r.longestSide == 7.0)
    }

    /// **Dart Source:** `geometry_test.dart:213-229` (test 'RRect.contains()')
    @Test("RRect.contains()")
    func testRRectContains() {
        let rrect = RRect(
            fromRectAndCorners: Rect.fromLTRB(1.0, 1.0, 2.0, 2.0),
            topLeft: Radius(circular: 0.5),
            topRight: Radius(circular: 0.25),
            bottomRight: Radius(elliptical: 0.25, 0.75)
        )

        // Corner cases - should be outside
        #expect(rrect.contains(Offset(1.0, 1.0)) == false)
        #expect(rrect.contains(Offset(1.1, 1.1)) == false)

        // Just inside the top-left corner
        #expect(rrect.contains(Offset(1.15, 1.15)) == true)

        // Top-right corner - should be outside
        #expect(rrect.contains(Offset(2.0, 1.0)) == false)
        #expect(rrect.contains(Offset(1.93, 1.07)) == false)

        // Bottom-right corner area
        #expect(rrect.contains(Offset(1.97, 1.7)) == false)
        #expect(rrect.contains(Offset(1.7, 1.97)) == true)

        // Bottom-left corner (no radius, so should be inside)
        #expect(rrect.contains(Offset(1.0, 1.99)) == true)
    }

    /// **Dart Source:** `geometry_test.dart:231-247` (test 'RRect.contains() large radii')
    @Test("RRect.contains() large radii")
    func testRRectContainsLargeRadii() {
        // Create RRect with large radii that should be scaled down
        let rrect = RRect(
            fromRectAndCorners: Rect.fromLTRB(1.0, 1.0, 2.0, 2.0),
            topLeft: Radius(circular: 5000.0),
            topRight: Radius(circular: 2500.0),
            bottomRight: Radius(elliptical: 2500.0, 7500.0)
        )

        // Same containment tests as testRRectContains - radii should be scaled down
        // so containment results are the same
        #expect(rrect.contains(Offset(1.0, 1.0)) == false)
        #expect(rrect.contains(Offset(1.1, 1.1)) == false)
        #expect(rrect.contains(Offset(1.15, 1.15)) == true)
        #expect(rrect.contains(Offset(2.0, 1.0)) == false)
        #expect(rrect.contains(Offset(1.93, 1.07)) == false)
        #expect(rrect.contains(Offset(1.97, 1.7)) == false)
        #expect(rrect.contains(Offset(1.7, 1.97)) == true)
        #expect(rrect.contains(Offset(1.0, 1.99)) == true)
    }

    /// **Dart Source:** `geometry_test.dart:249-272` (test 'RRect.scaleRadii() properly constrained radii should remain unchanged')
    @Test("RRect.scaleRadii() properly constrained radii should remain unchanged")
    func testRRectScaleRadiiConstrainedUnchanged() {
        let rrect = RRect(
            fromRectAndCorners: Rect.fromLTRB(1.0, 1.0, 2.0, 2.0),
            topLeft: Radius(circular: 0.5),
            topRight: Radius(circular: 0.25),
            bottomRight: Radius(elliptical: 0.25, 0.75)
        ).scaleRadii()

        // Check sides
        #expect(rrect.left == 1.0)
        #expect(rrect.top == 1.0)
        #expect(rrect.right == 2.0)
        #expect(rrect.bottom == 2.0)

        // Check corner radii
        #expect(rrect.tlRadiusX == 0.5)
        #expect(rrect.tlRadiusY == 0.5)
        #expect(rrect.trRadiusX == 0.25)
        #expect(rrect.trRadiusY == 0.25)
        #expect(rrect.blRadiusX == 0.0)
        #expect(rrect.blRadiusY == 0.0)
        #expect(rrect.brRadiusX == 0.25)
        #expect(rrect.brRadiusY == 0.75)
    }

    /// **Dart Source:** `geometry_test.dart:274-297` (test 'RRect.scaleRadii() sum of radii that exceed side length should properly scale')
    @Test("RRect.scaleRadii() sum of radii that exceed side length should properly scale")
    func testRRectScaleRadiiExceedSideLength() {
        // Create RRect with oversized radii that should be scaled down
        let rrect = RRect(
            fromRectAndCorners: Rect.fromLTRB(1.0, 1.0, 2.0, 2.0),
            topLeft: Radius(circular: 5000.0),
            topRight: Radius(circular: 2500.0),
            bottomRight: Radius(elliptical: 2500.0, 7500.0)
        ).scaleRadii()

        // Check sides - should remain unchanged
        #expect(rrect.left == 1.0)
        #expect(rrect.top == 1.0)
        #expect(rrect.right == 2.0)
        #expect(rrect.bottom == 2.0)

        // Check corner radii - should be scaled to fit
        #expect(rrect.tlRadiusX == 0.5)
        #expect(rrect.tlRadiusY == 0.5)
        #expect(rrect.trRadiusX == 0.25)
        #expect(rrect.trRadiusY == 0.25)
        #expect(rrect.blRadiusX == 0.0)
        #expect(rrect.blRadiusY == 0.0)
        #expect(rrect.brRadiusX == 0.25)
        #expect(rrect.brRadiusY == 0.75)
    }

    // MARK: - Radius Tests

    /// **Dart Source:** `geometry_test.dart:299-365` (test 'Radius.clamp() operates as expected')
    @Test("Radius.clamp() operates as expected")
    func testRadiusClamp() {
        // Test clamping negative radius to minimum Radius.zero
        let rrectMin = RRect(
            fromLTRBR: 1, 3, 5, 7,
            Radius(circular: -100).clamp(minimum: Radius.zero)
        )

        #expect(rrectMin.left == 1)
        #expect(rrectMin.top == 3)
        #expect(rrectMin.right == 5)
        #expect(rrectMin.bottom == 7)
        #expect(rrectMin.trRadius == Radius(circular: 0))
        #expect(rrectMin.blRadius == Radius(circular: 0))

        // Test clamping large radius to maximum Radius(circular: 10)
        let rrectMax = RRect(
            fromLTRBR: 1, 3, 5, 7,
            Radius(circular: 100).clamp(maximum: Radius(circular: 10))
        )

        #expect(rrectMax.left == 1)
        #expect(rrectMax.top == 3)
        #expect(rrectMax.right == 5)
        #expect(rrectMax.bottom == 7)
        #expect(rrectMax.trRadius == Radius(circular: 10))
        #expect(rrectMax.blRadius == Radius(circular: 10))

        // Test mixed clamping with elliptical radius (x negative, y large)
        let rrectMix = RRect(
            fromLTRBR: 1, 3, 5, 7,
            Radius(elliptical: -100, 100).clamp(
                minimum: Radius.zero,
                maximum: Radius(circular: 10)
            )
        )

        #expect(rrectMix.left == 1)
        #expect(rrectMix.top == 3)
        #expect(rrectMix.right == 5)
        #expect(rrectMix.bottom == 7)
        #expect(rrectMix.trRadius == Radius(elliptical: 0, 10))
        #expect(rrectMix.blRadius == Radius(elliptical: 0, 10))

        // Test mixed clamping with elliptical radius (x large, y negative)
        let rrectMix1 = RRect(
            fromLTRBR: 1, 3, 5, 7,
            Radius(elliptical: 100, -100).clamp(
                minimum: Radius.zero,
                maximum: Radius(circular: 10)
            )
        )

        #expect(rrectMix1.left == 1)
        #expect(rrectMix1.top == 3)
        #expect(rrectMix1.right == 5)
        #expect(rrectMix1.bottom == 7)
        #expect(rrectMix1.trRadius == Radius(elliptical: 10, 0))
        #expect(rrectMix1.blRadius == Radius(elliptical: 10, 0))
    }

    /// **Dart Source:** `geometry_test.dart:367-433` (test 'Radius.clampValues() operates as expected')
    @Test("Radius.clampValues() operates as expected")
    func testRadiusClampValues() {
        // Test clamping negative radius with minimumX and minimumY
        let rrectMin = RRect(
            fromLTRBR: 1, 3, 5, 7,
            Radius(circular: -100).clampValues(minimumX: 0, minimumY: 0)
        )

        #expect(rrectMin.left == 1)
        #expect(rrectMin.top == 3)
        #expect(rrectMin.right == 5)
        #expect(rrectMin.bottom == 7)
        #expect(rrectMin.trRadius == Radius(circular: 0))
        #expect(rrectMin.blRadius == Radius(circular: 0))

        // Test clamping large radius with maximumX and maximumY (different values)
        let rrectMax = RRect(
            fromLTRBR: 1, 3, 5, 7,
            Radius(circular: 100).clampValues(maximumX: 10, maximumY: 20)
        )

        #expect(rrectMax.left == 1)
        #expect(rrectMax.top == 3)
        #expect(rrectMax.right == 5)
        #expect(rrectMax.bottom == 7)
        #expect(rrectMax.trRadius == Radius(elliptical: 10, 20))
        #expect(rrectMax.blRadius == Radius(elliptical: 10, 20))

        // Test mixed clamping with elliptical radius (x negative, y large)
        let rrectMix = RRect(
            fromLTRBR: 1, 3, 5, 7,
            Radius(elliptical: -100, 100).clampValues(
                minimumX: 5,
                minimumY: 6,
                maximumX: 10,
                maximumY: 20
            )
        )

        #expect(rrectMix.left == 1)
        #expect(rrectMix.top == 3)
        #expect(rrectMix.right == 5)
        #expect(rrectMix.bottom == 7)
        #expect(rrectMix.trRadius == Radius(elliptical: 5, 20))
        #expect(rrectMix.blRadius == Radius(elliptical: 5, 20))

        // Test mixed clamping with elliptical radius (x large, y negative)
        let rrectMix2 = RRect(
            fromLTRBR: 1, 3, 5, 7,
            Radius(elliptical: 100, -100).clampValues(
                minimumX: 5,
                minimumY: 6,
                maximumX: 10,
                maximumY: 20
            )
        )

        #expect(rrectMix2.left == 1)
        #expect(rrectMix2.top == 3)
        #expect(rrectMix2.right == 5)
        #expect(rrectMix2.bottom == 7)
        #expect(rrectMix2.trRadius == Radius(elliptical: 10, 6))
        #expect(rrectMix2.blRadius == Radius(elliptical: 10, 6))
    }

    /// **Dart Source:** `geometry_test.dart:465-512` (test 'RRect.inflate clamps when deflating past zero')
    @Test("RRect.inflate clamps when deflating past zero")
    func testRRectInflateClampsWhenDeflatingPastZero() {
        // Create RRect with radii 1, 2, 3, 4 and deflate by 1
        // Note: Swift API has bottomRight before bottomLeft, but Dart test uses
        // topLeft=1, topRight=2, bottomLeft=3, bottomRight=4
        var rrect = RRect(
            fromRectAndCorners: Rect.fromLTRB(10.0, 20.0, 30.0, 40.0),
            topLeft: Radius(circular: 1),
            topRight: Radius(circular: 2),
            bottomRight: Radius(circular: 4),
            bottomLeft: Radius(circular: 3)
        ).inflate(-1)

        // After first inflate(-1): radii become 0, 1, 2, 3
        #expect(rrect.tlRadiusX == 0)
        #expect(rrect.tlRadiusY == 0)
        #expect(rrect.trRadiusX == 1)
        #expect(rrect.trRadiusY == 1)
        #expect(rrect.blRadiusX == 2)
        #expect(rrect.blRadiusY == 2)
        #expect(rrect.brRadiusX == 3)
        #expect(rrect.brRadiusY == 3)

        // Second inflate(-1): radii become 0, 0, 1, 2
        rrect = rrect.inflate(-1)
        #expect(rrect.tlRadiusX == 0)
        #expect(rrect.tlRadiusY == 0)
        #expect(rrect.trRadiusX == 0)
        #expect(rrect.trRadiusY == 0)
        #expect(rrect.blRadiusX == 1)
        #expect(rrect.blRadiusY == 1)
        #expect(rrect.brRadiusX == 2)
        #expect(rrect.brRadiusY == 2)

        // Third inflate(-1): radii become 0, 0, 0, 1
        rrect = rrect.inflate(-1)
        #expect(rrect.tlRadiusX == 0)
        #expect(rrect.tlRadiusY == 0)
        #expect(rrect.trRadiusX == 0)
        #expect(rrect.trRadiusY == 0)
        #expect(rrect.blRadiusX == 0)
        #expect(rrect.blRadiusY == 0)
        #expect(rrect.brRadiusX == 1)
        #expect(rrect.brRadiusY == 1)

        // Fourth inflate(-1): radii all become 0
        rrect = rrect.inflate(-1)
        #expect(rrect.tlRadiusX == 0)
        #expect(rrect.tlRadiusY == 0)
        #expect(rrect.trRadiusX == 0)
        #expect(rrect.trRadiusY == 0)
        #expect(rrect.blRadiusX == 0)
        #expect(rrect.blRadiusY == 0)
        #expect(rrect.brRadiusX == 0)
        #expect(rrect.brRadiusY == 0)
    }

    /// **Dart Source:** `geometry_test.dart:526-573` (test 'RRect.deflate clamps when deflating past zero')
    @Test("RRect.deflate clamps when deflating past zero")
    func testRRectDeflateClampsWhenDeflatingPastZero() {
        // Create RRect with radii 1, 2, 3, 4 and deflate by 1
        // Note: Swift API has bottomRight before bottomLeft, but Dart test uses
        // topLeft=1, topRight=2, bottomLeft=3, bottomRight=4
        var rrect = RRect(
            fromRectAndCorners: Rect.fromLTRB(10.0, 20.0, 30.0, 40.0),
            topLeft: Radius(circular: 1),
            topRight: Radius(circular: 2),
            bottomRight: Radius(circular: 4),
            bottomLeft: Radius(circular: 3)
        ).deflate(1)

        // After first deflate(1): radii become 0, 1, 2, 3
        #expect(rrect.tlRadiusX == 0)
        #expect(rrect.tlRadiusY == 0)
        #expect(rrect.trRadiusX == 1)
        #expect(rrect.trRadiusY == 1)
        #expect(rrect.blRadiusX == 2)
        #expect(rrect.blRadiusY == 2)
        #expect(rrect.brRadiusX == 3)
        #expect(rrect.brRadiusY == 3)

        // Second deflate(1): radii become 0, 0, 1, 2
        rrect = rrect.deflate(1)
        #expect(rrect.tlRadiusX == 0)
        #expect(rrect.tlRadiusY == 0)
        #expect(rrect.trRadiusX == 0)
        #expect(rrect.trRadiusY == 0)
        #expect(rrect.blRadiusX == 1)
        #expect(rrect.blRadiusY == 1)
        #expect(rrect.brRadiusX == 2)
        #expect(rrect.brRadiusY == 2)

        // Third deflate(1): radii become 0, 0, 0, 1
        rrect = rrect.deflate(1)
        #expect(rrect.tlRadiusX == 0)
        #expect(rrect.tlRadiusY == 0)
        #expect(rrect.trRadiusX == 0)
        #expect(rrect.trRadiusY == 0)
        #expect(rrect.blRadiusX == 0)
        #expect(rrect.blRadiusY == 0)
        #expect(rrect.brRadiusX == 1)
        #expect(rrect.brRadiusY == 1)

        // Fourth deflate(1): radii all become 0
        rrect = rrect.deflate(1)
        #expect(rrect.tlRadiusX == 0)
        #expect(rrect.tlRadiusY == 0)
        #expect(rrect.trRadiusX == 0)
        #expect(rrect.trRadiusY == 0)
        #expect(rrect.blRadiusX == 0)
        #expect(rrect.blRadiusY == 0)
        #expect(rrect.brRadiusX == 0)
        #expect(rrect.brRadiusY == 0)
    }

    // MARK: - Offset.lerp

    /// **Dart Source:** `geometry_test.dart:514-524` (test 'infinity lerp')
    @Test("infinity lerp")
    func testInfinityLerp() {
        let a = Offset(Double.infinity, Double.infinity)
        let b = Offset(4, 4)
        let result = Offset.lerp(a, b, 0.5)

        #expect(result != nil)
        #expect(result!.dx == Double.infinity)
        #expect(result!.dy == Double.infinity)
    }

    // MARK: - RSuperellipse Tests

    /// **Dart Source:** `geometry_test.dart:575-593` (test 'RSuperellipse.contains is correct with no corners')
    @Test("RSuperellipse.contains is correct with no corners")
    func testRSuperellipseContainsNoCorners() {
        // RSuperellipse of bounds with no corners contains corners just barely.
        let rse = RSuperellipse(fromLTRBXY: -50, -50, 50, 50, 0, 0)

        #expect(rse.contains(Offset(-50, -50)))
        // Rectangles have half-in, half-out containment so we need
        // to be careful about testing containment of right/bottom corners.
        #expect(rse.contains(Offset(-50, 49.99)))
        #expect(rse.contains(Offset(49.99, -50)))
        #expect(rse.contains(Offset(49.99, 49.99)))
        #expect(rse.contains(Offset(-50.01, -50)) == false)
        #expect(rse.contains(Offset(-50, -50.01)) == false)
        #expect(rse.contains(Offset(-50.01, 50)) == false)
        #expect(rse.contains(Offset(-50, 50.01)) == false)
        #expect(rse.contains(Offset(50.01, -50)) == false)
        #expect(rse.contains(Offset(50, -50.01)) == false)
        #expect(rse.contains(Offset(50.01, 50)) == false)
        #expect(rse.contains(Offset(50, 50.01)) == false)
    }

    /// **Dart Source:** `geometry_test.dart:595-603` (test 'RSuperellipse.contains is correct with tiny corners')
    @Test("RSuperellipse.contains is correct with tiny corners")
    func testRSuperellipseContainsTinyCorners() {
        // RSuperellipse of bounds with even the tiniest corners does not contain corners.
        let rse = RSuperellipse(fromLTRBXY: -50, -50, 50, 50, 0.01, 0.01)

        #expect(rse.contains(Offset(-50, -50)) == false)
        #expect(rse.contains(Offset(-50, 50)) == false)
        #expect(rse.contains(Offset(50, -50)) == false)
        #expect(rse.contains(Offset(50, 50)) == false)
    }

    /// **Dart Source:** `geometry_test.dart:605-622` (test 'RSuperellipse.contains is correct with uniform corners')
    @Test("RSuperellipse.contains is correct with uniform corners")
    func testRSuperellipseContainsUniformCorners() {
        let rse = RSuperellipse(fromLTRBXY: -50, -50, 50, 50, 5.0, 5.0)

        // Helper function to check a point and its mirrors across both axes
        func checkPointAndMirrors(_ p: Offset) {
            checkPointWithOffset(rse, Offset(p.dx, p.dy), Offset(0.02, 0.02))
            checkPointWithOffset(rse, Offset(p.dx, -p.dy), Offset(0.02, -0.02))
            checkPointWithOffset(rse, Offset(-p.dx, p.dy), Offset(-0.02, 0.02))
            checkPointWithOffset(rse, Offset(-p.dx, -p.dy), Offset(-0.02, -0.02))
        }

        checkPointAndMirrors(Offset(0, 49.995))       // Top
        checkPointAndMirrors(Offset(44.245, 49.95))   // Top curve start
        checkPointAndMirrors(Offset(45.72, 49.87))    // Top joint
        checkPointAndMirrors(Offset(48.53, 48.53))    // Circular arc mid
        checkPointAndMirrors(Offset(49.87, 45.72))    // Right joint
        checkPointAndMirrors(Offset(49.95, 44.245))   // Right curve start
        checkPointAndMirrors(Offset(49.995, 0))       // Right
    }

    /// **Dart Source:** `geometry_test.dart:624-641` (test 'RSuperellipse.contains is correct with uniform elliptical corners')
    @Test("RSuperellipse.contains is correct with uniform elliptical corners")
    func testRSuperellipseContainsUniformEllipticalCorners() {
        let rse = RSuperellipse(fromLTRBXY: -50, -50, 50, 50, 5.0, 10.0)

        // Helper function to check a point and its mirrors across both axes
        func checkPointAndMirrors(_ p: Offset) {
            checkPointWithOffset(rse, Offset(p.dx, p.dy), Offset(0.02, 0.02))
            checkPointWithOffset(rse, Offset(p.dx, -p.dy), Offset(0.02, -0.02))
            checkPointWithOffset(rse, Offset(-p.dx, p.dy), Offset(-0.02, 0.02))
            checkPointWithOffset(rse, Offset(-p.dx, -p.dy), Offset(-0.02, -0.02))
        }

        checkPointAndMirrors(Offset(0, 49.995))        // Top
        checkPointAndMirrors(Offset(44.245, 49.911))   // Top curve start
        checkPointAndMirrors(Offset(45.72, 49.75))     // Top joint
        checkPointAndMirrors(Offset(48.51, 47.07))     // Circular arc mid
        checkPointAndMirrors(Offset(49.87, 41.44))     // Right joint
        checkPointAndMirrors(Offset(49.95, 38.49))     // Right curve start
        checkPointAndMirrors(Offset(49.995, 0))        // Right
    }

    /// **Dart Source:** `geometry_test.dart:643-665` (test 'RSuperellipse.contains is correct with uniform corners and unequal height and width')
    @Test("RSuperellipse.contains is correct with uniform corners and unequal height and width")
    func testRSuperellipseContainsUnequalHeightWidth() {
        // The bounds is not centered at the origin and has unequal height and width.
        let rse = RSuperellipse(fromLTRBXY: 0, 0, 50, 100, 23.0, 30.0)

        let center = rse.outerRect.center

        // Helper function to check a point and its mirrors across both axes relative to center
        func checkPointAndMirrors(_ globalPoint: Offset) {
            let p = globalPoint - center
            checkPointWithOffset(rse, Offset(p.dx, p.dy) + center, Offset(0.02, 0.02))
            checkPointWithOffset(rse, Offset(p.dx, -p.dy) + center, Offset(0.02, -0.02))
            checkPointWithOffset(rse, Offset(-p.dx, p.dy) + center, Offset(-0.02, 0.02))
            checkPointWithOffset(rse, Offset(-p.dx, -p.dy) + center, Offset(-0.02, -0.02))
        }

        checkPointAndMirrors(Offset(24.99, 99.99))  // Bottom mid-edge
        checkPointAndMirrors(Offset(29.99, 99.64))
        checkPointAndMirrors(Offset(34.99, 98.06))
        checkPointAndMirrors(Offset(39.99, 94.73))
        checkPointAndMirrors(Offset(44.13, 89.99))
        checkPointAndMirrors(Offset(48.46, 79.99))
        checkPointAndMirrors(Offset(49.70, 69.99))
        checkPointAndMirrors(Offset(49.97, 59.99))
        checkPointAndMirrors(Offset(49.99, 49.99))  // Right mid-edge
    }

    /// **Dart Source:** `geometry_test.dart:667-704` (test 'RSuperellipse.contains is correct for a slim diagonal shape')
    @Test("RSuperellipse.contains is correct for a slim diagonal shape")
    func testRSuperellipseContainsDiagonalShape() {
        // This shape has large radii on one diagonal and tiny radii on the other,
        // resulting in an almond-like shape placed diagonally (NW to SE).
        let rse = RSuperellipse(
            fromLTRBAndCorners: -50, -50, 50, 50,
            topLeft: Radius(circular: 1.0),
            topRight: Radius(circular: 99.0),
            bottomRight: Radius(circular: 1.0),
            bottomLeft: Radius(circular: 99.0)
        )

        #expect(rse.contains(Offset(0, 0)))
        #expect(rse.contains(Offset(-49.999, -49.999)) == false)
        #expect(rse.contains(Offset(-49.999, 49.999)) == false)
        #expect(rse.contains(Offset(49.999, 49.999)) == false)
        #expect(rse.contains(Offset(49.999, -49.999)) == false)

        // The pointy ends at the NE and SW corners
        checkPointWithOffset(rse, Offset(-49.70, -49.70), Offset(-0.02, -0.02))
        checkPointWithOffset(rse, Offset(49.70, 49.70), Offset(0.02, 0.02))

        // Helper function to check two points symmetrical to the origin
        func checkDiagonalPoints(_ p: Offset) {
            checkPointWithOffset(rse, p, Offset(0.02, -0.02))
            checkPointWithOffset(rse, Offset(-p.dx, -p.dy), Offset(-0.02, 0.02))
        }

        // A few other points along the edge
        checkDiagonalPoints(Offset(-40.0, -49.59))
        checkDiagonalPoints(Offset(-20.0, -45.64))
        checkDiagonalPoints(Offset(0.0, -37.01))
        checkDiagonalPoints(Offset(20.0, -21.96))
        checkDiagonalPoints(Offset(21.05, -20.92))
        checkDiagonalPoints(Offset(40.0, 5.68))
    }

    /// **Dart Source:** `geometry_test.dart:706-718` (test 'RSuperellipse.contains is correct for points outside of a sharp corner')
    @Test("RSuperellipse.contains is correct for points outside of a sharp corner")
    func testRSuperellipseContainsOutsideSharpCorner() {
        // This tests that a point outside the bounds of an RSuperellipse
        // with sharp corners is correctly reported as not contained.
        let rse = RSuperellipse(
            fromLTRBAndCorners: 196.0, 0.0, 294.0, 28.0,
            topRight: Radius(circular: 3.0),
            bottomRight: Radius(circular: 3.0)
        )

        #expect(rse.contains(Offset(147.0, 14.0)) == false)
    }
}

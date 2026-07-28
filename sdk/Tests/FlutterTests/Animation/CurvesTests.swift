// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for Curves types migrated from curves.dart.
///
/// **Dart Test Source:** `packages/flutter/test/animation/curves_test.dart`
final class CurvesTests: XCTestCase {

    // MARK: - toString Tests

    /// Verify SawTooth, Interval, Split produce descriptions.
    ///
    /// **Dart Test:** `curves_test.dart:11-17`
    func testToStringDescriptions() {
        // Curves.linear
        let linear = Curves.linear
        XCTAssertFalse(linear.description.isEmpty)

        // SawTooth
        let sawTooth = SawTooth(3)
        XCTAssertFalse(sawTooth.description.isEmpty)
        XCTAssertTrue(sawTooth.description.contains("SawTooth"))

        // Interval without custom curve
        let interval1 = Interval(0.25, 0.75)
        XCTAssertFalse(interval1.description.isEmpty)
        XCTAssertTrue(interval1.description.contains("Interval"))

        // Interval with custom curve
        let interval2 = Interval(0.25, 0.75, curve: Curves.ease)
        XCTAssertFalse(interval2.description.isEmpty)
        XCTAssertTrue(interval2.description.contains("Interval"))

        // Split
        let split = Split(0.25, beginCurve: Curves.ease)
        XCTAssertFalse(split.description.isEmpty)
    }

    // MARK: - Flipped Curve Tests

    /// Test Curves.ease.flipped behavior at t=0, 0.5, 1.
    ///
    /// **Dart Test:** `curves_test.dart:19-26`
    func testCurveFlipped() {
        let ease = Curves.ease
        let flippedEase = ease.flipped

        XCTAssertLessThan(flippedEase.transform(0.0), 0.001)
        XCTAssertLessThan(flippedEase.transform(0.5), ease.transform(0.5))
        XCTAssertGreaterThan(flippedEase.transform(1.0), 0.999)
        XCTAssertFalse(flippedEase.description.isEmpty)
    }

    // MARK: - Threshold Tests

    /// Test step function behavior before and after threshold.
    ///
    /// **Dart Test:** `curves_test.dart:28-35`
    func testThreshold() {
        let step = Threshold(0.25)
        XCTAssertEqual(step.transform(0.0), 0.0)
        XCTAssertEqual(step.transform(0.24), 0.0)
        XCTAssertEqual(step.transform(0.25), 1.0)
        XCTAssertEqual(step.transform(0.26), 1.0)
        XCTAssertEqual(step.transform(1.0), 1.0)
    }

    // MARK: - Continuity Tests

    /// Helper to assert that a curve does not have slope greater than maximumSlope.
    ///
    /// **Dart Test:** `curves_test.dart:37-43`
    private func assertMaximumSlope(_ curve: any Curve, _ maximumSlope: Double, file: StaticString = #filePath, line: UInt = #line) {
        let delta = 0.005
        var x = 0.0
        while x < 1.0 - delta {
            let deltaY = curve.transform(x) - curve.transform(x + delta)
            XCTAssertLessThan(
                Swift.abs(deltaY),
                delta * maximumSlope,
                "Curve discontinuous at \(x)",
                file: file,
                line: line
            )
            x += delta
        }
    }

    /// Test that ~30 named curves are continuous.
    ///
    /// **Dart Test:** `curves_test.dart:45-86`
    func testCurveIsContinuous() {
        assertMaximumSlope(Curves.linear, 20.0)
        assertMaximumSlope(Curves.decelerate, 20.0)
        assertMaximumSlope(Curves.fastOutSlowIn, 20.0)
        assertMaximumSlope(Curves.slowMiddle, 20.0)
        assertMaximumSlope(Curves.bounceIn, 20.0)
        assertMaximumSlope(Curves.bounceOut, 20.0)
        assertMaximumSlope(Curves.bounceInOut, 20.0)
        assertMaximumSlope(Curves.elasticOut, 20.0)
        assertMaximumSlope(Curves.elasticInOut, 20.0)
        assertMaximumSlope(Curves.ease, 20.0)

        assertMaximumSlope(Curves.easeIn, 20.0)
        assertMaximumSlope(Curves.easeInSine, 20.0)
        assertMaximumSlope(Curves.easeInQuad, 20.0)
        assertMaximumSlope(Curves.easeInCubic, 20.0)
        assertMaximumSlope(Curves.easeInQuart, 20.0)
        assertMaximumSlope(Curves.easeInQuint, 20.0)
        assertMaximumSlope(Curves.easeInExpo, 20.0)
        assertMaximumSlope(Curves.easeInCirc, 20.0)

        assertMaximumSlope(Curves.easeOut, 20.0)
        assertMaximumSlope(Curves.easeOutSine, 20.0)
        assertMaximumSlope(Curves.easeOutQuad, 20.0)
        assertMaximumSlope(Curves.easeOutCubic, 20.0)
        assertMaximumSlope(Curves.easeInOutCubicEmphasized, 20.0)
        assertMaximumSlope(Curves.easeOutQuart, 20.0)
        assertMaximumSlope(Curves.easeOutQuint, 20.0)
        assertMaximumSlope(Curves.easeOutExpo, 20.0)
        assertMaximumSlope(Curves.easeOutCirc, 20.0)

        // Curves.easeInOutExpo is discontinuous at its midpoint, so not included

        assertMaximumSlope(Curves.easeInOut, 20.0)
        assertMaximumSlope(Curves.easeInOutSine, 20.0)
        assertMaximumSlope(Curves.easeInOutQuad, 20.0)
        assertMaximumSlope(Curves.easeInOutCubic, 20.0)
        assertMaximumSlope(Curves.easeInOutQuart, 20.0)
        assertMaximumSlope(Curves.easeInOutQuint, 20.0)
        assertMaximumSlope(Curves.easeInOutCirc, 20.0)
    }

    // MARK: - Bounds Tests

    /// Helper to verify a curve stays within [0, 1].
    ///
    /// **Dart Test:** `curves_test.dart:88-100`
    private func expectStaysInBounds(_ curve: any Curve, file: StaticString = #filePath, line: UInt = #line) {
        for t in stride(from: 0.0, through: 1.0, by: 0.1) {
            let value = curve.transform(t)
            XCTAssertGreaterThanOrEqual(value, 0.0, "Out of bounds at t=\(t)", file: file, line: line)
            XCTAssertLessThanOrEqual(value, 1.0, "Out of bounds at t=\(t)", file: file, line: line)
        }
    }

    /// Test that bounce curves stay within [0, 1].
    ///
    /// **Dart Test:** `curves_test.dart:102-106`
    func testBounceStaysInBounds() {
        expectStaysInBounds(Curves.bounceIn)
        expectStaysInBounds(Curves.bounceOut)
        expectStaysInBounds(Curves.bounceInOut)
    }

    // MARK: - Elastic Overshoot Tests

    /// Helper to estimate bounds of a curve over 11 sample points.
    ///
    /// **Dart Test:** `curves_test.dart:108-124`
    private func estimateBounds(_ curve: any Curve) -> (min: Double, max: Double) {
        var values: [Double] = []
        for t in stride(from: 0.0, through: 1.0, by: 0.1) {
            values.append(curve.transform(t))
        }
        return (values.min()!, values.max()!)
    }

    /// Test that elastic curves overshoot bounds.
    ///
    /// **Dart Test:** `curves_test.dart:126-141`
    func testElasticOvershootsBounds() {
        XCTAssertFalse(Curves.elasticIn.description.isEmpty)
        XCTAssertFalse(Curves.elasticOut.description.isEmpty)
        XCTAssertFalse(Curves.elasticInOut.description.isEmpty)

        var bounds = estimateBounds(Curves.elasticIn)
        XCTAssertLessThan(bounds.min, 0.0)
        XCTAssertLessThanOrEqual(bounds.max, 1.0)

        bounds = estimateBounds(Curves.elasticOut)
        XCTAssertGreaterThanOrEqual(bounds.min, 0.0)
        XCTAssertGreaterThan(bounds.max, 1.0)

        bounds = estimateBounds(Curves.elasticInOut)
        XCTAssertLessThan(bounds.min, 0.0)
        XCTAssertGreaterThan(bounds.max, 1.0)
    }

    // MARK: - Back Overshoot Tests

    /// Test that back curves overshoot bounds.
    ///
    /// **Dart Test:** `curves_test.dart:143-158`
    func testBackOvershootsBounds() {
        XCTAssertFalse(Curves.easeInBack.description.isEmpty)
        XCTAssertFalse(Curves.easeOutBack.description.isEmpty)
        XCTAssertFalse(Curves.easeInOutBack.description.isEmpty)

        var bounds = estimateBounds(Curves.easeInBack)
        XCTAssertLessThan(bounds.min, 0.0)
        XCTAssertLessThanOrEqual(bounds.max, 1.0)

        bounds = estimateBounds(Curves.easeOutBack)
        XCTAssertGreaterThanOrEqual(bounds.min, 0.0)
        XCTAssertGreaterThan(bounds.max, 1.0)

        bounds = estimateBounds(Curves.easeInOutBack)
        XCTAssertLessThan(bounds.min, 0.0)
        XCTAssertGreaterThan(bounds.max, 1.0)
    }

    // MARK: - Decelerate Tests

    /// Test that decelerate stays in bounds and rate of change decreases.
    ///
    /// **Dart Test:** `curves_test.dart:160-170`
    func testDecelerate() {
        XCTAssertFalse(Curves.decelerate.description.isEmpty)

        let bounds = estimateBounds(Curves.decelerate)
        XCTAssertGreaterThanOrEqual(bounds.min, 0.0)
        XCTAssertLessThanOrEqual(bounds.max, 1.0)

        let d1 = Curves.decelerate.transform(0.2) - Curves.decelerate.transform(0.0)
        let d2 = Curves.decelerate.transform(1.0) - Curves.decelerate.transform(0.8)
        XCTAssertLessThan(d2, d1)
    }

    // MARK: - ThreePointCubic Tests

    /// Test that ThreePointCubic interpolates through midpoint.
    ///
    /// **Dart Test:** `curves_test.dart:172-181`
    func testThreePointCubicInterpolatesMidpoint() {
        let test = ThreePointCubic(
            Offset(0.05, 0),
            Offset(0.133333, 0.06),
            Offset(0.166666, 0.4),
            Offset(0.208333, 0.82),
            Offset(0.25, 1)
        )
        XCTAssertEqual(test.transform(0.166666), 0.4)
    }

    // MARK: - Boundary Value Tests

    /// Test that transform(0) == 0 and transform(1) == 1 for all curve types.
    ///
    /// **Dart Test:** `curves_test.dart:221-266`
    func testBoundaryValues() {
        // SawTooth
        XCTAssertEqual(SawTooth(2).transform(0), 0)
        XCTAssertEqual(SawTooth(2).transform(1), 1)

        // Interval
        XCTAssertEqual(Interval(0, 1).transform(0), 0)
        XCTAssertEqual(Interval(0, 1).transform(1), 1)

        // Split
        XCTAssertEqual(Split(0.5).transform(0), 0)
        XCTAssertEqual(Split(0.5).transform(1), 1)

        // Threshold
        XCTAssertEqual(Threshold(0.5).transform(0), 0)
        XCTAssertEqual(Threshold(0.5).transform(1), 1)

        // Elastic curves
        XCTAssertEqual(ElasticInCurve().transform(0), 0)
        XCTAssertEqual(ElasticInCurve().transform(1), 1)
        XCTAssertEqual(ElasticOutCurve().transform(0), 0)
        XCTAssertEqual(ElasticOutCurve().transform(1), 1)
        XCTAssertEqual(ElasticInOutCurve().transform(0), 0)
        XCTAssertEqual(ElasticInOutCurve().transform(1), 1)

        // Named constants
        XCTAssertEqual(Curves.linear.transform(0), 0)
        XCTAssertEqual(Curves.linear.transform(1), 1)
        XCTAssertEqual(Curves.easeInOutExpo.transform(0), 0)
        XCTAssertEqual(Curves.easeInOutExpo.transform(1), 1)
        XCTAssertEqual(Curves.easeInOutCubicEmphasized.transform(0), 0)
        XCTAssertEqual(Curves.easeInOutCubicEmphasized.transform(1), 1)

        // FlippedCurve
        XCTAssertEqual(FlippedCurve(Curves.easeInOutExpo).transform(0), 0)
        XCTAssertEqual(FlippedCurve(Curves.easeInOutExpo).transform(1), 1)

        // Decelerate
        XCTAssertEqual(Curves.decelerate.transform(0), 0)
        XCTAssertEqual(Curves.decelerate.transform(1), 1)

        // Bounce
        XCTAssertEqual(Curves.bounceIn.transform(0), 0)
        XCTAssertEqual(Curves.bounceIn.transform(1), 1)
        XCTAssertEqual(Curves.bounceOut.transform(0), 0)
        XCTAssertEqual(Curves.bounceOut.transform(1), 1)
        XCTAssertEqual(Curves.bounceInOut.transform(0), 0)
        XCTAssertEqual(Curves.bounceInOut.transform(1), 1)
    }

    // MARK: - Split Interpolation Tests

    /// Test that Split interpolates values properly.
    ///
    /// **Dart Test:** `curves_test.dart:268-279`
    func testSplitInterpolation() {
        let curve = Split(0.3)
        let tolerance = 1e-6

        XCTAssertEqual(curve.transform(0.0), 0.0)
        XCTAssertEqual(curve.transform(0.1), 0.1, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.25), 0.25, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.3), 0.3)
        XCTAssertEqual(curve.transform(0.5), 0.760461, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.75), 0.962055, accuracy: tolerance)
        XCTAssertEqual(curve.transform(1.0), 1.0)
    }

    // MARK: - CatmullRomSpline Tests

    /// Test CatmullRomSpline interpolates values properly.
    ///
    /// **Dart Test:** `curves_test.dart:281-306`
    func testCatmullRomSplineInterpolation() {
        let curve = CatmullRomSpline(
            controlPoints: [
                Offset.zero,
                Offset(0.01, 0.25),
                Offset(0.2, 0.25),
                Offset(0.33, 0.25),
                Offset(0.5, 1.0),
                Offset(0.66, 0.75),
                Offset(1.0, 1.0),
            ],
            startHandle: Offset(0.0, -0.3),
            endHandle: Offset(1.3, 1.3)
        )
        let tolerance = 1e-6

        XCTAssertEqual(curve.transform(0.0).dx, 0.0, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.0).dy, 0.0, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.25).dx, 0.0966945, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.25).dy, 0.2626806, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.5).dx, 0.33, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.5).dy, 0.25, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.75).dx, 0.570260, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.75).dy, 0.883085, accuracy: tolerance)
        XCTAssertEqual(curve.transform(1.0).dx, 1.0, accuracy: tolerance)
        XCTAssertEqual(curve.transform(1.0).dy, 1.0, accuracy: tolerance)
    }

    /// Test CatmullRomSpline interpolates values properly when precomputed.
    ///
    /// **Dart Test:** `curves_test.dart:371-396`
    func testCatmullRomSplinePrecomputedInterpolation() {
        let curve = CatmullRomSpline.precompute(
            controlPoints: [
                Offset.zero,
                Offset(0.01, 0.25),
                Offset(0.2, 0.25),
                Offset(0.33, 0.25),
                Offset(0.5, 1.0),
                Offset(0.66, 0.75),
                Offset(1.0, 1.0),
            ],
            startHandle: Offset(0.0, -0.3),
            endHandle: Offset(1.3, 1.3)
        )
        let tolerance = 1e-6

        XCTAssertEqual(curve.transform(0.0).dx, 0.0, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.0).dy, 0.0, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.25).dx, 0.0966945, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.25).dy, 0.2626806, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.5).dx, 0.33, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.5).dy, 0.25, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.75).dx, 0.570260, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.75).dy, 0.883085, accuracy: tolerance)
        XCTAssertEqual(curve.transform(1.0).dx, 1.0, accuracy: tolerance)
        XCTAssertEqual(curve.transform(1.0).dy, 1.0, accuracy: tolerance)
    }

    // MARK: - CatmullRomCurve Tests

    /// Test CatmullRomCurve interpolation.
    ///
    /// Note: Tolerance is wider than Dart (1e-3 vs 1e-6) because our SeededRandom
    /// LCG produces different sample points than Dart's math.Random(seed), leading
    /// to slightly different interpolation results while remaining mathematically correct.
    ///
    /// **Dart Test:** `curves_test.dart:461-479`
    func testCatmullRomCurveInterpolation() {
        let curve = CatmullRomCurve(controlPoints: [
            Offset(0.2, 0.25),
            Offset(0.33, 0.25),
            Offset(0.5, 1.0),
            Offset(0.8, 0.75),
        ])
        let tolerance = 1e-3

        XCTAssertEqual(curve.transform(0.0), 0.0, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.01), 0.012874734350170863, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.2), 0.24989646045277542, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.33), 0.250037698527661, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.5), 0.9999057323235939, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.6), 0.9357294964536621, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.8), 0.7500423402378034, accuracy: tolerance)
        XCTAssertEqual(curve.transform(1.0), 1.0, accuracy: tolerance)
    }

    /// Test CatmullRomCurve interpolation when precomputed.
    ///
    /// Note: Tolerance is wider than Dart (1e-3 vs 1e-6) because our SeededRandom
    /// LCG produces different sample points than Dart's math.Random(seed).
    ///
    /// **Dart Test:** `curves_test.dart:481-499`
    func testCatmullRomCurvePrecomputedInterpolation() {
        let curve = CatmullRomCurve.precompute(controlPoints: [
            Offset(0.2, 0.25),
            Offset(0.33, 0.25),
            Offset(0.5, 1.0),
            Offset(0.8, 0.75),
        ])
        let tolerance = 1e-3

        XCTAssertEqual(curve.transform(0.0), 0.0, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.01), 0.012874734350170863, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.2), 0.24989646045277542, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.33), 0.250037698527661, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.5), 0.9999057323235939, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.6), 0.9357294964536621, accuracy: tolerance)
        XCTAssertEqual(curve.transform(0.8), 0.7500423402378034, accuracy: tolerance)
        XCTAssertEqual(curve.transform(1.0), 1.0, accuracy: tolerance)
    }

    /// Test CatmullRomCurve.validateControlPoints returns failure reasons.
    ///
    /// **Dart Test:** `curves_test.dart:501-564`
    func testCatmullRomCurveValidateControlPoints() {
        // Monotonically increasing in X
        XCTAssertNotNil(
            CatmullRomCurve.validateControlPoints([Offset(0.2, 0.25), Offset(0.01, 0.25)])
        )

        // X within range (0.0, 1.0)
        XCTAssertNotNil(
            CatmullRomCurve.validateControlPoints([Offset(0.2, 0.25), Offset(1.01, 0.25)])
        )

        // Not multi-valued in Y at x=0.0
        XCTAssertNotNil(
            CatmullRomCurve.validateControlPoints([
                Offset(0.05, 0.50),
                Offset(0.50, 0.50),
                Offset(0.75, 0.75),
            ])
        )

        // Not multi-valued in Y at x=1.0
        XCTAssertNotNil(
            CatmullRomCurve.validateControlPoints([
                Offset(0.25, 0.25),
                Offset(0.50, 0.50),
                Offset(0.95, 0.51),
            ])
        )

        // Not multi-valued in Y in between x = 0.0 and x = 1.0
        XCTAssertNotNil(
            CatmullRomCurve.validateControlPoints([Offset(0.5, 0.05), Offset(0.5, 0.95)])
        )

        // Valid control points should return nil
        XCTAssertNil(
            CatmullRomCurve.validateControlPoints([
                Offset(0.2, 0.25),
                Offset(0.33, 0.25),
                Offset(0.5, 1.0),
                Offset(0.8, 0.75),
            ])
        )
    }
}

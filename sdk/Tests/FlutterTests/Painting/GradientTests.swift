// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Gradient types.
///
/// **Dart Test Source:** `packages/flutter/test/painting/gradient_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Helpers

/// Approximate comparison for [Double] lists, matching Dart's _listDoubleMatches.
///
/// **Dart Test Source:** `gradient_test.dart:15-31`
private func listDoubleMatches(_ x: [Double]?, _ y: [Double]?) -> Bool {
    if x == nil && y == nil { return true }
    guard let x = x, let y = y else { return false }
    if x.count != y.count { return false }
    for i in 0..<x.count {
        if Swift.abs(x[i] - y[i]) >= 0.0001 { return false }
    }
    return true
}

/// Approximate comparison for [Color] lists, matching Dart's _listColorMatches.
///
/// **Dart Test Source:** `gradient_test.dart:33-47`
private func listColorMatches(_ x: [Color], _ y: [Color]) -> Bool {
    if x.count != y.count { return false }
    let limit: Double = 1.0 / 255.0
    for i in 0..<x.count {
        if Swift.abs(x[i].a - y[i].a) >= limit ||
           Swift.abs(x[i].r - y[i].r) >= limit ||
           Swift.abs(x[i].g - y[i].g) >= limit ||
           Swift.abs(x[i].b - y[i].b) >= limit {
            return false
        }
    }
    return true
}

/// Checks if a LinearGradient approximately matches the target.
///
/// **Dart Test Source:** `gradient_test.dart:49-71`
private func matchesLinearGradient(_ actual: GradientBase?, _ target: LinearGradient) -> Bool {
    guard let actual = actual as? LinearGradient else { return false }
    return actual.begin == target.begin &&
        actual.end == target.end &&
        actual.tileMode == target.tileMode &&
        actual.transform == target.transform &&
        listColorMatches(actual.colors, target.colors) &&
        listDoubleMatches(actual.stops, target.stops)
}

/// Checks if a RadialGradient approximately matches the target.
///
/// **Dart Test Source:** `gradient_test.dart:73-100`
private func matchesRadialGradient(_ actual: GradientBase?, _ target: RadialGradient) -> Bool {
    guard let actual = actual as? RadialGradient else { return false }
    // Compare focal alignment
    let focalMatch: Bool
    if actual.focal == nil && target.focal == nil {
        focalMatch = true
    } else if let af = actual.focal, let tf = target.focal {
        focalMatch = af == tf
    } else {
        focalMatch = false
    }
    return actual.center == target.center &&
        actual.radius == target.radius &&
        actual.tileMode == target.tileMode &&
        actual.transform == target.transform &&
        focalMatch &&
        actual.focalRadius == target.focalRadius &&
        listColorMatches(actual.colors, target.colors) &&
        listDoubleMatches(actual.stops, target.stops)
}

/// Checks if a SweepGradient approximately matches the target.
///
/// **Dart Test Source:** `gradient_test.dart:102-128`
private func matchesSweepGradient(_ actual: GradientBase?, _ target: SweepGradient) -> Bool {
    guard let actual = actual as? SweepGradient else { return false }
    return actual.center == target.center &&
        actual.startAngle == target.startAngle &&
        actual.endAngle == target.endAngle &&
        actual.tileMode == target.tileMode &&
        actual.transform == target.transform &&
        listColorMatches(actual.colors, target.colors) &&
        listDoubleMatches(actual.stops, target.stops)
}

// MARK: - Tests

final class GradientTests: XCTestCase {

    // MARK: - LinearGradient Scale Tests

    /// **Dart Test Source:** `gradient_test.dart:131-149`
    func testLinearGradientScale() {
        let testGradient = LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment(0.7, 1.0),
            colors: [Color(0x00FFFFFF), Color(0x11777777), Color(0x44444444)]
        )
        let actual = LinearGradient.lerp(nil, testGradient, 0.25)

        XCTAssertTrue(matchesLinearGradient(actual, LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment(0.7, 1.0),
            colors: [Color(0x00FFFFFF), Color(0x04777777), Color(0x11444444)]
        )))
    }

    // MARK: - LinearGradient Lerp Tests

    /// **Dart Test Source:** `gradient_test.dart:151-175`
    func testLinearGradientLerp() {
        let testGradient1 = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
            colors: [Color(0x33333333), Color(0x66666666)]
        )
        let testGradient2 = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.topLeft,
            colors: [Color(0x44444444), Color(0x88888888)]
        )

        let actual = LinearGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesLinearGradient(actual, LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.centerLeft,
            colors: [Color(0x3B3B3B3B), Color(0x77777777)],
            stops: [0, 1]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:177-183`
    func testLinearGradientLerpIdentical() {
        XCTAssertNil(LinearGradient.lerp(nil, nil, 0))
        let gradient = LinearGradient(
            colors: [Color(0x33333333), Color(0x66666666)]
        )
        XCTAssertTrue(LinearGradient.lerp(gradient, gradient, 0.5) === gradient)
    }

    /// **Dart Test Source:** `gradient_test.dart:185-211`
    func testLinearGradientLerpWithStops() {
        let testGradient1 = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0.0, 0.5]
        )
        let testGradient2 = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.topLeft,
            colors: [Color(0x44444444), Color(0x88888888)],
            stops: [0.5, 1.0]
        )

        let actual = LinearGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesLinearGradient(actual, LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.centerLeft,
            colors: [Color(0x3B3B3B3B), Color(0x55555555), Color(0x77777777)],
            stops: [0.0, 0.5, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:213-231`
    func testLinearGradientLerpWithUnequalColors() {
        let testGradient1 = LinearGradient(
            colors: [Color(0x22222222), Color(0x66666666)]
        )
        let testGradient2 = LinearGradient(
            colors: [Color(0x44444444), Color(0x66666666), Color(0x88888888)]
        )

        let actual = LinearGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesLinearGradient(actual, LinearGradient(
            colors: [Color(0x33333333), Color(0x55555555), Color(0x77777777)],
            stops: [0.0, 0.5, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:233-258`
    func testLinearGradientLerpWithStopsAndUnequalColors() {
        let testGradient1 = LinearGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0.0, 0.5]
        )
        let testGradient2 = LinearGradient(
            colors: [Color(0x44444444), Color(0x48484848), Color(0x88888888)],
            stops: [0.5, 0.7, 1.0]
        )

        let actual = LinearGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesLinearGradient(actual, LinearGradient(
            colors: [
                Color(0x3B3B3B3B),
                Color(0x55555555),
                Color(0x57575757),
                Color(0x77777777),
            ],
            stops: [0.0, 0.5, 0.7, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:260-278`
    func testLinearGradientLerpWithTransforms() {
        let testGradient1 = LinearGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0, 1],
            transform: AnyGradientTransform(GradientRotation(Double.pi / 4))
        )
        let testGradient2 = LinearGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0, 1],
            transform: AnyGradientTransform(GradientRotation(Double.pi / 2))
        )

        let actual0 = LinearGradient.lerp(testGradient1, testGradient2, 0.0)
        let actual1 = LinearGradient.lerp(testGradient1, testGradient2, 1.0)
        let actual2 = LinearGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertEqual(testGradient1, actual0)
        XCTAssertEqual(testGradient2, actual1)
        XCTAssertEqual(testGradient2, actual2)
    }

    /// **Dart Test Source:** `gradient_test.dart:294-310`
    func testLinearGradientWithDifferentTransforms() {
        let testGradient1 = LinearGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            transform: AnyGradientTransform(GradientRotation(Double.pi / 4))
        )
        let testGradient1Copy = LinearGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            transform: AnyGradientTransform(GradientRotation(Double.pi / 4))
        )
        let testGradient2 = LinearGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            transform: AnyGradientTransform(GradientRotation(Double.pi / 2))
        )

        XCTAssertEqual(testGradient1, testGradient1Copy)
        XCTAssertNotEqual(testGradient1, testGradient2)
    }

    /// **Dart Test Source:** `gradient_test.dart:312-337`
    func testLinearGradientWithAlignmentDirectional() {
        // Without textDirection should fail assert
        // With textDirection should succeed
        let gradient = LinearGradient(
            begin: AlignmentDirectional.topStart,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]
        )
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 100.0)

        // With text direction should work fine
        let _ = gradient.createShader(rect: rect, textDirection: .rtl)
        let _ = gradient.createShader(rect: rect, textDirection: .ltr)

        // Non-directional alignment should work without text direction
        let gradient2 = LinearGradient(
            begin: Alignment.topLeft,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]
        )
        let _ = gradient2.createShader(rect: rect)
    }

    /// **Dart Test Source:** `gradient_test.dart:339-355`
    func testLinearGradientWithOpacity() {
        let testGradient = LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topCenter,
            colors: [Color(0xFFFFFFFF), Color(0xAF777777), Color(0x44444444)]
        )
        let actual = testGradient.withOpacity(0.5)

        XCTAssertEqual(actual, LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topCenter,
            colors: [Color(0x80FFFFFF), Color(0x80777777), Color(0x80444444)]
        ))
    }

    /// **Dart Test Source:** `gradient_test.dart:357-375`
    func testLinearGradientWithOpacityPreservesTransform() {
        let testGradient = LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topCenter,
            colors: [Color(0xFFFFFFFF), Color(0xAF777777), Color(0x44444444)],
            transform: AnyGradientTransform(GradientRotation(1))
        )
        let actual = testGradient.withOpacity(0.5)

        XCTAssertEqual(actual, LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topCenter,
            colors: [Color(0x80FFFFFF), Color(0x80777777), Color(0x80444444)],
            transform: AnyGradientTransform(GradientRotation(1))
        ))
    }

    // MARK: - RadialGradient Tests

    /// **Dart Test Source:** `gradient_test.dart:377-403`
    func testRadialGradientWithAlignmentDirectional() {
        let gradient = RadialGradient(
            center: AlignmentDirectional.topStart,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]
        )
        let rect = Rect.fromLTWH(0.0, 0.0, 100.0, 100.0)

        // With text direction should work fine
        let _ = gradient.createShader(rect: rect, textDirection: .rtl)
        let _ = gradient.createShader(rect: rect, textDirection: .ltr)

        // Non-directional alignment should work without text direction
        let gradient2 = RadialGradient(
            center: Alignment.topLeft,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]
        )
        let _ = gradient2.createShader(rect: rect)
    }

    /// **Dart Test Source:** `gradient_test.dart:405-429`
    func testRadialGradientLerp() {
        let testGradient1 = RadialGradient(
            center: Alignment.topLeft,
            radius: 20.0,
            colors: [Color(0x33333333), Color(0x66666666)]
        )
        let testGradient2 = RadialGradient(
            center: Alignment.topRight,
            radius: 10.0,
            colors: [Color(0x44444444), Color(0x88888888)]
        )

        let actual = RadialGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesRadialGradient(actual, RadialGradient(
            center: Alignment.topCenter,
            radius: 15.0,
            colors: [Color(0x3B3B3B3B), Color(0x77777777)],
            stops: [0.0, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:431-437`
    func testRadialGradientLerpIdentical() {
        XCTAssertNil(RadialGradient.lerp(nil, nil, 0))
        let gradient = RadialGradient(
            colors: [Color(0x33333333), Color(0x66666666)]
        )
        XCTAssertTrue(RadialGradient.lerp(gradient, gradient, 0.5) === gradient)
    }

    /// **Dart Test Source:** `gradient_test.dart:439-468`
    func testRadialGradientLerpWithStops() {
        let testGradient1 = RadialGradient(
            center: Alignment.topLeft,
            radius: 20.0,
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0.0, 0.5]
        )
        let testGradient2 = RadialGradient(
            center: Alignment.topRight,
            radius: 10.0,
            colors: [Color(0x44444444), Color(0x88888888)],
            stops: [0.5, 1.0]
        )

        let actual = RadialGradient.lerp(testGradient1, testGradient2, 0.5)

        XCTAssertTrue(matchesRadialGradient(actual, RadialGradient(
            center: Alignment.topCenter,
            radius: 15.0,
            colors: [Color(0x3B3B3B3B), Color(0x55555555), Color(0x77777777)],
            stops: [0.0, 0.5, 1.0]
        )))

        XCTAssertNil((actual as? RadialGradient)?.focal)
    }

    /// **Dart Test Source:** `gradient_test.dart:470-488`
    func testRadialGradientLerpWithUnequalColors() {
        let testGradient1 = RadialGradient(
            colors: [Color(0x22222222), Color(0x66666666)]
        )
        let testGradient2 = RadialGradient(
            colors: [Color(0x44444444), Color(0x66666666), Color(0x88888888)]
        )

        let actual = RadialGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesRadialGradient(actual, RadialGradient(
            colors: [Color(0x33333333), Color(0x55555555), Color(0x77777777)],
            stops: [0.0, 0.5, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:490-515`
    func testRadialGradientLerpWithStopsAndUnequalColors() {
        let testGradient1 = RadialGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0.0, 0.5]
        )
        let testGradient2 = RadialGradient(
            colors: [Color(0x44444444), Color(0x48484848), Color(0x88888888)],
            stops: [0.5, 0.7, 1.0]
        )

        let actual = RadialGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesRadialGradient(actual, RadialGradient(
            colors: [
                Color(0x3B3B3B3B),
                Color(0x55555555),
                Color(0x57575757),
                Color(0x77777777),
            ],
            stops: [0.0, 0.5, 0.7, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:517-535`
    func testRadialGradientLerpWithTransforms() {
        let testGradient1 = RadialGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0, 1],
            transform: AnyGradientTransform(GradientRotation(Double.pi / 4))
        )
        let testGradient2 = RadialGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0, 1],
            transform: AnyGradientTransform(GradientRotation(Double.pi / 2))
        )

        let actual0 = RadialGradient.lerp(testGradient1, testGradient2, 0.0)
        let actual1 = RadialGradient.lerp(testGradient1, testGradient2, 1.0)
        let actual2 = RadialGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertEqual(testGradient1, actual0)
        XCTAssertEqual(testGradient2, actual1)
        XCTAssertEqual(testGradient2, actual2)
    }

    /// **Dart Test Source:** `gradient_test.dart:537-587`
    func testRadialGradientLerpWithFocal() {
        let testGradient1 = RadialGradient(
            center: Alignment.topLeft,
            radius: 20.0,
            colors: [Color(0x33333333), Color(0x66666666)],
            focal: Alignment.centerLeft,
            focalRadius: 10.0
        )
        let testGradient2 = RadialGradient(
            center: Alignment.topRight,
            radius: 10.0,
            colors: [Color(0x44444444), Color(0x88888888)],
            focal: Alignment.centerRight,
            focalRadius: 5.0
        )
        let testGradient3 = RadialGradient(
            center: Alignment.topRight,
            radius: 10.0,
            colors: [Color(0x44444444), Color(0x88888888)]
        )

        let actual = RadialGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesRadialGradient(actual, RadialGradient(
            center: Alignment.topCenter,
            radius: 15.0,
            colors: [Color(0x3B3B3B3B), Color(0x77777777)],
            stops: [0.0, 1.0],
            focal: Alignment.center,
            focalRadius: 7.5
        )))

        let actual2 = RadialGradient.lerp(testGradient1, testGradient3, 0.5)
        XCTAssertTrue(matchesRadialGradient(actual2, RadialGradient(
            center: Alignment.topCenter,
            radius: 15.0,
            colors: [Color(0x3B3B3B3B), Color(0x77777777)],
            stops: [0.0, 1.0],
            focal: Alignment(-0.5, 0.0),
            focalRadius: 5.0
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:589-609`
    func testRadialGradientWithOpacity() {
        let testGradient = RadialGradient(
            center: Alignment.topLeft,
            radius: 20.0,
            colors: [Color(0xFFFFFFFF), Color(0xAF777777), Color(0x44444444)],
            focal: Alignment.centerLeft,
            focalRadius: 10.0
        )
        let actual = testGradient.withOpacity(0.5)

        XCTAssertEqual(actual, RadialGradient(
            center: Alignment.topLeft,
            radius: 20.0,
            colors: [Color(0x80FFFFFF), Color(0x80777777), Color(0x80444444)],
            focal: Alignment.centerLeft,
            focalRadius: 10.0
        ))
    }

    /// **Dart Test Source:** `gradient_test.dart:611-633`
    func testRadialGradientWithOpacityPreservesTransform() {
        let testGradient = RadialGradient(
            center: Alignment.topLeft,
            radius: 20.0,
            colors: [Color(0xFFFFFFFF), Color(0xAF777777), Color(0x44444444)],
            focal: Alignment.centerLeft,
            focalRadius: 10.0,
            transform: AnyGradientTransform(GradientRotation(1))
        )
        let actual = testGradient.withOpacity(0.5)

        XCTAssertEqual(actual, RadialGradient(
            center: Alignment.topLeft,
            radius: 20.0,
            colors: [Color(0x80FFFFFF), Color(0x80777777), Color(0x80444444)],
            focal: Alignment.centerLeft,
            focalRadius: 10.0,
            transform: AnyGradientTransform(GradientRotation(1))
        ))
    }

    // MARK: - SweepGradient Tests

    /// **Dart Test Source:** `gradient_test.dart:635-661`
    func testSweepGradientLerp() {
        let testGradient1 = SweepGradient(
            center: Alignment.topLeft,
            endAngle: Double.pi / 2,
            colors: [Color(0x33333333), Color(0x66666666)]
        )
        let testGradient2 = SweepGradient(
            center: Alignment.topRight,
            startAngle: Double.pi / 2,
            endAngle: Double.pi,
            colors: [Color(0x44444444), Color(0x88888888)]
        )

        let actual = SweepGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesSweepGradient(actual, SweepGradient(
            center: Alignment.topCenter,
            startAngle: Double.pi / 4,
            endAngle: Double.pi * 3 / 4,
            colors: [Color(0x3B3B3B3B), Color(0x77777777)],
            stops: [0.0, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:663-669`
    func testSweepGradientLerpIdentical() {
        XCTAssertNil(SweepGradient.lerp(nil, nil, 0))
        let gradient = SweepGradient(
            colors: [Color(0x33333333), Color(0x66666666)]
        )
        XCTAssertTrue(SweepGradient.lerp(gradient, gradient, 0.5) === gradient)
    }

    /// **Dart Test Source:** `gradient_test.dart:671-699`
    func testSweepGradientLerpWithStops() {
        let testGradient1 = SweepGradient(
            center: Alignment.topLeft,
            endAngle: Double.pi / 2,
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0.0, 0.5]
        )
        let testGradient2 = SweepGradient(
            center: Alignment.topRight,
            startAngle: Double.pi / 2,
            endAngle: Double.pi,
            colors: [Color(0x44444444), Color(0x88888888)],
            stops: [0.5, 1.0]
        )

        let actual = SweepGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesSweepGradient(actual, SweepGradient(
            center: Alignment.topCenter,
            startAngle: Double.pi / 4,
            endAngle: Double.pi * 3 / 4,
            colors: [Color(0x3B3B3B3B), Color(0x55555555), Color(0x77777777)],
            stops: [0.0, 0.5, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:701-719`
    func testSweepGradientLerpWithUnequalColors() {
        let testGradient1 = SweepGradient(
            colors: [Color(0x22222222), Color(0x66666666)]
        )
        let testGradient2 = SweepGradient(
            colors: [Color(0x44444444), Color(0x66666666), Color(0x88888888)]
        )

        let actual = SweepGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesSweepGradient(actual, SweepGradient(
            colors: [Color(0x33333333), Color(0x55555555), Color(0x77777777)],
            stops: [0.0, 0.5, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:721-746`
    func testSweepGradientLerpWithStopsAndUnequalColors() {
        let testGradient1 = SweepGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0.0, 0.5]
        )
        let testGradient2 = SweepGradient(
            colors: [Color(0x44444444), Color(0x48484848), Color(0x88888888)],
            stops: [0.5, 0.7, 1.0]
        )

        let actual = SweepGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertTrue(matchesSweepGradient(actual, SweepGradient(
            colors: [
                Color(0x3B3B3B3B),
                Color(0x55555555),
                Color(0x57575757),
                Color(0x77777777),
            ],
            stops: [0.0, 0.5, 0.7, 1.0]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:748-766`
    func testSweepGradientLerpWithTransforms() {
        let testGradient1 = SweepGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0, 1],
            transform: AnyGradientTransform(GradientRotation(Double.pi / 4))
        )
        let testGradient2 = SweepGradient(
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0, 1],
            transform: AnyGradientTransform(GradientRotation(Double.pi / 2))
        )

        let actual0 = SweepGradient.lerp(testGradient1, testGradient2, 0.0)
        let actual1 = SweepGradient.lerp(testGradient1, testGradient2, 1.0)
        let actual2 = SweepGradient.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertEqual(testGradient1, actual0)
        XCTAssertEqual(testGradient2, actual1)
        XCTAssertEqual(testGradient2, actual2)
    }

    /// **Dart Test Source:** `gradient_test.dart:768-787`
    func testSweepGradientScale() {
        let testGradient = SweepGradient(
            center: Alignment.topLeft,
            endAngle: Double.pi / 2,
            colors: [Color(0xff333333), Color(0xff666666)]
        )

        let actual = testGradient.scale(0.5)

        XCTAssertTrue(matchesSweepGradient(actual, SweepGradient(
            center: Alignment.topLeft,
            endAngle: Double.pi / 2,
            colors: [Color(0x80333333), Color(0x80666666)]
        )))
    }

    /// **Dart Test Source:** `gradient_test.dart:789-805`
    func testSweepGradientWithOpacity() {
        let testGradient = SweepGradient(
            center: Alignment.topLeft,
            endAngle: Double.pi / 2,
            colors: [Color(0xFFFFFFFF), Color(0xAF777777), Color(0x44444444)]
        )
        let actual = testGradient.withOpacity(0.5)

        XCTAssertEqual(actual, SweepGradient(
            center: Alignment.topLeft,
            endAngle: Double.pi / 2,
            colors: [Color(0x80FFFFFF), Color(0x80777777), Color(0x80444444)]
        ))
    }

    /// **Dart Test Source:** `gradient_test.dart:807-825`
    func testSweepGradientWithOpacityPreservesTransform() {
        let testGradient = SweepGradient(
            center: Alignment.topLeft,
            endAngle: Double.pi / 2,
            colors: [Color(0xFFFFFFFF), Color(0xAF777777), Color(0x44444444)],
            transform: AnyGradientTransform(GradientRotation(1.0))
        )
        let actual = testGradient.withOpacity(0.5)

        XCTAssertEqual(actual, SweepGradient(
            center: Alignment.topLeft,
            endAngle: Double.pi / 2,
            colors: [Color(0x80FFFFFF), Color(0x80777777), Color(0x80444444)],
            transform: AnyGradientTransform(GradientRotation(1.0))
        ))
    }

    // MARK: - Cross-type Gradient.lerp Tests

    /// **Dart Test Source:** `gradient_test.dart:827-853`
    func testGradientLerpWithRadialGradient() {
        let testGradient1 = RadialGradient(
            center: Alignment.topLeft,
            radius: 20.0,
            colors: [Color(0x33333333), Color(0x66666666)],
            stops: [0.0, 1.0]
        )
        let testGradient2 = RadialGradient(
            center: Alignment.topCenter,
            radius: 15.0,
            colors: [Color(0x3B3B3B3B), Color(0x77777777)],
            stops: [0.0, 1.0]
        )
        let testGradient3 = RadialGradient(
            center: Alignment.topRight,
            radius: 10.0,
            colors: [Color(0x44444444), Color(0x88888888)],
            stops: [0.0, 1.0]
        )

        XCTAssertTrue(matchesRadialGradient(GradientBase.lerp(testGradient1, testGradient3, 0.0), testGradient1))
        XCTAssertTrue(matchesRadialGradient(GradientBase.lerp(testGradient1, testGradient3, 0.5), testGradient2))
        XCTAssertTrue(matchesRadialGradient(GradientBase.lerp(testGradient1, testGradient3, 1.0), testGradient3))
        XCTAssertTrue(matchesRadialGradient(GradientBase.lerp(testGradient3, testGradient1, 0.0), testGradient3))
        XCTAssertTrue(matchesRadialGradient(GradientBase.lerp(testGradient3, testGradient1, 0.5), testGradient2))
        XCTAssertTrue(matchesRadialGradient(GradientBase.lerp(testGradient3, testGradient1, 1.0), testGradient1))
    }

    /// **Dart Test Source:** `gradient_test.dart:855-869`
    func testGradientLerpLinearToRadial() {
        let testGradient1 = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x33333333), Color(0x66666666)]
        )
        let testGradient2 = RadialGradient(
            radius: 20.0,
            colors: [Color(0x44444444), Color(0x88888888)]
        )

        XCTAssertEqual(GradientBase.lerp(testGradient1, testGradient2, 0.0) as? LinearGradient, testGradient1)
        XCTAssertEqual(GradientBase.lerp(testGradient1, testGradient2, 1.0) as? RadialGradient, testGradient2)
        // At 0.5, cross-type lerp falls back to scale
        let result = GradientBase.lerp(testGradient1, testGradient2, 0.5)
        XCTAssertEqual(result as? RadialGradient, testGradient2.scale(0.0))
    }

    /// **Dart Test Source:** `gradient_test.dart:871-895`
    func testGradientsCanHandleMissingStops() {
        let test1a = LinearGradient(
            colors: [Color(0x11111111), Color(0x22222222), Color(0x33333333)]
        )
        let test1b = RadialGradient(
            colors: [Color(0x11111111), Color(0x22222222), Color(0x33333333)]
        )
        let rect = Rect.fromLTWH(1.0, 2.0, 3.0, 4.0)

        // These should succeed (implied stops are generated)
        let _ = test1a.createShader(rect: rect)
        let _ = test1b.createShader(rect: rect)
    }

    // MARK: - GradientRotation Tests

    /// Test that GradientRotation equality works.
    func testGradientRotationEquality() {
        let r1 = GradientRotation(Double.pi / 4)
        let r2 = GradientRotation(Double.pi / 4)
        let r3 = GradientRotation(Double.pi / 2)

        XCTAssertEqual(r1, r2)
        XCTAssertNotEqual(r1, r3)
    }

    /// Test that GradientRotation hash is consistent.
    func testGradientRotationHash() {
        let r1 = GradientRotation(Double.pi / 4)
        let r2 = GradientRotation(Double.pi / 4)

        XCTAssertEqual(r1.hashValue, r2.hashValue)
    }

    /// Test GradientRotation transform produces a valid matrix.
    func testGradientRotationTransform() {
        let rotation = GradientRotation(Double.pi / 4)
        let bounds = Rect.fromLTWH(0.0, 0.0, 300.0, 400.0)
        let matrix = rotation.transform(bounds: bounds, textDirection: nil)

        XCTAssertNotNil(matrix)
        // The matrix should have 16 elements
        XCTAssertEqual(matrix!.storage.count, 16)
    }

    /// Test GradientRotation description.
    func testGradientRotationDescription() {
        let rotation = GradientRotation(1.6)
        let desc = rotation.description
        XCTAssertTrue(desc.contains("GradientRotation"))
        XCTAssertTrue(desc.contains("radians"))
        XCTAssertTrue(desc.contains("1.6"))
    }

    // MARK: - AnyGradientTransform Tests

    /// Test AnyGradientTransform equality.
    func testAnyGradientTransformEquality() {
        let t1 = AnyGradientTransform(GradientRotation(Double.pi / 4))
        let t2 = AnyGradientTransform(GradientRotation(Double.pi / 4))
        let t3 = AnyGradientTransform(GradientRotation(Double.pi / 2))

        XCTAssertEqual(t1, t2)
        XCTAssertNotEqual(t1, t3)
    }

    /// Test AnyGradientTransform delegates transform correctly.
    func testAnyGradientTransformDelegation() {
        let wrapped = GradientRotation(Double.pi / 4)
        let anyTransform = AnyGradientTransform(wrapped)
        let bounds = Rect.fromLTWH(0.0, 0.0, 300.0, 400.0)

        let m1 = wrapped.transform(bounds: bounds, textDirection: nil)
        let m2 = anyTransform.transform(bounds: bounds, textDirection: nil)

        XCTAssertEqual(m1, m2)
    }

    // MARK: - GradientBase Static Lerp Tests

    /// Test GradientBase.lerp with both nil returns nil.
    func testGradientBaseLerpBothNil() {
        XCTAssertNil(GradientBase.lerp(nil, nil, 0.5))
    }

    // MARK: - Gradient Shader Creation Tests

    /// Test that gradients with transforms can create shaders.
    func testGradientWithTransformCreatesShader() {
        let colors: [Color] = [Color(0xFFFFFFFF), Color(0xFF000088)]
        let rect = Rect.fromLTWH(0.0, 0.0, 300.0, 400.0)

        let linear = LinearGradient(
            colors: colors,
            transform: AnyGradientTransform(GradientRotation(Double.pi / 4))
        )
        let radial = RadialGradient(
            center: Alignment.topCenter,
            colors: colors,
            transform: AnyGradientTransform(GradientRotation(Double.pi / 4))
        )
        let sweep = SweepGradient(
            colors: colors,
            transform: AnyGradientTransform(GradientRotation(Double.pi / 4))
        )

        // These should all succeed without error
        let _ = linear.createShader(rect: rect)
        let _ = radial.createShader(rect: rect)
        let _ = sweep.createShader(rect: rect)
    }
}

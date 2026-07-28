// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for Colors (HSVColor, HSLColor, ColorSwatch, ColorProperty).
///
/// **Dart Test Source:** `packages/flutter/test/painting/colors_test.dart`

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class ColorsTests: XCTestCase {

    let _doubleColorPrecision: Double = 0.01

    // MARK: - Helper

    /// Asserts that two doubles are approximately equal within the given precision.
    func assertClose(_ actual: Double, _ expected: Double, accuracy: Double? = nil, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        let acc = accuracy ?? _doubleColorPrecision
        XCTAssertEqual(actual, expected, accuracy: acc, message, file: file, line: line)
    }

    /// Asserts that two Colors are approximately the same by comparing their ARGB32 values.
    func assertSameColor(_ actual: Color, _ expected: Color, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.toARGB32(), expected.toARGB32(), "\(message) actual=\(actual) expected=\(expected)", file: file, line: line)
    }

    // MARK: - HSVColor Control Test

    /// **Dart Source:** `colors_test.dart:12-35`
    func testHSVColorControlTest() {
        let color = HSVColor.fromAHSV(0.7, 28.0, 0.3, 0.6)

        // Test description is one line
        XCTAssertFalse(color.description.contains("\n"))

        // Test hashCode equality
        XCTAssertEqual(color.hashValue, HSVColor.fromAHSV(0.7, 28.0, 0.3, 0.6).hashValue)

        // Test with methods
        XCTAssertEqual(color.withAlpha(0.8), HSVColor.fromAHSV(0.8, 28.0, 0.3, 0.6))
        XCTAssertEqual(color.withHue(123.0), HSVColor.fromAHSV(0.7, 123.0, 0.3, 0.6))
        XCTAssertEqual(color.withSaturation(0.9), HSVColor.fromAHSV(0.7, 28.0, 0.9, 0.6))
        XCTAssertEqual(color.withValue(0.1), HSVColor.fromAHSV(0.7, 28.0, 0.3, 0.1))

        // Test toColor
        XCTAssertEqual(color.toColor(), Color(0xb399816b))

        // Test lerp
        let result = HSVColor.lerp(
            color,
            HSVColor.fromAHSV(0.3, 128.0, 0.7, 0.2),
            0.25
        )!
        assertClose(result.alpha, 0.6)
        assertClose(result.hue, 53.0)
        XCTAssertGreaterThan(result.saturation, 0.3999)
        XCTAssertLessThan(result.saturation, 0.4001)
        assertClose(result.value, 0.5)
    }

    // MARK: - HSVColor Hue Sweep Test

    /// **Dart Source:** `colors_test.dart:37-65`
    func testHSVColorHueSweep() {
        var output: [Color] = []
        var hue = 0.0
        while hue <= 360.0 {
            let hsvColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0)
            let color = hsvColor.toColor()
            output.append(color)
            if hue != 360.0 {
                // Check that it's reversible
                let reversed = HSVColor.fromColor(color)
                assertClose(reversed.alpha, hsvColor.alpha)
                assertClose(reversed.hue, hsvColor.hue, accuracy: 1.0)
                assertClose(reversed.saturation, hsvColor.saturation)
                assertClose(reversed.value, hsvColor.value)
            }
            hue += 36.0
        }
        let expectedColors: [Color] = [
            Color(0xffff0000),
            Color(0xffff9900),
            Color(0xffccff00),
            Color(0xff33ff00),
            Color(0xff00ff66),
            Color(0xff00ffff),
            Color(0xff0066ff),
            Color(0xff3300ff),
            Color(0xffcc00ff),
            Color(0xffff0099),
            Color(0xffff0000),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "hue sweep index \(i)")
        }
    }

    // MARK: - HSVColor Saturation Sweep Test

    /// **Dart Source:** `colors_test.dart:67-93`
    func testHSVColorSaturationSweep() {
        var output: [Color] = []
        // Use cumulative addition (matching Dart behavior) but with a fixed
        // iteration count to avoid Swift float loop boundary issues.
        var saturation = 0.0
        for _ in 0..<10 {
            let hsvColor = HSVColor.fromAHSV(1.0, 0.0, saturation, 1.0)
            let color = hsvColor.toColor()
            output.append(color)
            // Check reversible
            let reversed = HSVColor.fromColor(color)
            assertClose(reversed.alpha, hsvColor.alpha)
            assertClose(reversed.hue, hsvColor.hue, accuracy: 1.0)
            assertClose(reversed.saturation, hsvColor.saturation)
            assertClose(reversed.value, hsvColor.value)
            saturation += 0.1
        }
        // Add final value at saturation = 1.0
        output.append(HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0).toColor())

        let expectedColors: [Color] = [
            Color(0xffffffff),
            Color(0xffffe6e6),
            Color(0xffffcccc),
            Color(0xffffb3b3),
            Color(0xffff9999),
            Color(0xffff8080),
            Color(0xffff6666),
            Color(0xffff4d4d),
            Color(0xffff3333),
            Color(0xffff1a1a),
            Color(0xffff0000),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "saturation sweep index \(i)")
        }
    }

    // MARK: - HSVColor Value Sweep Test

    /// **Dart Source:** `colors_test.dart:95-125`
    func testHSVColorValueSweep() {
        var output: [Color] = []
        // Use cumulative addition (matching Dart behavior) but with a fixed
        // iteration count to avoid Swift float loop boundary issues.
        var value = 0.0
        for _ in 0..<10 {
            let hsvColor = HSVColor.fromAHSV(1.0, 0.0, 1.0, value)
            let color = hsvColor.toColor()
            output.append(color)
            if value >= _doubleColorPrecision && value <= (1.0 - _doubleColorPrecision) {
                let reversed = HSVColor.fromColor(color)
                assertClose(reversed.alpha, hsvColor.alpha)
                assertClose(reversed.hue, hsvColor.hue, accuracy: 1.0)
                assertClose(reversed.saturation, hsvColor.saturation)
                assertClose(reversed.value, hsvColor.value)
            }
            value += 0.1
        }
        // Add final value
        output.append(HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0).toColor())

        let expectedColors: [Color] = [
            Color(0xff000000),
            Color(0xff1a0000),
            Color(0xff330000),
            Color(0xff4d0000),
            Color(0xff660000),
            Color(0xff800000),
            Color(0xff990000),
            Color(0xffb30000),
            Color(0xffcc0000),
            Color(0xffe50000),
            Color(0xffff0000),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "value sweep index \(i)")
        }
    }

    // MARK: - HSVColor.lerp identical a,b

    /// **Dart Source:** `colors_test.dart:127-131`
    func testHSVColorLerpIdentical() {
        XCTAssertNil(HSVColor.lerp(nil, nil, 0))
        let color = HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0)
        let result = HSVColor.lerp(color, color, 0.5)
        XCTAssertEqual(result, color)
    }

    // MARK: - HSVColor lerps hue correctly

    /// **Dart Source:** `colors_test.dart:133-163`
    func testHSVColorLerpsHueCorrectly() {
        var output: [Color] = []
        let startColor = HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0)
        let endColor = HSVColor.fromAHSV(1.0, 360.0, 1.0, 1.0)

        var t = -0.5
        while t < 1.5 {
            output.append(HSVColor.lerp(startColor, endColor, t)!.toColor())
            t += 0.1
        }
        let expectedColors: [Color] = [
            Color(0xff00ffff),
            Color(0xff0066ff),
            Color(0xff3300ff),
            Color(0xffcc00ff),
            Color(0xffff0099),
            Color(0xffff0000),
            Color(0xffff9900),
            Color(0xffccff00),
            Color(0xff33ff00),
            Color(0xff00ff66),
            Color(0xff00ffff),
            Color(0xff0066ff),
            Color(0xff3300ff),
            Color(0xffcc00ff),
            Color(0xffff0099),
            Color(0xffff0000),
            Color(0xffff9900),
            Color(0xffccff00),
            Color(0xff33ff00),
            Color(0xff00ff66),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "hue lerp index \(i)")
        }
    }

    // MARK: - HSVColor lerps saturation correctly

    /// **Dart Source:** `colors_test.dart:166-190`
    func testHSVColorLerpsSaturationCorrectly() {
        var output: [Color] = []
        let startColor = HSVColor.fromAHSV(1.0, 0.0, 0.0, 1.0)
        let endColor = HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0)

        var t = -0.1
        while t < 1.1 {
            output.append(HSVColor.lerp(startColor, endColor, t)!.toColor())
            t += 0.1
        }
        let expectedColors: [Color] = [
            Color(0xffffffff),
            Color(0xffffffff),
            Color(0xffffe6e6),
            Color(0xffffcccc),
            Color(0xffffb3b3),
            Color(0xffff9999),
            Color(0xffff8080),
            Color(0xffff6666),
            Color(0xffff4d4d),
            Color(0xffff3333),
            Color(0xffff1a1a),
            Color(0xffff0000),
            Color(0xffff0000),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "sat lerp index \(i)")
        }
    }

    // MARK: - HSVColor lerps value correctly

    /// **Dart Source:** `colors_test.dart:192-216`
    func testHSVColorLerpsValueCorrectly() {
        var output: [Color] = []
        let startColor = HSVColor.fromAHSV(1.0, 0.0, 1.0, 0.0)
        let endColor = HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0)

        var t = -0.1
        while t < 1.1 {
            output.append(HSVColor.lerp(startColor, endColor, t)!.toColor())
            t += 0.1
        }
        let expectedColors: [Color] = [
            Color(0xff000000),
            Color(0xff000000),
            Color(0xff1a0000),
            Color(0xff330000),
            Color(0xff4d0000),
            Color(0xff660000),
            Color(0xff800000),
            Color(0xff990000),
            Color(0xffb30000),
            Color(0xffcc0000),
            Color(0xffe50000),
            Color(0xffff0000),
            Color(0xffff0000),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "value lerp index \(i)")
        }
    }

    // MARK: - HSLColor Control Test

    /// **Dart Source:** `colors_test.dart:218-241`
    func testHSLColorControlTest() {
        let color = HSLColor.fromAHSL(0.7, 28.0, 0.3, 0.6)

        // Test description is one line
        XCTAssertFalse(color.description.contains("\n"))

        // Test hashCode equality
        XCTAssertEqual(color.hashValue, HSLColor.fromAHSL(0.7, 28.0, 0.3, 0.6).hashValue)

        // Test with methods
        XCTAssertEqual(color.withAlpha(0.8), HSLColor.fromAHSL(0.8, 28.0, 0.3, 0.6))
        XCTAssertEqual(color.withHue(123.0), HSLColor.fromAHSL(0.7, 123.0, 0.3, 0.6))
        XCTAssertEqual(color.withSaturation(0.9), HSLColor.fromAHSL(0.7, 28.0, 0.9, 0.6))
        XCTAssertEqual(color.withLightness(0.1), HSLColor.fromAHSL(0.7, 28.0, 0.3, 0.1))

        // Test toColor
        XCTAssertEqual(color.toColor(), Color(0xb3b8977a))

        // Test lerp
        let result = HSLColor.lerp(
            color,
            HSLColor.fromAHSL(0.3, 128.0, 0.7, 0.2),
            0.25
        )!
        assertClose(result.alpha, 0.6)
        assertClose(result.hue, 53.0)
        XCTAssertGreaterThan(result.saturation, 0.3999)
        XCTAssertLessThan(result.saturation, 0.4001)
        assertClose(result.lightness, 0.5)
    }

    // MARK: - HSLColor Hue Sweep Test

    /// **Dart Source:** `colors_test.dart:243-271`
    func testHSLColorHueSweep() {
        var output: [Color] = []
        var hue = 0.0
        while hue <= 360.0 {
            let hslColor = HSLColor.fromAHSL(1.0, hue, 0.5, 0.5)
            let color = hslColor.toColor()
            output.append(color)
            if hue != 360.0 {
                let reversed = HSLColor.fromColor(color)
                assertClose(reversed.alpha, hslColor.alpha)
                assertClose(reversed.hue, hslColor.hue, accuracy: 1.0)
                assertClose(reversed.saturation, hslColor.saturation)
                assertClose(reversed.lightness, hslColor.lightness)
            }
            hue += 36.0
        }
        let expectedColors: [Color] = [
            Color(0xffbf4040),
            Color(0xffbf8c40),
            Color(0xffa6bf40),
            Color(0xff59bf40),
            Color(0xff40bf73),
            Color(0xff40bfbf),
            Color(0xff4073bf),
            Color(0xff5940bf),
            Color(0xffa640bf),
            Color(0xffbf408c),
            Color(0xffbf4040),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "hsl hue sweep index \(i)")
        }
    }

    // MARK: - HSLColor Saturation Sweep Test

    /// **Dart Source:** `colors_test.dart:273-299`
    func testHSLColorSaturationSweep() {
        var output: [Color] = []
        // Use cumulative addition (matching Dart behavior) but with a fixed
        // iteration count to avoid Swift float loop boundary issues.
        var saturation = 0.0
        for _ in 0..<10 {
            let hslColor = HSLColor.fromAHSL(1.0, 0.0, saturation, 0.5)
            let color = hslColor.toColor()
            output.append(color)
            let reversed = HSLColor.fromColor(color)
            assertClose(reversed.alpha, hslColor.alpha)
            assertClose(reversed.hue, hslColor.hue, accuracy: 1.0)
            assertClose(reversed.saturation, hslColor.saturation)
            assertClose(reversed.lightness, hslColor.lightness)
            saturation += 0.1
        }
        output.append(HSLColor.fromAHSL(1.0, 0.0, 1.0, 0.5).toColor())

        let expectedColors: [Color] = [
            Color(0xff808080),
            Color(0xff8c7373),
            Color(0xff996666),
            Color(0xffa65959),
            Color(0xffb34d4d),
            Color(0xffbf4040),
            Color(0xffcc3333),
            Color(0xffd92626),
            Color(0xffe51a1a),
            Color(0xfff20d0d),
            Color(0xffff0000),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "hsl sat sweep index \(i)")
        }
    }

    // MARK: - HSLColor Lightness Sweep Test

    /// **Dart Source:** `colors_test.dart:301-330`
    func testHSLColorLightnessSweep() {
        var output: [Color] = []
        // Use cumulative addition (matching Dart behavior) but with a fixed
        // iteration count to avoid Swift float loop boundary issues.
        var lightness = 0.0
        for _ in 0..<10 {
            let hslColor = HSLColor.fromAHSL(1.0, 0.0, 0.5, lightness)
            let color = hslColor.toColor()
            output.append(color)
            if lightness >= _doubleColorPrecision && lightness <= (1.0 - _doubleColorPrecision) {
                let reversed = HSLColor.fromColor(color)
                assertClose(reversed.alpha, hslColor.alpha)
                assertClose(reversed.hue, hslColor.hue, accuracy: 1.0)
                assertClose(reversed.saturation, hslColor.saturation)
                assertClose(reversed.lightness, hslColor.lightness)
            }
            lightness += 0.1
        }
        output.append(HSLColor.fromAHSL(1.0, 0.0, 0.5, 1.0).toColor())

        let expectedColors: [Color] = [
            Color(0xff000000),
            Color(0xff260d0d),
            Color(0xff4d1a1a),
            Color(0xff732626),
            Color(0xff993333),
            Color(0xffbf4040),
            Color(0xffcc6666),
            Color(0xffd98c8c),
            Color(0xffe6b3b3),
            Color(0xfff2d9d9),
            Color(0xffffffff),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "lightness sweep index \(i)")
        }
    }

    // MARK: - HSLColor.fromColor Tests

    /// **Dart Source:** `colors_test.dart:332-368`
    func testHSLColorFromColorPink() {
        let color = Color(argb: 255, 255, 51, 152)
        let hslColor = HSLColor.fromColor(color)
        assertClose(hslColor.alpha, 1.0)
        assertClose(hslColor.hue, 330.0, accuracy: 0.3)
        assertClose(hslColor.saturation, 1.0)
        assertClose(hslColor.lightness, 0.6)
    }

    func testHSLColorFromColorWhite() {
        let color = Color(0xffffffff)
        let hslColor = HSLColor.fromColor(color)
        assertClose(hslColor.alpha, 1.0)
        XCTAssertEqual(hslColor.hue, 0.0)
        XCTAssertEqual(hslColor.saturation, 0.0)
        assertClose(hslColor.lightness, 1.0)
    }

    func testHSLColorFromColorBlack() {
        let color = Color(0xff000000)
        let hslColor = HSLColor.fromColor(color)
        assertClose(hslColor.alpha, 1.0)
        XCTAssertEqual(hslColor.hue, 0.0)
        XCTAssertEqual(hslColor.saturation, 0.0)
        assertClose(hslColor.lightness, 0.0)
    }

    func testHSLColorFromColorGray() {
        let color = Color(0xff808080)
        let hslColor = HSLColor.fromColor(color)
        assertClose(hslColor.alpha, 1.0)
        XCTAssertEqual(hslColor.hue, 0.0)
        XCTAssertEqual(hslColor.saturation, 0.0)
        assertClose(hslColor.lightness, 0.5)
    }

    // MARK: - HSLColor.lerp identical a,b

    /// **Dart Source:** `colors_test.dart:370-374`
    func testHSLColorLerpIdentical() {
        XCTAssertNil(HSLColor.lerp(nil, nil, 0))
        let color = HSLColor.fromAHSL(1.0, 0.0, 0.5, 0.5)
        let result = HSLColor.lerp(color, color, 0.5)
        XCTAssertEqual(result, color)
    }

    // MARK: - HSLColor lerps hue correctly

    /// **Dart Source:** `colors_test.dart:376-407`
    func testHSLColorLerpsHueCorrectly() {
        var output: [Color] = []
        let startColor = HSLColor.fromAHSL(1.0, 0.0, 0.5, 0.5)
        let endColor = HSLColor.fromAHSL(1.0, 360.0, 0.5, 0.5)

        var t = -0.5
        while t < 1.5 {
            output.append(HSLColor.lerp(startColor, endColor, t)!.toColor())
            t += 0.1
        }
        let expectedColors: [Color] = [
            Color(0xff40bfbf),
            Color(0xff4073bf),
            Color(0xff5940bf),
            Color(0xffa640bf),
            Color(0xffbf408c),
            Color(0xffbf4040),
            Color(0xffbf8c40),
            Color(0xffa6bf40),
            Color(0xff59bf40),
            Color(0xff40bf73),
            Color(0xff40bfbf),
            Color(0xff4073bf),
            Color(0xff5940bf),
            Color(0xffa640bf),
            Color(0xffbf408c),
            Color(0xffbf4040),
            Color(0xffbf8c40),
            Color(0xffa6bf40),
            Color(0xff59bf40),
            Color(0xff40bf73),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "hsl hue lerp index \(i)")
        }
    }

    // MARK: - HSLColor lerps saturation correctly

    /// **Dart Source:** `colors_test.dart:409-433`
    func testHSLColorLerpsSaturationCorrectly() {
        var output: [Color] = []
        let startColor = HSLColor.fromAHSL(1.0, 0.0, 0.0, 0.5)
        let endColor = HSLColor.fromAHSL(1.0, 0.0, 1.0, 0.5)

        var t = -0.1
        while t < 1.1 {
            output.append(HSLColor.lerp(startColor, endColor, t)!.toColor())
            t += 0.1
        }
        let expectedColors: [Color] = [
            Color(0xff808080),
            Color(0xff808080),
            Color(0xff8c7373),
            Color(0xff996666),
            Color(0xffa65959),
            Color(0xffb34d4d),
            Color(0xffbf4040),
            Color(0xffcc3333),
            Color(0xffd92626),
            Color(0xffe51a1a),
            Color(0xfff20d0d),
            Color(0xffff0000),
            Color(0xffff0000),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "hsl sat lerp index \(i)")
        }
    }

    // MARK: - HSLColor lerps lightness correctly

    /// **Dart Source:** `colors_test.dart:435-459`
    func testHSLColorLerpsLightnessCorrectly() {
        var output: [Color] = []
        let startColor = HSLColor.fromAHSL(1.0, 0.0, 0.5, 0.0)
        let endColor = HSLColor.fromAHSL(1.0, 0.0, 0.5, 1.0)

        var t = -0.1
        while t < 1.1 {
            output.append(HSLColor.lerp(startColor, endColor, t)!.toColor())
            t += 0.1
        }
        let expectedColors: [Color] = [
            Color(0xff000000),
            Color(0xff000000),
            Color(0xff260d0d),
            Color(0xff4d1a1a),
            Color(0xff732626),
            Color(0xff993333),
            Color(0xffbf4040),
            Color(0xffcc6666),
            Color(0xffd98c8c),
            Color(0xffe6b3b3),
            Color(0xfff2d9d9),
            Color(0xffffffff),
            Color(0xffffffff),
        ]
        XCTAssertEqual(output.count, expectedColors.count)
        for i in 0..<output.count {
            assertSameColor(output[i], expectedColors[i], "hsl lightness lerp index \(i)")
        }
    }

    // MARK: - Wikipedia Examples Table Test

    /// **Dart Source:** `colors_test.dart:461-541`
    func testWikipediaExamplesTable() {
        // (rgb, r, g, b, hue, v, l, sHSV, sHSL, name)
        let colors: [(Int, Double, Double, Double, Double, Double, Double, Double, Double, String)] = [
            (0xFFFFFFFF, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, "white"),
            (0xFF808080, 0.5, 0.5, 0.5, 0.0, 0.5, 0.5, 0.0, 0.0, "gray"),
            (0xFF000000, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "black"),
            (0xFFFF0000, 1.0, 0.0, 0.0, 0.0, 1.0, 0.5, 1.0, 1.0, "red"),
            (0xFFBFBF00, 0.75, 0.75, 0.0, 60, 0.75, 0.375, 1.0, 1.0, "lime"),
            (0xFF008000, 0.0, 0.5, 0.0, 120, 0.5, 0.25, 1.0, 1.0, "green"),
            (0xFF80FFFF, 0.5, 1.0, 1.0, 180, 1.0, 0.75, 0.5, 1, "cyan"),
            (0xFF8080FF, 0.5, 0.5, 1.0, 240, 1.0, 0.75, 0.5, 1, "light purple"),
            (0xFFBF40BF, 0.75, 0.25, 0.75, 300, 0.75, 0.5, 2.0 / 3, 0.5, "mute magenta"),
        ]

        for (rgb, r, g, b, hue, v, l, sHSV, sHSL, name) in colors {
            let color = Color(alpha: 1.0, red: r, green: g, blue: b)
            let intColor = Color(rgb)

            // Verify int color components match expected
            assertClose(intColor.r, r, accuracy: _doubleColorPrecision)
            assertClose(intColor.g, g, accuracy: _doubleColorPrecision)
            assertClose(intColor.b, b, accuracy: _doubleColorPrecision)

            let hsv = HSVColor.fromAHSV(1.0, hue, sHSV, v)
            let hsl = HSLColor.fromAHSL(1.0, hue, sHSL, l)

            // Verify HSV toColor matches
            let hsvColor = hsv.toColor()
            assertClose(hsvColor.r, color.r, accuracy: _doubleColorPrecision)
            assertClose(hsvColor.g, color.g, accuracy: _doubleColorPrecision)
            assertClose(hsvColor.b, color.b, accuracy: _doubleColorPrecision)

            // Verify HSL toColor matches
            let hslColor = hsl.toColor()
            assertClose(hslColor.r, color.r, accuracy: _doubleColorPrecision)
            assertClose(hslColor.g, color.g, accuracy: _doubleColorPrecision)
            assertClose(hslColor.b, color.b, accuracy: _doubleColorPrecision)

            // Verify HSVColor.fromColor roundtrip
            let hsvFromColor = HSVColor.fromColor(color)
            assertClose(hsvFromColor.hue, hsv.hue, accuracy: _doubleColorPrecision)
            assertClose(hsvFromColor.saturation, hsv.saturation, accuracy: _doubleColorPrecision)
            assertClose(hsvFromColor.value, hsv.value, accuracy: _doubleColorPrecision)

            // Verify HSLColor.fromColor roundtrip
            let hslFromColor = HSLColor.fromColor(color)
            assertClose(hslFromColor.hue, hsl.hue, accuracy: _doubleColorPrecision)
            assertClose(hslFromColor.saturation, hsl.saturation, accuracy: _doubleColorPrecision)
            assertClose(hslFromColor.lightness, hsl.lightness, accuracy: _doubleColorPrecision)
        }
    }

    // MARK: - ColorSwatch Test

    /// **Dart Source:** `colors_test.dart:543-562`
    func testColorSwatch() {
        let greens1 = ColorSwatch<String>(0xFF027223, [
            "2259 C": Color(0xFF027223),
            "2273 C": Color(0xFF257226),
            "2426 XGC": Color(0xFF00932F),
            "7732 XGC": Color(0xFF007940),
        ])
        let greens2 = ColorSwatch<String>(0xFF027223, [
            "2259 C": Color(0xFF027223),
            "2273 C": Color(0xFF257226),
            "2426 XGC": Color(0xFF00932F),
            "7732 XGC": Color(0xFF007940),
        ])
        XCTAssertEqual(greens1, greens2)
        XCTAssertEqual(greens1.hashValue, greens2.hashValue)
        XCTAssertEqual(greens1["2259 C"], Color(0xFF027223))
        XCTAssertEqual(greens1.value, 0xFF027223)
    }

    // MARK: - ColorSwatch.lerp

    /// **Dart Source:** `colors_test.dart:564-591`
    func testColorSwatchLerp() {
        let swatchA = ColorSwatch<Int>(0x00000000, [1: Color(0x00000000)])
        let swatchB = ColorSwatch<Int>(0xFFFFFFFF, [1: Color(0xFFFFFFFF)])

        // lerp at 0.0
        let result0 = ColorSwatch<Int>.lerp(swatchA, swatchB, 0.0)!
        assertSameColor(result0.color, Color(0x00000000), "lerp 0.0 primary")
        assertSameColor(result0[1]!, Color(0x00000000), "lerp 0.0 swatch[1]")

        // lerp at 0.5
        let result50 = ColorSwatch<Int>.lerp(swatchA, swatchB, 0.5)!
        assertSameColor(result50.color, Color(0x7F7F7F7F), "lerp 0.5 primary")
        assertSameColor(result50[1]!, Color(0x7F7F7F7F), "lerp 0.5 swatch[1]")

        // lerp at 1.0
        let result1 = ColorSwatch<Int>.lerp(swatchA, swatchB, 1.0)!
        assertSameColor(result1.color, Color(0xFFFFFFFF), "lerp 1.0 primary")
        assertSameColor(result1[1]!, Color(0xFFFFFFFF), "lerp 1.0 swatch[1]")

        // lerp at -0.1
        let resultNeg = ColorSwatch<Int>.lerp(swatchA, swatchB, -0.1)!
        assertSameColor(resultNeg.color, Color(0x00000000), "lerp -0.1 primary")
        assertSameColor(resultNeg[1]!, Color(0x00000000), "lerp -0.1 swatch[1]")

        // lerp at 1.1
        let resultOver = ColorSwatch<Int>.lerp(swatchA, swatchB, 1.1)!
        assertSameColor(resultOver.color, Color(0xFFFFFFFF), "lerp 1.1 primary")
        assertSameColor(resultOver[1]!, Color(0xFFFFFFFF), "lerp 1.1 swatch[1]")
    }

    // MARK: - ColorSwatch.lerp identical a,b

    /// **Dart Source:** `colors_test.dart:593-597`
    func testColorSwatchLerpIdentical() {
        XCTAssertNil(ColorSwatch<Int>.lerp(nil, nil, 0))
        let color = ColorSwatch<Int>(0x00000000, [1: Color(0x00000000)])
        let result = ColorSwatch<Int>.lerp(color, color, 0.5)
        XCTAssertEqual(result, color)
    }

    // MARK: - ColorProperty Tests

    /// **Dart Source:** `colors_test.dart:599-612`
    func testColorPropertyIncludesValuePropertiesInJSON() {
        #if DEBUG
        let property = ColorProperty("foo", Color(argb: 10, 20, 30, 40))
        let json = property.toJsonMap(delegate: DefaultDiagnosticsSerializationDelegate())
        let valueProperties = json["valueProperties"] as! [String: Any]
        XCTAssertEqual(valueProperties["alpha"] as! Int, 10)
        XCTAssertEqual(valueProperties["red"] as! Int, 20)
        XCTAssertEqual(valueProperties["green"] as! Int, 30)
        XCTAssertEqual(valueProperties["blue"] as! Int, 40)
        #endif
    }

    func testColorPropertyNullValueOmitsValueProperties() {
        #if DEBUG
        let property = ColorProperty("foo", nil)
        let json = property.toJsonMap(delegate: DefaultDiagnosticsSerializationDelegate())
        XCTAssertNil(json["valueProperties"])
        #endif
    }
}

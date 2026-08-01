// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for TextStyle (painting layer).
///
/// **Dart Test Source:** `packages/flutter/test/painting/text_style_test.dart`
///
/// Note: `Flutter.TextStyle` (painting layer) is distinct from
/// `FlutterSwiftBridge.TextStyle` (dart:ui layer). We use a typealias
/// to refer to the painting-layer version unambiguously.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Typealias to disambiguate from FlutterSwiftBridge.TextStyle (dart:ui level).
private typealias PaintingTextStyle = Flutter.TextStyle

final class TextStyleTests: XCTestCase {

    // MARK: - Control Test (Dart: 'TextStyle control test')

    /// Test basic toString output for default and inherit:false styles.
    ///
    /// **Dart Test:** `text_style_test.dart:106-112`
    func testControlTestToString() {
        let inheritFalse = PaintingTextStyle(inherit: false)
        XCTAssertEqual(
            inheritFalse.description,
            "TextStyle(inherit: false, <no style specified>)"
        )

        let defaultStyle = PaintingTextStyle()
        XCTAssertEqual(defaultStyle.description, "TextStyle(<all styles inherited>)")
    }

    /// Test basic property access and equality.
    ///
    /// **Dart Test:** `text_style_test.dart:113-122`
    func testControlTestBasicProperties() {
        let s1 = PaintingTextStyle(fontSize: 10.0, fontWeight: .w800, height: 123.0)
        XCTAssertNil(s1.fontFamily)
        XCTAssertEqual(s1.fontSize, 10.0)
        XCTAssertEqual(s1.fontWeight, .w800)
        XCTAssertEqual(s1.height, 123.0)
        XCTAssertEqual(s1, s1)
        XCTAssertEqual(
            s1.description,
            "TextStyle(inherit: true, size: 10.0, weight: 800, height: 123.0x)"
        )
    }

    /// Test that inherit flag can be set with copyWith.
    ///
    /// **Dart Test:** `text_style_test.dart:124-128`
    func testCopyWithInheritFlag() {
        let s1 = PaintingTextStyle(fontSize: 10.0, fontWeight: .w800, height: 123.0)
        XCTAssertEqual(
            s1.copyWith(inherit: false).description,
            "TextStyle(inherit: false, size: 10.0, weight: 800, height: 123.0x)"
        )
    }

    /// Test copyWith preserves original and creates new style.
    ///
    /// **Dart Test:** `text_style_test.dart:130-152`
    func testCopyWithPreservesOriginal() {
        let s1 = PaintingTextStyle(fontSize: 10.0, fontWeight: .w800, height: 123.0)
        let s2 = s1.copyWith(
            color: Color(0xFF00FF00),
            height: 100.0,
            leadingDistribution: .even
        )

        // s1 unchanged
        XCTAssertNil(s1.fontFamily)
        XCTAssertEqual(s1.fontSize, 10.0)
        XCTAssertEqual(s1.fontWeight, .w800)
        XCTAssertEqual(s1.height, 123.0)
        XCTAssertNil(s1.color)

        // s2 has new values
        XCTAssertNil(s2.fontFamily)
        XCTAssertEqual(s2.fontSize, 10.0)
        XCTAssertEqual(s2.fontWeight, .w800)
        XCTAssertEqual(s2.height, 100.0)
        XCTAssertEqual(s2.color, Color(0xFF00FF00))
        XCTAssertEqual(s2.leadingDistribution, TextLeadingDistribution.even)
        XCTAssertNotEqual(s2, s1)
        XCTAssertEqual(
            s2.description,
            "TextStyle(inherit: true, color: \(Color(0xFF00FF00)), size: 10.0, weight: 800, height: 100.0x, leadingDistribution: even)"
        )
    }

    /// Test apply with font size and weight.
    ///
    /// **Dart Test:** `text_style_test.dart:154-168`
    func testApplyFontSizeAndWeight() {
        let s1 = PaintingTextStyle(fontSize: 10.0, fontWeight: .w800, height: 123.0)
        let s3 = s1.apply(fontSizeFactor: 2.0, fontSizeDelta: -2.0, fontWeightDelta: -4)

        // s1 unchanged
        XCTAssertNil(s1.fontFamily)
        XCTAssertEqual(s1.fontSize, 10.0)
        XCTAssertEqual(s1.fontWeight, .w800)
        XCTAssertEqual(s1.height, 123.0)
        XCTAssertNil(s1.color)

        // s3 computed
        XCTAssertNil(s3.fontFamily)
        XCTAssertEqual(s3.fontSize, 18.0)
        XCTAssertEqual(s3.fontWeight, .w400)
        XCTAssertEqual(s3.height, 123.0)
        XCTAssertNil(s3.color)
        XCTAssertNotEqual(s3, s1)

        // fontWeight clamping
        XCTAssertEqual(s1.apply(fontWeightDelta: -10).fontWeight, .w100)
        XCTAssertEqual(s1.apply(fontWeightDelta: 2).fontWeight, .w900)
    }

    /// Test merge with nil returns self.
    ///
    /// **Dart Test:** `text_style_test.dart:169`
    func testMergeNilReturnsSelf() {
        let s1 = PaintingTextStyle(fontSize: 10.0, fontWeight: .w800, height: 123.0)
        XCTAssertEqual(s1.merge(nil), s1)
    }

    /// Test merge combines styles correctly.
    ///
    /// **Dart Test:** `text_style_test.dart:171-191`
    func testMergeCombinesStyles() {
        let s1 = PaintingTextStyle(fontSize: 10.0, fontWeight: .w800, height: 123.0)
        let s2 = s1.copyWith(
            color: Color(0xFF00FF00),
            height: 100.0,
            leadingDistribution: .even
        )
        let s4 = s2.merge(s1)

        // s1 and s2 unchanged
        XCTAssertEqual(s1.fontSize, 10.0)
        XCTAssertEqual(s1.fontWeight, .w800)
        XCTAssertEqual(s1.height, 123.0)
        XCTAssertNil(s1.color)

        XCTAssertEqual(s2.fontSize, 10.0)
        XCTAssertEqual(s2.fontWeight, .w800)
        XCTAssertEqual(s2.height, 100.0)
        XCTAssertEqual(s2.color, Color(0xFF00FF00))
        XCTAssertEqual(s2.leadingDistribution, TextLeadingDistribution.even)
        XCTAssertNotEqual(s2, s1)
        XCTAssertNotEqual(s2, s4)

        // s4 merged: s1 overrides onto s2
        XCTAssertNil(s4.fontFamily)
        XCTAssertEqual(s4.fontSize, 10.0)
        XCTAssertEqual(s4.fontWeight, .w800)
        XCTAssertEqual(s4.height, 123.0)
        XCTAssertEqual(s4.color, Color(0xFF00FF00))
        XCTAssertEqual(s4.leadingDistribution, TextLeadingDistribution.even)
    }

    // MARK: - Lerp Tests

    /// Test lerp between two non-nil styles.
    ///
    /// **Dart Test:** `text_style_test.dart:192-209`
    func testLerpBetweenTwoStyles() {
        let s1 = PaintingTextStyle(fontSize: 10.0, fontWeight: .w800, height: 123.0)
        let s3 = s1.apply(fontSizeFactor: 2.0, fontSizeDelta: -2.0, fontWeightDelta: -4)

        let s5 = PaintingTextStyle.lerp(s1, s3, 0.25)!

        // Originals unchanged
        XCTAssertEqual(s1.fontSize, 10.0)
        XCTAssertEqual(s1.fontWeight, .w800)
        XCTAssertEqual(s1.height, 123.0)
        XCTAssertEqual(s3.fontSize, 18.0)
        XCTAssertEqual(s3.fontWeight, .w400)
        XCTAssertEqual(s3.height, 123.0)
        XCTAssertNotEqual(s3, s1)
        XCTAssertNotEqual(s3, s5)

        // Lerped
        XCTAssertNil(s5.fontFamily)
        XCTAssertEqual(s5.fontSize, 12.0)
        XCTAssertEqual(s5.fontWeight, .w700)
        XCTAssertEqual(s5.height, 123.0)
        XCTAssertNil(s5.color)
    }

    /// Test lerp(nil, nil, t) returns nil.
    ///
    /// **Dart Test:** `text_style_test.dart:211`
    func testLerpNilNilIsNil() {
        XCTAssertNil(PaintingTextStyle.lerp(nil, nil, 0.5))
    }

    /// Test lerp(nil, style, 0.25) - early: most props nil.
    ///
    /// **Dart Test:** `text_style_test.dart:213-224`
    func testLerpFromNilEarly() {
        let s3 = PaintingTextStyle(fontSize: 18.0, fontWeight: .w400, height: 123.0)
        let s6 = PaintingTextStyle.lerp(nil, s3, 0.25)!

        XCTAssertNil(s6.fontFamily)
        XCTAssertNil(s6.fontSize)
        XCTAssertEqual(s6.fontWeight, .w400)
        XCTAssertNil(s6.height)
        XCTAssertNil(s6.color)
    }

    /// Test lerp(nil, style, 0.75) - late: takes style values.
    ///
    /// **Dart Test:** `text_style_test.dart:226-237`
    func testLerpFromNilLate() {
        let s3 = PaintingTextStyle(fontSize: 18.0, fontWeight: .w400, height: 123.0)
        let s7 = PaintingTextStyle.lerp(nil, s3, 0.75)!

        XCTAssertEqual(s7, s3)
        XCTAssertNil(s7.fontFamily)
        XCTAssertEqual(s7.fontSize, 18.0)
        XCTAssertEqual(s7.fontWeight, .w400)
        XCTAssertEqual(s7.height, 123.0)
        XCTAssertNil(s7.color)
    }

    /// Test lerp(style, nil, 0.25) - early: keeps style values.
    ///
    /// **Dart Test:** `text_style_test.dart:239-250`
    func testLerpToNilEarly() {
        let s3 = PaintingTextStyle(fontSize: 18.0, fontWeight: .w400, height: 123.0)
        let s8 = PaintingTextStyle.lerp(s3, nil, 0.25)!

        XCTAssertEqual(s8, s3)
        XCTAssertNil(s8.fontFamily)
        XCTAssertEqual(s8.fontSize, 18.0)
        XCTAssertEqual(s8.fontWeight, .w400)
        XCTAssertEqual(s8.height, 123.0)
        XCTAssertNil(s8.color)
    }

    /// Test lerp(style, nil, 0.75) - late: most props nil.
    ///
    /// **Dart Test:** `text_style_test.dart:252-263`
    func testLerpToNilLate() {
        let s3 = PaintingTextStyle(fontSize: 18.0, fontWeight: .w400, height: 123.0)
        let s9 = PaintingTextStyle.lerp(s3, nil, 0.75)!

        XCTAssertNotEqual(s3, s9)
        XCTAssertNil(s9.fontFamily)
        XCTAssertNil(s9.fontSize)
        XCTAssertEqual(s9.fontWeight, .w400)
        XCTAssertNil(s9.height)
        XCTAssertNil(s9.color)
    }

    /// Test lerp identical returns same value (value equality for structs).
    ///
    /// **Dart Test:** `text_style_test.dart:706-710`
    func testLerpIdentical() {
        XCTAssertNil(PaintingTextStyle.lerp(nil, nil, 0))
        let style = PaintingTextStyle()
        let result = PaintingTextStyle.lerp(style, style, 0.5)
        XCTAssertEqual(result, style)
    }

    // MARK: - getTextStyle Tests

    /// Test getTextStyle produces correct engine TextStyle.
    ///
    /// **Dart Test:** `text_style_test.dart:265-281`
    func testGetTextStyle() {
        let s1 = PaintingTextStyle(fontSize: 10.0, fontWeight: .w800, height: 123.0)
        let s3 = s1.apply(fontSizeFactor: 2.0, fontSizeDelta: -2.0, fontWeightDelta: -4)
        let s5 = PaintingTextStyle.lerp(s1, s3, 0.25)!

        let ts5 = s5.getTextStyle()
        let expected5 = FlutterSwiftBridge.TextStyle(
            fontWeight: .w700,
            fontSize: 12.0,
            height: 123.0
        )
        XCTAssertEqual(ts5, expected5)

        let s2 = s1.copyWith(
            color: Color(0xFF00FF00),
            height: 100.0,
            leadingDistribution: .even
        )
        let ts2 = s2.getTextStyle()
        let expected2 = FlutterSwiftBridge.TextStyle(
            color: Color(0xFF00FF00),
            fontWeight: .w800,
            fontSize: 10.0,
            height: 100.0,
            leadingDistribution: .even
        )
        XCTAssertEqual(ts2, expected2)
    }

    // MARK: - getParagraphStyle Tests

    /// Test getParagraphStyle with textAlign.
    ///
    /// **Dart Test:** `text_style_test.dart:283-302`
    func testGetParagraphStyle() {
        let s1 = PaintingTextStyle(fontSize: 10.0, fontWeight: .w800, height: 123.0)
        let s2 = s1.copyWith(
            color: Color(0xFF00FF00),
            height: 100.0,
            leadingDistribution: .even
        )
        let ps2 = s2.getParagraphStyle(textAlign: .center)
        let expectedPs2 = FlutterSwiftBridge.ParagraphStyle(
            textAlign: .center,
            fontSize: 10.0,
            height: 100.0,
            textHeightBehavior: TextHeightBehavior(leadingDistribution: .even),
            fontWeight: .w800
        )
        XCTAssertEqual(ps2, expectedPs2)

        let s5 = PaintingTextStyle.lerp(
            s1,
            s1.apply(fontSizeFactor: 2.0, fontSizeDelta: -2.0, fontWeightDelta: -4),
            0.25
        )!
        let ps5 = s5.getParagraphStyle()
        let expectedPs5 = FlutterSwiftBridge.ParagraphStyle(
            fontSize: 12.0,
            height: 123.0,
            fontWeight: .w700
        )
        XCTAssertEqual(ps5, expectedPs5)
    }

    /// Test getParagraphStyle with text direction.
    ///
    /// **Dart Test:** `text_style_test.dart:305-315`
    func testGetParagraphStyleWithTextDirection() {
        let defaultStyle = PaintingTextStyle()

        let ps6 = defaultStyle.getParagraphStyle(textDirection: .ltr)
        let expected6 = FlutterSwiftBridge.ParagraphStyle(
            textDirection: .ltr,
            fontSize: 14.0
        )
        XCTAssertEqual(ps6, expected6)

        let ps7 = defaultStyle.getParagraphStyle(textDirection: .rtl)
        let expected7 = FlutterSwiftBridge.ParagraphStyle(
            textDirection: .rtl,
            fontSize: 14.0
        )
        XCTAssertEqual(ps7, expected7)
    }

    // MARK: - Package Font Tests

    /// Test fontFamily with and without package prefix.
    ///
    /// **Dart Test:** `text_style_test.dart:317-350`
    func testPackageFont() {
        let s6 = PaintingTextStyle(fontFamily: "test")
        XCTAssertEqual(s6.fontFamily, "test")

        let s7 = PaintingTextStyle(fontFamily: "test", package: "p")
        XCTAssertEqual(s7.fontFamily, "packages/p/test")

        let s8 = PaintingTextStyle(fontFamilyFallback: ["test", "test2"], package: "p")
        XCTAssertEqual(s8.fontFamilyFallback![0], "packages/p/test")
        XCTAssertEqual(s8.fontFamilyFallback![1], "packages/p/test2")
        XCTAssertEqual(s8.fontFamilyFallback!.count, 2)

        let s9 = PaintingTextStyle(package: "p")
        XCTAssertNil(s9.fontFamilyFallback)

        let s10 = PaintingTextStyle(fontFamilyFallback: [], package: "p")
        XCTAssertEqual(s10.fontFamilyFallback, [String]())

        // Ensure package prefix is not duplicated after copying
        let s11 = s8.copyWith()
        XCTAssertEqual(s11.fontFamilyFallback![0], "packages/p/test")
        XCTAssertEqual(s11.fontFamilyFallback![1], "packages/p/test2")
        XCTAssertEqual(s11.fontFamilyFallback!.count, 2)
        XCTAssertEqual(s8, s11)

        // Ensure package prefix is not duplicated after applying
        let s12 = s8.apply()
        XCTAssertEqual(s12.fontFamilyFallback![0], "packages/p/test")
        XCTAssertEqual(s12.fontFamilyFallback![1], "packages/p/test2")
        XCTAssertEqual(s12.fontFamilyFallback!.count, 2)
        XCTAssertEqual(s8, s12)
    }

    /// Test package font merge.
    ///
    /// **Dart Test:** `text_style_test.dart:352-375`
    func testPackageFontMerge() {
        let s1 = PaintingTextStyle(
            fontFamily: "font1",
            fontFamilyFallback: ["fallback1"],
            package: "p"
        )
        let s2 = PaintingTextStyle(
            fontFamily: "font2",
            fontFamilyFallback: ["fallback2"],
            package: "p"
        )

        let emptyMerge = PaintingTextStyle().merge(s1)
        XCTAssertEqual(emptyMerge.fontFamily, "packages/p/font1")
        XCTAssertEqual(emptyMerge.fontFamilyFallback, ["packages/p/fallback1"])

        let lerp1 = PaintingTextStyle.lerp(s1, s2, 0)!
        XCTAssertEqual(lerp1.fontFamily, "packages/p/font1")
        XCTAssertEqual(lerp1.fontFamilyFallback, ["packages/p/fallback1"])

        let lerp2 = PaintingTextStyle.lerp(s1, s2, 1.0)!
        XCTAssertEqual(lerp2.fontFamily, "packages/p/font2")
        XCTAssertEqual(lerp2.fontFamilyFallback, ["packages/p/fallback2"])
    }

    /// Test font family fallback.
    ///
    /// **Dart Test:** `text_style_test.dart:377-411`
    func testFontFamilyFallback() {
        let s1 = PaintingTextStyle(fontFamilyFallback: ["Roboto", "test"])
        XCTAssertEqual(s1.fontFamilyFallback![0], "Roboto")
        XCTAssertEqual(s1.fontFamilyFallback![1], "test")
        XCTAssertEqual(s1.fontFamilyFallback!.count, 2)

        let s2 = PaintingTextStyle(
            fontFamily: "foo",
            fontFamilyFallback: ["Roboto", "test"]
        )
        XCTAssertEqual(s2.fontFamilyFallback![0], "Roboto")
        XCTAssertEqual(s2.fontFamilyFallback![1], "test")
        XCTAssertEqual(s2.fontFamily, "foo")
        XCTAssertEqual(s2.fontFamilyFallback!.count, 2)

        let s3 = PaintingTextStyle(fontFamily: "foo")
        XCTAssertEqual(s3.fontFamily, "foo")
        XCTAssertNil(s3.fontFamilyFallback)

        let s4 = PaintingTextStyle(fontFamily: "foo", fontFamilyFallback: [])
        XCTAssertEqual(s4.fontFamily, "foo")
        XCTAssertEqual(s4.fontFamilyFallback, [String]())
        XCTAssertTrue(s4.fontFamilyFallback!.isEmpty)

        // apply preserves values
        XCTAssertEqual(s2.apply().fontFamily, "foo")
        XCTAssertEqual(s2.apply().fontFamilyFallback, ["Roboto", "test"])
        XCTAssertEqual(s2.apply(fontFamily: "bar").fontFamily, "bar")
        XCTAssertEqual(
            s2.apply(fontFamilyFallback: ["Banana"]).fontFamilyFallback,
            ["Banana"]
        )
    }

    // MARK: - Debug Label Tests

    /// Test debugLabel handling.
    ///
    /// **Dart Test:** `text_style_test.dart:413-436`
    func testDebugLabel() {
        let unknown = PaintingTextStyle()
        let foo = PaintingTextStyle(fontSize: 1.0, debugLabel: "foo")
        let bar = PaintingTextStyle(fontSize: 2.0, debugLabel: "bar")
        let baz = PaintingTextStyle(fontSize: 3.0, debugLabel: "baz")

        XCTAssertNil(unknown.debugLabel)
        XCTAssertEqual(unknown.description, "TextStyle(<all styles inherited>)")
        XCTAssertNil(unknown.copyWith().debugLabel)
        XCTAssertEqual(unknown.copyWith(debugLabel: "123").debugLabel, "123")
        XCTAssertNil(unknown.apply().debugLabel)

        XCTAssertEqual(foo.debugLabel, "foo")
        XCTAssertEqual(foo.description, "TextStyle(debugLabel: foo, inherit: true, size: 1.0)")
        XCTAssertEqual(foo.merge(bar).debugLabel, "(foo).merge(bar)")
        XCTAssertEqual(foo.merge(bar).merge(baz).debugLabel, "((foo).merge(bar)).merge(baz)")
        XCTAssertEqual(foo.copyWith().debugLabel, "(foo).copyWith")
        XCTAssertEqual(foo.apply().debugLabel, "(foo).apply")
        XCTAssertEqual(
            PaintingTextStyle.lerp(foo, bar, 0.5)!.debugLabel,
            "lerp(foo \u{23AF}0.5\u{2192} bar)"
        )
        XCTAssertEqual(
            PaintingTextStyle.lerp(foo.merge(bar), baz, 0.51)!.copyWith().debugLabel,
            "(lerp((foo).merge(bar) \u{23AF}0.5\u{2192} baz)).copyWith"
        )
    }

    // MARK: - Hash Code Tests

    /// Test hash code consistency and differentiation.
    ///
    /// **Dart Test:** `text_style_test.dart:438-458`
    func testHashCode() {
        let a = PaintingTextStyle(
            shadows: [Shadow()],
            fontFeatures: [FontFeature("abcd", 1)],
            fontVariations: [FlutterSwiftBridge.FontVariation(weight: 123.0)],
            fontFamily: nil,
            fontFamilyFallback: ["Roboto"]
        )
        let b = PaintingTextStyle(
            shadows: [Shadow()],
            fontFeatures: [FontFeature("abcd", 1)],
            fontVariations: [FlutterSwiftBridge.FontVariation(weight: 123.0)],
            fontFamily: nil,
            fontFamilyFallback: ["Noto"]
        )
        XCTAssertEqual(a.hashValue, a.hashValue)
        XCTAssertNotEqual(a.hashValue, b.hashValue)

        let c = PaintingTextStyle(leadingDistribution: .even)
        let d = PaintingTextStyle(leadingDistribution: .proportional)
        XCTAssertEqual(c.hashValue, c.hashValue)
        XCTAssertNotEqual(c.hashValue, d.hashValue)
    }

    // MARK: - Shadow Tests

    /// Test lerp between styles with shadows.
    ///
    /// **Dart Test:** `text_style_test.dart:460-496`
    func testShadows() {
        let shadow1 = Shadow(offset: Offset(1.0, 1.0), blurRadius: 1.0)
        let shadow2 = Shadow(color: Color(0xFF111111), offset: Offset(2.0, 2.0), blurRadius: 2.0)
        let shadow3 = Shadow(color: Color(0xFF222222), offset: Offset(3.0, 3.0), blurRadius: 3.0)
        let shadow4 = Shadow(color: Color(0xFF333333), offset: Offset(4.0, 4.0), blurRadius: 4.0)

        let s1 = PaintingTextStyle(shadows: [shadow1, shadow2])
        let s2 = PaintingTextStyle(shadows: [shadow3, shadow4])

        let lerp12 = PaintingTextStyle.lerp(s1, s2, 0.5)!

        XCTAssertEqual(lerp12.shadows?.count, 2)
        XCTAssertEqual(
            lerp12.shadows?[0].blurRadius,
            lerpDouble(shadow1.blurRadius, shadow3.blurRadius, 0.5)
        )
        XCTAssertEqual(
            lerp12.shadows?[0].color,
            Color.lerp(shadow1.color, shadow3.color, 0.5)
        )
        XCTAssertEqual(
            lerp12.shadows?[0].offset,
            Offset.lerp(shadow1.offset, shadow3.offset, 0.5)
        )
        XCTAssertEqual(
            lerp12.shadows?[1].blurRadius,
            lerpDouble(shadow2.blurRadius, shadow4.blurRadius, 0.5)
        )
        XCTAssertEqual(
            lerp12.shadows?[1].color,
            Color.lerp(shadow2.color, shadow4.color, 0.5)
        )
        XCTAssertEqual(
            lerp12.shadows?[1].offset,
            Offset.lerp(shadow2.offset, shadow4.offset, 0.5)
        )
    }

    // MARK: - Foreground / Color Combo Tests

    /// Test foreground and color interactions with merge, copyWith, apply, lerp.
    ///
    /// **Dart Test:** `text_style_test.dart:498-537`
    func testForegroundAndColorCombos() {
        let red = Color(argb: 255, 255, 0, 0)
        let blue = Color(argb: 255, 0, 0, 255)
        let redTextStyle = PaintingTextStyle(color: red)
        let blueTextStyle = PaintingTextStyle(color: blue)

        let redPaint = Paint()
        redPaint.color = red
        let redPaintTextStyle = PaintingTextStyle(foreground: redPaint)

        let bluePaint = Paint()
        bluePaint.color = blue
        let bluePaintTextStyle = PaintingTextStyle(foreground: bluePaint)

        // merge/copyWith
        let redBlueBothForegroundMerged = redTextStyle.merge(blueTextStyle)
        XCTAssertEqual(redBlueBothForegroundMerged.color, blue)
        XCTAssertNil(redBlueBothForegroundMerged.foreground)

        let redBlueBothPaintMerged = redPaintTextStyle.merge(bluePaintTextStyle)
        XCTAssertNil(redBlueBothPaintMerged.color)
        XCTAssertTrue(redBlueBothPaintMerged.foreground === bluePaintTextStyle.foreground)

        let redPaintBlueColorMerged = redPaintTextStyle.merge(blueTextStyle)
        XCTAssertNil(redPaintBlueColorMerged.color)
        XCTAssertTrue(redPaintBlueColorMerged.foreground === redPaintTextStyle.foreground)

        let blueColorRedPaintMerged = blueTextStyle.merge(redPaintTextStyle)
        XCTAssertNil(blueColorRedPaintMerged.color)
        XCTAssertTrue(blueColorRedPaintMerged.foreground === redPaintTextStyle.foreground)

        // apply
        XCTAssertNil(redPaintTextStyle.apply(color: blue).color)
        XCTAssertEqual(redPaintTextStyle.apply(color: blue).foreground!.color, red)
        XCTAssertEqual(redTextStyle.apply(color: blue).color, blue)

        // lerp
        XCTAssertEqual(
            PaintingTextStyle.lerp(redTextStyle, blueTextStyle, 0.25)!.color,
            Color.lerp(red, blue, 0.25)
        )
        XCTAssertNil(PaintingTextStyle.lerp(redTextStyle, bluePaintTextStyle, 0.25)!.color)
        XCTAssertEqual(
            PaintingTextStyle.lerp(redTextStyle, bluePaintTextStyle, 0.25)!.foreground!.color,
            red
        )
        XCTAssertEqual(
            PaintingTextStyle.lerp(redTextStyle, bluePaintTextStyle, 0.75)!.foreground!.color,
            blue
        )

        XCTAssertNil(PaintingTextStyle.lerp(redPaintTextStyle, bluePaintTextStyle, 0.25)!.color)
        XCTAssertEqual(
            PaintingTextStyle.lerp(redPaintTextStyle, bluePaintTextStyle, 0.25)!.foreground!.color,
            red
        )
        XCTAssertEqual(
            PaintingTextStyle.lerp(redPaintTextStyle, bluePaintTextStyle, 0.75)!.foreground!.color,
            blue
        )
    }

    // MARK: - Background Color Tests

    /// Test backgroundColor basics.
    ///
    /// **Dart Test:** `text_style_test.dart:539-555`
    func testBackgroundColor() {
        let s1 = PaintingTextStyle()
        XCTAssertNil(s1.backgroundColor)
        XCTAssertEqual(s1.description, "TextStyle(<all styles inherited>)")

        let s2 = PaintingTextStyle(backgroundColor: Color(0xFF00FF00))
        XCTAssertEqual(s2.backgroundColor, Color(0xFF00FF00))
        XCTAssertEqual(
            s2.description,
            "TextStyle(inherit: true, backgroundColor: \(Color(0xFF00FF00)))"
        )
    }

    /// Test background and backgroundColor interactions.
    ///
    /// **Dart Test:** `text_style_test.dart:557-599`
    func testBackgroundAndBackgroundColorCombos() {
        let red = Color(argb: 255, 255, 0, 0)
        let blue = Color(argb: 255, 0, 0, 255)
        let redTextStyle = PaintingTextStyle(backgroundColor: red)
        let blueTextStyle = PaintingTextStyle(backgroundColor: blue)

        let redPaint = Paint()
        redPaint.color = red
        let redPaintTextStyle = PaintingTextStyle(background: redPaint)

        let bluePaint = Paint()
        bluePaint.color = blue
        let bluePaintTextStyle = PaintingTextStyle(background: bluePaint)

        // merge/copyWith
        let redBlueBothForegroundMerged = redTextStyle.merge(blueTextStyle)
        XCTAssertEqual(redBlueBothForegroundMerged.backgroundColor, blue)
        XCTAssertNil(redBlueBothForegroundMerged.foreground)

        let redBlueBothPaintMerged = redPaintTextStyle.merge(bluePaintTextStyle)
        XCTAssertNil(redBlueBothPaintMerged.backgroundColor)
        XCTAssertTrue(redBlueBothPaintMerged.background === bluePaintTextStyle.background)

        let redPaintBlueColorMerged = redPaintTextStyle.merge(blueTextStyle)
        XCTAssertNil(redPaintBlueColorMerged.backgroundColor)
        XCTAssertTrue(redPaintBlueColorMerged.background === redPaintTextStyle.background)

        let blueColorRedPaintMerged = blueTextStyle.merge(redPaintTextStyle)
        XCTAssertNil(blueColorRedPaintMerged.backgroundColor)
        XCTAssertTrue(blueColorRedPaintMerged.background === redPaintTextStyle.background)

        // apply
        XCTAssertNil(redPaintTextStyle.apply(backgroundColor: blue).backgroundColor)
        XCTAssertEqual(redPaintTextStyle.apply(backgroundColor: blue).background!.color, red)
        XCTAssertEqual(redTextStyle.apply(backgroundColor: blue).backgroundColor, blue)

        // lerp
        XCTAssertEqual(
            PaintingTextStyle.lerp(redTextStyle, blueTextStyle, 0.25)!.backgroundColor,
            Color.lerp(red, blue, 0.25)
        )
        XCTAssertNil(
            PaintingTextStyle.lerp(redTextStyle, bluePaintTextStyle, 0.25)!.backgroundColor
        )
        XCTAssertEqual(
            PaintingTextStyle.lerp(redTextStyle, bluePaintTextStyle, 0.25)!.background!.color,
            red
        )
        XCTAssertEqual(
            PaintingTextStyle.lerp(redTextStyle, bluePaintTextStyle, 0.75)!.background!.color,
            blue
        )

        XCTAssertNil(
            PaintingTextStyle.lerp(redPaintTextStyle, bluePaintTextStyle, 0.25)!.backgroundColor
        )
        XCTAssertEqual(
            PaintingTextStyle.lerp(redPaintTextStyle, bluePaintTextStyle, 0.25)!.background!.color,
            red
        )
        XCTAssertEqual(
            PaintingTextStyle.lerp(redPaintTextStyle, bluePaintTextStyle, 0.75)!.background!.color,
            blue
        )
    }

    // MARK: - TextScaler Tests

    /// Test strut textScaler integration.
    ///
    /// **Dart Test:** `text_style_test.dart:601-611`
    func testStrutTextScaler() {
        let style0 = PaintingTextStyle(fontSize: 10)
        let paragraphStyle0 = style0.getParagraphStyle(
            textScaler: LinearTextScaler(2.5)
        )

        let style1 = PaintingTextStyle(fontSize: 25)
        let paragraphStyle1 = style1.getParagraphStyle()

        XCTAssertEqual(paragraphStyle0, paragraphStyle1)
    }

    // MARK: - Apply Tests

    /// Test apply method with various properties.
    ///
    /// **Dart Test:** `text_style_test.dart:613-662`
    func testApply() {
        let style = PaintingTextStyle(
            fontSize: 10,
            fontStyle: .normal,
            letterSpacing: nil,
            wordSpacing: nil,
            textBaseline: .alphabetic,
            height: nil,
            leadingDistribution: .even,
            shadows: [],
            fontFeatures: [],
            fontVariations: []
        )
        XCTAssertEqual(style.apply().shadows, [Shadow]())
        XCTAssertEqual(
            style.apply(shadows: [Shadow(blurRadius: 2.0)]).shadows,
            [Shadow(blurRadius: 2.0)]
        )
        XCTAssertEqual(style.apply().fontStyle, FontStyle.normal)
        XCTAssertEqual(style.apply(fontStyle: .italic).fontStyle, FontStyle.italic)
        XCTAssertNil(style.apply().locale)
        XCTAssertEqual(
            style.apply(locale: Locale(fromSubtags: "es")).locale,
            Locale(fromSubtags: "es")
        )
        XCTAssertEqual(style.apply().fontFeatures, [FontFeature]())
        XCTAssertEqual(
            style.apply(fontFeatures: [FontFeatures.enable("test")]).fontFeatures,
            [FontFeatures.enable("test")]
        )
        XCTAssertEqual(style.apply().fontVariations, [FlutterSwiftBridge.FontVariation]())
        XCTAssertEqual(
            style.apply(
                fontVariations: [FlutterSwiftBridge.FontVariation("test", 100.0)]
            ).fontVariations,
            [FlutterSwiftBridge.FontVariation("test", 100.0)]
        )
        XCTAssertEqual(style.apply().textBaseline, TextBaseline.alphabetic)
        XCTAssertEqual(
            style.apply(textBaseline: .ideographic).textBaseline,
            TextBaseline.ideographic
        )
        XCTAssertEqual(style.apply().leadingDistribution, TextLeadingDistribution.even)
        XCTAssertEqual(
            style.apply(leadingDistribution: .proportional).leadingDistribution,
            TextLeadingDistribution.proportional
        )

        // kTextHeightNone is preserved by apply
        let noneHeightStyle = PaintingTextStyle(height: kTextHeightNone)
        XCTAssertEqual(
            noneHeightStyle.apply(heightFactor: 1000, heightDelta: 1000).height,
            kTextHeightNone
        )
    }

    // MARK: - fontFamily and package Tests

    /// Test fontFamily and package interactions.
    ///
    /// **Dart Test:** `text_style_test.dart:664-704`
    func testFontFamilyAndPackage() {
        let fooStyle = PaintingTextStyle(fontFamily: "fontFamily", package: "foo")
        let barStyle = PaintingTextStyle(fontFamily: "fontFamily", package: "bar")
        XCTAssertNotEqual(fooStyle, barStyle)
        XCTAssertNotEqual(fooStyle.hashValue, barStyle.hashValue)

        XCTAssertEqual(
            PaintingTextStyle(fontFamily: "fontFamily").fontFamily,
            "fontFamily"
        )
        XCTAssertEqual(
            PaintingTextStyle(fontFamily: "fontFamily").copyWith(package: "bar").fontFamily,
            "packages/bar/fontFamily"
        )
        XCTAssertEqual(
            PaintingTextStyle(fontFamily: "fontFamily", package: "foo").fontFamily,
            "packages/foo/fontFamily"
        )
        XCTAssertEqual(
            PaintingTextStyle(fontFamily: "fontFamily", package: "foo")
                .copyWith(package: "bar").fontFamily,
            "packages/bar/fontFamily"
        )
        XCTAssertEqual(
            PaintingTextStyle()
                .merge(PaintingTextStyle(fontFamily: "fontFamily", package: "bar")).fontFamily,
            "packages/bar/fontFamily"
        )
        XCTAssertEqual(
            PaintingTextStyle()
                .apply(fontFamily: "fontFamily", package: "foo").fontFamily,
            "packages/foo/fontFamily"
        )
        XCTAssertEqual(
            PaintingTextStyle(fontFamily: "fontFamily", package: "foo")
                .apply(fontFamily: "fontFamily", package: "bar").fontFamily,
            "packages/bar/fontFamily"
        )
    }

    // MARK: - compareTo Tests

    /// Test compareTo returns identical for equal styles.
    func testCompareToIdentical() {
        let s = PaintingTextStyle(fontSize: 14, fontWeight: .w400)
        XCTAssertEqual(s.compareTo(s), RenderComparison.identical)
    }

    /// Test compareTo returns identical for equal but separate instances.
    func testCompareToEqual() {
        let s1 = PaintingTextStyle(fontSize: 14, fontWeight: .w400)
        let s2 = PaintingTextStyle(fontSize: 14, fontWeight: .w400)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.identical)
    }

    /// Test compareTo returns layout for different layout properties.
    func testCompareToLayout() {
        let s1 = PaintingTextStyle(fontSize: 14)
        let s2 = PaintingTextStyle(fontSize: 16)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.layout)
    }

    /// Test compareTo returns paint for different color.
    func testCompareToPaint() {
        let s1 = PaintingTextStyle(color: Color(0xFFFF0000))
        let s2 = PaintingTextStyle(color: Color(0xFF00FF00))
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.paint)
    }

    /// Test compareTo returns paint for different decoration.
    func testCompareToPaintDecoration() {
        let s1 = PaintingTextStyle(decoration: .underline)
        let s2 = PaintingTextStyle(decoration: .lineThrough)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.paint)
    }

    /// Test compareTo returns layout for different fontFamily.
    func testCompareToLayoutFontFamily() {
        let s1 = PaintingTextStyle(fontFamily: "Roboto")
        let s2 = PaintingTextStyle(fontFamily: "Arial")
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.layout)
    }

    /// Test compareTo returns layout for different fontWeight.
    func testCompareToLayoutFontWeight() {
        let s1 = PaintingTextStyle(fontWeight: .w400)
        let s2 = PaintingTextStyle(fontWeight: .w700)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.layout)
    }

    /// Test compareTo with foreground paints.
    func testCompareToForegroundPaint() {
        let paint1 = Paint()
        let paint2 = Paint()
        let s1 = PaintingTextStyle(foreground: paint1)
        let s2 = PaintingTextStyle(foreground: paint2)
        XCTAssertEqual(s1.compareTo(s2), RenderComparison.layout)

        // Same paint object
        let s3 = PaintingTextStyle(foreground: paint1)
        XCTAssertEqual(s1.compareTo(s3), RenderComparison.identical)
    }

    // MARK: - Equality Edge Cases

    /// Test debugLabel is not considered in equality.
    func testDebugLabelNotInEquality() {
        let s1 = PaintingTextStyle(fontSize: 14, debugLabel: "label1")
        let s2 = PaintingTextStyle(fontSize: 14, debugLabel: "label2")
        XCTAssertEqual(s1, s2)
    }

    /// Test equality with all properties.
    func testEqualityWithAllProperties() {
        let paint = Paint()
        let s1 = PaintingTextStyle(
            inherit: false,
            color: nil,
            backgroundColor: nil,
            fontSize: 14,
            fontWeight: .w700,
            fontStyle: .italic,
            letterSpacing: 1.0,
            wordSpacing: 2.0,
            textBaseline: .alphabetic,
            height: 1.5,
            leadingDistribution: .even,
            locale: Locale("en"),
            foreground: paint,
            decoration: .underline,
            decorationColor: Color(0xFFFF0000),
            decorationStyle: .dashed,
            decorationThickness: 2.0,
            fontFamily: "Roboto",
            fontFamilyFallback: ["Arial"],
            overflow: .ellipsis
        )
        let s2 = PaintingTextStyle(
            inherit: false,
            color: nil,
            backgroundColor: nil,
            fontSize: 14,
            fontWeight: .w700,
            fontStyle: .italic,
            letterSpacing: 1.0,
            wordSpacing: 2.0,
            textBaseline: .alphabetic,
            height: 1.5,
            leadingDistribution: .even,
            locale: Locale("en"),
            foreground: paint,
            decoration: .underline,
            decorationColor: Color(0xFFFF0000),
            decorationStyle: .dashed,
            decorationThickness: 2.0,
            fontFamily: "Roboto",
            fontFamilyFallback: ["Arial"],
            overflow: .ellipsis
        )
        XCTAssertEqual(s1, s2)
    }

    // MARK: - Value Semantics Tests

    /// Test struct value semantics.
    func testValueSemantics() {
        let original = PaintingTextStyle(fontSize: 14, fontFamily: "Roboto")
        var copy = original
        copy = PaintingTextStyle(fontSize: 16, fontFamily: "Arial")

        XCTAssertEqual(original.fontFamily, "Roboto")
        XCTAssertEqual(original.fontSize, 14)
        XCTAssertEqual(copy.fontFamily, "Arial")
        XCTAssertEqual(copy.fontSize, 16)
    }

    // MARK: - Merge with inherit:false Tests

    /// Test merge with other.inherit = false returns other unchanged.
    func testMergeInheritFalse() {
        let base = PaintingTextStyle(
            color: Color(0xFFFF0000),
            fontSize: 14,
            fontWeight: .w400
        )
        let other = PaintingTextStyle(inherit: false, fontSize: 20)
        let merged = base.merge(other)
        XCTAssertEqual(merged, other)
    }

    // MARK: - lerpFontVariations Tests

    /// Test lerpFontVariations with nil/empty cases.
    ///
    /// **Dart Test:** `text_style_test.dart:738-760`
    func testLerpFontVariationsNilCases() {
        let empty: [FlutterSwiftBridge.FontVariation] = []
        XCTAssertEqual(lerpFontVariations(empty, empty, 0.0), empty)
        XCTAssertEqual(lerpFontVariations(empty, empty, 0.5), empty)
        XCTAssertEqual(lerpFontVariations(empty, empty, 1.0), empty)
        XCTAssertNil(lerpFontVariations(nil, empty, 0.0))
        XCTAssertEqual(lerpFontVariations(empty, nil, 0.0), empty)
        XCTAssertNil(lerpFontVariations(nil, nil, 0.0))
        XCTAssertEqual(lerpFontVariations(nil, empty, 0.5), empty)
        XCTAssertNil(lerpFontVariations(empty, nil, 0.5))
        XCTAssertNil(lerpFontVariations(nil, nil, 0.5))
        XCTAssertEqual(lerpFontVariations(nil, empty, 1.0), empty)
        XCTAssertNil(lerpFontVariations(empty, nil, 1.0))
        XCTAssertNil(lerpFontVariations(nil, nil, 1.0))
    }

    /// Test lerpFontVariations with one axis.
    ///
    /// **Dart Test:** `text_style_test.dart:762-785`
    func testLerpFontVariationsOneAxis() {
        let w100 = FlutterSwiftBridge.FontVariation(weight: 100.0)
        let w120 = FlutterSwiftBridge.FontVariation(weight: 120.0)
        let w150 = FlutterSwiftBridge.FontVariation(weight: 150.0)
        let w200 = FlutterSwiftBridge.FontVariation(weight: 200.0)
        let w300 = FlutterSwiftBridge.FontVariation(weight: 300.0)

        XCTAssertEqual(lerpFontVariations([w100], [w200], 0.0), [w100])
        XCTAssertEqual(lerpFontVariations([w100], [w200], 0.2), [w120])
        XCTAssertEqual(lerpFontVariations([w100], [w200], 0.5), [w150])
        XCTAssertEqual(lerpFontVariations([w100], [w200], 2.0), [w300])
    }

    /// Test lerpFontVariations with two axes matched order.
    ///
    /// **Dart Test:** `text_style_test.dart:811-815`
    func testLerpFontVariationsTwoAxesMatched() {
        let w100 = FlutterSwiftBridge.FontVariation(weight: 100.0)
        let w200 = FlutterSwiftBridge.FontVariation(weight: 200.0)
        let w300 = FlutterSwiftBridge.FontVariation(weight: 300.0)
        let sn80 = FlutterSwiftBridge.FontVariation(slant: -80.0)
        let s0 = FlutterSwiftBridge.FontVariation(slant: 0.0)
        let sp80 = FlutterSwiftBridge.FontVariation(slant: 80.0)

        XCTAssertEqual(
            lerpFontVariations([w100, sn80], [w300, sp80], 0.5),
            [w200, s0]
        )
    }

    /// Test lerpFontVariations with two axes unmatched order.
    ///
    /// **Dart Test:** `text_style_test.dart:817-829`
    func testLerpFontVariationsTwoAxesUnmatched() {
        let w100 = FlutterSwiftBridge.FontVariation(weight: 100.0)
        let w200 = FlutterSwiftBridge.FontVariation(weight: 200.0)
        let w300 = FlutterSwiftBridge.FontVariation(weight: 300.0)
        let sn80 = FlutterSwiftBridge.FontVariation(slant: -80.0)
        let s0 = FlutterSwiftBridge.FontVariation(slant: 0.0)
        let sp80 = FlutterSwiftBridge.FontVariation(slant: 80.0)

        XCTAssertEqual(
            lerpFontVariations([sn80, w100], [w300, sp80], 0.0),
            [sn80, w100]
        )

        // Unmatched order at t=0.5 - result contains both axes but order may vary
        let result = lerpFontVariations([sn80, w100], [w300, sp80], 0.5)!
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains(s0))
        XCTAssertTrue(result.contains(w200))

        XCTAssertEqual(
            lerpFontVariations([sn80, w100], [w300, sp80], 1.0),
            [w300, sp80]
        )
    }

    /// Test lerpFontVariations with mixed axis counts.
    ///
    /// **Dart Test:** `text_style_test.dart:841-861`
    func testLerpFontVariationsMixedAxisCounts() {
        let w100 = FlutterSwiftBridge.FontVariation(weight: 100.0)
        let w200 = FlutterSwiftBridge.FontVariation(weight: 200.0)
        let w300 = FlutterSwiftBridge.FontVariation(weight: 300.0)
        let sn80 = FlutterSwiftBridge.FontVariation(slant: -80.0)

        XCTAssertEqual(
            lerpFontVariations([sn80, w100], [w300], 0.5),
            [w200]
        )
        XCTAssertEqual(lerpFontVariations([sn80], [w300], 0.0), [sn80])
        XCTAssertEqual(lerpFontVariations([sn80], [w300], 0.1), [sn80])
        XCTAssertEqual(lerpFontVariations([sn80], [w300], 0.9), [w300])
        XCTAssertEqual(lerpFontVariations([sn80], [w300], 1.0), [w300])
    }

    // MARK: - Set Usage Tests

    /// Test TextStyle can be used as a Set element.
    func testAsSetElement() {
        let s1 = PaintingTextStyle(fontSize: 14, fontFamily: "Roboto")
        let s2 = PaintingTextStyle(fontSize: 14, fontFamily: "Roboto")
        let s3 = PaintingTextStyle(fontSize: 16, fontFamily: "Arial")

        var set = Set<PaintingTextStyle>()
        set.insert(s1)
        set.insert(s2)
        set.insert(s3)

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(s1))
        XCTAssertTrue(set.contains(s3))
    }

    // MARK: - Default Initializer Tests

    /// Test default initializer values.
    func testDefaultInitializer() {
        let style = PaintingTextStyle()
        XCTAssertTrue(style.inherit)
        XCTAssertNil(style.color)
        XCTAssertNil(style.backgroundColor)
        XCTAssertNil(style.fontFamily)
        XCTAssertNil(style.fontSize)
        XCTAssertNil(style.fontWeight)
        XCTAssertNil(style.fontStyle)
        XCTAssertNil(style.letterSpacing)
        XCTAssertNil(style.wordSpacing)
        XCTAssertNil(style.textBaseline)
        XCTAssertNil(style.height)
        XCTAssertNil(style.leadingDistribution)
        XCTAssertNil(style.locale)
        XCTAssertNil(style.foreground)
        XCTAssertNil(style.background)
        XCTAssertNil(style.shadows)
        XCTAssertNil(style.fontFeatures)
        XCTAssertNil(style.fontVariations)
        XCTAssertNil(style.decoration)
        XCTAssertNil(style.decorationColor)
        XCTAssertNil(style.decorationStyle)
        XCTAssertNil(style.decorationThickness)
        XCTAssertNil(style.debugLabel)
        XCTAssertNil(style.overflow)
    }
}

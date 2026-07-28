// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tests for TextPainter and related types.
///
/// **Dart Test Source:** `packages/flutter/test/painting/text_painter_test.dart`
///
/// Note: Many tests in the Dart source require actual text layout engine support
/// (caret positioning, line metrics, layout widths, etc.). These tests focus on
/// the painting-layer API surface that can be tested without engine support:
/// construction, property management, static utilities, enums, and helper types.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

final class TextPainterTests: XCTestCase {

    // MARK: - Constructor and Default Values

    /// Test that TextPainter constructor defaults are correct.
    ///
    /// **Dart Test:** `text_painter_test.dart` (various constructor tests)
    func testDefaultConstructor() {
        let painter = TextPainter()
        XCTAssertNil(painter.text)
        XCTAssertEqual(painter.textAlign, .start)
        XCTAssertNil(painter.textDirection)
        XCTAssertTrue(painter.textScaler == TextScalers.noScaling)
        XCTAssertNil(painter.maxLines)
        XCTAssertNil(painter.ellipsis)
        XCTAssertNil(painter.locale)
        XCTAssertNil(painter.strutStyle)
        XCTAssertEqual(painter.textWidthBasis, .parent)
        XCTAssertNil(painter.textHeightBehavior)
        XCTAssertFalse(painter.debugDisposed)
        painter.dispose()
    }

    /// Test that TextPainter can be constructed with all parameters.
    func testConstructorWithAllParameters() {
        let span = TextSpan(text: "Hello")
        let painter = TextPainter(
            text: span,
            textAlign: .center,
            textDirection: .ltr,
            textScaler: TextScalers.linear(2.0),
            maxLines: 3,
            ellipsis: "...",
            strutStyle: StrutStyle(fontSize: 14.0),
            textWidthBasis: .longestLine
        )
        XCTAssertNotNil(painter.text)
        XCTAssertEqual(painter.textAlign, .center)
        XCTAssertEqual(painter.textDirection, .ltr)
        XCTAssertTrue(painter.textScaler == TextScalers.linear(2.0))
        XCTAssertEqual(painter.maxLines, 3)
        XCTAssertEqual(painter.ellipsis, "...")
        XCTAssertEqual(painter.textWidthBasis, .longestLine)
        painter.dispose()
    }

    // MARK: - Property Setters

    /// Test that setting text property works.
    func testSetText() {
        let painter = TextPainter()
        XCTAssertNil(painter.text)

        let span = TextSpan(text: "Hello")
        painter.text = span
        XCTAssertNotNil(painter.text)

        painter.text = nil
        XCTAssertNil(painter.text)
        painter.dispose()
    }

    /// Test that setting textAlign property works.
    func testSetTextAlign() {
        let painter = TextPainter()
        XCTAssertEqual(painter.textAlign, .start)

        painter.textAlign = .center
        XCTAssertEqual(painter.textAlign, .center)

        painter.textAlign = .end
        XCTAssertEqual(painter.textAlign, .end)

        painter.textAlign = .justify
        XCTAssertEqual(painter.textAlign, .justify)
        painter.dispose()
    }

    /// Test that setting textDirection property works.
    func testSetTextDirection() {
        let painter = TextPainter()
        XCTAssertNil(painter.textDirection)

        painter.textDirection = .ltr
        XCTAssertEqual(painter.textDirection, .ltr)

        painter.textDirection = .rtl
        XCTAssertEqual(painter.textDirection, .rtl)
        painter.dispose()
    }

    /// Test that setting textScaler property works.
    func testSetTextScaler() {
        let painter = TextPainter()
        XCTAssertTrue(painter.textScaler == TextScalers.noScaling)

        painter.textScaler = TextScalers.linear(2.0)
        XCTAssertTrue(painter.textScaler == TextScalers.linear(2.0))

        painter.textScaler = TextScalers.noScaling
        XCTAssertTrue(painter.textScaler == TextScalers.noScaling)
        painter.dispose()
    }

    /// Test that setting maxLines property works.
    func testSetMaxLines() {
        let painter = TextPainter()
        XCTAssertNil(painter.maxLines)

        painter.maxLines = 5
        XCTAssertEqual(painter.maxLines, 5)

        painter.maxLines = nil
        XCTAssertNil(painter.maxLines)
        painter.dispose()
    }

    /// Test that setting ellipsis property works.
    func testSetEllipsis() {
        let painter = TextPainter()
        XCTAssertNil(painter.ellipsis)

        painter.ellipsis = "..."
        XCTAssertEqual(painter.ellipsis, "...")

        painter.ellipsis = "\u{2026}"  // Horizontal ellipsis
        XCTAssertEqual(painter.ellipsis, "\u{2026}")

        painter.ellipsis = nil
        XCTAssertNil(painter.ellipsis)
        painter.dispose()
    }

    /// Test that setting strutStyle property works.
    func testSetStrutStyle() {
        let painter = TextPainter()
        XCTAssertNil(painter.strutStyle)

        let strut = Flutter.StrutStyle(fontSize: 14.0)
        painter.strutStyle = strut
        XCTAssertEqual(painter.strutStyle, strut)

        painter.strutStyle = nil
        XCTAssertNil(painter.strutStyle)
        painter.dispose()
    }

    /// Test that setting textWidthBasis property works.
    func testSetTextWidthBasis() {
        let painter = TextPainter()
        XCTAssertEqual(painter.textWidthBasis, .parent)

        painter.textWidthBasis = .longestLine
        XCTAssertEqual(painter.textWidthBasis, .longestLine)

        painter.textWidthBasis = .parent
        XCTAssertEqual(painter.textWidthBasis, .parent)
        painter.dispose()
    }

    /// Test that setting textHeightBehavior property works.
    func testSetTextHeightBehavior() {
        let painter = TextPainter()
        XCTAssertNil(painter.textHeightBehavior)

        let behavior = TextHeightBehavior()
        painter.textHeightBehavior = behavior
        XCTAssertNotNil(painter.textHeightBehavior)

        painter.textHeightBehavior = nil
        XCTAssertNil(painter.textHeightBehavior)
        painter.dispose()
    }

    // MARK: - plainText

    /// Test plainText returns the text content.
    func testPlainText() {
        let painter = TextPainter(
            text: TextSpan(text: "Hello, world!")
        )
        XCTAssertEqual(painter.plainText, "Hello, world!")
        painter.dispose()
    }

    /// Test plainText returns empty string when text is nil.
    func testPlainTextNil() {
        let painter = TextPainter()
        XCTAssertEqual(painter.plainText, "")
        painter.dispose()
    }

    /// Test plainText with nested TextSpans.
    func testPlainTextNested() {
        let painter = TextPainter(
            text: TextSpan(
                text: "Hello",
                children: [
                    TextSpan(text: ", "),
                    TextSpan(text: "world!"),
                ]
            )
        )
        XCTAssertEqual(painter.plainText, "Hello, world!")
        painter.dispose()
    }

    // MARK: - Static UTF-16 Methods

    /// Test isHighSurrogate static method.
    ///
    /// **Dart Source:** `text_painter.dart:1392-1395`
    func testIsHighSurrogate() {
        // U+D800 is the first high surrogate
        XCTAssertTrue(TextPainter.isHighSurrogate(0xD800))
        // U+DBFF is the last high surrogate
        XCTAssertTrue(TextPainter.isHighSurrogate(0xDBFF))
        // U+D900 is in the middle of the high surrogate range
        XCTAssertTrue(TextPainter.isHighSurrogate(0xD900))

        // U+DC00 is the first low surrogate (not a high surrogate)
        XCTAssertFalse(TextPainter.isHighSurrogate(0xDC00))
        // Regular ASCII character
        XCTAssertFalse(TextPainter.isHighSurrogate(0x0041))
        // U+FFFF
        XCTAssertFalse(TextPainter.isHighSurrogate(0xFFFF))
    }

    /// Test isLowSurrogate static method.
    ///
    /// **Dart Source:** `text_painter.dart:1405-1408`
    func testIsLowSurrogate() {
        // U+DC00 is the first low surrogate
        XCTAssertTrue(TextPainter.isLowSurrogate(0xDC00))
        // U+DFFF is the last low surrogate
        XCTAssertTrue(TextPainter.isLowSurrogate(0xDFFF))
        // U+DD00 is in the middle of the low surrogate range
        XCTAssertTrue(TextPainter.isLowSurrogate(0xDD00))

        // U+D800 is a high surrogate (not a low surrogate)
        XCTAssertFalse(TextPainter.isLowSurrogate(0xD800))
        // Regular ASCII character
        XCTAssertFalse(TextPainter.isLowSurrogate(0x0041))
        // U+FFFF
        XCTAssertFalse(TextPainter.isLowSurrogate(0xFFFF))
    }

    // MARK: - Dispose

    /// Test that dispose marks the painter as disposed.
    func testDispose() {
        let painter = TextPainter()
        XCTAssertFalse(painter.debugDisposed)
        painter.dispose()
        XCTAssertTrue(painter.debugDisposed)
    }

    /// Test that dispose cleans up the text reference.
    func testDisposeReleasesText() {
        let painter = TextPainter(
            text: TextSpan(text: "Hello")
        )
        XCTAssertNotNil(painter.text)
        painter.dispose()
        XCTAssertNil(painter.text)
    }

    // MARK: - setPlaceholderDimensions

    /// Test that setPlaceholderDimensions accepts non-empty value.
    func testSetPlaceholderDimensions() {
        let painter = TextPainter()
        let dims = [
            PlaceholderDimensions(size: Size(100, 50), alignment: .bottom)
        ]
        // This should not crash
        painter.setPlaceholderDimensions(dims)
        painter.dispose()
    }

    /// Test that setPlaceholderDimensions ignores nil.
    func testSetPlaceholderDimensionsNil() {
        let painter = TextPainter()
        // This should not crash
        painter.setPlaceholderDimensions(nil)
        painter.dispose()
    }

    /// Test that setPlaceholderDimensions ignores empty list.
    func testSetPlaceholderDimensionsEmpty() {
        let painter = TextPainter()
        // This should not crash
        painter.setPlaceholderDimensions([])
        painter.dispose()
    }

    // MARK: - inlinePlaceholderBoxes

    /// Test that inlinePlaceholderBoxes is nil before layout.
    func testInlinePlaceholderBoxesBeforeLayout() {
        let painter = TextPainter()
        XCTAssertNil(painter.inlinePlaceholderBoxes)
        painter.dispose()
    }
}

// MARK: - TextWidthBasis Tests

final class TextWidthBasisTests: XCTestCase {

    /// Test TextWidthBasis enum values exist.
    ///
    /// **Dart Source:** `text_painter.dart:152-162`
    func testEnumValues() {
        let parent = TextWidthBasis.parent
        let longestLine = TextWidthBasis.longestLine
        XCTAssertNotEqual(parent, longestLine)
    }

    /// Test TextWidthBasis equality.
    func testEquality() {
        XCTAssertEqual(TextWidthBasis.parent, TextWidthBasis.parent)
        XCTAssertEqual(TextWidthBasis.longestLine, TextWidthBasis.longestLine)
        XCTAssertNotEqual(TextWidthBasis.parent, TextWidthBasis.longestLine)
    }
}

// MARK: - TextOverflow Tests

final class TextOverflowTests: XCTestCase {

    /// Test TextOverflow enum values exist.
    ///
    /// **Dart Source:** `text_painter.dart:47-59`
    func testEnumValues() {
        let clip = TextOverflow.clip
        let fade = TextOverflow.fade
        let ellipsis = TextOverflow.ellipsis
        let visible = TextOverflow.visible

        XCTAssertNotEqual(clip, fade)
        XCTAssertNotEqual(clip, ellipsis)
        XCTAssertNotEqual(clip, visible)
        XCTAssertNotEqual(fade, ellipsis)
        XCTAssertNotEqual(fade, visible)
        XCTAssertNotEqual(ellipsis, visible)
    }

    /// Test TextOverflow equality.
    func testEquality() {
        XCTAssertEqual(TextOverflow.clip, TextOverflow.clip)
        XCTAssertEqual(TextOverflow.fade, TextOverflow.fade)
        XCTAssertEqual(TextOverflow.ellipsis, TextOverflow.ellipsis)
        XCTAssertEqual(TextOverflow.visible, TextOverflow.visible)
    }
}

// MARK: - PlaceholderDimensions Tests (extended from InlineSpanTests)

final class TextPainterPlaceholderDimensionsTests: XCTestCase {

    /// Test PlaceholderDimensions with baseline alignment.
    ///
    /// **Dart Source:** `text_painter.dart:73-147`
    func testBaselineAlignment() {
        let dims = PlaceholderDimensions(
            size: Size(50, 30),
            alignment: .baseline,
            baseline: .alphabetic,
            baselineOffset: 20.0
        )
        XCTAssertEqual(dims.size, Size(50, 30))
        XCTAssertEqual(dims.alignment, .baseline)
        XCTAssertEqual(dims.baseline, .alphabetic)
        XCTAssertEqual(dims.baselineOffset, 20.0)
    }

    /// Test PlaceholderDimensions toString for baseline alignment.
    func testToStringBaseline() {
        let dims = PlaceholderDimensions(
            size: Size(50, 30),
            alignment: .baseline,
            baseline: .alphabetic,
            baselineOffset: 20.0
        )
        let desc = dims.description
        XCTAssertTrue(desc.contains("PlaceholderDimensions"))
        XCTAssertTrue(desc.contains("baseline"))
        XCTAssertTrue(desc.contains("20.0"))
    }

    /// Test PlaceholderDimensions toString for non-baseline alignment.
    func testToStringNonBaseline() {
        let dims = PlaceholderDimensions(
            size: Size(50, 30),
            alignment: .bottom
        )
        let desc = dims.description
        XCTAssertTrue(desc.contains("PlaceholderDimensions"))
        XCTAssertTrue(desc.contains("bottom"))
    }

    /// Test PlaceholderDimensions.empty constant.
    func testEmptyConstant() {
        let empty = PlaceholderDimensions.empty
        XCTAssertEqual(empty.size, Size.zero)
        XCTAssertEqual(empty.alignment, .bottom)
        XCTAssertNil(empty.baseline)
        XCTAssertNil(empty.baselineOffset)
    }

    /// Test PlaceholderDimensions Hashable conformance.
    func testHashable() {
        let a = PlaceholderDimensions(size: Size(10, 20), alignment: .top)
        let b = PlaceholderDimensions(size: Size(10, 20), alignment: .top)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    /// Test PlaceholderDimensions equality.
    func testEquality() {
        let a = PlaceholderDimensions(
            size: Size(100, 50),
            alignment: .baseline,
            baseline: .alphabetic,
            baselineOffset: 30.0
        )
        let b = PlaceholderDimensions(
            size: Size(100, 50),
            alignment: .baseline,
            baseline: .alphabetic,
            baselineOffset: 30.0
        )
        XCTAssertEqual(a, b)
    }

    /// Test PlaceholderDimensions inequality.
    func testInequality() {
        let a = PlaceholderDimensions(
            size: Size(100, 50),
            alignment: .baseline,
            baseline: .alphabetic,
            baselineOffset: 30.0
        )
        let b = PlaceholderDimensions(
            size: Size(100, 50),
            alignment: .baseline,
            baseline: .ideographic,
            baselineOffset: 30.0
        )
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - LineCaretMetrics Tests

final class LineCaretMetricsTests: XCTestCase {

    /// Test LineCaretMetrics creation and shift.
    ///
    /// **Dart Source:** `text_painter.dart:534-562`
    func testShiftByZero() {
        let metrics = LineCaretMetrics(
            offset: Offset(10, 20),
            writingDirection: .ltr,
            height: 14.0
        )
        let shifted = metrics.shift(Offset.zero)
        // Shifting by zero should return same values
        XCTAssertEqual(shifted.offset.dx, 10)
        XCTAssertEqual(shifted.offset.dy, 20)
        XCTAssertEqual(shifted.writingDirection, .ltr)
        XCTAssertEqual(shifted.height, 14.0)
    }

    /// Test LineCaretMetrics shift by non-zero offset.
    func testShiftByNonZero() {
        let metrics = LineCaretMetrics(
            offset: Offset(10, 20),
            writingDirection: .rtl,
            height: 16.0
        )
        let shifted = metrics.shift(Offset(5, 3))
        XCTAssertEqual(shifted.offset.dx, 15)
        XCTAssertEqual(shifted.offset.dy, 23)
        XCTAssertEqual(shifted.writingDirection, .rtl)
        XCTAssertEqual(shifted.height, 16.0)
    }
}

// MARK: - WordBoundary Tests

final class WordBoundaryTests: XCTestCase {

    /// Test WordBoundary._isNewline static method.
    ///
    /// **Dart Source:** `text_painter.dart:216-227`
    func testIsNewline() {
        // Line Feed (U+000A)
        XCTAssertTrue(WordBoundary._isNewline(0x000A))
        // New Line (U+0085)
        XCTAssertTrue(WordBoundary._isNewline(0x0085))
        // Form Feed (U+000B)
        XCTAssertTrue(WordBoundary._isNewline(0x000B))
        // Vertical Feed (U+000C)
        XCTAssertTrue(WordBoundary._isNewline(0x000C))
        // Line Separator (U+2028)
        XCTAssertTrue(WordBoundary._isNewline(0x2028))
        // Paragraph Separator (U+2029)
        XCTAssertTrue(WordBoundary._isNewline(0x2029))

        // Regular characters should not be newlines
        XCTAssertFalse(WordBoundary._isNewline(0x0041))  // 'A'
        XCTAssertFalse(WordBoundary._isNewline(0x0020))  // Space
        XCTAssertFalse(WordBoundary._isNewline(0x0009))  // Tab
        // Carriage Return is NOT treated as a hard line break
        XCTAssertFalse(WordBoundary._isNewline(0x000D))
    }
}

// MARK: - TextSelection Tests

final class TextSelectionTests: XCTestCase {

    /// Test TextSelection construction.
    func testConstruction() {
        let sel = TextSelection(baseOffset: 5, extentOffset: 10)
        XCTAssertEqual(sel.baseOffset, 5)
        XCTAssertEqual(sel.extentOffset, 10)
        XCTAssertEqual(sel.start, 5)
        XCTAssertEqual(sel.end, 10)
        XCTAssertFalse(sel.isCollapsed)
        XCTAssertTrue(sel.isValid)
    }

    /// Test collapsed TextSelection.
    func testCollapsed() {
        let sel = TextSelection(offset: 5)
        XCTAssertEqual(sel.baseOffset, 5)
        XCTAssertEqual(sel.extentOffset, 5)
        XCTAssertTrue(sel.isCollapsed)
        XCTAssertEqual(sel.start, 5)
        XCTAssertEqual(sel.end, 5)
    }

    /// Test reversed TextSelection.
    func testReversed() {
        let sel = TextSelection(baseOffset: 10, extentOffset: 5)
        XCTAssertEqual(sel.start, 5)
        XCTAssertEqual(sel.end, 10)
        XCTAssertFalse(sel.isCollapsed)
    }

    /// Test TextSelection equality.
    func testEquality() {
        let a = TextSelection(baseOffset: 3, extentOffset: 7)
        let b = TextSelection(baseOffset: 3, extentOffset: 7)
        XCTAssertEqual(a, b)

        let c = TextSelection(baseOffset: 3, extentOffset: 8)
        XCTAssertNotEqual(a, c)
    }

    /// Test TextSelection base and extent positions.
    func testBaseAndExtent() {
        let sel = TextSelection(baseOffset: 3, extentOffset: 7)
        XCTAssertEqual(sel.base.offset, 3)
        XCTAssertEqual(sel.extent.offset, 7)
    }
}

// MARK: - kDefaultFontSize Tests

final class DefaultFontSizeTests: XCTestCase {

    /// Test that the default font size constant is 14.0.
    ///
    /// **Dart Source:** `text_painter.dart:41`
    func testDefaultFontSize() {
        XCTAssertEqual(kDefaultFontSize, 14.0)
    }
}

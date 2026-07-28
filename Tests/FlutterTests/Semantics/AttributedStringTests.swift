// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Typealias to disambiguate Flutter.AttributedString from Foundation.AttributedString.
private typealias FlutterAttributedString = Flutter.AttributedString
/// Typealias to disambiguate FlutterSwiftBridge.Locale from Foundation.Locale.
private typealias FlutterLocale = FlutterSwiftBridge.Locale

/// Tests for `AttributedString` and `SemanticsLabelBuilder`.
///
/// **Dart Test Source:** `packages/flutter/test/semantics/semantics_test.dart`
final class AttributedStringTests: XCTestCase {

    // MARK: - AttributedString Construction Tests

    /// Test construction with string only (no attributes).
    func testConstructionWithStringOnly() {
        let attrStr = FlutterAttributedString("Hello")
        XCTAssertEqual(attrStr.string, "Hello")
        XCTAssertTrue(attrStr.attributes.isEmpty)
    }

    /// Test construction with empty string.
    func testConstructionWithEmptyString() {
        let attrStr = FlutterAttributedString("")
        XCTAssertEqual(attrStr.string, "")
        XCTAssertTrue(attrStr.attributes.isEmpty)
    }

    /// Test construction with string and attributes.
    ///
    /// **Dart Test:** `semantics_test.dart:875-898`
    func testConstructionWithAttributes() {
        let attrStr = FlutterAttributedString(
            "Hello",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 3))
            ]
        )
        XCTAssertEqual(attrStr.string, "Hello")
        XCTAssertEqual(attrStr.attributes.count, 1)
        XCTAssertEqual(attrStr.attributes[0].range, TextRange(start: 0, end: 3))
        XCTAssertTrue(attrStr.attributes[0] is SpellOutStringAttribute)
    }

    // MARK: - Concatenation Tests

    /// Test `+` operator concatenation of two attributed strings.
    ///
    /// **Dart Test:** `semantics_test.dart:874-898`
    func testConcatenation() {
        let string1 = FlutterAttributedString(
            "string1",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 4))
            ]
        )
        let string2 = FlutterAttributedString(
            "string2",
            attributes: [
                LocaleStringAttribute(
                    range: TextRange(start: 0, end: 4),
                    locale: FlutterLocale("es", "MX")
                )
            ]
        )
        let result = string1 + string2

        XCTAssertEqual(result.string, "string1string2")
        XCTAssertEqual(result.attributes.count, 2)

        // First attribute should be unchanged
        XCTAssertEqual(result.attributes[0].range, TextRange(start: 0, end: 4))
        XCTAssertTrue(result.attributes[0] is SpellOutStringAttribute)

        // Second attribute should have offset range
        XCTAssertEqual(result.attributes[1].range, TextRange(start: 7, end: 11))
        XCTAssertTrue(result.attributes[1] is LocaleStringAttribute)
    }

    /// Test concatenation with empty left-hand side returns right-hand side.
    func testConcatenationWithEmptyLHS() {
        let empty = FlutterAttributedString("")
        let rhs = FlutterAttributedString("world")
        let result = empty + rhs
        XCTAssertEqual(result.string, "world")
    }

    /// Test concatenation with empty right-hand side returns left-hand side.
    func testConcatenationWithEmptyRHS() {
        let lhs = FlutterAttributedString("hello")
        let empty = FlutterAttributedString("")
        let result = lhs + empty
        XCTAssertEqual(result.string, "hello")
    }

    /// Test concatenation of two strings without attributes.
    func testConcatenationWithoutAttributes() {
        let s1 = FlutterAttributedString("Hello")
        let s2 = FlutterAttributedString("World")
        let result = s1 + s2
        XCTAssertEqual(result.string, "HelloWorld")
        XCTAssertTrue(result.attributes.isEmpty)
    }

    /// Test concatenation preserves attribute offsets correctly.
    func testConcatenationAttributeOffsets() {
        let s1 = FlutterAttributedString(
            "abc",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 1, end: 2))
            ]
        )
        let s2 = FlutterAttributedString(
            "def",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 1))
            ]
        )
        let result = s1 + s2

        XCTAssertEqual(result.string, "abcdef")
        XCTAssertEqual(result.attributes.count, 2)
        // s1 attribute unchanged
        XCTAssertEqual(result.attributes[0].range, TextRange(start: 1, end: 2))
        // s2 attribute offset by s1.string.count (3)
        XCTAssertEqual(result.attributes[1].range, TextRange(start: 3, end: 4))
    }

    // MARK: - Equality Tests

    /// Test that two attributed strings with same string and no attributes are equal.
    func testEqualityNoAttributes() {
        let s1 = FlutterAttributedString("same")
        let s2 = FlutterAttributedString("same")
        XCTAssertTrue(s1 == s2)
    }

    /// Test that two attributed strings with different strings are not equal.
    func testInequalityDifferentStrings() {
        let s1 = FlutterAttributedString("one")
        let s2 = FlutterAttributedString("two")
        XCTAssertTrue(s1 != s2)
    }

    /// Test equality with matching attributes.
    func testEqualityWithMatchingAttributes() {
        let s1 = FlutterAttributedString(
            "test",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 2))
            ]
        )
        let s2 = FlutterAttributedString(
            "test",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 2))
            ]
        )
        XCTAssertTrue(s1 == s2)
    }

    /// Test inequality with different attribute counts.
    func testInequalityDifferentAttributeCounts() {
        let s1 = FlutterAttributedString(
            "test",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 2))
            ]
        )
        let s2 = FlutterAttributedString("test")
        XCTAssertTrue(s1 != s2)
    }

    /// Test inequality with different attribute ranges.
    func testInequalityDifferentAttributeRanges() {
        let s1 = FlutterAttributedString(
            "test",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 2))
            ]
        )
        let s2 = FlutterAttributedString(
            "test",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 1, end: 3))
            ]
        )
        XCTAssertTrue(s1 != s2)
    }

    /// Test inequality with different attribute types.
    func testInequalityDifferentAttributeTypes() {
        let s1 = FlutterAttributedString(
            "test",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 2))
            ]
        )
        let s2 = FlutterAttributedString(
            "test",
            attributes: [
                LocaleStringAttribute(
                    range: TextRange(start: 0, end: 2),
                    locale: FlutterLocale("en")
                )
            ]
        )
        XCTAssertTrue(s1 != s2)
    }

    // MARK: - Description Tests

    /// Test description output.
    func testDescription() {
        let attrStr = FlutterAttributedString("hello")
        XCTAssertEqual(attrStr.description, "AttributedString('hello', attributes: [])")
    }

    /// Test description output with attributes.
    func testDescriptionWithAttributes() {
        let attrStr = FlutterAttributedString(
            "hello",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 3))
            ]
        )
        let desc = attrStr.description
        XCTAssertTrue(desc.hasPrefix("AttributedString('hello', attributes: "))
        XCTAssertTrue(desc.contains("SpellOutStringAttribute"))
    }

    // MARK: - SemanticsLabelBuilder Tests

    /// Test basic functionality with default separator.
    ///
    /// **Dart Test:** `semantics_test.dart:1055-1069`
    func testLabelBuilderBasicFunctionality() {
        let builder = SemanticsLabelBuilder()
        XCTAssertTrue(builder.isEmpty)
        XCTAssertEqual(builder.length, 0)

        builder.addPart("Hello")
        XCTAssertFalse(builder.isEmpty)
        XCTAssertEqual(builder.length, 1)

        builder.addPart("world")
        XCTAssertEqual(builder.length, 2)

        let label = builder.build()
        XCTAssertEqual(label, "Hello world")
    }

    /// Test custom separator.
    ///
    /// **Dart Test:** `semantics_test.dart:1071-1080`
    func testLabelBuilderCustomSeparator() {
        let builder = SemanticsLabelBuilder(separator: ", ")
        builder.addPart("One")
        builder.addPart("Two")
        builder.addPart("Three")

        let label = builder.build()
        XCTAssertEqual(label, "One, Two, Three")
    }

    /// Test empty separator.
    ///
    /// **Dart Test:** `semantics_test.dart:1082-1090`
    func testLabelBuilderEmptySeparator() {
        let builder = SemanticsLabelBuilder(separator: "")
        builder.addPart("Hello")
        builder.addPart("World")

        let label = builder.build()
        XCTAssertEqual(label, "HelloWorld")
    }

    /// Test that empty parts are ignored.
    ///
    /// **Dart Test:** `semantics_test.dart:1092-1102`
    func testLabelBuilderIgnoresEmptyParts() {
        let builder = SemanticsLabelBuilder()
        builder.addPart("Hello")
        builder.addPart("")
        builder.addPart("world")

        let label = builder.build()
        XCTAssertEqual(label, "Hello world")
        XCTAssertEqual(builder.length, 2)
    }

    /// Test single part.
    ///
    /// **Dart Test:** `semantics_test.dart:1104-1110`
    func testLabelBuilderSinglePart() {
        let builder = SemanticsLabelBuilder()
        builder.addPart("Single")

        let label = builder.build()
        XCTAssertEqual(label, "Single")
    }

    /// Test empty builder.
    ///
    /// **Dart Test:** `semantics_test.dart:1112-1116`
    func testLabelBuilderEmpty() {
        let builder = SemanticsLabelBuilder()
        let label = builder.build()
        XCTAssertEqual(label, "")
    }

    /// Test clear functionality.
    ///
    /// **Dart Test:** `semantics_test.dart:1118-1132`
    func testLabelBuilderClear() {
        let builder = SemanticsLabelBuilder()
        builder.addPart("Hello")
        builder.addPart("world")

        XCTAssertEqual(builder.length, 2)

        builder.clear()
        XCTAssertTrue(builder.isEmpty)
        XCTAssertEqual(builder.length, 0)

        let label = builder.build()
        XCTAssertEqual(label, "")
    }

    /// Test reusable builder (clear and reuse).
    ///
    /// **Dart Test:** `semantics_test.dart:1134-1149`
    func testLabelBuilderReusable() {
        let builder = SemanticsLabelBuilder()

        // First use
        builder.addPart("First")
        builder.addPart("use")
        XCTAssertEqual(builder.build(), "First use")

        // Clear and reuse
        builder.clear()
        builder.addPart("Second")
        builder.addPart("use")
        XCTAssertEqual(builder.build(), "Second use")
    }

    /// Test reuse without clearing - parts accumulate.
    ///
    /// **Dart Test:** `semantics_test.dart:1151-1172`
    func testLabelBuilderReuseWithoutClearing() {
        let builder = SemanticsLabelBuilder()

        // First use
        builder.addPart("First")
        builder.addPart("batch")
        XCTAssertEqual(builder.build(), "First batch")
        XCTAssertEqual(builder.length, 2)

        // Add more parts without clearing - should accumulate
        builder.addPart("Second")
        builder.addPart("batch")
        XCTAssertEqual(builder.build(), "First batch Second batch")
        XCTAssertEqual(builder.length, 4)

        // Add even more parts
        builder.addPart("Final")
        XCTAssertEqual(builder.build(), "First batch Second batch Final")
        XCTAssertEqual(builder.length, 5)
    }

    // MARK: - SemanticsLabelBuilder Text Direction Tests

    /// Test no text direction embedding when overall direction is nil.
    ///
    /// **Dart Test:** `semantics_test.dart:1176-1184`
    func testLabelBuilderNoEmbeddingWhenNullDirection() {
        let builder = SemanticsLabelBuilder()
        builder.addPart("Hello", textDirection: .ltr)
        builder.addPart("\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}", textDirection: .rtl)

        let label = builder.build()
        XCTAssertEqual(label, "Hello \u{0645}\u{0631}\u{062D}\u{0628}\u{0627}")
    }

    /// Test text direction embedding with LTR overall direction.
    ///
    /// **Dart Test:** `semantics_test.dart:1186-1195`
    func testLabelBuilderLTROverallDirection() {
        let builder = SemanticsLabelBuilder(textDirection: .ltr)
        builder.addPart("Hello", textDirection: .ltr)
        builder.addPart("\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}", textDirection: .rtl)
        builder.addPart("world", textDirection: .ltr)

        let label = builder.build()
        XCTAssertEqual(label, "Hello \u{202B}\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}\u{202C} world")
    }

    /// Test text direction embedding with RTL overall direction.
    ///
    /// **Dart Test:** `semantics_test.dart:1197-1205`
    func testLabelBuilderRTLOverallDirection() {
        let builder = SemanticsLabelBuilder(textDirection: .rtl)
        builder.addPart("\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}", textDirection: .rtl)
        builder.addPart("Hello", textDirection: .ltr)

        let label = builder.build()
        XCTAssertEqual(label, "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{202A}Hello\u{202C}")
    }

    /// Test no embedding when all parts have same direction as overall.
    ///
    /// **Dart Test:** `semantics_test.dart:1207-1215`
    func testLabelBuilderNoEmbeddingSameDirection() {
        let builder = SemanticsLabelBuilder(textDirection: .ltr)
        builder.addPart("Hello", textDirection: .ltr)
        builder.addPart("world", textDirection: .ltr)

        let label = builder.build()
        XCTAssertEqual(label, "Hello world")
    }

    /// Test that part direction falls back to overall direction.
    ///
    /// **Dart Test:** `semantics_test.dart:1217-1225`
    func testLabelBuilderPartFallbackToOverallDirection() {
        let builder = SemanticsLabelBuilder(textDirection: .ltr)
        builder.addPart("Hello")
        builder.addPart("world")

        let label = builder.build()
        XCTAssertEqual(label, "Hello world")
    }

    /// Test complex multilingual example.
    ///
    /// **Dart Test:** `semantics_test.dart:1227-1239`
    func testLabelBuilderComplexMultilingual() {
        let builder = SemanticsLabelBuilder(
            separator: ", ",
            textDirection: .ltr
        )
        builder.addPart("Welcome", textDirection: .ltr)
        builder.addPart("\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}", textDirection: .rtl)
        builder.addPart("\u{05E9}\u{05DC}\u{05D5}\u{05DD}", textDirection: .rtl)
        builder.addPart("to our app", textDirection: .ltr)

        let result = builder.build()
        XCTAssertEqual(
            result,
            "Welcome, \u{202B}\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}\u{202C}, \u{202B}\u{05E9}\u{05DC}\u{05D5}\u{05DD}\u{202C}, to our app"
        )
    }

    /// Test special characters in separator.
    ///
    /// **Dart Test:** `semantics_test.dart:1270-1279`
    func testLabelBuilderSpecialCharSeparator() {
        let builder = SemanticsLabelBuilder(separator: " | ")
        builder.addPart("first")
        builder.addPart("second")
        builder.addPart("third")

        let label = builder.build()
        XCTAssertEqual(label, "first | second | third")
    }

    /// Test many parts.
    ///
    /// **Dart Test:** `semantics_test.dart:1257-1268`
    func testLabelBuilderManyParts() {
        let builder = SemanticsLabelBuilder()

        for i in 0..<100 {
            builder.addPart("part\(i)")
        }

        let label = builder.build()
        XCTAssertTrue(label.hasPrefix("part0 part1"))
        XCTAssertTrue(label.hasSuffix("part98 part99"))
        XCTAssertEqual(builder.length, 100)
    }
}

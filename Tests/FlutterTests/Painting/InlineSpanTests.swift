// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest

@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// A minimal concrete subclass of InlineSpan for testing purposes.
///
/// Since InlineSpan is abstract (open class with fatalError in abstract methods),
/// we need a concrete implementation to test the base class behavior.
private final class TestInlineSpan: InlineSpan {
    let text: String
    let children: [TestInlineSpan]
    let semanticsLabel: String?

    init(
        text: String = "",
        style: Flutter.TextStyle? = nil,
        children: [TestInlineSpan] = [],
        semanticsLabel: String? = nil
    ) {
        self.text = text
        self.children = children
        self.semanticsLabel = semanticsLabel
        super.init(style: style)
    }

    override func build(
        _ builder: any FlutterSwiftBridge.ParagraphBuilder,
        textScaler: any TextScaler = TextScalers.noScaling,
        dimensions: [PlaceholderDimensions]? = nil
    ) {
        // No-op for testing
    }

    override func visitChildren(_ visitor: InlineSpanVisitor) -> Bool {
        // Visit self first if we have text
        if !text.isEmpty {
            if !visitor(self) {
                return false
            }
        }
        // Then visit children
        for child in children {
            if !child.visitChildren(visitor) {
                return false
            }
        }
        return true
    }

    override func visitDirectChildren(_ visitor: InlineSpanVisitor) -> Bool {
        for child in children {
            if !visitor(child) {
                return false
            }
        }
        return true
    }

    override func getSpanForPositionVisitor(
        _ position: TextPosition,
        _ offset: Accumulator
    ) -> InlineSpan? {
        let endOffset = offset.value + text.utf16.count
        if position.offset >= offset.value && position.offset < endOffset {
            return self
        }
        offset.increment(text.utf16.count)
        return nil
    }

    override func computeSemanticsInformation(
        _ collector: inout [InlineSpanSemanticsInformation]
    ) {
        collector.append(
            InlineSpanSemanticsInformation(
                text,
                semanticsLabel: semanticsLabel
            )
        )
        for child in children {
            child.computeSemanticsInformation(&collector)
        }
    }

    override func computeToPlainText(
        _ buffer: inout String,
        includeSemanticsLabels: Bool = true,
        includePlaceholders: Bool = true
    ) {
        if includeSemanticsLabels, let label = semanticsLabel {
            buffer += label
        } else {
            buffer += text
        }
        for child in children {
            child.computeToPlainText(
                &buffer,
                includeSemanticsLabels: includeSemanticsLabels,
                includePlaceholders: includePlaceholders
            )
        }
    }

    override func codeUnitAtVisitor(_ index: Int, _ offset: Accumulator) -> Int? {
        let localIndex = index - offset.value
        let utf16 = Array(text.utf16)
        if localIndex >= 0 && localIndex < utf16.count {
            return Int(utf16[localIndex])
        }
        offset.increment(utf16.count)
        return nil
    }

    override func compareTo(_ other: InlineSpan) -> RenderComparison {
        if self === other {
            return .identical
        }
        guard let otherTest = other as? TestInlineSpan else {
            return .layout
        }
        if text != otherTest.text {
            return .layout
        }
        if style != otherTest.style {
            return .layout
        }
        return .identical
    }
}

/// A stub GestureRecognizer for testing.
private final class TestGestureRecognizer: GestureRecognizer {}

// MARK: - Accumulator Tests

final class AccumulatorTests: XCTestCase {

    func testDefaultInitialValue() {
        let accumulator = Accumulator()
        XCTAssertEqual(accumulator.value, 0)
    }

    func testCustomInitialValue() {
        let accumulator = Accumulator(42)
        XCTAssertEqual(accumulator.value, 42)
    }

    func testIncrement() {
        let accumulator = Accumulator()
        accumulator.increment(5)
        XCTAssertEqual(accumulator.value, 5)
    }

    func testMultipleIncrements() {
        let accumulator = Accumulator(10)
        accumulator.increment(3)
        accumulator.increment(7)
        accumulator.increment(0)
        XCTAssertEqual(accumulator.value, 20)
    }

    func testReferenceSemantics() {
        // Accumulator must be a reference type so that mutations are visible
        // across recursive call stacks.
        let a = Accumulator()
        let b = a
        a.increment(10)
        XCTAssertEqual(b.value, 10, "Accumulator should have reference semantics")
    }

    func testIncrementByZero() {
        let accumulator = Accumulator(5)
        accumulator.increment(0)
        XCTAssertEqual(accumulator.value, 5)
    }
}

// MARK: - InlineSpanSemanticsInformation Tests

final class InlineSpanSemanticsInformationTests: XCTestCase {

    func testDefaultConstruction() {
        let info = InlineSpanSemanticsInformation("hello")
        XCTAssertEqual(info.text, "hello")
        XCTAssertNil(info.semanticsLabel)
        XCTAssertNil(info.semanticsIdentifier)
        XCTAssertNil(info.recognizer)
        XCTAssertFalse(info.isPlaceholder)
        XCTAssertFalse(info.requiresOwnNode)
        XCTAssertTrue(info.stringAttributes.isEmpty)
    }

    func testPlaceholder() {
        let info = InlineSpanSemanticsInformation.placeholder
        XCTAssertEqual(info.text, "\u{FFFC}")
        XCTAssertTrue(info.isPlaceholder)
        XCTAssertTrue(info.requiresOwnNode)
        XCTAssertNil(info.semanticsLabel)
        XCTAssertNil(info.recognizer)
    }

    func testWithSemanticsLabel() {
        let info = InlineSpanSemanticsInformation(
            "test",
            semanticsLabel: "label"
        )
        XCTAssertEqual(info.text, "test")
        XCTAssertEqual(info.semanticsLabel, "label")
        XCTAssertFalse(info.requiresOwnNode)
    }

    func testWithSemanticsIdentifier() {
        let info = InlineSpanSemanticsInformation(
            "test",
            semanticsIdentifier: "id"
        )
        XCTAssertEqual(info.semanticsIdentifier, "id")
        XCTAssertTrue(info.requiresOwnNode, "semanticsIdentifier should require own node")
    }

    func testRequiresOwnNodeWithRecognizer() {
        let recognizer = TestGestureRecognizer()
        let info = InlineSpanSemanticsInformation(
            "test",
            recognizer: recognizer
        )
        XCTAssertTrue(info.requiresOwnNode, "recognizer should require own node")
    }

    func testRequiresOwnNodeWithPlaceholder() {
        XCTAssertTrue(
            InlineSpanSemanticsInformation.placeholder.requiresOwnNode,
            "placeholder should require own node"
        )
    }

    func testEquality() {
        let a = InlineSpanSemanticsInformation("hello", semanticsLabel: "world")
        let b = InlineSpanSemanticsInformation("hello", semanticsLabel: "world")
        XCTAssertEqual(a, b)
    }

    func testInequalityDifferentText() {
        let a = InlineSpanSemanticsInformation("hello")
        let b = InlineSpanSemanticsInformation("world")
        XCTAssertNotEqual(a, b)
    }

    func testInequalityDifferentLabel() {
        let a = InlineSpanSemanticsInformation("hello", semanticsLabel: "a")
        let b = InlineSpanSemanticsInformation("hello", semanticsLabel: "b")
        XCTAssertNotEqual(a, b)
    }

    func testInequalityDifferentIdentifier() {
        let a = InlineSpanSemanticsInformation("hello", semanticsIdentifier: "a")
        let b = InlineSpanSemanticsInformation("hello", semanticsIdentifier: "b")
        XCTAssertNotEqual(a, b)
    }

    func testEqualityWithSameRecognizer() {
        let recognizer = TestGestureRecognizer()
        let a = InlineSpanSemanticsInformation("test", recognizer: recognizer)
        let b = InlineSpanSemanticsInformation("test", recognizer: recognizer)
        XCTAssertEqual(a, b)
    }

    func testInequalityWithDifferentRecognizers() {
        let recognizer1 = TestGestureRecognizer()
        let recognizer2 = TestGestureRecognizer()
        let a = InlineSpanSemanticsInformation("test", recognizer: recognizer1)
        let b = InlineSpanSemanticsInformation("test", recognizer: recognizer2)
        XCTAssertNotEqual(a, b)
    }

    func testPlaceholderEquality() {
        let a = InlineSpanSemanticsInformation.placeholder
        let b = InlineSpanSemanticsInformation("\u{FFFC}", isPlaceholder: true)
        XCTAssertEqual(a, b)
    }

    func testDescription() {
        let info = InlineSpanSemanticsInformation("hello", semanticsLabel: "world")
        let desc = info.description
        XCTAssertTrue(desc.contains("hello"))
        XCTAssertTrue(desc.contains("world"))
        XCTAssertTrue(desc.contains("InlineSpanSemanticsInformation"))
    }

    func testHashValueConsistency() {
        let a = InlineSpanSemanticsInformation("hello", semanticsLabel: "world")
        let b = InlineSpanSemanticsInformation("hello", semanticsLabel: "world")
        // Equal objects should have equal hash values
        XCTAssertEqual(a.hashValue, b.hashValue)
    }
}

// MARK: - combineSemanticsInfo Tests

final class CombineSemanticsInfoTests: XCTestCase {

    func testEmptyList() {
        let result = combineSemanticsInfo([])
        // Should return a single entry with empty text
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "")
    }

    func testSingleNonPlaceholderEntry() {
        let info = InlineSpanSemanticsInformation("hello")
        let result = combineSemanticsInfo([info])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "hello")
        XCTAssertEqual(result[0].semanticsLabel, "hello")
    }

    func testCombineAdjacentNonPlaceholders() {
        let a = InlineSpanSemanticsInformation("hello ")
        let b = InlineSpanSemanticsInformation("world")
        let result = combineSemanticsInfo([a, b])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "hello world")
        XCTAssertEqual(result[0].semanticsLabel, "hello world")
    }

    func testPreservePlaceholder() {
        let a = InlineSpanSemanticsInformation("hello ")
        let placeholder = InlineSpanSemanticsInformation.placeholder
        let b = InlineSpanSemanticsInformation("world")
        let result = combineSemanticsInfo([a, placeholder, b])
        // Before placeholder (accumulated), placeholder, after placeholder (trailing)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].text, "hello ")
        XCTAssertTrue(result[1].isPlaceholder)
        XCTAssertEqual(result[2].text, "world")
    }

    func testPreserveRecognizerNode() {
        let recognizer = TestGestureRecognizer()
        let a = InlineSpanSemanticsInformation("before ")
        let b = InlineSpanSemanticsInformation("link", recognizer: recognizer)
        let c = InlineSpanSemanticsInformation(" after")
        let result = combineSemanticsInfo([a, b, c])
        // Before recognizer (accumulated), recognizer node, after recognizer (trailing)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].text, "before ")
        XCTAssertEqual(result[1].text, "link")
        XCTAssertTrue(result[1].requiresOwnNode)
        XCTAssertEqual(result[2].text, " after")
    }

    func testSemanticsLabelUsedWhenPresent() {
        let a = InlineSpanSemanticsInformation("$100", semanticsLabel: "one hundred dollars")
        let b = InlineSpanSemanticsInformation(" remaining")
        let result = combineSemanticsInfo([a, b])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "$100 remaining")
        XCTAssertEqual(result[0].semanticsLabel, "one hundred dollars remaining")
    }

    func testMultiplePlaceholders() {
        let placeholder = InlineSpanSemanticsInformation.placeholder
        let result = combineSemanticsInfo([placeholder, placeholder])
        // Before first placeholder: empty, first placeholder, between: empty,
        // second placeholder, trailing: empty
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[0].text, "")
        XCTAssertTrue(result[1].isPlaceholder)
        XCTAssertEqual(result[2].text, "")
        XCTAssertTrue(result[3].isPlaceholder)
        XCTAssertEqual(result[4].text, "")
    }
}

// MARK: - InlineSpan Tests

final class InlineSpanTests: XCTestCase {

    func testStyleProperty() {
        let style = Flutter.TextStyle(fontSize: 16.0)
        let span = TestInlineSpan(text: "hello", style: style)
        XCTAssertEqual(span.style, style)
    }

    func testStylePropertyNil() {
        let span = TestInlineSpan(text: "hello")
        XCTAssertNil(span.style)
    }

    func testToPlainText() {
        let span = TestInlineSpan(
            text: "hello ",
            children: [TestInlineSpan(text: "world")]
        )
        XCTAssertEqual(span.toPlainText(), "hello world")
    }

    func testToPlainTextWithSemanticsLabel() {
        let span = TestInlineSpan(
            text: "$100",
            semanticsLabel: "one hundred dollars"
        )
        XCTAssertEqual(
            span.toPlainText(includeSemanticsLabels: true),
            "one hundred dollars"
        )
        XCTAssertEqual(
            span.toPlainText(includeSemanticsLabels: false),
            "$100"
        )
    }

    func testGetSemanticsInformation() {
        let span = TestInlineSpan(
            text: "hello",
            children: [TestInlineSpan(text: " world")]
        )
        let info = span.getSemanticsInformation()
        XCTAssertEqual(info.count, 2)
        XCTAssertEqual(info[0].text, "hello")
        XCTAssertEqual(info[1].text, " world")
    }

    func testGetSpanForPosition() {
        let child1 = TestInlineSpan(text: "hello")
        let child2 = TestInlineSpan(text: " world")
        let span = TestInlineSpan(text: "", children: [child1, child2])

        // Position 0 should be in "hello"
        let result0 = span.getSpanForPosition(TextPosition(offset: 0))
        XCTAssertTrue(result0 === child1)

        // Position 4 should still be in "hello"
        let result4 = span.getSpanForPosition(TextPosition(offset: 4))
        XCTAssertTrue(result4 === child1)

        // Position 5 should be in " world"
        let result5 = span.getSpanForPosition(TextPosition(offset: 5))
        XCTAssertTrue(result5 === child2)
    }

    func testCodeUnitAt() {
        let span = TestInlineSpan(
            text: "",
            children: [
                TestInlineSpan(text: "AB"),
                TestInlineSpan(text: "CD"),
            ]
        )
        // 'A' = 65, 'B' = 66, 'C' = 67, 'D' = 68
        XCTAssertEqual(span.codeUnitAt(0), 65)  // A
        XCTAssertEqual(span.codeUnitAt(1), 66)  // B
        XCTAssertEqual(span.codeUnitAt(2), 67)  // C
        XCTAssertEqual(span.codeUnitAt(3), 68)  // D
        XCTAssertNil(span.codeUnitAt(4))         // Out of bounds
        XCTAssertNil(span.codeUnitAt(-1))        // Negative index
    }

    func testEqualityIdentical() {
        let span = TestInlineSpan(text: "hello")
        XCTAssertTrue(span == span)
    }

    func testEqualitySameStyle() {
        let style = Flutter.TextStyle(fontSize: 16.0)
        let a = TestInlineSpan(text: "hello", style: style)
        let b = TestInlineSpan(text: "world", style: style)
        // Base InlineSpan == only checks style, not text
        let lhs: InlineSpan = a
        let rhs: InlineSpan = b
        XCTAssertTrue(lhs == rhs)
    }

    func testInequalityDifferentStyle() {
        let a: InlineSpan = TestInlineSpan(text: "hello", style: Flutter.TextStyle(fontSize: 16.0))
        let b: InlineSpan = TestInlineSpan(text: "hello", style: Flutter.TextStyle(fontSize: 20.0))
        XCTAssertFalse(a == b)
    }

    func testCompareTo() {
        let a = TestInlineSpan(text: "hello")
        let b = TestInlineSpan(text: "hello")
        XCTAssertEqual(a.compareTo(b), .identical)

        let c = TestInlineSpan(text: "world")
        XCTAssertEqual(a.compareTo(c), .layout)
    }

    func testDebugAssertIsValid() {
        let span = TestInlineSpan(text: "hello")
        XCTAssertTrue(span.debugAssertIsValid())
    }

    func testHashValueConsistency() {
        let style = Flutter.TextStyle(fontSize: 16.0)
        let a = TestInlineSpan(text: "hello", style: style)
        let b = TestInlineSpan(text: "world", style: style)
        // Same style should produce same hash for the base InlineSpan hash
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testToStringShort() {
        let span = TestInlineSpan(text: "hello")
        let str = span.toStringShort()
        XCTAssertTrue(str.contains("InlineSpan") || str.contains("TestInlineSpan"))
    }

    func testVisitDirectChildren() {
        let child1 = TestInlineSpan(text: "a")
        let child2 = TestInlineSpan(text: "b")
        let span = TestInlineSpan(text: "root", children: [child1, child2])

        var visited: [String] = []
        _ = span.visitDirectChildren { child in
            if let testChild = child as? TestInlineSpan {
                visited.append(testChild.text)
            }
            return true
        }
        XCTAssertEqual(visited, ["a", "b"])
    }

    func testVisitDirectChildrenStopsEarly() {
        let child1 = TestInlineSpan(text: "a")
        let child2 = TestInlineSpan(text: "b")
        let span = TestInlineSpan(text: "root", children: [child1, child2])

        var visited: [String] = []
        let result = span.visitDirectChildren { child in
            if let testChild = child as? TestInlineSpan {
                visited.append(testChild.text)
            }
            return false  // Stop after first child
        }
        XCTAssertEqual(visited, ["a"])
        XCTAssertFalse(result)
    }
}

// MARK: - PlaceholderDimensions Tests

final class PlaceholderDimensionsTests: XCTestCase {

    func testEmptyPlaceholder() {
        let empty = PlaceholderDimensions.empty
        XCTAssertEqual(empty.size, Size.zero)
        XCTAssertEqual(empty.alignment, .bottom)
        XCTAssertNil(empty.baseline)
        XCTAssertNil(empty.baselineOffset)
    }

    func testCustomPlaceholder() {
        let dims = PlaceholderDimensions(
            size: Size(100, 50),
            alignment: .baseline,
            baseline: .alphabetic,
            baselineOffset: 25.0
        )
        XCTAssertEqual(dims.size.width, 100)
        XCTAssertEqual(dims.size.height, 50)
        XCTAssertEqual(dims.alignment, .baseline)
        XCTAssertEqual(dims.baseline, .alphabetic)
        XCTAssertEqual(dims.baselineOffset, 25.0)
    }

    func testEquality() {
        let a = PlaceholderDimensions(
            size: Size(100, 50),
            alignment: .bottom
        )
        let b = PlaceholderDimensions(
            size: Size(100, 50),
            alignment: .bottom
        )
        XCTAssertEqual(a, b)
    }

    func testInequality() {
        let a = PlaceholderDimensions(
            size: Size(100, 50),
            alignment: .bottom
        )
        let b = PlaceholderDimensions(
            size: Size(200, 50),
            alignment: .bottom
        )
        XCTAssertNotEqual(a, b)
    }
}

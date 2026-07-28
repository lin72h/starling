// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest

@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// A minimal concrete subclass of PlaceholderSpan for testing purposes.
///
/// Since PlaceholderSpan is an open class with abstract methods inherited from
/// InlineSpan, we need a concrete implementation to test the base class behavior.
private final class TestPlaceholderSpan: PlaceholderSpan {

    override func build(
        _ builder: any FlutterSwiftBridge.ParagraphBuilder,
        textScaler: any TextScaler = TextScalers.noScaling,
        dimensions: [PlaceholderDimensions]? = nil
    ) {
        // No-op for testing
    }

    override func visitChildren(_ visitor: InlineSpanVisitor) -> Bool {
        return visitor(self)
    }

    override func visitDirectChildren(_ visitor: InlineSpanVisitor) -> Bool {
        return true
    }

    override func getSpanForPositionVisitor(
        _ position: TextPosition,
        _ offset: Accumulator
    ) -> InlineSpan? {
        return nil
    }

    override func codeUnitAtVisitor(_ index: Int, _ offset: Accumulator) -> Int? {
        return nil
    }

    override func compareTo(_ other: InlineSpan) -> RenderComparison {
        if self === other {
            return .identical
        }
        guard let otherPlaceholder = other as? TestPlaceholderSpan else {
            return .layout
        }
        if alignment != otherPlaceholder.alignment || baseline != otherPlaceholder.baseline {
            return .layout
        }
        if style != otherPlaceholder.style {
            return .layout
        }
        return .identical
    }
}

// MARK: - PlaceholderSpan Tests

final class PlaceholderSpanTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let span = TestPlaceholderSpan()
        XCTAssertEqual(span.alignment, .bottom, "Default alignment should be .bottom")
        XCTAssertNil(span.baseline, "Default baseline should be nil")
        XCTAssertNil(span.style, "Default style should be nil")
    }

    func testCustomAlignment() {
        let span = TestPlaceholderSpan(alignment: .top)
        XCTAssertEqual(span.alignment, .top)
    }

    func testBaselineAlignment() {
        let span = TestPlaceholderSpan(
            alignment: .baseline,
            baseline: .alphabetic
        )
        XCTAssertEqual(span.alignment, .baseline)
        XCTAssertEqual(span.baseline, .alphabetic)
    }

    func testAboveBaselineAlignment() {
        let span = TestPlaceholderSpan(
            alignment: .aboveBaseline,
            baseline: .ideographic
        )
        XCTAssertEqual(span.alignment, .aboveBaseline)
        XCTAssertEqual(span.baseline, .ideographic)
    }

    func testBelowBaselineAlignment() {
        let span = TestPlaceholderSpan(
            alignment: .belowBaseline,
            baseline: .alphabetic
        )
        XCTAssertEqual(span.alignment, .belowBaseline)
        XCTAssertEqual(span.baseline, .alphabetic)
    }

    func testMiddleAlignment() {
        let span = TestPlaceholderSpan(alignment: .middle)
        XCTAssertEqual(span.alignment, .middle)
    }

    func testWithStyle() {
        let style = Flutter.TextStyle(fontSize: 14.0)
        let span = TestPlaceholderSpan(
            alignment: .bottom,
            baseline: nil,
            style: style
        )
        XCTAssertEqual(span.style, style)
    }

    func testAllAlignmentValues() {
        // Verify all PlaceholderAlignment cases can be used
        let alignments: [PlaceholderAlignment] = [
            .baseline, .aboveBaseline, .belowBaseline,
            .top, .bottom, .middle,
        ]
        for alignment in alignments {
            let span = TestPlaceholderSpan(alignment: alignment)
            XCTAssertEqual(span.alignment, alignment)
        }
    }

    // MARK: - Static Constant Tests

    func testPlaceholderCodeUnit() {
        XCTAssertEqual(
            PlaceholderSpan.placeholderCodeUnit,
            0xFFFC,
            "placeholderCodeUnit should be 0xFFFC"
        )
    }

    // MARK: - computeToPlainText Tests

    func testComputeToPlainTextWithPlaceholders() {
        let span = TestPlaceholderSpan()
        var buffer = ""
        span.computeToPlainText(
            &buffer,
            includeSemanticsLabels: true,
            includePlaceholders: true
        )
        XCTAssertEqual(buffer, "\u{FFFC}")
    }

    func testComputeToPlainTextWithoutPlaceholders() {
        let span = TestPlaceholderSpan()
        var buffer = ""
        span.computeToPlainText(
            &buffer,
            includeSemanticsLabels: true,
            includePlaceholders: false
        )
        XCTAssertEqual(buffer, "", "Should produce empty string when includePlaceholders is false")
    }

    func testComputeToPlainTextAppendsToExistingBuffer() {
        let span = TestPlaceholderSpan()
        var buffer = "prefix"
        span.computeToPlainText(
            &buffer,
            includeSemanticsLabels: true,
            includePlaceholders: true
        )
        XCTAssertEqual(buffer, "prefix\u{FFFC}")
    }

    func testComputeToPlainTextDefaultParameters() {
        let span = TestPlaceholderSpan()
        var buffer = ""
        span.computeToPlainText(&buffer)
        XCTAssertEqual(
            buffer, "\u{FFFC}",
            "Default parameters should include placeholders"
        )
    }

    // MARK: - computeSemanticsInformation Tests

    func testComputeSemanticsInformation() {
        let span = TestPlaceholderSpan()
        var collector: [InlineSpanSemanticsInformation] = []
        span.computeSemanticsInformation(&collector)
        XCTAssertEqual(collector.count, 1)
        XCTAssertEqual(collector[0], InlineSpanSemanticsInformation.placeholder)
        XCTAssertTrue(collector[0].isPlaceholder)
    }

    func testComputeSemanticsInformationAppendsToExistingCollector() {
        let span = TestPlaceholderSpan()
        var collector: [InlineSpanSemanticsInformation] = [
            InlineSpanSemanticsInformation("existing text"),
        ]
        span.computeSemanticsInformation(&collector)
        XCTAssertEqual(collector.count, 2)
        XCTAssertEqual(collector[0].text, "existing text")
        XCTAssertTrue(collector[1].isPlaceholder)
    }

    // MARK: - toPlainText Tests (inherited from InlineSpan)

    func testToPlainText() {
        let span = TestPlaceholderSpan()
        let text = span.toPlainText(includePlaceholders: true)
        XCTAssertEqual(text, "\u{FFFC}")
    }

    func testToPlainTextWithoutPlaceholders() {
        let span = TestPlaceholderSpan()
        let text = span.toPlainText(includePlaceholders: false)
        XCTAssertEqual(text, "")
    }

    // MARK: - getSemanticsInformation Tests (inherited from InlineSpan)

    func testGetSemanticsInformation() {
        let span = TestPlaceholderSpan()
        let info = span.getSemanticsInformation()
        XCTAssertEqual(info.count, 1)
        XCTAssertTrue(info[0].isPlaceholder)
        XCTAssertEqual(info[0].text, "\u{FFFC}")
    }

    // MARK: - Subclassing Tests

    func testInheritsFromInlineSpan() {
        let span = TestPlaceholderSpan()
        XCTAssertTrue(span is InlineSpan, "PlaceholderSpan should inherit from InlineSpan")
    }

    func testStyleInheritance() {
        let style = Flutter.TextStyle(fontSize: 20.0, fontWeight: .bold)
        let span = TestPlaceholderSpan(style: style)
        // style is inherited from InlineSpan
        XCTAssertEqual(span.style?.fontSize, 20.0)
        XCTAssertEqual(span.style?.fontWeight, .bold)
    }
}

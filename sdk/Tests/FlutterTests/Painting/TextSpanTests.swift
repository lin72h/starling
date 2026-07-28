// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest

@testable import Flutter
@testable import FlutterSwiftBridge

// MARK: - Test Helpers

/// A stub GestureRecognizer for testing.
private final class TestGestureRecognizer: GestureRecognizer {}

// MARK: - TextSpan Construction Tests

final class TextSpanConstructionTests: XCTestCase {

    func testBasicTextSpan() {
        let span = TextSpan(text: "hello")
        XCTAssertEqual(span.text, "hello")
        XCTAssertNil(span.children)
        XCTAssertNil(span.style)
        XCTAssertNil(span.recognizer)
        XCTAssertNil(span.semanticsLabel)
        XCTAssertNil(span.semanticsIdentifier)
        XCTAssertNil(span.locale)
        XCTAssertNil(span.spellOut)
    }

    func testEmptyTextSpan() {
        let span = TextSpan()
        XCTAssertNil(span.text)
        XCTAssertNil(span.children)
        XCTAssertNil(span.style)
    }

    func testTextSpanWithStyle() {
        let style = Flutter.TextStyle(fontSize: 10.0)
        let span = TextSpan(text: "styled", style: style)
        XCTAssertEqual(span.style, style)
    }

    func testTextSpanWithChildren() {
        let child1 = TextSpan(text: "a")
        let child2 = TextSpan(text: "b")
        let span = TextSpan(children: [child1, child2])
        XCTAssertNil(span.text)
        XCTAssertEqual(span.children?.count, 2)
    }

    func testTextSpanWithTextAndChildren() {
        let child = TextSpan(text: "child")
        let span = TextSpan(text: "parent", children: [child])
        XCTAssertEqual(span.text, "parent")
        XCTAssertEqual(span.children?.count, 1)
    }

    func testTextSpanWithRecognizer() {
        let recognizer = TestGestureRecognizer()
        let span = TextSpan(text: "tap me", recognizer: recognizer)
        XCTAssertTrue(span.recognizer === recognizer)
    }

    func testTextSpanWithSemanticsLabel() {
        let span = TextSpan(text: "$$", semanticsLabel: "Double dollars")
        XCTAssertEqual(span.semanticsLabel, "Double dollars")
    }

    func testTextSpanWithSemanticsIdentifier() {
        let span = TextSpan(text: "test", semanticsIdentifier: "my_id")
        XCTAssertEqual(span.semanticsIdentifier, "my_id")
    }

    func testTextSpanWithLocale() {
        let locale = Locale("es", "MX")
        let span = TextSpan(text: "hola", locale: locale)
        XCTAssertEqual(span.locale, locale)
    }

    func testTextSpanWithSpellOut() {
        let span = TextSpan(text: "abc", spellOut: true)
        XCTAssertEqual(span.spellOut, true)
    }
}

// MARK: - TextSpan Equality Tests

final class TextSpanEqualityTests: XCTestCase {

    /// **Dart Test Source:** `text_span_test.dart:13-55`
    func testTextSpanEquals() {
        let a1 = TextSpan(text: "a")
        let a2 = TextSpan(text: "a")
        let b1 = TextSpan(children: [TextSpan(text: "a")])
        let b2 = TextSpan(children: [TextSpan(text: "a")])
        let c1 = TextSpan()
        let c2 = TextSpan()

        XCTAssertTrue(a1 == a2)
        XCTAssertTrue(b1 == b2)
        XCTAssertTrue(c1 == c2)

        // Cross-type comparisons
        XCTAssertFalse(a1 == b2)
        XCTAssertFalse(b1 == c2)
        XCTAssertFalse(c1 == a2)

        XCTAssertFalse(a1 == c2)
        XCTAssertFalse(b1 == a2)
        XCTAssertFalse(c1 == b2)
    }

    func testEqualityWithIdenticalRecognizer() {
        let recognizer = TestGestureRecognizer()
        let a = TextSpan(text: "a", recognizer: recognizer)
        let b = TextSpan(text: "a", recognizer: recognizer)
        XCTAssertTrue(a == b)
    }

    func testInequalityWithDifferentRecognizers() {
        let recognizer1 = TestGestureRecognizer()
        let recognizer2 = TestGestureRecognizer()
        let a = TextSpan(text: "a", recognizer: recognizer1)
        let b = TextSpan(text: "a", recognizer: recognizer2)
        XCTAssertFalse(a == b)
    }

    func testEqualityIdentical() {
        let span = TextSpan(text: "hello")
        XCTAssertTrue(span == span)
    }

    func testInequalityDifferentText() {
        let a = TextSpan(text: "hello")
        let b = TextSpan(text: "world")
        XCTAssertFalse(a == b)
    }

    func testInequalityDifferentStyle() {
        let a = TextSpan(text: "a", style: Flutter.TextStyle(fontSize: 10.0))
        let b = TextSpan(text: "a", style: Flutter.TextStyle(fontSize: 20.0))
        XCTAssertFalse(a == b)
    }

    func testInequalityDifferentChildren() {
        let a = TextSpan(text: "a", children: [TextSpan(text: "x")])
        let b = TextSpan(text: "a", children: [TextSpan(text: "y")])
        XCTAssertFalse(a == b)
    }

    func testEqualityBothNilChildren() {
        let a = TextSpan(text: "a")
        let b = TextSpan(text: "a")
        XCTAssertTrue(a == b)
    }

    func testInequalityOneNilChildren() {
        let a = TextSpan(text: "a", children: [TextSpan(text: "x")])
        let b = TextSpan(text: "a")
        XCTAssertFalse(a == b)
    }

    func testInequalityDifferentSemanticsLabel() {
        let a = TextSpan(text: "a", semanticsLabel: "label1")
        let b = TextSpan(text: "a", semanticsLabel: "label2")
        XCTAssertFalse(a == b)
    }

    func testInequalityDifferentSemanticsIdentifier() {
        let a = TextSpan(text: "a", semanticsIdentifier: "id1")
        let b = TextSpan(text: "a", semanticsIdentifier: "id2")
        XCTAssertFalse(a == b)
    }

    func testHashCodeConsistency() {
        let a = TextSpan(text: "hello", style: Flutter.TextStyle(fontSize: 10.0))
        let b = TextSpan(text: "hello", style: Flutter.TextStyle(fontSize: 10.0))
        XCTAssertTrue(a == b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashCodeDiffers() {
        let a = TextSpan(text: "hello")
        let b = TextSpan(text: "world")
        // While hash collisions can occur, different text should usually differ
        XCTAssertNotEqual(a.hashValue, b.hashValue)
    }
}

// MARK: - TextSpan toPlainText Tests

final class TextSpanToPlainTextTests: XCTestCase {

    /// **Dart Test Source:** `text_span_test.dart:110-119`
    func testToPlainText() {
        let textSpan = TextSpan(
            text: "a",
            children: [
                TextSpan(text: "b"),
                TextSpan(text: "c"),
            ]
        )
        XCTAssertEqual(textSpan.toPlainText(), "abc")
    }

    /// **Dart Test Source:** `text_span_test.dart:133-143`
    func testToPlainTextWithSemanticsLabel() {
        let textSpan = TextSpan(
            text: "a",
            children: [
                TextSpan(text: "b", semanticsLabel: "foo"),
                TextSpan(text: "c"),
            ]
        )
        XCTAssertEqual(textSpan.toPlainText(), "afooc")
        XCTAssertEqual(textSpan.toPlainText(includeSemanticsLabels: false), "abc")
    }

    func testToPlainTextEmpty() {
        let textSpan = TextSpan()
        XCTAssertEqual(textSpan.toPlainText(), "")
    }

    func testToPlainTextNestedChildren() {
        let textSpan = TextSpan(
            text: "a",
            children: [
                TextSpan(
                    text: "b",
                    children: [TextSpan(text: "c")]
                ),
                TextSpan(text: "d"),
            ]
        )
        XCTAssertEqual(textSpan.toPlainText(), "abcd")
    }

    func testToPlainTextWithOnlyChildren() {
        let textSpan = TextSpan(
            children: [
                TextSpan(text: "hello"),
                TextSpan(text: " "),
                TextSpan(text: "world"),
            ]
        )
        XCTAssertEqual(textSpan.toPlainText(), "hello world")
    }
}

// MARK: - TextSpan GetSpanForPosition Tests

final class TextSpanGetSpanForPositionTests: XCTestCase {

    /// **Dart Test Source:** `text_span_test.dart:255-272`
    func testGetSpanForPosition() {
        let textSpan = TextSpan(
            text: "",
            children: [
                TextSpan(
                    text: "",
                    children: [TextSpan(text: "a")]
                ),
                TextSpan(text: "b"),
                TextSpan(text: "c"),
            ]
        )

        let span0 = textSpan.getSpanForPosition(TextPosition(offset: 0)) as? TextSpan
        XCTAssertEqual(span0?.text, "a")

        let span1 = textSpan.getSpanForPosition(TextPosition(offset: 1)) as? TextSpan
        XCTAssertEqual(span1?.text, "b")

        let span2 = textSpan.getSpanForPosition(TextPosition(offset: 2)) as? TextSpan
        XCTAssertEqual(span2?.text, "c")

        let span3 = textSpan.getSpanForPosition(TextPosition(offset: 3)) as? TextSpan
        XCTAssertNil(span3?.text)
    }

    func testGetSpanForPositionWithParentText() {
        let textSpan = TextSpan(
            text: "hello",
            children: [
                TextSpan(text: " world"),
            ]
        )

        // Position 0 should be in "hello"
        let span0 = textSpan.getSpanForPosition(TextPosition(offset: 0)) as? TextSpan
        XCTAssertEqual(span0?.text, "hello")

        // Position 4 should still be in "hello"
        let span4 = textSpan.getSpanForPosition(TextPosition(offset: 4)) as? TextSpan
        XCTAssertEqual(span4?.text, "hello")

        // Position 5 should be in " world"
        let span5 = textSpan.getSpanForPosition(TextPosition(offset: 5)) as? TextSpan
        XCTAssertEqual(span5?.text, " world")
    }

    func testGetSpanForPositionAffinity() {
        // Test downstream affinity at boundary (offset == start)
        let textSpan = TextSpan(
            text: "",
            children: [
                TextSpan(text: "ab"),
                TextSpan(text: "cd"),
            ]
        )

        // Position 2 with downstream affinity should be in "cd"
        let spanDown = textSpan.getSpanForPosition(
            TextPosition(offset: 2, affinity: .downstream)
        ) as? TextSpan
        XCTAssertEqual(spanDown?.text, "cd")

        // Position 2 with upstream affinity should be in "ab"
        let spanUp = textSpan.getSpanForPosition(
            TextPosition(offset: 2, affinity: .upstream)
        ) as? TextSpan
        XCTAssertEqual(spanUp?.text, "ab")
    }
}

// MARK: - TextSpan CompareTo Tests

final class TextSpanCompareToTests: XCTestCase {

    func testIdenticalSelf() {
        let span = TextSpan(text: "hello")
        XCTAssertEqual(span.compareTo(span), .identical)
    }

    func testIdenticalEqual() {
        let a = TextSpan(text: "hello")
        let b = TextSpan(text: "hello")
        XCTAssertEqual(a.compareTo(b), .identical)
    }

    func testLayoutDifferentText() {
        let a = TextSpan(text: "hello")
        let b = TextSpan(text: "world")
        XCTAssertEqual(a.compareTo(b), .layout)
    }

    func testLayoutDifferentChildrenCount() {
        let a = TextSpan(text: "a", children: [TextSpan(text: "x")])
        let b = TextSpan(text: "a", children: [TextSpan(text: "x"), TextSpan(text: "y")])
        XCTAssertEqual(a.compareTo(b), .layout)
    }

    func testLayoutStylePresenceDiffers() {
        let a = TextSpan(text: "a", style: Flutter.TextStyle(fontSize: 10.0))
        let b = TextSpan(text: "a")
        XCTAssertEqual(a.compareTo(b), .layout)
    }

    func testPaintStyleDiffers() {
        let a = TextSpan(
            text: "a",
            style: Flutter.TextStyle(color: Color(0xFF000000))
        )
        let b = TextSpan(
            text: "a",
            style: Flutter.TextStyle(color: Color(0xFFFF0000))
        )
        XCTAssertEqual(a.compareTo(b), .paint)
    }

    func testLayoutStyleDiffersSize() {
        let a = TextSpan(
            text: "a",
            style: Flutter.TextStyle(fontSize: 10.0)
        )
        let b = TextSpan(
            text: "a",
            style: Flutter.TextStyle(fontSize: 20.0)
        )
        XCTAssertEqual(a.compareTo(b), .layout)
    }

    func testMetadataRecognizerDiffers() {
        let recognizer1 = TestGestureRecognizer()
        let recognizer2 = TestGestureRecognizer()
        let a = TextSpan(text: "a", recognizer: recognizer1)
        let b = TextSpan(text: "a", recognizer: recognizer2)
        XCTAssertEqual(a.compareTo(b), .metadata)
    }

    func testIdenticalWithSameRecognizer() {
        let recognizer = TestGestureRecognizer()
        let a = TextSpan(text: "a", recognizer: recognizer)
        let b = TextSpan(text: "a", recognizer: recognizer)
        XCTAssertEqual(a.compareTo(b), .identical)
    }

    func testCompareToChildrenPropagation() {
        // Children with paint differences should propagate paint comparison
        let a = TextSpan(
            text: "a",
            children: [
                TextSpan(
                    text: "x",
                    style: Flutter.TextStyle(color: Color(0xFF000000))
                ),
            ]
        )
        let b = TextSpan(
            text: "a",
            children: [
                TextSpan(
                    text: "x",
                    style: Flutter.TextStyle(color: Color(0xFFFF0000))
                ),
            ]
        )
        XCTAssertEqual(a.compareTo(b), .paint)
    }

    func testCompareToChildrenLayoutDifference() {
        let a = TextSpan(
            text: "a",
            children: [TextSpan(text: "x")]
        )
        let b = TextSpan(
            text: "a",
            children: [TextSpan(text: "y")]
        )
        XCTAssertEqual(a.compareTo(b), .layout)
    }
}

// MARK: - TextSpan visitChildren Tests

final class TextSpanVisitChildrenTests: XCTestCase {

    func testVisitChildrenSimple() {
        let span = TextSpan(text: "hello")
        var visited: [String?] = []
        _ = span.visitChildren { child in
            visited.append((child as? TextSpan)?.text)
            return true
        }
        XCTAssertEqual(visited, ["hello"])
    }

    func testVisitChildrenWithNilText() {
        let span = TextSpan(children: [TextSpan(text: "a"), TextSpan(text: "b")])
        var visited: [String?] = []
        _ = span.visitChildren { child in
            visited.append((child as? TextSpan)?.text)
            return true
        }
        XCTAssertEqual(visited, ["a", "b"])
    }

    func testVisitChildrenPreOrder() {
        let span = TextSpan(
            text: "root",
            children: [
                TextSpan(text: "child1"),
                TextSpan(text: "child2"),
            ]
        )
        var visited: [String?] = []
        _ = span.visitChildren { child in
            visited.append((child as? TextSpan)?.text)
            return true
        }
        XCTAssertEqual(visited, ["root", "child1", "child2"])
    }

    func testVisitChildrenStopsEarly() {
        let span = TextSpan(
            text: "root",
            children: [
                TextSpan(text: "child1"),
                TextSpan(text: "child2"),
            ]
        )
        var visited: [String?] = []
        let result = span.visitChildren { child in
            visited.append((child as? TextSpan)?.text)
            return false  // Stop after first visit
        }
        XCTAssertEqual(visited, ["root"])
        XCTAssertFalse(result)
    }

    func testVisitChildrenDeepNesting() {
        let span = TextSpan(
            text: "a",
            children: [
                TextSpan(
                    text: "b",
                    children: [TextSpan(text: "c")]
                ),
            ]
        )
        var visited: [String?] = []
        _ = span.visitChildren { child in
            visited.append((child as? TextSpan)?.text)
            return true
        }
        XCTAssertEqual(visited, ["a", "b", "c"])
    }
}

// MARK: - TextSpan visitDirectChildren Tests

final class TextSpanVisitDirectChildrenTests: XCTestCase {

    /// **Dart Test Source:** `text_span_test.dart:311-355`
    func testVisitDirectChildren() {
        let leaf1 = TextSpan(text: "leaf1")
        let leaf2 = TextSpan(text: "leaf2")
        let branch1 = TextSpan(children: [leaf1, leaf2])
        let branch2 = TextSpan(text: "branch2")
        let root = TextSpan(children: [branch1, branch2])

        func directChildrenOf(_ span: InlineSpan) -> [InlineSpan] {
            var visitOrder: [InlineSpan] = []
            _ = span.visitDirectChildren { child in
                visitOrder.append(child)
                return true
            }
            return visitOrder
        }

        let rootChildren = directChildrenOf(root)
        XCTAssertEqual(rootChildren.count, 2)
        XCTAssertTrue(rootChildren[0] === branch1)
        XCTAssertTrue(rootChildren[1] === branch2)

        let branch1Children = directChildrenOf(branch1)
        XCTAssertEqual(branch1Children.count, 2)
        XCTAssertTrue(branch1Children[0] === leaf1)
        XCTAssertTrue(branch1Children[1] === leaf2)

        XCTAssertTrue(directChildrenOf(branch2).isEmpty)
        XCTAssertTrue(directChildrenOf(leaf1).isEmpty)
        XCTAssertTrue(directChildrenOf(leaf2).isEmpty)
    }

    func testVisitDirectChildrenIndexInTree() {
        let leaf1 = TextSpan(text: "leaf1")
        let leaf2 = TextSpan(text: "leaf2")
        let branch1 = TextSpan(children: [leaf1, leaf2])
        let branch2 = TextSpan(text: "branch2")
        let root = TextSpan(children: [branch1, branch2])

        func indexInTree(_ target: InlineSpan) -> Int? {
            var index = 0
            func findInSubtree(_ subtreeRoot: InlineSpan) -> Bool {
                if target === subtreeRoot {
                    return false  // Found it, stop
                }
                index += 1
                return subtreeRoot.visitDirectChildren(findInSubtree)
            }
            return findInSubtree(root) ? nil : index
        }

        XCTAssertEqual(indexInTree(root), 0)
        XCTAssertEqual(indexInTree(branch1), 1)
        XCTAssertEqual(indexInTree(leaf1), 2)
        XCTAssertEqual(indexInTree(leaf2), 3)
        XCTAssertEqual(indexInTree(branch2), 4)
        XCTAssertNil(indexInTree(TextSpan(text: "foobar")))
    }
}

// MARK: - TextSpan Semantics Tests

final class TextSpanSemanticsTests: XCTestCase {

    /// **Dart Test Source:** `text_span_test.dart:299-309`
    func testComputeSemanticsInformation() {
        let span = TextSpan(
            text: "aaa",
            semanticsLabel: "bbb",
            semanticsIdentifier: "ccc"
        )
        var collector: [InlineSpanSemanticsInformation] = []
        span.computeSemanticsInformation(&collector)
        XCTAssertEqual(collector[0].text, "aaa")
        XCTAssertEqual(collector[0].semanticsLabel, "bbb")
        XCTAssertEqual(collector[0].semanticsIdentifier, "ccc")
    }

    /// **Dart Test Source:** `text_span_test.dart:441-491`
    func testComputeStringAttributes() {
        let span = TextSpan(
            text: "aaaaa",
            children: [
                TextSpan(
                    text: "yyyyy",
                    locale: Locale("es", "MX")
                ),
                TextSpan(
                    text: "xxxxx",
                    children: [
                        TextSpan(text: "zzzzz"),
                        TextSpan(text: "bbbbb", spellOut: true),
                    ],
                    spellOut: false
                ),
            ],
            spellOut: true
        )
        var collector: [InlineSpanSemanticsInformation] = []
        span.computeSemanticsInformation(&collector)

        XCTAssertEqual(collector.count, 5)

        // First entry: "aaaaa" with spellOut
        XCTAssertEqual(collector[0].stringAttributes.count, 1)
        XCTAssertTrue(collector[0].stringAttributes[0] is SpellOutStringAttribute)
        XCTAssertEqual(collector[0].stringAttributes[0].range, TextRange(start: 0, end: 5))

        // Second entry: "yyyyy" inherits spellOut + has locale
        XCTAssertEqual(collector[1].stringAttributes.count, 2)
        XCTAssertTrue(collector[1].stringAttributes[0] is SpellOutStringAttribute)
        XCTAssertEqual(collector[1].stringAttributes[0].range, TextRange(start: 0, end: 5))
        XCTAssertTrue(collector[1].stringAttributes[1] is LocaleStringAttribute)
        XCTAssertEqual(collector[1].stringAttributes[1].range, TextRange(start: 0, end: 5))
        let localeAttr = collector[1].stringAttributes[1] as! LocaleStringAttribute
        XCTAssertEqual(localeAttr.locale, Locale("es", "MX"))

        // Third entry: "xxxxx" with spellOut=false, no attributes
        XCTAssertEqual(collector[2].stringAttributes.count, 0)

        // Fourth entry: "zzzzz" inherits spellOut=false, no attributes
        XCTAssertEqual(collector[3].stringAttributes.count, 0)

        // Fifth entry: "bbbbb" with spellOut=true
        XCTAssertEqual(collector[4].stringAttributes.count, 1)
        XCTAssertTrue(collector[4].stringAttributes[0] is SpellOutStringAttribute)
        XCTAssertEqual(collector[4].stringAttributes[0].range, TextRange(start: 0, end: 5))
    }

    func testComputeStringAttributesCombined() {
        let span = TextSpan(
            text: "aaaaa",
            children: [
                TextSpan(
                    text: "yyyyy",
                    locale: Locale("es", "MX")
                ),
                TextSpan(
                    text: "xxxxx",
                    children: [
                        TextSpan(text: "zzzzz"),
                        TextSpan(text: "bbbbb", spellOut: true),
                    ],
                    spellOut: false
                ),
            ],
            spellOut: true
        )
        var collector: [InlineSpanSemanticsInformation] = []
        span.computeSemanticsInformation(&collector)

        let combined = combineSemanticsInfo(collector)
        XCTAssertEqual(combined.count, 1)
        XCTAssertEqual(combined[0].stringAttributes.count, 4)

        XCTAssertTrue(combined[0].stringAttributes[0] is SpellOutStringAttribute)
        XCTAssertEqual(combined[0].stringAttributes[0].range, TextRange(start: 0, end: 5))

        XCTAssertTrue(combined[0].stringAttributes[1] is SpellOutStringAttribute)
        XCTAssertEqual(combined[0].stringAttributes[1].range, TextRange(start: 5, end: 10))

        XCTAssertTrue(combined[0].stringAttributes[2] is LocaleStringAttribute)
        XCTAssertEqual(combined[0].stringAttributes[2].range, TextRange(start: 5, end: 10))
        let combinedLocaleAttr = combined[0].stringAttributes[2] as! LocaleStringAttribute
        XCTAssertEqual(
            combinedLocaleAttr.locale,
            Locale("es", "MX")
        )

        XCTAssertTrue(combined[0].stringAttributes[3] is SpellOutStringAttribute)
        XCTAssertEqual(combined[0].stringAttributes[3].range, TextRange(start: 20, end: 25))
    }

    func testSemanticsWithRecognizer() {
        let recognizer = TestGestureRecognizer()
        let span = TextSpan(text: "link", recognizer: recognizer)
        var collector: [InlineSpanSemanticsInformation] = []
        span.computeSemanticsInformation(&collector)
        XCTAssertEqual(collector.count, 1)
        XCTAssertTrue(collector[0].recognizer === recognizer)
        XCTAssertTrue(collector[0].requiresOwnNode)
    }
}

// MARK: - TextSpan CodeUnitAt Tests

final class TextSpanCodeUnitAtTests: XCTestCase {

    func testCodeUnitAt() {
        let span = TextSpan(
            text: "",
            children: [
                TextSpan(text: "AB"),
                TextSpan(text: "CD"),
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

    func testCodeUnitAtWithParentText() {
        let span = TextSpan(text: "Hello")
        XCTAssertEqual(span.codeUnitAt(0), 72)   // H
        XCTAssertEqual(span.codeUnitAt(4), 111)  // o
        XCTAssertNil(span.codeUnitAt(5))          // Out of bounds
    }
}

// MARK: - TextSpan Diagnostics Tests

final class TextSpanDiagnosticsTests: XCTestCase {

    func testToStringShort() {
        let span = TextSpan(text: "hello")
        XCTAssertEqual(span.toStringShort(), "TextSpan")
    }

    func testToStringDeepSimple() {
        let span = TextSpan(text: "a")
        let output = span.toStringDeep()
        XCTAssertTrue(output.contains("TextSpan"))
        XCTAssertTrue(output.contains("\"a\""))
    }

    func testToStringDeepEmpty() {
        let span = TextSpan()
        let output = span.toStringDeep()
        XCTAssertTrue(output.contains("(empty)"))
    }

    func testToStringDeepWithChildren() {
        let span = TextSpan(
            text: "a",
            children: [
                TextSpan(
                    text: "b",
                    children: [TextSpan()]
                ),
                TextSpan(text: "c"),
            ],
            style: Flutter.TextStyle(fontSize: 10.0)
        )
        let output = span.toStringDeep()
        XCTAssertTrue(output.contains("TextSpan"))
        XCTAssertTrue(output.contains("\"a\""))
        XCTAssertTrue(output.contains("\"b\""))
        XCTAssertTrue(output.contains("\"c\""))
        XCTAssertTrue(output.contains("(empty)"))
    }

    func testDebugDescribeChildren() {
        let child1 = TextSpan(text: "a")
        let child2 = TextSpan(text: "b")
        let span = TextSpan(children: [child1, child2])
        let nodes = span.debugDescribeChildren()
        XCTAssertEqual(nodes.count, 2)
    }

    func testDebugDescribeChildrenEmpty() {
        let span = TextSpan(text: "hello")
        let nodes = span.debugDescribeChildren()
        XCTAssertTrue(nodes.isEmpty)
    }

    func testDebugDescribeChildrenNilChildren() {
        let span = TextSpan()
        let nodes = span.debugDescribeChildren()
        XCTAssertTrue(nodes.isEmpty)
    }
}

// MARK: - TextSpan Validation Tests

final class TextSpanValidationTests: XCTestCase {

    func testDebugAssertIsValid() {
        let span = TextSpan(text: "hello")
        XCTAssertTrue(span.debugAssertIsValid())
    }

    func testDebugAssertIsValidWithChildren() {
        let span = TextSpan(
            text: "parent",
            children: [
                TextSpan(text: "child1"),
                TextSpan(text: "child2"),
            ]
        )
        XCTAssertTrue(span.debugAssertIsValid())
    }

    func testDebugAssertIsValidNested() {
        let span = TextSpan(
            children: [
                TextSpan(
                    text: "a",
                    children: [
                        TextSpan(text: "b")
                    ]
                ),
            ]
        )
        XCTAssertTrue(span.debugAssertIsValid())
    }
}

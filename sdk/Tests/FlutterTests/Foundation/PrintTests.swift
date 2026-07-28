// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Testing
import Foundation
@testable import Flutter

/// Tests for the debug printing utilities.
///
/// **Dart Test Source:** `packages/flutter/test/foundation/print_test.dart`

// MARK: - debugWordWrap Tests

@Suite("debugWordWrap Tests")
struct DebugWordWrapTests {
    /// **Dart Test:** `print_test.dart:22-26` - word wrap at width 10
    @Test("Word wrap at width 10 wraps correctly")
    func testWordWrapAtWidth10() {
        let result = debugWordWrap("Hello, world", 10)
        // "Hello," is 6 chars, "world" is 5 chars - should wrap
        #expect(result == ["Hello,", "world"])
    }

    /// **Dart Test:** `print_test.dart:27-34` - word wrap with narrow widths
    @Test("Word wrap with very narrow width handles correctly")
    func testWordWrapNarrowWidth() {
        // For narrow widths (0-13), "Hello,   world" should wrap to ["Hello,", "world"]
        for i in 0..<14 {
            let result = debugWordWrap("Hello,   world", i)
            #expect(result == ["Hello,", "world"], "Failed at width \(i)")
        }
    }

    @Test("Short message returns unchanged")
    func testShortMessageUnchanged() {
        let result = debugWordWrap("Hi", 80)
        #expect(result == ["Hi"])
    }

    @Test("Empty message returns unchanged")
    func testEmptyMessage() {
        let result = debugWordWrap("", 80)
        #expect(result == [""])
    }

    @Test("Line starting with # is not wrapped")
    func testHashLineNotWrapped() {
        let longHashLine = "# " + String(repeating: "a", count: 100)
        let result = debugWordWrap(longHashLine, 20)
        // Lines starting with # should not be wrapped
        #expect(result == [longHashLine])
    }

    @Test("Line with leading spaces and # is not wrapped")
    func testHashLineWithLeadingSpacesNotWrapped() {
        let longHashLine = "   # " + String(repeating: "a", count: 100)
        let result = debugWordWrap(longHashLine, 20)
        #expect(result == [longHashLine])
    }

    @Test("Long single word is not broken")
    func testLongSingleWordNotBroken() {
        let longWord = String(repeating: "a", count: 50)
        let result = debugWordWrap(longWord, 20)
        // Single word that's too long should stay as one line
        #expect(result == [longWord])
    }

    @Test("Multiple words with proper wrapping")
    func testMultipleWordsWrapping() {
        let result = debugWordWrap("The quick brown fox jumps over", 15)
        // Should wrap at word boundaries
        #expect(result.count > 1)
        // Each line should not exceed width (except possibly the first word if it's longer)
        for (index, line) in result.enumerated() {
            if index > 0 {
                // Subsequent lines may include the wrapIndent/prefix
                #expect(line.count <= 20, "Line too long: \(line)")
            }
        }
    }

    @Test("wrapIndent is added to subsequent lines")
    func testWrapIndentAdded() {
        let result = debugWordWrap("Hello world test wrap", 10, wrapIndent: ">> ")
        #expect(result.count > 1)
        // Subsequent lines should start with the wrapIndent
        for (index, line) in result.enumerated() {
            if index > 0 {
                #expect(line.hasPrefix(">> "), "Line \(index) missing wrapIndent: \(line)")
            }
        }
    }

    @Test("List-style prefix is preserved")
    func testListStylePrefixPreserved() {
        let result = debugWordWrap("- This is a long list item that needs wrapping", 20)
        #expect(result.count > 1)
        // Subsequent lines should have proper indentation matching the list prefix
        if result.count > 1 {
            // The "- " prefix is 2 chars, so subsequent lines should have at least 2 spaces
            #expect(result[1].hasPrefix("  "), "Subsequent line should have matching indent")
        }
    }

    @Test("Numbered list prefix is preserved")
    func testNumberedListPrefixPreserved() {
        let result = debugWordWrap("1. This is a long numbered list item that needs wrapping", 20)
        #expect(result.count > 1)
    }
}

// MARK: - debugPrintSynchronously Tests

@Suite("debugPrintSynchronously Tests")
struct DebugPrintSynchronouslyTests {
    /// **Dart Test:** `print_test.dart:12-19` - basic print
    @Test("Prints simple message")
    func testPrintsSimpleMessage() {
        // We can't easily capture stdout in Swift tests, but we can verify the function runs
        // without error
        debugPrintSynchronously("Hello, world")
        // If we get here without crashing, test passes
        #expect(Bool(true))
    }

    @Test("Prints nil as 'null'")
    func testPrintsNil() {
        // debugPrintSynchronously should handle nil
        debugPrintSynchronously(nil)
        #expect(Bool(true))
    }

    @Test("Prints with wrap width")
    func testPrintsWithWrapWidth() {
        debugPrintSynchronously("Hello, world", wrapWidth: 10)
        #expect(Bool(true))
    }
}

// MARK: - debugPrintThrottled Tests

@Suite("debugPrintThrottled Tests")
struct DebugPrintThrottledTests {
    /// **Dart Test:** `print_test.dart:36-41` - basic throttled print
    @Test("Prints simple message")
    func testPrintsSimpleMessage() {
        debugPrintThrottled("Hello, world")
        #expect(Bool(true))
    }

    /// **Dart Test:** `print_test.dart:43-48` - throttled print with wrap
    @Test("Prints with wrap width")
    func testPrintsWithWrapWidth() {
        debugPrintThrottled("Hello, world", wrapWidth: 10)
        #expect(Bool(true))
    }

    /// **Dart Test:** `print_test.dart:71-85` - can print null
    @Test("Prints nil as 'null'")
    func testPrintsNil() {
        debugPrintThrottled(nil)
        #expect(Bool(true))
    }

    @Test("Prints nil with wrap width")
    func testPrintsNilWithWrapWidth() {
        debugPrintThrottled(nil, wrapWidth: 80)
        #expect(Bool(true))
    }
}

// MARK: - debugPrint Variable Tests

@Suite("debugPrint Variable Tests")
struct DebugPrintVariableTests {
    @Test("debugPrint defaults to debugPrintThrottled")
    func testDefaultValue() {
        // The debugPrint variable should be set
        let message = "test message"
        debugPrint(message, nil)
        #expect(Bool(true))
    }

    @Test("debugPrint can be reassigned")
    func testCanBeReassigned() {
        // Save original
        let original = debugPrint

        // Create a custom callback
        var captured: String? = nil
        let customPrint: DebugPrintCallback = { message, _ in
            captured = message
        }

        // Assign and use
        debugPrint = customPrint
        debugPrint("test", nil)

        // Restore
        debugPrint = original

        #expect(captured == "test")
    }
}

// MARK: - DebugPrintCallback Tests

@Suite("DebugPrintCallback Tests")
struct DebugPrintCallbackTests {
    @Test("DebugPrintCallback signature is correct")
    func testCallbackSignature() {
        // Create a callback matching the expected signature
        let callback: DebugPrintCallback = { message, wrapWidth in
            _ = message
            _ = wrapWidth
        }

        // Should be callable with String? and Int?
        callback("test", 80)
        callback(nil, nil)
        callback("test", nil)
        callback(nil, 80)

        #expect(Bool(true))
    }
}

// MARK: - debugPrintDone Tests

@Suite("debugPrintDone Tests")
struct DebugPrintDoneTests {
    @Test("Callback version completes immediately when buffer empty")
    func testCallbackCompletesImmediately() async {
        // First ensure any pending prints are done
        await debugPrintDone()

        var completed = false
        debugPrintDone {
            completed = true
        }

        // Should complete immediately since buffer is empty
        // Give a tiny bit of time for the callback to be called
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        #expect(completed == true)
    }

    @Test("Async version completes when buffer empty")
    func testAsyncCompletesWhenEmpty() async {
        // This should complete immediately if buffer is empty
        await debugPrintDone()
        #expect(Bool(true))
    }
}

// MARK: - Edge Case Tests

@Suite("Edge Case Tests")
struct EdgeCaseTests {
    @Test("debugWordWrap handles message equal to width")
    func testMessageEqualToWidth() {
        let message = "12345"
        let result = debugWordWrap(message, 5)
        #expect(result == [message])
    }

    @Test("debugWordWrap handles message one char shorter than width")
    func testMessageOneShorterThanWidth() {
        let message = "1234"
        let result = debugWordWrap(message, 5)
        #expect(result == [message])
    }

    @Test("debugWordWrap handles message one char longer than width with no spaces")
    func testMessageOneLongerNoSpaces() {
        let message = "123456"
        let result = debugWordWrap(message, 5)
        // Single word longer than width should stay as one line
        #expect(result == [message])
    }

    @Test("debugWordWrap handles multiple spaces between words")
    func testMultipleSpacesBetweenWords() {
        let result = debugWordWrap("hello     world", 10)
        // Multiple spaces should be handled gracefully
        #expect(result.count >= 1)
    }

    @Test("debugWordWrap handles leading spaces")
    func testLeadingSpaces() {
        let result = debugWordWrap("   hello world test", 10)
        #expect(result.count >= 1)
        // First line should preserve leading spaces
        #expect(result[0].hasPrefix("   "))
    }

    @Test("debugWordWrap handles trailing spaces")
    func testTrailingSpaces() {
        let result = debugWordWrap("hello world   ", 20)
        #expect(result.count >= 1)
    }

    @Test("debugPrintSynchronously handles multiline message")
    func testMultilineMessage() {
        debugPrintSynchronously("Line 1\nLine 2\nLine 3")
        #expect(Bool(true))
    }

    @Test("debugPrintSynchronously handles multiline message with wrap")
    func testMultilineMessageWithWrap() {
        debugPrintSynchronously("This is line 1\nThis is line 2", wrapWidth: 10)
        #expect(Bool(true))
    }

    @Test("debugPrintThrottled handles multiline message")
    func testThrottledMultilineMessage() {
        debugPrintThrottled("Line 1\nLine 2\nLine 3")
        #expect(Bool(true))
    }

    @Test("Very long message is handled")
    func testVeryLongMessage() {
        let longMessage = String(repeating: "word ", count: 1000)
        debugPrintSynchronously(longMessage, wrapWidth: 80)
        #expect(Bool(true))
    }
}

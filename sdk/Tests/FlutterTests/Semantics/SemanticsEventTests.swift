// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for SemanticsEvent types (Assertiveness, SemanticsEvent protocol,
/// AnnounceSemanticsEvent, TooltipSemanticsEvent, LongPressSemanticsEvent,
/// TapSemanticEvent, FocusSemanticEvent).
///
/// **Dart Test Source:** `packages/flutter/test/widgets/semantics_event_test.dart`
final class SemanticsEventTests: XCTestCase {

    // MARK: - Assertiveness Enum Tests

    /// Test that Assertiveness.polite has raw value 0.
    func testAssertivenessPoliteRawValue() {
        XCTAssertEqual(Assertiveness.polite.rawValue, 0)
    }

    /// Test that Assertiveness.assertive has raw value 1.
    func testAssertivenessAssertiveRawValue() {
        XCTAssertEqual(Assertiveness.assertive.rawValue, 1)
    }

    // MARK: - SemanticsEvent Protocol Default Tests

    /// Test toMap() without nodeId returns type and data.
    ///
    /// **Dart Test:** `semantics_event_test.dart:18-22`
    func testSemanticsEventToMapWithoutNodeId() {
        let event = TestSemanticsEvent(text: "hi", number: 11)
        let map = event.toMap()

        XCTAssertEqual(map["type"] as? String, "TestEvent")

        let data = map["data"] as? [String: Any]
        XCTAssertNotNil(data)
        XCTAssertEqual(data?["text"] as? String, "hi")
        XCTAssertEqual(data?["number"] as? Int, 11)

        // Should not contain nodeId key
        XCTAssertNil(map["nodeId"])
    }

    /// Test toMap() with nodeId includes the nodeId in the map.
    ///
    /// **Dart Test:** `semantics_event_test.dart:23-27`
    func testSemanticsEventToMapWithNodeId() {
        let event = TestSemanticsEvent(text: "hi", number: 11)
        let map = event.toMap(nodeId: 123)

        XCTAssertEqual(map["type"] as? String, "TestEvent")
        XCTAssertEqual(map["nodeId"] as? Int, 123)

        let data = map["data"] as? [String: Any]
        XCTAssertNotNil(data)
        XCTAssertEqual(data?["text"] as? String, "hi")
        XCTAssertEqual(data?["number"] as? Int, 11)
    }

    /// Test description property format with no data.
    ///
    /// **Dart Test:** `semantics_event_test.dart:9-10`
    func testSemanticsEventDescriptionEmpty() {
        let event = TestSemanticsEvent()
        XCTAssertEqual(event.description, "TestSemanticsEvent()")
    }

    /// Test description property format with number only.
    ///
    /// **Dart Test:** `semantics_event_test.dart:11`
    func testSemanticsEventDescriptionWithNumber() {
        let event = TestSemanticsEvent(number: 10)
        XCTAssertEqual(event.description, "TestSemanticsEvent(number: 10)")
    }

    /// Test description property format with text only.
    ///
    /// **Dart Test:** `semantics_event_test.dart:12`
    func testSemanticsEventDescriptionWithText() {
        let event = TestSemanticsEvent(text: "hello")
        XCTAssertEqual(event.description, "TestSemanticsEvent(text: hello)")
    }

    /// Test description property format with both text and number.
    /// Keys are sorted alphabetically, so number comes before text.
    ///
    /// **Dart Test:** `semantics_event_test.dart:13-16`
    func testSemanticsEventDescriptionWithTextAndNumber() {
        let event = TestSemanticsEvent(text: "hello", number: 10)
        XCTAssertEqual(event.description, "TestSemanticsEvent(number: 10, text: hello)")
    }

    // MARK: - AnnounceSemanticsEvent Tests

    /// Test AnnounceSemanticsEvent construction with all parameters.
    func testAnnounceSemanticsEventConstruction() {
        let event = AnnounceSemanticsEvent(
            "Hello world",
            .ltr,
            1,
            assertiveness: .assertive
        )
        XCTAssertEqual(event.message, "Hello world")
        XCTAssertEqual(event.textDirection, .ltr)
        XCTAssertEqual(event.viewId, 1)
        XCTAssertEqual(event.assertiveness, .assertive)
    }

    /// Test getDataMap() with default assertiveness (polite) omits assertiveness key.
    func testAnnounceSemanticsEventGetDataMapDefaultAssertiveness() {
        let event = AnnounceSemanticsEvent("test message", .ltr, 0)
        let dataMap = event.getDataMap()

        XCTAssertEqual(dataMap["message"] as? String, "test message")
        XCTAssertEqual(dataMap["textDirection"] as? Int, TextDirection.ltr.rawValue)
        XCTAssertEqual(dataMap["viewId"] as? Int, 0)
        // Default assertiveness is polite, which should be omitted from the map
        XCTAssertNil(dataMap["assertiveness"])
    }

    /// Test getDataMap() with assertive assertiveness includes assertiveness key.
    func testAnnounceSemanticsEventGetDataMapAssertiveAssertiveness() {
        let event = AnnounceSemanticsEvent(
            "urgent message",
            .rtl,
            2,
            assertiveness: .assertive
        )
        let dataMap = event.getDataMap()

        XCTAssertEqual(dataMap["message"] as? String, "urgent message")
        XCTAssertEqual(dataMap["textDirection"] as? Int, TextDirection.rtl.rawValue)
        XCTAssertEqual(dataMap["viewId"] as? Int, 2)
        XCTAssertEqual(dataMap["assertiveness"] as? Int, Assertiveness.assertive.rawValue)
    }

    /// Test textDirection.rawValue mapping: ltr=1, rtl=0.
    func testAnnounceSemanticsEventTextDirectionRawValues() {
        let ltrEvent = AnnounceSemanticsEvent("msg", .ltr, 0)
        let rtlEvent = AnnounceSemanticsEvent("msg", .rtl, 0)

        let ltrDataMap = ltrEvent.getDataMap()
        let rtlDataMap = rtlEvent.getDataMap()

        XCTAssertEqual(ltrDataMap["textDirection"] as? Int, 1)
        XCTAssertEqual(rtlDataMap["textDirection"] as? Int, 0)
    }

    /// Test that AnnounceSemanticsEvent type is "announce".
    func testAnnounceSemanticsEventType() {
        let event = AnnounceSemanticsEvent("msg", .ltr, 0)
        XCTAssertEqual(event.type, "announce")
    }

    /// Test toMap() output for AnnounceSemanticsEvent.
    func testAnnounceSemanticsEventToMap() {
        let event = AnnounceSemanticsEvent("hello", .ltr, 5)
        let map = event.toMap()

        XCTAssertEqual(map["type"] as? String, "announce")
        XCTAssertNil(map["nodeId"])

        let data = map["data"] as? [String: Any]
        XCTAssertNotNil(data)
        XCTAssertEqual(data?["message"] as? String, "hello")
        XCTAssertEqual(data?["textDirection"] as? Int, 1)
        XCTAssertEqual(data?["viewId"] as? Int, 5)
    }

    // MARK: - TooltipSemanticsEvent Tests

    /// Test getDataMap() returns dictionary with message.
    func testTooltipSemanticsEventGetDataMap() {
        let event = TooltipSemanticsEvent("my tooltip")
        let dataMap = event.getDataMap()

        XCTAssertEqual(dataMap.count, 1)
        XCTAssertEqual(dataMap["message"] as? String, "my tooltip")
    }

    /// Test that TooltipSemanticsEvent type is "tooltip".
    func testTooltipSemanticsEventType() {
        let event = TooltipSemanticsEvent("tip")
        XCTAssertEqual(event.type, "tooltip")
    }

    // MARK: - LongPressSemanticsEvent Tests

    /// Test getDataMap() returns empty dictionary.
    func testLongPressSemanticsEventGetDataMap() {
        let event = LongPressSemanticsEvent()
        let dataMap = event.getDataMap()

        XCTAssertTrue(dataMap.isEmpty)
    }

    /// Test that LongPressSemanticsEvent type is "longPress".
    func testLongPressSemanticsEventType() {
        let event = LongPressSemanticsEvent()
        XCTAssertEqual(event.type, "longPress")
    }

    // MARK: - TapSemanticEvent Tests

    /// Test getDataMap() returns empty dictionary.
    func testTapSemanticEventGetDataMap() {
        let event = TapSemanticEvent()
        let dataMap = event.getDataMap()

        XCTAssertTrue(dataMap.isEmpty)
    }

    /// Test that TapSemanticEvent type is "tap".
    func testTapSemanticEventType() {
        let event = TapSemanticEvent()
        XCTAssertEqual(event.type, "tap")
    }

    // MARK: - FocusSemanticEvent Tests

    /// Test getDataMap() returns empty dictionary.
    func testFocusSemanticEventGetDataMap() {
        let event = FocusSemanticEvent()
        let dataMap = event.getDataMap()

        XCTAssertTrue(dataMap.isEmpty)
    }

    /// Test that FocusSemanticEvent type is "focus".
    func testFocusSemanticEventType() {
        let event = FocusSemanticEvent()
        XCTAssertEqual(event.type, "focus")
    }

    /// Test toMap() returns expected map structure.
    ///
    /// **Dart Test:** `semantics_event_test.dart:29-33`
    func testFocusSemanticEventToMap() {
        let event = FocusSemanticEvent()
        let map = event.toMap()

        XCTAssertEqual(map["type"] as? String, "focus")

        let data = map["data"] as? [String: Any]
        XCTAssertNotNil(data)
        XCTAssertTrue(data!.isEmpty)
    }
}

// MARK: - Test Helper

/// A test-only SemanticsEvent implementation that mirrors the Dart test helper.
///
/// **Dart Test Source:** `semantics_event_test.dart:37-54`
private struct TestSemanticsEvent: SemanticsEvent {
    let type: String = "TestEvent"
    let text: String?
    let number: Int?

    init(text: String? = nil, number: Int? = nil) {
        self.text = text
        self.number = number
    }

    func getDataMap() -> [String: Any] {
        var result: [String: Any] = [:]
        if let text {
            result["text"] = text
        }
        if let number {
            result["number"] = number
        }
        return result
    }
}

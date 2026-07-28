// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for `SemanticsData`.
///
/// **Dart Test Source:** `packages/flutter/test/semantics/semantics_test.dart`
final class SemanticsDataTests: XCTestCase {

    // MARK: - Helper

    /// Creates a minimal `SemanticsData` with default values.
    private func makeMinimalData(
        actions: Int = 0,
        label: String = "",
        value: String = "",
        hint: String = "",
        tooltip: String = "",
        textDirection: TextDirection? = nil,
        headingLevel: Int = 0
    ) -> SemanticsData {
        let td = textDirection ?? (label.isEmpty && value.isEmpty && hint.isEmpty && tooltip.isEmpty ? nil : .ltr)
        return SemanticsData(
            flagsCollection: .none,
            actions: actions,
            identifier: "",
            attributedLabel: Flutter.AttributedString(label),
            attributedValue: Flutter.AttributedString(value),
            attributedIncreasedValue: Flutter.AttributedString(""),
            attributedDecreasedValue: Flutter.AttributedString(""),
            attributedHint: Flutter.AttributedString(hint),
            tooltip: tooltip,
            textDirection: td,
            rect: .zero,
            textSelection: nil,
            scrollIndex: nil,
            scrollChildCount: nil,
            scrollPosition: nil,
            scrollExtentMax: nil,
            scrollExtentMin: nil,
            platformViewId: nil,
            maxValueLength: nil,
            currentValueLength: nil,
            headingLevel: headingLevel,
            linkUrl: nil,
            role: .none,
            controlsNodes: nil,
            validationResult: .none,
            inputType: .none,
            locale: nil
        )
    }

    // MARK: - Construction Tests

    /// Test construction with required properties.
    func testConstruction() {
        let data = makeMinimalData(label: "Hello", textDirection: .ltr)
        XCTAssertEqual(data.label, "Hello")
        XCTAssertEqual(data.attributedLabel.string, "Hello")
        XCTAssertEqual(data.textDirection, .ltr)
        XCTAssertEqual(data.actions, 0)
        XCTAssertEqual(data.identifier, "")
        XCTAssertEqual(data.tooltip, "")
    }

    // MARK: - Computed Property Tests

    /// Test `label` computed property returns the attributedLabel string.
    func testLabelComputedProperty() {
        let data = makeMinimalData(label: "My Label", textDirection: .ltr)
        XCTAssertEqual(data.label, "My Label")
    }

    /// Test `value` computed property returns the attributedValue string.
    func testValueComputedProperty() {
        let data = makeMinimalData(value: "My Value", textDirection: .ltr)
        XCTAssertEqual(data.value, "My Value")
    }

    /// Test `hint` computed property returns the attributedHint string.
    func testHintComputedProperty() {
        let data = makeMinimalData(hint: "My Hint", textDirection: .ltr)
        XCTAssertEqual(data.hint, "My Hint")
    }

    // MARK: - hasAction Tests

    /// Test `hasAction` returns true for included actions.
    func testHasActionReturnsTrue() {
        let actions = SemanticsAction.tap.index | SemanticsAction.longPress.index
        let data = makeMinimalData(actions: actions)
        XCTAssertTrue(data.hasAction(.tap))
        XCTAssertTrue(data.hasAction(.longPress))
    }

    /// Test `hasAction` returns false for actions not included.
    func testHasActionReturnsFalse() {
        let actions = SemanticsAction.tap.index
        let data = makeMinimalData(actions: actions)
        XCTAssertFalse(data.hasAction(.longPress))
        XCTAssertFalse(data.hasAction(.scrollUp))
    }

    /// Test `hasAction` with no actions (0).
    func testHasActionWithNoActions() {
        let data = makeMinimalData(actions: 0)
        XCTAssertFalse(data.hasAction(.tap))
        XCTAssertFalse(data.hasAction(.longPress))
    }

    // MARK: - Equality Tests

    /// Test that two SemanticsData with same fields are equal.
    func testEqualityWithSameFields() {
        let data1 = makeMinimalData(label: "test", textDirection: .ltr)
        let data2 = makeMinimalData(label: "test", textDirection: .ltr)
        XCTAssertEqual(data1, data2)
    }

    /// Test that SemanticsData with different labels are not equal.
    func testInequalityDifferentLabels() {
        let data1 = makeMinimalData(label: "one", textDirection: .ltr)
        let data2 = makeMinimalData(label: "two", textDirection: .ltr)
        XCTAssertNotEqual(data1, data2)
    }

    /// Test that SemanticsData with different actions are not equal.
    func testInequalityDifferentActions() {
        let data1 = makeMinimalData(actions: SemanticsAction.tap.index)
        let data2 = makeMinimalData(actions: SemanticsAction.longPress.index)
        XCTAssertNotEqual(data1, data2)
    }

    /// Test that SemanticsData with different textDirection are not equal.
    func testInequalityDifferentTextDirection() {
        let data1 = makeMinimalData(label: "x", textDirection: .ltr)
        let data2 = makeMinimalData(label: "x", textDirection: .rtl)
        XCTAssertNotEqual(data1, data2)
    }

    /// Test that SemanticsData with different headingLevel are not equal.
    func testInequalityDifferentHeadingLevel() {
        let data1 = makeMinimalData(headingLevel: 1)
        let data2 = makeMinimalData(headingLevel: 2)
        XCTAssertNotEqual(data1, data2)
    }

    // MARK: - Hashable Tests

    /// Test that equal SemanticsData have equal hash values.
    func testHashValueConsistency() {
        let data1 = makeMinimalData(label: "hash", textDirection: .ltr)
        let data2 = makeMinimalData(label: "hash", textDirection: .ltr)
        XCTAssertEqual(data1.hashValue, data2.hashValue)
    }

    // MARK: - toStringShort Tests

    /// Test toStringShort returns "SemanticsData".
    func testToStringShort() {
        let data = makeMinimalData()
        XCTAssertEqual(data.toStringShort(), "SemanticsData")
    }
}

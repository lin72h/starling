// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for `CustomSemanticsAction`.
///
/// **Dart Test Source:** `packages/flutter/test/semantics/semantics_test.dart`
final class CustomSemanticsActionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CustomSemanticsAction.resetForTests()
    }

    override func tearDown() {
        CustomSemanticsAction.resetForTests()
        super.tearDown()
    }

    // MARK: - Construction Tests

    /// Test label-based construction.
    func testLabelBasedConstruction() {
        let action = CustomSemanticsAction(label: "Move Up")
        XCTAssertEqual(action.label, "Move Up")
        XCTAssertNil(action.hint)
        XCTAssertNil(action.action)
    }

    /// Test overriding construction with hint and action.
    func testOverridingConstruction() {
        let action = CustomSemanticsAction(
            overridingHint: "Double tap to activate",
            action: .tap
        )
        XCTAssertNil(action.label)
        XCTAssertEqual(action.hint, "Double tap to activate")
        XCTAssertEqual(action.action, .tap)
    }

    // MARK: - getIdentifier Tests

    /// Test that `getIdentifier` assigns unique IDs starting from 0.
    func testGetIdentifierAssignsUniqueIds() {
        let action1 = CustomSemanticsAction(label: "Action 1")
        let action2 = CustomSemanticsAction(label: "Action 2")
        let action3 = CustomSemanticsAction(label: "Action 3")

        let id1 = CustomSemanticsAction.getIdentifier(action1)
        let id2 = CustomSemanticsAction.getIdentifier(action2)
        let id3 = CustomSemanticsAction.getIdentifier(action3)

        XCTAssertEqual(id1, 0)
        XCTAssertEqual(id2, 1)
        XCTAssertEqual(id3, 2)
    }

    /// Test that calling `getIdentifier` twice for the same action returns the same ID.
    func testGetIdentifierReturnsSameIdForSameAction() {
        let action = CustomSemanticsAction(label: "Consistent")
        let id1 = CustomSemanticsAction.getIdentifier(action)
        let id2 = CustomSemanticsAction.getIdentifier(action)
        XCTAssertEqual(id1, id2)
    }

    /// Test that equal actions (same label) share the same ID.
    func testGetIdentifierSameIdForEqualActions() {
        let action1 = CustomSemanticsAction(label: "Same Label")
        let action2 = CustomSemanticsAction(label: "Same Label")

        let id1 = CustomSemanticsAction.getIdentifier(action1)
        let id2 = CustomSemanticsAction.getIdentifier(action2)

        // Since action1 == action2 (same label), they should get the same ID
        XCTAssertEqual(id1, id2)
    }

    // MARK: - getAction Tests

    /// Test that `getAction` retrieves an action by its assigned ID.
    func testGetActionRetrievesByID() {
        let action = CustomSemanticsAction(label: "Retrieve Me")
        let id = CustomSemanticsAction.getIdentifier(action)

        let retrieved = CustomSemanticsAction.getAction(id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, action)
    }

    /// Test that `getAction` returns nil for an unregistered ID.
    func testGetActionReturnsNilForUnknownId() {
        let result = CustomSemanticsAction.getAction(999)
        XCTAssertNil(result)
    }

    // MARK: - Equality and Hashing Tests

    /// Test that actions with the same label are equal.
    func testEqualityWithSameLabel() {
        let action1 = CustomSemanticsAction(label: "Move")
        let action2 = CustomSemanticsAction(label: "Move")
        XCTAssertEqual(action1, action2)
    }

    /// Test that actions with different labels are not equal.
    func testInequalityWithDifferentLabels() {
        let action1 = CustomSemanticsAction(label: "Move Up")
        let action2 = CustomSemanticsAction(label: "Move Down")
        XCTAssertNotEqual(action1, action2)
    }

    /// Test that label-based and overriding actions are not equal.
    func testInequalityLabelVsOverriding() {
        let labelAction = CustomSemanticsAction(label: "Tap")
        let overrideAction = CustomSemanticsAction(
            overridingHint: "Tap",
            action: .tap
        )
        XCTAssertNotEqual(labelAction, overrideAction)
    }

    /// Test that two overriding actions with same hint and action are equal.
    func testEqualityOverridingSameHintAndAction() {
        let action1 = CustomSemanticsAction(
            overridingHint: "Press",
            action: .longPress
        )
        let action2 = CustomSemanticsAction(
            overridingHint: "Press",
            action: .longPress
        )
        XCTAssertEqual(action1, action2)
    }

    /// Test that equal actions have equal hash values.
    func testHashValueConsistencyForEqualActions() {
        let action1 = CustomSemanticsAction(label: "Hash Test")
        let action2 = CustomSemanticsAction(label: "Hash Test")
        XCTAssertEqual(action1.hashValue, action2.hashValue)
    }

    /// Test that actions work correctly as dictionary keys.
    func testUsableAsDictionaryKey() {
        let action1 = CustomSemanticsAction(label: "Key1")
        let action2 = CustomSemanticsAction(label: "Key2")
        let action1Dup = CustomSemanticsAction(label: "Key1")

        var dict: [CustomSemanticsAction: String] = [:]
        dict[action1] = "value1"
        dict[action2] = "value2"

        // action1Dup should find the same entry as action1
        XCTAssertEqual(dict[action1Dup], "value1")
        XCTAssertEqual(dict[action2], "value2")
    }

    // MARK: - resetForTests Tests

    /// Test that `resetForTests` clears all registered actions and resets ID counter.
    func testResetForTestsClearsState() {
        let action = CustomSemanticsAction(label: "Will Be Cleared")
        let id = CustomSemanticsAction.getIdentifier(action)
        XCTAssertEqual(id, 0)

        CustomSemanticsAction.resetForTests()

        // After reset, getAction should return nil for the old ID
        XCTAssertNil(CustomSemanticsAction.getAction(id))

        // After reset, new actions should start from 0 again
        let newAction = CustomSemanticsAction(label: "Fresh Start")
        let newId = CustomSemanticsAction.getIdentifier(newAction)
        XCTAssertEqual(newId, 0)
    }

    // MARK: - Description Tests

    /// Test description output for a label-based action without a registered ID.
    func testDescriptionWithoutRegisteredId() {
        let action = CustomSemanticsAction(label: "Test Action")
        let desc = action.description
        XCTAssertTrue(desc.contains("CustomSemanticsAction("))
        XCTAssertTrue(desc.contains("label:Test Action"))
        XCTAssertTrue(desc.contains("hint:nil"))
        XCTAssertTrue(desc.contains("action:nil"))
    }

    /// Test description output for a label-based action with a registered ID.
    func testDescriptionWithRegisteredId() {
        let action = CustomSemanticsAction(label: "Registered")
        let id = CustomSemanticsAction.getIdentifier(action)
        let desc = action.description
        XCTAssertTrue(desc.contains("CustomSemanticsAction(\(id)"))
        XCTAssertTrue(desc.contains("label:Registered"))
    }

    /// Test description output for an overriding action.
    func testDescriptionOverridingAction() {
        let action = CustomSemanticsAction(
            overridingHint: "Custom tap hint",
            action: .tap
        )
        let desc = action.description
        XCTAssertTrue(desc.contains("label:nil"))
        XCTAssertTrue(desc.contains("hint:Custom tap hint"))
        XCTAssertTrue(desc.contains("action:"))
    }
}

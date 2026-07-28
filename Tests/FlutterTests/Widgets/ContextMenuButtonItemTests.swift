// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for ContextMenuButtonType and ContextMenuButtonItem.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/context_menu_button_item_test.dart`
final class ContextMenuButtonItemTests: XCTestCase {

    // MARK: - ContextMenuButtonType Enum Cases

    func testContextMenuButtonTypeAllCasesExist() {
        // Verify all 10 enum cases exist and are distinct
        let allCases: [ContextMenuButtonType] = [
            .cut, .copy, .paste, .selectAll, .delete,
            .lookUp, .searchWeb, .share, .liveTextInput, .custom,
        ]
        // All 10 cases should be unique
        XCTAssertEqual(allCases.count, 10)
        for i in 0..<allCases.count {
            for j in (i + 1)..<allCases.count {
                XCTAssertNotEqual(
                    String(describing: allCases[i]),
                    String(describing: allCases[j]),
                    "Cases at index \(i) and \(j) should be different"
                )
            }
        }
    }

    func testContextMenuButtonTypeIsSendable() {
        let type: ContextMenuButtonType = .cut
        let _: any Sendable = type
        XCTAssertTrue(true) // Compiles = passes
    }

    // MARK: - ContextMenuButtonItem Constructor Defaults

    func testConstructorDefaultTypeIsCustom() {
        let item = ContextMenuButtonItem(onPressed: nil)
        XCTAssertEqual(item.type, .custom)
    }

    func testConstructorDefaultLabelIsNil() {
        let item = ContextMenuButtonItem(onPressed: nil)
        XCTAssertNil(item.label)
    }

    func testConstructorWithOnPressedNil() {
        let item = ContextMenuButtonItem(onPressed: nil)
        XCTAssertNil(item.onPressed)
    }

    func testConstructorWithOnPressedCallback() {
        var called = false
        let item = ContextMenuButtonItem(onPressed: { called = true })
        XCTAssertNotNil(item.onPressed)
        item.onPressed!()
        XCTAssertTrue(called)
    }

    func testConstructorWithExplicitType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .cut)
        XCTAssertEqual(item.type, .cut)
    }

    func testConstructorWithExplicitLabel() {
        let item = ContextMenuButtonItem(onPressed: nil, label: "My Label")
        XCTAssertEqual(item.label, "My Label")
    }

    func testConstructorWithAllParameters() {
        let item = ContextMenuButtonItem(
            onPressed: {},
            type: .paste,
            label: "Paste Here"
        )
        XCTAssertNotNil(item.onPressed)
        XCTAssertEqual(item.type, .paste)
        XCTAssertEqual(item.label, "Paste Here")
    }

    // MARK: - Constructor with All 10 Types

    func testConstructorWithCutType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .cut)
        XCTAssertEqual(item.type, .cut)
    }

    func testConstructorWithCopyType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .copy)
        XCTAssertEqual(item.type, .copy)
    }

    func testConstructorWithPasteType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .paste)
        XCTAssertEqual(item.type, .paste)
    }

    func testConstructorWithSelectAllType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .selectAll)
        XCTAssertEqual(item.type, .selectAll)
    }

    func testConstructorWithDeleteType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .delete)
        XCTAssertEqual(item.type, .delete)
    }

    func testConstructorWithLookUpType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .lookUp)
        XCTAssertEqual(item.type, .lookUp)
    }

    func testConstructorWithSearchWebType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .searchWeb)
        XCTAssertEqual(item.type, .searchWeb)
    }

    func testConstructorWithShareType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .share)
        XCTAssertEqual(item.type, .share)
    }

    func testConstructorWithLiveTextInputType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .liveTextInput)
        XCTAssertEqual(item.type, .liveTextInput)
    }

    func testConstructorWithCustomType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .custom)
        XCTAssertEqual(item.type, .custom)
    }

    // MARK: - Equality

    func testEqualitySameTypeSameLabel() {
        let a = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Cut")
        let b = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Cut")
        XCTAssertEqual(a, b)
    }

    func testEqualitySameTypeSameLabelDifferentOnPressed() {
        // Equality ignores onPressed
        let a = ContextMenuButtonItem(onPressed: nil, type: .copy, label: "Copy")
        let b = ContextMenuButtonItem(onPressed: {}, type: .copy, label: "Copy")
        XCTAssertEqual(a, b)
    }

    func testEqualityDifferentType() {
        let a = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Action")
        let b = ContextMenuButtonItem(onPressed: nil, type: .copy, label: "Action")
        XCTAssertNotEqual(a, b)
    }

    func testEqualityDifferentLabel() {
        let a = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Cut")
        let b = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Delete")
        XCTAssertNotEqual(a, b)
    }

    func testEqualityBothNilLabels() {
        let a = ContextMenuButtonItem(onPressed: nil, type: .paste)
        let b = ContextMenuButtonItem(onPressed: nil, type: .paste)
        XCTAssertEqual(a, b)
    }

    func testEqualityNilVsNonNilLabel() {
        let a = ContextMenuButtonItem(onPressed: nil, type: .paste, label: nil)
        let b = ContextMenuButtonItem(onPressed: nil, type: .paste, label: "Paste")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - copyWith

    func testCopyWithOverrideTypeOnly() {
        let original = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Cut")
        let copy = original.copyWith(type: .copy)
        XCTAssertEqual(copy.type, .copy)
        XCTAssertEqual(copy.label, "Cut") // unchanged
        XCTAssertNil(copy.onPressed) // unchanged
    }

    func testCopyWithOverrideLabelOnly() {
        let original = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Cut")
        let copy = original.copyWith(label: "New Label")
        XCTAssertEqual(copy.type, .cut) // unchanged
        XCTAssertEqual(copy.label, "New Label")
    }

    func testCopyWithOverrideOnPressedOnly() {
        var called = false
        let original = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Cut")
        let copy = original.copyWith(onPressed: { called = true })
        XCTAssertEqual(copy.type, .cut) // unchanged
        XCTAssertEqual(copy.label, "Cut") // unchanged
        XCTAssertNotNil(copy.onPressed)
        copy.onPressed!()
        XCTAssertTrue(called)
    }

    func testCopyWithOverrideAll() {
        var called = false
        let original = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Cut")
        let copy = original.copyWith(
            onPressed: { called = true },
            type: .paste,
            label: "Paste Here"
        )
        XCTAssertEqual(copy.type, .paste)
        XCTAssertEqual(copy.label, "Paste Here")
        XCTAssertNotNil(copy.onPressed)
        copy.onPressed!()
        XCTAssertTrue(called)
    }

    func testCopyWithNoOverrides() {
        let original = ContextMenuButtonItem(onPressed: nil, type: .selectAll, label: "Select All")
        let copy = original.copyWith()
        XCTAssertEqual(copy, original) // should be equal
        XCTAssertEqual(copy.type, .selectAll)
        XCTAssertEqual(copy.label, "Select All")
    }

    // MARK: - CustomStringConvertible (description)

    func testDescriptionWithLabel() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .cut, label: "Cut")
        XCTAssertEqual(item.description, "ContextMenuButtonItem cut, Cut")
    }

    func testDescriptionWithoutLabel() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .paste)
        XCTAssertEqual(item.description, "ContextMenuButtonItem paste, nil")
    }

    func testDescriptionCustomType() {
        let item = ContextMenuButtonItem(onPressed: nil, type: .custom, label: "Do Something")
        XCTAssertEqual(item.description, "ContextMenuButtonItem custom, Do Something")
    }

    func testDescriptionCustomTypeNoLabel() {
        let item = ContextMenuButtonItem(onPressed: nil)
        XCTAssertEqual(item.description, "ContextMenuButtonItem custom, nil")
    }
}

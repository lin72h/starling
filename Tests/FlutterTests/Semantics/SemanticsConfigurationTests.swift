// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for `SemanticsConfiguration`.
///
/// **Dart Test Source:** `packages/flutter/test/semantics/semantics_test.dart:945-1037`
final class SemanticsConfigurationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CustomSemanticsAction.resetForTests()
    }

    override func tearDown() {
        CustomSemanticsAction.resetForTests()
        super.tearDown()
    }

    // MARK: - Initial State Tests

    /// Test initial state of a new SemanticsConfiguration.
    ///
    /// **Dart Test:** `semantics_test.dart:946-972`
    func testInitialState() {
        let config = SemanticsConfiguration()

        XCTAssertFalse(config.isSemanticBoundary)
        XCTAssertFalse(config.isButton)
        XCTAssertFalse(config.isLink)
        XCTAssertNil(config.isEnabled)
        XCTAssertNil(config.isChecked)
        XCTAssertFalse(config.isSelected)
        XCTAssertFalse(config.isBlockingSemanticsOfPreviouslyPaintedNodes)
        XCTAssertNil(config.isFocused)
        XCTAssertFalse(config.isTextField)
        XCTAssertFalse(config.hasBeenAnnotated)

        XCTAssertNil(config.onShowOnScreen)
        XCTAssertNil(config.onScrollDown)
        XCTAssertNil(config.onScrollUp)
        XCTAssertNil(config.onScrollLeft)
        XCTAssertNil(config.onScrollRight)
        XCTAssertNil(config.onScrollToOffset)
        XCTAssertNil(config.onLongPress)
        XCTAssertNil(config.onDecrease)
        XCTAssertNil(config.onIncrease)
        XCTAssertNil(config.onMoveCursorForwardByCharacter)
        XCTAssertNil(config.onMoveCursorBackwardByCharacter)
        XCTAssertNil(config.onTap)

        XCTAssertEqual(config.label, "")
        XCTAssertEqual(config.value, "")
        XCTAssertEqual(config.hint, "")
        XCTAssertEqual(config.tooltip, "")
        XCTAssertEqual(config.identifier, "")
    }

    // MARK: - Property Setter Tests

    /// Test that setting properties marks the config as annotated and stores the values.
    ///
    /// **Dart Test:** `semantics_test.dart:974-1037`
    func testPropertySettersMarkAsAnnotated() {
        let config = SemanticsConfiguration()
        XCTAssertFalse(config.hasBeenAnnotated)

        config.label = "test label"
        XCTAssertTrue(config.hasBeenAnnotated)
        XCTAssertEqual(config.label, "test label")
        XCTAssertEqual(config.attributedLabel.string, "test label")
    }

    /// Test setting boolean flags.
    func testBooleanFlagSetters() {
        let config = SemanticsConfiguration()

        config.isSemanticBoundary = true
        config.isButton = true
        config.isLink = true
        config.isEnabled = true
        config.isChecked = true
        config.isSelected = true
        config.isBlockingSemanticsOfPreviouslyPaintedNodes = true
        config.isFocused = true
        config.isTextField = true

        XCTAssertTrue(config.isSemanticBoundary)
        XCTAssertTrue(config.isButton)
        XCTAssertTrue(config.isLink)
        XCTAssertEqual(config.isEnabled, true)
        XCTAssertEqual(config.isChecked, true)
        XCTAssertTrue(config.isSelected)
        XCTAssertTrue(config.isBlockingSemanticsOfPreviouslyPaintedNodes)
        XCTAssertEqual(config.isFocused, true)
        XCTAssertTrue(config.isTextField)
    }

    /// Test setting label, value, and hint via string setters.
    ///
    /// **Dart Test:** `semantics_test.dart:70-173`
    func testStringSettersOverrideAttributed() {
        let config = SemanticsConfiguration()

        // Setting label via string
        config.label = "label1"
        XCTAssertEqual(config.label, "label1")
        XCTAssertEqual(config.attributedLabel.string, "label1")
        XCTAssertTrue(config.attributedLabel.attributes.isEmpty)

        // Setting label via attributed string
        config.attributedLabel = Flutter.AttributedString(
            "label2",
            attributes: [
                SpellOutStringAttribute(range: TextRange(start: 0, end: 1))
            ]
        )
        XCTAssertEqual(config.label, "label2")
        XCTAssertEqual(config.attributedLabel.string, "label2")
        XCTAssertEqual(config.attributedLabel.attributes.count, 1)

        // Setting label via string again clears attributes
        config.label = "label3"
        XCTAssertEqual(config.label, "label3")
        XCTAssertTrue(config.attributedLabel.attributes.isEmpty)

        // Same for value
        config.value = "value1"
        XCTAssertEqual(config.value, "value1")
        XCTAssertEqual(config.attributedValue.string, "value1")

        // Same for hint
        config.hint = "hint1"
        XCTAssertEqual(config.hint, "hint1")
        XCTAssertEqual(config.attributedHint.string, "hint1")
    }

    // MARK: - Action Handler Tests

    /// Test that setting action handlers marks as annotated and stores them.
    func testActionHandlerRegistration() {
        let config = SemanticsConfiguration()

        var tapCalled = false
        config.onTap = { tapCalled = true }
        XCTAssertTrue(config.hasBeenAnnotated)
        XCTAssertNotNil(config.onTap)

        // Call the handler
        config.onTap!()
        XCTAssertTrue(tapCalled)
    }

    /// Test multiple action handler setters.
    func testMultipleActionHandlers() {
        let config = SemanticsConfiguration()

        var longPressCalled = false
        var scrollUpCalled = false
        var showOnScreenCalled = false

        config.onLongPress = { longPressCalled = true }
        config.onScrollUp = { scrollUpCalled = true }
        config.onShowOnScreen = { showOnScreenCalled = true }

        XCTAssertNotNil(config.onLongPress)
        XCTAssertNotNil(config.onScrollUp)
        XCTAssertNotNil(config.onShowOnScreen)

        config.onLongPress!()
        config.onScrollUp!()
        config.onShowOnScreen!()

        XCTAssertTrue(longPressCalled)
        XCTAssertTrue(scrollUpCalled)
        XCTAssertTrue(showOnScreenCalled)
    }

    /// Test getActionHandler retrieves registered handlers.
    func testGetActionHandler() {
        let config = SemanticsConfiguration()

        // No handler registered yet
        XCTAssertNil(config.getActionHandler(.tap))

        config.onTap = {}
        XCTAssertNotNil(config.getActionHandler(.tap))
    }

    /// Test scroll action handlers.
    func testScrollActionHandlers() {
        let config = SemanticsConfiguration()

        config.onScrollDown = {}
        config.onScrollLeft = {}
        config.onScrollRight = {}

        XCTAssertNotNil(config.onScrollDown)
        XCTAssertNotNil(config.onScrollLeft)
        XCTAssertNotNil(config.onScrollRight)
        XCTAssertNotNil(config.getActionHandler(.scrollDown))
        XCTAssertNotNil(config.getActionHandler(.scrollLeft))
        XCTAssertNotNil(config.getActionHandler(.scrollRight))
    }

    // MARK: - Custom Semantics Actions Tests

    /// Test custom semantics actions registration.
    func testCustomSemanticsActionsRegistration() {
        let config = SemanticsConfiguration()
        let action1 = CustomSemanticsAction(label: "action1")
        let action2 = CustomSemanticsAction(label: "action2")

        var action1Called = false
        var action2Called = false

        config.customSemanticsActions = [
            action1: { action1Called = true },
            action2: { action2Called = true },
        ]

        XCTAssertTrue(config.hasBeenAnnotated)
        XCTAssertNotNil(config.customSemanticsActions[action1])
        XCTAssertNotNil(config.customSemanticsActions[action2])

        config.customSemanticsActions[action1]!()
        config.customSemanticsActions[action2]!()

        XCTAssertTrue(action1Called)
        XCTAssertTrue(action2Called)
    }

    // MARK: - Sort Key Tests

    /// Test sort key setter.
    func testSortKeySetter() {
        let config = SemanticsConfiguration()
        XCTAssertNil(config.sortKey)
        XCTAssertFalse(config.hasBeenAnnotated)

        config.sortKey = OrdinalSortKey(1.0)
        XCTAssertNotNil(config.sortKey)
        XCTAssertTrue(config.hasBeenAnnotated)
    }

    // MARK: - isCompatibleWith Tests

    /// Test that nil config is always compatible.
    func testIsCompatibleWithNil() {
        let config = SemanticsConfiguration()
        XCTAssertTrue(config.isCompatibleWith(nil))
    }

    /// Test that two unannotated configs are compatible.
    func testIsCompatibleWithUnannotated() {
        let config1 = SemanticsConfiguration()
        let config2 = SemanticsConfiguration()
        XCTAssertTrue(config1.isCompatibleWith(config2))
    }

    /// Test that configs with overlapping actions are incompatible.
    func testIsIncompatibleWithOverlappingActions() {
        let config1 = SemanticsConfiguration()
        config1.onTap = {}

        let config2 = SemanticsConfiguration()
        config2.onTap = {}

        XCTAssertFalse(config1.isCompatibleWith(config2))
    }

    /// Test that configs with non-overlapping actions are compatible.
    func testIsCompatibleWithNonOverlappingActions() {
        let config1 = SemanticsConfiguration()
        config1.onTap = {}

        let config2 = SemanticsConfiguration()
        config2.onLongPress = {}

        XCTAssertTrue(config1.isCompatibleWith(config2))
    }

    /// Test incompatibility with overlapping values.
    func testIsIncompatibleWithOverlappingValues() {
        let config1 = SemanticsConfiguration()
        config1.value = "val1"

        let config2 = SemanticsConfiguration()
        config2.value = "val2"

        XCTAssertFalse(config1.isCompatibleWith(config2))
    }

    // MARK: - copy() Tests

    /// Test that copy creates an independent copy with same values.
    func testCopyCreatesIndependentCopy() {
        let original = SemanticsConfiguration()
        original.label = "original"
        original.value = "v1"
        original.hint = "h1"
        original.tooltip = "tt"
        original.identifier = "id"
        original.isSemanticBoundary = true
        original.isButton = true
        original.textDirection = .ltr
        original.headingLevel = 2
        original.onTap = {}

        let copy = original.copy()

        // Copy should have same values
        XCTAssertEqual(copy.label, "original")
        XCTAssertEqual(copy.value, "v1")
        XCTAssertEqual(copy.hint, "h1")
        XCTAssertEqual(copy.tooltip, "tt")
        XCTAssertEqual(copy.identifier, "id")
        XCTAssertTrue(copy.isSemanticBoundary)
        XCTAssertTrue(copy.isButton)
        XCTAssertEqual(copy.textDirection, .ltr)
        XCTAssertEqual(copy.headingLevel, 2)
        XCTAssertTrue(copy.hasBeenAnnotated)

        // Copy should be independent - modifying copy doesn't affect original
        copy.label = "modified"
        XCTAssertEqual(original.label, "original")
        XCTAssertEqual(copy.label, "modified")
    }

    // MARK: - absorb() Tests

    /// Test that absorb merges child config into parent.
    func testAbsorbMergesChildConfig() {
        let parent = SemanticsConfiguration()
        parent.label = "Parent"
        parent.textDirection = .ltr

        let child = SemanticsConfiguration()
        child.value = "ChildValue"
        child.hint = "ChildHint"
        child.textDirection = .ltr
        child.onTap = {}

        parent.absorb(child)

        // parent should now have child's value and hint
        XCTAssertEqual(parent.value, "ChildValue")
        XCTAssertEqual(parent.hint, "ChildHint")
        XCTAssertTrue(parent.hasBeenAnnotated)
        // Label should still be parent's (concatenated)
        XCTAssertTrue(parent.label.contains("Parent"))
    }

    /// Test that absorb does nothing with unannotated child.
    func testAbsorbDoesNothingWithUnannotatedChild() {
        let parent = SemanticsConfiguration()
        parent.label = "Parent"
        parent.textDirection = .ltr

        let child = SemanticsConfiguration()
        // child has not been annotated

        parent.absorb(child)

        XCTAssertEqual(parent.label, "Parent")
    }

    /// Test that absorb merges actions from child.
    func testAbsorbMergesActions() {
        let parent = SemanticsConfiguration()
        parent.onTap = {}

        let child = SemanticsConfiguration()
        child.onLongPress = {}

        parent.absorb(child)

        XCTAssertNotNil(parent.getActionHandler(.tap))
        XCTAssertNotNil(parent.getActionHandler(.longPress))
    }

    /// Test that absorb takes first non-nil for optional properties.
    func testAbsorbFirstNonNilWins() {
        let parent = SemanticsConfiguration()
        parent.textDirection = .ltr
        parent.scrollPosition = 10.0

        let child = SemanticsConfiguration()
        child.scrollPosition = 20.0

        parent.absorb(child)

        // Parent's scrollPosition should win since it was set first
        XCTAssertEqual(parent.scrollPosition, 10.0)
    }

    /// Test that absorb takes child value when parent value is empty.
    func testAbsorbTakesChildValueWhenParentEmpty() {
        let parent = SemanticsConfiguration()
        parent.textDirection = .ltr

        let child = SemanticsConfiguration()
        child.value = "fromChild"
        child.textDirection = .ltr

        parent.absorb(child)

        XCTAssertEqual(parent.value, "fromChild")
    }

    // MARK: - Tags Tests

    /// Test addTagForChildren and tagsChildrenWith.
    func testTagsForChildren() {
        let config = SemanticsConfiguration()
        let tag = SemanticsTag("testTag")

        XCTAssertFalse(config.tagsChildrenWith(tag))
        XCTAssertNil(config.tagsForChildren)

        config.addTagForChildren(tag)

        XCTAssertTrue(config.tagsChildrenWith(tag))
        XCTAssertNotNil(config.tagsForChildren)
        XCTAssertTrue(config.tagsForChildren!.contains(tag))
    }

    // MARK: - Heading Level Tests

    /// Test heading level setter and getter.
    func testHeadingLevel() {
        let config = SemanticsConfiguration()
        XCTAssertEqual(config.headingLevel, 0)

        config.headingLevel = 3
        XCTAssertEqual(config.headingLevel, 3)
        XCTAssertTrue(config.hasBeenAnnotated)
    }

    // MARK: - Role Tests

    /// Test role setter and getter.
    func testRole() {
        let config = SemanticsConfiguration()
        XCTAssertEqual(config.role, .none)

        config.role = .tab
        XCTAssertEqual(config.role, .tab)
        XCTAssertTrue(config.hasBeenAnnotated)
    }

    // MARK: - Validation and Input Type Tests

    /// Test validationResult setter and getter.
    func testValidationResult() {
        let config = SemanticsConfiguration()
        XCTAssertEqual(config.validationResult, .none)

        config.validationResult = .valid
        XCTAssertEqual(config.validationResult, .valid)
        XCTAssertTrue(config.hasBeenAnnotated)
    }

    /// Test inputType setter and getter.
    func testInputType() {
        let config = SemanticsConfiguration()
        XCTAssertEqual(config.inputType, .none)

        config.inputType = .text
        XCTAssertEqual(config.inputType, .text)
        XCTAssertTrue(config.hasBeenAnnotated)
    }

    // MARK: - Index in Parent Tests

    /// Test indexInParent setter.
    func testIndexInParent() {
        let config = SemanticsConfiguration()
        XCTAssertNil(config.indexInParent)

        config.indexInParent = 5
        XCTAssertEqual(config.indexInParent, 5)
        XCTAssertTrue(config.hasBeenAnnotated)
    }

    // MARK: - Scroll Properties Tests

    /// Test scroll property setters.
    func testScrollProperties() {
        let config = SemanticsConfiguration()

        config.scrollChildCount = 10
        XCTAssertEqual(config.scrollChildCount, 10)

        config.scrollIndex = 3
        XCTAssertEqual(config.scrollIndex, 3)

        config.scrollPosition = 100.0
        XCTAssertEqual(config.scrollPosition, 100.0)

        config.scrollExtentMax = 500.0
        XCTAssertEqual(config.scrollExtentMax, 500.0)

        config.scrollExtentMin = 0.0
        XCTAssertEqual(config.scrollExtentMin, 0.0)
    }
}

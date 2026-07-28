// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for WidgetState enum, constraint operators, WidgetStateProperty,
/// WidgetStateMapper, WidgetStatePropertyAll, and WidgetStatesController.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/widget_state_test.dart`
final class WidgetStateTests: XCTestCase {

    // MARK: - WidgetState enum values

    func testWidgetStateEnumCases() {
        // Verify all 8 enum cases exist and are distinct
        let allStates: Set<WidgetState> = [
            .hovered, .focused, .pressed, .dragged,
            .selected, .scrolledUnder, .disabled, .error,
        ]
        XCTAssertEqual(allStates.count, 8, "Should have 8 distinct WidgetState cases")
    }

    func testWidgetStateHashable() {
        // Same values should be equal
        XCTAssertEqual(WidgetState.hovered, WidgetState.hovered)
        XCTAssertEqual(WidgetState.disabled, WidgetState.disabled)

        // Different values should not be equal
        XCTAssertNotEqual(WidgetState.hovered, WidgetState.focused)
        XCTAssertNotEqual(WidgetState.pressed, WidgetState.disabled)
    }

    func testWidgetStateCanBeUsedInSet() {
        var states: Set<WidgetState> = []
        states.insert(.hovered)
        states.insert(.focused)
        states.insert(.hovered) // duplicate
        XCTAssertEqual(states.count, 2)
        XCTAssertTrue(states.contains(.hovered))
        XCTAssertTrue(states.contains(.focused))
        XCTAssertFalse(states.contains(.pressed))
    }

    // MARK: - WidgetState.isSatisfiedBy

    func testWidgetStateIsSatisfiedByContainingSet() {
        let states: Set<WidgetState> = [.hovered, .focused]
        XCTAssertTrue(WidgetState.hovered.isSatisfiedBy(states))
        XCTAssertTrue(WidgetState.focused.isSatisfiedBy(states))
    }

    func testWidgetStateIsNotSatisfiedByNonContainingSet() {
        let states: Set<WidgetState> = [.hovered]
        XCTAssertFalse(WidgetState.focused.isSatisfiedBy(states))
        XCTAssertFalse(WidgetState.pressed.isSatisfiedBy(states))
    }

    func testWidgetStateIsNotSatisfiedByEmptySet() {
        let states: Set<WidgetState> = []
        XCTAssertFalse(WidgetState.hovered.isSatisfiedBy(states))
        XCTAssertFalse(WidgetState.disabled.isSatisfiedBy(states))
    }

    // MARK: - WidgetState.any

    func testWidgetStateAnySatisfiedByEmptySet() {
        XCTAssertTrue(WidgetState.any.isSatisfiedBy([]))
    }

    func testWidgetStateAnySatisfiedByAnySet() {
        XCTAssertTrue(WidgetState.any.isSatisfiedBy([.hovered]))
        XCTAssertTrue(WidgetState.any.isSatisfiedBy([.disabled, .error]))
        XCTAssertTrue(WidgetState.any.isSatisfiedBy([.hovered, .focused, .pressed]))
    }

    // MARK: - Constraint operator &

    func testAndOperatorBothSatisfied() {
        let constraint = WidgetState.hovered & WidgetState.focused
        XCTAssertTrue(constraint.isSatisfiedBy([.hovered, .focused]))
        XCTAssertTrue(constraint.isSatisfiedBy([.hovered, .focused, .pressed]))
    }

    func testAndOperatorOnlyOneSatisfied() {
        let constraint = WidgetState.hovered & WidgetState.focused
        XCTAssertFalse(constraint.isSatisfiedBy([.hovered]))
        XCTAssertFalse(constraint.isSatisfiedBy([.focused]))
    }

    func testAndOperatorNoneSatisfied() {
        let constraint = WidgetState.hovered & WidgetState.focused
        XCTAssertFalse(constraint.isSatisfiedBy([.pressed]))
        XCTAssertFalse(constraint.isSatisfiedBy([]))
    }

    // MARK: - Constraint operator |

    func testOrOperatorBothSatisfied() {
        let constraint = WidgetState.hovered | WidgetState.focused
        XCTAssertTrue(constraint.isSatisfiedBy([.hovered, .focused]))
    }

    func testOrOperatorOneSatisfied() {
        let constraint = WidgetState.hovered | WidgetState.focused
        XCTAssertTrue(constraint.isSatisfiedBy([.hovered]))
        XCTAssertTrue(constraint.isSatisfiedBy([.focused]))
    }

    func testOrOperatorNoneSatisfied() {
        let constraint = WidgetState.hovered | WidgetState.focused
        XCTAssertFalse(constraint.isSatisfiedBy([.pressed]))
        XCTAssertFalse(constraint.isSatisfiedBy([]))
    }

    // MARK: - Constraint operator ~ (NOT)

    func testNotOperatorSatisfiedWhenStateAbsent() {
        let constraint = ~WidgetState.disabled
        XCTAssertTrue(constraint.isSatisfiedBy([]))
        XCTAssertTrue(constraint.isSatisfiedBy([.hovered]))
        XCTAssertTrue(constraint.isSatisfiedBy([.focused, .pressed]))
    }

    func testNotOperatorNotSatisfiedWhenStatePresent() {
        let constraint = ~WidgetState.disabled
        XCTAssertFalse(constraint.isSatisfiedBy([.disabled]))
        XCTAssertFalse(constraint.isSatisfiedBy([.hovered, .disabled]))
    }

    // MARK: - Complex constraint combinations

    func testComplexConstraintAndOr() {
        // (hovered & focused) | pressed
        let constraint = (WidgetState.hovered & WidgetState.focused) | WidgetState.pressed
        XCTAssertTrue(constraint.isSatisfiedBy([.hovered, .focused]))
        XCTAssertTrue(constraint.isSatisfiedBy([.pressed]))
        XCTAssertFalse(constraint.isSatisfiedBy([.hovered]))
        XCTAssertFalse(constraint.isSatisfiedBy([.focused]))
        XCTAssertFalse(constraint.isSatisfiedBy([]))
    }

    func testComplexConstraintNotAnd() {
        // ~disabled & hovered
        let constraint = ~WidgetState.disabled & WidgetState.hovered
        XCTAssertTrue(constraint.isSatisfiedBy([.hovered]))
        XCTAssertTrue(constraint.isSatisfiedBy([.hovered, .focused]))
        XCTAssertFalse(constraint.isSatisfiedBy([.hovered, .disabled]))
        XCTAssertFalse(constraint.isSatisfiedBy([.disabled]))
        XCTAssertFalse(constraint.isSatisfiedBy([]))
    }

    // MARK: - Constraint description

    func testWidgetStateDescription() {
        let desc = WidgetState.hovered.description
        XCTAssertTrue(desc.contains("hovered"), "Description should contain the case name")
    }

    func testAnyConstraintDescription() {
        let desc = WidgetState.any.description
        XCTAssertEqual(desc, "WidgetState.any")
    }

    // MARK: - WidgetStatePropertyHelper.resolveWith

    func testResolveWithReturnsCallbackResult() {
        let property = WidgetStatePropertyHelper.resolveWith { (states: Set<WidgetState>) -> String in
            if states.contains(.disabled) { return "disabled" }
            if states.contains(.hovered) { return "hovered" }
            return "default"
        }
        XCTAssertEqual(property.resolve([.disabled]), "disabled")
        XCTAssertEqual(property.resolve([.hovered]), "hovered")
        XCTAssertEqual(property.resolve([]), "default")
        XCTAssertEqual(property.resolve([.focused]), "default")
    }

    func testResolveWithMultipleStates() {
        let property = WidgetStatePropertyHelper.resolveWith { (states: Set<WidgetState>) -> Int in
            if states.contains(.pressed) && states.contains(.hovered) { return 3 }
            if states.contains(.pressed) { return 2 }
            if states.contains(.hovered) { return 1 }
            return 0
        }
        XCTAssertEqual(property.resolve([.pressed, .hovered]), 3)
        XCTAssertEqual(property.resolve([.pressed]), 2)
        XCTAssertEqual(property.resolve([.hovered]), 1)
        XCTAssertEqual(property.resolve([]), 0)
    }

    // MARK: - WidgetStatePropertyAll

    func testPropertyAllReturnsConstantValue() {
        let property = WidgetStatePropertyAll(42)
        XCTAssertEqual(property.resolve([]), 42)
        XCTAssertEqual(property.resolve([.hovered]), 42)
        XCTAssertEqual(property.resolve([.disabled, .error]), 42)
    }

    func testPropertyAllWithStringValue() {
        let property = WidgetStatePropertyAll("hello")
        XCTAssertEqual(property.resolve([]), "hello")
        XCTAssertEqual(property.resolve([.pressed]), "hello")
    }

    func testPropertyAllDescription() {
        let property = WidgetStatePropertyAll("test")
        XCTAssertTrue(property.description.contains("WidgetStatePropertyAll"))
        XCTAssertTrue(property.description.contains("test"))
    }

    func testPropertyAllDescriptionWithDouble() {
        let property = WidgetStatePropertyAll(3.14)
        let desc = property.description
        XCTAssertTrue(desc.contains("WidgetStatePropertyAll"))
    }

    func testPropertyAllViaHelper() {
        let property = WidgetStatePropertyHelper.all(99)
        XCTAssertEqual(property.resolve([]), 99)
        XCTAssertEqual(property.resolve([.focused]), 99)
    }

    // MARK: - WidgetStateMapper

    func testMapperResolvesFirstMatch() {
        let mapper = WidgetStateMapper<String>([
            (constraint: WidgetState.error, value: "error"),
            (constraint: WidgetState.disabled, value: "disabled"),
            (constraint: WidgetState.any, value: "default"),
        ])
        XCTAssertEqual(mapper.resolve([.error]), "error")
        XCTAssertEqual(mapper.resolve([.disabled]), "disabled")
        XCTAssertEqual(mapper.resolve([]), "default")
    }

    func testMapperResolvesFirstMatchPriority() {
        // When multiple constraints match, the first one wins
        let mapper = WidgetStateMapper<String>([
            (constraint: WidgetState.error, value: "error"),
            (constraint: WidgetState.hovered, value: "hovered"),
            (constraint: WidgetState.any, value: "default"),
        ])
        // Both error and hovered are present, error comes first
        XCTAssertEqual(mapper.resolve([.error, .hovered]), "error")
    }

    func testMapperWithCombinedConstraints() {
        let mapper = WidgetStateMapper<String>([
            (constraint: WidgetState.hovered & WidgetState.focused, value: "hover+focus"),
            (constraint: WidgetState.hovered, value: "hover"),
            (constraint: WidgetState.any, value: "default"),
        ])
        XCTAssertEqual(mapper.resolve([.hovered, .focused]), "hover+focus")
        XCTAssertEqual(mapper.resolve([.hovered]), "hover")
        XCTAssertEqual(mapper.resolve([.pressed]), "default")
    }

    func testMapperWithNotConstraint() {
        let mapper = WidgetStateMapper<String>([
            (constraint: WidgetState.disabled, value: "disabled"),
            (constraint: ~WidgetState.disabled, value: "enabled"),
        ])
        XCTAssertEqual(mapper.resolve([.disabled]), "disabled")
        XCTAssertEqual(mapper.resolve([.hovered]), "enabled")
        XCTAssertEqual(mapper.resolve([]), "enabled")
    }

    func testMapperDescription() {
        let mapper = WidgetStateMapper<Int>([
            (constraint: WidgetState.any, value: 42),
        ])
        XCTAssertTrue(mapper.description.contains("WidgetStateMapper"))
    }

    // MARK: - WidgetStatesController

    func testControllerInitializesWithEmptySet() {
        let controller = WidgetStatesController()
        XCTAssertTrue(controller.value.isEmpty)
    }

    func testControllerInitializesWithProvidedStates() {
        let controller = WidgetStatesController([.hovered, .focused])
        XCTAssertEqual(controller.value, [.hovered, .focused])
    }

    func testControllerUpdateAddsState() {
        let controller = WidgetStatesController()
        controller.update(.hovered, true)
        XCTAssertTrue(controller.value.contains(.hovered))
    }

    func testControllerUpdateRemovesState() {
        let controller = WidgetStatesController([.hovered, .focused])
        controller.update(.hovered, false)
        XCTAssertFalse(controller.value.contains(.hovered))
        XCTAssertTrue(controller.value.contains(.focused))
    }

    func testControllerUpdateNotifiesOnAdd() {
        let controller = WidgetStatesController()
        var notified = false
        controller.addListener { notified = true }

        controller.update(.hovered, true)
        XCTAssertTrue(notified)
    }

    func testControllerUpdateNotifiesOnRemove() {
        let controller = WidgetStatesController([.hovered])
        var notified = false
        controller.addListener { notified = true }

        controller.update(.hovered, false)
        XCTAssertTrue(notified)
    }

    func testControllerUpdateDoesNotNotifyIfAlreadyPresent() {
        let controller = WidgetStatesController([.hovered])
        var notifyCount = 0
        controller.addListener { notifyCount += 1 }

        controller.update(.hovered, true) // already present
        XCTAssertEqual(notifyCount, 0, "Should not notify when state is already present")
    }

    func testControllerUpdateDoesNotNotifyIfAlreadyAbsent() {
        let controller = WidgetStatesController()
        var notifyCount = 0
        controller.addListener { notifyCount += 1 }

        controller.update(.hovered, false) // already absent
        XCTAssertEqual(notifyCount, 0, "Should not notify when state is already absent")
    }

    func testControllerMultipleUpdates() {
        let controller = WidgetStatesController()

        controller.update(.hovered, true)
        controller.update(.focused, true)
        controller.update(.pressed, true)
        XCTAssertEqual(controller.value, [.hovered, .focused, .pressed])

        controller.update(.focused, false)
        XCTAssertEqual(controller.value, [.hovered, .pressed])

        controller.update(.hovered, false)
        controller.update(.pressed, false)
        XCTAssertEqual(controller.value, Set<WidgetState>())
    }
}

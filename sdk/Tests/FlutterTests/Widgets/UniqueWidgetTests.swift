// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for UniqueWidget.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/unique_widget_test.dart`
final class UniqueWidgetTests: XCTestCase {

    // MARK: - Test Helpers

    private class TestState: State<StatefulWidget> {}

    private class ConcreteUniqueWidget: UniqueWidget<TestState> {
        override func createState() -> State<StatefulWidget> {
            return TestState()
        }
    }

    /// A GlobalKey subclass that can return a state for testing.
    private class MockGlobalKey: GlobalKey<TestState> {
        var mockState: TestState?
        override var currentState: TestState? { return mockState }
    }

    // MARK: - Constructor Tests

    func testConstructorStoresGlobalKey() {
        let key = GlobalKey<TestState>()
        let widget = ConcreteUniqueWidget(key: key)
        XCTAssertNotNil(widget)
        XCTAssertTrue(widget.key is GlobalKey<TestState>)
    }

    // MARK: - Key Accessibility Tests

    func testKeyIsAccessible() {
        let key = GlobalKey<TestState>()
        let widget = ConcreteUniqueWidget(key: key)
        // The key passed in should be the same object accessible via widget.key
        XCTAssertTrue(widget.key as AnyObject === key)
    }

    // MARK: - currentState Tests

    func testCurrentStateWithStubGlobalKeyReturnsNil() {
        let key = GlobalKey<TestState>()
        let widget = ConcreteUniqueWidget(key: key)
        // Default GlobalKey.currentState returns nil
        XCTAssertNil(widget.currentState)
    }

    func testCurrentStateWithMockGlobalKeyReturnsMockState() {
        let mockKey = MockGlobalKey()
        let testState = TestState()
        mockKey.mockState = testState
        let widget = ConcreteUniqueWidget(key: mockKey)
        // Should return the mock state via the mock key
        XCTAssertTrue(widget.currentState === testState)
    }

    // MARK: - Inheritance Tests

    func testUniqueWidgetIsStatefulWidget() {
        let key = GlobalKey<TestState>()
        let widget = ConcreteUniqueWidget(key: key)
        XCTAssertTrue(widget is StatefulWidget)
    }

    func testUniqueWidgetIsWidget() {
        let key = GlobalKey<TestState>()
        let widget = ConcreteUniqueWidget(key: key)
        XCTAssertTrue(widget is Widget)
    }

    // MARK: - createState Tests

    func testSubclassCreateStateReturnsTestState() {
        let key = GlobalKey<TestState>()
        let widget = ConcreteUniqueWidget(key: key)
        let state = widget.createState()
        XCTAssertTrue(state is TestState)
    }

    // MARK: - Key Identity Tests

    func testGlobalKeyUsesIdentityEquality() {
        let key1 = GlobalKey<TestState>()
        let key2 = GlobalKey<TestState>()
        // Two different GlobalKey instances should not be equal
        XCTAssertNotEqual(key1, key2)
        // A GlobalKey should be equal to itself
        XCTAssertEqual(key1, key1)
    }
}

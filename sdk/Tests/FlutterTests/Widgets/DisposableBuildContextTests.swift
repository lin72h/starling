// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for DisposableBuildContext.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/disposable_build_context_test.dart`
final class DisposableBuildContextTests: XCTestCase {

    // MARK: - Test Helpers

    private class TestStatefulWidget: StatefulWidget {
        override func createState() -> State<StatefulWidget> {
            return TestState()
        }
    }

    private class TestState: State<StatefulWidget> {}

    /// A minimal BuildContext implementation for testing.
    private class MockElement: Element {
        init() {
            super.init(TestStatefulWidget())
        }
    }

    /// Creates a TestState with mounted set to the given value.
    private func makeState(mounted: Bool, context: (any BuildContext)? = nil) -> TestState {
        let state = TestState()
        state.mounted = mounted
        state.context = context
        return state
    }

    // MARK: - Constructor Tests

    func testConstructorWithMountedState() {
        let state = makeState(mounted: true)
        // Should not crash when creating with a mounted state
        let dbc = DisposableBuildContext(state)
        XCTAssertNotNil(dbc)
    }

    // MARK: - context property Tests

    func testContextBeforeDispose() {
        let state = makeState(mounted: true)
        let dbc = DisposableBuildContext(state)

        // context is nil because no BuildContext was set on the state
        let ctx = dbc.context
        XCTAssertNil(ctx)
    }

    func testContextWithActualBuildContext() {
        let mockElement = MockElement()
        let state = makeState(mounted: true, context: mockElement)
        let dbc = DisposableBuildContext(state)

        // Should return the mock element as the context
        let ctx = dbc.context
        XCTAssertTrue(ctx === mockElement)
    }

    func testContextAfterDispose() {
        let mockElement = MockElement()
        let state = makeState(mounted: true, context: mockElement)
        let dbc = DisposableBuildContext(state)

        dbc.dispose()

        // After dispose, context should be nil
        XCTAssertNil(dbc.context)
    }

    // MARK: - dispose Tests

    func testDisposeSetsContextToNil() {
        let state = makeState(mounted: true)
        let dbc = DisposableBuildContext(state)

        dbc.dispose()

        XCTAssertNil(dbc.context)
    }

    func testDisposeIsIdempotent() {
        let state = makeState(mounted: true)
        let dbc = DisposableBuildContext(state)

        // Calling dispose multiple times should not crash
        dbc.dispose()
        dbc.dispose()
        dbc.dispose()

        XCTAssertNil(dbc.context)
    }

    // MARK: - Multiple instances

    func testMultipleDisposableBuildContextsWithSameState() {
        let mockElement = MockElement()
        let state = makeState(mounted: true, context: mockElement)

        let dbc1 = DisposableBuildContext(state)
        let dbc2 = DisposableBuildContext(state)

        // Both should return the same context
        XCTAssertTrue(dbc1.context === mockElement)
        XCTAssertTrue(dbc2.context === mockElement)

        // Disposing one should not affect the other
        dbc1.dispose()
        XCTAssertNil(dbc1.context)
        XCTAssertTrue(dbc2.context === mockElement)
    }
}

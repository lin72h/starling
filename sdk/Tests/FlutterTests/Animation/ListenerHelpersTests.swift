// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
@testable import FlutterSwiftBridge

/// Tests for listener helper classes migrated from listener_helpers.dart.
///
/// **Dart Test Source:** `packages/flutter/test/animation/listener_helpers_test.dart`
final class ListenerHelpersTests: XCTestCase {

    // MARK: - AnimationLazyListenerMixin Tests

    /// Test that isListening is false initially.
    func testLazyListenerInitiallyNotListening() {
        let mixin = TestLazyListener()
        XCTAssertFalse(mixin.isListening)
    }

    /// Test that didStartListening is called when first listener registers.
    func testLazyListenerStartsListeningOnFirstRegister() {
        let mixin = TestLazyListener()
        mixin.didRegisterListener()
        XCTAssertTrue(mixin.isListening)
        XCTAssertEqual(mixin.startListeningCount, 1)
    }

    /// Test that didStartListening is NOT called on subsequent registrations.
    func testLazyListenerNoDoubleStart() {
        let mixin = TestLazyListener()
        mixin.didRegisterListener()
        mixin.didRegisterListener()
        XCTAssertTrue(mixin.isListening)
        XCTAssertEqual(mixin.startListeningCount, 1)
    }

    /// Test that didStopListening is called when last listener unregisters.
    func testLazyListenerStopsListeningOnLastUnregister() {
        let mixin = TestLazyListener()
        mixin.didRegisterListener()
        mixin.didRegisterListener()
        mixin.didUnregisterListener()
        XCTAssertTrue(mixin.isListening)
        XCTAssertEqual(mixin.stopListeningCount, 0)

        mixin.didUnregisterListener()
        XCTAssertFalse(mixin.isListening)
        XCTAssertEqual(mixin.stopListeningCount, 1)
    }

    /// Test that re-registering after all removed calls didStartListening again.
    func testLazyListenerRestartsAfterAllRemoved() {
        let mixin = TestLazyListener()
        mixin.didRegisterListener()
        mixin.didUnregisterListener()
        XCTAssertEqual(mixin.startListeningCount, 1)
        XCTAssertEqual(mixin.stopListeningCount, 1)

        mixin.didRegisterListener()
        XCTAssertEqual(mixin.startListeningCount, 2)
        XCTAssertTrue(mixin.isListening)
    }

    // MARK: - AnimationEagerListenerMixin Tests

    /// Test that didRegisterListener and didUnregisterListener are no-ops.
    func testEagerListenerNoOps() {
        let mixin = AnimationEagerListenerMixin()
        // Should not crash
        mixin.didRegisterListener()
        mixin.didUnregisterListener()
    }

    /// Test that dispose can be called.
    func testEagerListenerDispose() {
        let mixin = AnimationEagerListenerMixin()
        // Should not crash
        mixin.dispose()
    }

    // MARK: - AnimationLocalListenersMixin Tests

    /// Test addListener and notifyListeners.
    func testLocalListenersAddAndNotify() {
        let mixin = TestLocalListeners()
        var called = false
        mixin.addListener { called = true }
        mixin.notifyListeners()
        XCTAssertTrue(called)
    }

    /// Test that multiple listeners are all called.
    func testLocalListenersMultipleListeners() {
        let mixin = TestLocalListeners()
        var count = 0
        mixin.addListener { count += 1 }
        mixin.addListener { count += 1 }
        mixin.addListener { count += 1 }
        mixin.notifyListeners()
        XCTAssertEqual(count, 3)
    }

    /// Test removeListener removes a listener.
    func testLocalListenersRemove() {
        let mixin = TestLocalListeners()
        var count = 0
        let listener: VoidCallback = { count += 1 }
        mixin.addListener(listener)
        mixin.addListener { count += 10 }
        mixin.removeListener(listener)
        mixin.notifyListeners()
        // After removing the last-added listener (the count += 10 one),
        // only the first listener remains
        XCTAssertEqual(count, 1)
    }

    /// Test that didRegisterListener is called on add.
    func testLocalListenersRegisterCallback() {
        let mixin = TestLocalListeners()
        XCTAssertEqual(mixin.registerCount, 0)
        mixin.addListener {}
        XCTAssertEqual(mixin.registerCount, 1)
        mixin.addListener {}
        XCTAssertEqual(mixin.registerCount, 2)
    }

    /// Test that didUnregisterListener is called on remove.
    func testLocalListenersUnregisterCallback() {
        let mixin = TestLocalListeners()
        mixin.addListener {}
        XCTAssertEqual(mixin.unregisterCount, 0)
        mixin.removeListener {}
        XCTAssertEqual(mixin.unregisterCount, 1)
    }

    /// Test clearListeners removes all without triggering unregister.
    func testLocalListenersClear() {
        let mixin = TestLocalListeners()
        mixin.addListener {}
        mixin.addListener {}
        mixin.clearListeners()

        var called = false
        mixin.notifyListeners()
        XCTAssertFalse(called)
        // clearListeners should NOT call didUnregisterListener
        XCTAssertEqual(mixin.unregisterCount, 0)
    }

    /// Test that notifyListeners uses snapshot (safe for concurrent modification).
    func testLocalListenersSnapshotOnIterate() {
        let mixin = TestLocalListeners()
        var callOrder: [Int] = []
        mixin.addListener {
            callOrder.append(1)
            // Adding during iteration should not affect current iteration
            mixin.addListener { callOrder.append(99) }
        }
        mixin.addListener { callOrder.append(2) }
        mixin.notifyListeners()
        // Should only call the original 2 listeners, not the newly added one
        XCTAssertEqual(callOrder, [1, 2])
    }

    /// Test notifyListeners with no listeners does nothing.
    func testLocalListenersNotifyEmpty() {
        let mixin = TestLocalListeners()
        // Should not crash
        mixin.notifyListeners()
    }

    // MARK: - AnimationLocalStatusListenersMixin Tests

    /// Test addStatusListener and notifyStatusListeners.
    func testStatusListenersAddAndNotify() {
        let mixin = TestStatusListeners()
        var receivedStatus: AnimationStatus?
        mixin.addStatusListener { status in receivedStatus = status }
        mixin.notifyStatusListeners(.forward)
        XCTAssertEqual(receivedStatus, .forward)
    }

    /// Test that multiple status listeners are all called.
    func testStatusListenersMultipleListeners() {
        let mixin = TestStatusListeners()
        var count = 0
        mixin.addStatusListener { _ in count += 1 }
        mixin.addStatusListener { _ in count += 1 }
        mixin.notifyStatusListeners(.completed)
        XCTAssertEqual(count, 2)
    }

    /// Test that correct status value is passed to each listener.
    func testStatusListenersPassesCorrectStatus() {
        let mixin = TestStatusListeners()
        var statuses: [AnimationStatus] = []
        mixin.addStatusListener { status in statuses.append(status) }

        mixin.notifyStatusListeners(.dismissed)
        mixin.notifyStatusListeners(.forward)
        mixin.notifyStatusListeners(.reverse)
        mixin.notifyStatusListeners(.completed)

        XCTAssertEqual(statuses, [.dismissed, .forward, .reverse, .completed])
    }

    /// Test removeStatusListener removes a listener.
    func testStatusListenersRemove() {
        let mixin = TestStatusListeners()
        var count = 0
        mixin.addStatusListener { _ in count += 1 }
        mixin.removeStatusListener { _ in }
        mixin.notifyStatusListeners(.forward)
        XCTAssertEqual(count, 0)
    }

    /// Test clearStatusListeners removes all.
    func testStatusListenersClear() {
        let mixin = TestStatusListeners()
        var count = 0
        mixin.addStatusListener { _ in count += 1 }
        mixin.addStatusListener { _ in count += 1 }
        mixin.clearStatusListeners()
        mixin.notifyStatusListeners(.forward)
        XCTAssertEqual(count, 0)
        XCTAssertEqual(mixin.unregisterCount, 0)
    }

    /// Test that didRegisterListener is called on addStatusListener.
    func testStatusListenersRegisterCallback() {
        let mixin = TestStatusListeners()
        mixin.addStatusListener { _ in }
        XCTAssertEqual(mixin.registerCount, 1)
    }

    /// Test notifyStatusListeners with no listeners does nothing.
    func testStatusListenersNotifyEmpty() {
        let mixin = TestStatusListeners()
        // Should not crash
        mixin.notifyStatusListeners(.completed)
    }

    /// Test snapshot-on-iterate for status listeners.
    func testStatusListenersSnapshotOnIterate() {
        let mixin = TestStatusListeners()
        var callOrder: [Int] = []
        mixin.addStatusListener { _ in
            callOrder.append(1)
            mixin.addStatusListener { _ in callOrder.append(99) }
        }
        mixin.addStatusListener { _ in callOrder.append(2) }
        mixin.notifyStatusListeners(.forward)
        XCTAssertEqual(callOrder, [1, 2])
    }
}

// MARK: - Test Helpers

/// Concrete subclass of AnimationLazyListenerMixin for testing.
private class TestLazyListener: AnimationLazyListenerMixin {
    var startListeningCount = 0
    var stopListeningCount = 0

    override func didStartListening() {
        startListeningCount += 1
    }

    override func didStopListening() {
        stopListeningCount += 1
    }
}

/// Concrete subclass of AnimationLocalListenersMixin for testing.
private class TestLocalListeners: AnimationLocalListenersMixin {
    var registerCount = 0
    var unregisterCount = 0

    override func didRegisterListener() {
        registerCount += 1
    }

    override func didUnregisterListener() {
        unregisterCount += 1
    }
}

/// Concrete subclass of AnimationLocalStatusListenersMixin for testing.
private class TestStatusListeners: AnimationLocalStatusListenersMixin {
    var registerCount = 0
    var unregisterCount = 0

    override func didRegisterListener() {
        registerCount += 1
    }

    override func didUnregisterListener() {
        unregisterCount += 1
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

// Use a typealias to disambiguate Flutter.Notification from Foundation.Notification
private typealias FlutterNotification = Flutter.Notification

/// Tests for Notification, NotificationListener, NotificationElement,
/// and LayoutChangedNotification.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/notification_listener_test.dart`
final class NotificationListenerTests: XCTestCase {

    // MARK: - Test Helpers

    private class TestNotification: FlutterNotification {
        let value: Int
        init(value: Int) {
            self.value = value
            super.init()
        }
        override func debugFillDescription(_ description: inout [String]) {
            super.debugFillDescription(&description)
            description.append("value: \(value)")
        }
    }

    private class OtherNotification: FlutterNotification {}

    /// A minimal child widget for constructing NotificationListener instances.
    private class DummyWidget: Widget {
        init() { super.init(key: nil) }
        override func createElement() -> Element {
            return Element(self)
        }
    }

    // MARK: - Notification Base Class

    func testNotificationInit() {
        let notification = FlutterNotification()
        XCTAssertNotNil(notification)
    }

    func testNotificationDescriptionFormat() {
        let notification = FlutterNotification()
        let desc = notification.description
        // In debug mode, objectRuntimeType returns the actual type name
        XCTAssertTrue(desc.contains("Notification"))
        XCTAssertTrue(desc.contains("("))
        XCTAssertTrue(desc.contains(")"))
    }

    func testNotificationDescriptionEmptyParts() {
        let notification = FlutterNotification()
        let desc = notification.description
        // Base Notification has no debug info, so parts are empty
        XCTAssertTrue(desc.hasSuffix("()"))
    }

    // MARK: - Notification Subclass with debugFillDescription

    func testNotificationSubclassDebugFillDescription() {
        let notification = TestNotification(value: 42)
        var parts: [String] = []
        notification.debugFillDescription(&parts)
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0], "value: 42")
    }

    func testNotificationSubclassDescription() {
        let notification = TestNotification(value: 99)
        let desc = notification.description
        XCTAssertTrue(desc.contains("TestNotification"))
        XCTAssertTrue(desc.contains("value: 99"))
    }

    // MARK: - LayoutChangedNotification

    func testLayoutChangedNotificationIsNotification() {
        let notification = LayoutChangedNotification()
        XCTAssertTrue(notification is FlutterNotification)
    }

    func testLayoutChangedNotificationDescription() {
        let notification = LayoutChangedNotification()
        let desc = notification.description
        XCTAssertTrue(desc.contains("LayoutChangedNotification"))
    }

    // MARK: - NotificationListener Constructor

    func testNotificationListenerStoresChild() {
        let child = DummyWidget()
        let listener = NotificationListener<TestNotification>(child: child)
        XCTAssertTrue(listener.child === child)
    }

    func testNotificationListenerStoresCallback() {
        let child = DummyWidget()
        let listener = NotificationListener<TestNotification>(
            child: child,
            onNotification: { _ in return true }
        )
        XCTAssertNotNil(listener.onNotification)
    }

    func testNotificationListenerNilCallback() {
        let child = DummyWidget()
        let listener = NotificationListener<TestNotification>(child: child)
        XCTAssertNil(listener.onNotification)
    }

    // MARK: - NotificationListener createElement

    func testNotificationListenerCreateElement() {
        let child = DummyWidget()
        let listener = NotificationListener<TestNotification>(child: child)
        let element = listener.createElement()
        XCTAssertTrue(element is NotificationElement<TestNotification>)
    }

    // MARK: - NotificationElement.onNotification - Matching Type

    func testNotificationElementOnNotificationMatchingType() {
        var receivedValue: Int?
        let child = DummyWidget()
        let listener = NotificationListener<TestNotification>(
            child: child,
            onNotification: { notification in
                receivedValue = notification.value
                return true
            }
        )
        let element = listener.createElement() as! NotificationElement<TestNotification>
        let notification = TestNotification(value: 7)
        let result = element.onNotification(notification)
        XCTAssertTrue(result)
        XCTAssertEqual(receivedValue, 7)
    }

    func testNotificationElementOnNotificationReturnsFalse() {
        let child = DummyWidget()
        let listener = NotificationListener<TestNotification>(
            child: child,
            onNotification: { _ in return false }
        )
        let element = listener.createElement() as! NotificationElement<TestNotification>
        let notification = TestNotification(value: 1)
        let result = element.onNotification(notification)
        XCTAssertFalse(result)
    }

    // MARK: - NotificationElement.onNotification - Non-Matching Type

    func testNotificationElementOnNotificationNonMatchingType() {
        var callbackCalled = false
        let child = DummyWidget()
        let listener = NotificationListener<TestNotification>(
            child: child,
            onNotification: { _ in
                callbackCalled = true
                return true
            }
        )
        let element = listener.createElement() as! NotificationElement<TestNotification>
        let otherNotification = OtherNotification()
        let result = element.onNotification(otherNotification)
        XCTAssertFalse(result)
        XCTAssertFalse(callbackCalled)
    }

    // MARK: - NotificationElement.onNotification - Nil Callback

    func testNotificationElementOnNotificationNilCallback() {
        let child = DummyWidget()
        let listener = NotificationListener<TestNotification>(child: child)
        let element = listener.createElement() as! NotificationElement<TestNotification>
        let notification = TestNotification(value: 5)
        let result = element.onNotification(notification)
        XCTAssertFalse(result)
    }

    // MARK: - NotificationElement.notifyClients

    func testNotificationElementNotifyClientsDoesNotCrash() {
        let child = DummyWidget()
        let listener = NotificationListener<TestNotification>(child: child)
        let element = listener.createElement() as! NotificationElement<TestNotification>
        // notifyClients is a no-op; just verify it doesn't crash
        let oldWidget = NotificationListener<TestNotification>(child: child)
        element.notifyClients(oldWidget)
    }
}

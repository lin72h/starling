// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

// Use a typealias to disambiguate Flutter.Notification from Foundation.Notification
private typealias FlutterNotification = Flutter.Notification

/// Tests for SizeChangedLayoutNotification, SizeChangedLayoutNotifier,
/// and kMinInteractiveDimension constant.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/size_changed_layout_notifier_test.dart`
final class SizeChangedLayoutNotifierTests: XCTestCase {

    // MARK: - Test Helpers

    private class TestChildWidget: Widget {}

    // MARK: - SizeChangedLayoutNotification: Subclass Checks

    func testSizeChangedLayoutNotificationIsLayoutChangedNotification() {
        let notification = SizeChangedLayoutNotification()
        XCTAssertTrue(notification is LayoutChangedNotification)
    }

    func testSizeChangedLayoutNotificationIsNotification() {
        let notification = SizeChangedLayoutNotification()
        XCTAssertTrue(notification is FlutterNotification)
    }

    func testSizeChangedLayoutNotificationCanBeCreated() {
        let notification = SizeChangedLayoutNotification()
        XCTAssertNotNil(notification)
    }

    // MARK: - SizeChangedLayoutNotification: Description

    func testSizeChangedLayoutNotificationDescription() {
        let notification = SizeChangedLayoutNotification()
        let description = notification.description
        XCTAssertTrue(description.contains("SizeChangedLayoutNotification"))
    }

    func testSizeChangedLayoutNotificationDescriptionFormat() {
        let notification = SizeChangedLayoutNotification()
        // The description format from Notification base class is:
        // "TypeName()" with debugFillDescription parts
        let description = notification.description
        XCTAssertEqual(description, "SizeChangedLayoutNotification()")
    }

    // MARK: - SizeChangedLayoutNotifier: Construction

    func testSizeChangedLayoutNotifierConstruction() {
        let notifier = SizeChangedLayoutNotifier()
        XCTAssertNotNil(notifier)
    }

    func testSizeChangedLayoutNotifierWithChild() {
        let child = TestChildWidget()
        let notifier = SizeChangedLayoutNotifier(child: child)
        XCTAssertNotNil(notifier)
        XCTAssertTrue(notifier.child is TestChildWidget)
    }

    func testSizeChangedLayoutNotifierChildProperty() {
        let child = TestChildWidget()
        let notifier = SizeChangedLayoutNotifier(child: child)
        XCTAssertNotNil(notifier.child)
    }

    func testSizeChangedLayoutNotifierWithNilChild() {
        let notifier = SizeChangedLayoutNotifier(child: nil)
        XCTAssertNil(notifier.child)
    }

    func testSizeChangedLayoutNotifierDefaultChildIsNil() {
        let notifier = SizeChangedLayoutNotifier()
        XCTAssertNil(notifier.child)
    }

    // MARK: - SizeChangedLayoutNotifier: Key

    func testSizeChangedLayoutNotifierKeyIsNilByDefault() {
        let notifier = SizeChangedLayoutNotifier()
        XCTAssertNil(notifier.key)
    }

    func testSizeChangedLayoutNotifierWithKey() {
        let key = ValueKey("notifier-key")
        let notifier = SizeChangedLayoutNotifier(key: key)
        XCTAssertNotNil(notifier.key)
    }

    func testSizeChangedLayoutNotifierWithUniqueKey() {
        let key = UniqueKey()
        let notifier = SizeChangedLayoutNotifier(key: key)
        XCTAssertNotNil(notifier.key)
    }

    func testSizeChangedLayoutNotifierWithKeyAndChild() {
        let key = ValueKey("test")
        let child = TestChildWidget()
        let notifier = SizeChangedLayoutNotifier(key: key, child: child)
        XCTAssertNotNil(notifier.key)
        XCTAssertNotNil(notifier.child)
    }

    // MARK: - SizeChangedLayoutNotifier: Widget Hierarchy

    func testSizeChangedLayoutNotifierIsWidget() {
        let notifier = SizeChangedLayoutNotifier()
        XCTAssertTrue(notifier is Widget)
    }

    func testSizeChangedLayoutNotifierIsSingleChildRenderObjectWidget() {
        let notifier = SizeChangedLayoutNotifier()
        XCTAssertTrue(notifier is SingleChildRenderObjectWidget)
    }

    func testSizeChangedLayoutNotifierIsRenderObjectWidget() {
        let notifier = SizeChangedLayoutNotifier()
        XCTAssertTrue(notifier is RenderObjectWidget)
    }

    // MARK: - kMinInteractiveDimension Constant

    func testKMinInteractiveDimensionEquals48() {
        XCTAssertEqual(kMinInteractiveDimension, 48.0)
    }

    func testKMinInteractiveDimensionIsDouble() {
        let value: Double = kMinInteractiveDimension
        XCTAssertEqual(value, 48.0)
    }

    func testKMinInteractiveDimensionIsPositive() {
        XCTAssertGreaterThan(kMinInteractiveDimension, 0.0)
    }
}

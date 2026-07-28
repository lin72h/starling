// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
import FlutterSwiftBridge

/// Tests for InheritedNotifier and _InheritedNotifierElement.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/inherited_notifier_test.dart`
final class InheritedNotifierTests: XCTestCase {

    // MARK: - Test Helpers

    /// A ChangeNotifier subclass that tracks addListener/removeListener calls.
    private class TestNotifier: ChangeNotifier {
        var addListenerCount = 0
        var removeListenerCount = 0

        override func addListener(_ listener: @escaping VoidCallback) {
            addListenerCount += 1
            super.addListener(listener)
        }

        override func removeListener(_ listener: @escaping VoidCallback) {
            removeListenerCount += 1
            super.removeListener(listener)
        }
    }

    /// A minimal child widget for constructing InheritedNotifier instances.
    private class DummyWidget: Widget {
        init() { super.init(key: nil) }
        override func createElement() -> Element {
            return Element(self)
        }
    }

    /// Concrete InheritedNotifier subclass for testing since InheritedNotifier is generic.
    private class TestInheritedNotifier: InheritedNotifier<TestNotifier> {
        init(notifier: TestNotifier? = nil, child: Widget) {
            super.init(notifier: notifier, child: child)
        }
    }

    // MARK: - Constructor with notifier

    func testConstructorWithNotifier() {
        let notifier = TestNotifier()
        let child = DummyWidget()
        let widget = TestInheritedNotifier(notifier: notifier, child: child)

        XCTAssertTrue(widget.notifier === notifier)
        XCTAssertTrue(widget.child === child)
    }

    // MARK: - Constructor without notifier

    func testConstructorWithoutNotifier() {
        let child = DummyWidget()
        let widget = TestInheritedNotifier(child: child)

        XCTAssertNil(widget.notifier)
        XCTAssertTrue(widget.child === child)
    }

    // MARK: - InheritedWidget inheritance

    func testInheritedNotifierIsInheritedWidget() {
        let child = DummyWidget()
        let widget = TestInheritedNotifier(child: child)

        XCTAssertTrue(widget is InheritedWidget)
        XCTAssertTrue(widget is ProxyWidget)
        XCTAssertTrue(widget is Widget)
    }

    // MARK: - updateShouldNotify - same notifier instance

    func testUpdateShouldNotifySameNotifierReturnsFalse() {
        let notifier = TestNotifier()
        let child = DummyWidget()
        let widget1 = TestInheritedNotifier(notifier: notifier, child: child)
        let widget2 = TestInheritedNotifier(notifier: notifier, child: child)

        XCTAssertFalse(widget1.updateShouldNotify(widget2))
    }

    // MARK: - updateShouldNotify - different notifier instance

    func testUpdateShouldNotifyDifferentNotifierReturnsTrue() {
        let notifier1 = TestNotifier()
        let notifier2 = TestNotifier()
        let child = DummyWidget()
        let widget1 = TestInheritedNotifier(notifier: notifier1, child: child)
        let widget2 = TestInheritedNotifier(notifier: notifier2, child: child)

        XCTAssertTrue(widget1.updateShouldNotify(widget2))
    }

    // MARK: - updateShouldNotify - both nil

    func testUpdateShouldNotifyBothNilReturnsFalse() {
        let child = DummyWidget()
        let widget1 = TestInheritedNotifier(child: child)
        let widget2 = TestInheritedNotifier(child: child)

        XCTAssertFalse(widget1.updateShouldNotify(widget2))
    }

    // MARK: - updateShouldNotify - one nil one non-nil

    func testUpdateShouldNotifyOneNilOneNonNilReturnsTrue() {
        let notifier = TestNotifier()
        let child = DummyWidget()
        let widgetWithNotifier = TestInheritedNotifier(notifier: notifier, child: child)
        let widgetWithoutNotifier = TestInheritedNotifier(child: child)

        // new has notifier, old is nil
        XCTAssertTrue(widgetWithNotifier.updateShouldNotify(widgetWithoutNotifier))
        // new is nil, old has notifier
        XCTAssertTrue(widgetWithoutNotifier.updateShouldNotify(widgetWithNotifier))
    }

    // MARK: - createElement

    func testCreateElementReturnsInheritedNotifierElement() {
        let child = DummyWidget()
        let widget = TestInheritedNotifier(child: child)
        let element = widget.createElement()

        // The element should be an InheritedElement (the internal type
        // _InheritedNotifierElement inherits from InheritedElement)
        XCTAssertTrue(element is InheritedElement)
    }

    // MARK: - Element listener registration

    func testElementListenerRegistration() {
        let notifier = TestNotifier()
        let child = DummyWidget()
        let widget = TestInheritedNotifier(notifier: notifier, child: child)

        // Creating the element should call addListener on the notifier
        let _ = widget.createElement()

        XCTAssertEqual(notifier.addListenerCount, 1)
    }

    func testElementCreatedWithNilNotifierDoesNotAddListener() {
        let child = DummyWidget()
        let widget = TestInheritedNotifier(child: child)

        // This should not crash even though notifier is nil
        let element = widget.createElement()
        XCTAssertNotNil(element)
    }

    // MARK: - Element unmount

    func testElementUnmountRemovesListener() {
        let notifier = TestNotifier()
        let child = DummyWidget()
        let widget = TestInheritedNotifier(notifier: notifier, child: child)
        let element = widget.createElement()

        XCTAssertEqual(notifier.addListenerCount, 1)
        XCTAssertEqual(notifier.removeListenerCount, 0)

        // Unmounting should remove the listener
        element.unmount()

        XCTAssertEqual(notifier.removeListenerCount, 1)
    }

    func testElementUnmountWithNilNotifierDoesNotCrash() {
        let child = DummyWidget()
        let widget = TestInheritedNotifier(child: child)
        let element = widget.createElement()

        // Should not crash when unmounting with nil notifier
        element.unmount()
    }

    // MARK: - Key propagation

    func testKeyPropagation() {
        let child = DummyWidget()
        let key = ValueKey(42)
        let widget = InheritedNotifier<TestNotifier>(key: key, notifier: nil, child: child)

        XCTAssertNotNil(widget.key)
    }

    // MARK: - updateShouldNotify is symmetric

    func testUpdateShouldNotifySymmetric() {
        let notifier1 = TestNotifier()
        let notifier2 = TestNotifier()
        let child = DummyWidget()
        let widget1 = TestInheritedNotifier(notifier: notifier1, child: child)
        let widget2 = TestInheritedNotifier(notifier: notifier2, child: child)

        // Both directions should return true for different notifiers
        XCTAssertTrue(widget1.updateShouldNotify(widget2))
        XCTAssertTrue(widget2.updateShouldNotify(widget1))

        // Same notifier: both directions return false
        let widget3 = TestInheritedNotifier(notifier: notifier1, child: child)
        XCTAssertFalse(widget1.updateShouldNotify(widget3))
        XCTAssertFalse(widget3.updateShouldNotify(widget1))
    }
}

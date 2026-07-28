// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
import FlutterSwiftBridge

/// Tests for the IconTheme widget.
///
/// **Dart Source:** `packages/flutter/lib/src/widgets/icon_theme.dart`
final class IconThemeTests: XCTestCase {

    // MARK: - Test Helpers

    private class MockElement: Element {
        init() { super.init(Widget()) }
    }

    // MARK: - Constructor Tests

    func testConstructorStoresData() {
        let data = IconThemeData(size: 24.0)
        let child = Widget()
        let theme = IconTheme(data: data, child: child)
        XCTAssertEqual(theme.data, data)
    }

    func testConstructorStoresChild() {
        let data = IconThemeData(size: 24.0)
        let child = Widget()
        let theme = IconTheme(data: data, child: child)
        XCTAssertTrue(theme.child === child)
    }

    func testConstructorStoresKey() {
        let key = ValueKey(42)
        let data = IconThemeData(size: 24.0)
        let child = Widget()
        let theme = IconTheme(key: key, data: data, child: child)
        XCTAssertNotNil(theme.key)
    }

    // MARK: - Property Tests

    func testDataPropertyReturnsIconThemeData() {
        let data = IconThemeData(size: 48.0, color: Color(0xFFFF0000))
        let theme = IconTheme(data: data, child: Widget())
        XCTAssertEqual(theme.data.size, 48.0)
        XCTAssertEqual(theme.data.color, Color(0xFFFF0000))
    }

    func testChildPropertyReturnsWidget() {
        let child = Widget()
        let theme = IconTheme(data: IconThemeData(size: 24.0), child: child)
        XCTAssertTrue(theme.child === child)
    }

    // MARK: - Inheritance Tests

    func testIconThemeIsInheritedTheme() {
        let theme = IconTheme(data: IconThemeData(size: 24.0), child: Widget())
        XCTAssertTrue(theme is InheritedTheme)
    }

    func testIconThemeIsInheritedWidget() {
        let theme = IconTheme(data: IconThemeData(size: 24.0), child: Widget())
        XCTAssertTrue(theme is InheritedWidget)
    }

    // MARK: - updateShouldNotify Tests

    func testUpdateShouldNotifyReturnsFalseForSameData() {
        let data = IconThemeData(size: 24.0)
        let oldTheme = IconTheme(data: data, child: Widget())
        let newTheme = IconTheme(data: IconThemeData(size: 24.0), child: Widget())
        XCTAssertFalse(newTheme.updateShouldNotify(oldTheme))
    }

    func testUpdateShouldNotifyReturnsTrueForDifferentData() {
        let data1 = IconThemeData(size: 24.0)
        let data2 = IconThemeData(size: 48.0)
        let oldTheme = IconTheme(data: data1, child: Widget())
        let newTheme = IconTheme(data: data2, child: Widget())
        XCTAssertTrue(newTheme.updateShouldNotify(oldTheme))
    }

    func testUpdateShouldNotifyReturnsTrueForDifferentWidgetType() {
        let data = IconThemeData(size: 24.0)
        let newTheme = IconTheme(data: data, child: Widget())
        // Pass a plain InheritedWidget (not an IconTheme) as the old widget
        let otherWidget = InheritedWidget(child: Widget())
        XCTAssertTrue(newTheme.updateShouldNotify(otherWidget))
    }

    // MARK: - wrap Tests

    func testWrapReturnsNewIconThemeWithGivenChild() {
        let data = IconThemeData(size: 24.0)
        let originalChild = Widget()
        let theme = IconTheme(data: data, child: originalChild)

        let newChild = Widget()
        let context = MockElement()
        let wrapped = theme.wrap(context, newChild)

        // The wrapped result should contain the new child
        guard let wrappedTheme = wrapped as? IconTheme else {
            XCTFail("wrap should return an IconTheme")
            return
        }
        XCTAssertTrue(wrappedTheme.child === newChild)
    }

    func testWrapResultIsIconTheme() {
        let data = IconThemeData(size: 24.0)
        let theme = IconTheme(data: data, child: Widget())
        let context = MockElement()
        let wrapped = theme.wrap(context, Widget())
        XCTAssertTrue(wrapped is IconTheme)
    }

    func testWrapResultHasSameData() {
        let data = IconThemeData(size: 24.0, color: Color(0xFF00FF00))
        let theme = IconTheme(data: data, child: Widget())
        let context = MockElement()
        let wrapped = theme.wrap(context, Widget())

        guard let wrappedTheme = wrapped as? IconTheme else {
            XCTFail("wrap should return an IconTheme")
            return
        }
        XCTAssertEqual(wrappedTheme.data, data)
    }
}

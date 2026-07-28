// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import FlutterSwiftBridge
@testable import Flutter

/// Tests for BottomNavigationBarItem.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/bottom_navigation_bar_item_test.dart`
final class BottomNavigationBarItemTests: XCTestCase {

    // MARK: - Constructor

    func testConstructorMinimal() {
        let icon = Widget()
        let item = BottomNavigationBarItem(icon: icon)
        XCTAssertNotNil(item.icon)
        XCTAssertNil(item.key)
        XCTAssertNil(item.label)
        XCTAssertNil(item.backgroundColor)
        XCTAssertNil(item.tooltip)
    }

    func testConstructorAllParams() {
        let key = ValueKey<String>("navItem")
        let icon = Widget()
        let activeIcon = Widget()
        let color = Color(0xFF00FF00)
        let item = BottomNavigationBarItem(
            key: key,
            icon: icon,
            label: "Home",
            activeIcon: activeIcon,
            backgroundColor: color,
            tooltip: "Navigate home"
        )
        XCTAssertTrue(item.icon === icon)
        XCTAssertTrue(item.activeIcon === activeIcon)
        XCTAssertEqual(item.label, "Home")
        XCTAssertEqual(item.backgroundColor, color)
        XCTAssertEqual(item.tooltip, "Navigate home")
        XCTAssertNotNil(item.key)
    }

    // MARK: - activeIcon default

    func testActiveIconDefaultsToIcon() {
        let icon = Widget()
        let item = BottomNavigationBarItem(icon: icon)
        XCTAssertTrue(item.activeIcon === icon, "activeIcon should default to the same object as icon")
    }

    func testActiveIconExplicit() {
        let icon = Widget()
        let activeIcon = Widget()
        let item = BottomNavigationBarItem(icon: icon, activeIcon: activeIcon)
        XCTAssertTrue(item.activeIcon === activeIcon)
        XCTAssertFalse(item.activeIcon === icon, "activeIcon should be a different object from icon when explicitly provided")
    }

    // MARK: - label property

    func testLabelNilByDefault() {
        let item = BottomNavigationBarItem(icon: Widget())
        XCTAssertNil(item.label)
    }

    func testLabelNonNil() {
        let item = BottomNavigationBarItem(icon: Widget(), label: "Settings")
        XCTAssertEqual(item.label, "Settings")
    }

    // MARK: - backgroundColor property

    func testBackgroundColorNilByDefault() {
        let item = BottomNavigationBarItem(icon: Widget())
        XCTAssertNil(item.backgroundColor)
    }

    func testBackgroundColorNonNil() {
        let color = Color(0xFF00FF00)
        let item = BottomNavigationBarItem(icon: Widget(), backgroundColor: color)
        XCTAssertEqual(item.backgroundColor, color)
    }

    // MARK: - tooltip property

    func testTooltipNilByDefault() {
        let item = BottomNavigationBarItem(icon: Widget())
        XCTAssertNil(item.tooltip)
    }

    func testTooltipNonNil() {
        let item = BottomNavigationBarItem(icon: Widget(), tooltip: "Open settings")
        XCTAssertEqual(item.tooltip, "Open settings")
    }

    // MARK: - key property

    func testKeyNilByDefault() {
        let item = BottomNavigationBarItem(icon: Widget())
        XCTAssertNil(item.key)
    }

    func testKeyNonNil() {
        let key = ValueKey<String>("navKey")
        let item = BottomNavigationBarItem(key: key, icon: Widget())
        XCTAssertNotNil(item.key)
    }
}

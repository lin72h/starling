// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import FlutterSwiftBridge
@testable import Flutter

/// Tests for DefaultSelectionStyle.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/default_selection_style_test.dart`
final class DefaultSelectionStyleTests: XCTestCase {

    // MARK: - Test Helpers

    private class MockElement: Element {
        init() { super.init(Widget()) }
    }

    private class TestChildWidget: Widget {}

    // MARK: - Constructor Tests (all nil)

    func testConstructorWithAllNilProperties() {
        let child = TestChildWidget()
        let style = DefaultSelectionStyle(child: child)
        XCTAssertNil(style.cursorColor)
        XCTAssertNil(style.selectionColor)
        XCTAssertNil(style.mouseCursor)
    }

    func testConstructorKeyIsNilByDefault() {
        let style = DefaultSelectionStyle(child: TestChildWidget())
        XCTAssertNil(style.key)
    }

    // MARK: - Constructor Tests (with colors)

    func testConstructorWithCursorColor() {
        let color = Color(0xFFFF0000)
        let style = DefaultSelectionStyle(cursorColor: color, child: TestChildWidget())
        XCTAssertEqual(style.cursorColor, color)
    }

    func testConstructorWithSelectionColor() {
        let color = Color(0xFF00FF00)
        let style = DefaultSelectionStyle(selectionColor: color, child: TestChildWidget())
        XCTAssertEqual(style.selectionColor, color)
    }

    func testConstructorWithBothColors() {
        let cursorColor = Color(0xFFFF0000)
        let selectionColor = Color(0xFF00FF00)
        let style = DefaultSelectionStyle(
            cursorColor: cursorColor,
            selectionColor: selectionColor,
            child: TestChildWidget()
        )
        XCTAssertEqual(style.cursorColor, cursorColor)
        XCTAssertEqual(style.selectionColor, selectionColor)
    }

    func testConstructorWithMouseCursor() {
        let cursor = MouseCursor()
        let style = DefaultSelectionStyle(mouseCursor: cursor, child: TestChildWidget())
        XCTAssertTrue(style.mouseCursor === cursor)
    }

    // MARK: - Fallback Constructor

    func testFallbackConstructorCreatesInstanceWithNilProperties() {
        let style = DefaultSelectionStyle(fallback: nil)
        XCTAssertNil(style.cursorColor)
        XCTAssertNil(style.selectionColor)
        XCTAssertNil(style.mouseCursor)
    }

    func testFallbackConstructorKeyIsNilByDefault() {
        let style = DefaultSelectionStyle(fallback: nil)
        XCTAssertNil(style.key)
    }

    func testFallbackConstructorWithKey() {
        let key = ValueKey<String>("fallback-key")
        let style = DefaultSelectionStyle(fallback: key)
        XCTAssertNotNil(style.key)
    }

    // MARK: - defaultColor

    func testDefaultColorEqualsExpectedValue() {
        let expected = Color(0x80808080)
        XCTAssertEqual(DefaultSelectionStyle.defaultColor, expected)
    }

    func testDefaultColorIsStatic() {
        // Accessing twice yields the same value
        let color1 = DefaultSelectionStyle.defaultColor
        let color2 = DefaultSelectionStyle.defaultColor
        XCTAssertEqual(color1, color2)
    }

    // MARK: - Inheritance

    func testIsInheritedTheme() {
        let style = DefaultSelectionStyle(child: TestChildWidget())
        XCTAssertTrue(style is InheritedTheme)
    }

    func testIsInheritedWidget() {
        let style = DefaultSelectionStyle(child: TestChildWidget())
        XCTAssertTrue(style is InheritedWidget)
    }

    func testIsProxyWidget() {
        let style = DefaultSelectionStyle(child: TestChildWidget())
        XCTAssertTrue(style is ProxyWidget)
    }

    func testIsWidget() {
        let style = DefaultSelectionStyle(child: TestChildWidget())
        XCTAssertTrue(style is Widget)
    }

    // MARK: - updateShouldNotify (same properties)

    func testUpdateShouldNotifyReturnsFalseForSameProperties() {
        let cursorColor = Color(0xFFFF0000)
        let selectionColor = Color(0xFF00FF00)
        let cursor = MouseCursor()
        let style1 = DefaultSelectionStyle(
            cursorColor: cursorColor,
            selectionColor: selectionColor,
            mouseCursor: cursor,
            child: TestChildWidget()
        )
        let style2 = DefaultSelectionStyle(
            cursorColor: cursorColor,
            selectionColor: selectionColor,
            mouseCursor: cursor,
            child: TestChildWidget()
        )
        XCTAssertFalse(style1.updateShouldNotify(style2))
    }

    func testUpdateShouldNotifyReturnsFalseForAllNilProperties() {
        let style1 = DefaultSelectionStyle(child: TestChildWidget())
        let style2 = DefaultSelectionStyle(child: TestChildWidget())
        XCTAssertFalse(style1.updateShouldNotify(style2))
    }

    // MARK: - updateShouldNotify (different cursorColor)

    func testUpdateShouldNotifyReturnsTrueForDifferentCursorColor() {
        let style1 = DefaultSelectionStyle(
            cursorColor: Color(0xFFFF0000),
            child: TestChildWidget()
        )
        let style2 = DefaultSelectionStyle(
            cursorColor: Color(0xFF0000FF),
            child: TestChildWidget()
        )
        XCTAssertTrue(style1.updateShouldNotify(style2))
    }

    func testUpdateShouldNotifyReturnsTrueWhenCursorColorBecomesNil() {
        let style1 = DefaultSelectionStyle(
            cursorColor: Color(0xFFFF0000),
            child: TestChildWidget()
        )
        let style2 = DefaultSelectionStyle(child: TestChildWidget())
        XCTAssertTrue(style1.updateShouldNotify(style2))
    }

    // MARK: - updateShouldNotify (different selectionColor)

    func testUpdateShouldNotifyReturnsTrueForDifferentSelectionColor() {
        let style1 = DefaultSelectionStyle(
            selectionColor: Color(0xFF00FF00),
            child: TestChildWidget()
        )
        let style2 = DefaultSelectionStyle(
            selectionColor: Color(0xFF0000FF),
            child: TestChildWidget()
        )
        XCTAssertTrue(style1.updateShouldNotify(style2))
    }

    func testUpdateShouldNotifyReturnsTrueWhenSelectionColorBecomesNil() {
        let style1 = DefaultSelectionStyle(
            selectionColor: Color(0xFF00FF00),
            child: TestChildWidget()
        )
        let style2 = DefaultSelectionStyle(child: TestChildWidget())
        XCTAssertTrue(style1.updateShouldNotify(style2))
    }

    // MARK: - updateShouldNotify (different mouseCursor)

    func testUpdateShouldNotifyReturnsTrueForDifferentMouseCursor() {
        let cursor1 = MouseCursor()
        let cursor2 = MouseCursor()
        let style1 = DefaultSelectionStyle(
            mouseCursor: cursor1,
            child: TestChildWidget()
        )
        let style2 = DefaultSelectionStyle(
            mouseCursor: cursor2,
            child: TestChildWidget()
        )
        // mouseCursor uses identity comparison (!==)
        XCTAssertTrue(style1.updateShouldNotify(style2))
    }

    func testUpdateShouldNotifyReturnsFalseForSameMouseCursorInstance() {
        let cursor = MouseCursor()
        let style1 = DefaultSelectionStyle(
            mouseCursor: cursor,
            child: TestChildWidget()
        )
        let style2 = DefaultSelectionStyle(
            mouseCursor: cursor,
            child: TestChildWidget()
        )
        XCTAssertFalse(style1.updateShouldNotify(style2))
    }

    // MARK: - updateShouldNotify (different type)

    func testUpdateShouldNotifyReturnsTrueForDifferentWidgetType() {
        let style = DefaultSelectionStyle(child: TestChildWidget())
        // Pass a plain InheritedWidget (not a DefaultSelectionStyle)
        let otherWidget = InheritedWidget(child: TestChildWidget())
        XCTAssertTrue(style.updateShouldNotify(otherWidget))
    }

    // MARK: - wrap

    func testWrapReturnsDefaultSelectionStyle() {
        let cursorColor = Color(0xFFFF0000)
        let selectionColor = Color(0xFF00FF00)
        let style = DefaultSelectionStyle(
            cursorColor: cursorColor,
            selectionColor: selectionColor,
            child: TestChildWidget()
        )
        let context = MockElement()
        let newChild = TestChildWidget()
        let wrapped = style.wrap(context, newChild)
        XCTAssertTrue(wrapped is DefaultSelectionStyle)
    }

    func testWrapPreservesCursorColor() {
        let cursorColor = Color(0xFFFF0000)
        let style = DefaultSelectionStyle(
            cursorColor: cursorColor,
            child: TestChildWidget()
        )
        let context = MockElement()
        let newChild = TestChildWidget()
        let wrapped = style.wrap(context, newChild) as! DefaultSelectionStyle
        XCTAssertEqual(wrapped.cursorColor, cursorColor)
    }

    func testWrapPreservesSelectionColor() {
        let selectionColor = Color(0xFF00FF00)
        let style = DefaultSelectionStyle(
            selectionColor: selectionColor,
            child: TestChildWidget()
        )
        let context = MockElement()
        let newChild = TestChildWidget()
        let wrapped = style.wrap(context, newChild) as! DefaultSelectionStyle
        XCTAssertEqual(wrapped.selectionColor, selectionColor)
    }

    func testWrapPreservesMouseCursor() {
        let cursor = MouseCursor()
        let style = DefaultSelectionStyle(
            mouseCursor: cursor,
            child: TestChildWidget()
        )
        let context = MockElement()
        let newChild = TestChildWidget()
        let wrapped = style.wrap(context, newChild) as! DefaultSelectionStyle
        XCTAssertTrue(wrapped.mouseCursor === cursor)
    }

    func testWrapUsesNewChild() {
        let style = DefaultSelectionStyle(child: TestChildWidget())
        let context = MockElement()
        let newChild = TestChildWidget()
        let wrapped = style.wrap(context, newChild) as! DefaultSelectionStyle
        // The child of the wrapped widget should be the new child, not the original
        XCTAssertTrue(wrapped.child === newChild)
    }
}

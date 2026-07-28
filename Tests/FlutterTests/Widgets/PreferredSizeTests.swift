// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import FlutterSwiftBridge
@testable import Flutter

/// Tests for PreferredSize and PreferredSizeWidget.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/preferred_size_test.dart`
final class PreferredSizeTests: XCTestCase {

    // MARK: - Mock BuildContext

    private class MockElement: Element {
        init() { super.init(Widget()) }
    }

    // MARK: - Constructor

    func testConstructorStoresProperties() {
        let size = Size(100, 50)
        let child = Widget()
        let key = ValueKey<String>("preferred")
        let widget = PreferredSize(key: key, preferredSize: size, child: child)

        XCTAssertEqual(widget.preferredSize, size)
        XCTAssertTrue(widget.child === child)
        XCTAssertNotNil(widget.key)
    }

    func testConstructorKeyNilByDefault() {
        let widget = PreferredSize(preferredSize: Size(100, 50), child: Widget())
        XCTAssertNil(widget.key)
    }

    // MARK: - preferredSize property

    func testPreferredSizeReturnsConstructorValue() {
        let size = Size(200, 100)
        let widget = PreferredSize(preferredSize: size, child: Widget())
        XCTAssertEqual(widget.preferredSize, size)
    }

    func testPreferredSizeFromHeight() {
        let size = Size(fromHeight: 48)
        let widget = PreferredSize(preferredSize: size, child: Widget())
        XCTAssertEqual(widget.preferredSize.height, 48)
        XCTAssertEqual(widget.preferredSize.width, .infinity)
    }

    func testPreferredSizeZero() {
        let size = Size(0, 0)
        let widget = PreferredSize(preferredSize: size, child: Widget())
        XCTAssertEqual(widget.preferredSize.width, 0)
        XCTAssertEqual(widget.preferredSize.height, 0)
    }

    // MARK: - child property

    func testChildReturnsConstructorWidget() {
        let child = Widget()
        let widget = PreferredSize(preferredSize: Size(100, 50), child: child)
        XCTAssertTrue(widget.child === child)
    }

    // MARK: - build method

    func testBuildReturnsChild() {
        let child = Widget()
        let widget = PreferredSize(preferredSize: Size(100, 50), child: child)
        let context = MockElement()
        let result = widget.build(context)
        XCTAssertTrue(result === child, "build() should return the same child reference")
    }

    // MARK: - PreferredSizeWidget protocol conformance

    func testConformsToPreferredSizeWidget() {
        let widget = PreferredSize(preferredSize: Size(100, 50), child: Widget())
        XCTAssertTrue(widget is PreferredSizeWidget)
    }

    func testPreferredSizeWidgetProtocolAccess() {
        let size = Size(300, 56)
        let widget = PreferredSize(preferredSize: size, child: Widget())
        let protocolRef: PreferredSizeWidget = widget
        XCTAssertEqual(protocolRef.preferredSize, size)
    }

    // MARK: - StatelessWidget inheritance

    func testIsStatelessWidget() {
        let widget = PreferredSize(preferredSize: Size(100, 50), child: Widget())
        XCTAssertTrue(widget is StatelessWidget)
    }

    // MARK: - Widget inheritance

    func testIsWidget() {
        let widget = PreferredSize(preferredSize: Size(100, 50), child: Widget())
        XCTAssertTrue(widget is Widget)
    }

    // MARK: - Different sizes

    func testDifferentSizes() {
        let sizes: [Size] = [
            Size(100, 50),
            Size(fromHeight: 48),
            Size(0, 0),
            Size(320, 568),
        ]
        for size in sizes {
            let widget = PreferredSize(preferredSize: size, child: Widget())
            XCTAssertEqual(widget.preferredSize, size)
        }
    }

    // MARK: - Key

    func testKeyNilByDefault() {
        let widget = PreferredSize(preferredSize: Size(100, 50), child: Widget())
        XCTAssertNil(widget.key)
    }

    func testKeyStoredWhenProvided() {
        let key = ValueKey<String>("test-key")
        let widget = PreferredSize(key: key, preferredSize: Size(100, 50), child: Widget())
        XCTAssertNotNil(widget.key)
    }

    // MARK: - build returns same child reference

    func testBuildReturnsSameChildReference() {
        let child = Widget()
        let widget = PreferredSize(preferredSize: Size(100, 50), child: child)
        let context = MockElement()
        let buildResult = widget.build(context)
        XCTAssertTrue(child === buildResult, "build() must return the exact same child object (identity)")
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for InheritedTheme, CapturedThemes, and CaptureAll.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/inherited_theme_test.dart`
final class InheritedThemeTests: XCTestCase {

    // MARK: - Test Helpers

    /// A minimal child widget for constructing widgets.
    private class DummyWidget: Widget {
        init() { super.init(key: nil) }
        override func createElement() -> Element {
            return Element(self)
        }
    }

    /// Concrete InheritedTheme subclass for testing.
    private class TestTheme: InheritedTheme {
        override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
            return TestTheme(child: child)
        }

        override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
            return true
        }
    }

    /// A second theme subclass to test deduplication by type.
    private class AnotherTestTheme: InheritedTheme {
        override func wrap(_ context: any BuildContext, _ child: Widget) -> Widget {
            return AnotherTestTheme(child: child)
        }

        override func updateShouldNotify(_ oldWidget: InheritedWidget) -> Bool {
            return true
        }
    }

    /// A mock BuildContext that provides a configurable ancestor element chain.
    private class MockBuildContext: Element {
        var ancestors: [Element]

        init(widget: Widget, ancestors: [Element] = []) {
            self.ancestors = ancestors
            super.init(widget)
        }

        override func visitAncestorElements(_ visitor: (Element) -> Bool) {
            for ancestor in ancestors {
                if !visitor(ancestor) {
                    return
                }
            }
        }
    }

    // MARK: - InheritedTheme constructor

    func testConstructorStoresChild() {
        let child = DummyWidget()
        let theme = TestTheme(child: child)

        XCTAssertTrue(theme.child === child)
    }

    func testConstructorWithKey() {
        let child = DummyWidget()
        let key = ValueKey("theme-key")
        let theme = TestTheme(key: key, child: child)

        XCTAssertNotNil(theme.key)
    }

    func testConstructorWithoutKey() {
        let child = DummyWidget()
        let theme = TestTheme(child: child)

        XCTAssertNil(theme.key)
    }

    // MARK: - InheritedWidget inheritance

    func testInheritedThemeIsInheritedWidget() {
        let child = DummyWidget()
        let theme = TestTheme(child: child)

        XCTAssertTrue(theme is InheritedWidget)
        XCTAssertTrue(theme is ProxyWidget)
        XCTAssertTrue(theme is Widget)
    }

    // MARK: - TestTheme wrap

    func testWrapReturnsNewTestTheme() {
        let child = DummyWidget()
        let theme = TestTheme(child: child)
        let dummy = DummyWidget()
        let context = MockBuildContext(widget: dummy)

        let newChild = DummyWidget()
        let wrapped = theme.wrap(context, newChild)

        XCTAssertTrue(wrapped is TestTheme)
        let wrappedTheme = wrapped as! TestTheme
        XCTAssertTrue(wrappedTheme.child === newChild)
    }

    // MARK: - CapturedThemes empty

    func testCapturedThemesEmptyWrapReturnsCaptureAll() {
        let captured = CapturedThemes([])
        let child = DummyWidget()
        let result = captured.wrap(child)

        XCTAssertTrue(result is CaptureAll)
    }

    // MARK: - CapturedThemes wrap

    func testCapturedThemesWrapReturnsCaptureAll() {
        let child = DummyWidget()
        let theme = TestTheme(child: child)
        let captured = CapturedThemes([theme])
        let wrappedChild = DummyWidget()
        let result = captured.wrap(wrappedChild)

        XCTAssertTrue(result is CaptureAll)
    }

    // MARK: - CapturedThemes with themes

    func testCapturedThemesStoresThemes() {
        let child = DummyWidget()
        let theme1 = TestTheme(child: child)
        let theme2 = AnotherTestTheme(child: child)
        let captured = CapturedThemes([theme1, theme2])
        let wrappedChild = DummyWidget()
        let result = captured.wrap(wrappedChild) as! CaptureAll

        XCTAssertEqual(result.themes.count, 2)
        XCTAssertTrue(result.themes[0] === theme1)
        XCTAssertTrue(result.themes[1] === theme2)
    }

    // MARK: - CaptureAll build with empty themes

    func testCaptureAllBuildWithEmptyThemesReturnsChild() {
        let child = DummyWidget()
        let captureAll = CaptureAll(themes: [], child: child)
        let context = MockBuildContext(widget: child)

        let built = captureAll.build(context)

        XCTAssertTrue(built === child)
    }

    // MARK: - CaptureAll build with themes

    func testCaptureAllBuildWithThemesWrapsChild() {
        let child = DummyWidget()
        let themeChild = DummyWidget()
        let theme1 = TestTheme(child: themeChild)
        let theme2 = AnotherTestTheme(child: themeChild)
        let captureAll = CaptureAll(themes: [theme1, theme2], child: child)
        let context = MockBuildContext(widget: child)

        let built = captureAll.build(context)

        // The result should be wrapped by the last theme (AnotherTestTheme wraps the result of TestTheme wrapping child)
        XCTAssertTrue(built is AnotherTestTheme)
        // The inner wrapped widget should be a TestTheme
        let outerTheme = built as! AnotherTestTheme
        XCTAssertTrue(outerTheme.child is TestTheme)
        // The innermost child should be the original child
        let innerTheme = outerTheme.child as! TestTheme
        XCTAssertTrue(innerTheme.child === child)
    }

    // MARK: - InheritedTheme.capture same context

    func testCaptureSameContextReturnsEmptyCapturedThemes() {
        let dummy = DummyWidget()
        let context = MockBuildContext(widget: dummy)

        // When from === to, should return empty CapturedThemes
        let captured = InheritedTheme.capture(from: context, to: context)
        let result = captured.wrap(dummy) as! CaptureAll

        XCTAssertEqual(result.themes.count, 0)
    }

    // MARK: - InheritedTheme.capture with ancestor themes

    func testCaptureCollectsAncestorThemes() {
        let child = DummyWidget()
        let theme = TestTheme(child: child)
        let themeElement = InheritedElement(theme)

        let dummy = DummyWidget()
        let context = MockBuildContext(widget: dummy, ancestors: [themeElement])

        let captured = InheritedTheme.capture(from: context)
        let result = captured.wrap(child) as! CaptureAll

        XCTAssertEqual(result.themes.count, 1)
        XCTAssertTrue(result.themes[0] === theme)
    }

    // MARK: - InheritedTheme.capture deduplicates by type

    func testCaptureDeduplicatesByType() {
        let child = DummyWidget()
        let theme1 = TestTheme(child: child)
        let theme2 = TestTheme(child: child)
        let element1 = InheritedElement(theme1)
        let element2 = InheritedElement(theme2)

        let dummy = DummyWidget()
        let context = MockBuildContext(widget: dummy, ancestors: [element1, element2])

        let captured = InheritedTheme.capture(from: context)
        let result = captured.wrap(child) as! CaptureAll

        // Only the first TestTheme should be captured (same type)
        XCTAssertEqual(result.themes.count, 1)
        XCTAssertTrue(result.themes[0] === theme1)
    }

    // MARK: - InheritedTheme.capture with different theme types

    func testCaptureCollectsDifferentThemeTypes() {
        let child = DummyWidget()
        let theme1 = TestTheme(child: child)
        let theme2 = AnotherTestTheme(child: child)
        let element1 = InheritedElement(theme1)
        let element2 = InheritedElement(theme2)

        let dummy = DummyWidget()
        let context = MockBuildContext(widget: dummy, ancestors: [element1, element2])

        let captured = InheritedTheme.capture(from: context)
        let result = captured.wrap(child) as! CaptureAll

        XCTAssertEqual(result.themes.count, 2)
        XCTAssertTrue(result.themes[0] === theme1)
        XCTAssertTrue(result.themes[1] === theme2)
    }

    // MARK: - InheritedTheme.capture stops at 'to' context

    func testCaptureStopsAtToContext() {
        let child = DummyWidget()
        let theme1 = TestTheme(child: child)
        let theme2 = AnotherTestTheme(child: child)
        let element1 = InheritedElement(theme1)
        let stopElement = InheritedElement(theme2)

        let dummy = DummyWidget()
        // element1 is visited first, then stopElement (which is the 'to' boundary)
        let context = MockBuildContext(widget: dummy, ancestors: [element1, stopElement])

        let captured = InheritedTheme.capture(from: context, to: stopElement)
        let result = captured.wrap(child) as! CaptureAll

        // Should only capture theme1, since stopElement is the 'to' boundary
        XCTAssertEqual(result.themes.count, 1)
        XCTAssertTrue(result.themes[0] === theme1)
    }

    // MARK: - InheritedTheme.captureAll

    func testCaptureAllStaticMethod() {
        let child = DummyWidget()
        let theme = TestTheme(child: child)
        let themeElement = InheritedElement(theme)

        let dummy = DummyWidget()
        let context = MockBuildContext(widget: dummy, ancestors: [themeElement])

        let result = InheritedTheme.captureAll(context, child: child)

        // captureAll returns a CaptureAll widget
        XCTAssertTrue(result is CaptureAll)
    }

    // MARK: - InheritedTheme.capture skips non-InheritedElement ancestors

    func testCaptureSkipsNonInheritedElements() {
        let child = DummyWidget()
        let theme = TestTheme(child: child)
        let themeElement = InheritedElement(theme)

        // A plain Element that is not an InheritedElement
        let plainElement = Element(DummyWidget())

        let dummy = DummyWidget()
        let context = MockBuildContext(widget: dummy, ancestors: [plainElement, themeElement])

        let captured = InheritedTheme.capture(from: context)
        let result = captured.wrap(child) as! CaptureAll

        // Should only capture the InheritedTheme, skipping the plain Element
        XCTAssertEqual(result.themes.count, 1)
        XCTAssertTrue(result.themes[0] === theme)
    }

    // MARK: - InheritedTheme.capture with no ancestors

    func testCaptureWithNoAncestorsReturnsEmpty() {
        let dummy = DummyWidget()
        let context = MockBuildContext(widget: dummy, ancestors: [])

        let captured = InheritedTheme.capture(from: context)
        let result = captured.wrap(dummy) as! CaptureAll

        XCTAssertEqual(result.themes.count, 0)
    }
}

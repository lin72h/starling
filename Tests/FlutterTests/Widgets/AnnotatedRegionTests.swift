// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for AnnotatedRegion widget.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/annotated_region_test.dart`
final class AnnotatedRegionTests: XCTestCase {

    // MARK: - Test Helpers

    private class MockElement: Element {
        init() { super.init(Widget()) }
    }

    private class TestChildWidget: Widget {}

    // MARK: - Construction with String value and default sized

    func testConstructionWithStringValueDefaultSized() {
        let child = TestChildWidget()
        let region = AnnotatedRegion<String>(child: child, value: "hello")
        XCTAssertEqual(region.value, "hello")
        XCTAssertTrue(region.sized)
    }

    func testConstructionDefaultSizedIsTrue() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "test")
        XCTAssertTrue(region.sized)
    }

    // MARK: - Construction with Int value and sized=false

    func testConstructionWithIntValueAndSizedFalse() {
        let region = AnnotatedRegion<Int>(child: TestChildWidget(), value: 42, sized: false)
        XCTAssertEqual(region.value, 42)
        XCTAssertFalse(region.sized)
    }

    // MARK: - Property Access

    func testValuePropertyAccess() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "my value")
        XCTAssertEqual(region.value, "my value")
    }

    func testSizedPropertyAccessTrue() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "test", sized: true)
        XCTAssertTrue(region.sized)
    }

    func testSizedPropertyAccessFalse() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "test", sized: false)
        XCTAssertFalse(region.sized)
    }

    // MARK: - Key

    func testKeyIsNilByDefault() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "test")
        XCTAssertNil(region.key)
    }

    func testKeyIsStoredCorrectly() {
        let key = ValueKey("myKey")
        let region = AnnotatedRegion<String>(key: key, child: TestChildWidget(), value: "test")
        XCTAssertNotNil(region.key)
    }

    func testKeyIsStoredWithUniqueKey() {
        let key = UniqueKey()
        let region = AnnotatedRegion<Int>(key: key, child: TestChildWidget(), value: 7)
        XCTAssertNotNil(region.key)
    }

    // MARK: - createRenderObject

    func testCreateRenderObjectReturnsRenderAnnotatedRegionString() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "test")
        let context = MockElement()
        let renderObject = region.createRenderObject(context)
        XCTAssertTrue(renderObject is RenderAnnotatedRegion<String>)
    }

    func testCreateRenderObjectReturnsRenderAnnotatedRegionInt() {
        let region = AnnotatedRegion<Int>(child: TestChildWidget(), value: 42)
        let context = MockElement()
        let renderObject = region.createRenderObject(context)
        XCTAssertTrue(renderObject is RenderAnnotatedRegion<Int>)
    }

    func testCreateRenderObjectHasCorrectValue() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "hello")
        let context = MockElement()
        let renderObject = region.createRenderObject(context) as! RenderAnnotatedRegion<String>
        XCTAssertEqual(renderObject.value, "hello")
    }

    func testCreateRenderObjectHasCorrectSizedTrue() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "hello", sized: true)
        let context = MockElement()
        let renderObject = region.createRenderObject(context) as! RenderAnnotatedRegion<String>
        XCTAssertTrue(renderObject.sized)
    }

    func testCreateRenderObjectHasCorrectSizedFalse() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "hello", sized: false)
        let context = MockElement()
        let renderObject = region.createRenderObject(context) as! RenderAnnotatedRegion<String>
        XCTAssertFalse(renderObject.sized)
    }

    // MARK: - Generic Type Works with Different Types

    func testGenericTypeWithString() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "string value")
        XCTAssertEqual(region.value, "string value")
    }

    func testGenericTypeWithInt() {
        let region = AnnotatedRegion<Int>(child: TestChildWidget(), value: 123)
        XCTAssertEqual(region.value, 123)
    }

    func testGenericTypeWithDouble() {
        let region = AnnotatedRegion<Double>(child: TestChildWidget(), value: 3.14)
        XCTAssertEqual(region.value, 3.14)
    }

    func testGenericTypeWithBool() {
        let region = AnnotatedRegion<Bool>(child: TestChildWidget(), value: true)
        XCTAssertEqual(region.value, true)
    }

    // MARK: - Widget Hierarchy

    func testIsWidget() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "test")
        XCTAssertTrue(region is Widget)
    }

    func testIsSingleChildRenderObjectWidget() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "test")
        XCTAssertTrue(region is SingleChildRenderObjectWidget)
    }

    func testIsRenderObjectWidget() {
        let region = AnnotatedRegion<String>(child: TestChildWidget(), value: "test")
        XCTAssertTrue(region is RenderObjectWidget)
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
import FlutterSwiftBridge

/// Tests for TextureWidget.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/texture_test.dart`
final class TextureWidgetTests: XCTestCase {

    // MARK: - Mock BuildContext

    private class MockElement: Element {
        init() { super.init(Widget()) }
    }

    // MARK: - Construction with all parameters

    func testConstructionWithAllParameters() {
        let key = ValueKey<String>("texture-key")
        let widget = TextureWidget(
            key: key,
            textureId: 42,
            freeze: true,
            filterQuality: .high
        )
        XCTAssertEqual(widget.textureId, 42)
        XCTAssertTrue(widget.freeze)
        XCTAssertEqual(widget.filterQuality, .high)
        XCTAssertNotNil(widget.key)
    }

    // MARK: - Construction with defaults

    func testDefaultFreezeIsFalse() {
        let widget = TextureWidget(textureId: 1)
        XCTAssertFalse(widget.freeze)
    }

    func testDefaultFilterQualityIsLow() {
        let widget = TextureWidget(textureId: 1)
        XCTAssertEqual(widget.filterQuality, .low)
    }

    func testDefaultKeyIsNil() {
        let widget = TextureWidget(textureId: 1)
        XCTAssertNil(widget.key)
    }

    // MARK: - textureId property access

    func testTextureIdPropertyAccess() {
        let widget = TextureWidget(textureId: 123)
        XCTAssertEqual(widget.textureId, 123)
    }

    func testTextureIdZero() {
        let widget = TextureWidget(textureId: 0)
        XCTAssertEqual(widget.textureId, 0)
    }

    func testTextureIdNegative() {
        let widget = TextureWidget(textureId: -1)
        XCTAssertEqual(widget.textureId, -1)
    }

    func testTextureIdLargeValue() {
        let widget = TextureWidget(textureId: 999_999_999)
        XCTAssertEqual(widget.textureId, 999_999_999)
    }

    // MARK: - freeze property access

    func testFreezePropertyTrue() {
        let widget = TextureWidget(textureId: 1, freeze: true)
        XCTAssertTrue(widget.freeze)
    }

    func testFreezePropertyFalse() {
        let widget = TextureWidget(textureId: 1, freeze: false)
        XCTAssertFalse(widget.freeze)
    }

    // MARK: - filterQuality property access

    func testFilterQualityNone() {
        let widget = TextureWidget(textureId: 1, filterQuality: .none)
        XCTAssertEqual(widget.filterQuality, .none)
    }

    func testFilterQualityLow() {
        let widget = TextureWidget(textureId: 1, filterQuality: .low)
        XCTAssertEqual(widget.filterQuality, .low)
    }

    func testFilterQualityMedium() {
        let widget = TextureWidget(textureId: 1, filterQuality: .medium)
        XCTAssertEqual(widget.filterQuality, .medium)
    }

    func testFilterQualityHigh() {
        let widget = TextureWidget(textureId: 1, filterQuality: .high)
        XCTAssertEqual(widget.filterQuality, .high)
    }

    // MARK: - Key

    func testKeyStoredCorrectly() {
        let key = ValueKey<String>("my-texture")
        let widget = TextureWidget(key: key, textureId: 5)
        XCTAssertNotNil(widget.key)
    }

    func testKeyIsNilWhenNotProvided() {
        let widget = TextureWidget(textureId: 5)
        XCTAssertNil(widget.key)
    }

    // MARK: - Inheritance

    func testIsLeafRenderObjectWidget() {
        let widget = TextureWidget(textureId: 1)
        XCTAssertTrue(widget is LeafRenderObjectWidget)
    }

    func testIsWidget() {
        let widget = TextureWidget(textureId: 1)
        XCTAssertTrue(widget is Widget)
    }

    // MARK: - createRenderObject

    func testCreateRenderObjectReturnsTextureBox() {
        let widget = TextureWidget(textureId: 42)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context)
        XCTAssertTrue(renderObject is TextureBox)
    }

    func testCreateRenderObjectReturnsRenderObject() {
        let widget = TextureWidget(textureId: 42)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context)
        XCTAssertTrue(renderObject is RenderObject)
    }

    func testCreateRenderObjectHasCorrectTextureId() {
        let widget = TextureWidget(textureId: 99)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context) as! TextureBox
        XCTAssertEqual(renderObject.textureId, 99)
    }

    func testCreateRenderObjectHasCorrectFreeze() {
        let widget = TextureWidget(textureId: 1, freeze: true)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context) as! TextureBox
        XCTAssertTrue(renderObject.freeze)
    }

    func testCreateRenderObjectHasCorrectFilterQuality() {
        let widget = TextureWidget(textureId: 1, filterQuality: .high)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context) as! TextureBox
        XCTAssertEqual(renderObject.filterQuality, .high)
    }

    func testCreateRenderObjectWithDefaults() {
        let widget = TextureWidget(textureId: 7)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context) as! TextureBox
        XCTAssertEqual(renderObject.textureId, 7)
        XCTAssertFalse(renderObject.freeze)
        XCTAssertEqual(renderObject.filterQuality, .low)
    }

    // MARK: - updateRenderObject

    func testUpdateRenderObjectUpdatesTextureId() {
        let widget = TextureWidget(textureId: 50)
        let context = MockElement()
        let textureBox = TextureBox(textureId: 10)
        widget.updateRenderObject(context, renderObject: textureBox)
        XCTAssertEqual(textureBox.textureId, 50)
    }

    func testUpdateRenderObjectUpdatesFreeze() {
        let widget = TextureWidget(textureId: 1, freeze: true)
        let context = MockElement()
        let textureBox = TextureBox(textureId: 1, freeze: false)
        widget.updateRenderObject(context, renderObject: textureBox)
        XCTAssertTrue(textureBox.freeze)
    }

    func testUpdateRenderObjectUpdatesFilterQuality() {
        let widget = TextureWidget(textureId: 1, filterQuality: .high)
        let context = MockElement()
        let textureBox = TextureBox(textureId: 1, filterQuality: .low)
        widget.updateRenderObject(context, renderObject: textureBox)
        XCTAssertEqual(textureBox.filterQuality, .high)
    }

    func testUpdateRenderObjectUpdatesAllProperties() {
        let widget = TextureWidget(textureId: 100, freeze: true, filterQuality: .medium)
        let context = MockElement()
        let textureBox = TextureBox(textureId: 1, freeze: false, filterQuality: .low)
        widget.updateRenderObject(context, renderObject: textureBox)
        XCTAssertEqual(textureBox.textureId, 100)
        XCTAssertTrue(textureBox.freeze)
        XCTAssertEqual(textureBox.filterQuality, .medium)
    }

    // MARK: - Different textureId values

    func testDifferentTextureIdValues() {
        let ids = [0, 1, -1, 42, Int.max, Int.min, 999_999_999]
        for id in ids {
            let widget = TextureWidget(textureId: id)
            XCTAssertEqual(widget.textureId, id, "textureId should be \(id)")
        }
    }
}

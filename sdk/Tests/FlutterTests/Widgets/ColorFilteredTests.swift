// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
import FlutterSwiftBridge

/// Tests for ColorFiltered widget and ColorFilterRenderObject.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/color_filter_test.dart`
final class ColorFilteredTests: XCTestCase {

    // MARK: - Mock BuildContext

    private class MockElement: Element {
        init() { super.init(Widget()) }
    }

    // MARK: - Helper

    /// Creates a ColorFilter using mode constructor for testing.
    private func makeColorFilter(color: Color = Color(0xFFFF0000), blendMode: BlendMode = .srcOver) -> ColorFilter {
        return ColorFilter(mode: color, blendMode)
    }

    // MARK: - ColorFiltered Construction

    func testColorFilteredStoresColorFilter() {
        let filter = makeColorFilter()
        let widget = ColorFiltered(colorFilter: filter)
        XCTAssertEqual(widget.colorFilter, filter)
    }

    func testColorFilteredWithChild() {
        let filter = makeColorFilter()
        let child = Widget()
        let widget = ColorFiltered(colorFilter: filter, child: child)
        XCTAssertEqual(widget.colorFilter, filter)
        XCTAssertNotNil(widget.child)
    }

    func testColorFilteredWithKey() {
        let filter = makeColorFilter()
        let key = ValueKey<String>("color-filtered-key")
        let widget = ColorFiltered(colorFilter: filter, key: key)
        XCTAssertNotNil(widget.key)
    }

    func testColorFilteredWithAllParameters() {
        let filter = makeColorFilter()
        let child = Widget()
        let key = ValueKey<String>("all-params")
        let widget = ColorFiltered(colorFilter: filter, child: child, key: key)
        XCTAssertEqual(widget.colorFilter, filter)
        XCTAssertNotNil(widget.child)
        XCTAssertNotNil(widget.key)
    }

    func testColorFilteredDefaultChildIsNil() {
        let filter = makeColorFilter()
        let widget = ColorFiltered(colorFilter: filter)
        XCTAssertNil(widget.child)
    }

    func testColorFilteredDefaultKeyIsNil() {
        let filter = makeColorFilter()
        let widget = ColorFiltered(colorFilter: filter)
        XCTAssertNil(widget.key)
    }

    // MARK: - ColorFiltered.colorFilter property access

    func testColorFilterPropertyAccessWithModeFilter() {
        let filter = ColorFilter(mode: Color(0xFF00FF00), .srcIn)
        let widget = ColorFiltered(colorFilter: filter)
        XCTAssertEqual(widget.colorFilter, filter)
    }

    func testColorFilterPropertyAccessWithLinearToSrgbGamma() {
        let filter = ColorFilter(linearToSrgbGamma: ())
        let widget = ColorFiltered(colorFilter: filter)
        XCTAssertEqual(widget.colorFilter, filter)
    }

    func testColorFilterPropertyAccessWithSrgbToLinearGamma() {
        let filter = ColorFilter(srgbToLinearGamma: ())
        let widget = ColorFiltered(colorFilter: filter)
        XCTAssertEqual(widget.colorFilter, filter)
    }

    func testColorFilterPropertyAccessWithMatrixFilter() {
        let matrix: [Double] = [
            1, 0, 0, 0, 0,
            0, 1, 0, 0, 0,
            0, 0, 1, 0, 0,
            0, 0, 0, 1, 0,
        ]
        let filter = ColorFilter(matrix: matrix)
        let widget = ColorFiltered(colorFilter: filter)
        XCTAssertEqual(widget.colorFilter, filter)
    }

    // MARK: - Inheritance

    func testColorFilteredIsSingleChildRenderObjectWidget() {
        let filter = makeColorFilter()
        let widget = ColorFiltered(colorFilter: filter)
        XCTAssertTrue(widget is SingleChildRenderObjectWidget)
    }

    func testColorFilteredIsWidget() {
        let filter = makeColorFilter()
        let widget = ColorFiltered(colorFilter: filter)
        XCTAssertTrue(widget is Widget)
    }

    // MARK: - createRenderObject

    func testCreateRenderObjectReturnsColorFilterRenderObject() {
        let filter = makeColorFilter()
        let widget = ColorFiltered(colorFilter: filter)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context)
        XCTAssertTrue(renderObject is ColorFilterRenderObject)
    }

    func testCreateRenderObjectReturnsRenderObject() {
        let filter = makeColorFilter()
        let widget = ColorFiltered(colorFilter: filter)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context)
        XCTAssertTrue(renderObject is RenderObject)
    }

    func testCreateRenderObjectHasCorrectColorFilter() {
        let filter = ColorFilter(mode: Color(0xFF0000FF), .srcOver)
        let widget = ColorFiltered(colorFilter: filter)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context) as! ColorFilterRenderObject
        XCTAssertEqual(renderObject.colorFilter, filter)
    }

    // MARK: - updateRenderObject

    func testUpdateRenderObjectUpdatesColorFilter() {
        let filter1 = ColorFilter(mode: Color(0xFFFF0000), .srcOver)
        let filter2 = ColorFilter(mode: Color(0xFF00FF00), .srcIn)
        let widget = ColorFiltered(colorFilter: filter2)
        let context = MockElement()
        let renderObject = ColorFilterRenderObject(filter1)
        widget.updateRenderObject(context, renderObject: renderObject)
        XCTAssertEqual(renderObject.colorFilter, filter2)
    }

    // MARK: - ColorFilterRenderObject Construction

    func testColorFilterRenderObjectConstruction() {
        let filter = makeColorFilter()
        let renderObject = ColorFilterRenderObject(filter)
        XCTAssertEqual(renderObject.colorFilter, filter)
    }

    func testColorFilterRenderObjectWithDifferentFilters() {
        let modeFilter = ColorFilter(mode: Color(0xFF123456), .dst)
        let ro1 = ColorFilterRenderObject(modeFilter)
        XCTAssertEqual(ro1.colorFilter, modeFilter)

        let gammaFilter = ColorFilter(linearToSrgbGamma: ())
        let ro2 = ColorFilterRenderObject(gammaFilter)
        XCTAssertEqual(ro2.colorFilter, gammaFilter)
    }

    // MARK: - ColorFilterRenderObject.colorFilter getter

    func testColorFilterRenderObjectColorFilterGetter() {
        let filter = ColorFilter(mode: Color(0xFFABCDEF), .srcOver)
        let renderObject = ColorFilterRenderObject(filter)
        XCTAssertEqual(renderObject.colorFilter, filter)
    }

    // MARK: - ColorFilterRenderObject.colorFilter setter

    func testColorFilterRenderObjectSetSameValueDoesNothing() {
        let filter = ColorFilter(mode: Color(0xFFFF0000), .srcOver)
        let renderObject = ColorFilterRenderObject(filter)
        // Setting the same value should not change the filter
        renderObject.colorFilter = filter
        XCTAssertEqual(renderObject.colorFilter, filter)
    }

    func testColorFilterRenderObjectSetDifferentValue() {
        let filter1 = ColorFilter(mode: Color(0xFFFF0000), .srcOver)
        let filter2 = ColorFilter(mode: Color(0xFF00FF00), .srcIn)
        let renderObject = ColorFilterRenderObject(filter1)
        renderObject.colorFilter = filter2
        XCTAssertEqual(renderObject.colorFilter, filter2)
    }

    func testColorFilterRenderObjectSetDifferentFilterType() {
        let modeFilter = ColorFilter(mode: Color(0xFFFF0000), .srcOver)
        let gammaFilter = ColorFilter(linearToSrgbGamma: ())
        let renderObject = ColorFilterRenderObject(modeFilter)
        renderObject.colorFilter = gammaFilter
        XCTAssertEqual(renderObject.colorFilter, gammaFilter)
    }

    // MARK: - ColorFilterRenderObject.alwaysNeedsCompositingOverride

    func testAlwaysNeedsCompositingOverrideWhenChildIsNil() {
        let filter = makeColorFilter()
        let renderObject = ColorFilterRenderObject(filter)
        // child is nil by default (RenderProxyBox starts with no child)
        XCTAssertFalse(renderObject.alwaysNeedsCompositingOverride)
    }

    func testAlwaysNeedsCompositingOverrideWhenChildExists() {
        let filter = makeColorFilter()
        let renderObject = ColorFilterRenderObject(filter)
        // Add a child render box
        let childBox = RenderBox()
        renderObject.child = childBox
        XCTAssertTrue(renderObject.alwaysNeedsCompositingOverride)
    }

    // MARK: - ColorFilterRenderObject Inheritance

    func testColorFilterRenderObjectIsRenderProxyBox() {
        let filter = makeColorFilter()
        let renderObject = ColorFilterRenderObject(filter)
        XCTAssertTrue(renderObject is RenderProxyBox)
    }

    func testColorFilterRenderObjectIsRenderObject() {
        let filter = makeColorFilter()
        let renderObject = ColorFilterRenderObject(filter)
        XCTAssertTrue(renderObject is RenderObject)
    }

    // MARK: - ColorFilter Equality used in setter

    func testColorFilterEqualityForIdenticalFilters() {
        let filter1 = ColorFilter(mode: Color(0xFFFF0000), .srcOver)
        let filter2 = ColorFilter(mode: Color(0xFFFF0000), .srcOver)
        XCTAssertEqual(filter1, filter2)
    }

    func testColorFilterInequalityForDifferentColors() {
        let filter1 = ColorFilter(mode: Color(0xFFFF0000), .srcOver)
        let filter2 = ColorFilter(mode: Color(0xFF00FF00), .srcOver)
        XCTAssertNotEqual(filter1, filter2)
    }

    func testColorFilterInequalityForDifferentBlendModes() {
        let filter1 = ColorFilter(mode: Color(0xFFFF0000), .srcOver)
        let filter2 = ColorFilter(mode: Color(0xFFFF0000), .srcIn)
        XCTAssertNotEqual(filter1, filter2)
    }
}

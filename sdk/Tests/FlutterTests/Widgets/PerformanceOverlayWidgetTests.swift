// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter

/// Tests for PerformanceOverlay widget.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/performance_overlay_test.dart`
final class PerformanceOverlayTests: XCTestCase {

    // MARK: - Mock BuildContext

    private class MockElement: Element {
        init() { super.init(Widget()) }
    }

    // MARK: - Default constructor

    func testDefaultOptionsMaskIsZero() {
        let widget = PerformanceOverlay()
        XCTAssertEqual(widget.optionsMask, 0)
    }

    // MARK: - Custom optionsMask

    func testCustomOptionsMaskStoresGivenValue() {
        let widget = PerformanceOverlay(optionsMask: 42)
        XCTAssertEqual(widget.optionsMask, 42)
    }

    // MARK: - Key

    func testKeyIsNilByDefault() {
        let widget = PerformanceOverlay()
        XCTAssertNil(widget.key)
    }

    func testKeyStoredWhenProvided() {
        let key = ValueKey<String>("perf-overlay")
        let widget = PerformanceOverlay(key: key, optionsMask: 0)
        XCTAssertNotNil(widget.key)
    }

    // MARK: - allEnabled

    func testAllEnabledReturnsOverlayWithCorrectBitmask() {
        let overlay = PerformanceOverlay.allEnabled()
        let expectedMask: Int =
            1 << PerformanceOverlayOption.displayRasterizerStatistics.rawValue |
            1 << PerformanceOverlayOption.visualizeRasterizerStatistics.rawValue |
            1 << PerformanceOverlayOption.displayEngineStatistics.rawValue |
            1 << PerformanceOverlayOption.visualizeEngineStatistics.rawValue
        XCTAssertEqual(overlay.optionsMask, expectedMask)
    }

    func testAllEnabledBitmaskHasEachBitSet() {
        let overlay = PerformanceOverlay.allEnabled()
        let mask = overlay.optionsMask

        XCTAssertTrue(
            mask & (1 << PerformanceOverlayOption.displayRasterizerStatistics.rawValue) != 0,
            "displayRasterizerStatistics bit should be set"
        )
        XCTAssertTrue(
            mask & (1 << PerformanceOverlayOption.visualizeRasterizerStatistics.rawValue) != 0,
            "visualizeRasterizerStatistics bit should be set"
        )
        XCTAssertTrue(
            mask & (1 << PerformanceOverlayOption.displayEngineStatistics.rawValue) != 0,
            "displayEngineStatistics bit should be set"
        )
        XCTAssertTrue(
            mask & (1 << PerformanceOverlayOption.visualizeEngineStatistics.rawValue) != 0,
            "visualizeEngineStatistics bit should be set"
        )
    }

    func testAllEnabledWithKeyPassesKeyThrough() {
        let key = ValueKey<String>("all-enabled-key")
        let overlay = PerformanceOverlay.allEnabled(key: key)
        XCTAssertNotNil(overlay.key)
    }

    // MARK: - Inheritance

    func testIsLeafRenderObjectWidget() {
        let widget = PerformanceOverlay()
        XCTAssertTrue(widget is LeafRenderObjectWidget)
    }

    func testIsWidget() {
        let widget = PerformanceOverlay()
        XCTAssertTrue(widget is Widget)
    }

    // MARK: - createRenderObject

    func testCreateRenderObjectReturnsRenderPerformanceOverlay() {
        let widget = PerformanceOverlay(optionsMask: 7)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context)
        XCTAssertTrue(renderObject is RenderPerformanceOverlay)
    }

    func testCreateRenderObjectHasCorrectOptionsMask() {
        let widget = PerformanceOverlay(optionsMask: 7)
        let context = MockElement()
        let renderObject = widget.createRenderObject(context) as! RenderPerformanceOverlay
        XCTAssertEqual(renderObject.optionsMask, 7)
    }

    // MARK: - updateRenderObject

    func testUpdateRenderObjectUpdatesOptionsMask() {
        let widget = PerformanceOverlay(optionsMask: 15)
        let context = MockElement()
        let renderObject = RenderPerformanceOverlay(optionsMask: 0)
        widget.updateRenderObject(context, renderObject: renderObject)
        XCTAssertEqual(renderObject.optionsMask, 15)
    }
}

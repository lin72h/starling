// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import Flutter
import FlutterSwiftBridge

/// Tests for ScrollNotification and its subclasses.
///
/// **Dart Test Source:** `packages/flutter/test/widgets/scroll_notification_test.dart`
final class ScrollNotificationTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeMetrics(
        min: Double = 0,
        max: Double = 1000,
        pixels: Double = 500,
        viewport: Double = 600,
        axisDirection: AxisDirection = .down,
        devicePixelRatio: Double = 3.0
    ) -> FixedScrollMetrics {
        FixedScrollMetrics(
            minScrollExtent: min,
            maxScrollExtent: max,
            pixels: pixels,
            viewportDimension: viewport,
            axisDirection: axisDirection,
            devicePixelRatio: devicePixelRatio
        )
    }

    // MARK: - ScrollNotification Base

    func testScrollNotificationProperties() {
        let metrics = makeMetrics()
        let notification = ScrollStartNotification(metrics: metrics, context: nil)
        XCTAssertEqual(notification.depth, 0)
        XCTAssertNil(notification.context)
        XCTAssertNotNil(notification.metrics)
    }

    func testScrollNotificationDepthDefault() {
        let metrics = makeMetrics()
        let notification = ScrollStartNotification(metrics: metrics, context: nil)
        XCTAssertEqual(notification.depth, 0)
    }

    func testScrollNotificationDepthMutable() {
        let metrics = makeMetrics()
        let notification = ScrollStartNotification(metrics: metrics, context: nil)
        notification.depth = 3
        XCTAssertEqual(notification.depth, 3)
    }

    func testScrollNotificationDebugFillDescription() {
        let metrics = makeMetrics(pixels: 100.0)
        let notification = ScrollStartNotification(metrics: metrics, context: nil)
        var desc: [String] = []
        notification.debugFillDescription(&desc)
        let joined = desc.joined(separator: " ")
        XCTAssertTrue(joined.contains("depth: 0"))
        XCTAssertTrue(joined.contains("local"))
    }

    func testScrollNotificationDebugFillDescriptionRemote() {
        let metrics = makeMetrics()
        let notification = ScrollStartNotification(metrics: metrics, context: nil)
        notification.depth = 2
        var desc: [String] = []
        notification.debugFillDescription(&desc)
        let joined = desc.joined(separator: " ")
        XCTAssertTrue(joined.contains("depth: 2"))
        XCTAssertTrue(joined.contains("remote"))
    }

    // MARK: - ScrollStartNotification

    func testScrollStartNotificationNoDragDetails() {
        let metrics = makeMetrics()
        let notification = ScrollStartNotification(metrics: metrics, context: nil)
        XCTAssertNil(notification.dragDetails)
    }

    func testScrollStartNotificationWithDragDetails() {
        let metrics = makeMetrics()
        let details = DragStartDetails(globalPosition: Offset(10, 20))
        let notification = ScrollStartNotification(
            metrics: metrics,
            context: nil,
            dragDetails: details
        )
        XCTAssertNotNil(notification.dragDetails)
    }

    // MARK: - ScrollUpdateNotification

    func testScrollUpdateNotificationProperties() {
        let metrics = makeMetrics()
        let notification = ScrollUpdateNotification(
            metrics: metrics,
            context: nil,
            scrollDelta: 10.5
        )
        XCTAssertEqual(notification.scrollDelta, 10.5)
        XCTAssertNil(notification.dragDetails)
    }

    func testScrollUpdateNotificationCustomDepth() {
        let metrics = makeMetrics()
        let notification = ScrollUpdateNotification(
            metrics: metrics,
            context: nil,
            depth: 5
        )
        XCTAssertEqual(notification.depth, 5)
    }

    func testScrollUpdateNotificationDefaultDepth() {
        let metrics = makeMetrics()
        let notification = ScrollUpdateNotification(
            metrics: metrics,
            context: nil
        )
        XCTAssertEqual(notification.depth, 0)
    }

    func testScrollUpdateNotificationDebugDescription() {
        let metrics = makeMetrics()
        let notification = ScrollUpdateNotification(
            metrics: metrics,
            context: nil,
            scrollDelta: 25.0
        )
        var desc: [String] = []
        notification.debugFillDescription(&desc)
        let joined = desc.joined(separator: " ")
        XCTAssertTrue(joined.contains("scrollDelta"))
        XCTAssertTrue(joined.contains("25.0"))
    }

    // MARK: - OverscrollNotification

    func testOverscrollNotificationProperties() {
        let metrics = makeMetrics()
        let notification = OverscrollNotification(
            metrics: metrics,
            context: nil,
            overscroll: 15.0,
            velocity: 100.0
        )
        XCTAssertEqual(notification.overscroll, 15.0)
        XCTAssertEqual(notification.velocity, 100.0)
        XCTAssertNil(notification.dragDetails)
    }

    func testOverscrollNotificationNegativeOverscroll() {
        let metrics = makeMetrics()
        let notification = OverscrollNotification(
            metrics: metrics,
            context: nil,
            overscroll: -20.0
        )
        XCTAssertEqual(notification.overscroll, -20.0)
        XCTAssertEqual(notification.velocity, 0.0)
    }

    func testOverscrollNotificationDebugDescription() {
        let metrics = makeMetrics()
        let notification = OverscrollNotification(
            metrics: metrics,
            context: nil,
            overscroll: 15.5,
            velocity: 200.3
        )
        var desc: [String] = []
        notification.debugFillDescription(&desc)
        let joined = desc.joined(separator: " ")
        XCTAssertTrue(joined.contains("overscroll"))
        XCTAssertTrue(joined.contains("velocity"))
    }

    // MARK: - ScrollEndNotification

    func testScrollEndNotificationNoDragDetails() {
        let metrics = makeMetrics()
        let notification = ScrollEndNotification(metrics: metrics, context: nil)
        XCTAssertNil(notification.dragDetails)
    }

    // MARK: - UserScrollNotification

    func testUserScrollNotificationIdle() {
        let metrics = makeMetrics()
        let notification = UserScrollNotification(
            metrics: metrics,
            context: nil,
            direction: .idle
        )
        XCTAssertEqual(notification.direction, .idle)
    }

    func testUserScrollNotificationForward() {
        let metrics = makeMetrics()
        let notification = UserScrollNotification(
            metrics: metrics,
            context: nil,
            direction: .forward
        )
        XCTAssertEqual(notification.direction, .forward)
    }

    func testUserScrollNotificationReverse() {
        let metrics = makeMetrics()
        let notification = UserScrollNotification(
            metrics: metrics,
            context: nil,
            direction: .reverse
        )
        XCTAssertEqual(notification.direction, .reverse)
    }

    func testUserScrollNotificationDebugDescription() {
        let metrics = makeMetrics()
        let notification = UserScrollNotification(
            metrics: metrics,
            context: nil,
            direction: .forward
        )
        var desc: [String] = []
        notification.debugFillDescription(&desc)
        let joined = desc.joined(separator: " ")
        XCTAssertTrue(joined.contains("direction"))
    }

    // MARK: - defaultScrollNotificationPredicate

    func testDefaultPredicateDepthZero() {
        let metrics = makeMetrics()
        let notification = ScrollStartNotification(metrics: metrics, context: nil)
        notification.depth = 0
        XCTAssertTrue(defaultScrollNotificationPredicate(notification))
    }

    func testDefaultPredicateDepthNonZero() {
        let metrics = makeMetrics()
        let notification = ScrollStartNotification(metrics: metrics, context: nil)
        notification.depth = 1
        XCTAssertFalse(defaultScrollNotificationPredicate(notification))
    }

    func testDefaultPredicateDepthTwo() {
        let metrics = makeMetrics()
        let notification = ScrollUpdateNotification(metrics: metrics, context: nil)
        notification.depth = 2
        XCTAssertFalse(defaultScrollNotificationPredicate(notification))
    }

    // MARK: - All notification types are ScrollNotification

    func testAllTypesAreScrollNotification() {
        let metrics = makeMetrics()
        let start: ScrollNotification = ScrollStartNotification(metrics: metrics, context: nil)
        let update: ScrollNotification = ScrollUpdateNotification(metrics: metrics, context: nil)
        let overscroll: ScrollNotification = OverscrollNotification(metrics: metrics, context: nil, overscroll: 10.0)
        let end: ScrollNotification = ScrollEndNotification(metrics: metrics, context: nil)
        let user: ScrollNotification = UserScrollNotification(metrics: metrics, context: nil, direction: .idle)

        XCTAssertTrue(start is ScrollStartNotification)
        XCTAssertTrue(update is ScrollUpdateNotification)
        XCTAssertTrue(overscroll is OverscrollNotification)
        XCTAssertTrue(end is ScrollEndNotification)
        XCTAssertTrue(user is UserScrollNotification)
    }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest

@testable import Flutter

final class WidgetsServiceExtensionsTests: XCTestCase {

    // MARK: - WidgetsServiceExtensions rawValue tests

    func testAllWidgetsServiceExtensionsRawValues() {
        XCTAssertEqual(WidgetsServiceExtensions.debugDumpApp.rawValue, "debugDumpApp")
        XCTAssertEqual(WidgetsServiceExtensions.debugDumpFocusTree.rawValue, "debugDumpFocusTree")
        XCTAssertEqual(
            WidgetsServiceExtensions.showPerformanceOverlay.rawValue, "showPerformanceOverlay"
        )
        XCTAssertEqual(
            WidgetsServiceExtensions.didSendFirstFrameEvent.rawValue, "didSendFirstFrameEvent"
        )
        XCTAssertEqual(
            WidgetsServiceExtensions.didSendFirstFrameRasterizedEvent.rawValue,
            "didSendFirstFrameRasterizedEvent"
        )
        XCTAssertEqual(WidgetsServiceExtensions.fastReassemble.rawValue, "fastReassemble")
        XCTAssertEqual(
            WidgetsServiceExtensions.profileWidgetBuilds.rawValue, "profileWidgetBuilds"
        )
        XCTAssertEqual(
            WidgetsServiceExtensions.profileUserWidgetBuilds.rawValue, "profileUserWidgetBuilds"
        )
        XCTAssertEqual(WidgetsServiceExtensions.debugAllowBanner.rawValue, "debugAllowBanner")
    }

    // MARK: - WidgetsServiceExtensions RawRepresentable round-trip

    func testWidgetsServiceExtensionsRoundTrip() {
        let allCases: [WidgetsServiceExtensions] = [
            .debugDumpApp,
            .debugDumpFocusTree,
            .showPerformanceOverlay,
            .didSendFirstFrameEvent,
            .didSendFirstFrameRasterizedEvent,
            .fastReassemble,
            .profileWidgetBuilds,
            .profileUserWidgetBuilds,
            .debugAllowBanner,
        ]
        for expected in allCases {
            let reconstructed = WidgetsServiceExtensions(rawValue: expected.rawValue)
            XCTAssertEqual(reconstructed, expected)
        }
    }

    // MARK: - WidgetsServiceExtensions invalid rawValue

    func testWidgetsServiceExtensionsInvalidRawValue() {
        XCTAssertNil(WidgetsServiceExtensions(rawValue: "nonExistentExtension"))
        XCTAssertNil(WidgetsServiceExtensions(rawValue: ""))
        XCTAssertNil(WidgetsServiceExtensions(rawValue: "DebugDumpApp"))
    }

    // MARK: - WidgetInspectorServiceExtensions rawValue tests

    func testWidgetInspectorServiceExtensionsKeyRawValues() {
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.structuredErrors.rawValue, "structuredErrors"
        )
        XCTAssertEqual(WidgetInspectorServiceExtensions.show.rawValue, "show")
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.trackRebuildDirtyWidgets.rawValue,
            "trackRebuildDirtyWidgets"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.widgetLocationIdMap.rawValue, "widgetLocationIdMap"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.trackRepaintWidgets.rawValue, "trackRepaintWidgets"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.disposeAllGroups.rawValue, "disposeAllGroups"
        )
        XCTAssertEqual(WidgetInspectorServiceExtensions.disposeGroup.rawValue, "disposeGroup")
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.isWidgetTreeReady.rawValue, "isWidgetTreeReady"
        )
        XCTAssertEqual(WidgetInspectorServiceExtensions.disposeId.rawValue, "disposeId")
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.addPubRootDirectories.rawValue,
            "addPubRootDirectories"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.removePubRootDirectories.rawValue,
            "removePubRootDirectories"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getPubRootDirectories.rawValue,
            "getPubRootDirectories"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.setSelectionById.rawValue, "setSelectionById"
        )
        XCTAssertEqual(WidgetInspectorServiceExtensions.getParentChain.rawValue, "getParentChain")
        XCTAssertEqual(WidgetInspectorServiceExtensions.getProperties.rawValue, "getProperties")
        XCTAssertEqual(WidgetInspectorServiceExtensions.getChildren.rawValue, "getChildren")
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getChildrenSummaryTree.rawValue,
            "getChildrenSummaryTree"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getChildrenDetailsSubtree.rawValue,
            "getChildrenDetailsSubtree"
        )
        XCTAssertEqual(WidgetInspectorServiceExtensions.getRootWidget.rawValue, "getRootWidget")
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getRootWidgetTree.rawValue, "getRootWidgetTree"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getRootWidgetSummaryTree.rawValue,
            "getRootWidgetSummaryTree"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getRootWidgetSummaryTreeWithPreviews.rawValue,
            "getRootWidgetSummaryTreeWithPreviews"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getDetailsSubtree.rawValue, "getDetailsSubtree"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getSelectedWidget.rawValue, "getSelectedWidget"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getSelectedSummaryWidget.rawValue,
            "getSelectedSummaryWidget"
        )
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.isWidgetCreationTracked.rawValue,
            "isWidgetCreationTracked"
        )
        XCTAssertEqual(WidgetInspectorServiceExtensions.screenshot.rawValue, "screenshot")
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.getLayoutExplorerNode.rawValue,
            "getLayoutExplorerNode"
        )
        XCTAssertEqual(WidgetInspectorServiceExtensions.setFlexFit.rawValue, "setFlexFit")
        XCTAssertEqual(WidgetInspectorServiceExtensions.setFlexFactor.rawValue, "setFlexFactor")
        XCTAssertEqual(
            WidgetInspectorServiceExtensions.setFlexProperties.rawValue, "setFlexProperties"
        )
    }

    // MARK: - WidgetInspectorServiceExtensions RawRepresentable round-trip

    func testWidgetInspectorServiceExtensionsRoundTrip() {
        let representativeCases: [WidgetInspectorServiceExtensions] = [
            .structuredErrors,
            .show,
            .disposeAllGroups,
            .getRootWidget,
            .screenshot,
            .setFlexProperties,
        ]
        for expected in representativeCases {
            let reconstructed = WidgetInspectorServiceExtensions(rawValue: expected.rawValue)
            XCTAssertEqual(reconstructed, expected)
        }
    }

    // MARK: - WidgetInspectorServiceExtensions invalid rawValue

    func testWidgetInspectorServiceExtensionsInvalidRawValue() {
        XCTAssertNil(WidgetInspectorServiceExtensions(rawValue: "nonExistentExtension"))
        XCTAssertNil(WidgetInspectorServiceExtensions(rawValue: ""))
        XCTAssertNil(WidgetInspectorServiceExtensions(rawValue: "Show"))
    }
}

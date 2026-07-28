// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import StarlingRegistry

/// Window → app identity. Every case here is one a real client produces.
final class AppIdentityTests: XCTestCase {

    private func record(id: String, appIds: [String] = [],
                        titleMatches: [String] = []) -> AppRecord {
        AppRecord(
            id: id, name: id, kind: .host, order: 0, glyph: "externalApp",
            color: 0, dockOrder: nil, category: "", publisher: "", subtitle: "",
            sizeLabel: "", details: "", exec: id, windowRect: nil,
            installRecipe: nil, bins: [], desktopEntries: [], wmClasses: [],
            titleMatches: titleMatches, renameWindows: false, debURL: nil,
            debMarker: nil, desktopFile: nil, iconPath: nil, version: nil,
            installedAt: nil, installed: true,
            appIds: appIds.isEmpty ? [id] : appIds)
    }

    /// Clients are inconsistent about case: Chrome reports "google-chrome",
    /// VS Code reports "Code", GIMP reports "gimp".
    func testAppIdMatchIsCaseInsensitive() {
        let vscode = record(id: "vscode", appIds: ["Code"])
        XCTAssertTrue(vscode.matches(appId: "Code"))
        XCTAssertTrue(vscode.matches(appId: "code"))
        XCTAssertTrue(vscode.matches(appId: "CODE"))
        XCTAssertFalse(vscode.matches(appId: "codium"))
    }

    /// A client that names itself by its desktop file id may or may not
    /// include the suffix.
    func testDesktopSuffixIsIgnoredOnBothSides() {
        let telegram = record(id: "telegram", appIds: ["org.telegram.desktop"])
        XCTAssertTrue(telegram.matches(appId: "org.telegram.desktop"))
        XCTAssertTrue(telegram.matches(appId: "org.telegram.desktop.desktop"))

        let suffixed = record(id: "gimp", appIds: ["gimp.desktop"])
        XCTAssertTrue(suffixed.matches(appId: "gimp"))
    }

    func testEmptyAppIdNeverMatches() {
        XCTAssertFalse(record(id: "gimp").matches(appId: ""))
    }

    /// Title matching is opt-in per record, because it cannot be a general
    /// fallback: IntelliJ's project window is titled "untitled – Main.java".
    func testTitleMatchingOnlyAppliesToRecordsThatAskForIt() {
        let intellij = record(id: "intellij")
        XCTAssertFalse(intellij.matches(title: "untitled – Main.java"))
        XCTAssertFalse(intellij.matches(title: "Welcome to IntelliJ IDEA"))

        let zoom = record(id: "zoom", titleMatches: ["Zoom"])
        XCTAssertTrue(zoom.matches(title: "Zoom Meeting"))
        XCTAssertFalse(zoom.matches(title: "Slack | general"))
    }

    /// The WeChat case: its window is the whole rootful Xwayland screen.
    func testTitlePrefixMatchesXwaylandScreen() {
        let wechat = record(id: "wechat",
                            titleMatches: ["Xwayland on", "WeChat", "Weixin"])
        XCTAssertTrue(wechat.matches(title: "Xwayland on :1"))
        XCTAssertTrue(wechat.matches(title: "WeChat"))
    }
}

// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import StarlingRegistry

/// The key-file parser reads three different things — our catalog records, the
/// records app-install writes, and the host's `.desktop` entries — so its edge
/// cases are not academic. Each test here corresponds to a real shape found on
/// disk.
final class KeyFileTests: XCTestCase {

    func testReadsKeysAndSkipsCommentsAndBlanks() {
        let kf = KeyFile(text: """
            # a comment
            [Starling App]
            Id=intellij

            Name=IntelliJ IDEA
            """)
        XCTAssertEqual(kf.string("Id"), "intellij")
        XCTAssertEqual(kf.string("Name"), "IntelliJ IDEA")
        XCTAssertNil(kf.string("Missing"))
    }

    /// The trap that makes `.desktop` parsing subtle: an entry's action groups
    /// carry their own Icon and Name, and must never win over [Desktop Entry].
    /// Chrome's entry has three such groups.
    func testLaterGroupsDoNotOverrideTheWantedOne() {
        let text = """
            [Desktop Entry]
            Name=Google Chrome
            Icon=google-chrome

            [Desktop Action new-window]
            Name=New Window
            Icon=wrong-icon
            """
        let entry = KeyFile(text: text, group: "Desktop Entry")
        XCTAssertEqual(entry.string("Icon"), "google-chrome")
        XCTAssertEqual(entry.string("Name"), "Google Chrome")

        // With no group named, the first one claims the file.
        let implicit = KeyFile(text: text)
        XCTAssertEqual(implicit.string("Icon"), "google-chrome")
    }

    func testValueMayContainEqualsSigns() {
        let kf = KeyFile(text: "[G]\nExec=/usr/bin/app --flag=value\n")
        XCTAssertEqual(kf.string("Exec"), "/usr/bin/app --flag=value")
    }

    /// Empty is not the same as absent for our purposes — both mean "no value".
    func testEmptyValueReadsAsMissing() {
        let kf = KeyFile(text: "[G]\nIcon=\n")
        XCTAssertNil(kf.string("Icon"))
        XCTAssertEqual(kf.list("Icon"), [])
    }

    func testSemicolonListsTolerateTrailingSeparatorAndSpaces() {
        let kf = KeyFile(text: "[G]\nBins=/usr/bin/gimp; /usr/bin/gimp-3.2;\n")
        XCTAssertEqual(kf.list("Bins"), ["/usr/bin/gimp", "/usr/bin/gimp-3.2"])
    }

    func testIntAndRgb() {
        let kf = KeyFile(text: "[G]\nOrder=180\nColor=8A62C8\nHashed=#FF0000\nBad=zz\n")
        XCTAssertEqual(kf.int("Order"), 180)
        XCTAssertNil(kf.int("Bad"))
        XCTAssertEqual(kf.rgb("Color"), 0x8A62C8)
        XCTAssertEqual(kf.rgb("Hashed"), 0xFF0000)
        XCTAssertNil(kf.rgb("Bad"))
    }

    func testFirstOccurrenceWins() {
        let kf = KeyFile(text: "[G]\nName=first\nName=second\n")
        XCTAssertEqual(kf.string("Name"), "first")
    }

    func testMissingFileIsNil() {
        XCTAssertNil(KeyFile(path: "/nonexistent/definitely.app"))
    }
}

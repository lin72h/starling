// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import StarlingPower

/// A fake /sys/class/backlight: one device directory of one-line files,
/// exactly the kernel's layout.
private func fakeBacklight(brightness: Int, max: Int) throws -> String {
    let root = NSTemporaryDirectory() + "backlight-" + UUID().uuidString
    let dir = root + "/test_backlight"
    try FileManager.default.createDirectory(
        atPath: dir, withIntermediateDirectories: true)
    try "\(brightness)\n".write(toFile: dir + "/brightness",
                                atomically: true, encoding: .utf8)
    try "\(max)\n".write(toFile: dir + "/max_brightness",
                         atomically: true, encoding: .utf8)
    return root
}

@Suite struct BacklightReading {

    @Test func missingRootIsAbsentNotAnError() {
        let s = BacklightControl.read(root: "/nonexistent/backlight")
        #expect(!s.present)
    }

    @Test func desktopWithNoBacklight() throws {
        let root = NSTemporaryDirectory() + "backlight-" + UUID().uuidString
        try FileManager.default.createDirectory(
            atPath: root, withIntermediateDirectories: true)
        let s = BacklightControl.read(root: root)
        #expect(!s.present)
    }

    @Test func laptopReadsLevelAndScale() throws {
        let s = BacklightControl.read(root: try fakeBacklight(brightness: 600,
                                                              max: 1000))
        #expect(s.present)
        #expect(s.device == "test_backlight")
        #expect(s.brightness == 600)
        #expect(s.maxBrightness == 1000)
        #expect(s.percent == 60)
    }

    @Test func zeroMaxIsAbsent() throws {
        // A device that reports max_brightness=0 offers nothing to control;
        // treating it as present would divide by zero somewhere downstream.
        let s = BacklightControl.read(root: try fakeBacklight(brightness: 0,
                                                              max: 0))
        #expect(!s.present)
    }
}

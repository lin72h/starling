// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// Placeholder sources for the non-macOS build of the DSATool package.
//
// DSATool itself (`Sources/DSATool/main.swift`) drives DesktopShellApp through
// AppKit and CGWindowList, so it only exists on macOS. On Linux the equivalent
// is `build/shell-drive.py`, and this target stands in so the package still
// resolves and builds.
//
// It has to be a separate directory rather than a `#if os(macOS)` guard around
// `main.swift`: SwiftPM promotes any target containing a file *named*
// `main.swift` to an executable regardless of whether that file compiles to
// anything, and `build/stage.sh` stages every app that leaves a binary at
// `.build/<config>/<name>` — so the guarded version would ship an empty
// DSATool in the .deb. Pointing the Linux target at a directory with no main
// file keeps it a true library, which emits no such binary.

enum DSAToolUnavailable {
    /// What to use instead of DSATool on this platform.
    static let useInstead = "build/shell-drive.py"
}

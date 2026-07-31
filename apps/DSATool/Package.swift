// swift-tools-version: 6.0

import PackageDescription

// DSATool drives DesktopShellApp on macOS through AppKit and CGWindowList
// (click, screenshot, window info) — see `sdk/macos-compat/`, which develops
// macOS-first. Neither framework exists on Linux, where `build/shell-drive.py`
// does that job, so off macOS this package builds a placeholder library and
// `Sources/DSATool` is not compiled at all.
//
// Swapping the target's *path*, rather than guarding `main.swift` with
// `#if os(macOS)`, is the load-bearing part. SwiftPM promotes any target
// holding a file named `main.swift` to an executable even when the guard
// leaves it empty, and `build/stage.sh` stages every app that leaves a binary
// at `.build/<config>/<name>` — so the guarded form would ship an empty
// DSATool inside the .deb. This form emits no binary on Linux and leaves the
// macOS sources byte-identical.

#if os(macOS)
let platformConstraints: [SupportedPlatform] = [.macOS(.v14)]
let dsaTool: Target = .executableTarget(
    name: "DSATool",
    path: "Sources/DSATool"
)
#else
let platformConstraints: [SupportedPlatform] = []
let dsaTool: Target = .target(
    name: "DSAToolUnavailable",
    path: "Sources/DSAToolUnavailable"
)
#endif

let package = Package(
    name: "DSATool",
    platforms: platformConstraints.isEmpty ? nil : platformConstraints,
    targets: [dsaTool]
)

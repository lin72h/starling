// swift-tools-version: 6.0

import PackageDescription

// The app registry: one description of every app Starling knows about, shared
// by the shell (launcher + dock) and the App Store so neither hardcodes a
// catalog. Pure Foundation — no engine, no framework — so both packages can
// depend on it without pulling anything else in.
let package = Package(
    name: "StarlingRegistry",
    products: [
        .library(name: "StarlingRegistry", targets: ["StarlingRegistry"]),
    ],
    targets: [
        .target(name: "StarlingRegistry"),
        .testTarget(name: "StarlingRegistryTests",
                    dependencies: ["StarlingRegistry"]),
    ]
)

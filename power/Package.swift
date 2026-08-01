// swift-tools-version: 6.0

import PackageDescription

// The power layer: one sysfs-backed reading of battery state, shared by the
// shell (status-bar popup) and anything else that wants it. Pure Foundation —
// no engine, no framework — mirroring network/ and registry/, the other
// shared packages.
let package = Package(
    name: "StarlingPower",
    products: [
        .library(name: "StarlingPower", targets: ["StarlingPower"]),
    ],
    targets: [
        .target(name: "StarlingPower"),
        .testTarget(name: "StarlingPowerTests",
                    dependencies: ["StarlingPower"]),
    ]
)

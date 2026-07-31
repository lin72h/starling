// swift-tools-version: 6.0

import PackageDescription

// The network layer: one nmcli-backed implementation of WiFi state and
// control, shared by the shell (status-bar popup) and the Settings app so
// neither grows its own parser of nmcli output. Pure Foundation — no engine,
// no framework — mirroring registry/, the other shared package.
let package = Package(
    name: "StarlingNet",
    products: [
        .library(name: "StarlingNet", targets: ["StarlingNet"]),
    ],
    targets: [
        .target(name: "StarlingNet"),
        .testTarget(name: "StarlingNetTests",
                    dependencies: ["StarlingNet"]),
    ]
)

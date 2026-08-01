// swift-tools-version: 6.0

import PackageDescription

// The clock layer: systemd-timedated wrapped once (timedatectl), shared by
// Settings' Date & Time pane and anything else that wants it. Pure
// Foundation — no engine, no framework — mirroring network/, power/ and
// audio/, the other shared packages.
let package = Package(
    name: "StarlingTime",
    products: [
        .library(name: "StarlingTime", targets: ["StarlingTime"]),
    ],
    targets: [
        .target(name: "StarlingTime"),
        .testTarget(name: "StarlingTimeTests",
                    dependencies: ["StarlingTime"]),
    ]
)

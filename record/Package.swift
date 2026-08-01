// swift-tools-version: 6.0

import PackageDescription

// The screen-recording layer: ffmpeg spawned once and fed raw frames on
// stdin, plus the output naming under ~/Videos. Shared by the shell (the
// control-center Record tile) and anything else that wants it. Pure
// Foundation — no engine, no framework — mirroring audio/, network/,
// power/ and registry/, the other shared packages.
let package = Package(
    name: "StarlingRecord",
    products: [
        .library(name: "StarlingRecord", targets: ["StarlingRecord"]),
    ],
    targets: [
        .target(name: "StarlingRecord"),
        .testTarget(name: "StarlingRecordTests",
                    dependencies: ["StarlingRecord"]),
    ]
)

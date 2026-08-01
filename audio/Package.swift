// swift-tools-version: 6.0

import PackageDescription

// The audio layer: PipeWire's wpctl wrapped once, shared by Settings (the
// Sound pane) and anything else that wants it. Pure Foundation — no engine,
// no framework — mirroring network/, power/ and registry/, the other shared
// packages.
let package = Package(
    name: "StarlingAudio",
    products: [
        .library(name: "StarlingAudio", targets: ["StarlingAudio"]),
    ],
    targets: [
        .target(name: "StarlingAudio"),
        .testTarget(name: "StarlingAudioTests",
                    dependencies: ["StarlingAudio"]),
    ]
)

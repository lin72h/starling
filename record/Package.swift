// swift-tools-version: 6.0

import PackageDescription

// The screen-recording layer: the pipe encoder (ffmpeg spawned once and fed
// raw frames on stdin), the zero-copy encoder (CVaapiEncoder — dmabuf frames
// mapped into VAAPI in-process, ffmpeg's libraries dlopen'd so they are a
// build-time dependency but never a runtime hard one), and the output naming
// under ~/Videos. Shared by the shell (the control-center Record tile) and
// anything else that wants it. No engine, no framework — mirroring audio/,
// network/, power/ and registry/, the other shared packages. Building needs
// the libav*-dev headers (docs/BUILDING.md).
let package = Package(
    name: "StarlingRecord",
    products: [
        .library(name: "StarlingRecord", targets: ["StarlingRecord"]),
    ],
    targets: [
        .target(name: "CVaapiEncoder"),
        .target(name: "StarlingRecord", dependencies: ["CVaapiEncoder"]),
        .testTarget(name: "StarlingRecordTests",
                    dependencies: ["StarlingRecord"]),
    ]
)

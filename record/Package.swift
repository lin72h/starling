// swift-tools-version: 6.0

import PackageDescription

// The screen-recording layer: the pipe encoder (ffmpeg spawned once and fed
// raw frames on stdin), the zero-copy encoder (CVaapiEncoder — dmabuf frames
// imported into VA-API in-process, converted, encoded and muxed with no libav
// anywhere), and the output naming under ~/Videos. Shared by the shell (the
// control-center Record tile) and anything else that wants it. No engine, no
// framework — mirroring audio/, network/, power/ and registry/, the other
// shared packages.
//
// Building needs libva-dev only. libva is MIT and present wherever VA-API is,
// so it links directly — the same call the video player's CH264Decoder makes,
// in the other direction. This used to dlopen libavcodec/format/filter/util
// behind a soname check to keep GPL libraries off the runtime dependency
// list; writing the parameter sets, the H.264 headers and the MP4 index by
// hand removed the need for them entirely.
let package = Package(
    name: "StarlingRecord",
    products: [
        .library(name: "StarlingRecord", targets: ["StarlingRecord"]),
    ],
    targets: [
        .target(
            name: "CVaapiEncoder",
            linkerSettings: [.linkedLibrary("va"), .linkedLibrary("va-drm")]
        ),
        .target(name: "StarlingRecord", dependencies: ["CVaapiEncoder"]),
        .testTarget(name: "StarlingRecordTests",
                    dependencies: ["StarlingRecord"]),
    ]
)

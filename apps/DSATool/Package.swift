// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DSATool",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DSATool",
            path: "Sources/DSATool"
        ),
    ]
)

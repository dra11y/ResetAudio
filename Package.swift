// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "ResetAudio",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(
            name: "ResetAudio",
            targets: ["ResetAudio"]),
    ],
    targets: [
        .target(
            name: "ResetAudio",
            path: "Sources/ResetAudio",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        )
    ]
)

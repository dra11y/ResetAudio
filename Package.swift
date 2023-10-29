// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "WakeAudio",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(
            name: "WakeAudio",
            targets: ["WakeAudio"]),
    ],
    targets: [
        .target(
            name: "WakeAudio",
            path: "Sources/WakeAudio",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        )
    ]
)

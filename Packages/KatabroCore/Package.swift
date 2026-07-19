// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "KatabroCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "KatabroCore",
            targets: ["KatabroCore"]
        ),
    ],
    targets: [
        .target(
            name: "KatabroCore"
        ),
        .testTarget(
            name: "KatabroCoreTests",
            dependencies: ["KatabroCore"]
        ),
    ]
)

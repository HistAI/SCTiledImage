// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SCTiledImage",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v14),
        .tvOS(.v14)
    ],
    products: [
        .library(name: "SCTiledImage", targets: ["SCTiledImage"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SCTiledImage",
            dependencies: []
        )
    ]
)

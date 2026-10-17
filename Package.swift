// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Stitch",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "Stitch",
            targets: ["Stitch"]
        ),
    ],
    targets: [
        .target(
            name: "Stitch",
            resources: [.process("Resources")]
        ),
    ]
)

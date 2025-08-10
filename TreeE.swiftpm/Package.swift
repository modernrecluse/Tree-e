// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TreeE",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "TreeE",
            targets: ["TreeE"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeE",
            dependencies: []
        ),
    ]
)
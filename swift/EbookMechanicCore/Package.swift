// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EbookMechanicCore",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "EbookMechanicCore",
            targets: ["EbookMechanicCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "EbookMechanicCore",
            dependencies: []),
        .testTarget(
            name: "EbookMechanicCoreTests",
            dependencies: ["EbookMechanicCore"],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)

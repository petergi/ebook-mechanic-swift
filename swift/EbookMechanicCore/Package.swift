// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EbookMechanicCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "EbookMechanicCore",
            targets: ["EbookMechanicCore"]
        ),
    ],
    targets: [
        .target(
            name: "EbookMechanicCore"
        ),
        .testTarget(
            name: "EbookMechanicCoreTests",
            dependencies: ["EbookMechanicCore"],
            resources: []
        ),
    ],
    swiftLanguageModes: [.v6]
)

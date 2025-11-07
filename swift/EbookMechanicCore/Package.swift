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
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
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

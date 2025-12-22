// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EPUBMechanicCLI",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(path: "../EbookMechanicCore"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "EPUBMechanicCLI",
            dependencies: [
                .product(name: "EbookMechanicCore", package: "EbookMechanicCore")
            ]
        ),
        .testTarget(
            name: "EPUBMechanicCLITests",
            dependencies: ["EPUBMechanicCLI"]
        ),
    ]
)

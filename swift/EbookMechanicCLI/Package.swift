// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EbookMechanicCLI",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "../EbookMechanicCore"),
    ],
    targets: [
        .executableTarget(
            name: "EbookMechanicCLI",
            dependencies: [
                .product(name: "EbookMechanicCore", package: "EbookMechanicCore"),
            ]
        ),
        .testTarget(
            name: "EbookMechanicCLITests",
            dependencies: ["EbookMechanicCLI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EPUBMechanicCLI",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "../EbookMechanicCore"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
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
    ],
    swiftLanguageModes: [.v6]
)

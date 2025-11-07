// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EbookMechanicApp",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "../EbookMechanicCore"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "EbookMechanicApp",
            dependencies: [
                .product(name: "EbookMechanicCore", package: "EbookMechanicCore"),                
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EbookMechanicAppTests",
            dependencies: ["EbookMechanicApp"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

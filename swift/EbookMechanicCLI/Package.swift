// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "EbookMechanicCLI",
  platforms: [
    .macOS(.v12)
  ],
  dependencies: [
    .package(path: "../EbookMechanicCore"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "EbookMechanicCLI",
      dependencies: [
        .product(name: "EbookMechanicCore", package: "EbookMechanicCore"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "EbookMechanicCLITests",
      dependencies: ["EbookMechanicCLI"]
    ),
  ]
)

// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "TestUtils",
  platforms: [
    .macOS(.v12)
  ],
  dependencies: [
    .package(path: "../../../../../Packages/EbookMechanicCore")
  ],
  targets: [
    .executableTarget(
      name: "RemoveMetadata",
      dependencies: ["EbookMechanicCore"],
      path: "Sources/RemoveMetadata"
    )
  ]
)

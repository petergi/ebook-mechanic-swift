// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "TestUtils",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(path: "/Users/petergiannopoulos/Documents/Projects/Personal/Active/EbookMechanic/swift/EbookMechanicCore"),
    ],
    targets: [
        .executableTarget(
            name: "RemoveMetadata",
            dependencies: ["EbookMechanicCore"],
            path: "Sources/RemoveMetadata"
        )
    ]
)

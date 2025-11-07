# DocC Documentation Setup

## Issue Fixed

The original Makefile used an outdated DocC command syntax that is no longer supported in modern Swift toolchains. The error was:

```
error: Unknown subcommand or plugin name 'generate-documentation'
```

## Solution

The Makefile has been updated to support multiple DocC generation methods with automatic fallback:

### Method 1: Swift Package Plugin (Recommended)

If you have Swift 5.6+ with the DocC plugin, the Makefile will use:

```bash
swift package plugin generate-documentation
```

This is the modern approach and works with SwiftPM packages.

### Method 2: Xcode's xcodebuild

If the plugin isn't available but Xcode is installed, the Makefile falls back to:

```bash
xcodebuild docbuild -scheme EbookMechanicCore
```

This generates documentation using Xcode's built-in DocC support.

## Adding DocC Plugin to Your Packages

To enable the Swift Package Plugin method, add the DocC plugin to your `Package.swift` files:

### For EbookMechanicCore/Package.swift:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EbookMechanicCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "EbookMechanicCore", targets: ["EbookMechanicCore"]),
    ],
    dependencies: [
        // Add DocC plugin
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(name: "EbookMechanicCore"),
        .testTarget(name: "EbookMechanicCoreTests", dependencies: ["EbookMechanicCore"]),
    ]
)
```

### For EbookMechanicApp/Package.swift:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EbookMechanicApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "EbookMechanicApp", targets: ["EbookMechanicApp"]),
    ],
    dependencies: [
        .package(path: "../EbookMechanicCore"),
        // Add DocC plugin
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "EbookMechanicApp",
            dependencies: [
                .product(name: "EbookMechanicCore", package: "EbookMechanicCore"),
            ]
        ),
        .testTarget(
            name: "EbookMechanicAppTests",
            dependencies: ["EbookMechanicApp"]
        ),
    ]
)
```

### For EbookMechanicCLI/Package.swift:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EbookMechanicCLI",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../EbookMechanicCore"),
        // Add DocC plugin
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
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
    ]
)
```

## Usage

After adding the plugin dependency:

```bash
# Generate documentation for the core library
make docc-core

# Generate documentation for the app
make docc-app

# Serve documentation locally at http://localhost:8080
make docc-serve
```

## Output Locations

- **Core docs**: `EbookMechanicCore/.build/docc/`
- **App docs**: `EbookMechanicApp/.build/docc/`
- **Xcode-generated docs**: `.build/xcode-derived/Build/Products/Debug/`

## Alternative: Using Xcode Directly

If you prefer using Xcode:

1. Open `EbookMechanic.xcworkspace`
2. Select **Product → Build Documentation** (⌃⇧⌘D)
3. Xcode will build and open the documentation viewer

## Troubleshooting

### Plugin Not Found

If you get "plugin not found" errors:

```bash
# Update Swift dependencies
swift package resolve

# Or reset and refetch
swift package reset
swift package resolve
```

### Xcode Command Line Tools

Ensure Xcode Command Line Tools are properly configured:

```bash
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer

# If not, set it:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Permission Issues

If you get permission errors when writing to `.build/docc`:

```bash
# Clean the build directory
make clean

# Try again
make docc-core
```

## Documentation Comments

To write documentation that DocC can process, use triple-slash comments:

```swift
/// A file scanner that detects corrupted ebooks.
///
/// `FileScanner` recursively scans directories for ebook files and validates them.
///
/// ## Topics
///
/// ### Scanning Operations
/// - ``scanForCorruption(progress:)``
/// - ``scanForEmptyFolders(progress:)``
///
/// ### Repair Operations
/// - ``repairCorruptedFiles(progress:)``
/// - ``moveCorruptedFiles(progress:)``
public actor FileScanner {
    // ...
}
```

For more information, see [Apple's DocC Documentation](https://www.swift.org/documentation/docc/).

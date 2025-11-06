# Swift Workspace – EbookMechanic

This directory contains a modular Swift rewrite of the Go-based EbookMechanic toolchain. It ships as an Xcode workspace with three components that share a common Swift package and expose runnable test suites:

- `EbookMechanicCore` – a Swift Package library with the scanning, validation, repair, and reporting engine. It exposes an actor-based `FileScanner`, format-specific validators, and a Markdown report generator. Comprehensive XCTest coverage mirrors the Go implementation’s behaviours.
- `EbookMechanicCLI` – a command-line application that wraps the core package, providing a fast text interface with progress feedback, optional repair/move/delete automation, Markdown report generation, and unit tests that exercise configuration parsing.
- `EbookMechanicApp` – a macOS SwiftUI experience that lets you run scans visually, toggle behaviours, review summaries, and see corrupted files/empty folders in a polished, gradient-backed UI. View-model tests ensure the UI state behaves predictably.

## Workspace Layout

```
EbookMechanic.xcworkspace
├── EbookMechanicCore/Package.swift            # Core library + XCTest
├── EbookMechanicCLI/Package.swift             # CLI executable + XCTest
└── EbookMechanicApp/Package.swift             # SwiftUI app + XCTest
```

Open `EbookMechanic.xcworkspace` in Xcode 16+ to work across all targets, or use SwiftPM from the command line.

## Building & Testing

```bash
# Core library unit tests & build
cd EbookMechanicCore
SWIFT_MODULE_CACHE_PATH=.build/module-cache \
CLANG_MODULE_CACHE_PATH=.build/module-cache \
swift test --disable-sandbox

# CLI tests, then run the binary (prints help by default)
cd ../EbookMechanicCLI
SWIFT_MODULE_CACHE_PATH=.build/module-cache \
CLANG_MODULE_CACHE_PATH=.build/module-cache \
swift test --disable-sandbox
SWIFT_MODULE_CACHE_PATH=.build/module-cache \
CLANG_MODULE_CACHE_PATH=.build/module-cache \
swift run --disable-sandbox EbookMechanicCLI --help

# SwiftUI app tests & build (macOS)
cd ../EbookMechanicApp
SWIFT_MODULE_CACHE_PATH=.build/module-cache \
CLANG_MODULE_CACHE_PATH=.build/module-cache \
swift test --disable-sandbox
SWIFT_MODULE_CACHE_PATH=.build/module-cache \
CLANG_MODULE_CACHE_PATH=.build/module-cache \
swift build --disable-sandbox
```

## Benchmarking the CLIs

Compare the Go and Swift command-line implementations with the helper script,
which automatically generates a fresh sample library before every run (timings
are reported per run and averaged):

```bash
./scripts/benchmark.sh --iterations 5

# Pass additional options if required
./scripts/benchmark.sh --iterations 5 \
  --authors 5 \
  --go-args "-repair" \
  --swift-args "--repair --quiet"
```

Both CLIs run in dry-run/no-confirm mode by default; generated libraries are
discarded unless `--keep-libraries` is supplied. Build artifacts are cached
under `swift/.bench`.

> The environment uses sandboxed module caches, so we pin both `SWIFT_MODULE_CACHE_PATH` and `CLANG_MODULE_CACHE_PATH` to the local `.build` directory for convenience.

## CLI Usage Examples

```bash
# Scan current directory, no filesystem changes
ebook-mechanic --dry-run

# Scan a specific library and attempt repairs, auto-move to ARCHIVE
ebook-mechanic --dir ~/Books --repair --no-confirm --corrupted-dir ARCHIVE

# Only analyse empty folders and delete them automatically
ebook-mechanic --dir ~/Books --empty-folders-only --no-confirm --dry-run=false
```

## SwiftUI Highlights

- Quick directory picker using `NSOpenPanel` (macOS only)
- Live progress headlines and detail text driven by structured `ProgressEvent`s
- Toggle-driven options for dry run, repairs, automation, and reporting
- Dynamic summary cards + scrollable corrupted/empty lists styled with materials and gradients

## Core Library Highlights

- Native EPUB/MOBI/PDF validators (ZIP parsing, header checks, EOF detection)
- Repair routines (EPUB manifest rebuilding, PDF EOF restoration) with safe backups
- Actor-based `FileScanner` for concurrency-safe progress reporting
- Markdown report generator mirroring the Go tooling output structure.
- Extensive XCTest suite covering validators, repairs, scanners, and reporting, with additional smoke coverage for the CLI and SwiftUI app.

Feel free to extend the workspace with additional UI targets, alternative front-ends, or support for more ebook formats.

# Implementation Plan

1. **Analyse Go Reference** – Review the Go project to understand scanning, validation, repair, and reporting responsibilities.
2. **Design Swift Architecture** – Define modules for a reusable core library, CLI wrapper, and SwiftUI app, ensuring shared models and asynchronous progress APIs.
3. **Scaffold Projects** – Initialise SwiftPM packages (`EbookMechanicCore`, `EbookMechanicCLI`, `EbookMechanicApp`) and register them in `EbookMechanic.xcworkspace`.
4. **Port Core Logic** – Implement validators, repairers, custom ZIP handling, the `FileScanner` actor, and Markdown reporting. Remove templated files and organise source layout.
5. **Author Test Suites** – Write XCTest coverage for validation, repair, scanning, and reporting to mirror Go behaviour, plus target-specific smoke tests for the CLI parser and SwiftUI view model.
6. **Build CLI** – Implement flag parsing, progress printing, optional automation (repair/move/delete), and report generation using the core package.
7. **Build SwiftUI App** – Create `ScanViewModel`, SwiftUI `ContentView`, and polished UI with macOS directory picker and live progress.
8. **Integrate Tooling** – Provide a workspace Makefile and lightweight `.xcodeproj` wrappers so each scheme can build/run/test inside Xcode while delegating to SwiftPM.
9. **Documentation & Validation** – Update README and docs, and run `swift test/build/run` across packages to capture usage.

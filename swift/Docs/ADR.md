# Architectural Decision Record

## Context

The existing Go implementation of EbookMechanic provides a fast CLI with a rich TUI. The project now requires a modular Swift translation that supports a reusable core engine, a command-line frontend, and a SwiftUI macOS application. The solution must be well tested, engineered for reliability, and visually appealing.

## Decision

1. **Workspace Structure** – Adopt an Xcode workspace hosting three SwiftPM packages: `EbookMechanicCore` (library), `EbookMechanicCLI` (executable), and `EbookMechanicApp` (macOS SwiftUI app). Swift Package Manager keeps the build portable while the workspace offers integrated development in Xcode.
2. **Core Library Design** – Implement the scanning pipeline as an `actor` (`FileScanner`) to guarantee thread-safety and support asynchronous progress callbacks. Expose strongly typed models (`ScanResult`, `CorruptedFile`, `ProgressEvent`) to keep the API stable across front-ends.
3. **Validation Strategy** – Recreate Go’s validators natively in Swift, including ZIP inspection for EPUB, header checks for MOBI/PDF/AZW formats, and minimal repair logic (EOF injection, EPUB manifest regeneration). A lightweight custom ZIP reader/writer (`ZipArchive`) avoids external dependencies while retaining speed and control.
4. **Testing Commitment** – Mirror the original Go coverage with XCTest suites for validation, repair, scanning, and reporting. Add smoke-level suites for the CLI argument parser and SwiftUI view model so every target has native tests that can be executed via `swift test` or Xcode.
5. **CLI Interface** – Provide a batteries-included CLI with flag-driven behaviour (repair, dry-run, automation toggles, report generation). Progress feedback mirrors the Go TUI via textual output while keeping the implementation dependency-free and easily scriptable.
6. **SwiftUI Experience** – Create a desktop app with a modern gradient aesthetic, live progress indicators, and rich summaries. SwiftUI view state is orchestrated by the shared `ScanViewModel`, ensuring consistent behaviour with the CLI. macOS-specific affordances (e.g., `NSOpenPanel`) are encapsulated behind build flags.
7. **Makefile + Xcode Projects** – Maintain a top-level Makefile with targets for build/run/test of every component and create lightweight `.xcodeproj` wrappers per package so developers can build or test via Xcode schemes that simply delegate to the make recipes.
8. **Shared Documentation** – Add a repository-level README and Docs folder capturing build commands, usage examples, architectural decisions, and outstanding tasks to ensure the workspace remains approachable.

## Consequences

- Shared logic in `EbookMechanicCore` guarantees consistent behaviour (validation, repair, reports) across CLI and GUI front-ends and simplifies future experimentation (e.g., a visionOS app).
- The custom ZIP implementation removes external dependencies but requires continued maintenance if ZIP edge cases arise in the future.
- Actor-based scanning and async progress APIs simplify concurrency but require Swift 6 toolchains.
- SwiftPM-based packaging lowers the barrier to command-line builds but surfaces sandbox cache warnings in restricted environments; documentation mitigates this by pinning cache paths.
- The Makefile + legacy Xcode targets add a thin layer over SwiftPM, keeping IDE workflows working at the cost of maintaining simple project files.

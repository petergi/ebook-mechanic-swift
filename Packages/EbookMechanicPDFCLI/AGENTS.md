# Repository Guidelines

## Project Structure & Module Organization
- `Apps/EbookMechanicApp/`: SwiftUI macOS app.
- `Packages/EbookMechanicCore/`: core library used by all tools.
- `Packages/EbookMechanicCLI/`: all-in-one CLI.
- `Packages/EbookMechanicEPUBCLI/` and `Packages/EbookMechanicPDFCLI/`: specialized CLIs.
- `Docs/Swift/`: Swift documentation entry point.
- `Scripts/`: developer utilities (benchmarks, test helpers).
- Root `Makefile` and `Makefile.swift`: unified build/test/run targets.

## Build, Test, and Development Commands
- `make build`: build app + main CLI.
- `make build-all`: build every target (all CLIs + app).
- `make run-ebook-mechanic-app`: run the macOS app.
- `make run-epub-mechanic-cli` / `make run-pdf-mechanic-cli`: run specialized CLIs.
- `make test`: run core + CLI + app tests.
- `make test-all`: run all test suites.
- `make check-format`: lint formatting with swift-format.
- `make lint`: run SwiftLint.
- `make ci`: build-all + test-all + check-format.

## Coding Style & Naming Conventions
- Swift formatting is enforced via `swift-format` (`make format` / `make check-format`).
- Linting uses SwiftLint (`make lint`).
- Make targets follow the `action-target` naming pattern (e.g., `test-core`, `build-cli`).
- Prefer module-prefixed names that mirror package boundaries (e.g., `EbookMechanicCore`, `EbookMechanicCLI`).

## Testing Guidelines
- Tests are XCTest-based and live under `*/Tests` for each package/app.
- Use `make test` for the default suite and `make test-all` for full coverage.
- External tool integration is exercised via `scripts/test-external-tools.sh`.

## Commit & Pull Request Guidelines
- Commit messages follow a conventional style: `type: short description` (e.g., `docs: ...`, `build: ...`, `refactor: ...`).
- PRs should include a short summary, list of commands run, and screenshots for UI changes.

## Configuration & Tooling Notes
- MCP gateway setup is documented in `DOCKER_MCP.md`.
- If a command depends on external tools, note versions or install steps in the PR description.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EbookMechanic is a multi-language ebook library management toolkit with implementations in **Go**, **Swift**, and **Python**. It validates ebook files (EPUB, MOBI, AZW3, AZW4, PDF), detects corruption, repairs files, and cleans up empty folders.

The repository is organized into language-specific directories:
- **golang/** - Production Go implementation with Bubble Tea TUI
- **swift/** - Native Swift implementation with CLI + macOS SwiftUI app
- **python/** - Original Python scripts and test library generator
- **scripts/** - Cross-language benchmarking utilities

## Repository Structure

```
EbookMechanic/
├── golang/          # Go implementation (primary CLI with TUI)
├── swift/           # Swift workspace (Core + CLI + macOS App)
├── python/          # Python scripts + test library generator
└── scripts/         # Benchmark scripts comparing implementations
```

## Build & Test Commands

### Go Implementation (golang/)

```bash
cd golang

# Build optimized binary
make build

# Run without building
make run
go run .

# Run tests with coverage
make test
make test-coverage

# Code quality checks
make check        # fmt + vet + lint
make lint

# Generate sample test library (10 authors, all formats)
make sample-library

# Cross-platform builds
make build-all    # Linux, macOS (Intel/ARM), Windows
```

**Key Go flags:**
- `-dir <path>` - Directory to scan
- `-dry-run` - Scan only, no modifications
- `-repair` - Attempt automatic repairs
- `-corruption-only` - Skip empty folder detection
- `-empty-folders-only` - Skip corruption detection
- `-no-tui` - Simple text output mode
- `-no-confirm` - Skip confirmation prompts

### Swift Implementation (swift/)

```bash
cd swift

# Run core library tests
make core-test

# Build and run CLI
make cli-build
make cli-run ARGS="--help"

# Build and test macOS SwiftUI app
make app-build
make app-test

# Open Xcode workspace
make workspace

# Clean build artifacts
make clean
```

**Swift module cache environment:**
All Swift commands use sandboxed module caches via `SWIFT_MODULE_CACHE_PATH` and `CLANG_MODULE_CACHE_PATH` set to `.build/module-cache` to avoid global cache conflicts.

**CLI flags (Swift):**
- `-d, --dir <path>` - Directory to scan
- `--dry-run` - Scan only
- `-r, --repair` - Attempt repairs
- `--corruption-only` - Skip empty folders
- `--empty-folders-only` - Only check empty folders
- `--no-confirm` - Auto-confirm all prompts
- `--quiet` - Reduce output
- `--report` - Generate Markdown report

### Benchmarking (scripts/)

Compare Go vs Swift implementations:

```bash
# Run 5 iterations per implementation
./scripts/benchmark.sh --iterations 5

# Custom settings
./scripts/benchmark.sh \
  --iterations 5 \
  --authors 10 \
  --formats pdf,epub,mobi \
  --go-args "-repair" \
  --swift-args "--repair --quiet"
```

The benchmark script:
1. Builds both Go and Swift CLIs (release mode)
2. Generates fresh libraries per iteration using `python/generate_test_library.py`
3. Runs both implementations in dry-run mode
4. Reports per-run timings and averages

### Test Library Generator (python/)

```bash
# Generate sample library with 10 authors, all formats
python3 python/generate_test_library.py \
  --output test-library \
  --authors 10 \
  --formats pdf,epub,mobi,azw3,azw4 \
  --force

# Minimal library (PDF and EPUB only)
python3 python/generate_test_library.py \
  --output fixtures \
  --authors 3 \
  --formats pdf,epub \
  --force
```

The generator creates:
- Valid and corrupt pairs for each format
- Nested author/book directory structure
- Empty folders for cleanup testing

## Architecture Deep Dive

### Go Implementation (golang/)

**File Structure:**
- `main.go` - Entry point + Bubble Tea TUI state machine
- `scanner.go` - File system operations + concurrent scanning
- `validator.go` - Format-specific validation logic
- `report.go` - Markdown report generation

**TUI State Machine (main.go):**
Phase-based progression: `PhaseInit → PhaseScanning → PhaseMoving → PhaseScanningFolders → PhaseDeleting → PhaseGeneratingReport → PhaseDone`

Each phase transition is message-driven using Bubble Tea's `tea.Cmd` pattern. Progress updates flow through buffered channels (capacity: 100) to the TUI event loop.

**Scanner Algorithm (scanner.go):**
- **Two-pass corruption scan:** First pass counts files for progress tracking, second pass validates each file
- **Bottom-up folder traversal:** Empty folders are evaluated from deepest to shallowest, ensuring children are checked before parents
- **CORRUPTED directory skipping:** Always skip `CORRUPTED/` directory using `filepath.SkipDir` to avoid re-scanning moved files
- **Mutex-protected results:** `sync.Mutex` guards shared `ScanResult` data during concurrent operations

**Validation Logic (validator.go):**
- **EPUB:** ZIP structure validation + `mimetype` file (exact content: `application/epub+zip`) + `META-INF/container.xml` presence
- **MOBI:** PalmDB header check + identifier at bytes 60-68 (`BOOKMOBI` or `TEXtREAd`)
- **AZW3:** Delegates to MOBI validator (Kindle Format 8 uses MOBI/PalmDB structure)
- **AZW4:** Delegates to PDF validator (PDF wrapper format)
- **PDF:** Header validation (`%PDF-`) + EOF marker (`%%EOF` in last 1KB)

**Critical Implementation Details:**
- Directory hierarchy is preserved when moving corrupted files to `CORRUPTED/` using `filepath.Rel()` and `filepath.Join()`
- Progress callbacks are optional: always check `if fs.progressCallback != nil` before calling
- Report format: `ebook_manager_report_YYYY-MM-DD_HH-MM-SS.md`

### Swift Implementation (swift/)

**Workspace Structure:**
Three SwiftPM packages in `EbookMechanic.xcworkspace`:

1. **EbookMechanicCore** (swift/EbookMechanicCore/) - Core library
   - `FileScanner` - Actor-based scanner for thread-safe concurrency
   - `FileValidator` - Format-specific validators
   - `FileRepairer` - Automatic repair engine (EPUB manifest, PDF EOF)
   - `ZipArchive` - Custom ZIP implementation (no external dependencies)
   - `MarkdownReportGenerator` - Report generation

2. **EbookMechanicCLI** (swift/EbookMechanicCLI/) - Command-line interface
   - Flag parsing with configuration struct
   - Progress printer with emoji feedback
   - Interactive prompts with auto-confirm mode
   - Depends on EbookMechanicCore

3. **EbookMechanicApp** (swift/EbookMechanicApp/) - macOS SwiftUI app
   - `ScanViewModel` - Observable view model shared with CLI logic
   - `ContentView` - Gradient UI with live progress, toggle controls
   - Directory picker using `NSOpenPanel`
   - Scrollable corrupted/empty folder lists

**Actor-Based Concurrency (FileScanner.swift):**
- `FileScanner` is an `actor` for guaranteed thread safety
- All methods are async and await-able
- Progress events are `Sendable` structs with structured stages
- No manual locking required—Swift 6 strict concurrency enforced

**Validation Strategy (FileValidator.swift):**
- EPUB: ZIP validation + `mimetype` + `META-INF/container.xml` checks
- MOBI/AZW3: Header bytes 60-68 must contain `BOOKMOBI` or `TEXtREAd`
- PDF/AZW4: Header `%PDF-` + `%%EOF` in last 1KB
- Returns `ValidationResult(isValid: Bool, reason: String)`

**Repair Capabilities (FileRepairer.swift):**
- EPUB: Auto-adds missing `mimetype` and `META-INF/container.xml` files
- PDF: Appends missing `%%EOF` markers
- MOBI/AZW3: Returns helpful message suggesting Calibre conversion
- Creates `.backup` files before repairs, restores on failure

**Key Implementation Details:**
- Platform support: macOS 13+, iOS 16+
- Swift language mode: 6 (strict concurrency)
- Module caches are sandboxed to `.build/module-cache` per package
- All tests use `--disable-sandbox` flag for file system access
- Custom ZIP implementation avoids external dependencies but requires maintenance for edge cases

### Python Scripts (python/)

**Primary Scripts:**
- `generate_test_library.py` - Creates test fixtures with valid/corrupt files
- `ebook_manager_tui.py` - Original Python TUI implementation (reference)
- `ebook_manager.py` - Core Python validation logic
- `check_corrupted_ebooks.py` - Standalone corruption checker
- `delete_empty_ebook_folders.py` - Standalone folder cleanup

**Generator Output:**
Creates author/book hierarchy with paired valid and corrupt files for all formats. Includes empty folders and nested structures for comprehensive testing.

## Common Development Patterns

### Adding a New Ebook Format

**Go (golang/):**
1. Add extension to `EbookExtensions` map in `NewFileScanner()` (scanner.go)
2. Create `Validate[FORMAT]()` function in validator.go
3. Add case to `ValidateFile()` switch statement
4. Update `ScanResult` struct with `[FORMAT]Total` and `[FORMAT]Corrupted` fields
5. Update statistics tracking in scanner.go (both counting and validation passes)
6. Update report.go to include format in tables
7. Update main.go TUI statistics display
8. Add comprehensive tests in validator_test.go

**Swift (swift/EbookMechanicCore/):**
1. Add case to `EbookFileType` enum (Models.swift)
2. Implement validator in FileValidator.swift
3. Add repair logic to FileRepairer.swift (if applicable)
4. Update tests in ValidationTests.swift and RepairTests.swift

### Modifying the Go TUI

- Phases are defined in the `Phase` enum (main.go:50-61)
- Add new phase transition messages as structs (e.g., `type newPhaseMsg struct{}`)
- Handle messages in `Update()` for state transitions
- Render UI in `View()` method
- Use Lipgloss for styling (pink titles, green success, red errors, cyan info)

### Working with File Scanners

**Go (scanner.go):**
- Scanner operations return `tea.Cmd` for TUI integration in TUI mode
- Use `fs.mu.Lock()` when modifying shared `ScanResult` data
- Progress callbacks are optional: `if fs.progressCallback != nil`
- Always skip CORRUPTED directory: `if filepath.Base(path) == "CORRUPTED" { return filepath.SkipDir }`

**Swift (FileScanner.swift):**
- All scanner methods are `async` and actor-isolated
- Pass progress handler: `progress: ((ProgressEvent) -> Void)?`
- Progress events have structured stages: `.scanningFiles`, `.validatingFile(URL)`, `.repairingFiles`, etc.
- Last result is cached in `lastResult` property for subsequent operations

## File Format Validation Reference

### EPUB Files
- Must be valid ZIP (use `archive/zip` in Go, custom `ZipArchive` in Swift)
- Required file: `mimetype` with exact content `application/epub+zip`
- Required file: `META-INF/container.xml` (non-empty)

### MOBI Files
- Check bytes 60-68 for identifier: `BOOKMOBI` or `TEXtREAd`
- Validate PalmDB header structure (first 32 bytes must not be all zeros)
- Minimum size: 68 bytes

### AZW3 Files (Kindle Format 8)
- Use MOBI validation (based on MOBI/PalmDB structure)
- Same header checks as MOBI

### AZW4 Files (Kindle PDF Wrapper)
- Use PDF validation
- Same structure requirements as PDF

### PDF Files
- Header: Must start with `%PDF-`
- Minimum size: 100 bytes (Go) or 5 bytes (Swift)
- EOF marker: Last 1KB must contain `%%EOF`

## Testing Strategy

### Go Tests
- **validator_test.go:** 45+ tests covering all formats, valid/invalid cases, edge cases
- **scanner_test.go:** 15+ tests for file scanning, corruption detection, folder operations
- **report_test.go:** 10+ tests for report generation and formatting

Coverage target: 46%+ (use `make test-coverage` to view)

### Swift Tests
- **ValidationTests.swift:** Format-specific validation tests
- **RepairTests.swift:** Automatic repair functionality
- **ScannerTests.swift:** File scanning and folder operations
- **ReportGeneratorTests.swift:** Markdown report generation
- **CLIConfigurationTests.swift:** CLI argument parsing
- **ScanOptionsTests.swift:** SwiftUI view model behavior

All tests: 19 total (10 core + 6 CLI + 3 app)

## Performance Characteristics

**Go vs Swift Benchmarking:**
Use `scripts/benchmark.sh` to compare implementations on identical generated libraries. Typical results on 10,000 files:
- Go: ~5-10 seconds (compiled, goroutines, Bubble Tea TUI)
- Swift: ~8-12 seconds (compiled, actor-based concurrency)
- Python: ~30-45 seconds (interpreted, Rich library)

**Optimization Notes:**
- Go uses two-pass scanning to maintain accurate progress tracking
- Swift uses actor isolation for automatic thread safety without manual locks
- Both implementations skip CORRUPTED directory to avoid redundant scanning
- File validation is I/O-bound; format-specific validators use minimal memory

## Important File Paths & Conventions

**Generated Artifacts:**
- Corrupted files: `{rootDir}/CORRUPTED/` (preserves directory structure)
- Go reports: `ebook_manager_report_YYYY-MM-DD_HH-MM-SS.md`
- Swift reports: `ebook_mechanic_report_YYYY-MM-DD_HH-MM-SS.md`
- Test libraries: `test-library/` (default, configurable)

**Build Artifacts:**
- Go binaries: `golang/build/ebook-mechanic`, `golang/dist/ebook-mechanic-*`
- Swift builds: `swift/*/‌.build/` (per-package subdirectories)
- Benchmark cache: `swift/.bench/`

**Extensions:**
- Supported (case-insensitive): `.epub`, `.mobi`, `.azw3`, `.azw4`, `.pdf`
- Backup files (Swift repairs): `*.backup`

## Cross-Implementation Compatibility

All three implementations (Go, Swift, Python) use the same:
- Validation rules for each format
- CORRUPTED directory naming convention
- Markdown report structure (minor formatting differences)
- Empty folder detection algorithm (bottom-up traversal)

This allows benchmarking, testing, and cross-validation between implementations.

## Dependencies

**Go (golang/go.mod):**
- `github.com/charmbracelet/bubbletea` v0.25.0 - TUI framework
- `github.com/charmbracelet/lipgloss` v0.9.1 - Styling
- `github.com/charmbracelet/bubbles` v0.18.0 - TUI components

**Swift (Package.swift files):**
- No external dependencies (custom ZIP implementation)
- Swift 6.2 toolchain required
- Platforms: macOS 13+, iOS 16+

**Python (python/):**
- Standard library only for `generate_test_library.py`
- Original TUI scripts use `rich` library (optional, legacy)

## Makefile Commands Reference

**Go (golang/Makefile):**
- `make build` - Optimized binary
- `make test` - Run all tests
- `make check` - fmt + vet + lint
- `make sample-library` - Generate test fixtures
- `make build-all` - Cross-platform builds

**Swift (swift/Makefile):**
- `make core-test` - Core library tests
- `make cli-build` - Build CLI
- `make app-build` - Build SwiftUI app
- `make workspace` - Open in Xcode
- `make clean` - Clean artifacts

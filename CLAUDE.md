# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EbookMechanic is a Swift-based ebook library management toolkit with helper Python scripts for fixture generation. It validates ebook files (EPUB, MOBI, AZW3, AZW4, PDF), detects corruption, repairs files when possible, and cleans up empty folders.

**Current Status (November 2025):**

- **Swift**: Full-featured implementation with CLI(s) + native macOS SwiftUI app, actor-based concurrency

The repository is organized into directories:

- **Apps/** + **Packages/** - Native Swift implementation with CLI(s) + macOS SwiftUI app
- **Scripts/** - Cross-language benchmarking utilities and test library generator

## Repository Structure

```text
EbookMechanic/
├── Apps/
│  └── EbookMechanicApp/             # macOS SwiftUI app (SwiftPM)
├── Packages/
│  ├── EbookMechanicCore/            # Core library package
│  ├── EbookMechanicCLI/             # Command-line interface
│  ├── EbookMechanicEPUBCLI/         # EPUB-focused CLI
│  └── EbookMechanicPDFCLI/          # PDF-focused CLI
├── Docs/
│  └── Swift/                        # Swift documentation
├── Scripts/                         # Benchmarking + helper scripts
├── EbookMechanic.xcworkspace        # Xcode workspace (optional)
├── Makefile.swift                   # Swift build automation
└── completions/                     # Generated shell completions
   ├── ebook-mechanic.bash
   ├── _ebook-mechanic
   ├── ebook-mechanic.fish
   └── ebook-mechanic.ps1
```

## Build & Test Commands

Swift Implementation (repo root, Makefile.swift)

```bash
# Core library
make -f Makefile.swift build-core         # Build core library
make -f Makefile.swift test-core          # Run core tests

# Main CLI
make -f Makefile.swift build-cli          # Build main CLI
make -f Makefile.swift run-cli ARGS="..." # Run main CLI
make -f Makefile.swift test-cli           # Test main CLI

# macOS SwiftUI app
make -f Makefile.swift build-app          # Build app
make -f Makefile.swift test-app           # Test app
make -f Makefile.swift run-app            # Launch app

# Specialized CLIs (EPUB and PDF)
make -f Makefile.swift build-specialized  # Build both specialized CLIs
make -f Makefile.swift build-epub         # Build EPUB Mechanic CLI
make -f Makefile.swift build-pdf          # Build PDF Mechanic CLI
make -f Makefile.swift test-epub          # Test EPUB Mechanic CLI
make -f Makefile.swift test-pdf           # Test PDF Mechanic CLI
make -f Makefile.swift run-epub ARGS="..."# Run EPUB Mechanic CLI
make -f Makefile.swift run-pdf ARGS="..." # Run PDF Mechanic CLI

# Build everything
make -f Makefile.swift build-all          # Build core + all CLIs + app
make -f Makefile.swift test-all           # Test everything
make -f Makefile.swift build-release      # Optimized release builds

# Install CLIs
make -f Makefile.swift install              # Install main CLI (debug)
make -f Makefile.swift install-release      # Install main CLI (release)
make -f Makefile.swift install-specialized  # Install EPUB + PDF CLIs
make -f Makefile.swift install-epub         # Install EPUB CLI (debug)
make -f Makefile.swift install-epub-release # Install EPUB CLI (release)
make -f Makefile.swift install-pdf          # Install PDF CLI (debug)
make -f Makefile.swift install-pdf-release  # Install PDF CLI (release)

# Uninstall
make -f Makefile.swift uninstall             # Uninstall main CLI
make -f Makefile.swift uninstall-specialized # Uninstall specialized CLIs
make -f Makefile.swift uninstall-epub        # Uninstall EPUB CLI
make -f Makefile.swift uninstall-pdf         # Uninstall PDF CLI

# Utilities
make -f Makefile.swift workspace          # Open Xcode workspace
make -f Makefile.swift clean              # Remove build artifacts
make -f Makefile.swift clean-all          # Deep clean (includes docs/completions)
make -f Makefile.swift info               # Show build information
make -f Makefile.swift installExternalTools # Print/install external tool helpers
```

**Swift module cache environment:**
All Swift commands use sandboxed module caches via `SWIFT_MODULE_CACHE_PATH` and `CLANG_MODULE_CACHE_PATH` set to `.build/module-cache` to avoid global cache conflicts.

**CLI flags (Swift):**

- `-d, --dir <path>` - Directory to scan
- `--dry-run` - Scan only
- `-r, --repair` - Attempt repairs
- `--corruption-only` - Skip empty folders
- `--empty-folders-only` - Only check empty folders
- `--auto-confirm` - Auto-confirm all prompts
- `--verbose` - Enable verbose logging
- `--report` - Generate report files
- `--report-format` - Single report format
- `--report-formats <csv>` - Report formats (markdown,json,csv,html)
- `--use-epubcheck` - Enable epubcheck for EPUB-only checks
- `--external-tools` - Enable epubcheck/pdfcpu validation
- `--max-concurrent <n>` - Max concurrent validations
- `--no-cache` - Disable validation cache
- `--performance-stats` - Emit performance metrics
- `--normalize-epubs` - Normalize EPUB files
- `--force-normalize` - Force EPUB normalization

**External tools (optional):**

```bash
brew install epubcheck
brew install pdfcpu
```

Use `--external-tools` to enable them in the CLI.

### Benchmarking (Scripts/)

```bash
# Run 5 iterations per implementation
./Scripts/benchmark.sh --iterations 5

# Custom settings
./Scripts/benchmark.sh \
  --iterations 5 \
  --authors 10 \
  --formats pdf,epub,mobi \
  --go-args "-repair" \
  --swift-args "--repair"
```

The benchmark script:

1. Builds all Swift CLIs (release mode)
2. Generates fresh libraries per iteration using `Scripts/generate_test_library.py`
3. Runs both implementations in dry-run mode
4. Reports per-run timings and averages

### Test Library Generator (Scripts/)

```bash
# Generate sample library with 10 authors, all formats
python3 Scripts/generate_test_library.py \
  --output test-library \
  --authors 10 \
  --formats pdf,epub,mobi,azw3,azw4 \
  --force

# Minimal library (PDF and EPUB only)
python3 Scripts/generate_test_library.py \
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

### Swift Implementation Details

**Workspace Structure:**
Five SwiftPM packages in `EbookMechanic.xcworkspace`:

1. **EbookMechanicCore** (Packages/EbookMechanicCore/) - Core library
   - `FileScanner` - Actor-based scanner for thread-safe concurrency
   - `FileValidator` - Format-specific validators
   - `FileRepairer` - Automatic repair engine (EPUB manifest, comprehensive PDF header/EOF repair)
   - `PDFHeaderRepair` - Advanced PDF header corruption detection and repair
   - `ZipArchive` - Custom ZIP implementation (no external dependencies)
   - `MarkdownReportGenerator` - Report generation
   - 77 tests

2. **EbookMechanicCLI** (Packages/EbookMechanicCLI/) - Full-featured command-line interface
   - Flag parsing with configuration struct
   - Progress printer with emoji feedback
   - Interactive prompts with auto-confirm mode
   - Shell completions (Bash, Zsh, Fish, PowerShell)
   - Depends on EbookMechanicCore
   - 105 tests for CLI functionality

3. **EbookMechanicApp** (Apps/EbookMechanicApp/) - macOS SwiftUI app
   - `ScanViewModel` - Observable view model shared with CLI logic
   - `ContentView` - Gradient UI with live progress, toggle controls
   - Directory picker using `NSOpenPanel`
   - Scrollable corrupted/empty folder lists
   - 30 tests (view-model + UI)

4. **EbookMechanicEPUBCLI** (Packages/EbookMechanicEPUBCLI/) - Specialized EPUB utility
   - EPUB-only validation (ZIP + mimetype + container.xml)
   - Automatic repair of missing EPUB metadata
   - Simplified CLI focused on EPUB operations
   - Depends on EbookMechanicCore
   - 6 tests

5. **EbookMechanicPDFCLI** (Packages/EbookMechanicPDFCLI/) - Specialized PDF utility
   - PDF + AZW4 validation (header + EOF markers)
   - Advanced PDF header corruption repair
   - Detects junk prefixes, UTF-8 BOM, email wrappers
   - Simplified CLI focused on PDF operations
   - Depends on EbookMechanicCore
   - 4 tests

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

- **EPUB:** Auto-adds missing `mimetype` and `META-INF/container.xml` files
- **PDF:** Comprehensive two-phase repair process:
  - **Phase 1 (Header Repair):** Advanced header detection (searches first 8KB), strips corrupted prefix bytes, validates PDF version format (1.0-2.0), adds missing binary markers, handles UTF-8 BOM and email wrapper corruption
  - **Phase 2 (EOF Repair):** Appends missing `%%EOF` markers
  - Handles real-world corruption patterns: junk prefixes, email corruption, FTP corruption, invalid versions
- **MOBI/AZW3:** Returns helpful message suggesting Calibre conversion
- Creates `.backup` files before repairs, restores on failure

**Key Implementation Details:**

- Platform support: macOS 13+, iOS 16+
- Swift language mode: 6 (strict concurrency)
- Module caches are sandboxed to `.build/module-cache` per package
- All tests use `--disable-sandbox` flag for file system access
- Custom ZIP implementation avoids external dependencies but requires maintenance for edge cases

**Test Library Generator (Scripts/generate_test_library.py):**

Creates comprehensive test fixtures with:

- Valid and corrupt pairs for each format
- Nested author/book directory structures
- Empty folders for cleanup testing
- Configurable author count and format selection
- Force overwrite option for regeneration

## Common Development Patterns

### Adding a New Ebook Format

**Swift (Packages/EbookMechanicCore/):**

1. Add case to `EbookFileType` enum (Models.swift)
2. Implement validator in FileValidator.swift
3. Add repair logic to FileRepairer.swift (if applicable)
4. Update tests in ValidationTests.swift and RepairTests.swift

### Modifying the Swift App

- View model is in `ScanViewModel.swift` (EbookMechanicApp/)
- UI state is managed with `@Published` properties for reactive updates
- `ContentView.swift` contains the SwiftUI interface with gradient backgrounds
- Progress updates flow through `ProgressEvent` structs from `FileScanner`
- Use `NSOpenPanel` for directory picker integration
- Lists use `ForEach` with file/folder arrays for display

**Swift (FileScanner.swift):**

- All scanner methods are `async` and actor-isolated
- Pass progress handler: `progress: ((ProgressEvent) -> Void)?`
- Progress events have structured stages: `.scanningFiles`, `.validatingFile(URL)`, `.repairingFiles`, etc.
- Last result is cached in `lastResult` property for subsequent operations

- File operations use `pathlib.Path` for cross-platform compatibility

## File Format Validation Reference

### EPUB Files

- Must be valid ZIP (custom `ZipArchive` in Swift, `zipfile` in Python scripts)
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

### Swift Tests

- **ValidationTests.swift:** Format-specific validation tests (4 tests)
- **RepairTests.swift:** Automatic repair functionality including PDF header repair (3 tests)
- **PDFVerifierTests.swift:** PDF header verification and corruption detection (4 tests covering junk prefixes, UTF-8 BOM, missing binary markers, email/FTP corruption)
- **ScannerTests.swift:** File scanning and folder operations (3 tests)
- **ReportGeneratorTests.swift:** Markdown report generation (12 tests)
- **CLIConfigurationTests.swift:** CLI argument parsing (45 tests)
- **ProgressPrinterTests.swift:** CLI progress output (27 tests)
- **ShellCompletionTests.swift:** Shell completion generation (31 tests)
- **ScanOptionsTests.swift:** SwiftUI view model behavior

Coverage target: 46%+ (review Xcode coverage reports for Swift targets)

All tests: 128+ total (core + CLI + app)
Core library includes comprehensive PDF repair test coverage with real-world corruption scenarios
- Use `Scripts/generate_test_library.py` to create comprehensive test fixtures
- Test all formats with valid/corrupt pairs
- Validate external tool integrations with `Scripts/test-external-tools.sh`

## Performance Characteristics

**Benchmarking:**
Use `Scripts/benchmark.sh` to compare runs on identical generated libraries.

**Optimization Notes:**

- **Swift:** Actor isolation for automatic thread safety without manual locks, async/await patterns
- The scanner skips the CORRUPTED directory to avoid redundant scanning
- File validation is I/O-bound; format-specific validators use minimal memory

## Important File Paths & Conventions

**Generated Artifacts:**

- Corrupted files: `{rootDir}/CORRUPTED/` (preserves directory structure)
- Reports: `ebook_mechanic_report_YYYY-MM-DD_HH-MM-SS.md`
- Test libraries: `test-library/` (default, configurable)

**Build Artifacts:**

- Swift builds: `Packages/*/.build/` and `Apps/*/.build/`
- Benchmark cache: `.bench/`

**Extensions:**

- Supported (case-insensitive): `.epub`, `.mobi`, `.azw3`, `.azw4`, `.pdf`
- Backup files (Swift repairs): `*.backup`

## Dependencies

**Swift (Package.swift files):**

- No external dependencies (custom ZIP implementation)
- Swift 6.2 toolchain required
- Platforms: macOS 13+, iOS 16+

**Python (Scripts/):**

- Standard library only for `Scripts/generate_test_library.py` and `Scripts/data_generator.py`

## Makefile Commands Reference

**(Makefile.swift):**

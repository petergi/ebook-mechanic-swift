# 📚 EbookMechanic

A native Swift implementation featuring both a command-line interface and a beautiful macOS SwiftUI app, powered by modern Swift concurrency. I need a tool to help with a ton of corrupted files I had when I deleted my carefully curated library (15 years!) and then used a Disk Recovery tool. It recovered the library. But *most* of it was corrupted. Some of the corrupted files maybe recoverable, so I needed a way to test them, and recover them. So here we are, a good learning opportunity with a real-world need behind it.  

I decided to learn directly from Sigil and Calibre source code, how they handle ZIP unpacking, manifest parsing, and repair flows, as well as EPUB repairs and normalization.

## Overview

The Swift implementation of EbookMechanic provides dual interfaces—a CLI for terminal users and a native macOS app for graphical interaction. Built with Swift's actor-based concurrency model and SwiftUI, it delivers a modern, type-safe approach to ebook library management with excellent macOS integration.

## Features

- 🍎 **Dual Interface** - CLI + native macOS SwiftUI app
- ⚡ **Actor-Based Concurrency** - Swift actors for thread-safe operations
- 🎨 **Beautiful SwiftUI** - Gradient-backed UI with real-time progress
- 📊 **Live Updates** - Real-time progress tracking in both CLI and app
- 🔍 **Deep Validation** - Validates EPUB, MOBI, AZW3, AZW4, and PDF files
- 🔧 **Auto-Repair** - Automatically fixes corrupted ebooks when possible
- 📕 **EPUB Normalization** - Canonical ZIP layout and OPF normalization
- 🗑️ **Smart Cleanup** - Identifies and removes folders without ebooks
- 📄 **Markdown Reports** - Generates detailed reports with statistics
- 🔒 **Safe Operations** - Dry-run mode, backups, and confirmation prompts
- 📦 **Zero Dependencies** - Pure Swift, no external packages
- 🧪 **Well Tested** - 200+ tests across Core, CLIs, and App modules

## Architecture

The Swift implementation uses a modular Swift Package Manager architecture with 5 packages:

### EbookMechanicCore (Core Library)

**Location:** `Packages/EbookMechanicCore/`

The foundation package providing all core functionality:

- **FileScanner** - Actor-based scanner for thread-safe concurrent file processing
- **FileValidator** - Format-specific validators for all ebook types
- **FileRepairer** - Automatic repair engine for EPUB and PDF files
- **ZipArchive** - Custom ZIP implementation (no external dependencies)
- **MarkdownReportGenerator** - Report generation with statistics

**Key Features:**

- Swift 6 strict concurrency enforced
- Actor isolation for automatic thread safety
- Async/await patterns throughout
- Comprehensive XCTest coverage (77 tests)

### EbookMechanicCLI (Full-Featured CLI)

**Location:** `Packages/EbookMechanicCLI/`

Terminal interface for all ebook formats:

- Fast text interface with progress feedback
- Flag parsing with configuration struct
- Progress printer with emoji feedback
- Interactive prompts with auto-confirm mode
- Shell completion support (Bash, Zsh, Fish, PowerShell)
- Depends on EbookMechanicCore

**Test Coverage:** 105 tests for configuration and completions

### EbookMechanicEPUBCLI (EPUB-Focused Utility)

**Location:** `Packages/EbookMechanicEPUBCLI/`

Specialized CLI for EPUB validation and repair:

- EPUB-only validation (ZIP + mimetype + container.xml)
- Automatic repair of missing EPUB metadata
- Simplified interface focused on EPUB operations
- Lightweight alternative to full CLI
- Depends on EbookMechanicCore

**Test Coverage:** 6 tests for core CLI flows

### EbookMechanicPDFCLI (PDF-Focused Utility)

**Location:** `Packages/EbookMechanicPDFCLI/`

Specialized CLI for PDF and AZW4 validation and repair:

- PDF + AZW4 validation (header + EOF markers)
- Advanced PDF header corruption repair
- Detects: junk prefixes, UTF-8 BOM, email wrappers
- Simplified interface focused on PDF operations
- Depends on EbookMechanicCore

**Test Coverage:** 4 tests for core CLI flows

### EbookMechanicApp (macOS SwiftUI App)

**Location:** `Apps/EbookMechanicApp/`

Native macOS application with SwiftUI:

- **ScanViewModel** - Observable view model with business logic
- **ContentView** - Gradient UI with live progress updates
- **Directory Picker** - Native `NSOpenPanel` integration
- **Toggle Controls** - Behavior configuration switches
- **Result Display** - Scrollable corrupted files and empty folders lists

**Platform Requirements:** macOS 13+, iOS 16+ ready

**Test Coverage:** 30 tests (view-model + UI)

## Installation

### Prerequisites

- macOS with Xcode 15.0 or later
- Swift 5.9 or later
- Python 3 (for documentation server)

### Build from Source

```bash
# Build all components (default)
make -f Makefile.swift build

# Or build everything explicitly
make -f Makefile.swift build-all

# Build optimized release binaries
make -f Makefile.swift build-release
```

### Quick Installation

```bash
# Install CLI (debug version)
make -f Makefile.swift install

# Or install optimized release version (recommended)
make -f Makefile.swift install-release

# Verify installation
ebook-mechanic --help

# Uninstall when needed
make -f Makefile.swift uninstall
```

## Quick Start

### Using the macOS App

```bash
# Launch the SwiftUI app
make -f Makefile.swift run-app

# Or build and run explicitly
make -f Makefile.swift build-app
make -f Makefile.swift run-app
```

The app provides:

- Visual directory selection via native picker
- Real-time progress bars
- Toggle switches for repair, normalization, dry-run
- Scrollable results with file lists
- Beautiful gradient design

### Using the CLI

```bash
# Run CLI directly (builds if needed)
make -f Makefile.swift run-cli ARGS="--help"

# Scan a directory
make -f Makefile.swift run-cli ARGS="--dir ~/Books"

# With specific options
make -f Makefile.swift run-cli ARGS="--dir ~/Books --repair --dry-run"

# Or run without Make
swift run --package-path Packages/EbookMechanicCLI EbookMechanicCLI --help
```

## Command-Line Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--dir` | `-d` | Directory to scan | `.` (current) |
| `--corrupted-dir` | `-c` | Directory for corrupted files | `CORRUPTED` |
| `--dry-run` | | Scan only, no modifications | `false` |
| `--repair` | `-r` | Attempt to repair corrupted files | `false` |
| `--corruption-only` | | Only check for corrupted files | `false` |
| `--empty-folders-only` | | Only check for empty folders | `false` |
| `--no-confirm` | | Skip confirmation prompts | `false` |
| `--quiet` | | Reduce output verbosity | `false` |
| `--report` | | Generate a report | `false` |
| `--report-format` | | Report format (markdown/json/csv/html) | `markdown` |
| `--normalize-epubs` | | Normalize EPUB files | `false` |
| `--force-normalize` | | Force normalization | `false` |
| `--use-epubcheck` | | Use epubcheck for EPUB validation | `false` |
| `--performance-stats` | | Show performance statistics | `false` |

## Usage Examples

### Basic Operations

```bash
# Scan current directory with CLI
ebook-mechanic

# Scan specific directory
ebook-mechanic --dir ~/Books

# Dry run to preview changes
ebook-mechanic --dir ~/Books --dry-run

# Automatically repair corrupted files
ebook-mechanic --dir ~/Books --repair

# Generate detailed report
ebook-mechanic --dir ~/Books --report
```

### EPUB Normalization

```bash
# Normalize EPUBs (dry-run)
make -f Makefile.swift normalize

# Force normalize (live mode)
make -f Makefile.swift normalize-force

# Or use CLI directly
ebook-mechanic --dir ~/Books --normalize-epubs --dry-run
ebook-mechanic --dir ~/Books --normalize-epubs --force-normalize
```

### Targeted Operations

```bash
# Only check for corruption with repair
ebook-mechanic --corruption-only --repair

# Only clean empty folders without confirmation
ebook-mechanic --empty-folders-only --no-confirm

# Quiet mode with report generation
ebook-mechanic --quiet --report
```

## How It Works

### Validation Strategy

**EPUB Files:**

- ZIP validation using custom `ZipArchive` implementation
- Check for `mimetype` file with content: `application/epub+zip`
- Verify `META-INF/container.xml` presence (non-empty)

**MOBI Files:**

- PalmDB header validation
- Identifier check at bytes 60-68 (`BOOKMOBI` or `TEXtREAd`)
- Header structure validation (first 32 bytes)

**PDF Files:**

- Header validation (`%PDF-`)
- Minimum file size validation (5 bytes)
- EOF marker check (`%%EOF` in last 1KB)

**AZW3 Files (Kindle Format 8):**

- Uses MOBI/PalmDB structure validation
- Same header checks as MOBI

**AZW4 Files (PDF wrapper):**

- Validates as PDF format
- PDF header and EOF markers required

Returns `ValidationResult(isValid: Bool, reason: String)`

### EPUB Normalization

Comprehensive restructuring to canonical format:

**ZIP Structure Normalization:**

- `mimetype` first and uncompressed with exact contents `application/epub+zip`
- All other entries deflated (compression method 8)
- UTF-8 file names with language encoding flag
- Normalized timestamps/attributes for reproducible builds
- Ensures `META-INF/container.xml` exists (synthesizes if missing)
- Removes extraneous files (`__MACOSX/*`, `.DS_Store`, `Thumbs.db`, `desktop.ini`)

**OPF (content.opf) Normalization:**

- Locate via META-INF/container.xml (rootfile@full-path)
- Canonicalize XML declaration, UTF-8 encoding, LF newlines
- Normalize metadata text (trim, collapse spaces, NFC)
- Sort `<metadata>` children deterministically
- Normalize `<manifest>` items:
  - Sort by id (then href)
  - Correct common media types (xhtml/css/images/opf)
  - Normalize hrefs (remove leading `./`, fix casing)
  - Remove items for extraneous files
- Normalize `<spine>` order to follow manifest

**Dry-Run Support:**

- Reports what would change without modifications
- Use `--force-normalize` to re-normalize already normalized files

### Repair Capabilities

**EPUB Repair:**

- Auto-adds missing `mimetype` file
- Creates `META-INF/container.xml` if missing
- Rebuilds ZIP structure correctly

**PDF Repair:**

- Appends missing `%%EOF` markers
- Validates and fixes structure issues

**MOBI/AZW3:**

- Returns helpful message suggesting Calibre conversion
- Cannot auto-repair proprietary format

**Safety:**

- Creates `.backup` files before repairs
- Restores from backup on failure
- Detailed error messages for troubleshooting

### Actor-Based Concurrency

**FileScanner Actor:**

- All methods are `async` and actor-isolated
- Guaranteed thread safety without manual locking
- Progress events are `Sendable` structs
- Structured stages: `.scanningFiles`, `.validatingFile(URL)`, `.repairingFiles`

**Benefits:**

- No data races
- No manual mutex management
- Swift 6 strict concurrency compliance
- Type-safe concurrent operations

## Shell Completion

The CLI supports tab completion for all major shells:

### Generate All Completions

```bash
# Generate all completion scripts at once
make -f Makefile.swift completions
```

This creates scripts in `./completions/`:

- `ebook-mechanic.bash` - Bash completion
- `_ebook-mechanic` - Zsh completion
- `ebook-mechanic.fish` - Fish completion
- `ebook-mechanic.ps1` - PowerShell completion

### Installation

```bash
# Bash (macOS with Homebrew)
cp completions/ebook-mechanic.bash $(brew --prefix)/etc/bash_completion.d/

# Zsh
cp completions/_ebook-mechanic /usr/local/share/zsh/site-functions/

# Fish
cp completions/ebook-mechanic.fish ~/.config/fish/completions/

# PowerShell
. completions/ebook-mechanic.ps1
```

See [COMPLETIONS.md](COMPLETIONS.md) for detailed installation instructions.

## Documentation

### Generating Documentation

```bash
# Generate all documentation (Core + App)
make -f Makefile.swift docc-all

# Generate for specific components
make -f Makefile.swift docc-core    # Core library documentation
make -f Makefile.swift docc-app     # App documentation

# Serve documentation locally at http://localhost:8080
make -f Makefile.swift docc-serve
```

### Update All Artifacts

```bash
# Regenerate completions and documentation
make -f Makefile.swift update-all
```

## Makefile Commands

The Swift Makefile (`Makefile.swift`) provides comprehensive build automation:

### Build Targets

```bash
make -f Makefile.swift build               # Build core library only (default)
make -f Makefile.swift build-all           # Build everything (core + CLI + app)
make -f Makefile.swift build-release       # Build optimized release binaries
make -f Makefile.swift build-core          # Build the core library
make -f Makefile.swift build-cli           # Build the CLI executable
make -f Makefile.swift build-app           # Build the macOS SwiftUI app
```

### Test Targets

```bash
make -f Makefile.swift test                # Run core library tests (default)
make -f Makefile.swift test-all            # Run all test suites (core + CLI + app)
make -f Makefile.swift test-core           # Run EbookMechanicCore tests
make -f Makefile.swift test-cli            # Run CLI tests
make -f Makefile.swift test-app            # Run app tests
```

### Run Targets

```bash
make -f Makefile.swift run-cli ARGS=       # Run the CLI (default: --help)
make -f Makefile.swift normalize           # Normalize EPUBs (dry-run mode)
make -f Makefile.swift normalize-force     # Force normalize EPUBs (live mode)
make -f Makefile.swift run-app             # Launch the SwiftUI app
```

### Documentation Targets

```bash
make -f Makefile.swift docc-all            # Generate all documentation
make -f Makefile.swift docc-core           # Generate DocC for Core
make -f Makefile.swift docc-app            # Generate DocC for App
make -f Makefile.swift docc-serve          # Serve docs at http://localhost:8080
```

### Utility Targets

```bash
make -f Makefile.swift completions         # Generate shell completion scripts
make -f Makefile.swift install             # Install CLI (debug)
make -f Makefile.swift install-release     # Install optimized CLI
make -f Makefile.swift uninstall           # Remove installed CLI
make -f Makefile.swift format              # Format Swift code (requires swift-format)
make -f Makefile.swift lint                # Lint code (requires SwiftLint)
make -f Makefile.swift check-format        # Check if code is formatted (CI)
make -f Makefile.swift workspace           # Open Xcode workspace
make -f Makefile.swift clean               # Remove build artifacts
make -f Makefile.swift clean-all           # Deep clean (includes completions & docs)
make -f Makefile.swift info                # Display build information
make -f Makefile.swift update-all          # Update completions and docs
```

### CI/CD Targets

```bash
make -f Makefile.swift ci                  # Run full CI pipeline
                         # (build-all + test-all + check-format)
```

Run `make -f Makefile.swift help` from the repo root for a complete list.

## Testing

Comprehensive test coverage across all modules:

```bash
# Run all tests
make -f Makefile.swift test-all

# Run specific module tests
make -f Makefile.swift test-core           # Core library (77 tests)
make -f Makefile.swift test-cli            # CLI (105 tests)
make -f Makefile.swift test-epub           # EPUB CLI (6 tests)
make -f Makefile.swift test-pdf            # PDF CLI (4 tests)
make -f Makefile.swift test-app            # App (30 tests)

# Or use Swift directly
swift test --package-path Packages/EbookMechanicCore
```

### Test Coverage

**Total:** 222 tests across Core, CLIs, and App modules

- **ValidationTests.swift** - Format-specific validation tests
- **RepairTests.swift** - Automatic repair functionality
- **ScannerTests.swift** - File scanning and folder operations
- **ReportGeneratorTests.swift** - Markdown report generation
- **CLIConfigurationTests.swift** - CLI argument parsing
- **EPUBMechanicCLITests.swift** - EPUB CLI behavior and flags
- **PDFMechanicCLITests.swift** - PDF CLI behavior and flags
- **ScanOptionsTests.swift** - SwiftUI view model behavior

All tests use `--disable-sandbox` flag for file system access.

## Performance

Swift's compiled nature and actor-based concurrency provide excellent performance:

- **Compiled Binary** - Native code execution
- **Actor Isolation** - Efficient concurrent operations
- **No Manual Locks** - Swift runtime manages synchronization
- **Low Memory** - Efficient memory management

**Typical performance on 10,000 files:**

- **Swift version: ~8-12 seconds**

## Project Structure

```
.
├── Apps/
│   └── EbookMechanicApp/          # macOS SwiftUI app (SwiftPM)
├── Packages/
│   ├── EbookMechanicCore/         # Core library package
│   ├── EbookMechanicCLI/          # Command-line interface
│   ├── EbookMechanicEPUBCLI/      # EPUB-focused CLI
│   └── EbookMechanicPDFCLI/       # PDF-focused CLI
├── Docs/
│   └── Swift/                     # Swift documentation
├── Scripts/                       # Benchmarking + helper scripts
├── EbookMechanic.xcworkspace      # Xcode workspace (optional)
├── Makefile.swift                 # Swift build automation
└── completions/                   # Generated shell completions
    ├── ebook-mechanic.bash
    ├── _ebook-mechanic
    ├── ebook-mechanic.fish
    └── ebook-mechanic.ps1
```

## Dependencies

**Zero external dependencies!**

- Pure Swift standard library
- Custom ZIP implementation (no external packages)
- Swift Package Manager for module management
- SwiftUI for macOS app (built-in)

**Requirements:**

- Swift 5.9+
- macOS 13+ (for app)
- iOS 16+ (architecture ready)

## Code Quality

```bash
# Format Swift code (requires swift-format)
make -f Makefile.swift format

# Check code formatting (CI-friendly)
make -f Makefile.swift check-format

# Lint code (requires SwiftLint)
make -f Makefile.swift lint
```

## Development Workflow

### Using Xcode

```bash
# Open workspace in Xcode
make -f Makefile.swift workspace

# Or open directly
open EbookMechanic.xcworkspace
```

### Command Line

```bash
# 1. Make changes
# 2. Run tests
make -f Makefile.swift test-all

# 3. Check formatting
make -f Makefile.swift check-format

# 4. Build
make -f Makefile.swift build-all

# 5. Test manually
make -f Makefile.swift run-cli ARGS="--dir test-library --dry-run"
make -f Makefile.swift run-app
```

## Troubleshooting

### Build Issues

```bash
# View build information
make -f Makefile.swift info

# Clean and rebuild
make -f Makefile.swift clean-all
make -f Makefile.swift build-all
```

### Permission Errors During Clean

The Makefile automatically fixes permissions before cleaning:

```bash
# Manual permission fix if needed
chmod -R u+w Packages/EbookMechanicCore/.build
chmod -R u+w Packages/EbookMechanicCLI/.build
chmod -R u+w Apps/EbookMechanicApp/.build

# Then clean
make -f Makefile.swift clean-all
```

### Documentation Generation Fails

If `make docc-core` fails, see [DOCC_SETUP.md](DOCC_SETUP.md) for setup instructions.

### Module Cache Issues

Swift uses sandboxed module caches to avoid conflicts:

```bash
# Caches are in .build/module-cache per package
# Clean if experiencing issues
make clean-all
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make test-all`)
5. Format code (`make format`)
6. Run CI pipeline (`make ci`)
7. Commit changes (`git commit -m 'Add amazing feature'`)
8. Push to branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

## License

This project is licensed under the MIT License.

## Credits

- Swift Package Manager and SwiftUI communities
- Contributors to the project

---

**Quick Links:** [Parent README](../../README.md) | [Master Makefile](../../Makefile)

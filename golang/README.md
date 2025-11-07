# 📚 EbookMechanic - Go Implementation

A blazing-fast, production-ready ebook library management tool with a beautiful terminal interface powered by [Bubble Tea](https://github.com/charmbracelet/bubbletea).

## Overview

The Go implementation of EbookMechanic provides maximum performance, a single-binary deployment model, and a polished terminal user interface. Built with Go's concurrency primitives and compiled to native code, it delivers exceptional speed for large ebook libraries.

## Features

- ⚡ **Lightning Fast** - Compiled binary with goroutine-based concurrency
- 🎨 **Beautiful TUI** - Powered by Bubble Tea framework with Lipgloss styling
- 📊 **Real-time Progress** - Live progress bars, spinners, and status updates
- 🔍 **Deep Validation** - Validates EPUB, MOBI, AZW3, AZW4, and PDF files
- 🔧 **Auto-Repair** - Automatically fixes corrupted ebooks when possible
- 📕 **EPUB Normalization** - Restructures EPUBs to Sigil standards with proper file extensions and manifest IDs
- 🗑️ **Smart Cleanup** - Identifies and removes folders without ebooks
- 📄 **Markdown Reports** - Generates detailed reports with statistics
- 🔒 **Safe Operations** - Confirmation prompts, dry-run mode, and automatic backups
- 🧪 **Well Tested** - 48.2% test coverage with comprehensive unit tests
- 📦 **Zero Dependencies** - Single binary deployment, no runtime requirements

### Performance Highlights

- 🔁 **Single-Pass Scanner** - Streams files through a worker pool instead of walking the directory tree twice
- 🧵 **Parallel Processing** - CPU-heavy ZIP/PDF work fans out across all cores
- 🧠 **Cached EPUB Index** - Normalization reuses paths collected during corruption scan (no second disk sweep)
- 💾 **Streaming Repairs** - PDF/MOBI fixers touch only necessary file regions, keeping memory usage low

## Installation

### Prerequisites

- Go 1.24+ (tested with Go 1.25.3)

### Build from Source

```bash
# Navigate to golang directory
cd golang

# Download dependencies
make deps

# Build optimized binary
make build

# Binary will be at: build/ebook-mechanic
```

### Quick Installation

```bash
# Using Makefile (recommended)
make build          # Build optimized binary
make install        # Install to $GOPATH/bin

# Or manually
go build -ldflags="-s -w" -o ebook-mechanic .
go install
```

## Quick Start

### Generate Sample Library (for testing)

Need quick fixtures with a mix of healthy and broken ebooks? Generate them on demand:

```bash
# Create 10 author folders with valid + corrupt EPUB/MOBI/AZW3/AZW4/PDF pairs
make sample-library

# Custom settings
make sample-library LIBRARY_DIR=my-fixtures LIBRARY_AUTHORS=5

# Or use Python script directly
python3 ../python/generate_test_library.py \
  --output test-library \
  --authors 10 \
  --formats pdf,epub,mobi,azw3,azw4 \
  --force
```

### Basic Usage

```bash
# Run with TUI (default)
./ebook-mechanic

# Run on specific directory
./ebook-mechanic -dir /path/to/ebooks

# Run without TUI (simple text output)
./ebook-mechanic -no-tui
```

## Command-Line Flags

| Flag | Description | Default |
|------|-------------|---------|
| `-dir` | Root directory to scan | `.` (current) |
| `-corrupted-dir` | Directory for corrupted files | `CORRUPTED` |
| `-corruption-only` | Only check for corrupted files | `false` |
| `-empty-folders-only` | Only check for empty folders | `false` |
| `-repair` | Attempt to repair corrupted files | `false` |
| `-normalize-epub` | Normalize EPUB files to Sigil standards | `false` |
| `-force-normalize` | Force normalization even if already normalized | `false` |
| `-keep-backups` | Keep .backup files after operations | `false` |
| `-clean-backups` | Remove existing .backup files | `false` |
| `-dry-run` | Scan only, don't modify anything | `false` |
| `-no-confirm` | Skip confirmation prompts | `false` |
| `-no-tui` | Disable TUI, use simple output | `false` |

## Usage Examples

### Basic Operations

```bash
# Scan current directory with TUI
./ebook-mechanic

# Dry run to preview changes
./ebook-mechanic -dry-run

# Automatically repair corrupted files
./ebook-mechanic -repair

# Check specific directory
./ebook-mechanic -dir ~/Books -repair
```

### EPUB Normalization

```bash
# Normalize EPUB files to Sigil standards
./ebook-mechanic -normalize-epub

# Force normalize all EPUBs (even if already normalized)
./ebook-mechanic -normalize-epub -force-normalize

# Normalize with backup files kept
./ebook-mechanic -normalize-epub -keep-backups

# Clean existing backups, then normalize
./ebook-mechanic -clean-backups -normalize-epub

# Demo normalization (using Makefile)
make demo-normalize
```

### Targeted Operations

```bash
# Only check for corruption with repair
./ebook-mechanic -corruption-only -repair

# Only clean empty folders without confirmation
./ebook-mechanic -empty-folders-only -no-confirm

# Scan specific directory with custom corrupted dir
./ebook-mechanic -dir ~/Books -corrupted-dir BROKEN

# Simple mode without TUI
./ebook-mechanic -no-tui -repair -normalize-epub
```

## How It Works

### Corruption Detection

The tool validates ebook files by checking format-specific structural requirements:

**EPUB Files:**
- Valid ZIP structure using Go's `archive/zip`
- Required `mimetype` file with exact content: `application/epub+zip`
- Required `META-INF/container.xml` file (non-empty)

**MOBI Files:**
- Valid MOBI/PalmDB header structure
- Correct identifier (`BOOKMOBI` or `TEXtREAd`) at byte offset 60
- Minimum file size validation (68 bytes)

**PDF Files:**
- Valid PDF header (`%PDF-`)
- Minimum file size validation (100 bytes)
- EOF marker (`%%EOF`) in last 1KB of file

**AZW3 Files (Kindle Format 8):**
- Uses MOBI/PalmDB structure validation
- Valid identifier at offset 60

**AZW4 Files (PDF wrapper):**
- Validates as PDF format
- PDF header and EOF markers required

### EPUB Normalization

When the `-normalize-epub` flag is used, the tool restructures EPUB files to follow Sigil standards:

**Smart Processing:**
- Scans ALL EPUB files in the directory (not just corrupted ones)
- Pre-checks if EPUBs are already normalized to avoid unnecessary work
- Use `-force-normalize` to bypass pre-checks and normalize everything
- Significantly improves performance for large libraries with mixed normalized/unnormalized files

**Normalization Steps:**

1. **File Extension Normalization:**
   - `.htm` → `.xhtml`
   - `.css` files retain proper extension
   - Image files normalized to standard extensions

2. **OPF Manifest Rebasing:**
   - Generates new IDs based on actual filenames
   - Updates all references to use new IDs
   - Ensures manifest consistency

3. **HTML Prettification:**
   - Properly formats all XHTML files
   - Maintains valid XML structure
   - Improves readability and consistency

4. **CSS Formatting:**
   - Normalizes CSS formatting
   - Maintains styling functionality

### Backup Management

The tool creates backup files (.backup extension) before making changes:

**Default Behavior:**
- Backups are automatically removed after successful operations
- Provides safety during operations without cluttering directories

**Backup Control Flags:**
- `-keep-backups`: Preserve backup files after successful operations
- `-clean-backups`: Remove all existing .backup files in directory

### Empty Folder Detection

- Recursively scans all subdirectories
- Bottom-up traversal for efficient processing
- Identifies folders containing no ebook files (.epub, .mobi, .azw3, .azw4, .pdf)
- Shows folder contents before deletion

### Operations Flow

```text
1. Clean existing backups (if -clean-backups flag)
   ↓
2. Scan for corrupted files
   ↓
3. Create backups before repairs/normalization
   ↓
4. Repair corrupted files (if -repair flag)
   ↓
5. Normalize EPUB files (if -normalize-epub flag)
   ↓
6. Remove/keep backups based on -keep-backups flag
   ↓
7. Move corrupted files to CORRUPTED/
   ↓
8. Scan for empty folders
   ↓
9. Delete empty folders (with confirmation)
   ↓
10. Generate Markdown report
    ↓
11. Display summary statistics
```

## TUI Features

The Bubble Tea TUI provides an interactive experience:

- 🎯 **Animated Spinners** - Visual feedback during operations
- 📊 **Progress Tracking** - Real-time progress display with file counts
- 🎨 **Color-Coded Output**:
  - Pink/Magenta for titles
  - Green for success messages
  - Red for errors
  - Cyan for informational messages
- 📈 **Live Statistics** - File counts, folder counts, status updates
- ⌨️ **Interactive Confirmations** - Press 'y' or 'n' for folder deletion
- 🚀 **Fast Rendering** - Efficient terminal updates

## Shell Completion

EbookMechanic supports tab completion for bash, zsh, fish, and PowerShell.

### Quick Installation

**Auto-detect and install for current shell:**

```bash
make completion-install
```

### Manual Installation

```bash
# Bash
make completion-bash

# Zsh
make completion-zsh

# Fish
make completion-fish

# PowerShell
make completion-powershell
```

### Generate Completion Scripts

```bash
# Generate all completion scripts to completions/ directory
make completion-generate
```

## Makefile Commands

The project includes a comprehensive Makefile with 50+ commands organized into categories:

### Build Commands

```bash
make build           # Build optimized binary
make build-dev       # Build with debug symbols
make build-all       # Cross-platform builds (Linux/macOS/Windows)
make release         # Create release builds
```

### Development Commands

```bash
make run             # Run without building
make run-dry         # Run in dry-run mode
make dev             # Auto-reload (requires air)
make watch           # Watch and rebuild
make sample-library  # Generate test library
```

### EPUB Normalization Commands

```bash
make run-normalize-all       # Normalize ALL EPUBs (skips already normalized)
make run-normalize-force     # Force normalize ALL EPUBs (even if normalized)
make run-normalize-all-dry   # Show what would be normalized (dry-run)
make run-normalize-force-dry # Show what would be force-normalized (dry-run)
make demo-normalize          # Demo normalization on sample library
```

### Testing Commands

```bash
make test            # Run all tests
make test-unit       # Run unit tests only
make test-coverage   # Generate coverage report
make test-race       # Run with race detector
make test-watch      # Watch mode (requires entr)
make benchmark       # Run benchmarks
```

### Quality Commands

```bash
make check           # Run all quality checks
make fmt             # Format code
make vet             # Run go vet
make lint            # Run golangci-lint
make tidy            # Tidy dependencies
```

### Installation Commands

```bash
make install         # Install to $GOPATH/bin
make uninstall       # Remove installed binary
```

### Documentation Commands

```bash
make docs            # View documentation
make godoc           # Start godoc server at :6060
```

### Profiling Commands

```bash
make profile-cpu     # Generate CPU profile
make profile-mem     # Generate memory profile
```

Run `make help` for a complete list of available commands.

## Testing

The project includes comprehensive unit tests covering all major functionality:

```bash
# Run all tests
make test

# Run with coverage
make test-coverage

# Run specific tests
go test -v -run TestValidateEPUB

# Run tests with race detection
make test-race

# Watch mode (requires entr)
make test-watch
```

### Test Coverage

Current coverage: **48.2%** of statements

- **validator_test.go**: 45+ tests for EPUB, MOBI, AZW3, AZW4, and PDF validation
- **scanner_test.go**: 15+ tests for file scanning, corruption detection, and folder operations
- **report_test.go**: 10+ tests for report generation and formatting
- **repair_test.go**: Comprehensive tests for automatic file repair functionality
- **normalize_test.go**: Tests for EPUB normalization logic

### Benchmarking

Measure scan throughput with the synthetic library harness:

```bash
# Run benchmarks
make benchmark

# Or directly with go test
go test -bench=BenchmarkScanForCorruption -benchmem

# Scale the generated dataset
EBOOK_BENCH_AUTHORS=40 EBOOK_BENCH_BOOKS=40 \
  go test -bench=BenchmarkScanForCorruption -run '^$'
```

Environment variables:
- `EBOOK_BENCH_AUTHORS` - Number of author folders (default: 20)
- `EBOOK_BENCH_BOOKS` - Ebooks per author (default: 25)

## Performance

Go's concurrency and compiled nature make this significantly faster than interpreted implementations:

- **Compiled Binary** - No interpreter overhead
- **Static Typing** - Better optimization opportunities
- **Goroutines** - Efficient concurrent processing
- **Low Memory** - Minimal runtime footprint

**Typical performance on 10,000 files:**
- Python version: ~30-45 seconds
- **Go version: ~5-10 seconds** (3-5x faster)

## Project Structure

```text
golang/
├── Makefile              # Comprehensive build system
├── README.md             # This file
├── Dockerfile            # Multi-stage Docker build
├── go.mod                # Go module definition
├── go.sum                # Dependency checksums
├── main.go               # Entry point + Bubble Tea TUI
├── validator.go          # EPUB/MOBI/PDF/AZW validation logic
├── scanner.go            # File/folder scanning operations
├── report.go             # Markdown report generation
├── repair.go             # Automatic file repair functionality
├── normalize.go          # EPUB normalization to Sigil standards
├── doc.go                # Package documentation
├── *_test.go             # Comprehensive test suite
├── build/                # Build artifacts
└── coverage/             # Test coverage reports
```

## Dependencies

```go
github.com/charmbracelet/bubbletea v1.3.10  // TUI framework
github.com/charmbracelet/lipgloss v1.1.0    // Styling
github.com/charmbracelet/bubbles v0.21.0    // TUI components
golang.org/x/net v0.46.0                    // HTML parsing for EPUB normalization
```

All dependencies are managed via `go.mod`. Use `make deps` to download and verify dependencies.

## Cross-Platform Builds

```bash
# Using Makefile (recommended)
make build-all       # Build for all platforms
make build-linux     # Linux amd64
make build-darwin    # macOS (Intel + Apple Silicon)
make build-windows   # Windows amd64

# Manual builds
GOOS=linux GOARCH=amd64 go build -o ebook-mechanic-linux .
GOOS=darwin GOARCH=amd64 go build -o ebook-mechanic-macos-intel .
GOOS=darwin GOARCH=arm64 go build -o ebook-mechanic-macos-arm .
GOOS=windows GOARCH=amd64 go build -o ebook-mechanic.exe .

# Release builds with optimizations
make release
```

## Docker Support

```bash
# Build Docker image
make docker-build

# Run in Docker
make docker-run
```

## Output Example

### With TUI

```text
📚 EBOOKMECHANIC

🔍 Scanning for Corrupted Ebooks

⠋ Checking: my-book.epub
   Progress: 42/100 files
```

### Final Summary

```text
📚 EBOOKMECHANIC

✅ ALL OPERATIONS COMPLETED!

╭─────────────────────────────────╮
│ 📊 Statistics                   │
│                                 │
│ Files Scanned:     1,234        │
│ Corrupted Files:   5            │
│                                 │
│ By Type:                        │
│   EPUB: 2/800 ❌                │
│   MOBI: 1/234 ❌                │
│   PDF:  2/200 ❌                │
│                                 │
│ Folders Scanned:   150          │
│ Empty Folders:     12           │
╰─────────────────────────────────╯

📄 Report: ebook_mechanic_report_2025-11-03_14-30-00.md

⏱️  Completed in 8s
```

## Safety Features

- **Confirmation Prompts** - Required before deleting folders (unless `-no-confirm`)
- **Dry Run Mode** - Preview all changes with `-dry-run`
- **Automatic Backups** - Created before repairs/normalization
- **Detailed Reports** - Full Markdown documentation of all changes
- **Structure Preservation** - Corrupted files maintain directory hierarchy
- **Skip CORRUPTED** - Won't scan or modify the CORRUPTED directory

## Troubleshooting

### Build Errors

```bash
# Clean module cache
go clean -modcache

# Re-download dependencies
go mod download

# Tidy dependencies
go mod tidy
```

### Permission Issues

On Unix systems, make the binary executable:

```bash
chmod +x ebook-mechanic
```

### TUI Not Displaying Properly

- Ensure your terminal supports ANSI colors
- Try `-no-tui` flag for simple output
- Update terminal emulator

### Performance Issues

```bash
# Profile CPU usage
make profile-cpu

# Profile memory usage
make profile-mem
```

## Comparison with Other Implementations

| Feature | Go | Swift | Python |
|---------|-----|-------|--------|
| **Speed** | ~8s for 10k files | ~12s for 10k files | ~30s for 10k files |
| **Memory** | ~15MB | ~20MB | ~50MB |
| **Dependencies** | Built-in binary | Built-in binary | Requires Python + Rich |
| **Portability** | Single executable | macOS only | Any platform with Python |
| **TUI Framework** | Bubble Tea | CLI + SwiftUI App | Rich library |
| **Startup Time** | <10ms | <50ms | ~500ms |
| **Binary Size** | ~8MB | ~2MB | N/A (interpreted) |

## Contributing

Contributions are welcome! Please:

1. Report bugs
2. Suggest features
3. Submit pull requests
4. Improve documentation

### Development Workflow

```bash
# 1. Make changes
# 2. Run tests
make test

# 3. Check code quality
make check

# 4. Build
make build

# 5. Test manually
./build/ebook-mechanic -dry-run
```

## License

Free to use and modify.

## Credits

- Built with [Bubble Tea](https://github.com/charmbracelet/bubbletea)
- Styled with [Lipgloss](https://github.com/charmbracelet/lipgloss)
- Created with ❤️ by the team

---

**Quick Links:** [Parent README](../README.md) | [Master Makefile](../Makefile) | [Swift Implementation](../swift/README.md) | [Python Implementation](../python/README.md)

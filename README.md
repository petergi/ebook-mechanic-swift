# 📚 EbookMechanic (swift)


** This was an attempt at testing and learning something new while addressing a trivial problem of mine: If you use this, it **might** work, or it **might** cause the extinction of the long-fingered Aye-aye from Madagascar. You've been warned! **


A comprehensive, ebook library management toolkit for validating, repairing, and organizing ebook collections.

## Overview

EbookMechanic is a powerful command-line tool suite for managing ebook libraries. It validates ebook files, detects corruption, repairs damaged files when possible, normalizes EPUB files to industry standards, and maintains clean library organization.

### Supported Formats

| Format     | Description              | Validation                             |
| ---------- | ------------------------ | -------------------------------------- |
| 📗**EPUB** | Electronic Publication   | ZIP structure, mimetype, container.xml |
| 📕**MOBI** | Mobipocket               | PalmDB header, identifier signature    |
| 📘**AZW3** | Kindle Format 8          | MOBI structure validation              |
| 📙**AZW4** | Kindle PDF Wrapper       | PDF structure validation               |
| 📄**PDF**  | Portable Document Format | Header and EOF markers                 |

## Features

- 🔍 **Deep Validation** — Structural integrity checking for all supported formats, with optional deep validation using `epubcheck` and `pdfcpu`.
- 🔧 **Auto-Repair** — Automatic fixing of corrupted files
  - **PDF Repair:** Comprehensive header corruption detection and repair (handles email/FTP corruption, UTF-8 BOM, junk prefixes, missing binary markers)
  - **EPUB Repair:** Auto-adds missing mimetype and container.xml files
- 📚 **EPUB Normalization** — Restructures EPUBs to Sigil/standard specifications
- 🗑️ **Smart Cleanup** — Removes empty folders while preserving directory structure
- 📊 **Progress Tracking** — Real-time progress with beautiful interfaces
- 📄 **Detailed Reports** — Multi-format reports (Markdown, JSON, CSV, HTML) with comprehensive statistics.
- 🔒 **Safe Operations** — Dry-run mode, backups and confirmation prompts
- ⚡ **High Performance** — Optimized scanning and concurrent processing
  - **Parallel Validation**: Concurrently validate multiple ebooks to maximize performance.
  - **Caching**: Avoid re-validating unchanged files with an intelligent caching layer.
  - **Performance Statistics**: Get detailed performance metrics to analyze and optimize your scans.

## Implementations

### 🔶 [Swift Implementation](./Docs/Swift/README.md)

**Best for:** macOS users, native app experience, Swift ecosystem integration

- **Performance:** Compiled native binary with actor-based concurrency
- **UI:** Dual interface — CLI + native macOS SwiftUI app
- **Architecture:** Modular Swift packages (Core + CLI(s) + App)
- **Platform:** macOS 13+, iOS 16+ ready
- **Concurrency:** Swift actors for thread-safe operations
- **Advanced PDF Repair:** Comprehensive header corruption detection and repair with two-phase repair process (extensive Swift tests across modules)

```bash
make run-app      # Launch macOS app
```

## Quick Start

### Master Makefile (Unified Interface)

The root Makefile provides a unified build system for all implementations:

```bash
# Build
make build                                     # Build all
make build-all                                 # Build everything (all-in-one, epub-mechanic, pdf-mechanic, SwiftUI macOS app)
make build-cli                                 # Build All-in-one cli
make build-epub-mechanic-cli                   # Build EPUB Mechanic cli
make build-pdf-mechanic-cli                    # Build PDF Mechanic cli
make build-ebook-mechanic-app                  # Build SwiftUI macOS app

# Test
make test                                      # Test all
make test-all                                  # Test everything (all-in-one, epub-mechanic, pdf-mechanic, SwiftUI macOS app)
make test-cli                                  # Test All-in-one cli
make test-epub-mechanic-cli                    # Test EPUB Mechanic cli
make test-pdf-mechanic-cli                     # Test PDF Mechanic cli
make test-ebook-mechanic-app                   # Test SwiftUI macOS app

# Run specific implementation
make run-ebook-mechanic-cli                    # Run cli (all-in-one)
make run-epub-mechanic-cli                     # Run EPUB Mechanic cli
make run-pdf-mechanic-cli                      # Run PDF Mechanic cli
make run-ebook-mechanic-app                    # Run SwiftUI macOS app

# Generate test library for testing
make sample-library

# Benchmark implementations
./Scripts/benchmark.sh

# Install
make install                                    # Install all the CLIs
make install-ebook-mechanic-cli                 # Install All-in-one cli
make install-epub-mechanic-cli                  # Install EPUB Mechanic cli
make install-pdf-mechanic-cli                   # Install PDF Mechanic cli
make install-ebook-mechanic-app                 # Install SwiftUI macOS app

# See all commands
make help
```

### Direct Usage

Each implementation can also be used independently:

```bash
# CLI(s)
make -f Makefile.swift build-cli && make -f Makefile.swift run-cli          # All-in-one cli
make -f Makefile.swift build-epub && make -f Makefile.swift run-epub        # EPUB Mechanic cli
make -f Makefile.swift build-pdf && make -f Makefile.swift run-pdf          # PDF Mechanic cli

# APP
make -f Makefile.swift build-app && make -f Makefile.swift run-app          # SwiftUI macOS app
```

## Docker MCP Gateway

See `DOCKER_MCP.md` for the full runbook. If you want the shortest path per session, use:

```bash
Scripts/run-mcp-gateway.sh
```

## Installation

### Prerequisites

| Implementation | Requirements                       |
| -------------- | ---------------------------------- |
| **Swift**      | macOS with Xcode 15.0+, Swift 5.9+ |

### Install from Source

```bash
# Clone repository
git clone https://github.com/{yourusername}/EbookMechanic
cd EbookMechanic

# Build all implementations
make build-all

# Install CLIs to system
make install
```

## Usage Examples

### Basic Operations

```bash
# Scan current directory
ebook-mechanic

# Scan specific directory
ebook-mechanic --dir ~/Books

# Dry run (preview only)
ebook-mechanic --dir ~/Books --dry-run

# Repair corrupted files
ebook-mechanic --dir ~/Books --repair

# Normalize EPUB files
ebook-mechanic --dir ~/Books --normalize-epubs
```

### Advanced Options

```bash
# Check corruption only (skip empty folders)
ebook-mechanic --corruption-only --repair

# Check empty folders only
ebook-mechanic --empty-folders-only

# Force EPUB normalization (even if already normalized)
ebook-mechanic --normalize-epubs --force-normalize

# Keep backup files after operations
ebook-mechanic --normalize-epubs --dry-run

# Auto-confirm prompts
ebook-mechanic --auto-confirm

# Verbose logging
ebook-mechanic --verbose

# Use external validators
ebook-mechanic --external-tools

# Generate reports in multiple formats
ebook-mechanic --report --report-formats markdown,json,csv,html

# Run with parallel validation and performance stats
ebook-mechanic --max-concurrent 8 --performance-stats
```

### Specialized CLI Examples

```bash
# EPUB CLI validation with epubcheck
epub-mechanic validate --spec-check --show-warnings --accessibility

# EPUB CLI metadata repair (creates .backup.epub if needed)
epub-mechanic repair --fix-metadata

# PDF CLI structure validation and info
pdf-mechanic validate --structure-check

# PDF CLI metadata extraction (json or yaml)
pdf-mechanic validate --extract-metadata json
pdf-mechanic validate --extract-metadata yaml

# PDF CLI optimization (writes .optimized.pdf alongside the original)
pdf-mechanic repair --optimize
```

## Project Structure

```text
EbookMechanic/
├── Makefile                    # Master build system (start here)
├── Makefile.swift              # Swift build targets
├── README.md                   # This file
├── CLAUDE.md                   # AI assistant instructions
│
├── Apps/                       # Swift app targets
│   └── EbookMechanicApp/       # macOS SwiftUI app
├── Packages/                   # Swift packages
│   ├── EbookMechanicCore/      # Core library package
│   ├── EbookMechanicCLI/       # All-in-one command-line interface
│   ├── EbookMechanicEPUBCLI/   # EPUB-focused command-line interface
│   └── EbookMechanicPDFCLI/    # PDF-focused command-line interface
├── Docs/                       # Documentation
│   └── Swift/                  # Swift implementation docs
│
└── Scripts/                    # Shared utilities
    ├── generate_test_library.py    # Test fixture generator
    └── benchmark.sh                # Cross-implementation benchmarks
```

## Development

### Build & Test All Implementations

```bash
# Build everything
make build-all

# Run all tests
make test-all

# Code quality checks
make check lint

# Clean all artifacts
make clean-all
```

### Generate Test Libraries

Create test fixtures with valid and corrupt files:

```bash
# Default: 10 authors, all formats
make sample-library

# Custom configuration
make sample-library LIBRARY_AUTHORS=20 LIBRARY_FORMATS=pdf,epub
```

## Documentation

### Implementation-Specific Docs

- **Swift:** [Docs/Swift/README.md](./Docs/Swift/README.md) - Swift workspace and app documentation

### Generate Documentation

```bash
# Generate all documentation
make docs

# Serve documentation locally
make docc-serve          # http://localhost:8080
```

### Wiki

```bash
# Generate and publish the GitHub wiki
make wiki

# Generate wiki content without pushing
make wiki-generate
```

## Shell Completion

All implementations support shell completion for Bash, Zsh, Fish, and PowerShell:

```bash
# Auto-detect and install for current shell
make install-completions

# Generate all completion scripts
make -f Makefile.swift completions
```

All implementations share:

- Identical validation rules
- Same CORRUPTED directory convention
- Compatible report formats
- Consistent command-line interfaces

## Contributing

Contributions welcome for any implementation:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make test-all`)
5. Run quality checks (`make check`)
6. Commit changes (`git commit -m 'Add amazing feature'`)
7. Push to branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

Each implementation has its own contribution guidelines in respective README files.

## Troubleshooting

### Build Issues

```bash
# View project information
make info

# Clean and rebuild
make clean-all
make build-all
```

### Performance Issues

```bash
# Run benchmarks to identify bottlenecks
./Scripts/benchmark.sh
```

### Test Failures

```bash
# Run full test suite
make test-all
```

## License

Free to use and modify.

## Acknowledgments

- **Swift:** Native SwiftUI and Swift Package Manager

---

**Quick Links:** [Swift README](./Docs/Swift/README.md) | [Master Makefile](./Makefile)

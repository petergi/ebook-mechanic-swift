# 📚 EbookMechanic

A comprehensive, multi-language ebook library management toolkit for validating, repairing, and organizing ebook collections.

## Overview

EbookMechanic is a powerful command-line tool suite for managing ebook libraries. It validates ebook files, detects corruption, repairs damaged files when possible, normalizes EPUB files to industry standards, and maintains clean library organization. Available in three implementations to suit different needs and environments.

### Supported Formats

| Format | Description | Validation |
|--------|-------------|------------|
| 📗 **EPUB** | Electronic Publication | ZIP structure, mimetype, container.xml |
| 📕 **MOBI** | Mobipocket | PalmDB header, identifier signature |
| 📘 **AZW3** | Kindle Format 8 | MOBI structure validation |
| 📙 **AZW4** | Kindle PDF Wrapper | PDF structure validation |
| 📄 **PDF** | Portable Document Format | Header and EOF markers |

## Features

- 🔍 **Deep Validation** - Structural integrity checking for all supported formats
- 🔧 **Auto-Repair** - Automatic fixing of corrupted files
  - **PDF Repair (Swift):** Comprehensive header corruption detection and repair (handles email/FTP corruption, UTF-8 BOM, junk prefixes, missing binary markers)
  - **EPUB Repair:** Auto-adds missing mimetype and container.xml files
- 📚 **EPUB Normalization** - Restructures EPUBs to Sigil/standard specifications
- 🗑️ **Smart Cleanup** - Removes empty folders while preserving directory structure
- 📊 **Progress Tracking** - Real-time progress with beautiful interfaces
- 📄 **Detailed Reports** - Markdown reports with comprehensive statistics
- 🔒 **Safe Operations** - Dry-run mode, backups, and confirmation prompts
- ⚡ **High Performance** - Optimized scanning and concurrent processing

## Implementations

This repository contains three complete, feature-compatible implementations:

### 🔷 [Go Implementation](./golang/)

**Best for:** Production use, performance-critical applications, standalone deployment

- **Performance:** Compiled binary, blazing fast (5-10s for 10k files)
- **UI:** Beautiful Bubble Tea TUI with real-time progress
- **Deployment:** Single binary, no dependencies, cross-platform builds
- **Testing:** 48.2% coverage with comprehensive unit tests
- **Concurrency:** Goroutines for efficient parallel processing

```bash
cd golang/
make build
./ebook-mechanic -dir ~/Books -repair
```

### 🔶 [Swift Implementation](./swift/)

**Best for:** macOS users, native app experience, Swift ecosystem integration

- **Performance:** Compiled native binary with actor-based concurrency
- **UI:** Dual interface - CLI + native macOS SwiftUI app
- **Architecture:** Modular Swift packages (Core + CLI + App)
- **Platform:** macOS 13+, iOS 16+ ready
- **Concurrency:** Swift actors for thread-safe operations
- **Advanced PDF Repair:** Comprehensive header corruption detection and repair with two-phase repair process (128+ comprehensive tests)

```bash
cd swift/
make build-all
make app-run  # Launch macOS app
```

### 🔸 [Python Implementation](./python/)

**Best for:** Python environments, prototyping, educational purposes

- **Performance:** Interpreted, functional (30-45s for 10k files)
- **UI:** Rich library for beautiful terminal output
- **Flexibility:** Modular scripts, easy to modify and extend
- **Portability:** Works anywhere Python 3 is available
- **Tools:** Includes test library generator

```bash
cd python/
python3 ebook_manager_tui.py ~/Books
```

## Quick Start

### Master Makefile (Unified Interface)

The root Makefile provides a unified build system for all implementations:

```bash
# Build both Go and Swift
make build

# Run all tests
make test

# Run specific implementation
make run-go        # Go CLI with TUI
make run-swift     # Swift CLI
make run-app       # Swift macOS app

# Generate test library for testing
make sample-library

# Compare implementations
make benchmark

# Install CLIs
make install

# See all commands
make help
```

### Direct Usage

Each implementation can also be used independently:

```bash
# Go
cd golang && make build && ./ebook-mechanic

# Swift
cd swift && make cli-build && make cli-run

# Python
cd python && python3 ebook_manager_tui.py
```

## Installation

### Prerequisites

| Implementation | Requirements |
|----------------|--------------|
| **Go** | Go 1.24+ |
| **Swift** | macOS with Xcode 15.0+, Swift 5.9+ |
| **Python** | Python 3.7+, Rich library (TUI only) |

### Install from Source

```bash
# Clone repository
git clone https://github.com/yourusername/EbookMechanic
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
ebook-mechanic -dir ~/Books

# Dry run (preview only)
ebook-mechanic -dir ~/Books -dry-run

# Repair corrupted files
ebook-mechanic -dir ~/Books -repair

# Normalize EPUB files
ebook-mechanic -dir ~/Books -normalize-epub
```

### Advanced Options

```bash
# Check corruption only (skip empty folders)
ebook-mechanic -corruption-only -repair

# Check empty folders only
ebook-mechanic -empty-folders-only

# Force EPUB normalization (even if already normalized)
ebook-mechanic -normalize-epub -force-normalize

# Keep backup files after operations
ebook-mechanic -normalize-epub -keep-backups

# Skip confirmation prompts
ebook-mechanic -no-confirm

# Simple text output (no TUI)
ebook-mechanic -no-tui
```

## Performance Comparison

Typical performance on 10,000 files across implementations:

| Implementation | Time | Memory | Binary Size | Startup Time |
|----------------|------|--------|-------------|--------------|
| **Go** | ~5-10s | ~15MB | ~8MB | <10ms |
| **Swift** | ~8-12s | ~20MB | ~2MB | <50ms |
| **Python** | ~30-45s | ~50MB | N/A (interpreted) | ~500ms |

*Benchmarks run on identical test libraries using `make benchmark`*

## Project Structure

```
EbookMechanic/
├── Makefile                    # Master build system (start here)
├── README.md                   # This file
├── CLAUDE.md                   # AI assistant instructions
│
├── golang/                     # Go implementation
│   ├── Makefile               # Go-specific build system
│   ├── README.md              # Go implementation docs
│   ├── main.go                # Entry point + Bubble Tea TUI
│   ├── validator.go           # Format validation logic
│   ├── scanner.go             # File scanning operations
│   ├── normalize.go           # EPUB normalization
│   ├── report.go              # Markdown reporting
│   └── *_test.go              # Comprehensive test suite
│
├── swift/                      # Swift implementation
│   ├── Makefile               # Swift-specific build system
│   ├── README.md              # Swift implementation docs
│   ├── EbookMechanicCore/     # Core library package
│   ├── EbookMechanicCLI/      # Command-line interface
│   └── EbookMechanicApp/      # macOS SwiftUI app
│
├── python/                     # Python implementation
│   ├── README.md              # Python implementation docs
│   ├── ebook_manager_tui.py   # Full TUI implementation
│   ├── ebook_manager.py       # Core validation logic
│   ├── check_corrupted_ebooks.py  # Corruption checker
│   ├── delete_empty_ebook_folders.py  # Folder cleanup
│   └── generate_test_library.py  # Test fixture generator
│
└── scripts/                    # Shared utilities
    └── benchmark.sh           # Cross-implementation benchmarks
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

### Language-Specific Commands

```bash
# Delegate to Go Makefile
make go-<target>              # e.g., make go-test-coverage

# Delegate to Swift Makefile
make swift-<target>           # e.g., make swift-docc-all
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

- **Go:** [golang/README.md](./golang/README.md) - Comprehensive Go implementation guide
- **Swift:** [swift/README.md](./swift/README.md) - Swift workspace and app documentation
- **Python:** [python/README.md](./python/README.md) - Python scripts and utilities

### Generate Documentation

```bash
# Generate all documentation
make docs

# Serve documentation locally
make docs-serve          # http://localhost:8080
```

## Shell Completion

All implementations support shell completion for Bash, Zsh, Fish, and PowerShell:

```bash
# Auto-detect and install for current shell
make completion-install

# Generate all completion scripts
make completion-generate
```

## Choosing an Implementation

| Use Case | Recommended Implementation |
|----------|---------------------------|
| **Production deployment** | Go - Single binary, best performance |
| **macOS native app** | Swift - Native SwiftUI interface |
| **Python environment** | Python - Easy integration, no compilation |
| **Maximum performance** | Go - Fastest execution, lowest memory |
| **Development/Prototyping** | Python - Easy to modify and experiment |
| **iOS integration** | Swift - iOS-ready architecture |
| **Cross-platform CLI** | Go - Works everywhere, no dependencies |

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
make benchmark

# Profile specific implementation
cd golang && make profile-cpu
```

### Test Failures

```bash
# Run full test suite
make test-all

# Test specific implementation
make go-test
make swift-test-all
```

## License

Free to use and modify.

## Acknowledgments

- **Go:** Built with [Bubble Tea](https://github.com/charmbracelet/bubbletea) and [Lipgloss](https://github.com/charmbracelet/lipgloss)
- **Python:** Uses [Rich](https://github.com/Textualize/rich) library for terminal UI
- **Swift:** Native SwiftUI and Swift Package Manager

---

**Quick Links:** [Go README](./golang/README.md) | [Swift README](./swift/README.md) | [Python README](./python/README.md) | [Master Makefile](./Makefile)

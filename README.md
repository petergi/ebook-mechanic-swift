# 📚 EbookMechanic

A comprehensive ebook library management toolkit with implementations in multiple languages.

## Project Overview

EbookMechanic is a powerful command-line tool for managing ebook libraries. It validates ebook files, detects corruption, repairs damaged files when possible, and maintains clean library organization.

### Supported Formats

- 📗 **EPUB** - Electronic Publication
- 📕 **MOBI** - Mobipocket  
- 📘 **AZW3** - Kindle Format 8
- 📙 **AZW4** - Kindle PDF Wrapper
- 📄 **PDF** - Portable Document Format

## Implementations

This repository contains three different implementations:

### 🚀 [Go Implementation](./golang/) (Recommended)

**Production Ready Status**: ✅

- **Performance**: Blazing fast (5-10x faster than Python)
- **UI**: Beautiful Bubble Tea TUI with real-time progress
- **Features**: Full corruption detection, auto-repair, EPUB normalization, empty folder cleanup
- **Testing**: 48.2% coverage with comprehensive unit tests  
- **Build**: Professional Makefile with 30+ commands
- **Deployment**: Single binary, cross-platform builds

```bash
cd golang/
make build
./ebook-mechanic
```

### 🐍 [Python Implementation](./python/)

**Status**: Legacy (feature-complete but slower)

- **Performance**: Functional but slower than Go version
- **UI**: Rich library for beautiful terminal output
- **Features**: Complete ebook validation and management
- **Use Case**: Good for prototyping and Python environments

### 🍎 [Swift Implementation](./swift/)

**Status**: ⚠️ In Development

- **Target**: Native macOS app with SwiftUI
- **Architecture**: Modular package structure
- **Status**: Basic CLI and app scaffolding complete
- **Development**: Active work in progress

## Quick Start

### Master Makefile (Recommended)

The project includes a **master Makefile** at the root that consolidates all implementations:

```bash
# Build both Go and Swift implementations
make build

# Run all tests
make test

# Run Go CLI (recommended)
make run-go

# Run Swift CLI
make run-swift

# Launch Swift macOS app
make run-app

# Generate test library for testing
make sample-library

# Compare Go vs Swift performance
make benchmark

# See all available commands
make help
```

### Go Implementation (Direct)

For direct access to the Go implementation:

```bash
# Clone and build
cd golang/
make deps
make build

# Run on current directory
./ebook-mechanic

# Run on specific directory with repair
./ebook-mechanic -dir ~/Books -repair

# Generate test library for testing
make sample-library
```

## Key Features

- 🔍 **Corruption Detection**: Deep validation of ebook file structures
- 🔧 **Auto-Repair**: Attempts to fix corrupted files automatically
- 🗑️ **Smart Cleanup**: Removes empty folders while preserving structure
- 📊 **Progress Tracking**: Real-time progress with beautiful TUI
- 📄 **Detailed Reports**: Markdown reports with full statistics
- 🔒 **Safe Operations**: Dry-run mode and confirmation prompts
- ⚡ **High Performance**: Concurrent processing for large libraries

## Development

### Unified Build System

The **master Makefile** at the root provides a unified interface for all implementations:

```bash
# Build and test everything
make build-all test-all

# Code quality checks
make check lint

# Install both CLIs
make install

# Clean all artifacts
make clean-all

# Language-specific delegation
make go-<target>     # Run any Go Makefile target
make swift-<target>  # Run any Swift Makefile target
```

### Per-Implementation Workflows

Each implementation also has its own development workflow:

- **Go**: See [golang/README.md](./golang/README.md) or use `make go-help`
- **Python**: Direct script execution with pip dependencies
- **Swift**: See [swift/README.md](./swift/) or use `make swift-help`

## Project Structure

```text
EbookMechanic/
├── Makefile            # 🎯 Master build system (start here!)
├── README.md           # This file
├── .github/            # GitHub configuration
│   └── copilot-instructions.md
├── golang/             # Go implementation (recommended)
│   ├── Makefile        # Go-specific build system
│   ├── *.go            # Source files
│   └── *_test.go       # Test suite
├── python/             # Python implementation (legacy)
│   └── *.py            # Python scripts
├── swift/              # Swift implementation (in development)
│   ├── Makefile        # Swift-specific build system
│   ├── EbookMechanicCore/    # Core library
│   ├── EbookMechanicCLI/     # Command-line interface
│   └── EbookMechanicApp/     # macOS SwiftUI app
└── scripts/            # Utility scripts
    └── benchmark.sh    # Cross-implementation benchmarking
```

## Performance Comparison

Typical performance on 10,000 files:

| Implementation | Time | Memory | Startup |
|----------------|------|--------|---------|
| **Go** | ~8s | ~15MB | <10ms |
| **Python** | ~30s | ~50MB | ~500ms |
| **Swift** | TBD | TBD | TBD |

## License

Free to use and modify.

## Contributing

Feel free to contribute to any implementation:

- **Go**: Production-ready, focus on performance and features
- **Python**: Maintenance mode, bug fixes welcome
- **Swift**: Active development, help appreciated

Each implementation has its own contribution guidelines in the respective directories.

---

**Recommendation**: Use the **Go implementation** for production use. It offers the best performance, most features, and active development.

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

**Status: ✅ Production Ready**

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

For most users, the **Go implementation** is recommended:

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

Each implementation has its own development workflow:

- **Go**: See [golang/README.md](./golang/README.md) for detailed instructions
- **Python**: Direct script execution with pip dependencies
- **Swift**: Xcode project with Package.swift

## Project Structure

```
EbookMechanic/
├── README.md           # This file
├── .github/            # GitHub configuration
│   └── copilot-instructions.md
├── golang/             # Go implementation (recommended)
│   ├── Makefile        # Professional build system
│   ├── *.go            # Source files
│   └── *_test.go       # Test suite
├── python/             # Python implementation (legacy)
│   └── *.py            # Python scripts
├── swift/              # Swift implementation (in development)
│   ├── EbookMechanicCore/    # Core library
│   ├── EbookMechanicCLI/     # Command-line interface
│   └── EbookMechanicApp/     # macOS SwiftUI app
└── scripts/            # Utility scripts
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

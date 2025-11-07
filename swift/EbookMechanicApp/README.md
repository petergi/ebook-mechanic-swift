# Swift Workspace – EbookMechanic

A modular Swift rewrite of the Go-based EbookMechanic toolchain. This project ships as an Xcode workspace with three components that share a common Swift package and expose comprehensive test suites.

## 📦 Components

### EbookMechanicCore
A Swift Package library with the scanning, validation, repair, and reporting engine. It exposes:
- Actor-based `FileScanner` for concurrent file processing
- Format-specific validators for EPUB and other ebook formats
- Markdown report generator
- Comprehensive XCTest coverage mirroring the Go implementation's behaviors

### EbookMechanicCLI
A command-line application providing:
- Fast text interface with progress feedback
- Optional repair/move/delete automation
- Markdown report generation
- Shell completion support (Bash, Zsh, Fish, PowerShell)
- Unit tests for configuration parsing

### EbookMechanicApp
A macOS SwiftUI application featuring:
- Visual scan interface with real-time progress
- Toggleable behavior options
- Summary views for corrupted files and empty folders
- Polished, gradient-backed UI
- View-model tests for predictable state management

## 🚀 Quick Start

### Prerequisites
- macOS with Xcode 15.0 or later
- Swift 5.9 or later
- Python 3 (for serving documentation)

### Building

```bash
# Build core library (default target)
make build

# Build all components (core + CLI + app)
make build-all

# Build optimized release binaries
make build-release
```

### Testing

```bash
# Run core library tests (default)
make test

# Run all test suites (core + CLI + app)
make test-all
```

### Installing the CLI

```bash
# Install optimized release version (recommended)
make install-release

# Or install debug version for development
make install

# Verify installation
ebook-mechanic --help

# Uninstall when needed
make uninstall
```

## 📖 CLI Usage

### Basic Commands

```bash
# Scan a directory for ebooks
ebook-mechanic scan ~/ebooks

# Validate a single EPUB file
ebook-mechanic validate ~/ebooks/mybook.epub

# Normalize an EPUB (dry-run mode)
ebook-mechanic normalize ~/ebooks/mybook.epub --dry-run

# Force normalize an EPUB (live mode)
ebook-mechanic normalize ~/ebooks/mybook.epub --force-normalize
```

### Running Without Installation

```bash
# Run CLI directly via Make
make cli-run ARGS="scan ~/ebooks"
make cli-run ARGS="--help"

# Or use Swift directly
swift run --package-path EbookMechanicCLI EbookMechanicCLI --help
```

## 🔧 EPUB Normalization Details

### ZIP Structure Normalization
- Rebuilds EPUBs into a canonical ZIP layout:
  - `mimetype` first and uncompressed, with exact contents `application/epub+zip`
  - All other entries are deflated (compression method 8) for compact, deterministic output
  - File names are UTF-8 with the language encoding flag set
  - Timestamps/attributes are normalized to fixed values for reproducible builds
- Ensures `META-INF/container.xml` exists and is correctly cased; synthesizes a minimal one if missing
- Removes extraneous files (e.g. `__MACOSX/*`, `.DS_Store`, `Thumbs.db`, `desktop.ini`)
- Performs light metadata normalization on text-based OPF files (UTF-8 re-encoding, normalized newlines)
- Dry-run support reports what would change; `--force-normalize` re-normalizes even already normalized files

### OPF (content.opf) Normalization
- Locate via META-INF/container.xml (rootfile@full-path)
- Canonicalize XML declaration, UTF-8 encoding, LF newlines
- Normalize metadata text (trim, collapse spaces, NFC)
- Sort `<metadata>` children deterministically
- Normalize `<manifest>` items:
  - Sort by id (then href)
  - Correct common media types (xhtml/css/images/opf)
  - Normalize hrefs (remove leading ./, fix casing to match ZIP entries)
  - Remove items for extraneous files
- Normalize `<spine>` order to follow manifest and remove invalid references

## 🐚 Shell Completion

The CLI supports shell completion for Bash, Zsh, Fish, and PowerShell.

### Generate All Completions

```bash
make cli-completions
```

This creates completion scripts in `./completions/`:
- `ebook-mechanic.bash` - Bash completion
- `_ebook-mechanic` - Zsh completion
- `ebook-mechanic.fish` - Fish completion
- `ebook-mechanic.ps1` - PowerShell completion

### Installation

```bash
# Bash
cp completions/ebook-mechanic.bash /usr/local/etc/bash_completion.d/

# Zsh
cp completions/_ebook-mechanic /usr/local/share/zsh/site-functions/

# Fish
cp completions/ebook-mechanic.fish ~/.config/fish/completions/

# PowerShell
. completions/ebook-mechanic.ps1
```

See [COMPLETIONS.md](COMPLETIONS.md) for detailed installation instructions.

## 📚 Documentation

### Generating Documentation

```bash
# Generate all documentation (core + app)
make docc-all

# Generate documentation for specific components
make docc-core    # Core library documentation
make docc-app     # App documentation

# Serve documentation locally at http://localhost:8080
make docc-serve
```

### Updating All Artifacts

```bash
# Regenerate completions and documentation
make update-all
```

## 🛠️ Development Workflow

### Common Tasks

```bash
# View all available targets
make help

# Build and test everything
make build-all test-all

# Run the SwiftUI app
make app-run

# Open in Xcode
make workspace

# Clean build artifacts
make clean

# Deep clean (includes completions and docs)
make clean-all

# View build information
make info
```

### Code Quality

```bash
# Format Swift code (requires swift-format)
make format

# Check code formatting (CI-friendly)
make check-format

# Lint code (requires SwiftLint)
make lint
```

### CI/CD

```bash
# Run full CI pipeline
make ci
# This runs: build-all + test-all + check-format
```

## 📁 Project Structure

```
EbookMechanic/
├── Makefile                      # Build automation and common tasks
├── EbookMechanic.xcworkspace     # Xcode workspace (optional)
│
├── EbookMechanicCore/            # Core library package
│   ├── Package.swift
│   ├── Sources/
│   │   └── EbookMechanicCore/
│   └── Tests/
│       └── EbookMechanicCoreTests/
│
├── EbookMechanicCLI/             # Command-line interface package
│   ├── Package.swift
│   ├── Sources/
│   │   └── EbookMechanicCLI/
│   └── Tests/
│       └── EbookMechanicCLITests/
│
├── EbookMechanicApp/             # macOS SwiftUI app package
│   ├── Package.swift
│   ├── Sources/
│   │   └── EbookMechanicApp/
│   └── Tests/
│       └── EbookMechanicAppTests/
│
└── completions/                  # Generated shell completions
    ├── ebook-mechanic.bash
    ├── _ebook-mechanic
    ├── ebook-mechanic.fish
    └── ebook-mechanic.ps1
```

## 🎯 Make Targets Reference

### Build Targets
- `make build` - Build core library only (default)
- `make build-all` - Build everything (core + CLI + app)
- `make build-release` - Build optimized release binaries
- `make core-build` - Build the core library
- `make cli-build` - Build the CLI executable
- `make app-build` - Build the macOS SwiftUI app

### Test Targets
- `make test` - Run core library tests (default)
- `make test-all` - Run all test suites (core + CLI + app)
- `make core-test` - Run the EbookMechanicCore test suite
- `make cli-test` - Run the CLI test suite
- `make app-test` - Run the app test suite

### Run Targets
- `make cli-run ARGS=` - Run the CLI (default: --help)
- `make cli-normalize` - Normalize EPUBs (dry-run mode)
- `make cli-normalize-force` - Force normalize EPUBs (live mode)
- `make app-run` - Launch the SwiftUI app

### Documentation Targets
- `make docc-all` - Generate all documentation (core + app)
- `make docc-core` - Generate DocC docs for EbookMechanicCore
- `make docc-app` - Generate DocC docs for EbookMechanicApp
- `make docc-serve` - Serve docs at http://localhost:8080

### Utility Targets
- `make cli-completions` - Generate shell completion scripts
- `make install` - Install CLI to /usr/local/bin (debug)
- `make install-release` - Install optimized CLI to /usr/local/bin
- `make uninstall` - Remove CLI from /usr/local/bin
- `make format` - Format all Swift code with swift-format
- `make lint` - Lint Swift code (requires SwiftLint)
- `make check-format` - Check if code is formatted (CI-friendly)
- `make workspace` - Open EbookMechanic.xcworkspace in Xcode
- `make clean` - Remove build artifacts for all packages
- `make clean-all` - Deep clean (includes completions & docs)
- `make info` - Display build information and sizes
- `make update-all` - Update completions and documentation

### CI/CD Targets
- `make ci` - Run full CI pipeline (build-all + test-all + check-format)

## 🔍 Troubleshooting

### Build Issues

```bash
# View build information and diagnostics
make info

# Clean and rebuild
make clean-all
make build-all
```

### Documentation Generation Fails

If `make docc-core` fails, see [DOCC_SETUP.md](DOCC_SETUP.md) for setup instructions.

### Permission Errors During Clean

The Makefile automatically fixes permissions before cleaning. If you still encounter issues:

```bash
# Manually fix permissions
chmod -R u+w EbookMechanicCore/.build
chmod -R u+w EbookMechanicCLI/.build
chmod -R u+w EbookMechanicApp/.build

# Then clean
make clean-all
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and test thoroughly (`make test-all`)
4. Format your code (`make format`)
5. Run the CI pipeline locally (`make ci`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## 📝 License

This project maintains compatibility with the original Go-based EbookMechanic toolchain.

## 🙏 Acknowledgments

- Original Go implementation of EbookMechanic
- Swift Package Manager and SwiftUI communities
- Contributors to the project

---

**Note**: This is a modular rewrite designed to maintain behavioral compatibility with the original Go implementation while leveraging Swift's modern concurrency features and native macOS integration.

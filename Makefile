# EbookMechanic - Master Makefile


.PHONY: help info version tree \
		clean clean-all clean-cli clean-epub-mechanic-cli clean-pdf-mechanic-cli clean-ebook-mechanic-app \
		clean-all clean-all-cli clean-all-epub-mechanic-cli clean-all-pdf-mechanic-cli \
		build build-all build-cli build-epub-mechanic-cli build-pdf-mechanic-cli build-ebook-mechanic-app \
		test test-cli test-cli-epub-mechanic test-pdf-mechanic-cli test-ebook-mechanic-app \
		test-all test-cli test-epub-mechanic-cli test-pdf-mechanic test-ebook-mechanic-app test-coverage \
		run run-ebook-mechanic-cli run-epub-mechanic-cli run-pdf-mechanic-cli run-ebook-mechanic-app \
		install install-ebook-mechanic-app install-ebook-mechanic-cli install-epub-mechanic-cli install-pdf-mechanic-cli \
		uninstall uninstall-cli uninstall-epub-mechanic-cli uninstall-pdf-mechanic-cli uninstall-app \
		check check-ebook-mechanic-cli check-epub-mechanic-cli check-pdf-mechanic-cli check-all check-all-cli check-ebook-mechanic-app \
		lint lint-ebook-mechanic-cli lint-epub-mechanic-cli lint-pdf-mechanic-cli \
		sample-library \
		benchmark \
		docs docs-all docs-swift docs-serve \
		swift-% \
		completion-install

# ==================== Configuration ====================

# Colors for output
COLOR_RESET=\033[0m
COLOR_BOLD=\033[1m
COLOR_GREEN=\033[32m
COLOR_YELLOW=\033[33m
COLOR_BLUE=\033[34m
COLOR_MAGENTA=\033[35m
COLOR_CYAN=\033[36m

# Directories
SWIFT_MAKEFILE=Makefile.swift
SCRIPTS_DIR=Scripts
PYTHON_DIR=Scripts
APP_INSTALL_PATH?=/Applications/EbookMechanic.app
APP_BUNDLE_NAME?=EbookMechanic.app

# Default test library settings
LIBRARY_DIR?=test-library
LIBRARY_AUTHORS?=10
LIBRARY_FORMATS?=pdf,epub,mobi,azw3,azw4

# Get version from git
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")

# ==================== Default Target ====================

.DEFAULT_GOAL := help

# ==================== Help & Info ====================

## help: Show this help message
help:
	@echo "$(COLOR_BOLD)╔═══════════════════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║          EbookMechanic - Master Build System              ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║              Ebook management toolkit                     ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)╚═══════════════════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)Usage:$(COLOR_RESET) make [target]"
	@echo ""
	@echo "$(COLOR_CYAN)🚀 Quick Start Commands:$(COLOR_RESET)"
	@printf "  $(COLOR_GREEN)%-35s$(COLOR_RESET) %s\n" "make build" "Build"
	@printf "  $(COLOR_GREEN)%-35s$(COLOR_RESET) %s\n" "make test" "Run all tests"
	@printf "  $(COLOR_GREEN)%-35s$(COLOR_RESET) %s\n" "make run-cli" "Run all-in-one CLI implementation"
	@printf "  $(COLOR_GREEN)%-35s$(COLOR_RESET) %s\n" "make run-app" "Launch Swift macOS App"
	@printf "  $(COLOR_GREEN)%-35s$(COLOR_RESET) %s\n" "make sample-library" "Generate test ebook library"
	@echo ""
	@echo "$(COLOR_CYAN)🏗️  Build Targets:$(COLOR_RESET)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "build" "Build both App and Swift CLI (all-in-one)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "build-all" "Build everything (CLIs and App)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "build-release" "Build optimized release binaries"
	@echo ""
	@echo "$(COLOR_CYAN)🧪 Test Targets:$(COLOR_RESET)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "test" "Run all tests"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "test-all" "Run comprehensive test suites"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "test-cli" "Run all-in-one CLI tests only"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "test-ebook-mechanic-cli" "Run Ebook Mechanic CLI tests only"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "test-epub-mechanic-cli" "Run EPUB Mechanic CLI tests only"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "test-pdf-mechanic-cli" "Run PDF Mechanic CLI tests only"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "test-ebook-mechanic-app" "Run Ebook Mechanic macOS App tests only"
	@echo ""
	@echo "$(COLOR_CYAN)🚀 Run Targets:$(COLOR_RESET)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "run" "Run all-in-one CLI (TUI mode)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "run-epub-mechanic-cli" "Run EPUB Mechanic CLI"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "run-pdf-mechanic-cli" "Run PDF Mechanic CLI"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "run-ebook-mechanic-cli" "Run Ebook Mechanic CLI"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "run-ebook-mechanic-app" "Run Ebook Mechanic macOS App"
	@echo ""
	@echo "$(COLOR_CYAN)📦 Installation:$(COLOR_RESET)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "install" "Install all CLIs to system"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "install-ebook-mechanic-cli" "Install Ebook Mechanic CLI"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "install-epub-mechanic-cli" "Install EPUB Mechanic CLI"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "install-pdf-mechanic-cli" "Install PDF Mechanic CLI"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "install-ebook-mechanic-app" "Install Ebook Mechanic macOS App"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "install-completions" "Install Shell Completions (auto-detect)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "uninstall" "Remove all installed binaries"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "uninstall-ebook-mechanic-cli" "Uninstall Ebook Mechanic CLI"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "uninstall-epub-mechanic-cli" "Uninstall EPUB Mechanic CLI"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "uninstall-pdf-mechanic-cli" "Uninstall PDF Mechanic CLI"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "uninstall-ebook-mechanic-app" "Uninstall Ebook Mechanic macOS App"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "uninstall-completions" "Uninstall Shell Completions (auto-detect)"
	@echo ""
	@echo "$(COLOR_CYAN)✅ Quality & Checks:$(COLOR_RESET)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "check" "Run all code quality checks"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "check-swift" "Run Swift checks (format lint)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "lint" "Run all linters"
	@echo ""
	@echo "$(COLOR_CYAN)📚 Documentation:$(COLOR_RESET)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "docs" "Generate documentation"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "docs-all" "Generate all documentation with details"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "docs-swift" "Generate Swift DocC documentation"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "docs-serve" "Serve documentation at http://localhost:8080"
	@echo ""
	@echo "$(COLOR_CYAN)🧹 Maintenance:$(COLOR_RESET)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "clean" "Clean build artifacts (all languages)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "clean-all" "Deep clean (includes caches and completions)"
	@echo ""
	@echo "$(COLOR_CYAN)🔬 Testing & Benchmarking:$(COLOR_RESET)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "sample-library" "Generate test ebook library with valid/corrupt files"
	@echo ""
	@echo "$(COLOR_CYAN)ℹ️  Information:$(COLOR_RESET)"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "info" "Show comprehensive project information"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "version" "Show version information"
	@printf "  $(COLOR_BLUE)%-35s$(COLOR_RESET) %s\n" "tree" "Display project directory structure"
	@echo ""
	@echo "$(COLOR_YELLOW)Examples:$(COLOR_RESET)"
	@printf "  %-45s %s\n" "make sample-library" "# Generate test library"
	@printf "  %-45s %s\n" "make docs && make docs-serve" "# Generate and serve documentation"
	@echo ""
	@echo "$(COLOR_YELLOW)Environment Variables:$(COLOR_RESET)"
	@printf "  %-45s %s\n" "LIBRARY_DIR" "Test library directory (default: test-library)"
	@printf "  %-45s %s\n" "LIBRARY_AUTHORS" "Number of authors (default: 10)"
	@printf "  %-45s %s\n" "LIBRARY_FORMATS" "Formats to generate (default: pdf,epub,mobi,azw3,azw4)"
	@echo ""

## info: Show comprehensive project information
info:
	@echo "$(COLOR_BOLD)╔════════════════════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║          EbookMechanic Project Information                 ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)╚════════════════════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@printf "$(COLOR_CYAN)%-20s$(COLOR_RESET) %s\n" "📦 Project:" "EbookMechanic"
	@printf "$(COLOR_CYAN)%-23s$(COLOR_RESET) %s\n" "🏷️  Version:" "$(VERSION)"
	@printf "$(COLOR_CYAN)%-20s$(COLOR_RESET) %s\n" "📅 Updated:" "$$(date '+%Y-%m-%d %H:%M:%S')"
	@echo ""
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)🔧 Implementations:$(COLOR_RESET)"
# 	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)✅ CLI & APP $(COLOR_RESET) (Active Development)"
	@printf "   $(COLOR_BLUE)%-25s$(COLOR_RESET) %s\n" "Location:" "Apps/ + Packages/"
	@printf "   $(COLOR_BLUE)%-25s$(COLOR_RESET) %s\n" "All-In-One CLI Binary:" "$$(if [ -f Packages/EbookMechanicCLI/.build/debug/EbookMechanicCLI ]; then echo '✓ Built'; else echo '✗ Not built'; fi)"
	@printf "   $(COLOR_BLUE)%-25s$(COLOR_RESET) %s\n" "EPUB CLI Binary:" "$$(if [ -f Packages/EbookMechanicEPUBCLI/.build/debug/EbookMechanicEPUBCLI ]; then echo '✓ Built'; else echo '✗ Not built'; fi)"
	@printf "   $(COLOR_BLUE)%-25s$(COLOR_RESET) %s\n" "PDF CLI Binary:" "$$(if [ -f Packages/EbookMechanicPDFCLI/.build/debug/EbookMechanicPDFCLI ]; then echo '✓ Built'; else echo '✗ Not built'; fi)"
	@printf "   $(COLOR_BLUE)%-25s$(COLOR_RESET) %s\n" "EbookApp Binary:" "$$(if [ -f Apps/EbookMechanicApp/.build/debug/EbookMechanicApp ]; then echo '✓ Built'; else echo '✗ Not built'; fi)"
	@printf "   $(COLOR_BLUE)%-25s$(COLOR_RESET) %s\n" "Swift:" "$$(swift --version 2>/dev/null | head -1 || echo 'Not installed')"
	@echo ""
	@echo "$(COLOR_YELLOW)🐍 Python Scripts$(COLOR_RESET) (Test Library Generator)"
	@printf "   $(COLOR_BLUE)%-25s$(COLOR_RESET) %s\n" "Location:" "$(PYTHON_DIR)/"
	@printf "   $(COLOR_BLUE)%-25s$(COLOR_RESET) %s\n" "Purpose:" "Test library generation & benchmarking"
	@printf "   $(COLOR_BLUE)%-25s$(COLOR_RESET) %s\n" "Python:" "$$(python3 --version 2>/dev/null || echo 'Not installed')"
	@echo ""
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)📚 Supported Formats:$(COLOR_RESET)"
	@echo ""
# 	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@printf "  %-10s %s\n" "📗 EPUB" "- Electronic Publication (with Sigil normalization)"
	@printf "  %-10s %s\n" "📕 MOBI" "- Mobipocket"
	@printf "  %-10s %s\n" "📘 AZW3" "- Kindle Format 8"
	@printf "  %-10s %s\n" "📙 AZW4" "- Kindle PDF Wrapper"
	@printf "  %-10s %s\n" "📄 PDF" "- Portable Document Format"
	@echo ""
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)✨ Features:$(COLOR_RESET)"
# 	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo ""
	@printf "  %-25s %s\n" "🔍 Corruption Detection" "- Validates file integrity across all formats"
	@printf "  %-25s %s\n" "🔧 Automatic Repair" "- Fixes damaged files when possible"
	@printf "  %-25s %s\n" "📚 EPUB Normalization" "- Restructures EPUBs to Sigil standards"
	@printf "  %-25s %s\n" "🗑️  Smart Cleanup" "- Removes empty directories"
	@printf "  %-25s %s\n" "📊 Markdown Reports" "- Detailed analysis and statistics"
	@printf "  %-25s %s\n" "🎨 Beautiful TUI" "- Interactive terminal interface (Swift)"
	@printf "  %-25s %s\n" "🖥️  Native macOS App" "- SwiftUI graphical interface (Swift)"
	@echo ""
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)📂 Repository Structure:$(COLOR_RESET)"
# 	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo ""
	@printf "  %-25s %s\n" "Apps/ + Packages/" "Swift workspace (Core + CLIs + macOS App)"
	@printf "  %-25s %s\n" "$(SCRIPTS_DIR)/" "Python scripts & test library generator & Benchmark utilities"
	@echo ""

## version: Show version information
version:
	@echo "$(COLOR_BOLD)EbookMechanic$(COLOR_RESET) version $(COLOR_GREEN)$(VERSION)$(COLOR_RESET)"
	@echo ""
	@echo "Git commit: $$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
	@echo "Branch:	   $$(git branch --show-current 2>/dev/null || echo 'unknown')"
	@echo "Build date: $$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

## tree: Display project directory structure
tree:
	@echo "$(COLOR_BOLD)╔════════════════════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║			   EbookMechanic Project Tree					 ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)╚════════════════════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@if command -v tree >/dev/null 2>&1; then \
		tree -L 3 -d; \
	else \
		echo "$(COLOR_YELLOW)⚠ 'tree' command not found. Install with: brew install tree (macOS) or apt install tree (Linux)$(COLOR_RESET)"; \
		echo ""; \
		echo "$(COLOR_CYAN)Showing basic directory structure:$(COLOR_RESET)"; \
		echo ""; \
		find . -type d \
			-not -path '*/\.*' \
			-not -path '*/build/*' \
			-not -path '*/dist/*' \
			-not -path '*/coverage/*' \
			-not -path '*/__pycache__/*' \
			-not -path '*/test-library/*' \
			-not -path '*/CORRUPTED/*' \
			-not -path '*/completions/*' \
			-not -path '*/.bench/*' \
			-not -path '*/.specstory/*' \
			-maxdepth 4 \
			| sed 's|^\./||' \
			| sed 's|[^/]*/|  |g' \
			| sed 's|^|  |' \
			| sort; \
	fi
	@echo ""
	@echo "$(COLOR_BLUE)Tip:$(COLOR_RESET) Install tree for better visualization: $(COLOR_CYAN)brew install tree$(COLOR_RESET)"

# ==================== Build Targets ====================

## build: Build both App and Swift CLI (all-in-one)
build:
	@echo "$(COLOR_BLUE)Building EbookMechanic (Swift CLI + App)...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) build
	@echo "$(COLOR_GREEN)✓ Build complete!$(COLOR_RESET)"

## build-all: Build everything (all CLIs and App)
build-all:
	@echo "$(COLOR_BLUE)Building all components...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) build-all
	@echo "$(COLOR_GREEN)✓ All components built!$(COLOR_RESET)"

## build-cli: Build all-in-one CLI
build-cli:
	@echo "$(COLOR_BLUE)Building EbookMechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) build-cli
	@echo "$(COLOR_GREEN)✓ CLI built!$(COLOR_RESET)"

## build-epub-mechanic-cli: Build EPUB Mechanic CLI
build-epub-mechanic-cli:
	@echo "$(COLOR_BLUE)Building EPUB Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) build-epub
	@echo "$(COLOR_GREEN)✓ EPUB Mechanic CLI built!$(COLOR_RESET)"

## build-pdf-mechanic-cli: Build PDF Mechanic CLI
build-pdf-mechanic-cli:
	@echo "$(COLOR_BLUE)Building PDF Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) build-pdf
	@echo "$(COLOR_GREEN)✓ PDF Mechanic CLI built!$(COLOR_RESET)"

## build-ebook-mechanic-app: Build Ebook Mechanic macOS App
build-ebook-mechanic-app:
	@echo "$(COLOR_BLUE)Building Ebook Mechanic App...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) build-app
	@echo "$(COLOR_GREEN)✓ Ebook Mechanic App built!$(COLOR_RESET)"

## build-release: Build optimized release binaries
build-release:
	@echo "$(COLOR_BLUE)Building optimized release binaries...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) build-release
	@echo "$(COLOR_GREEN)✓ Release builds complete!$(COLOR_RESET)"

# ==================== Test Targets ====================

## test: Run all tests
test:
	@echo "$(COLOR_BLUE)Running all tests...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) test
	@echo "$(COLOR_GREEN)✓ All tests passed!$(COLOR_RESET)"

## test-all: Run comprehensive test suites
test-all:
	@echo "$(COLOR_BLUE)Running comprehensive test suites...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) test-all
	@echo "$(COLOR_GREEN)✓ All test suites completed!$(COLOR_RESET)"

## test-cli: Run all-in-one CLI tests
test-cli:
	@echo "$(COLOR_BLUE)Running Ebook Mechanic CLI tests...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) test-cli
	@echo "$(COLOR_GREEN)✓ CLI tests passed!$(COLOR_RESET)"

## test-ebook-mechanic-cli: Run Ebook Mechanic CLI tests
test-ebook-mechanic-cli:
	@echo "$(COLOR_BLUE)Running Ebook Mechanic CLI tests...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) test-cli
	@echo "$(COLOR_GREEN)✓ Ebook Mechanic CLI tests passed!$(COLOR_RESET)"

## test-epub-mechanic-cli: Run EPUB Mechanic CLI tests
test-epub-mechanic-cli:
	@echo "$(COLOR_BLUE)Running EPUB Mechanic CLI tests...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) test-epub
	@echo "$(COLOR_GREEN)✓ EPUB Mechanic CLI tests passed!$(COLOR_RESET)"

## test-pdf-mechanic-cli: Run PDF Mechanic CLI tests
test-pdf-mechanic-cli:
	@echo "$(COLOR_BLUE)Running PDF Mechanic CLI tests...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) test-pdf
	@echo "$(COLOR_GREEN)✓ PDF Mechanic CLI tests passed!$(COLOR_RESET)"

## test-ebook-mechanic-app: Run Ebook Mechanic macOS App tests
test-ebook-mechanic-app:
	@echo "$(COLOR_BLUE)Running Ebook Mechanic App tests...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) test-app
	@echo "$(COLOR_GREEN)✓ Ebook Mechanic App tests passed!$(COLOR_RESET)"

# ==================== Run Targets ====================

## run: Run all-in-one CLI (alias for run-cli)
run: run-cli

## run-cli: Run all-in-one CLI
run-cli:
	@echo "$(COLOR_BLUE)Running Ebook Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) run-cli ARGS="$(ARGS)"

## run-ebook-mechanic-cli: Run Ebook Mechanic CLI
run-ebook-mechanic-cli:
	@echo "$(COLOR_BLUE)Running Ebook Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) run-cli ARGS="$(ARGS)"

## run-epub-mechanic-cli: Run EPUB Mechanic CLI
run-epub-mechanic-cli:
	@echo "$(COLOR_BLUE)Running EPUB Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) run-epub ARGS="$(ARGS)"

## run-pdf-mechanic-cli: Run PDF Mechanic CLI
run-pdf-mechanic-cli:
	@echo "$(COLOR_BLUE)Running PDF Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) run-pdf ARGS="$(ARGS)"

## run-ebook-mechanic-app: Run Ebook Mechanic macOS App
run-ebook-mechanic-app:
	@echo "$(COLOR_BLUE)Launching Ebook Mechanic App...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) run-app

## run-app: Run Ebook Mechanic macOS App (alias)
run-app: run-ebook-mechanic-app

# ==================== Installation ====================

## install: Install all CLIs to system
install:
	@echo "$(COLOR_BLUE)Installing all CLIs...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) install
	@$(MAKE) -f $(SWIFT_MAKEFILE) install-specialized
	@echo "$(COLOR_GREEN)✓ All CLIs installed!$(COLOR_RESET)"

## install-ebook-mechanic-cli: Install Ebook Mechanic CLI
install-ebook-mechanic-cli:
	@echo "$(COLOR_BLUE)Installing Ebook Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) install
	@echo "$(COLOR_GREEN)✓ Ebook Mechanic CLI installed!$(COLOR_RESET)"

## install-epub-mechanic-cli: Install EPUB Mechanic CLI
install-epub-mechanic-cli:
	@echo "$(COLOR_BLUE)Installing EPUB Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) install-epub
	@echo "$(COLOR_GREEN)✓ EPUB Mechanic CLI installed!$(COLOR_RESET)"

## install-pdf-mechanic-cli: Install PDF Mechanic CLI
install-pdf-mechanic-cli:
	@echo "$(COLOR_BLUE)Installing PDF Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) install-pdf
	@echo "$(COLOR_GREEN)✓ PDF Mechanic CLI installed!$(COLOR_RESET)"

## install-ebook-mechanic-app: Install Ebook Mechanic macOS App
install-ebook-mechanic-app:
	@echo "$(COLOR_BLUE)Installing Ebook Mechanic App...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) install-app
	@echo "$(COLOR_GREEN)✓ Ebook Mechanic App installed!$(COLOR_RESET)"

## install-completions: Install Shell Completions
install-completions:
	@echo "$(COLOR_BLUE)Installing shell completions...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) completions
	@echo "$(COLOR_GREEN)✓ Shell completions generated!$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)To install completions:$(COLOR_RESET)"
	@echo "  Bash:		 cp completions/ebook-mechanic.bash /usr/local/etc/bash_completion.d/"
	@echo "  Zsh:		 cp completions/_ebook-mechanic /usr/local/share/zsh/site-functions/"
	@echo "  Fish:		 cp completions/ebook-mechanic.fish ~/.config/fish/completions/"

## uninstall: Remove all installed binaries
uninstall:
	@echo "$(COLOR_BLUE)Uninstalling all CLIs...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) uninstall
	@$(MAKE) -f $(SWIFT_MAKEFILE) uninstall-specialized
	@echo "$(COLOR_GREEN)✓ All CLIs uninstalled!$(COLOR_RESET)"

## uninstall-ebook-mechanic-cli: Uninstall Ebook Mechanic CLI
uninstall-ebook-mechanic-cli:
	@echo "$(COLOR_BLUE)Uninstalling Ebook Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) uninstall
	@echo "$(COLOR_GREEN)✓ Ebook Mechanic CLI uninstalled!$(COLOR_RESET)"

## uninstall-epub-mechanic-cli: Uninstall EPUB Mechanic CLI
uninstall-epub-mechanic-cli:
	@echo "$(COLOR_BLUE)Uninstalling EPUB Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) uninstall-epub
	@echo "$(COLOR_GREEN)✓ EPUB Mechanic CLI uninstalled!$(COLOR_RESET)"

## uninstall-pdf-mechanic-cli: Uninstall PDF Mechanic CLI
uninstall-pdf-mechanic-cli:
	@echo "$(COLOR_BLUE)Uninstalling PDF Mechanic CLI...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) uninstall-pdf
	@echo "$(COLOR_GREEN)✓ PDF Mechanic CLI uninstalled!$(COLOR_RESET)"

## uninstall-ebook-mechanic-app: Uninstall Ebook Mechanic macOS App
uninstall-ebook-mechanic-app:
	@echo "$(COLOR_BLUE)Uninstalling Ebook Mechanic App...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) uninstall-app
	@echo "$(COLOR_GREEN)✓ Ebook Mechanic App uninstalled!$(COLOR_RESET)"

## uninstall-completions: Uninstall Shell Completions
uninstall-completions:
	@echo "$(COLOR_BLUE)Removing shell completions...$(COLOR_RESET)"
	@rm -f /usr/local/etc/bash_completion.d/ebook-mechanic.bash
	@rm -f /usr/local/share/zsh/site-functions/_ebook-mechanic
	@rm -f ~/.config/fish/completions/ebook-mechanic.fish
	@echo "$(COLOR_GREEN)✓ Shell completions removed!$(COLOR_RESET)"


# ==================== Quality Checks ====================

## check: Run all code quality checks
check: check-swift lint
	@echo ""
	@echo "$(COLOR_GREEN)✓ All quality checks passed!$(COLOR_RESET)"

## check-swift: Run Swift checks (format + lint)
check-swift:
	@echo "$(COLOR_BLUE)Running Swift quality checks...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) check-format || true

## lint: Run all linters
lint:
	@echo "$(COLOR_BLUE)Running linters...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) lint || true

# ==================== Test Library & Benchmarking ====================

## sample-library: Generate test ebook library
sample-library:
	@echo "$(COLOR_BLUE)Generating sample ebook library...$(COLOR_RESET)"
	@echo "  Authors: $(COLOR_CYAN)$(LIBRARY_AUTHORS)$(COLOR_RESET)"
	@echo "  Formats: $(COLOR_CYAN)$(LIBRARY_FORMATS)$(COLOR_RESET)"
	@echo "  Output:  $(COLOR_CYAN)$(LIBRARY_DIR)$(COLOR_RESET)"
	@python3 $(PYTHON_DIR)/generate_test_library.py \
		--output $(LIBRARY_DIR) \
		--authors $(LIBRARY_AUTHORS) \
		--formats $(LIBRARY_FORMATS) \
		--force
	@echo "$(COLOR_GREEN)✓ Sample library ready in $(LIBRARY_DIR)$(COLOR_RESET)"


# ==================== Documentation ====================

## docs: Generate documentation for both implementations
docs: docs-swift
	@echo ""
	@echo "$(COLOR_GREEN)✓ All documentation generated!$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_CYAN)To view documentation:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)Swift:$(COLOR_RESET) make docs-serve (http://localhost:8080)"

## docs-all: Generate comprehensive documentation
docs-all:
	@echo "$(COLOR_BLUE)Generating comprehensive documentation...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_CYAN)Swift DocC documentation:$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) docc-all
	@echo ""
	@echo "$(COLOR_GREEN)✓ All documentation generated!$(COLOR_RESET)"

## docs-swift: Generate Swift DocC documentation
docs-swift:
	@echo "$(COLOR_BLUE)Generating Swift DocC documentation...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) docc-all
	@echo "$(COLOR_GREEN)✓ Swift DocC documentation ready$(COLOR_RESET)"

## docs-serve: Serve documentation (Swift DocC or Go godoc)
docs-serve:
	@echo "$(COLOR_BLUE)Starting documentation server...$(COLOR_RESET)"
	@echo ""
	@if [ -d "Packages/EbookMechanicCore/.build/docc" ] || [ -d "Apps/EbookMechanicApp/.build/docc" ]; then \
		echo "$(COLOR_CYAN)Serving Swift DocC documentation at http://localhost:8080$(COLOR_RESET)"; \
		echo "$(COLOR_YELLOW)Press Ctrl+C to stop$(COLOR_RESET)"; \
		echo ""; \
		$(MAKE) -f $(SWIFT_MAKEFILE) docc-serve; \
	else \
		echo "$(COLOR_YELLOW)⚠ No Swift documentation found. Generating...$(COLOR_RESET)"; \
		echo ""; \
		$(MAKE) docs-swift && $(MAKE) -f $(SWIFT_MAKEFILE) docc-serve; \
	fi

# ==================== Clean Targets ====================

## clean: Clean build artifacts (all languages)
clean:
	@echo "$(COLOR_BLUE)Cleaning build artifacts...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) clean
	@rm -rf $(LIBRARY_DIR)
	@echo "$(COLOR_GREEN)✓ All artifacts cleaned$(COLOR_RESET)"

## clean-all: Deep clean (includes caches and completions)
clean-all:
	@echo "$(COLOR_BLUE)Deep cleaning project...$(COLOR_RESET)"
	@$(MAKE) -f $(SWIFT_MAKEFILE) clean-all
	@rm -rf $(LIBRARY_DIR)
	@rm -rf completions/
	@echo "$(COLOR_GREEN)✓ Deep clean complete$(COLOR_RESET)"

# ==================== Delegation Targets ====================

## swift-%: Delegate to Swift Makefile (e.g., make swift-core-test)
swift-%:
	@$(MAKE) -f $(SWIFT_MAKEFILE) $*

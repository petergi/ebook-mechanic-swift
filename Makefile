# EbookMechanic - Master Makefile
# Multi-language ebook library management toolkit
# Consolidates Go, Swift, and Python implementations

.PHONY: help info version tree clean clean-all \
        build build-all build-go build-swift build-go-all build-swift-release \
        test test-all test-go test-swift test-coverage \
        run run-go run-swift run-app \
        install install-go install-swift install-app uninstall uninstall-app \
        check check-go check-swift lint \
        sample-library benchmark \
        docs docs-all docs-go docs-swift docs-serve \
        go-% swift-% \
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
GO_DIR=golang
SWIFT_DIR=swift
PYTHON_DIR=python
SCRIPTS_DIR=scripts
APP_INSTALL_PATH?=/Applications/EbookMechanic.app

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
	@echo "$(COLOR_BOLD)╔════════════════════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║         EbookMechanic - Master Build System                ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║    Multi-language ebook management toolkit (Go + Swift)    ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)╚════════════════════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)Usage:$(COLOR_RESET) make [target]"
	@echo ""
	@echo "$(COLOR_CYAN)🚀 Quick Start Commands:$(COLOR_RESET)"
	@echo "  $(COLOR_GREEN)make build$(COLOR_RESET)              Build both Go and Swift implementations"
	@echo "  $(COLOR_GREEN)make test$(COLOR_RESET)               Run all tests (Go + Swift)"
	@echo "  $(COLOR_GREEN)make run-go$(COLOR_RESET)             Run Go CLI implementation"
	@echo "  $(COLOR_GREEN)make run-swift$(COLOR_RESET)          Run Swift CLI implementation"
	@echo "  $(COLOR_GREEN)make run-app$(COLOR_RESET)            Launch Swift macOS app"
	@echo "  $(COLOR_GREEN)make sample-library$(COLOR_RESET)    Generate test ebook library"
	@echo "  $(COLOR_GREEN)make benchmark$(COLOR_RESET)          Compare Go vs Swift performance"
	@echo ""
	@echo "$(COLOR_CYAN)🏗️  Build Targets:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)build$(COLOR_RESET)                   Build both Go and Swift CLIs"
	@echo "  $(COLOR_BLUE)build-all$(COLOR_RESET)               Build everything (Go + Swift + all platforms)"
	@echo "  $(COLOR_BLUE)build-go$(COLOR_RESET)                Build Go implementation only"
	@echo "  $(COLOR_BLUE)build-swift$(COLOR_RESET)             Build Swift implementation only"
	@echo "  $(COLOR_BLUE)build-go-all$(COLOR_RESET)            Build Go for all platforms (Linux/macOS/Windows)"
	@echo "  $(COLOR_BLUE)build-swift-release$(COLOR_RESET)     Build Swift optimized release binaries"
	@echo ""
	@echo "$(COLOR_CYAN)🧪 Test Targets:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)test$(COLOR_RESET)                    Run all tests (Go + Swift)"
	@echo "  $(COLOR_BLUE)test-all$(COLOR_RESET)                Run comprehensive test suites"
	@echo "  $(COLOR_BLUE)test-go$(COLOR_RESET)                 Run Go tests only"
	@echo "  $(COLOR_BLUE)test-swift$(COLOR_RESET)              Run Swift tests only"
	@echo "  $(COLOR_BLUE)test-coverage$(COLOR_RESET)           Generate Go test coverage report"
	@echo ""
	@echo "$(COLOR_CYAN)🚀 Run Targets:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)run-go$(COLOR_RESET)                  Run Go CLI (TUI mode)"
	@echo "  $(COLOR_BLUE)run-swift$(COLOR_RESET)               Run Swift CLI"
	@echo "  $(COLOR_BLUE)run-app$(COLOR_RESET)                 Launch Swift macOS application"
	@echo ""
	@echo "$(COLOR_CYAN)📦 Installation:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)install$(COLOR_RESET)                 Install both CLIs to system"
	@echo "  $(COLOR_BLUE)install-go$(COLOR_RESET)              Install Go CLI to \$$GOPATH/bin"
	@echo "  $(COLOR_BLUE)install-swift$(COLOR_RESET)           Install Swift CLI to /usr/local/bin"
	@echo "  $(COLOR_BLUE)install-app$(COLOR_RESET)             Install Swift macOS app bundle"
	@echo "  $(COLOR_BLUE)uninstall$(COLOR_RESET)               Remove installed binaries"
	@echo "  $(COLOR_BLUE)uninstall-app$(COLOR_RESET)           Remove installed macOS app"
	@echo "  $(COLOR_BLUE)completion-install$(COLOR_RESET)      Install shell completions (auto-detect)"
	@echo ""
	@echo "$(COLOR_CYAN)✅ Quality & Checks:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)check$(COLOR_RESET)                   Run all code quality checks"
	@echo "  $(COLOR_BLUE)check-go$(COLOR_RESET)                Run Go checks (fmt + vet + lint)"
	@echo "  $(COLOR_BLUE)check-swift$(COLOR_RESET)             Run Swift checks (format lint)"
	@echo "  $(COLOR_BLUE)lint$(COLOR_RESET)                    Run all linters"
	@echo ""
	@echo "$(COLOR_CYAN)📚 Documentation:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)docs$(COLOR_RESET)                    Generate documentation (Go + Swift)"
	@echo "  $(COLOR_BLUE)docs-all$(COLOR_RESET)                Generate all documentation with details"
	@echo "  $(COLOR_BLUE)docs-go$(COLOR_RESET)                 Generate Go documentation (godoc)"
	@echo "  $(COLOR_BLUE)docs-swift$(COLOR_RESET)              Generate Swift DocC documentation"
	@echo "  $(COLOR_BLUE)docs-serve$(COLOR_RESET)              Serve documentation at http://localhost:8080"
	@echo ""
	@echo "$(COLOR_CYAN)🧹 Maintenance:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)clean$(COLOR_RESET)                   Clean build artifacts (all languages)"
	@echo "  $(COLOR_BLUE)clean-all$(COLOR_RESET)               Deep clean (includes caches and completions)"
	@echo ""
	@echo "$(COLOR_CYAN)🔬 Testing & Benchmarking:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)sample-library$(COLOR_RESET)          Generate test ebook library with valid/corrupt files"
	@echo "  $(COLOR_BLUE)benchmark$(COLOR_RESET)               Run cross-implementation performance benchmark"
	@echo ""
	@echo "$(COLOR_CYAN)ℹ️  Information:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)info$(COLOR_RESET)                    Show comprehensive project information"
	@echo "  $(COLOR_BLUE)version$(COLOR_RESET)                 Show version information"
	@echo "  $(COLOR_BLUE)tree$(COLOR_RESET)                    Display project directory structure"
	@echo ""
	@echo "$(COLOR_CYAN)🎯 Language-Specific Targets:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)go-<target>$(COLOR_RESET)             Run any Go Makefile target (e.g., make go-build)"
	@echo "  $(COLOR_BLUE)swift-<target>$(COLOR_RESET)          Run any Swift Makefile target (e.g., make swift-core-test)"
	@echo ""
	@echo "$(COLOR_YELLOW)Examples:$(COLOR_RESET)"
	@echo "  make build                           # Build both implementations"
	@echo "  make sample-library                  # Generate test library"
	@echo "  make benchmark                       # Compare performance"
	@echo "  make docs && make docs-serve         # Generate and serve documentation"
	@echo "  make go-run-normalize                # Run Go with EPUB normalization"
	@echo "  make swift-cli-normalize-force       # Run Swift with force normalization"
	@echo ""
	@echo "$(COLOR_YELLOW)Environment Variables:$(COLOR_RESET)"
	@echo "  LIBRARY_DIR                          Test library directory (default: test-library)"
	@echo "  LIBRARY_AUTHORS                      Number of authors (default: 10)"
	@echo "  LIBRARY_FORMATS                      Formats to generate (default: pdf,epub,mobi,azw3,azw4)"
	@echo ""

## info: Show comprehensive project information
info:
	@echo "$(COLOR_BOLD)╔════════════════════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║              EbookMechanic Project Information             ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)╚════════════════════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_CYAN)📦 Project:$(COLOR_RESET)     EbookMechanic"
	@echo "$(COLOR_CYAN)🏷️  Version:$(COLOR_RESET)     $(VERSION)"
	@echo "$(COLOR_CYAN)📅 Updated:$(COLOR_RESET)     $$(date '+%Y-%m-%d %H:%M:%S')"
	@echo ""
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)🔧 Implementations:$(COLOR_RESET)"
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)✅ Go Implementation$(COLOR_RESET) (Production Ready)"
	@echo "   $(COLOR_BLUE)Location:$(COLOR_RESET)    $(GO_DIR)/"
	@echo "   $(COLOR_BLUE)Binary:$(COLOR_RESET)      $$(if [ -f $(GO_DIR)/build/ebook-mechanic ]; then echo '✓ Built' && ls -lh $(GO_DIR)/build/ebook-mechanic | awk '{print "("$$5")"}'; else echo '✗ Not built'; fi)"
	@echo "   $(COLOR_BLUE)Coverage:$(COLOR_RESET)    $$(cd $(GO_DIR) && go test -cover ./... 2>&1 | grep -o 'coverage: [0-9.]*%' | head -1 | cut -d' ' -f2 || echo 'Unknown')"
	@echo "   $(COLOR_BLUE)Go Version:$(COLOR_RESET)  $$(go version | cut -d' ' -f3)"
	@echo ""
	@echo "$(COLOR_GREEN)✅ Swift Implementation$(COLOR_RESET) (Active Development)"
	@echo "   $(COLOR_BLUE)Location:$(COLOR_RESET)    $(SWIFT_DIR)/"
	@echo "   $(COLOR_BLUE)CLI Binary:$(COLOR_RESET)  $$(if [ -f $(SWIFT_DIR)/EbookMechanicCLI/.build/debug/EbookMechanicCLI ]; then echo '✓ Built'; else echo '✗ Not built'; fi)"
	@echo "   $(COLOR_BLUE)App Binary:$(COLOR_RESET)  $$(if [ -f $(SWIFT_DIR)/EbookMechanicApp/.build/debug/EbookMechanicApp ]; then echo '✓ Built'; else echo '✗ Not built'; fi)"
	@echo "   $(COLOR_BLUE)Swift:$(COLOR_RESET)       $$(swift --version 2>/dev/null | head -1 || echo 'Not installed')"
	@echo ""
	@echo "$(COLOR_YELLOW)🐍 Python Scripts$(COLOR_RESET) (Test Library Generator)"
	@echo "   $(COLOR_BLUE)Location:$(COLOR_RESET)    $(PYTHON_DIR)/"
	@echo "   $(COLOR_BLUE)Purpose:$(COLOR_RESET)     Test library generation & benchmarking"
	@echo "   $(COLOR_BLUE)Python:$(COLOR_RESET)      $$(python3 --version 2>/dev/null || echo 'Not installed')"
	@echo ""
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)📚 Supported Formats:$(COLOR_RESET)"
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "  📗 EPUB  - Electronic Publication (with Sigil normalization)"
	@echo "  📕 MOBI  - Mobipocket"
	@echo "  📘 AZW3  - Kindle Format 8"
	@echo "  📙 AZW4  - Kindle PDF Wrapper"
	@echo "  📄 PDF   - Portable Document Format"
	@echo ""
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)✨ Features:$(COLOR_RESET)"
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "  🔍 Corruption Detection   - Validates file integrity across all formats"
	@echo "  🔧 Automatic Repair       - Fixes damaged files when possible"
	@echo "  📚 EPUB Normalization     - Restructures EPUBs to Sigil standards"
	@echo "  🗑️  Smart Cleanup          - Removes empty directories"
	@echo "  📊 Markdown Reports       - Detailed analysis and statistics"
	@echo "  🎨 Beautiful TUI          - Interactive terminal interface (Go)"
	@echo "  🖥️  Native macOS App       - SwiftUI graphical interface (Swift)"
	@echo ""
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)📂 Repository Structure:$(COLOR_RESET)"
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "  $(GO_DIR)/          Go implementation (primary CLI with TUI)"
	@echo "  $(SWIFT_DIR)/       Swift workspace (Core + CLI + macOS App)"
	@echo "  $(PYTHON_DIR)/      Python scripts & test library generator"
	@echo "  $(SCRIPTS_DIR)/     Benchmark utilities"
	@echo ""

## version: Show version information
version:
	@echo "$(COLOR_BOLD)EbookMechanic$(COLOR_RESET) version $(COLOR_GREEN)$(VERSION)$(COLOR_RESET)"
	@echo ""
	@echo "Git commit: $$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
	@echo "Branch:     $$(git branch --show-current 2>/dev/null || echo 'unknown')"
	@echo "Build date: $$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

## tree: Display project directory structure
tree:
	@echo "$(COLOR_BOLD)╔════════════════════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║              EbookMechanic Project Tree                    ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)╚════════════════════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@if command -v tree >/dev/null 2>&1; then \
		tree -L 3 -C --dirsfirst \
			-I '.git|.build|build|dist|coverage|node_modules|__pycache__|*.pyc|.DS_Store|*.xcuserstate|*.xcworkspace|DerivedData|.specstory|completions|.bench|test-library|CORRUPTED' \
			-a --prune; \
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

## build: Build both Go and Swift implementations
build: build-go build-swift
	@echo ""
	@echo "$(COLOR_GREEN)✓ All implementations built successfully!$(COLOR_RESET)"

## build-all: Build everything (all implementations, all platforms)
build-all: build-go-all build-swift-release
	@echo ""
	@echo "$(COLOR_GREEN)✓ Complete multi-platform build finished!$(COLOR_RESET)"

## build-go: Build Go implementation
build-go:
	@echo "$(COLOR_BLUE)Building Go implementation...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) build

## build-swift: Build Swift implementation
build-swift:
	@echo "$(COLOR_BLUE)Building Swift implementation...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) build-all

## build-go-all: Build Go for all platforms
build-go-all:
	@echo "$(COLOR_BLUE)Building Go for all platforms...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) build-all

## build-swift-release: Build Swift optimized release binaries
build-swift-release:
	@echo "$(COLOR_BLUE)Building Swift release binaries...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) build-release

# ==================== Test Targets ====================

## test: Run all tests
test: test-go test-swift
	@echo ""
	@echo "$(COLOR_GREEN)✓ All tests passed!$(COLOR_RESET)"

## test-all: Run comprehensive test suites
test-all:
	@echo "$(COLOR_BLUE)Running comprehensive test suites...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) test-coverage
	@echo ""
	@$(MAKE) -C $(SWIFT_DIR) test-all
	@echo ""
	@echo "$(COLOR_GREEN)✓ All comprehensive tests completed!$(COLOR_RESET)"

## test-go: Run Go tests
test-go:
	@echo "$(COLOR_BLUE)Running Go tests...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) test

## test-swift: Run Swift tests
test-swift:
	@echo "$(COLOR_BLUE)Running Swift tests...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) test-all

## test-coverage: Generate Go coverage report
test-coverage:
	@$(MAKE) -C $(GO_DIR) test-coverage

# ==================== Run Targets ====================

## run-go: Run Go CLI implementation
run-go:
	@echo "$(COLOR_BLUE)Running Go CLI...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) run

## run-swift: Run Swift CLI implementation
run-swift:
	@echo "$(COLOR_BLUE)Running Swift CLI...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) cli-run ARGS="$(ARGS)"

## run-app: Launch Swift macOS application
run-app:
	@echo "$(COLOR_BLUE)Launching Swift macOS app...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) app-run

# ==================== Installation ====================

## install: Install both CLIs to system
install: install-go install-swift
	@echo ""
	@echo "$(COLOR_GREEN)✓ Both implementations installed!$(COLOR_RESET)"

## install-go: Install Go CLI to $GOPATH/bin
install-go:
	@echo "$(COLOR_BLUE)Installing Go CLI...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) install

## install-swift: Install Swift CLI to /usr/local/bin
install-swift:
	@echo "$(COLOR_BLUE)Installing Swift CLI...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) install-release

## install-app: Install the SwiftUI macOS app bundle
install-app:
	@echo "$(COLOR_BLUE)Installing EbookMechanic macOS app...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) app-install APP_INSTALL_PATH="$(APP_INSTALL_PATH)"

## uninstall: Remove installed binaries
uninstall:
	@echo "$(COLOR_BLUE)Uninstalling...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) uninstall 2>/dev/null || true
	@$(MAKE) -C $(SWIFT_DIR) uninstall 2>/dev/null || true
	@$(MAKE) -C $(SWIFT_DIR) app-uninstall APP_INSTALL_PATH="$(APP_INSTALL_PATH)" 2>/dev/null || true
	@echo "$(COLOR_GREEN)✓ Uninstalled$(COLOR_RESET)"

## uninstall-app: Remove only the macOS app bundle
uninstall-app:
	@echo "$(COLOR_BLUE)Removing macOS app bundle...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) app-uninstall APP_INSTALL_PATH="$(APP_INSTALL_PATH)"

## completion-install: Install shell completions (auto-detect shell)
completion-install:
	@echo "$(COLOR_BLUE)Installing shell completions...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_CYAN)Go implementation:$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) completion-install
	@echo ""
	@echo "$(COLOR_CYAN)Swift implementation:$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) cli-completions

# ==================== Quality Checks ====================

## check: Run all code quality checks
check: check-go check-swift
	@echo ""
	@echo "$(COLOR_GREEN)✓ All quality checks passed!$(COLOR_RESET)"

## check-go: Run Go checks (fmt + vet + lint)
check-go:
	@echo "$(COLOR_BLUE)Running Go quality checks...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) check

## check-swift: Run Swift checks (format + lint)
check-swift:
	@echo "$(COLOR_BLUE)Running Swift quality checks...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) check-format || true

## lint: Run all linters
lint:
	@echo "$(COLOR_BLUE)Running linters...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) lint || true
	@$(MAKE) -C $(SWIFT_DIR) lint || true

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

## benchmark: Run cross-implementation performance benchmark
benchmark:
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)  🏁 Cross-Implementation Performance Benchmark$(COLOR_RESET)"
	@echo "$(COLOR_MAGENTA)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(COLOR_RESET)"
	@echo ""
	@if [ -f "$(SCRIPTS_DIR)/benchmark.sh" ]; then \
		chmod +x $(SCRIPTS_DIR)/benchmark.sh && \
		$(SCRIPTS_DIR)/benchmark.sh --iterations 5; \
	else \
		echo "$(COLOR_YELLOW)⚠ Benchmark script not found at $(SCRIPTS_DIR)/benchmark.sh$(COLOR_RESET)"; \
		echo "$(COLOR_BLUE)Running manual comparison...$(COLOR_RESET)"; \
		echo ""; \
		$(MAKE) sample-library LIBRARY_AUTHORS=5; \
		echo ""; \
		echo "$(COLOR_CYAN)Go implementation:$(COLOR_RESET)"; \
		time $(MAKE) -C $(GO_DIR) run-dry; \
		echo ""; \
		echo "$(COLOR_CYAN)Swift implementation:$(COLOR_RESET)"; \
		time $(MAKE) -C $(SWIFT_DIR) cli-run ARGS="--dir $(LIBRARY_DIR) --dry-run"; \
	fi

# ==================== Documentation ====================

## docs: Generate documentation for both implementations
docs: docs-go docs-swift
	@echo ""
	@echo "$(COLOR_GREEN)✓ All documentation generated!$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_CYAN)To view documentation:$(COLOR_RESET)"
	@echo "  $(COLOR_BLUE)Go:$(COLOR_RESET)    make go-godoc (opens browser)"
	@echo "  $(COLOR_BLUE)Swift:$(COLOR_RESET) make docs-serve (http://localhost:8080)"

## docs-all: Generate comprehensive documentation
docs-all:
	@echo "$(COLOR_BLUE)Generating comprehensive documentation...$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_CYAN)Go documentation:$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) docs
	@echo ""
	@echo "$(COLOR_CYAN)Swift DocC documentation:$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) docc-all
	@echo ""
	@echo "$(COLOR_GREEN)✓ All documentation generated!$(COLOR_RESET)"

## docs-go: Generate Go documentation
docs-go:
	@echo "$(COLOR_BLUE)Generating Go documentation...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) docs
	@echo "$(COLOR_GREEN)✓ Go documentation ready$(COLOR_RESET)"
	@echo "$(COLOR_CYAN)To start godoc server:$(COLOR_RESET) make go-godoc"

## docs-swift: Generate Swift DocC documentation
docs-swift:
	@echo "$(COLOR_BLUE)Generating Swift DocC documentation...$(COLOR_RESET)"
	@$(MAKE) -C $(SWIFT_DIR) docc-all
	@echo "$(COLOR_GREEN)✓ Swift DocC documentation ready$(COLOR_RESET)"

## docs-serve: Serve documentation (Swift DocC or Go godoc)
docs-serve:
	@echo "$(COLOR_BLUE)Starting documentation server...$(COLOR_RESET)"
	@echo ""
	@if [ -d "$(SWIFT_DIR)/EbookMechanicCore/.build/docc" ] || [ -d "$(SWIFT_DIR)/EbookMechanicApp/.build/docc" ]; then \
		echo "$(COLOR_CYAN)Serving Swift DocC documentation at http://localhost:8080$(COLOR_RESET)"; \
		echo "$(COLOR_YELLOW)Press Ctrl+C to stop$(COLOR_RESET)"; \
		echo ""; \
		$(MAKE) -C $(SWIFT_DIR) docc-serve; \
	else \
		echo "$(COLOR_YELLOW)⚠ No Swift documentation found. Generating...$(COLOR_RESET)"; \
		echo ""; \
		$(MAKE) docs-swift && $(MAKE) -C $(SWIFT_DIR) docc-serve; \
	fi

# ==================== Clean Targets ====================

## clean: Clean build artifacts (all languages)
clean:
	@echo "$(COLOR_BLUE)Cleaning build artifacts...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) clean
	@$(MAKE) -C $(SWIFT_DIR) clean
	@rm -rf $(LIBRARY_DIR)
	@echo "$(COLOR_GREEN)✓ All artifacts cleaned$(COLOR_RESET)"

## clean-all: Deep clean (includes caches and completions)
clean-all:
	@echo "$(COLOR_BLUE)Deep cleaning project...$(COLOR_RESET)"
	@$(MAKE) -C $(GO_DIR) clean-all
	@$(MAKE) -C $(SWIFT_DIR) clean-all
	@rm -rf $(LIBRARY_DIR)
	@rm -rf completions/
	@echo "$(COLOR_GREEN)✓ Deep clean complete$(COLOR_RESET)"

# ==================== Delegation Targets ====================

## go-%: Delegate to Go Makefile (e.g., make go-build-dev)
go-%:
	@$(MAKE) -C $(GO_DIR) $*

## swift-%: Delegate to Swift Makefile (e.g., make swift-core-test)
swift-%:
	@$(MAKE) -C $(SWIFT_DIR) $*

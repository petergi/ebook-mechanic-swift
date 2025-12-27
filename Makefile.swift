# EbookMechanic Swift workspace make targets

# Environment setup for reproducible builds
SPM_ENV := SWIFT_MODULE_CACHE_PATH=.build/module-cache CLANG_MODULE_CACHE_PATH=.build/module-cache
SELF_MAKEFILE := $(lastword $(MAKEFILE_LIST))
MAKE_SELF := $(MAKE) -f $(SELF_MAKEFILE)

# CLI install configuration
BIN_INSTALL_PATH ?= /usr/local/bin
CLI_INSTALL_NAME ?= ebook-mechanic
CLI_INSTALL_TARGET := $(BIN_INSTALL_PATH)/$(CLI_INSTALL_NAME)
CLI_DEBUG_BINARY := Packages/EbookMechanicCLI/.build/debug/EbookMechanicCLI
CLI_RELEASE_BINARY := Packages/EbookMechanicCLI/.build/release/EbookMechanicCLI

# EPUB Mechanic CLI configuration
EPUB_CLI_INSTALL_NAME ?= epub-mechanic
EPUB_CLI_INSTALL_TARGET := $(BIN_INSTALL_PATH)/$(EPUB_CLI_INSTALL_NAME)
EPUB_CLI_DEBUG_BINARY := Packages/EbookMechanicEPUBCLI/.build/debug/EbookMechanicEPUBCLI
EPUB_CLI_RELEASE_BINARY := Packages/EbookMechanicEPUBCLI/.build/release/EbookMechanicEPUBCLI

# PDF Mechanic CLI configuration
PDF_CLI_INSTALL_NAME ?= pdf-mechanic
PDF_CLI_INSTALL_TARGET := $(BIN_INSTALL_PATH)/$(PDF_CLI_INSTALL_NAME)
PDF_CLI_DEBUG_BINARY := Packages/EbookMechanicPDFCLI/.build/debug/EbookMechanicPDFCLI
PDF_CLI_RELEASE_BINARY := Packages/EbookMechanicPDFCLI/.build/release/EbookMechanicPDFCLI

# Default shell configuration for better error handling
SHELL := /bin/zsh
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:

# Phony targets (targets that don't represent files)
.PHONY: help build build-all build-release test test-all test-core build-core build-cli run-cli normalize normalize-force test-cli completions build-app run-app test-app install-app uninstall-app build-epub build-epub-release test-epub run-epub install-epub install-epub-release uninstall-epub build-pdf build-pdf-release test-pdf run-pdf install-pdf install-pdf-release uninstall-pdf build-specialized install-specialized uninstall-specialized workspace clean clean-all docc-core docc-app docc-serve docc-all install install-release uninstall format check-format lint ci info update-all test-external-tools

# Default target when running 'make' with no arguments
.DEFAULT_GOAL := build

help:
	@echo "EbookMechanic Make Targets"
	@echo "================================"
	@echo ""
	@echo "🏗️  Build Targets:"
	@printf "  %-30s %s\n" "make build" "Build core library only (default)"
	@printf "  %-30s %s\n" "make build-all" "Build everything (core + all CLIs + app)"
	@printf "  %-30s %s\n" "make build-release" "Build optimized release binaries"
	@printf "  %-30s %s\n" "make build-core" "Build the core library"
	@printf "  %-30s %s\n" "make build-cli" "Build the main CLI executable"
	@printf "  %-30s %s\n" "make build-app" "Build the macOS SwiftUI app"
	@printf "  %-30s %s\n" "make build-specialized" "Build specialized CLIs (EPUB + PDF)"
	@printf "  %-30s %s\n" "make build-epub" "Build EPUB Mechanic CLI"
	@printf "  %-30s %s\n" "make build-pdf" "Build PDF Mechanic CLI"
	@echo ""
	@echo "🧪 Test Targets:"
	@printf "  %-30s %s\n" "make test" "Run core library tests (default)"
	@printf "  %-30s %s\n" "make test-all" "Run all test suites (core + all CLIs + app)"
	@printf "  %-30s %s\n" "make test-core" "Run the EbookMechanicCore test suite"
	@printf "  %-30s %s\n" "make test-cli" "Run the main CLI test suite"
	@printf "  %-30s %s\n" "make test-app" "Run the app test suite"
	@printf "  %-30s %s\n" "make test-epub" "Run EPUB Mechanic CLI tests"
	@printf "  %-30s %s\n" "make test-pdf" "Run PDF Mechanic CLI tests"
	@printf "  %-30s %s\n" "make test-external-tools" "Run external tools integration test"
	@echo ""
	@echo "🚀 Run Targets:"
	@printf "  %-30s %s\n" "make run-cli ARGS=" "Run the main CLI (default: --help)"
	@printf "  %-30s %s\n" "make normalize" "Normalize EPUBs (dry-run mode)"
	@printf "  %-30s %s\n" "make normalize-force" "Force normalize EPUBs (live mode)"
	@printf "  %-30s %s\n" "make run-app" "Launch the SwiftUI app"
	@printf "  %-30s %s\n" "make run-epub ARGS=" "Run EPUB Mechanic CLI"
	@printf "  %-30s %s\n" "make run-pdf ARGS=" "Run PDF Mechanic CLI"
	@echo ""
	@echo "📚 Documentation Targets:"
	@printf "  %-30s %s\n" "make docc-all" "Generate all documentation (core + app)"
	@printf "  %-30s %s\n" "make docc-core" "Generate DocC docs for EbookMechanicCore"
	@printf "  %-30s %s\n" "make docc-app" "Generate DocC docs for EbookMechanicApp"
	@printf "  %-30s %s\n" "make docc-serve" "Serve docs at http://localhost:8080"
	@echo ""
	@echo "🛠️  Utility Targets:"
	@printf "  %-30s %s\n" "make completions" "Generate shell completion scripts"
	@printf "  %-30s %s\n" "make install" "Install main CLI to $(BIN_INSTALL_PATH) (debug)"
	@printf "  %-30s %s\n" "make install-release" "Install optimized main CLI to $(BIN_INSTALL_PATH)"
	@printf "  %-30s %s\n" "make install-app" "Build & copy the macOS app bundle"
	@printf "  %-30s %s\n" "make install-specialized" "Install specialized CLIs (EPUB + PDF)"
	@printf "  %-30s %s\n" "make install-epub" "Install EPUB Mechanic CLI"
	@printf "  %-30s %s\n" "make install-epub-release" "Install optimized EPUB Mechanic CLI"
	@printf "  %-30s %s\n" "make install-pdf" "Install PDF Mechanic CLI"
	@printf "  %-30s %s\n" "make install-pdf-release" "Install optimized PDF Mechanic CLI"
	@printf "  %-30s %s\n" "make uninstall" "Remove main CLI from $(BIN_INSTALL_PATH)"
	@printf "  %-30s %s\n" "make uninstall-app" "Remove installed macOS app bundle"
	@printf "  %-30s %s\n" "make uninstall-specialized" "Uninstall specialized CLIs"
	@printf "  %-30s %s\n" "make uninstall-epub" "Uninstall EPUB Mechanic CLI"
	@printf "  %-30s %s\n" "make uninstall-pdf" "Uninstall PDF Mechanic CLI"
	@printf "  %-30s %s\n" "make format" "Format all Swift code with swift-format"
	@printf "  %-30s %s\n" "make lint" "Lint Swift code (requires SwiftLint)"
	@printf "  %-30s %s\n" "make check-format" "Check if code is formatted (CI-friendly)"
	@printf "  %-30s %s\n" "make workspace" "Open EbookMechanic.xcworkspace in Xcode"
	@printf "  %-30s %s\n" "make clean" "Remove build artifacts for all packages"
	@printf "  %-30s %s\n" "make clean-all" "Deep clean (includes completions & docs)"
	@printf "  %-30s %s\n" "make info" "Display build information and sizes"
	@printf "  %-30s %s\n" "make update-all" "Update completions and documentation"
	@echo ""
	@echo "🤖 CI/CD Targets:"
	@printf "  %-30s %s\n" "make ci" "Run full CI pipeline (build-all + test-all + check-format)"
	@echo ""
	@echo "Environment defaults:"
	@echo "  SWIFT_MODULE_CACHE_PATH and CLANG_MODULE_CACHE_PATH are pinned to .build/module-cache"
	@echo "  to keep sandboxed builds reproducible. Override SPM_ENV to customise."
	@echo ""
	@echo "DocC documentation:"
	@echo "  See DOCC_SETUP.md for setup instructions if 'make docc-core' fails."

# Makefile Naming Convention:
# Targets follow the pattern: action-target
# Examples: test-core, build-cli, run-app, install-specialized
# This provides consistent, readable target names across all Makefiles.

# Default target
build: build-core

# Build all components
build-all: build-core build-cli build-app build-specialized
	@echo ""
	@echo "✅ All components built successfully!"

# Build specialized CLIs
build-specialized: build-epub build-pdf
	@echo ""
	@echo "✅ Specialized CLIs built successfully!"

# Release builds (optimized)
build-release:
	@echo "🚀 Building optimized release binaries..."
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicCore -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicCLI -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path Apps/EbookMechanicApp -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicEPUBCLI -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicPDFCLI -c release
	@echo "✅ Release builds complete!"
	@echo ""
	@echo "Main CLI binary: Packages/EbookMechanicCLI/.build/release/EbookMechanicCLI"
	@echo "EPUB CLI binary: Packages/EbookMechanicEPUBCLI/.build/release/EbookMechanicEPUBCLI"
	@echo "PDF CLI binary:  Packages/EbookMechanicPDFCLI/.build/release/EbookMechanicPDFCLI"

# Default test target now exercises core, CLI, and app (including UI hooks)
test: test-core test-cli test-app

# Run all test suites
test-all:
	@echo "🧪 Running all test suites..."
	@echo ""
	@$(MAKE_SELF) test-core
	@echo ""
	@$(MAKE_SELF) test-cli
	@echo ""
	@$(MAKE_SELF) test-app
	@echo ""
	@$(MAKE_SELF) test-epub
	@echo ""
	@$(MAKE_SELF) test-pdf
	@echo ""
	@echo "✅ All test suites completed!"

test-core:
	@echo "🧪 Running EbookMechanicCore tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path Packages/EbookMechanicCore

build-core:
	@echo "🔨 Building EbookMechanicCore..."
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicCore

build-cli:
	@echo "🔨 Building EbookMechanicCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicCLI

run-cli:
	$(SPM_ENV) swift run --disable-sandbox --package-path Packages/EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--help)

normalize:
	$(SPM_ENV) swift run --disable-sandbox --package-path Packages/EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--normalize-epubs --dry-run)

normalize-force:
	$(SPM_ENV) swift run --disable-sandbox --package-path Packages/EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--normalize-epubs --force-normalize --dry-run=false)

test-cli:
	@echo "🧪 Running EbookMechanicCLI tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path Packages/EbookMechanicCLI

completions:
	@echo "📝 Generating shell completion scripts..."
	@mkdir -p completions
	@$(SPM_ENV) swift run --disable-sandbox --package-path Packages/EbookMechanicCLI EbookMechanicCLI --generate-completion bash > completions/ebook-mechanic.bash
	@$(SPM_ENV) swift run --disable-sandbox --package-path Packages/EbookMechanicCLI EbookMechanicCLI --generate-completion zsh > completions/_ebook-mechanic
	@$(SPM_ENV) swift run --disable-sandbox --package-path Packages/EbookMechanicCLI EbookMechanicCLI --generate-completion fish > completions/ebook-mechanic.fish
	@$(SPM_ENV) swift run --disable-sandbox --package-path Packages/EbookMechanicCLI EbookMechanicCLI --generate-completion powershell > completions/ebook-mechanic.ps1
	@echo "✅ Completion scripts generated in ./completions/"
	@echo ""
	@echo "To install:"
	@echo "  Bash:       cp completions/ebook-mechanic.bash /usr/local/etc/bash_completion.d/"
	@echo "  Zsh:        cp completions/_ebook-mechanic /usr/local/share/zsh/site-functions/"
	@echo "  Fish:       cp completions/ebook-mechanic.fish ~/.config/fish/completions/"
	@echo "  PowerShell: . completions/ebook-mechanic.ps1"

build-app:
	@echo "🔨 Building EbookMechanicApp..."
	$(SPM_ENV) swift build --disable-sandbox --package-path Apps/EbookMechanicApp

app-build: app-bundle-debug

run-app:
	$(SPM_ENV) swift run --disable-sandbox --package-path Apps/EbookMechanicApp EbookMechanicApp

app-run: app-bundle-debug
	@echo "🚀 Running EbookMechanicApp..."
	@Apps/EbookMechanicApp/.build/AppBundle/$(APP_BUNDLE_NAME)/Contents/MacOS/EbookMechanicApp

test-app:
	@echo "🧪 Running EbookMechanicApp tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path Apps/EbookMechanicApp

# EPUB Mechanic CLI targets
build-epub:
	@echo "🔨 Building EbookMechanicEPUBCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicEPUBCLI

build-epub-release:
	@echo "🚀 Building optimized EbookMechanicEPUBCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicEPUBCLI -c release

test-epub:
	@echo "🧪 Running EbookMechanicEPUBCLI tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path Packages/EbookMechanicEPUBCLI

run-epub:
	$(SPM_ENV) swift run --disable-sandbox --package-path Packages/EbookMechanicEPUBCLI EbookMechanicEPUBCLI $(if $(ARGS),$(ARGS),--help)

install-epub: build-epub
	@echo "📦 Installing EbookMechanicEPUBCLI to $(EPUB_CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(EPUB_CLI_DEBUG_BINARY)" ]; then \
		echo "❌ Error: Binary not found. Run 'make build-epub' first."; \
		exit 1; \
	fi
	@if install -m 755 "$(EPUB_CLI_DEBUG_BINARY)" "$(EPUB_CLI_INSTALL_TARGET)"; then \
		strip "$(EPUB_CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed to $(EPUB_CLI_INSTALL_TARGET)"; \
	else \
		echo "❌ Error: install command failed. Try 'sudo make install-epub'."; \
		exit 1; \
	fi

install-epub-release: build-epub-release
	@echo "📦 Installing optimized EbookMechanicEPUBCLI to $(EPUB_CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(EPUB_CLI_RELEASE_BINARY)" ]; then \
		echo "❌ Error: Release binary not found."; \
		exit 1; \
	fi
	@if install -m 755 "$(EPUB_CLI_RELEASE_BINARY)" "$(EPUB_CLI_INSTALL_TARGET)"; then \
		strip "$(EPUB_CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed optimized binary to $(EPUB_CLI_INSTALL_TARGET)"; \
	else \
		echo "❌ Error: install command failed. Try 'sudo make install-epub-release'."; \
		exit 1; \
	fi

uninstall-epub:
	@echo "🗑️  Uninstalling $(EPUB_CLI_INSTALL_NAME)..."
	@rm -f "$(EPUB_CLI_INSTALL_TARGET)"
	@echo "✅ Uninstalled!"

# PDF Mechanic CLI targets
build-pdf:
	@echo "🔨 Building EbookMechanicPDFCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicPDFCLI

build-pdf-release:
	@echo "🚀 Building optimized EbookMechanicPDFCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path Packages/EbookMechanicPDFCLI -c release

test-pdf:
	@echo "🧪 Running EbookMechanicPDFCLI tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path Packages/EbookMechanicPDFCLI

run-pdf:
	$(SPM_ENV) swift run --disable-sandbox --package-path Packages/EbookMechanicPDFCLI EbookMechanicPDFCLI $(if $(ARGS),$(ARGS),--help)

install-pdf: build-pdf
	@echo "📦 Installing EbookMechanicPDFCLI to $(PDF_CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(PDF_CLI_DEBUG_BINARY)" ]; then \
		echo "❌ Error: Binary not found. Run 'make build-pdf' first."; \
		exit 1; \
	fi
	@if install -m 755 "$(PDF_CLI_DEBUG_BINARY)" "$(PDF_CLI_INSTALL_TARGET)"; then \
		strip "$(PDF_CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed to $(PDF_CLI_INSTALL_TARGET)"; \
	else \
		echo "❌ Error: install command failed. Try 'sudo make install-pdf'."; \
		exit 1; \
	fi

install-pdf-release: build-pdf-release
	@echo "📦 Installing optimized EbookMechanicPDFCLI to $(PDF_CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(PDF_CLI_RELEASE_BINARY)" ]; then \
		echo "❌ Error: Release binary not found."; \
		exit 1; \
	fi
	@if install -m 755 "$(PDF_CLI_RELEASE_BINARY)" "$(PDF_CLI_INSTALL_TARGET)"; then \
		strip "$(PDF_CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed optimized binary to $(PDF_CLI_INSTALL_TARGET)"; \
	else \
		echo "❌ Error: install command failed. Try 'sudo make install-pdf-release'."; \
		exit 1; \
	fi

uninstall-pdf:
	@echo "🗑️  Uninstalling $(PDF_CLI_INSTALL_NAME)..."
	@rm -f "$(PDF_CLI_INSTALL_TARGET)"
	@echo "✅ Uninstalled!"

# Combined specialized CLI targets
install-specialized: install-epub install-pdf
	@echo "✅ All specialized CLIs installed!"

uninstall-specialized: uninstall-epub uninstall-pdf
	@echo "✅ All specialized CLIs uninstalled!"

workspace:
	@echo "🚀 Opening EbookMechanic.xcworkspace in Xcode..."
	@open EbookMechanic.xcworkspace

clean:
	@echo "🧹 Cleaning build artifacts..."
	@chmod -R u+w Packages/EbookMechanicCore/.build 2>/dev/null || true
	@chmod -R u+w Packages/EbookMechanicCLI/.build 2>/dev/null || true
	@chmod -R u+w Apps/EbookMechanicApp/.build 2>/dev/null || true
	@chmod -R u+w Packages/EbookMechanicEPUBCLI/.build 2>/dev/null || true
	@chmod -R u+w Packages/EbookMechanicPDFCLI/.build 2>/dev/null || true
	@rm -rf Packages/EbookMechanicCore/.build Packages/EbookMechanicCLI/.build Apps/EbookMechanicApp/.build Packages/EbookMechanicEPUBCLI/.build Packages/EbookMechanicPDFCLI/.build
	@echo "✅ Build artifacts removed!"

# Deep clean - removes build artifacts, completions, and docs
clean-all:
	@echo "🧹 Deep cleaning project..."
	@echo "  Fixing permissions..."
	@chmod -R u+w Packages/EbookMechanicCore/.build 2>/dev/null || true
	@chmod -R u+w Packages/EbookMechanicCLI/.build 2>/dev/null || true
	@chmod -R u+w Apps/EbookMechanicApp/.build 2>/dev/null || true
	@chmod -R u+w Packages/EbookMechanicEPUBCLI/.build 2>/dev/null || true
	@chmod -R u+w Packages/EbookMechanicPDFCLI/.build 2>/dev/null || true
	@echo "  Removing build artifacts..."
	@rm -rf Packages/EbookMechanicCore/.build Packages/EbookMechanicCLI/.build Apps/EbookMechanicApp/.build Packages/EbookMechanicEPUBCLI/.build Packages/EbookMechanicPDFCLI/.build
	@echo "  Removing completions..."
	@rm -rf completions/
	@echo "✅ All build artifacts, completions, and documentation removed!"

# Generate all documentation
docc-all:
	@echo "📚 Generating all documentation..."
	@$(MAKE_SELF) docc-core
	@echo ""
	@$(MAKE_SELF) docc-app
	@echo ""
	@echo "✅ All documentation generated!"
	@echo ""
	@echo "To serve: make docc-serve"

docc-core:
	@echo "Generating DocC documentation for EbookMechanicCore..."
	@if command -v docc >/dev/null 2>&1; then \
		echo "Using docc command..."; \
		cd EbookMechanicCore && $(SPM_ENV) swift build --target EbookMechanicCore && \
		$(SPM_ENV) swift package plugin generate-documentation \
			--target EbookMechanicCore \
			--output-path .build/docc \
			--transform-for-static-hosting \
			--hosting-base-path EbookMechanicCore-docs; \
	elif xcodebuild -version >/dev/null 2>&1; then \
		echo "Using xcodebuild docbuild..."; \
		xcodebuild docbuild \
			-scheme EbookMechanicCore \
			-destination 'platform=macOS' \
			-derivedDataPath Packages/EbookMechanicCore/.build/xcode-derived; \
		echo "Documentation built to Packages/EbookMechanicCore/.build/xcode-derived"; \
	else \
		echo "Error: Neither docc nor xcodebuild found. Please install Xcode or swift-docc-plugin."; \
		exit 1; \
	fi

# Builds app target docs (symbols in the app module, including ContentView and ScanViewModel)
docc-app:
	@echo "Generating DocC documentation for EbookMechanicApp..."
	@if command -v docc >/dev/null 2>&1; then \
		echo "Using docc command..."; \
		cd EbookMechanicApp && $(SPM_ENV) swift build --target EbookMechanicApp && \
		$(SPM_ENV) swift package plugin generate-documentation \
			--target EbookMechanicApp \
			--output-path .build/docc \
			--transform-for-static-hosting \
			--hosting-base-path EbookMechanicApp-docs; \
	elif xcodebuild -version >/dev/null 2>&1; then \
		echo "Using xcodebuild docbuild..."; \
		xcodebuild docbuild \
			-scheme EbookMechanicApp \
			-destination 'platform=macOS' \
			-derivedDataPath Apps/EbookMechanicApp/.build/xcode-derived; \
		echo "Documentation built to Apps/EbookMechanicApp/.build/xcode-derived"; \
	else \
		echo "Error: Neither docc nor xcodebuild found. Please install Xcode or swift-docc-plugin."; \
		exit 1; \
	fi

# Quick local preview using Python HTTP server (requires Python 3)
docc-serve:
	@if [ -d "Packages/EbookMechanicCore/.build/docc" ]; then \
		echo "📚 Serving EbookMechanicCore documentation at http://localhost:8080"; \
		echo "Press Ctrl+C to stop the server."; \
		echo ""; \
		python3 -m http.server --directory Packages/EbookMechanicCore/.build/docc 8080; \
	elif [ -d "Apps/EbookMechanicApp/.build/docc" ]; then \
		echo "📚 Serving EbookMechanicApp documentation at http://localhost:8080"; \
		echo "Press Ctrl+C to stop the server."; \
		echo ""; \
		python3 -m http.server --directory Apps/EbookMechanicApp/.build/docc 8080; \
	else \
		echo "❌ Error: No DocC documentation found."; \
		echo ""; \
		echo "Please generate documentation first:"; \
		echo "  make docc-core    # Generate core library docs"; \
		echo "  make docc-app     # Generate app docs"; \
		echo ""; \
		echo "Then run 'make docc-serve' again."; \
		echo ""; \
		echo "Quick start: make docc-core && make docc-serve"; \
		exit 1; \
	fi

# Install CLI binary to system path
install: build-cli
	@echo "📦 Installing EbookMechanicCLI to $(CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(CLI_DEBUG_BINARY)" ]; then \
		echo "❌ Error: Binary not found. Run 'make cli-build' first."; \
		exit 1; \
	fi
	@if [ ! -d "$(BIN_INSTALL_PATH)" ]; then \
		echo "❌ Error: Install directory $(BIN_INSTALL_PATH) does not exist."; \
		echo "   Create it or pass BIN_INSTALL_PATH=/custom/path"; \
		exit 1; \
	fi
	@if [ ! -w "$(BIN_INSTALL_PATH)" ]; then \
		echo "❌ Error: Permission denied writing to $(BIN_INSTALL_PATH)."; \
		echo "   Try 'sudo make install' or set BIN_INSTALL_PATH to a writable directory."; \
		exit 1; \
	fi
	@if install -m 755 "$(CLI_DEBUG_BINARY)" "$(CLI_INSTALL_TARGET)"; then \
		strip "$(CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed to $(CLI_INSTALL_TARGET)"; \
		echo ""; \
		echo "Run '$(CLI_INSTALL_NAME) --help' to get started!"; \
	else \
		echo "❌ Error: install command failed. See message above."; \
		exit 1; \
	fi

# Install release version (optimized binary)
install-release: build-release
	@echo "📦 Installing optimized EbookMechanicCLI to $(CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(CLI_RELEASE_BINARY)" ]; then \
		echo "❌ Error: Release binary not found."; \
		exit 1; \
	fi
	@if [ ! -d "$(BIN_INSTALL_PATH)" ]; then \
		echo "❌ Error: Install directory $(BIN_INSTALL_PATH) does not exist."; \
		echo "   Create it or pass BIN_INSTALL_PATH=/custom/path"; \
		exit 1; \
	fi
	@if [ ! -w "$(BIN_INSTALL_PATH)" ]; then \
		echo "❌ Error: Permission denied writing to $(BIN_INSTALL_PATH)."; \
		echo "   Try 'sudo make install-release' or set BIN_INSTALL_PATH to a writable directory."; \
		exit 1; \
	fi
	@if install -m 755 "$(CLI_RELEASE_BINARY)" "$(CLI_INSTALL_TARGET)"; then \
		strip "$(CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed optimized binary to $(CLI_INSTALL_TARGET)"; \
		echo ""; \
		echo "Run '$(CLI_INSTALL_NAME) --help' to get started!"; \
	else \
		echo "❌ Error: install command failed. See message above."; \
		exit 1; \
	fi

# Uninstall CLI binary
uninstall:
	@echo "🗑️  Uninstalling $(CLI_INSTALL_NAME)..."
	@rm -f "$(CLI_INSTALL_TARGET)"
	@echo "✅ Uninstalled!"

APP_BUNDLE_NAME ?= EbookMechanic.app
APP_INSTALL_PATH ?= /Applications/$(APP_BUNDLE_NAME)

app-bundle-debug: build-app
	@echo "📦 Assembling debug app bundle..."
	@set -euo pipefail; \
	 BUNDLE_ROOT="Apps/EbookMechanicApp/.build/AppBundle"; \
	 BIN="Apps/EbookMechanicApp/.build/debug/EbookMechanicApp"; \
	 APP_DIR="$$BUNDLE_ROOT/$(APP_BUNDLE_NAME)"; \
	 mkdir -p "$$APP_DIR/Contents/MacOS" "$$APP_DIR/Contents/Resources"; \
	 printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>CFBundleDevelopmentRegion</key>' \
		'  <string>en</string>' \
		'  <key>CFBundleExecutable</key>' \
		'  <string>EbookMechanicApp</string>' \
		'  <key>CFBundleIdentifier</key>' \
		'  <string>com.ebookmechanic.app</string>' \
		'  <key>CFBundleInfoDictionaryVersion</key>' \
		'  <string>6.0</string>' \
		'  <key>CFBundleName</key>' \
		'  <string>EbookMechanic</string>' \
		'  <key>CFBundlePackageType</key>' \
		'  <string>APPL</string>' \
		'  <key>CFBundleShortVersionString</key>' \
		'  <string>1.0</string>' \
		'  <key>CFBundleVersion</key>' \
		'  <string>1</string>' \
		'  <key>LSMinimumSystemVersion</key>' \
		'  <string>13.0</string>' \
		'</dict>' \
		'</plist>' \
		> "$$APP_DIR/Contents/Info.plist"; \
	 cp "$$BIN" "$$APP_DIR/Contents/MacOS/EbookMechanicApp"; \
	 chmod +x "$$APP_DIR/Contents/MacOS/EbookMechanicApp"; \
	 echo "✅ Debug app bundle at $$APP_DIR"

install-app:
	@echo "🔨 Building release build of EbookMechanicApp..."
	$(SPM_ENV) swift build --disable-sandbox --package-path Apps/EbookMechanicApp -c release
	@echo "📦 Assembling app bundle..."
	@set -euo pipefail; \
	 BUNDLE_ROOT="Apps/EbookMechanicApp/.build/AppBundle"; \
	 BIN="Apps/EbookMechanicApp/.build/release/EbookMechanicApp"; \
	 APP_DIR="$$BUNDLE_ROOT/$(APP_BUNDLE_NAME)"; \
	 mkdir -p "$$APP_DIR/Contents/MacOS" "$$APP_DIR/Contents/Resources"; \
	 printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>CFBundleDevelopmentRegion</key>' \
		'  <string>en</string>' \
		'  <key>CFBundleExecutable</key>' \
		'  <string>EbookMechanicApp</string>' \
		'  <key>CFBundleIdentifier</key>' \
		'  <string>com.ebookmechanic.app</string>' \
		'  <key>CFBundleInfoDictionaryVersion</key>' \
		'  <string>6.0</string>' \
		'  <key>CFBundleName</key>' \
		'  <string>EbookMechanic</string>' \
		'  <key>CFBundlePackageType</key>' \
		'  <string>APPL</string>' \
		'  <key>CFBundleShortVersionString</key>' \
		'  <string>1.0</string>' \
		'  <key>CFBundleVersion</key>' \
		'  <string>1</string>' \
		'  <key>LSMinimumSystemVersion</key>' \
		'  <string>13.0</string>' \
		'</dict>' \
		'</plist>' \
		> "$$APP_DIR/Contents/Info.plist"; \
	 cp "$$BIN" "$$APP_DIR/Contents/MacOS/EbookMechanicApp"; \
	 chmod +x "$$APP_DIR/Contents/MacOS/EbookMechanicApp"; \
	 TARGET="$(APP_INSTALL_PATH)"; \
	 echo "🚚 Installing to $$TARGET"; \
	 if [ -d "$$TARGET" ]; then rm -rf "$$TARGET" 2>/dev/null || sudo rm -rf "$$TARGET"; fi; \
	 mkdir -p "$$(dirname "$$TARGET")"; \
	 cp -R "$$APP_DIR" "$$TARGET" 2>/dev/null || sudo cp -R "$$APP_DIR" "$$TARGET"; \
	 echo "✅ macOS app available at $$TARGET"

uninstall-app:
	@if [ -d "$(APP_INSTALL_PATH)" ]; then \
		rm -rf "$(APP_INSTALL_PATH)" 2>/dev/null || sudo rm -rf "$(APP_INSTALL_PATH)"; \
		echo "🗑️  Removed $(APP_INSTALL_PATH)"; \
	else \
		echo "ℹ️  No installed app found at $(APP_INSTALL_PATH)"; \
	fi

# Format Swift code (requires swift-format)
format:
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "🎨 Formatting Swift code..."; \
		find EbookMechanicCore/Sources -name "*.swift" -exec swift-format -i {} \;; \
		find EbookMechanicCore/Tests -name "*.swift" -exec swift-format -i {} \;; \
		find EbookMechanicCLI/Sources -name "*.swift" -exec swift-format -i {} \;; \
		find EbookMechanicCLI/Tests -name "*.swift" -exec swift-format -i {} \;; \
		find EbookMechanicApp/Sources -name "*.swift" -exec swift-format -i {} \;; \
		find EbookMechanicApp/Tests -name "*.swift" -exec swift-format -i {} \;; \
		find Packages/EbookMechanicEPUBCLI/Sources -name "*.swift" -exec swift-format -i {} \;; \
		find Packages/EbookMechanicEPUBCLI/Tests -name "*.swift" -exec swift-format -i {} \;; \
		find Packages/EbookMechanicPDFCLI/Sources -name "*.swift" -exec swift-format -i {} \;; \
		find Packages/EbookMechanicPDFCLI/Tests -name "*.swift" -exec swift-format -i {} \;; \
		echo "✅ Code formatted!"; \
	else \
		echo "❌ swift-format not found. Install with:"; \
		echo "   brew install swift-format"; \
		echo "   or: https://github.com/apple/swift-format"; \
		exit 1; \
	fi

# Check code formatting (CI-friendly, non-modifying)
check-format:
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "🔍 Checking Swift code formatting..."; \
		swift-format lint -r EbookMechanicCore/Sources EbookMechanicCore/Tests; \
		swift-format lint -r EbookMechanicCLI/Sources EbookMechanicCLI/Tests; \
		swift-format lint -r EbookMechanicApp/Sources EbookMechanicApp/Tests; \
		swift-format lint -r Packages/EbookMechanicEPUBCLI/Sources Packages/EbookMechanicEPUBCLI/Tests; \
		swift-format lint -r Packages/EbookMechanicPDFCLI/Sources Packages/EbookMechanicPDFCLI/Tests; \
		echo "✅ Format check passed!"; \
	else \
		echo "⚠️  swift-format not installed, skipping format check"; \
	fi

# Lint Swift code (requires SwiftLint)
lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		echo "🔍 Linting Swift code..."; \
		cd EbookMechanicCore && swiftlint; \
		cd ../EbookMechanicCLI && swiftlint; \
		cd ../EbookMechanicApp && swiftlint; \
		cd Packages/EbookMechanicEPUBCLI && swiftlint; \
		cd Packages/EbookMechanicPDFCLI && swiftlint; \
		echo "✅ Lint check passed!"; \
	else \
		echo "❌ SwiftLint not found. Install with:"; \
		echo "   brew install swiftlint"; \
		echo "   or: https://github.com/realm/SwiftLint"; \
		exit 1; \
	fi

# CI pipeline target
ci: build-all test-all check-format
	@echo ""
	@echo "✅ CI pipeline completed successfully!"
	@echo ""

# Print build info (useful for debugging)
info:
	@echo "🔍 EbookMechanic Build Information"
	@echo "===================================="
	@echo ""
	@echo "Swift version:"
	@swift --version
	@echo ""
	@echo "Xcode version:"
	@xcodebuild -version 2>/dev/null || echo "  Xcode not found"
	@echo ""
	@echo "Build directories:"
	@printf "  %-15s %s\n" "Core:" "$$(du -sh Packages/EbookMechanicCore/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@printf "  %-15s %s\n" "Main CLI:" "$$(du -sh Packages/EbookMechanicCLI/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@printf "  %-15s %s\n" "App:" "$$(du -sh Apps/EbookMechanicApp/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@printf "  %-15s %s\n" "EPUB CLI:" "$$(du -sh Packages/EbookMechanicEPUBCLI/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@printf "  %-15s %s\n" "PDF CLI:" "$$(du -sh Packages/EbookMechanicPDFCLI/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo ""
	@echo "Generated artifacts:"
	@printf "  %-15s %s\n" "Completions:" "$$(if [ -d completions ]; then ls -1 completions | wc -l | xargs; else echo '0'; fi) files"
	@printf "  %-15s %s\n" "Core docs:" "$$(if [ -d Packages/EbookMechanicCore/.build/docc ]; then echo 'Generated'; else echo 'Not generated'; fi)"
	@printf "  %-15s %s\n" "App docs:" "$$(if [ -d Apps/EbookMechanicApp/.build/docc ]; then echo 'Generated'; else echo 'Not generated'; fi)"
	@echo ""

# Update all generated artifacts (completions and documentation)
update-all:
	@echo "🔄 Updating all generated artifacts..."
	@echo ""
	@$(MAKE_SELF) completions
	@echo ""
	@$(MAKE_SELF) docc-all
	@echo ""
	@echo "✅ All artifacts updated!"
	@echo ""
	@echo "Generated:"
	@echo "  • Shell completions in ./completions/"
	@echo "  • Documentation in .build/docc directories"
	@echo ""
	@echo "To serve documentation: make docc-serve"

install-tools:
	@echo "Checking for external tools..."
	@if ! command -v epubcheck > /dev/null; then \
		echo "epubcheck not found. Please install it."; \
		echo "  On macOS: brew install epubcheck"; \
		echo "  On Linux: sudo apt-get install epubcheck (or equivalent)"; \
	else \
		echo "epubcheck is installed."; \
	fi
	@if ! command -v pdfcpu > /dev/null; then \
		echo "pdfcpu not found. Please install it."; \
		echo "  On macOS: brew install pdfcpu"; \
		echo "  On Linux: download from https://pdfcpu.io/download"; \
	else \
		echo "pdfcpu is installed."; \
	fi

test-external-tools:
	@echo "Running external tools integration test..."
	@./test-external-tools.sh

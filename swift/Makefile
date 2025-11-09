# EbookMechanic Swift workspace make targets

# Environment setup for reproducible builds
SPM_ENV := SWIFT_MODULE_CACHE_PATH=.build/module-cache CLANG_MODULE_CACHE_PATH=.build/module-cache

# CLI install configuration
BIN_INSTALL_PATH ?= /usr/local/bin
CLI_INSTALL_NAME ?= ebook-mechanic
CLI_INSTALL_TARGET := $(BIN_INSTALL_PATH)/$(CLI_INSTALL_NAME)
CLI_DEBUG_BINARY := EbookMechanicCLI/.build/debug/EbookMechanicCLI
CLI_RELEASE_BINARY := EbookMechanicCLI/.build/release/EbookMechanicCLI

# EPUB Mechanic CLI configuration
EPUB_CLI_INSTALL_NAME ?= epub-mechanic
EPUB_CLI_INSTALL_TARGET := $(BIN_INSTALL_PATH)/$(EPUB_CLI_INSTALL_NAME)
EPUB_CLI_DEBUG_BINARY := EPUBMechanicCLI/.build/debug/EPUBMechanicCLI
EPUB_CLI_RELEASE_BINARY := EPUBMechanicCLI/.build/release/EPUBMechanicCLI

# PDF Mechanic CLI configuration
PDF_CLI_INSTALL_NAME ?= pdf-mechanic
PDF_CLI_INSTALL_TARGET := $(BIN_INSTALL_PATH)/$(PDF_CLI_INSTALL_NAME)
PDF_CLI_DEBUG_BINARY := PDFMechanicCLI/.build/debug/PDFMechanicCLI
PDF_CLI_RELEASE_BINARY := PDFMechanicCLI/.build/release/PDFMechanicCLI

# Default shell configuration for better error handling
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:

# Phony targets (targets that don't represent files)
.PHONY: help build build-all build-release test test-all core-test core-build cli-build cli-run cli-normalize cli-normalize-force cli-test cli-completions app-build app-run app-test app-install app-uninstall epub-build epub-build-release epub-test epub-run epub-install epub-install-release epub-uninstall pdf-build pdf-build-release pdf-test pdf-run pdf-install pdf-install-release pdf-uninstall build-specialized install-specialized uninstall-specialized workspace clean clean-all docc-core docc-app docc-serve docc-all install install-release uninstall format check-format lint ci info update-all

# Default target when running 'make' with no arguments
.DEFAULT_GOAL := build

help:
	@echo "EbookMechanic Make Targets"
	@echo "================================"
	@echo ""
	@echo "🏗️  Build Targets:"
	@echo "  make build            - Build core library only (default)"
	@echo "  make build-all        - Build everything (core + all CLIs + app)"
	@echo "  make build-release    - Build optimized release binaries"
	@echo "  make build-core       - Build the core library"
	@echo "  make build-cli        - Build the main CLI executable"
	@echo "  make build-app        - Build the macOS SwiftUI app"
	@echo "  make build-specialized- Build specialized CLIs (EPUB + PDF)"
	@echo "  make epub-build       - Build EPUB Mechanic CLI"
	@echo "  make pdf-build        - Build PDF Mechanic CLI"
	@echo ""
	@echo "🧪 Test Targets:"
	@echo "  make test            - Run core library tests (default)"
	@echo "  make test-all        - Run all test suites (core + all CLIs + app)"
	@echo "  make test-core       - Run the EbookMechanicCore test suite"
	@echo "  make test-cli        - Run the main CLI test suite"
	@echo "  make test-app        - Run the app test suite"
	@echo "  make epub-test       - Run EPUB Mechanic CLI tests"
	@echo "  make pdf-test        - Run PDF Mechanic CLI tests"
	@echo ""
	@echo "🚀 Run Targets:"
	@echo "  make run-cli ARGS=   - Run the main CLI (default: --help)"
	@echo "  make normalize       - Normalize EPUBs (dry-run mode)"
	@echo "  make normalize-force - Force normalize EPUBs (live mode)"
	@echo "  make run-app         - Launch the SwiftUI app"
	@echo "  make epub-run ARGS=  - Run EPUB Mechanic CLI"
	@echo "  make pdf-run ARGS=   - Run PDF Mechanic CLI"
	@echo ""
	@echo "📚 Documentation Targets:"
	@echo "  make docc-all        - Generate all documentation (core + app)"
	@echo "  make docc-core       - Generate DocC docs for EbookMechanicCore"
	@echo "  make docc-app        - Generate DocC docs for EbookMechanicApp"
	@echo "  make docc-serve      - Serve docs at http://localhost:8080"
	@echo ""
	@echo "🛠️  Utility Targets:"
	@echo "  make completions        - Generate shell completion scripts"
	@echo "  make install            - Install main CLI to $(BIN_INSTALL_PATH) (debug)"
	@echo "  make install-release    - Install optimized main CLI to $(BIN_INSTALL_PATH)"
	@echo "  make install-app        - Build & copy the macOS app bundle"
	@echo "  make install-specialized- Install specialized CLIs (EPUB + PDF)"
	@echo "  make epub-install       - Install EPUB Mechanic CLI"
	@echo "  make epub-install-release - Install optimized EPUB Mechanic CLI"
	@echo "  make pdf-install        - Install PDF Mechanic CLI"
	@echo "  make pdf-install-release  - Install optimized PDF Mechanic CLI"
	@echo "  make uninstall          - Remove main CLI from $(BIN_INSTALL_PATH)"
	@echo "  make uninstall-app      - Remove installed macOS app bundle"
	@echo "  make uninstall-specialized - Uninstall specialized CLIs"
	@echo "  make epub-uninstall     - Uninstall EPUB Mechanic CLI"
	@echo "  make pdf-uninstall      - Uninstall PDF Mechanic CLI"
	@echo "  make format             - Format all Swift code with swift-format"
	@echo "  make lint               - Lint Swift code (requires SwiftLint)"
	@echo "  make check-format       - Check if code is formatted (CI-friendly)"
	@echo "  make workspace          - Open EbookMechanic.xcworkspace in Xcode"
	@echo "  make clean              - Remove build artifacts for all packages"
	@echo "  make clean-all          - Deep clean (includes completions & docs)"
	@echo "  make info               - Display build information and sizes"
	@echo "  make update-all         - Update completions and documentation"
	@echo ""
	@echo "🤖 CI/CD Targets:"
	@echo "  make ci            - Run full CI pipeline (build-all + test-all + check-format)"
	@echo ""
	@echo "Environment defaults:"
	@echo "  SWIFT_MODULE_CACHE_PATH and CLANG_MODULE_CACHE_PATH are pinned to .build/module-cache"
	@echo "  to keep sandboxed builds reproducible. Override SPM_ENV to customise."
	@echo ""
	@echo "DocC documentation:"
	@echo "  See DOCC_SETUP.md for setup instructions if 'make docc-core' fails."

# Default target
build: core-build

# Build all components
build-all: core-build build-cli build-app build-specialized
	@echo ""
	@echo "✅ All components built successfully!"

# Build specialized CLIs
build-specialized: epub-build pdf-build
	@echo ""
	@echo "✅ Specialized CLIs built successfully!"

# Release builds (optimized)
build-release:
	@echo "🚀 Building optimized release binaries..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCore -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCLI -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicApp -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path EPUBMechanicCLI -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path PDFMechanicCLI -c release
	@echo "✅ Release builds complete!"
	@echo ""
	@echo "Main CLI binary: EbookMechanicCLI/.build/release/EbookMechanicCLI"
	@echo "EPUB CLI binary: EPUBMechanicCLI/.build/release/EPUBMechanicCLI"
	@echo "PDF CLI binary:  PDFMechanicCLI/.build/release/PDFMechanicCLI"

# Default test target now exercises core, CLI, and app (including UI hooks)
test: core-test cli-test app-test

# Run all test suites
test-all:
	@echo "🧪 Running all test suites..."
	@echo ""
	@$(MAKE) test-core
	@echo ""
	@$(MAKE) test-cli
	@echo ""
	@$(MAKE) test-app
	@echo ""
	@$(MAKE) epub-test
	@echo ""
	@$(MAKE) pdf-test
	@echo ""
	@echo "✅ All test suites completed!"

test-core:
	@echo "🧪 Running EbookMechanicCore tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path EbookMechanicCore

build-core:
	@echo "🔨 Building EbookMechanicCore..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCore

build-cli:
	@echo "🔨 Building EbookMechanicCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCLI

run-cli:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--help)

normalize:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--normalize-epubs --dry-run)

normalize-force:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--normalize-epubs --force-normalize --dry-run=false)

test-cli:
	@echo "🧪 Running EbookMechanicCLI tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path EbookMechanicCLI

completions:
	@echo "📝 Generating shell completion scripts..."
	@mkdir -p completions
	@$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI --generate-completion bash > completions/ebook-mechanic.bash
	@$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI --generate-completion zsh > completions/_ebook-mechanic
	@$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI --generate-completion fish > completions/ebook-mechanic.fish
	@$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI --generate-completion powershell > completions/ebook-mechanic.ps1
	@echo "✅ Completion scripts generated in ./completions/"
	@echo ""
	@echo "To install:"
	@echo "  Bash:       cp completions/ebook-mechanic.bash /usr/local/etc/bash_completion.d/"
	@echo "  Zsh:        cp completions/_ebook-mechanic /usr/local/share/zsh/site-functions/"
	@echo "  Fish:       cp completions/ebook-mechanic.fish ~/.config/fish/completions/"
	@echo "  PowerShell: . completions/ebook-mechanic.ps1"

build-app:
	@echo "🔨 Building EbookMechanicApp..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicApp

run-app:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicApp EbookMechanicApp

test-app:
	@echo "🧪 Running EbookMechanicApp tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path EbookMechanicApp

# EPUB Mechanic CLI targets
epub-build:
	@echo "🔨 Building EPUBMechanicCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EPUBMechanicCLI

epub-build-release:
	@echo "🚀 Building optimized EPUBMechanicCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EPUBMechanicCLI -c release

epub-test:
	@echo "🧪 Running EPUBMechanicCLI tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path EPUBMechanicCLI

epub-run:
	$(SPM_ENV) swift run --disable-sandbox --package-path EPUBMechanicCLI EPUBMechanicCLI $(if $(ARGS),$(ARGS),--help)

epub-install: epub-build
	@echo "📦 Installing EPUBMechanicCLI to $(EPUB_CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(EPUB_CLI_DEBUG_BINARY)" ]; then \
		echo "❌ Error: Binary not found. Run 'make epub-build' first."; \
		exit 1; \
	fi
	@if install -m 755 "$(EPUB_CLI_DEBUG_BINARY)" "$(EPUB_CLI_INSTALL_TARGET)"; then \
		strip "$(EPUB_CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed to $(EPUB_CLI_INSTALL_TARGET)"; \
	else \
		echo "❌ Error: install command failed. Try 'sudo make epub-install'."; \
		exit 1; \
	fi

epub-install-release: epub-build-release
	@echo "📦 Installing optimized EPUBMechanicCLI to $(EPUB_CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(EPUB_CLI_RELEASE_BINARY)" ]; then \
		echo "❌ Error: Release binary not found."; \
		exit 1; \
	fi
	@if install -m 755 "$(EPUB_CLI_RELEASE_BINARY)" "$(EPUB_CLI_INSTALL_TARGET)"; then \
		strip "$(EPUB_CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed optimized binary to $(EPUB_CLI_INSTALL_TARGET)"; \
	else \
		echo "❌ Error: install command failed. Try 'sudo make epub-install-release'."; \
		exit 1; \
	fi

epub-uninstall:
	@echo "🗑️  Uninstalling $(EPUB_CLI_INSTALL_NAME)..."
	@rm -f "$(EPUB_CLI_INSTALL_TARGET)"
	@echo "✅ Uninstalled!"

# PDF Mechanic CLI targets
pdf-build:
	@echo "🔨 Building PDFMechanicCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path PDFMechanicCLI

pdf-build-release:
	@echo "🚀 Building optimized PDFMechanicCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path PDFMechanicCLI -c release

pdf-test:
	@echo "🧪 Running PDFMechanicCLI tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path PDFMechanicCLI

pdf-run:
	$(SPM_ENV) swift run --disable-sandbox --package-path PDFMechanicCLI PDFMechanicCLI $(if $(ARGS),$(ARGS),--help)

pdf-install: pdf-build
	@echo "📦 Installing PDFMechanicCLI to $(PDF_CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(PDF_CLI_DEBUG_BINARY)" ]; then \
		echo "❌ Error: Binary not found. Run 'make pdf-build' first."; \
		exit 1; \
	fi
	@if install -m 755 "$(PDF_CLI_DEBUG_BINARY)" "$(PDF_CLI_INSTALL_TARGET)"; then \
		strip "$(PDF_CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed to $(PDF_CLI_INSTALL_TARGET)"; \
	else \
		echo "❌ Error: install command failed. Try 'sudo make pdf-install'."; \
		exit 1; \
	fi

pdf-install-release: pdf-build-release
	@echo "📦 Installing optimized PDFMechanicCLI to $(PDF_CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(PDF_CLI_RELEASE_BINARY)" ]; then \
		echo "❌ Error: Release binary not found."; \
		exit 1; \
	fi
	@if install -m 755 "$(PDF_CLI_RELEASE_BINARY)" "$(PDF_CLI_INSTALL_TARGET)"; then \
		strip "$(PDF_CLI_INSTALL_TARGET)" 2>/dev/null || true; \
		echo "✅ Installed optimized binary to $(PDF_CLI_INSTALL_TARGET)"; \
	else \
		echo "❌ Error: install command failed. Try 'sudo make pdf-install-release'."; \
		exit 1; \
	fi

pdf-uninstall:
	@echo "🗑️  Uninstalling $(PDF_CLI_INSTALL_NAME)..."
	@rm -f "$(PDF_CLI_INSTALL_TARGET)"
	@echo "✅ Uninstalled!"

# Combined specialized CLI targets
install-specialized: epub-install pdf-install
	@echo "✅ All specialized CLIs installed!"

uninstall-specialized: epub-uninstall pdf-uninstall
	@echo "✅ All specialized CLIs uninstalled!"

workspace:
	@echo "🚀 Opening EbookMechanic.xcworkspace in Xcode..."
	@open EbookMechanic.xcworkspace

clean:
	@echo "🧹 Cleaning build artifacts..."
	@chmod -R u+w EbookMechanicCore/.build 2>/dev/null || true
	@chmod -R u+w EbookMechanicCLI/.build 2>/dev/null || true
	@chmod -R u+w EbookMechanicApp/.build 2>/dev/null || true
	@chmod -R u+w EPUBMechanicCLI/.build 2>/dev/null || true
	@chmod -R u+w PDFMechanicCLI/.build 2>/dev/null || true
	@rm -rf EbookMechanicCore/.build EbookMechanicCLI/.build EbookMechanicApp/.build EPUBMechanicCLI/.build PDFMechanicCLI/.build
	@echo "✅ Build artifacts removed!"

# Deep clean - removes build artifacts, completions, and docs
clean-all:
	@echo "🧹 Deep cleaning project..."
	@echo "  Fixing permissions..."
	@chmod -R u+w EbookMechanicCore/.build 2>/dev/null || true
	@chmod -R u+w EbookMechanicCLI/.build 2>/dev/null || true
	@chmod -R u+w EbookMechanicApp/.build 2>/dev/null || true
	@chmod -R u+w EPUBMechanicCLI/.build 2>/dev/null || true
	@chmod -R u+w PDFMechanicCLI/.build 2>/dev/null || true
	@echo "  Removing build artifacts..."
	@rm -rf EbookMechanicCore/.build EbookMechanicCLI/.build EbookMechanicApp/.build EPUBMechanicCLI/.build PDFMechanicCLI/.build
	@echo "  Removing completions..."
	@rm -rf completions/
	@echo "✅ All build artifacts, completions, and documentation removed!"

# Generate all documentation
docc-all:
	@echo "📚 Generating all documentation..."
	@$(MAKE) docc-core
	@echo ""
	@$(MAKE) docc-app
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
			-derivedDataPath EbookMechanicCore/.build/xcode-derived; \
		echo "Documentation built to EbookMechanicCore/.build/xcode-derived"; \
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
			-derivedDataPath EbookMechanicApp/.build/xcode-derived; \
		echo "Documentation built to EbookMechanicApp/.build/xcode-derived"; \
	else \
		echo "Error: Neither docc nor xcodebuild found. Please install Xcode or swift-docc-plugin."; \
		exit 1; \
	fi

# Quick local preview using Python HTTP server (requires Python 3)
docc-serve:
	@if [ -d "EbookMechanicCore/.build/docc" ]; then \
		echo "📚 Serving EbookMechanicCore documentation at http://localhost:8080"; \
		echo "Press Ctrl+C to stop the server."; \
		echo ""; \
		python3 -m http.server --directory EbookMechanicCore/.build/docc 8080; \
	elif [ -d "EbookMechanicApp/.build/docc" ]; then \
		echo "📚 Serving EbookMechanicApp documentation at http://localhost:8080"; \
		echo "Press Ctrl+C to stop the server."; \
		echo ""; \
		python3 -m http.server --directory EbookMechanicApp/.build/docc 8080; \
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

install-app:
	@echo "🔨 Building release build of EbookMechanicApp..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicApp -c release
	@echo "📦 Assembling app bundle..."
	@set -euo pipefail; \
	 BUNDLE_ROOT="EbookMechanicApp/.build/AppBundle"; \
	 BIN="EbookMechanicApp/.build/release/EbookMechanicApp"; \
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
	@echo "  Core:     $(shell du -sh EbookMechanicCore/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo "  Main CLI: $(shell du -sh EbookMechanicCLI/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo "  App:      $(shell du -sh EbookMechanicApp/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo "  EPUB CLI: $(shell du -sh EPUBMechanicCLI/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo "  PDF CLI:  $(shell du -sh PDFMechanicCLI/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo ""
	@echo "Generated artifacts:"
	@echo "  Completions: $(shell [ -d completions ] && ls -1 completions | wc -l | xargs || echo '0') files"
	@echo "  Core docs:   $(shell [ -d EbookMechanicCore/.build/docc ] && echo 'Generated' || echo 'Not generated')"
	@echo "  App docs:    $(shell [ -d EbookMechanicApp/.build/docc ] && echo 'Generated' || echo 'Not generated')"
	@echo ""

# Update all generated artifacts (completions and documentation)
update-all:
	@echo "🔄 Updating all generated artifacts..."
	@echo ""
	@$(MAKE) completions
	@echo ""
	@$(MAKE) docc-all
	@echo ""
	@echo "✅ All artifacts updated!"
	@echo ""
	@echo "Generated:"
	@echo "  • Shell completions in ./completions/"
	@echo "  • Documentation in .build/docc directories"
	@echo ""
	@echo "To serve documentation: make docc-serve"

# EPUBMechanic Swift workspace make targets

# Environment setup for reproducible builds
SPM_ENV := SWIFT_MODULE_CACHE_PATH=.build/module-cache CLANG_MODULE_CACHE_PATH=.build/module-cache

# CLI install configuration
BIN_INSTALL_PATH ?= /usr/local/bin
CLI_INSTALL_NAME ?= epub-mechanic
CLI_INSTALL_TARGET := $(BIN_INSTALL_PATH)/$(CLI_INSTALL_NAME)
CLI_DEBUG_BINARY := EPUBMechanicCLI/.build/debug/EPUBMechanicCLI
CLI_RELEASE_BINARY := EPUBMechanicCLI/.build/release/EPUBMechanicCLI

# Default shell configuration for better error handling
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:

# Phony targets (targets that don't represent files)
.PHONY: all help build build-release test test-all cli-build cli-run cli-normalize cli-normalize-force cli-test cli-completions workspace clean clean-all docc-cli docc-serve docc-all install install-release uninstall format check-format lint ci info update-all

# Default target when running 'make' with no arguments
.DEFAULT_GOAL := build

help:
	@echo "EpubMechanic Make Targets"
	@echo "================================"
	@echo ""
	@echo "🏗️  Build Targets:"
	@echo "  make build                     - Build CLI (default)"
	@echo "  make build-release             - Build optimized release binaries"
	@echo ""
	@echo "🧪 Test Targets:"
	@echo "  make test                      - Run cli tests (default)"
	@echo "  make test-all                  - Run all test suites (CLI )"
	@echo ""
	@echo "🚀 Run Targets:"
	@echo "  make cli-run ARGS=            	- Run the CLI (default: --help)"
	@echo "  make cli-normalize             - Normalize EPUBs (dry-run mode)"
	@echo "  make cli-normalize-force       - Force normalize EPUBs (live mode)"
	@echo ""
	@echo "📚 Documentation Targets:"
	@echo "  make docc-all                  - Generate all documentation (cli)"
	@echo "  make docc-cli                  - Generate DocC docs for EPUBMechanic"
	@echo "  make docc-serve                - Serve docs at http://localhost:8080"
	@echo ""
	@echo "🛠️  Utility Targets:"
	@echo "  make completions           - Generate shell completion scripts"
	@echo "  make install                   - Install CLI to $(BIN_INSTALL_PATH) (debug)"
	@echo "  make install-release           - Install optimized CLI to $(BIN_INSTALL_PATH)"
	@echo "  make uninstall                 - Remove CLI from $(BIN_INSTALL_PATH)"
	@echo "  make format                    - Format all Swift code with swift-format"
	@echo "  make lint                      - Lint Swift code (requires SwiftLint)"
	@echo "  make check-format              - Check if code is formatted (CI-friendly)"
	@echo "  make workspace                 - Open ../EPUBMechanic.xcworkspace in Xcode"
	@echo "  make clean                     - Remove build artifacts for all packages"
	@echo "  make clean-all                 - Deep clean (includes completions & docs)"
	@echo "  make info                      - Display build information and sizes"
	@echo "  make update-all                - Update completions and documentation"
	@echo ""
	@echo "🤖 CI/CD Targets:"
	@echo "  make ci                        - Run full CI pipeline (build-all + test-all + check-format)"
	@echo ""
	@echo "Environment defaults:"
	@echo "  SWIFT_MODULE_CACHE_PATH and CLANG_MODULE_CACHE_PATH are pinned to .build/module-cache"
	@echo "  to keep sandboxed builds reproducible. Override SPM_ENV to customise."
	@echo ""
	@echo "DocC documentation:"
	@echo "  See DOCC_SETUP.md for setup instructions if 'make docc-cli' fails."

# Default target
build: build-cli

# Build all components
build-all: build-cli
	@echo ""
	@echo "✅ All components built successfully!"

# Release builds (optimized)
build-release:
	@echo "🚀 Building optimized release binaries..."
	$(SPM_ENV) swift build --disable-sandbox -c release
	@echo "✅ Release builds complete!"
	@echo ""
	@echo "CLI binary: $(CLI_RELEASE_BINARY)"

# Default test target now exercises CLI
test: test-cli

# Run all test suites
test-all:
	@echo "🧪 Running all test suites..."
	@echo ""
	@$(MAKE) test-cli
	@echo ""
	@echo "✅ All test suites completed!"

build-cli:
	@echo "🔨 Building EPUBMechanicCLI..."
	$(SPM_ENV) swift build --disable-sandbox

run-cli:
	$(SPM_ENV) swift run --disable-sandbox EPUBMechanicCLI $(if $(ARGS),$(ARGS),--help)

cli-normalize:
	$(SPM_ENV) swift run --disable-sandbox EPUBMechanicCLI $(if $(ARGS),$(ARGS),--normalize-epubs --dry-run)

cli-normalize-force:
	$(SPM_ENV) swift run --disable-sandbox EPUBMechanicCLI $(if $(ARGS),$(ARGS),--normalize-epubs --force-normalize --dry-run=false)

test-cli:
	@echo "🧪 Running EPUBMechanicCLI tests..."
	$(SPM_ENV) swift test --disable-sandbox

completions:
	@echo "📝 Generating shell completion scripts..."
	@mkdir -p completions
	@$(SPM_ENV) swift run --disable-sandbox EPUBMechanicCLI --generate-completion bash > completions/epub-mechanic.bash
	@$(SPM_ENV) swift run --disable-sandbox EPUBMechanicCLI --generate-completion zsh > completions/_epub-mechanic
	@$(SPM_ENV) swift run --disable-sandbox EPUBMechanicCLI --generate-completion fish > completions/epub-mechanic.fish
	@$(SPM_ENV) swift run --disable-sandbox EPUBMechanicCLI --generate-completion powershell > completions/epub-mechanic.ps1
	@echo "✅ Completion scripts generated in ./completions/"
	@echo ""
	@echo "To install:"
	@echo "  Bash:       cp completions/epub-mechanic.bash /usr/local/etc/bash_completion.d/"
	@echo "  Zsh:        cp completions/_epub-mechanic /usr/local/share/zsh/site-functions/"
	@echo "  Fish:       cp completions/epub-mechanic.fish ~/.config/fish/completions/"
	@echo "  PowerShell: . completions/epub-mechanic.ps1"

workspace:
	@echo "🚀 Opening ../EbookMechanic.xcworkspace in Xcode..."
	@open ../EbookMechanic.xcworkspace

clean:
	@echo "🧹 Cleaning build artifacts..."
	@chmod -R u+w .build 2>/dev/null || true
	@rm -rf .build
	@echo "✅ Build artifacts removed!"

# Deep clean - removes build artifacts, completions, and docs
clean-all:
	@echo "🧹 Deep cleaning project..."
	@echo "  Fixing permissions..."
	@chmod -R u+w .build 2>/dev/null || true
	@echo "  Removing build artifacts..."
	@rm -rf .build
	@echo "  Removing completions..."
	@rm -rf completions/
	@echo "✅ All build artifacts, completions, and documentation removed!"

# Generate all documentation
docc-all:
	@echo "📚 Generating all documentation..."
	@$(MAKE) docc-cli
	@echo ""
	@echo "✅ All documentation generated!"
	@echo ""
	@echo "To serve: make docc-serve"

docc-cli:
	@echo "Generating DocC documentation for EPUBMechanicCLI..."
	@if command -v docc >/dev/null 2>&1; then \
		echo "Using docc command..."; \
		$(SPM_ENV) swift build --target EPUBMechanicCLI && \
		$(SPM_ENV) swift package plugin generate-documentation \
			--target EPUBMechanicCLI \
			--output-path .build/docc \
			--transform-for-static-hosting \
			--hosting-base-path EPUBMechanicCLI-docs; \
	elif xcodebuild -version >/dev/null 2>&1; then \
		echo "Using xcodebuild docbuild..."; \
		xcodebuild docbuild \
			-scheme EPUBMechanicCLI \
			-destination 'platform=macOS' \
			-derivedDataPath .build/xcode-derived; \
		echo "Documentation built to .build/xcode-derived"; \
	else \
		echo "Error: Neither docc nor xcodebuild found. Please install Xcode or swift-docc-plugin."; \
		exit 1; \
	fi

# Quick local preview using Python HTTP server (requires Python 3)
docc-serve:
	@if [ -d ".build/docc" ]; then \
		echo "📚 Serving EPUBMechanicCLI documentation at http://localhost:8080"; \
		echo "Press Ctrl+C to stop the server."; \
		echo ""; \
		python3 -m http.server --directory .build/docc 8080; \
	else \
		echo "❌ Error: No DocC documentation found."; \
		echo ""; \
		echo "Please generate documentation first:"; \
		echo "  make docc-cli    # Generate cli docs"; \
		echo ""; \
		echo "Then run 'make docc-serve' again."; \
		echo ""; \
		echo "Quick start: make docc-cli && make docc-serve"; \
		exit 1; \
	fi

# Install CLI binary to system path
install: build-cli
	@echo "📦 Installing EPUBMechanicCLI to $(CLI_INSTALL_TARGET)..."
	@if [ ! -f "$(CLI_DEBUG_BINARY)" ]; then \
		echo "❌ Error: Binary not found. Run 'make build-cli' first."; \
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
	@echo "📦 Installing optimized EPUBMechanicCLI to $(CLI_INSTALL_TARGET)..."
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

# Format Swift code (requires swift-format)
format:
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "🎨 Formatting Swift code..."; \
		find EPUBMechanicCLI/Sources -name "*.swift" -exec swift-format -i {} \;; \
		find EPUBMechanicCLI/Tests -name "*.swift" -exec swift-format -i {} \;; \
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
		swift-format lint -r EPUBMechanicCLI/Sources EPUBMechanicCLI/Tests; \
		echo "✅ Format check passed!"; \
	else \
		echo "⚠️  swift-format not installed, skipping format check"; \
	fi

# Lint Swift code (requires SwiftLint)
lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		echo "🔍 Linting Swift code..."; \
		cd ../EPUBMechanicCLI && swiftlint; \
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
	@echo "🔍 EPUBMechanicCLI Build Information"
	@echo "===================================="
	@echo ""
	@echo "Swift version:"
	@swift --version
	@echo ""
	@echo "Xcode version:"
	@xcodebuild -version 2>/dev/null || echo "  Xcode not found"
	@echo ""
	@echo "Build directories:"
	@echo "  CLI:  $(shell du -sh .build 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo ""
	@echo "Generated artifacts:"
	@echo "  Completions: $(shell [ -d completions ] && ls -1 completions | wc -l | xargs || echo '0') files"
	@echo "  CLI docs:   $(shell [ -d .build/docc ] && echo 'Generated' || echo 'Not generated')"
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

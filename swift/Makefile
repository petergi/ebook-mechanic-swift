# EbookMechanic Swift workspace make targets

# Environment setup for reproducible builds
SPM_ENV := SWIFT_MODULE_CACHE_PATH=.build/module-cache CLANG_MODULE_CACHE_PATH=.build/module-cache

# Default shell configuration for better error handling
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Phony targets (targets that don't represent files)
.PHONY: help build build-all build-release test test-all core-test core-build cli-build cli-run cli-normalize cli-normalize-force cli-test cli-completions app-build app-run app-test workspace clean clean-all docc-core docc-app docc-serve docc-all install install-release uninstall format check-format lint ci info update-all

# Default target when running 'make' with no arguments
.DEFAULT_GOAL := build

help:
	@echo "EbookMechanic Make Targets"
	@echo "================================"
	@echo ""
	@echo "🏗️  Build Targets:"
	@echo "  make build         - Build core library only (default)"
	@echo "  make build-all     - Build everything (core + CLI + app)"
	@echo "  make build-release - Build optimized release binaries"
	@echo "  make core-build    - Build the core library"
	@echo "  make cli-build     - Build the CLI executable"
	@echo "  make app-build     - Build the macOS SwiftUI app"
	@echo ""
	@echo "🧪 Test Targets:"
	@echo "  make test          - Run core library tests (default)"
	@echo "  make test-all      - Run all test suites (core + CLI + app)"
	@echo "  make core-test     - Run the EbookMechanicCore test suite"
	@echo "  make cli-test      - Run the CLI test suite"
	@echo "  make app-test      - Run the app test suite"
	@echo ""
	@echo "🚀 Run Targets:"
	@echo "  make cli-run ARGS=             - Run the CLI (default: --help)"
	@echo "  make cli-normalize             - Normalize EPUBs (dry-run mode)"
	@echo "  make cli-normalize-force       - Force normalize EPUBs (live mode)"
	@echo "  make app-run                   - Launch the SwiftUI app"
	@echo ""
	@echo "📚 Documentation Targets:"
	@echo "  make docc-all      - Generate all documentation (core + app)"
	@echo "  make docc-core     - Generate DocC docs for EbookMechanicCore"
	@echo "  make docc-app      - Generate DocC docs for EbookMechanicApp"
	@echo "  make docc-serve    - Serve docs at http://localhost:8080"
	@echo ""
	@echo "🛠️  Utility Targets:"
	@echo "  make cli-completions - Generate shell completion scripts"
	@echo "  make install       - Install CLI to /usr/local/bin (debug)"
	@echo "  make install-release - Install optimized CLI to /usr/local/bin"
	@echo "  make uninstall     - Remove CLI from /usr/local/bin"
	@echo "  make format        - Format all Swift code with swift-format"
	@echo "  make lint          - Lint Swift code (requires SwiftLint)"
	@echo "  make check-format  - Check if code is formatted (CI-friendly)"
	@echo "  make workspace     - Open EbookMechanic.xcworkspace in Xcode"
	@echo "  make clean         - Remove build artifacts for all packages"
	@echo "  make clean-all     - Deep clean (includes completions & docs)"
	@echo "  make info          - Display build information and sizes"
	@echo "  make update-all    - Update completions and documentation"
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
build-all: core-build cli-build app-build
	@echo ""
	@echo "✅ All components built successfully!"

# Release builds (optimized)
build-release:
	@echo "🚀 Building optimized release binaries..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCore -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCLI -c release
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicApp -c release
	@echo "✅ Release builds complete!"
	@echo ""
	@echo "CLI binary: EbookMechanicCLI/.build/release/EbookMechanicCLI"

# Default test target now exercises core, CLI, and app (including UI hooks)
test: core-test cli-test app-test

# Run all test suites
test-all:
	@echo "🧪 Running all test suites..."
	@echo ""
	@$(MAKE) core-test
	@echo ""
	@$(MAKE) cli-test
	@echo ""
	@$(MAKE) app-test
	@echo ""
	@echo "✅ All test suites completed!"

core-test:
	@echo "🧪 Running EbookMechanicCore tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path EbookMechanicCore

core-build:
	@echo "🔨 Building EbookMechanicCore..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCore

cli-build:
	@echo "🔨 Building EbookMechanicCLI..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCLI

cli-run:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--help)

cli-normalize:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--normalize-epubs --dry-run)

cli-normalize-force:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--normalize-epubs --force-normalize --dry-run=false)

cli-test:
	@echo "🧪 Running EbookMechanicCLI tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path EbookMechanicCLI

cli-completions:
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

app-build:
	@echo "🔨 Building EbookMechanicApp..."
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicApp

app-run:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicApp EbookMechanicApp

app-test:
	@echo "🧪 Running EbookMechanicApp tests..."
	$(SPM_ENV) swift test --disable-sandbox --package-path EbookMechanicApp

workspace:
	@echo "🚀 Opening EbookMechanic.xcworkspace in Xcode..."
	@open EbookMechanic.xcworkspace

clean:
	@echo "🧹 Cleaning build artifacts..."
	@chmod -R u+w EbookMechanicCore/.build 2>/dev/null || true
	@chmod -R u+w EbookMechanicCLI/.build 2>/dev/null || true
	@chmod -R u+w EbookMechanicApp/.build 2>/dev/null || true
	@rm -rf EbookMechanicCore/.build EbookMechanicCLI/.build EbookMechanicApp/.build
	@echo "✅ Build artifacts removed!"

# Deep clean - removes build artifacts, completions, and docs
clean-all:
	@echo "🧹 Deep cleaning project..."
	@echo "  Fixing permissions..."
	@chmod -R u+w EbookMechanicCore/.build 2>/dev/null || true
	@chmod -R u+w EbookMechanicCLI/.build 2>/dev/null || true
	@chmod -R u+w EbookMechanicApp/.build 2>/dev/null || true
	@echo "  Removing build artifacts..."
	@rm -rf EbookMechanicCore/.build EbookMechanicCLI/.build EbookMechanicApp/.build
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
install: cli-build
	@echo "📦 Installing EbookMechanicCLI to /usr/local/bin..."
	@if [ -f "EbookMechanicCLI/.build/debug/EbookMechanicCLI" ]; then \
		install -m 755 EbookMechanicCLI/.build/debug/EbookMechanicCLI /usr/local/bin/ebook-mechanic; \
		echo "✅ Installed to /usr/local/bin/ebook-mechanic"; \
		echo ""; \
		echo "Run 'ebook-mechanic --help' to get started!"; \
	else \
		echo "❌ Error: Binary not found. Run 'make cli-build' first."; \
		exit 1; \
	fi

# Install release version (optimized binary)
install-release: build-release
	@echo "📦 Installing optimized EbookMechanicCLI to /usr/local/bin..."
	@if [ -f "EbookMechanicCLI/.build/release/EbookMechanicCLI" ]; then \
		install -m 755 EbookMechanicCLI/.build/release/EbookMechanicCLI /usr/local/bin/ebook-mechanic; \
		strip /usr/local/bin/ebook-mechanic 2>/dev/null || true; \
		echo "✅ Installed optimized binary to /usr/local/bin/ebook-mechanic"; \
		echo ""; \
		echo "Run 'ebook-mechanic --help' to get started!"; \
	else \
		echo "❌ Error: Release binary not found."; \
		exit 1; \
	fi

# Uninstall CLI binary
uninstall:
	@echo "🗑️  Uninstalling ebook-mechanic..."
	@rm -f /usr/local/bin/ebook-mechanic
	@echo "✅ Uninstalled!"

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
	@echo "  Core: $(shell du -sh EbookMechanicCore/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo "  CLI:  $(shell du -sh EbookMechanicCLI/.build 2>/dev/null | cut -f1 || echo 'Not built')"
	@echo "  App:  $(shell du -sh EbookMechanicApp/.build 2>/dev/null | cut -f1 || echo 'Not built')"
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
	@$(MAKE) cli-completions
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

# Makefile for EbookMechanic
# A comprehensive build and development workflow tool

.PHONY: all build run clean install test help lint fmt vet check coverage \
        build-all build-linux build-darwin build-windows \
        test-unit test-integration test-coverage test-race \
        dev watch docker docker-build docker-run \
        docs godoc release version benchmark profile \
        sample-library

# ==================== Configuration ====================

# Binary name
BINARY_NAME=ebook-mechanic
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME=$(shell date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Build flags
LDFLAGS=-ldflags="-s -w -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)"
LDFLAGS_DEV=-ldflags="-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)"

# Directories
BUILD_DIR=build
COVERAGE_DIR=coverage
DIST_DIR=dist
LIBRARY_DIR?=test-library
LIBRARY_AUTHORS?=10
LIBRARY_FORMATS?=pdf,epub,mobi,azw3,azw4

# Colors for output
COLOR_RESET=\033[0m
COLOR_BOLD=\033[1m
COLOR_GREEN=\033[32m
COLOR_YELLOW=\033[33m
COLOR_BLUE=\033[34m
COLOR_MAGENTA=\033[35m

# ==================== Default Target ====================

all: check build test

# ==================== Build Targets ====================

## build: Build optimized binary for current platform
build:
	@echo "$(COLOR_BLUE)Building $(BINARY_NAME) $(VERSION)...$(COLOR_RESET)"
	@mkdir -p $(BUILD_DIR)
	@go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) .
	@echo "$(COLOR_GREEN)✓ Build complete: $(BUILD_DIR)/$(BINARY_NAME)$(COLOR_RESET)"

## build-dev: Build binary with debug symbols
build-dev:
	@echo "$(COLOR_BLUE)Building $(BINARY_NAME) (development mode)...$(COLOR_RESET)"
	@mkdir -p $(BUILD_DIR)
	@go build $(LDFLAGS_DEV) -o $(BUILD_DIR)/$(BINARY_NAME) .
	@echo "$(COLOR_GREEN)✓ Development build complete$(COLOR_RESET)"

## build-all: Build for all platforms (Linux, macOS, Windows)
build-all: build-linux build-darwin build-windows
	@echo "$(COLOR_GREEN)✓ All platform builds complete!$(COLOR_RESET)"

## build-linux: Build for Linux (amd64)
build-linux:
	@echo "$(COLOR_BLUE)Building for Linux amd64...$(COLOR_RESET)"
	@mkdir -p $(DIST_DIR)
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(DIST_DIR)/$(BINARY_NAME)-linux-amd64 .
	@echo "$(COLOR_GREEN)✓ Linux build complete$(COLOR_RESET)"

## build-darwin: Build for macOS (Intel and Apple Silicon)
build-darwin:
	@echo "$(COLOR_BLUE)Building for macOS...$(COLOR_RESET)"
	@mkdir -p $(DIST_DIR)
	@GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(DIST_DIR)/$(BINARY_NAME)-darwin-amd64 .
	@GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(DIST_DIR)/$(BINARY_NAME)-darwin-arm64 .
	@echo "$(COLOR_GREEN)✓ macOS builds complete$(COLOR_RESET)"

## build-windows: Build for Windows (amd64)
build-windows:
	@echo "$(COLOR_BLUE)Building for Windows amd64...$(COLOR_RESET)"
	@mkdir -p $(DIST_DIR)
	@GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(DIST_DIR)/$(BINARY_NAME)-windows-amd64.exe .
	@echo "$(COLOR_GREEN)✓ Windows build complete$(COLOR_RESET)"

# ==================== Run Targets ====================

## run: Run the application (without building)
run:
	@go run .

## run-dry: Run the application in dry-run mode
run-dry:
	@go run . -dry-run

## run-no-tui: Run the application without TUI
run-no-tui:
	@go run . -no-tui

# ==================== Test Fixtures ====================

## sample-library: Generate sample ebook library with valid and corrupt files
sample-library:
	@echo "$(COLOR_BLUE)Generating sample library...$(COLOR_RESET)"
	@python3 python/generate_test_library.py --output $(LIBRARY_DIR) --authors $(LIBRARY_AUTHORS) --formats $(LIBRARY_FORMATS) --force
	@echo "$(COLOR_GREEN)✓ Sample library ready in $(LIBRARY_DIR)$(COLOR_RESET)"

# ==================== Test Targets ====================

## test: Run all tests
test:
	@echo "$(COLOR_BLUE)Running tests...$(COLOR_RESET)"
	@go test -v ./...

## test-unit: Run unit tests only
test-unit:
	@echo "$(COLOR_BLUE)Running unit tests...$(COLOR_RESET)"
	@go test -v -short ./...

## test-race: Run tests with race detector
test-race:
	@echo "$(COLOR_BLUE)Running tests with race detector...$(COLOR_RESET)"
	@go test -race -v ./...

## test-coverage: Run tests with coverage report
test-coverage:
	@echo "$(COLOR_BLUE)Running tests with coverage...$(COLOR_RESET)"
	@mkdir -p $(COVERAGE_DIR)
	@go test -coverprofile=$(COVERAGE_DIR)/coverage.out ./...
	@go tool cover -html=$(COVERAGE_DIR)/coverage.out -o $(COVERAGE_DIR)/coverage.html
	@go tool cover -func=$(COVERAGE_DIR)/coverage.out
	@echo "$(COLOR_GREEN)✓ Coverage report: $(COVERAGE_DIR)/coverage.html$(COLOR_RESET)"

## test-watch: Run tests in watch mode (requires entr)
test-watch:
	@echo "$(COLOR_BLUE)Watching for changes...$(COLOR_RESET)"
	@if command -v entr >/dev/null 2>&1; then \
		find . -name "*.go" | entr -c go test ./...; \
	else \
		echo "$(COLOR_YELLOW)⚠ 'entr' not installed. Install with: brew install entr$(COLOR_RESET)"; \
	fi

## benchmark: Run benchmarks
benchmark:
	@echo "$(COLOR_BLUE)Running benchmarks...$(COLOR_RESET)"
	@go test -bench=. -benchmem ./...

# ==================== Code Quality Targets ====================

## check: Run all code quality checks (fmt, vet, lint)
check: fmt vet lint
	@echo "$(COLOR_GREEN)✓ All checks passed$(COLOR_RESET)"

## fmt: Format code with gofmt
fmt:
	@echo "$(COLOR_BLUE)Formatting code...$(COLOR_RESET)"
	@gofmt -s -w .
	@echo "$(COLOR_GREEN)✓ Code formatted$(COLOR_RESET)"

## vet: Run go vet
vet:
	@echo "$(COLOR_BLUE)Running go vet...$(COLOR_RESET)"
	@go vet ./...
	@echo "$(COLOR_GREEN)✓ go vet passed$(COLOR_RESET)"

## lint: Run golangci-lint (if available)
lint:
	@echo "$(COLOR_BLUE)Running linters...$(COLOR_RESET)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
		echo "$(COLOR_GREEN)✓ Linting complete$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_YELLOW)⚠ golangci-lint not installed, skipping$(COLOR_RESET)"; \
		echo "  Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
	fi

## tidy: Tidy go.mod and go.sum
tidy:
	@echo "$(COLOR_BLUE)Tidying dependencies...$(COLOR_RESET)"
	@go mod tidy
	@echo "$(COLOR_GREEN)✓ Dependencies tidied$(COLOR_RESET)"

# ==================== Dependencies ====================

## deps: Download and verify dependencies
deps:
	@echo "$(COLOR_BLUE)Downloading dependencies...$(COLOR_RESET)"
	@go mod download
	@go mod verify
	@go mod tidy
	@echo "$(COLOR_GREEN)✓ Dependencies ready$(COLOR_RESET)"

## deps-upgrade: Upgrade all dependencies to latest
deps-upgrade:
	@echo "$(COLOR_BLUE)Upgrading dependencies...$(COLOR_RESET)"
	@go get -u ./...
	@go mod tidy
	@echo "$(COLOR_GREEN)✓ Dependencies upgraded$(COLOR_RESET)"

## deps-graph: Show dependency graph (requires go-mod-graph-chart)
deps-graph:
	@go mod graph | go-mod-graph-chart

# ==================== Installation ====================

## install: Install binary to $GOPATH/bin
install:
	@echo "$(COLOR_BLUE)Installing to $$GOPATH/bin...$(COLOR_RESET)"
	@go install $(LDFLAGS)
	@echo "$(COLOR_GREEN)✓ Installed: $$GOPATH/bin/$(BINARY_NAME)$(COLOR_RESET)"

## uninstall: Remove installed binary
uninstall:
	@echo "$(COLOR_BLUE)Uninstalling...$(COLOR_RESET)"
	@rm -f $$GOPATH/bin/$(BINARY_NAME)
	@echo "$(COLOR_GREEN)✓ Uninstalled$(COLOR_RESET)"

# ==================== Documentation ====================

## docs: Generate and view documentation
docs:
	@echo "$(COLOR_BLUE)Generating documentation...$(COLOR_RESET)"
	@go doc -all
	@echo ""
	@echo "$(COLOR_GREEN)View full docs with: go doc -all$(COLOR_RESET)"

## godoc: Start godoc server
godoc:
	@echo "$(COLOR_BLUE)Starting godoc server at http://localhost:6060$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)View docs at: http://localhost:6060/pkg/github.com/petergiannopoulos/ebook-mechanic/$(COLOR_RESET)"
	@if command -v godoc >/dev/null 2>&1; then \
		godoc -http=:6060; \
	else \
		echo "$(COLOR_YELLOW)⚠ godoc not installed$(COLOR_RESET)"; \
		echo "  Install with: go install golang.org/x/tools/cmd/godoc@latest"; \
	fi

# ==================== Profiling ====================

## profile-cpu: Generate CPU profile
profile-cpu:
	@echo "$(COLOR_BLUE)Generating CPU profile...$(COLOR_RESET)"
	@mkdir -p $(BUILD_DIR)
	@go test -cpuprofile=$(BUILD_DIR)/cpu.prof -bench=.
	@go tool pprof -http=:8080 $(BUILD_DIR)/cpu.prof

## profile-mem: Generate memory profile
profile-mem:
	@echo "$(COLOR_BLUE)Generating memory profile...$(COLOR_RESET)"
	@mkdir -p $(BUILD_DIR)
	@go test -memprofile=$(BUILD_DIR)/mem.prof -bench=.
	@go tool pprof -http=:8080 $(BUILD_DIR)/mem.prof

# ==================== Development ====================

## dev: Run in development mode with auto-reload (requires air)
dev:
	@if command -v air >/dev/null 2>&1; then \
		air; \
	else \
		echo "$(COLOR_YELLOW)⚠ 'air' not installed$(COLOR_RESET)"; \
		echo "  Install with: go install github.com/cosmtrek/air@latest"; \
		echo "  Falling back to 'go run .'"; \
		go run .; \
	fi

## watch: Watch for changes and rebuild
watch:
	@echo "$(COLOR_BLUE)Watching for changes... (requires entr)$(COLOR_RESET)"
	@if command -v entr >/dev/null 2>&1; then \
		find . -name "*.go" | entr -c make build; \
	else \
		echo "$(COLOR_YELLOW)⚠ 'entr' not installed$(COLOR_RESET)"; \
		echo "  Install with: brew install entr (macOS) or apt install entr (Linux)"; \
	fi

# ==================== Docker ====================

## docker-build: Build Docker image
docker-build:
	@echo "$(COLOR_BLUE)Building Docker image...$(COLOR_RESET)"
	@docker build -t $(BINARY_NAME):$(VERSION) -t $(BINARY_NAME):latest .
	@echo "$(COLOR_GREEN)✓ Docker image built$(COLOR_RESET)"

## docker-run: Run Docker container
docker-run:
	@docker run --rm -v "$$(pwd)/test-books:/books" $(BINARY_NAME):latest -dir /books

# ==================== Clean Targets ====================

## clean: Clean build artifacts
clean:
	@echo "$(COLOR_BLUE)Cleaning...$(COLOR_RESET)"
	@go clean
	@rm -rf $(BUILD_DIR)
	@rm -rf $(DIST_DIR)
	@rm -rf $(COVERAGE_DIR)
	@rm -f $(BINARY_NAME)
	@rm -f $(BINARY_NAME)-*
	@rm -f *.prof
	@echo "$(COLOR_GREEN)✓ Clean complete$(COLOR_RESET)"

## clean-all: Deep clean of all build artifacts and caches
clean-all: clean
	@echo "$(COLOR_GREEN)✓ All project artifacts cleaned$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)Note: Use 'make clean-modcache' to clean global Go module cache$(COLOR_RESET)"

## clean-modcache: Clean global Go module cache (WARNING: affects all Go projects)
clean-modcache:
	@echo "$(COLOR_YELLOW)⚠ WARNING: This will clean the global Go module cache used by all projects$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)Cleaning module cache...$(COLOR_RESET)"
	@go clean -modcache || echo "$(COLOR_YELLOW)⚠ Module cache cleaning failed (may be in use by other projects)$(COLOR_RESET)"
	@echo "$(COLOR_GREEN)✓ Module cache clean attempted$(COLOR_RESET)"

# ==================== Release ====================

## version: Show version information
version:
	@echo "$(COLOR_BOLD)EbookMechanic$(COLOR_RESET)"
	@echo "Version:    $(VERSION)"
	@echo "Build Time: $(BUILD_TIME)"
	@echo "Git Commit: $(GIT_COMMIT)"
	@echo "Go Version: $$(go version | cut -d' ' -f3)"

## release: Create release builds for all platforms
release: clean check test build-all
	@echo "$(COLOR_GREEN)✓ Release builds created in $(DIST_DIR)/$(COLOR_RESET)"
	@ls -lh $(DIST_DIR)/

# ==================== Info & Help ====================

## info: Show project information
info:
	@echo "$(COLOR_BOLD)╔════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║        EbookMechanic Project Info          ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)╚════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)Project:$(COLOR_RESET)     EbookMechanic"
	@echo "$(COLOR_BLUE)Version:$(COLOR_RESET)     $(VERSION)"
	@echo "$(COLOR_BLUE)Git Commit:$(COLOR_RESET)  $(GIT_COMMIT)"
	@echo "$(COLOR_BLUE)Go Version:$(COLOR_RESET)  $$(go version | cut -d' ' -f3)"
	@echo ""
	@echo "$(COLOR_BLUE)Supported Formats:$(COLOR_RESET)"
	@echo "  📗 EPUB  - Electronic Publication"
	@echo "  📕 MOBI  - Mobipocket"
	@echo "  📘 AZW3  - Kindle Format 8"
	@echo "  📙 AZW4  - Kindle PDF Wrapper"
	@echo "  📄 PDF   - Portable Document Format"
	@echo ""
	@echo "$(COLOR_BLUE)Test Coverage:$(COLOR_RESET) $$(go test -cover ./... 2>&1 | grep coverage | cut -d':' -f2 | tr -d ' ')"
	@echo "$(COLOR_BLUE)Binary Size:$(COLOR_RESET)   $$(if [ -f $(BUILD_DIR)/$(BINARY_NAME) ]; then ls -lh $(BUILD_DIR)/$(BINARY_NAME) | awk '{print $$5}'; else echo 'Not built'; fi)"
	@echo ""

## help: Show available commands
help:
	@echo "$(COLOR_BOLD)╔════════════════════════════════════════════╗$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)║      EbookMechanic - Makefile Commands     ║$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)╚════════════════════════════════════════════╝$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)Usage:$(COLOR_RESET) make [command]"
	@echo ""
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'
	@echo ""
	@echo "$(COLOR_BLUE)Quick Start:$(COLOR_RESET)"
	@echo "  make build          # Build the application"
	@echo "  make test           # Run tests"
	@echo "  make run            # Run without building"
	@echo "  make check          # Run all code quality checks"
	@echo "  make info           # Show project information"
	@echo ""

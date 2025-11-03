# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EbookMechanic is a command-line tool written in Go for managing ebook libraries. It validates ebook files (EPUB, MOBI, AZW3, AZW4, PDF), detects corruption, and cleans up empty folders. Features a beautiful Terminal User Interface (TUI) powered by Bubble Tea.

## Build Commands

```bash
# Build the application (creates optimized binary)
make build

# Build for all platforms (Linux, macOS Intel/ARM, Windows)
make build-all

# Run without building
make run
go run .

# Download and tidy dependencies
make deps

# Clean build artifacts
make clean

# Install to $GOPATH/bin
make install
```

## Development Commands

```bash
# Run tests
make test
go test -v ./...

# Run with specific directory
./ebook-mechanic -dir /path/to/ebooks

# Run without TUI (simple text output)
./ebook-mechanic -no-tui

# Dry run mode (scan only, no modifications)
./ebook-mechanic -dry-run

# Check only for corruption
./ebook-mechanic -corruption-only

# Check only for empty folders
./ebook-mechanic -empty-folders-only

# Skip confirmation prompts
./ebook-mechanic -no-confirm
```

## Project Architecture

### File Organization

The project follows a simple, flat structure with 4 main Go files:

1. **main.go** - Application entry point and Bubble Tea TUI implementation
   - Command-line flag parsing
   - Bubble Tea model, update, and view logic
   - Phase-based state machine (Init → Scanning → Moving → ScanningFolders → Deleting → GeneratingReport → Done)
   - Simple mode runner (non-TUI fallback)

2. **validator.go** - File validation logic for all ebook formats
   - `ValidateEPUB()` - Validates ZIP structure, mimetype, and META-INF/container.xml
   - `ValidateMOBI()` - Checks PalmDB header and BOOKMOBI/TEXtREAd identifier at offset 60
   - `ValidateAZW3()` - Uses MOBI validation (AZW3 is Kindle Format 8 based on MOBI)
   - `ValidateAZW4()` - Uses PDF validation (AZW4 is PDF wrapper for Kindle)
   - `ValidatePDF()` - Validates %PDF- header and %%EOF marker
   - Returns `ValidationResult{IsValid bool, Reason string}`

3. **scanner.go** - File system scanning and operations
   - `FileScanner` - Main scanner struct with mutex for concurrent operations
   - `ScanForCorruption()` - Two-pass algorithm: count files, then validate
   - `ScanForEmptyFolders()` - Bottom-up directory traversal
   - `MoveCorruptedFiles()` - Preserves directory hierarchy in CORRUPTED/
   - `DeleteEmptyFolders()` - Removes folders without ebooks
   - Progress callback support for TUI updates

4. **report.go** - Markdown report generation
   - Generates timestamped reports with format: `ebook_manager_report_YYYY-MM-DD_HH-MM-SS.md`
   - Groups corrupted files by extension
   - Lists empty folder contents (max 5 items shown)

### Key Design Patterns

**Bubble Tea TUI Architecture**
- Phase-based state machine controls application flow
- Message passing between phases (scanCompleteMsg, moveCompleteMsg, etc.)
- Spinner and progress components for visual feedback
- Lipgloss styling with color-coded output (pink titles, green success, red errors, cyan info)

**File Scanner Design**
- Skip CORRUPTED directory to avoid scanning previously moved files
- Two-pass scanning: first count for progress tracking, then process
- Bottom-up folder traversal ensures child folders are checked before parents
- Mutex-protected concurrent access to shared result data
- Optional progress callbacks decouple TUI from core logic

**Validation Strategy**
- Format-specific validators check structural integrity, not content
- EPUB: ZIP validation + required files (mimetype, META-INF/container.xml)
- MOBI: Header signature at specific byte offset (60-68)
- PDF: Header marker + EOF marker in last 1KB

### Data Flow

```
CLI Flags → FileScanner creation → Bubble Tea model initialization
          → Phase transitions drive operations:
             1. ScanForCorruption() validates all ebook files
             2. MoveCorruptedFiles() relocates to CORRUPTED/ (preserving structure)
             3. ScanForEmptyFolders() identifies folders without ebooks
             4. DeleteEmptyFolders() removes empty directories
             5. GenerateMarkdownReport() creates detailed report
```

### Important Implementation Details

**File Validation**
- EPUB files must have `application/epub+zip` as mimetype content (exact match)
- MOBI identifier check: `BOOKMOBI` or `TEXtREAd` at bytes 60-68
- AZW3 files use same validation as MOBI (based on MOBI/PalmDB structure)
- AZW4 files use same validation as PDF (PDF wrapper format)
- PDF validation checks both header (`%PDF-`) and tail (`%%EOF` in last 1KB)
- Minimum file size checks prevent false positives on stub files

**Directory Operations**
- Empty folder detection: `hasEbooks()` walks directory tree checking for .epub/.mobi/.azw3/.azw4/.pdf
- CORRUPTED directory is always skipped (hardcoded path check with `filepath.SkipDir`)
- Bottom-up folder processing ensures children are evaluated before parents
- Directory hierarchy is preserved when moving corrupted files

**TUI State Management**
- Single in-progress phase at a time (enforced by state machine)
- Confirmation prompt waits for 'y'/'n' input before deleting folders
- `-no-confirm` flag bypasses confirmation, `-dry-run` prevents all modifications
- Real-time progress updates via buffered channel (capacity: 100)
- Progress callback sends `progressMsg` through channel to TUI event loop
- `listenForProgress()` creates a Bubble Tea command that waits for channel messages
- Progress is reset (current=0, total=0, item="") when transitioning between phases

## Dependencies

```go
github.com/charmbracelet/bubbletea  // TUI framework (v0.25.0)
github.com/charmbracelet/lipgloss   // Styling library (v0.9.1)
github.com/charmbracelet/bubbles    // TUI components (v0.18.0)
```

All managed via `go.mod` - use `make deps` to download/tidy.

## Common Patterns

**Adding a New File Format**
1. Add extension to `EbookExtensions` map in `NewFileScanner()` (scanner.go)
2. Create `Validate[FORMAT]()` function in validator.go
3. Add case to `ValidateFile()` switch statement
4. Update statistics tracking in `ScanResult` struct (add [FORMAT]Total and [FORMAT]Corrupted fields)
5. Update scanner.go to track statistics in both total counting and corruption tracking switch statements
6. Update report.go to include format in table and corrupted files sections
7. Update main.go TUI statistics display to show the new format
8. Add comprehensive unit tests in validator_test.go

**Modifying the TUI**
- Phases are defined in the `Phase` enum (main.go:50-61)
- Add new phase transition messages as needed (e.g., `type newPhaseMsg struct{}`)
- Update `Update()` to handle new messages and phase transitions
- Modify `View()` to render new phase UI

**Extending Scanner Operations**
- Scanner operations should be async (return `tea.Cmd` in TUI mode)
- Use `fs.mu.Lock()` when modifying shared `ScanResult` data
- Progress callbacks are optional - check `if fs.progressCallback != nil`
- Always skip CORRUPTED directory in `filepath.Walk()` callbacks
- Set progress callback before starting async operations using `scanner.SetProgressCallback()`
- Use `select` with `default` when sending to progress channel to avoid blocking
- Batch progress listener command with operation command using `tea.Batch()`

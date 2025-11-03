# Copilot Instructions for EbookMechanic

## Project Architecture

This is a Go CLI tool for ebook library management with a Bubble Tea TUI. The architecture follows a **flat, single-package design** with 4 main components:

- `main.go` - Entry point + Bubble Tea TUI state machine
- `scanner.go` - File system operations + concurrent scanning logic
- `validator.go` - Format-specific ebook validation (EPUB/MOBI/PDF)
- `report.go` - Markdown report generation

## Key Design Patterns

**Phase-Based State Machine (main.go:50-61)**
The TUI operates through sequential phases: `PhaseInit → PhaseScanning → PhaseMoving → PhaseScanningFolders → PhaseDeleting → PhaseGeneratingReport → PhaseDone`. Each phase transition is message-driven using Bubble Tea's `tea.Cmd` pattern.

**Two-Pass Scanner Algorithm (scanner.go)**
Corruption scanning uses a two-pass approach: first count all ebook files for progress tracking, then validate each file. This prevents progress bar jumps and enables accurate completion percentages.

**Bottom-Up Directory Traversal**
Empty folder detection walks directories from deepest to shallowest, ensuring child directories are evaluated before parents. Use `filepath.Walk` with custom logic, not `filepath.WalkDir`.

**Hardcoded CORRUPTED Directory Skipping**
Always skip the `CORRUPTED/` directory in `filepath.Walk` callbacks using `filepath.SkipDir`. This prevents scanning previously moved corrupted files.

## Critical Implementation Details

**File Format Validation (validator.go)**
- EPUB: Must be valid ZIP + contain `mimetype` file with exact content `application/epub+zip` + `META-INF/container.xml`
- MOBI: Check bytes 60-68 for `BOOKMOBI` or `TEXtREAd` signature (PalmDB header format)
- PDF: Validate `%PDF-` header AND `%%EOF` marker in last 1KB of file

**Concurrent Safety (scanner.go:36)**
The `FileScanner` uses `sync.Mutex` to protect shared `ScanResult` data. Always acquire `fs.mu.Lock()` before modifying statistics or result arrays.

**Directory Hierarchy Preservation**
When moving corrupted files, preserve the original directory structure under `CORRUPTED/`. Use `filepath.Rel()` and `filepath.Join()` to maintain relative paths.

## Development Commands

```bash
# Primary build command (creates optimized binary)
make build

# Development iteration
make run

# Cross-platform builds
make build-all

# Add dependencies
go mod download && go mod tidy
```

## Adding New Features

**New Ebook Format**
1. Add extension to `EbookExtensions` map in `NewFileScanner()`
2. Create `Validate[FORMAT]()` function in `validator.go`
3. Add case to `ValidateFile()` switch statement
4. Update statistics tracking in `ScanResult` struct

**New TUI Phase**
1. Add phase constant to `Phase` enum (main.go:50-61)
2. Create corresponding message type (e.g., `type newPhaseCompleteMsg struct{}`)
3. Handle message in `Update()` method for state transitions
4. Add rendering logic to `View()` method

**Scanner Operations**
- Must return `tea.Cmd` for TUI integration
- Use progress callbacks: check `if fs.progressCallback != nil` before calling
- Always handle the CORRUPTED directory skip pattern
- Wrap file operations in mutex locks for concurrent safety

## Important File Paths

- Ebook extensions: `.epub`, `.mobi`, `.pdf` (case-insensitive)
- Corrupted files moved to: `{rootDir}/CORRUPTED/` (preserving structure)
- Reports generated as: `ebook_manager_report_YYYY-MM-DD_HH-MM-SS.md`
- Binary output: `ebook-manager` (via Makefile)

## Command-Line Interface

The tool supports both TUI and simple modes via flags:
- `-no-tui` - Simple text output mode
- `-dry-run` - Scan only, no file modifications
- `-corruption-only` - Skip empty folder operations
- `-empty-folders-only` - Skip corruption detection
- `-no-confirm` - Skip deletion confirmation prompts
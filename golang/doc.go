// Package main provides EbookMechanic, a blazing-fast command-line tool for managing ebook libraries.
//
// EbookMechanic validates ebook files (EPUB, MOBI, AZW3, AZW4, PDF), detects corruption,
// and cleans up empty folders. It features a beautiful Terminal User Interface (TUI)
// powered by Bubble Tea.
//
// # Features
//
//   - Lightning-fast validation of EPUB, MOBI, AZW3, AZW4, and PDF files
//   - Beautiful interactive TUI with real-time progress updates
//   - Automatic detection and quarantine of corrupted files
//   - Smart cleanup of empty folders
//   - Detailed Markdown reports
//   - Safe operations with confirmation prompts and dry-run mode
//   - Concurrent file processing for maximum performance
//
// # Usage
//
// Basic usage with TUI:
//
//	./ebook-mechanic
//
// Scan specific directory:
//
//	./ebook-mechanic -dir /path/to/ebooks
//
// Run without TUI (simple text output):
//
//	./ebook-mechanic -no-tui
//
// Dry run mode (scan only, don't modify):
//
//	./ebook-mechanic -dry-run
//
// Check only for corrupted files:
//
//	./ebook-mechanic -corruption-only
//
// # File Validation
//
// EPUB: Validates ZIP structure, mimetype file, and META-INF/container.xml
//
// MOBI: Checks PalmDB header and BOOKMOBI/TEXtREAd identifier at offset 60
//
// AZW3: Uses MOBI validation (Kindle Format 8 based on MOBI structure)
//
// AZW4: Uses PDF validation (PDF wrapper format for Kindle)
//
// PDF: Validates %PDF- header and %%EOF marker in last 1KB
//
// # Architecture
//
// The application is organized into four main components:
//
//   - main.go: Application entry point and Bubble Tea TUI implementation
//   - validator.go: File validation logic for all supported ebook formats
//   - scanner.go: File system scanning and operations (corruption detection, folder cleanup)
//   - report.go: Markdown report generation with detailed statistics
//
// # Operations Flow
//
//  1. Scan for corrupted files
//  2. Move corrupted files to CORRUPTED/ directory (preserving structure)
//  3. Scan for empty folders (folders without any ebook files)
//  4. Delete empty folders (with confirmation)
//  5. Generate detailed Markdown report
//  6. Display summary statistics
//
// # Safety Features
//
//   - Confirmation prompts before deleting folders (unless -no-confirm)
//   - Dry run mode to preview changes without modifications
//   - Corrupted files moved to CORRUPTED/ directory (not deleted)
//   - Directory hierarchy preserved when moving corrupted files
//   - CORRUPTED directory automatically skipped during scans
package main

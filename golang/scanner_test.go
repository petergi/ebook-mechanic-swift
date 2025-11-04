package main

import (
	"os"
	"path/filepath"
	"testing"
)

// TestNewFileScanner tests scanner initialization
func TestNewFileScanner(t *testing.T) {
	scanner := NewFileScanner("/test/path", "CORRUPTED")

	if scanner.RootDir != "/test/path" {
		t.Errorf("Expected RootDir '/test/path', got '%s'", scanner.RootDir)
	}

	if scanner.CorruptedDir != "CORRUPTED" {
		t.Errorf("Expected CorruptedDir 'CORRUPTED', got '%s'", scanner.CorruptedDir)
	}

	if !scanner.EbookExtensions[".epub"] {
		t.Error("Expected .epub to be supported")
	}
	if !scanner.EbookExtensions[".mobi"] {
		t.Error("Expected .mobi to be supported")
	}
	if !scanner.EbookExtensions[".azw3"] {
		t.Error("Expected .azw3 to be supported")
	}
	if !scanner.EbookExtensions[".azw4"] {
		t.Error("Expected .azw4 to be supported")
	}
	if !scanner.EbookExtensions[".pdf"] {
		t.Error("Expected .pdf to be supported")
	}

	if scanner.Result == nil {
		t.Error("Expected Result to be initialized")
	}
}

// TestScanForCorruption tests corruption scanning
func TestScanForCorruption(t *testing.T) {
	tempDir := t.TempDir()

	// Create test files
	validEpub := filepath.Join(tempDir, "valid.epub")
	createValidEPUB(t, validEpub)

	invalidEpub := filepath.Join(tempDir, "invalid.epub")
	os.WriteFile(invalidEpub, []byte("not a valid epub"), 0644)

	validPdf := filepath.Join(tempDir, "valid.pdf")
	createValidPDF(t, validPdf)

	scanner := NewFileScanner(tempDir, "CORRUPTED")
	err := scanner.ScanForCorruption()

	if err != nil {
		t.Fatalf("ScanForCorruption failed: %v", err)
	}

	// Check statistics
	if scanner.Result.TotalFiles != 3 {
		t.Errorf("Expected 3 total files, got %d", scanner.Result.TotalFiles)
	}

	if scanner.Result.EPUBTotal != 2 {
		t.Errorf("Expected 2 EPUB files, got %d", scanner.Result.EPUBTotal)
	}

	if scanner.Result.PDFTotal != 1 {
		t.Errorf("Expected 1 PDF file, got %d", scanner.Result.PDFTotal)
	}

	// Check corruption detection
	if scanner.Result.EPUBCorrupted != 1 {
		t.Errorf("Expected 1 corrupted EPUB, got %d", scanner.Result.EPUBCorrupted)
	}

	if len(scanner.Result.CorruptedFiles) != 1 {
		t.Errorf("Expected 1 corrupted file, got %d", len(scanner.Result.CorruptedFiles))
	}
}

// TestScanForCorruptionSkipsCorruptedDir tests that CORRUPTED directory is skipped
func TestScanForCorruptionSkipsCorruptedDir(t *testing.T) {
	tempDir := t.TempDir()

	// Create a file in the main directory
	validEpub := filepath.Join(tempDir, "valid.epub")
	createValidEPUB(t, validEpub)

	// Create CORRUPTED directory with files
	corruptedDir := filepath.Join(tempDir, "CORRUPTED")
	os.Mkdir(corruptedDir, 0755)
	corruptedFile := filepath.Join(corruptedDir, "should_skip.epub")
	os.WriteFile(corruptedFile, []byte("test"), 0644)

	scanner := NewFileScanner(tempDir, "CORRUPTED")
	err := scanner.ScanForCorruption()

	if err != nil {
		t.Fatalf("ScanForCorruption failed: %v", err)
	}

	// Should only count the file outside CORRUPTED directory
	if scanner.Result.TotalFiles != 1 {
		t.Errorf("Expected 1 file (skipping CORRUPTED dir), got %d", scanner.Result.TotalFiles)
	}
}

// TestHasEbooks tests the hasEbooks function
func TestHasEbooks(t *testing.T) {
	tempDir := t.TempDir()

	t.Run("Directory with ebooks", func(t *testing.T) {
		dirWithEbooks := filepath.Join(tempDir, "with_ebooks")
		os.Mkdir(dirWithEbooks, 0755)

		epubFile := filepath.Join(dirWithEbooks, "book.epub")
		createValidEPUB(t, epubFile)

		scanner := NewFileScanner(tempDir, "CORRUPTED")
		if !scanner.hasEbooks(dirWithEbooks) {
			t.Error("Expected directory to have ebooks")
		}
	})

	t.Run("Directory without ebooks", func(t *testing.T) {
		dirWithoutEbooks := filepath.Join(tempDir, "no_ebooks")
		os.Mkdir(dirWithoutEbooks, 0755)

		txtFile := filepath.Join(dirWithoutEbooks, "readme.txt")
		os.WriteFile(txtFile, []byte("test"), 0644)

		scanner := NewFileScanner(tempDir, "CORRUPTED")
		if scanner.hasEbooks(dirWithoutEbooks) {
			t.Error("Expected directory to not have ebooks")
		}
	})

	t.Run("Empty directory", func(t *testing.T) {
		emptyDir := filepath.Join(tempDir, "empty")
		os.Mkdir(emptyDir, 0755)

		scanner := NewFileScanner(tempDir, "CORRUPTED")
		if scanner.hasEbooks(emptyDir) {
			t.Error("Expected empty directory to not have ebooks")
		}
	})
}

// TestScanForEmptyFolders tests empty folder scanning
func TestScanForEmptyFolders(t *testing.T) {
	tempDir := t.TempDir()

	// Create directory with ebooks
	dirWithEbooks := filepath.Join(tempDir, "with_ebooks")
	os.Mkdir(dirWithEbooks, 0755)
	createValidEPUB(t, filepath.Join(dirWithEbooks, "book.epub"))

	// Create directory without ebooks
	dirWithoutEbooks := filepath.Join(tempDir, "without_ebooks")
	os.Mkdir(dirWithoutEbooks, 0755)
	os.WriteFile(filepath.Join(dirWithoutEbooks, "readme.txt"), []byte("test"), 0644)

	// Create empty directory
	emptyDir := filepath.Join(tempDir, "empty")
	os.Mkdir(emptyDir, 0755)

	scanner := NewFileScanner(tempDir, "CORRUPTED")
	err := scanner.ScanForEmptyFolders()

	if err != nil {
		t.Fatalf("ScanForEmptyFolders failed: %v", err)
	}

	// Should find 2 folders without ebooks (dirWithoutEbooks and emptyDir)
	if len(scanner.Result.EmptyFolders) != 2 {
		t.Errorf("Expected 2 empty folders, got %d", len(scanner.Result.EmptyFolders))
	}

	if scanner.Result.FoldersWithEbooks != 1 {
		t.Errorf("Expected 1 folder with ebooks, got %d", scanner.Result.FoldersWithEbooks)
	}

	if scanner.Result.TotalFolders != 3 {
		t.Errorf("Expected 3 total folders, got %d", scanner.Result.TotalFolders)
	}
}

// TestMoveCorruptedFiles tests moving corrupted files
func TestMoveCorruptedFiles(t *testing.T) {
	tempDir := t.TempDir()

	// Create subdirectory structure
	subDir := filepath.Join(tempDir, "books", "fiction")
	os.MkdirAll(subDir, 0755)

	// Create corrupted file
	corruptedFile := filepath.Join(subDir, "corrupted.epub")
	os.WriteFile(corruptedFile, []byte("not valid"), 0644)

	scanner := NewFileScanner(tempDir, "CORRUPTED")

	// Manually add to corrupted files list
	scanner.Result.CorruptedFiles = append(scanner.Result.CorruptedFiles, CorruptedFile{
		Path:   corruptedFile,
		Reason: "Test corruption",
		Size:   9,
	})

	err := scanner.MoveCorruptedFiles()
	if err != nil {
		t.Fatalf("MoveCorruptedFiles failed: %v", err)
	}

	// Check that file was moved
	if _, err := os.Stat(corruptedFile); !os.IsNotExist(err) {
		t.Error("Expected original file to be moved")
	}

	// Check that file exists in CORRUPTED directory with same structure
	expectedPath := filepath.Join(tempDir, "CORRUPTED", "books", "fiction", "corrupted.epub")
	if _, err := os.Stat(expectedPath); os.IsNotExist(err) {
		t.Errorf("Expected file to exist at %s", expectedPath)
	}
}

// TestDeleteEmptyFolders tests deleting empty folders
func TestDeleteEmptyFolders(t *testing.T) {
	tempDir := t.TempDir()

	// Create folders to delete
	emptyDir1 := filepath.Join(tempDir, "empty1")
	emptyDir2 := filepath.Join(tempDir, "empty2")
	os.Mkdir(emptyDir1, 0755)
	os.Mkdir(emptyDir2, 0755)

	scanner := NewFileScanner(tempDir, "CORRUPTED")
	scanner.Result.EmptyFolders = []string{emptyDir1, emptyDir2}

	err := scanner.DeleteEmptyFolders()
	if err != nil {
		t.Fatalf("DeleteEmptyFolders failed: %v", err)
	}

	// Check that directories were deleted
	if _, err := os.Stat(emptyDir1); !os.IsNotExist(err) {
		t.Error("Expected emptyDir1 to be deleted")
	}

	if _, err := os.Stat(emptyDir2); !os.IsNotExist(err) {
		t.Error("Expected emptyDir2 to be deleted")
	}
}

// TestProgressCallback tests that progress callbacks are called
func TestProgressCallback(t *testing.T) {
	tempDir := t.TempDir()

	// Create test files
	createValidEPUB(t, filepath.Join(tempDir, "book1.epub"))
	createValidEPUB(t, filepath.Join(tempDir, "book2.epub"))

	scanner := NewFileScanner(tempDir, "CORRUPTED")

	callCount := 0
	var lastTotal int

	scanner.SetProgressCallback(func(current, total int, item string) {
		callCount++
		lastTotal = total
	})

	scanner.ScanForCorruption()

	if callCount == 0 {
		t.Error("Expected progress callback to be called")
	}

	if lastTotal != 2 {
		t.Errorf("Expected total of 2 files, got %d", lastTotal)
	}
}

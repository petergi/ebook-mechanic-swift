package main

import (
	"archive/zip"
	"os"
	"path/filepath"
	"testing"
)

// TestValidateEPUB tests EPUB validation
func TestValidateEPUB(t *testing.T) {
	// Create temp directory for test files
	tempDir := t.TempDir()

	t.Run("Valid EPUB", func(t *testing.T) {
		epubPath := filepath.Join(tempDir, "valid.epub")
		createValidEPUB(t, epubPath)

		result := ValidateEPUB(epubPath)
		if !result.IsValid {
			t.Errorf("Expected valid EPUB, got invalid: %s", result.Reason)
		}
	})

	t.Run("Missing mimetype file", func(t *testing.T) {
		epubPath := filepath.Join(tempDir, "no_mimetype.epub")
		createEPUBWithoutMimetype(t, epubPath)

		result := ValidateEPUB(epubPath)
		if result.IsValid {
			t.Error("Expected invalid EPUB (missing mimetype), got valid")
		}
		if result.Reason != "Missing mimetype file" {
			t.Errorf("Expected 'Missing mimetype file', got '%s'", result.Reason)
		}
	})

	t.Run("Invalid mimetype content", func(t *testing.T) {
		epubPath := filepath.Join(tempDir, "wrong_mimetype.epub")
		createEPUBWithWrongMimetype(t, epubPath)

		result := ValidateEPUB(epubPath)
		if result.IsValid {
			t.Error("Expected invalid EPUB (wrong mimetype), got valid")
		}
	})

	t.Run("Missing container.xml", func(t *testing.T) {
		epubPath := filepath.Join(tempDir, "no_container.epub")
		createEPUBWithoutContainer(t, epubPath)

		result := ValidateEPUB(epubPath)
		if result.IsValid {
			t.Error("Expected invalid EPUB (missing container.xml), got valid")
		}
		if result.Reason != "Missing META-INF/container.xml" {
			t.Errorf("Expected 'Missing META-INF/container.xml', got '%s'", result.Reason)
		}
	})

	t.Run("Not a ZIP file", func(t *testing.T) {
		epubPath := filepath.Join(tempDir, "not_zip.epub")
		os.WriteFile(epubPath, []byte("This is not a ZIP file"), 0644)

		result := ValidateEPUB(epubPath)
		if result.IsValid {
			t.Error("Expected invalid EPUB (not a ZIP), got valid")
		}
		if result.Reason != "Not a valid ZIP file" {
			t.Errorf("Expected 'Not a valid ZIP file', got '%s'", result.Reason)
		}
	})
}

// TestValidateMOBI tests MOBI validation
func TestValidateMOBI(t *testing.T) {
	tempDir := t.TempDir()

	t.Run("Valid MOBI with BOOKMOBI", func(t *testing.T) {
		mobiPath := filepath.Join(tempDir, "valid.mobi")
		createValidMOBI(t, mobiPath, "BOOKMOBI")

		result := ValidateMOBI(mobiPath)
		if !result.IsValid {
			t.Errorf("Expected valid MOBI, got invalid: %s", result.Reason)
		}
	})

	t.Run("Valid MOBI with TEXtREAd", func(t *testing.T) {
		mobiPath := filepath.Join(tempDir, "valid_text.mobi")
		createValidMOBI(t, mobiPath, "TEXtREAd")

		result := ValidateMOBI(mobiPath)
		if !result.IsValid {
			t.Errorf("Expected valid MOBI, got invalid: %s", result.Reason)
		}
	})

	t.Run("Invalid MOBI identifier", func(t *testing.T) {
		mobiPath := filepath.Join(tempDir, "invalid.mobi")
		createInvalidMOBI(t, mobiPath)

		result := ValidateMOBI(mobiPath)
		if result.IsValid {
			t.Error("Expected invalid MOBI, got valid")
		}
	})

	t.Run("File too small", func(t *testing.T) {
		mobiPath := filepath.Join(tempDir, "small.mobi")
		os.WriteFile(mobiPath, []byte("short"), 0644)

		result := ValidateMOBI(mobiPath)
		if result.IsValid {
			t.Error("Expected invalid MOBI (too small), got valid")
		}
		if result.Reason != "File too small" {
			t.Errorf("Expected 'File too small', got '%s'", result.Reason)
		}
	})

	t.Run("All zeros PalmDB header", func(t *testing.T) {
		mobiPath := filepath.Join(tempDir, "zeros.mobi")
		createMOBIWithZeroHeader(t, mobiPath)

		result := ValidateMOBI(mobiPath)
		if result.IsValid {
			t.Error("Expected invalid MOBI (zero header), got valid")
		}
		if result.Reason != "Invalid PalmDB header" {
			t.Errorf("Expected 'Invalid PalmDB header', got '%s'", result.Reason)
		}
	})
}

// TestValidatePDF tests PDF validation
func TestValidatePDF(t *testing.T) {
	tempDir := t.TempDir()

	t.Run("Valid PDF", func(t *testing.T) {
		pdfPath := filepath.Join(tempDir, "valid.pdf")
		createValidPDF(t, pdfPath)

		result := ValidatePDF(pdfPath)
		if !result.IsValid {
			t.Errorf("Expected valid PDF, got invalid: %s", result.Reason)
		}
	})

	t.Run("Missing PDF header", func(t *testing.T) {
		pdfPath := filepath.Join(tempDir, "no_header.pdf")
		os.WriteFile(pdfPath, []byte("Not a PDF file with enough content to pass size check but no header marker at all"), 0644)

		result := ValidatePDF(pdfPath)
		if result.IsValid {
			t.Error("Expected invalid PDF (no header), got valid")
		}
		if result.Reason != "Missing PDF header" {
			t.Errorf("Expected 'Missing PDF header', got '%s'", result.Reason)
		}
	})

	t.Run("File too small", func(t *testing.T) {
		pdfPath := filepath.Join(tempDir, "small.pdf")
		os.WriteFile(pdfPath, []byte("%PDF-1.4\nsmall"), 0644)

		result := ValidatePDF(pdfPath)
		if result.IsValid {
			t.Error("Expected invalid PDF (too small), got valid")
		}
		if result.Reason != "File too small to be valid PDF" {
			t.Errorf("Expected 'File too small to be valid PDF', got '%s'", result.Reason)
		}
	})

	t.Run("Missing EOF marker", func(t *testing.T) {
		pdfPath := filepath.Join(tempDir, "no_eof.pdf")
		createPDFWithoutEOF(t, pdfPath)

		result := ValidatePDF(pdfPath)
		if result.IsValid {
			t.Error("Expected invalid PDF (no EOF), got valid")
		}
		if result.Reason != "Missing %%EOF marker" {
			t.Errorf("Expected 'Missing %%EOF marker', got '%s'", result.Reason)
		}
	})
}

// TestValidateAZW3 tests AZW3 validation
func TestValidateAZW3(t *testing.T) {
	tempDir := t.TempDir()

	t.Run("Valid AZW3", func(t *testing.T) {
		azw3Path := filepath.Join(tempDir, "valid.azw3")
		createValidMOBI(t, azw3Path, "BOOKMOBI")

		result := ValidateAZW3(azw3Path)
		if !result.IsValid {
			t.Errorf("Expected valid AZW3, got invalid: %s", result.Reason)
		}
	})

	t.Run("Invalid AZW3", func(t *testing.T) {
		azw3Path := filepath.Join(tempDir, "invalid.azw3")
		os.WriteFile(azw3Path, []byte("not a valid azw3 file"), 0644)

		result := ValidateAZW3(azw3Path)
		if result.IsValid {
			t.Error("Expected invalid AZW3, got valid")
		}
	})
}

// TestValidateAZW4 tests AZW4 validation
func TestValidateAZW4(t *testing.T) {
	tempDir := t.TempDir()

	t.Run("Valid AZW4", func(t *testing.T) {
		azw4Path := filepath.Join(tempDir, "valid.azw4")
		createValidPDF(t, azw4Path)

		result := ValidateAZW4(azw4Path)
		if !result.IsValid {
			t.Errorf("Expected valid AZW4, got invalid: %s", result.Reason)
		}
	})

	t.Run("Invalid AZW4", func(t *testing.T) {
		azw4Path := filepath.Join(tempDir, "invalid.azw4")
		os.WriteFile(azw4Path, []byte("not a pdf"), 0644)

		result := ValidateAZW4(azw4Path)
		if result.IsValid {
			t.Error("Expected invalid AZW4, got valid")
		}
	})
}

// TestValidateFile tests the main ValidateFile function
func TestValidateFile(t *testing.T) {
	tempDir := t.TempDir()

	t.Run("EPUB file", func(t *testing.T) {
		epubPath := filepath.Join(tempDir, "test.epub")
		createValidEPUB(t, epubPath)

		result := ValidateFile(epubPath, ".epub")
		if !result.IsValid {
			t.Errorf("Expected valid EPUB, got invalid: %s", result.Reason)
		}
	})

	t.Run("MOBI file", func(t *testing.T) {
		mobiPath := filepath.Join(tempDir, "test.mobi")
		createValidMOBI(t, mobiPath, "BOOKMOBI")

		result := ValidateFile(mobiPath, ".mobi")
		if !result.IsValid {
			t.Errorf("Expected valid MOBI, got invalid: %s", result.Reason)
		}
	})

	t.Run("AZW3 file", func(t *testing.T) {
		azw3Path := filepath.Join(tempDir, "test.azw3")
		createValidMOBI(t, azw3Path, "BOOKMOBI")

		result := ValidateFile(azw3Path, ".azw3")
		if !result.IsValid {
			t.Errorf("Expected valid AZW3, got invalid: %s", result.Reason)
		}
	})

	t.Run("AZW4 file", func(t *testing.T) {
		azw4Path := filepath.Join(tempDir, "test.azw4")
		createValidPDF(t, azw4Path)

		result := ValidateFile(azw4Path, ".azw4")
		if !result.IsValid {
			t.Errorf("Expected valid AZW4, got invalid: %s", result.Reason)
		}
	})

	t.Run("PDF file", func(t *testing.T) {
		pdfPath := filepath.Join(tempDir, "test.pdf")
		createValidPDF(t, pdfPath)

		result := ValidateFile(pdfPath, ".pdf")
		if !result.IsValid {
			t.Errorf("Expected valid PDF, got invalid: %s", result.Reason)
		}
	})

	t.Run("Unknown file type", func(t *testing.T) {
		txtPath := filepath.Join(tempDir, "test.txt")
		os.WriteFile(txtPath, []byte("test"), 0644)

		result := ValidateFile(txtPath, ".txt")
		if !result.IsValid {
			t.Error("Expected unknown types to be marked valid")
		}
		if result.Reason != "Unknown file type" {
			t.Errorf("Expected 'Unknown file type', got '%s'", result.Reason)
		}
	})
}

// Helper functions to create test files

func createValidEPUB(tb testing.TB, path string) {
	tb.Helper()
	f, err := os.Create(path)
	if err != nil {
		tb.Fatal(err)
	}
	defer f.Close()

	w := zip.NewWriter(f)
	defer w.Close()

	addStoredMimetype(tb, w, "application/epub+zip")

	// Add container.xml
	containerFile, _ := w.Create("META-INF/container.xml")
	containerFile.Write([]byte(`<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>`))
}

func createEPUBWithoutMimetype(tb testing.TB, path string) {
	tb.Helper()
	f, err := os.Create(path)
	if err != nil {
		tb.Fatal(err)
	}
	defer f.Close()

	w := zip.NewWriter(f)
	defer w.Close()

	// Add container.xml but no mimetype
	containerFile, _ := w.Create("META-INF/container.xml")
	containerFile.Write([]byte(`<?xml version="1.0"?><container></container>`))
}

func createEPUBWithWrongMimetype(tb testing.TB, path string) {
	tb.Helper()
	f, err := os.Create(path)
	if err != nil {
		tb.Fatal(err)
	}
	defer f.Close()

	w := zip.NewWriter(f)
	defer w.Close()

	addStoredMimetype(tb, w, "text/plain")

	// Add container.xml
	containerFile, _ := w.Create("META-INF/container.xml")
	containerFile.Write([]byte(`<?xml version="1.0"?><container></container>`))
}

func createEPUBWithoutContainer(tb testing.TB, path string) {
	tb.Helper()
	f, err := os.Create(path)
	if err != nil {
		tb.Fatal(err)
	}
	defer f.Close()

	w := zip.NewWriter(f)
	defer w.Close()
	addStoredMimetype(tb, w, "application/epub+zip")
}

func createValidMOBI(tb testing.TB, path string, identifier string) {
	tb.Helper()
	header := make([]byte, 100)
	// Set some non-zero bytes in PalmDB name (first 32 bytes)
	copy(header[0:], []byte("Test MOBI File"))
	// Set identifier at offset 60
	copy(header[60:], []byte(identifier))

	if err := os.WriteFile(path, header, 0644); err != nil {
		tb.Fatal(err)
	}
}

func createInvalidMOBI(tb testing.TB, path string) {
	tb.Helper()
	header := make([]byte, 100)
	// Set some non-zero bytes in PalmDB name
	copy(header[0:], []byte("Test File"))
	// Set wrong identifier
	copy(header[60:], []byte("NOTMOBI!"))

	if err := os.WriteFile(path, header, 0644); err != nil {
		tb.Fatal(err)
	}
}

func createMOBIWithZeroHeader(tb testing.TB, path string) {
	tb.Helper()
	header := make([]byte, 100)
	// Leave first 32 bytes as zeros
	// Set valid identifier
	copy(header[60:], []byte("BOOKMOBI"))

	if err := os.WriteFile(path, header, 0644); err != nil {
		tb.Fatal(err)
	}
}

func addStoredMimetype(tb testing.TB, w *zip.Writer, value string) {
	tb.Helper()
	head := &zip.FileHeader{Name: "mimetype", Method: zip.Store}
	head.SetMode(0644)
	fw, err := w.CreateHeader(head)
	if err != nil {
		tb.Fatal(err)
	}
	if _, err := fw.Write([]byte(value)); err != nil {
		tb.Fatal(err)
	}
}

func createValidPDF(tb testing.TB, path string) {
	tb.Helper()
	content := []byte("%PDF-1.4\n")
	// Add enough content to pass size check
	for i := 0; i < 20; i++ {
		content = append(content, []byte("Some PDF content here to make it larger than 100 bytes.\n")...)
	}
	content = append(content, []byte("%%EOF\n")...)

	if err := os.WriteFile(path, content, 0644); err != nil {
		tb.Fatal(err)
	}
}

func createPDFWithoutEOF(tb testing.TB, path string) {
	tb.Helper()
	content := []byte("%PDF-1.4\n")
	// Add enough content to pass size check but no EOF marker
	for i := 0; i < 20; i++ {
		content = append(content, []byte("Some PDF content here to make it larger than 100 bytes.\n")...)
	}

	if err := os.WriteFile(path, content, 0644); err != nil {
		tb.Fatal(err)
	}
}

package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRepairEPUB(t *testing.T) {
	t.Run("Valid EPUB needs no repair", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "valid.epub")
		createValidEPUB(t, tempFile)
		defer os.Remove(tempFile)

		result := RepairEPUB(tempFile)
		if !result.Success {
			t.Errorf("Expected success, got failure: %s", result.Message)
		}
		if result.Fixed {
			t.Error("Expected file not to be modified")
		}
	})

	t.Run("EPUB missing mimetype", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "no-mimetype.epub")
		createEPUBWithoutMimetype(t, tempFile)
		defer os.Remove(tempFile)
		defer os.Remove(tempFile + ".backup")

		result := RepairEPUB(tempFile)
		if !result.Success {
			t.Errorf("Expected successful repair, got: %s", result.Message)
		}
		if !result.Fixed {
			t.Error("Expected file to be fixed")
		}

		// Verify repair worked
		validation := ValidateEPUB(tempFile)
		if !validation.IsValid {
			t.Errorf("Repair failed, file still invalid: %s", validation.Reason)
		}
	})

	t.Run("EPUB missing container.xml", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "no-container.epub")
		createEPUBWithoutContainer(t, tempFile)
		defer os.Remove(tempFile)
		defer os.Remove(tempFile + ".backup")

		result := RepairEPUB(tempFile)
		if !result.Success {
			t.Errorf("Expected successful repair, got: %s", result.Message)
		}
		if !result.Fixed {
			t.Error("Expected file to be fixed")
		}

		// Verify repair worked
		validation := ValidateEPUB(tempFile)
		if !validation.IsValid {
			t.Errorf("Repair failed, file still invalid: %s", validation.Reason)
		}
	})

	t.Run("Corrupted ZIP cannot be repaired", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "corrupted.epub")
		os.WriteFile(tempFile, []byte("not a zip file"), 0644)
		defer os.Remove(tempFile)

		result := RepairEPUB(tempFile)
		if result.Success {
			t.Error("Expected repair to fail for corrupted ZIP")
		}
		if result.Fixed {
			t.Error("Expected file not to be fixed")
		}
	})
}

func TestRepairPDF(t *testing.T) {
	t.Run("Valid PDF needs no repair", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "valid.pdf")
		createValidPDF(t, tempFile)
		defer os.Remove(tempFile)

		result := RepairPDF(tempFile)
		if !result.Success {
			t.Errorf("Expected success, got failure: %s", result.Message)
		}
		if result.Fixed {
			t.Error("Expected file not to be modified")
		}
	})

	t.Run("PDF missing EOF marker", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "test.pdf")
		// Create a PDF with sufficient content but missing EOF
		content := []byte("%PDF-1.4\n")
		for i := 0; i < 20; i++ {
			content = append(content, []byte("Some PDF content here to make it larger than 100 bytes.\n")...)
		}
		content = append(content, []byte("1 0 obj\n<<>>\nendobj\nxref\n0 2\ntrailer\n<<>>")...)
		os.WriteFile(tempFile, content, 0644)
		defer os.Remove(tempFile)
		defer os.Remove(tempFile + ".backup")

		result := RepairPDF(tempFile)
		if !result.Success {
			t.Errorf("Expected successful repair, got: %s", result.Message)
		}
		if !result.Fixed {
			t.Error("Expected file to be fixed")
		}

		// Verify repair worked
		validation := ValidatePDF(tempFile)
		if !validation.IsValid {
			t.Errorf("Repair failed, file still invalid: %s", validation.Reason)
		}
	})

	t.Run("PDF without header cannot be repaired", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "noheader.pdf")
		os.WriteFile(tempFile, []byte("This is not a PDF\n%%EOF"), 0644)
		defer os.Remove(tempFile)

		result := RepairPDF(tempFile)
		if result.Success {
			t.Error("Expected repair to fail for missing header")
		}
		if result.Fixed {
			t.Error("Expected file not to be fixed")
		}
	})

	t.Run("File too small to repair", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "tiny.pdf")
		os.WriteFile(tempFile, []byte("PDF"), 0644)
		defer os.Remove(tempFile)

		result := RepairPDF(tempFile)
		if result.Success {
			t.Error("Expected repair to fail for tiny file")
		}
	})
}

func TestRepairMOBI(t *testing.T) {
	t.Run("Valid MOBI needs no repair", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "valid.mobi")
		createValidMOBI(t, tempFile, "BOOKMOBI")
		defer os.Remove(tempFile)

		result := RepairMOBI(tempFile)
		if !result.Success {
			t.Errorf("Expected success, got failure: %s", result.Message)
		}
		if result.Fixed {
			t.Error("Expected file not to be modified")
		}
	})

	t.Run("Corrupted MOBI shows limitation message", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "corrupt.mobi")
		os.WriteFile(tempFile, make([]byte, 100), 0644)
		defer os.Remove(tempFile)

		result := RepairMOBI(tempFile)
		if result.Success {
			t.Error("Expected repair to indicate it cannot fix MOBI")
		}
		if result.Fixed {
			t.Error("Expected file not to be fixed")
		}
	})

	t.Run("File too small", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "tiny.mobi")
		os.WriteFile(tempFile, []byte("MOBI"), 0644)
		defer os.Remove(tempFile)

		result := RepairMOBI(tempFile)
		if result.Success {
			t.Error("Expected repair to fail for tiny file")
		}
	})
}

func TestRepairFile(t *testing.T) {
	t.Run("Route EPUB to RepairEPUB", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "test.epub")
		createValidEPUB(t, tempFile)
		defer os.Remove(tempFile)

		result := RepairFile(tempFile)
		if !result.Success {
			t.Error("Expected EPUB repair to succeed")
		}
	})

	t.Run("Route PDF to RepairPDF", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "test.pdf")
		createValidPDF(t, tempFile)
		defer os.Remove(tempFile)

		result := RepairFile(tempFile)
		if !result.Success {
			t.Error("Expected PDF repair to succeed")
		}
	})

	t.Run("Route AZW4 to RepairPDF", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "test.azw4")
		// AZW4 uses PDF validation - create a valid PDF structure
		createValidPDF(t, tempFile)
		defer os.Remove(tempFile)

		result := RepairFile(tempFile)
		if !result.Success {
			t.Error("Expected AZW4 repair to succeed")
		}
	})

	t.Run("Route MOBI to RepairMOBI", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "test.mobi")
		createValidMOBI(t, tempFile, "BOOKMOBI")
		defer os.Remove(tempFile)

		result := RepairFile(tempFile)
		if !result.Success {
			t.Error("Expected MOBI to return success for valid file")
		}
	})

	t.Run("Route AZW3 to RepairMOBI", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "test.azw3")
		createValidMOBI(t, tempFile, "BOOKMOBI")
		defer os.Remove(tempFile)

		result := RepairFile(tempFile)
		if !result.Success {
			t.Error("Expected AZW3 to return success for valid file")
		}
	})

	t.Run("Unknown file type", func(t *testing.T) {
		tempFile := filepath.Join(os.TempDir(), "test.txt")
		os.WriteFile(tempFile, []byte("text file"), 0644)
		defer os.Remove(tempFile)

		result := RepairFile(tempFile)
		if result.Success {
			t.Error("Expected failure for unknown file type")
		}
	})
}

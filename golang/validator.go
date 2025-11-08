package main

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"os"
)

// ValidationResult represents the result of validating a file
type ValidationResult struct {
	IsValid bool
	Reason  string
}

// ValidateEPUB checks if an EPUB file is corrupted
func ValidateEPUB(filePath string) ValidationResult {
	// Check if file is a valid ZIP
	r, err := zip.OpenReader(filePath)
	if err != nil {
		return ValidationResult{IsValid: false, Reason: "Not a valid ZIP file"}
	}
	defer r.Close()

	var hasMimetype bool
	var hasContainer bool
	var mimetypeContent string
	var firstEntry string
	var firstCompression uint16

	// Check for required files
	for idx, f := range r.File {
		if idx == 0 {
			firstEntry = f.Name
			firstCompression = f.Method
		}
		switch f.Name {
		case "mimetype":
			hasMimetype = true
			// Read mimetype content
			rc, err := f.Open()
			if err != nil {
				return ValidationResult{IsValid: false, Reason: "Cannot read mimetype"}
			}
			content, _ := io.ReadAll(rc)
			rc.Close()
			mimetypeContent = string(content)

		case "META-INF/container.xml":
			hasContainer = true
		}
	}

	if !hasMimetype {
		return ValidationResult{IsValid: false, Reason: "Missing mimetype file"}
	}

	if firstEntry != "mimetype" {
		return ValidationResult{IsValid: false, Reason: "mimetype must be first entry"}
	}

	if firstCompression != zip.Store {
		return ValidationResult{IsValid: false, Reason: "mimetype must be stored uncompressed"}
	}

	if mimetypeContent != "application/epub+zip" {
		return ValidationResult{IsValid: false, Reason: fmt.Sprintf("Invalid mimetype: %s", mimetypeContent)}
	}

	if !hasContainer {
		return ValidationResult{IsValid: false, Reason: "Missing META-INF/container.xml"}
	}

	return ValidationResult{IsValid: true, Reason: "Valid EPUB"}
}

// ValidateMOBI checks if a MOBI file is corrupted
func ValidateMOBI(filePath string) ValidationResult {
	f, err := os.Open(filePath)
	if err != nil {
		return ValidationResult{IsValid: false, Reason: fmt.Sprintf("Cannot open file: %v", err)}
	}
	defer f.Close()

	// Read first 68 bytes
	header := make([]byte, 68)
	n, err := f.Read(header)
	if err != nil || n < 68 {
		return ValidationResult{IsValid: false, Reason: "File too small"}
	}

	// Check for valid MOBI identifier at offset 60
	identifier := string(header[60:68])

	if identifier[:8] != "BOOKMOBI" && identifier[:8] != "TEXtREAd" {
		return ValidationResult{IsValid: false, Reason: fmt.Sprintf("Invalid MOBI identifier: %s", identifier)}
	}

	// Check PalmDB name (first 32 bytes should not be all zeros)
	allZeros := true
	for i := 0; i < 32; i++ {
		if header[i] != 0 {
			allZeros = false
			break
		}
	}

	if allZeros {
		return ValidationResult{IsValid: false, Reason: "Invalid PalmDB header"}
	}

	return ValidationResult{IsValid: true, Reason: "Valid MOBI"}
}

// ValidatePDF checks if a PDF file is corrupted
func ValidatePDF(filePath string) ValidationResult {
	f, err := os.Open(filePath)
	if err != nil {
		return ValidationResult{IsValid: false, Reason: fmt.Sprintf("Cannot open file: %v", err)}
	}
	defer f.Close()

	// Check PDF header
	header := make([]byte, 5)
	n, err := f.Read(header)
	if err != nil || n < 5 {
		return ValidationResult{IsValid: false, Reason: "Cannot read header"}
	}

	if !bytes.HasPrefix(header, []byte("%PDF-")) {
		return ValidationResult{IsValid: false, Reason: "Missing PDF header"}
	}

	// Check file size
	stat, err := f.Stat()
	if err != nil {
		return ValidationResult{IsValid: false, Reason: "Cannot stat file"}
	}

	if stat.Size() < 100 {
		return ValidationResult{IsValid: false, Reason: "File too small to be valid PDF"}
	}

	// Check for EOF marker in last 1KB
	tailSize := int64(1024)
	if stat.Size() < tailSize {
		tailSize = stat.Size()
	}

	_, err = f.Seek(-tailSize, io.SeekEnd)
	if err != nil {
		return ValidationResult{IsValid: false, Reason: "Cannot seek to end"}
	}

	tail := make([]byte, tailSize)
	_, err = f.Read(tail)
	if err != nil {
		return ValidationResult{IsValid: false, Reason: "Cannot read tail"}
	}

	if !bytes.Contains(tail, []byte("%%EOF")) {
		return ValidationResult{IsValid: false, Reason: "Missing %%EOF marker"}
	}

	return ValidationResult{IsValid: true, Reason: "Valid PDF"}
}

// ValidateAZW3 checks if an AZW3 file is corrupted
// AZW3 (KF8) uses similar structure to MOBI but may have different identifiers
func ValidateAZW3(filePath string) ValidationResult {
	// AZW3 files use MOBI/PalmDB structure
	// They typically have "BOOKMOBI" identifier at offset 60
	return ValidateMOBI(filePath)
}

// ValidateAZW4 checks if an AZW4 file is corrupted
// AZW4 is essentially a PDF wrapper for Kindle
func ValidateAZW4(filePath string) ValidationResult {
	// AZW4 files are PDFs, so use PDF validation
	return ValidatePDF(filePath)
}

// ValidateFile validates a file based on its extension
func ValidateFile(filePath string, ext string) ValidationResult {
	switch ext {
	case ".epub":
		return ValidateEPUB(filePath)
	case ".mobi":
		return ValidateMOBI(filePath)
	case ".azw3":
		return ValidateAZW3(filePath)
	case ".azw4":
		return ValidateAZW4(filePath)
	case ".pdf":
		return ValidatePDF(filePath)
	default:
		return ValidationResult{IsValid: true, Reason: "Unknown file type"}
	}
}

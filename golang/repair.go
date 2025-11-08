package main

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// RepairResult represents the result of a repair attempt
type RepairResult struct {
	Success bool
	Message string
	Fixed   bool // Whether the file was actually modified
}

const defaultContainerXML = `<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
`

// RepairFile attempts to repair a corrupted ebook file
func RepairFile(filePath string) RepairResult {
	ext := strings.ToLower(filepath.Ext(filePath))

	switch ext {
	case ".epub":
		return RepairEPUB(filePath)
	case ".pdf", ".azw4":
		return RepairPDF(filePath)
	case ".mobi", ".azw3":
		return RepairMOBI(filePath)
	default:
		return RepairResult{
			Success: false,
			Message: "Unknown file type, cannot repair",
			Fixed:   false,
		}
	}
}

// RepairEPUB attempts to fix corrupted EPUB files
func RepairEPUB(filePath string) RepairResult {
	// First, check what's wrong
	validation := ValidateEPUB(filePath)
	if validation.IsValid {
		return RepairResult{
			Success: true,
			Message: "File is already valid, no repair needed",
			Fixed:   false,
		}
	}

	// Try to open as ZIP
	r, err := zip.OpenReader(filePath)
	if err != nil {
		// ZIP structure is corrupted, cannot repair
		return RepairResult{
			Success: false,
			Message: fmt.Sprintf("Cannot open ZIP structure: %v", err),
			Fixed:   false,
		}
	}
	defer r.Close()

	// Create a backup
	backupPath := filePath + ".backup"
	if err := copyFile(filePath, backupPath); err != nil {
		return RepairResult{
			Success: false,
			Message: fmt.Sprintf("Failed to create backup: %v", err),
			Fixed:   false,
		}
	}

	// Create temporary file for repaired EPUB
	tempPath := filePath + ".repair.tmp"
	tempFile, err := os.Create(tempPath)
	if err != nil {
		_ = os.Remove(backupPath)
		return RepairResult{
			Success: false,
			Message: fmt.Sprintf("Failed to create temp file: %v", err),
			Fixed:   false,
		}
	}
	defer os.Remove(tempPath)

	zipWriter := zip.NewWriter(tempFile)
	defer zipWriter.Close()

	hasContainer := false
	fixed := false
	var entries []zip.FileHeader
	var contents [][]byte
	for _, file := range r.File {
		fh := file.FileHeader
		if strings.EqualFold(fh.Name, "META-INF/container.xml") {
			hasContainer = true
			if fh.Name != "META-INF/container.xml" {
				fh.Name = "META-INF/container.xml"
				fixed = true
			}
		}
		entries = append(entries, fh)
		data, err := readZipFile(file)
		if err != nil {
			tempFile.Close()
			_ = os.Remove(backupPath)
			return RepairResult{Success: false, Message: fmt.Sprintf("Failed to read %s: %v", file.Name, err)}
		}
		contents = append(contents, data)
	}

	// rebuild entries ensuring mimetype first & stored
	var rebuilt []zip.FileHeader
	var rebuiltData [][]byte
	for i, header := range entries {
		if header.Name == "mimetype" {
			continue
		}
		rebuilt = append(rebuilt, header)
		rebuiltData = append(rebuiltData, contents[i])
	}

	if len(rebuilt) == len(entries) { // no mimetype
		head := zip.FileHeader{Name: "mimetype", Method: zip.Store}
		head.SetMode(0644)
		rebuilt = append([]zip.FileHeader{head}, rebuilt...)
		rebuiltData = append([][]byte{[]byte("application/epub+zip")}, rebuiltData...)
		fixed = true
	} else {
		// ensure first entry is stored mimetype
		if len(rebuilt) == len(entries)-1 {
			head := zip.FileHeader{Name: "mimetype", Method: zip.Store}
			head.SetMode(0644)
			rebuilt = append([]zip.FileHeader{head}, rebuilt...)
			rebuiltData = append([][]byte{[]byte("application/epub+zip")}, rebuiltData...)
			fixed = true
		}
	}

	// ensure container
	if !hasContainer {
		head := zip.FileHeader{Name: "META-INF/container.xml", Method: zip.Deflate}
		head.SetMode(0644)
		head.SetModTime(time.Now())
		rebuilt = append(rebuilt, head)
		rebuiltData = append(rebuiltData, []byte(defaultContainerXML))
		fixed = true
	}

	// write rebuilt entries
	for i, header := range rebuilt {
		writer, err := zipWriter.CreateHeader(&header)
		if err != nil {
			return RepairResult{Success: false, Message: fmt.Sprintf("Failed writing %s: %v", header.Name, err)}
		}
		if _, err := writer.Write(rebuiltData[i]); err != nil {
			return RepairResult{Success: false, Message: fmt.Sprintf("Failed writing %s: %v", header.Name, err)}
		}
	}

	zipWriter.Close()
	tempFile.Close()

	if fixed {
		// Replace original with repaired version
		if err := os.Rename(tempPath, filePath); err != nil {
			_ = os.Remove(backupPath)
			return RepairResult{
				Success: false,
				Message: fmt.Sprintf("Failed to replace original file: %v", err),
				Fixed:   false,
			}
		}

		// Verify the repair worked
		newValidation := ValidateEPUB(filePath)
		if newValidation.IsValid {
			_ = os.Remove(backupPath)
			return RepairResult{
				Success: true,
				Message: "EPUB repaired successfully (added missing files)",
				Fixed:   true,
			}
		}

		// Repair didn't work, restore backup
		_ = os.Rename(backupPath, filePath)
		return RepairResult{
			Success: false,
			Message: "Repair attempted but file still invalid",
			Fixed:   false,
		}
	}

	_ = os.Remove(backupPath)
	return RepairResult{
		Success: false,
		Message: "No repairable issues found",
		Fixed:   false,
	}
}

func readZipFile(f *zip.File) ([]byte, error) {
	rc, err := f.Open()
	if err != nil {
		return nil, err
	}
	defer rc.Close()
	return io.ReadAll(rc)
}

// RepairPDF attempts to fix corrupted PDF files
func RepairPDF(filePath string) RepairResult {
	validation := ValidatePDF(filePath)
	if validation.IsValid {
		return RepairResult{
			Success: true,
			Message: "File is already valid, no repair needed",
			Fixed:   false,
		}
	}

	stat, err := os.Stat(filePath)
	if err != nil {
		return RepairResult{
			Success: false,
			Message: fmt.Sprintf("Failed to stat file: %v", err),
			Fixed:   false,
		}
	}

	if stat.Size() < 5 {
		return RepairResult{
			Success: false,
			Message: "File too small to repair",
			Fixed:   false,
		}
	}

	file, err := os.OpenFile(filePath, os.O_RDWR, 0644)
	if err != nil {
		return RepairResult{
			Success: false,
			Message: fmt.Sprintf("Failed to open file: %v", err),
			Fixed:   false,
		}
	}
	defer file.Close()

	header := make([]byte, 5)
	if _, err := file.ReadAt(header, 0); err != nil {
		return RepairResult{
			Success: false,
			Message: fmt.Sprintf("Cannot read header: %v", err),
			Fixed:   false,
		}
	}

	if !bytes.HasPrefix(header, []byte("%PDF-")) {
		return RepairResult{
			Success: false,
			Message: "Missing PDF header, cannot repair",
			Fixed:   false,
		}
	}

	tailSize := int64(1024)
	if stat.Size() < tailSize {
		tailSize = stat.Size()
	}
	tail := make([]byte, tailSize)
	if _, err := file.ReadAt(tail, stat.Size()-tailSize); err != nil {
		return RepairResult{
			Success: false,
			Message: fmt.Sprintf("Cannot read tail: %v", err),
			Fixed:   false,
		}
	}

	if !bytes.Contains(tail, []byte("%%EOF")) {
		backupPath := filePath + ".backup"
		if err := copyFile(filePath, backupPath); err != nil {
			return RepairResult{
				Success: false,
				Message: fmt.Sprintf("Failed to create backup: %v", err),
				Fixed:   false,
			}
		}

		if _, err := file.Seek(0, io.SeekEnd); err != nil {
			_ = os.Remove(backupPath)
			return RepairResult{
				Success: false,
				Message: fmt.Sprintf("Failed to seek to end: %v", err),
				Fixed:   false,
			}
		}

		if _, err := file.Write([]byte("\n%%EOF\n")); err != nil {
			_ = os.Remove(backupPath)
			return RepairResult{
				Success: false,
				Message: fmt.Sprintf("Failed to write repaired file: %v", err),
				Fixed:   false,
			}
		}

		if err := file.Sync(); err != nil {
			_ = os.Remove(backupPath)
			return RepairResult{
				Success: false,
				Message: fmt.Sprintf("Failed to flush repaired file: %v", err),
				Fixed:   false,
			}
		}

		newValidation := ValidatePDF(filePath)
		if newValidation.IsValid {
			_ = os.Remove(backupPath)
			return RepairResult{
				Success: true,
				Message: "PDF repaired successfully (added EOF marker)",
				Fixed:   true,
			}
		}

		_ = os.Rename(backupPath, filePath)
		return RepairResult{
			Success: false,
			Message: "Adding EOF marker didn't fix the file",
			Fixed:   false,
		}
	}

	return RepairResult{
		Success: false,
		Message: "No repairable issues found",
		Fixed:   false,
	}
}

// RepairMOBI attempts to fix corrupted MOBI/AZW3 files
func RepairMOBI(filePath string) RepairResult {
	validation := ValidateMOBI(filePath)
	if validation.IsValid {
		return RepairResult{
			Success: true,
			Message: "File is already valid, no repair needed",
			Fixed:   false,
		}
	}

	// MOBI format is complex and proprietary
	// We can only do limited repairs
	stat, err := os.Stat(filePath)
	if err != nil {
		return RepairResult{
			Success: false,
			Message: fmt.Sprintf("Failed to stat file: %v", err),
			Fixed:   false,
		}
	}

	if stat.Size() < 68 {
		return RepairResult{
			Success: false,
			Message: "File too small to repair",
			Fixed:   false,
		}
	}

	// Check if it's a valid PalmDB header structure
	// MOBI corruption is often too complex to repair automatically
	return RepairResult{
		Success: false,
		Message: "MOBI/AZW3 format is too complex for automatic repair. Consider using Calibre's convert function.",
		Fixed:   false,
	}
}

// Helper functions

func copyFile(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer sourceFile.Close()

	destFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, sourceFile)
	return err
}

func copyZipFile(zipWriter *zip.Writer, file *zip.File) error {
	fileReader, err := file.Open()
	if err != nil {
		return err
	}
	defer fileReader.Close()

	header := file.FileHeader
	writer, err := zipWriter.CreateHeader(&header)
	if err != nil {
		return err
	}

	_, err = io.Copy(writer, fileReader)
	return err
}

func addMimetypeToZip(zipWriter *zip.Writer) error {
	// mimetype must be first file and uncompressed
	header := &zip.FileHeader{
		Name:   "mimetype",
		Method: zip.Store, // No compression
	}

	writer, err := zipWriter.CreateHeader(header)
	if err != nil {
		return err
	}

	_, err = writer.Write([]byte("application/epub+zip"))
	return err
}

func addContainerXMLToZip(zipWriter *zip.Writer) error {
	// Create basic container.xml
	containerXML := `<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>`

	writer, err := zipWriter.Create("META-INF/container.xml")
	if err != nil {
		return err
	}

	_, err = writer.Write([]byte(containerXML))
	return err
}

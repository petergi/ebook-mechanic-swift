package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// GenerateMarkdownReport creates a detailed Markdown report
func GenerateMarkdownReport(result *ScanResult, rootDir, corruptedDir string) (string, error) {
	timestamp := time.Now().Format("2006-01-02_15-04-05")
	reportPath := filepath.Join(rootDir, fmt.Sprintf("ebook_mechanic_report_%s.md", timestamp))

	f, err := os.Create(reportPath)
	if err != nil {
		return "", err
	}
	defer f.Close()

	var sb strings.Builder

	// Header
	sb.WriteString("# EbookMechanic Report\n\n")
	sb.WriteString(fmt.Sprintf("**Report Date:** %s  \n", time.Now().Format("2006-01-02 15:04:05")))
	sb.WriteString(fmt.Sprintf("**Root Directory:** `%s`  \n", rootDir))
	sb.WriteString(fmt.Sprintf("**Corrupted Files Directory:** `%s`\n\n", corruptedDir))
	sb.WriteString("---\n\n")

	// Corruption scan summary
	sb.WriteString("## Corruption Scan Summary\n\n")
	sb.WriteString(fmt.Sprintf("- **Total files scanned:** %d\n", result.TotalFiles))
	sb.WriteString(fmt.Sprintf("- **Total corrupted files:** %d\n\n", len(result.CorruptedFiles)))

	sb.WriteString("### By File Type\n\n")
	sb.WriteString("| File Type | Corrupted | Total | Status |\n")
	sb.WriteString("|-----------|-----------|-------|--------|\n")

	sb.WriteString(fmt.Sprintf("| EPUB | %d | %d | %s |\n",
		result.EPUBCorrupted, result.EPUBTotal, statusMark(result.EPUBCorrupted)))
	sb.WriteString(fmt.Sprintf("| MOBI | %d | %d | %s |\n",
		result.MOBICorrupted, result.MOBITotal, statusMark(result.MOBICorrupted)))
	sb.WriteString(fmt.Sprintf("| AZW3 | %d | %d | %s |\n",
		result.AZW3Corrupted, result.AZW3Total, statusMark(result.AZW3Corrupted)))
	sb.WriteString(fmt.Sprintf("| AZW4 | %d | %d | %s |\n",
		result.AZW4Corrupted, result.AZW4Total, statusMark(result.AZW4Corrupted)))
	sb.WriteString(fmt.Sprintf("| PDF | %d | %d | %s |\n",
		result.PDFCorrupted, result.PDFTotal, statusMark(result.PDFCorrupted)))

	sb.WriteString("\n")

	// Empty folders summary
	sb.WriteString("## Empty Folders Summary\n\n")
	sb.WriteString(fmt.Sprintf("- **Total folders scanned:** %d\n", result.TotalFolders))
	sb.WriteString(fmt.Sprintf("- **Folders with ebooks:** %d\n", result.FoldersWithEbooks))
	sb.WriteString(fmt.Sprintf("- **Folders without ebooks:** %d\n\n", len(result.EmptyFolders)))

	// Corrupted files details
	if len(result.CorruptedFiles) > 0 {
		sb.WriteString("---\n\n")
		sb.WriteString("## Corrupted Files Details\n\n")

		// Group by extension
		epubFiles := filterByExt(result.CorruptedFiles, ".epub")
		mobiFiles := filterByExt(result.CorruptedFiles, ".mobi")
		azw3Files := filterByExt(result.CorruptedFiles, ".azw3")
		azw4Files := filterByExt(result.CorruptedFiles, ".azw4")
		pdfFiles := filterByExt(result.CorruptedFiles, ".pdf")

		if len(epubFiles) > 0 {
			sb.WriteString("### EPUB Files\n\n")
			for _, file := range epubFiles {
				relPath, _ := filepath.Rel(rootDir, file.Path)
				sb.WriteString(fmt.Sprintf("#### `%s`\n\n", relPath))
				sb.WriteString(fmt.Sprintf("- **Size:** %s\n", formatBytes(file.Size)))
				sb.WriteString(fmt.Sprintf("- **Reason:** %s\n\n", file.Reason))
			}
		}

		if len(mobiFiles) > 0 {
			sb.WriteString("### MOBI Files\n\n")
			for _, file := range mobiFiles {
				relPath, _ := filepath.Rel(rootDir, file.Path)
				sb.WriteString(fmt.Sprintf("#### `%s`\n\n", relPath))
				sb.WriteString(fmt.Sprintf("- **Size:** %s\n", formatBytes(file.Size)))
				sb.WriteString(fmt.Sprintf("- **Reason:** %s\n\n", file.Reason))
			}
		}

		if len(azw3Files) > 0 {
			sb.WriteString("### AZW3 Files\n\n")
			for _, file := range azw3Files {
				relPath, _ := filepath.Rel(rootDir, file.Path)
				sb.WriteString(fmt.Sprintf("#### `%s`\n\n", relPath))
				sb.WriteString(fmt.Sprintf("- **Size:** %s\n", formatBytes(file.Size)))
				sb.WriteString(fmt.Sprintf("- **Reason:** %s\n\n", file.Reason))
			}
		}

		if len(azw4Files) > 0 {
			sb.WriteString("### AZW4 Files\n\n")
			for _, file := range azw4Files {
				relPath, _ := filepath.Rel(rootDir, file.Path)
				sb.WriteString(fmt.Sprintf("#### `%s`\n\n", relPath))
				sb.WriteString(fmt.Sprintf("- **Size:** %s\n", formatBytes(file.Size)))
				sb.WriteString(fmt.Sprintf("- **Reason:** %s\n\n", file.Reason))
			}
		}

		if len(pdfFiles) > 0 {
			sb.WriteString("### PDF Files\n\n")
			for _, file := range pdfFiles {
				relPath, _ := filepath.Rel(rootDir, file.Path)
				sb.WriteString(fmt.Sprintf("#### `%s`\n\n", relPath))
				sb.WriteString(fmt.Sprintf("- **Size:** %s\n", formatBytes(file.Size)))
				sb.WriteString(fmt.Sprintf("- **Reason:** %s\n\n", file.Reason))
			}
		}
	} else {
		sb.WriteString("---\n\n")
		sb.WriteString("## ✅ No Corrupted Files Found\n\n")
	}

	// Empty folders details
	if len(result.EmptyFolders) > 0 {
		sb.WriteString("---\n\n")
		sb.WriteString("## Folders Without Ebooks\n\n")

		for _, folder := range result.EmptyFolders {
			relPath, _ := filepath.Rel(rootDir, folder)
			sb.WriteString(fmt.Sprintf("### `%s`\n\n", relPath))

			// List contents if folder still exists
			if entries, err := os.ReadDir(folder); err == nil && len(entries) > 0 {
				sb.WriteString(fmt.Sprintf("**Contents:** %d items\n\n", len(entries)))
				for i, entry := range entries {
					if i >= 5 {
						sb.WriteString(fmt.Sprintf("- *... and %d more items*\n", len(entries)-5))
						break
					}
					icon := "📄"
					if entry.IsDir() {
						icon = "📁"
					}
					sb.WriteString(fmt.Sprintf("- %s `%s`\n", icon, entry.Name()))
				}
				sb.WriteString("\n")
			} else if len(entries) == 0 {
				sb.WriteString("**Status:** Empty folder\n\n")
			}
		}
	} else if result.TotalFolders > 0 {
		sb.WriteString("---\n\n")
		sb.WriteString("## ✅ No Empty Folders Found\n\n")
	}

	sb.WriteString("---\n\n")
	sb.WriteString("*Report generated by EbookMechanic*\n")

	_, err = f.WriteString(sb.String())
	if err != nil {
		return "", err
	}

	return reportPath, nil
}

func statusMark(corrupted int) string {
	if corrupted > 0 {
		return "❌"
	}
	return "✅"
}

func filterByExt(files []CorruptedFile, ext string) []CorruptedFile {
	var result []CorruptedFile
	for _, file := range files {
		if strings.ToLower(filepath.Ext(file.Path)) == ext {
			result = append(result, file)
		}
	}
	return result
}

func formatBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

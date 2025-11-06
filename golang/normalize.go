package main

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"golang.org/x/net/html"
)

// NormalizeResult represents the result of EPUB normalization
type NormalizeResult struct {
	Success      bool
	Message      string
	Modified     bool
	ChangesCount int
	Details      []string
}

// EPUBManifest represents the OPF manifest structure
type EPUBManifest struct {
	XMLName   xml.Name        `xml:"package"`
	Namespace string          `xml:"xmlns,attr"`
	Version   string          `xml:"version,attr"`
	UniqueID  string          `xml:"unique-identifier,attr"`
	Metadata  EPUBMetadata    `xml:"metadata"`
	Manifest  EPUBManifestElt `xml:"manifest"`
	Spine     EPUBSpine       `xml:"spine"`
}

type EPUBMetadata struct {
	XMLName xml.Name `xml:"metadata"`
	Items   []xml.Token
}

type EPUBManifestElt struct {
	XMLName xml.Name      `xml:"manifest"`
	Items   []EPUBManItem `xml:"item"`
}

type EPUBManItem struct {
	ID        string `xml:"id,attr"`
	Href      string `xml:"href,attr"`
	MediaType string `xml:"media-type,attr"`
}

type EPUBSpine struct {
	XMLName xml.Name       `xml:"spine"`
	TOC     string         `xml:"toc,attr"`
	Items   []EPUBSpineRef `xml:"itemref"`
}

type EPUBSpineRef struct {
	IDRef string `xml:"idref,attr"`
}

// NormalizeEPUB applies Sigil-style normalization to an EPUB file
func NormalizeEPUB(filePath string, keepBackups bool) NormalizeResult {
	// First validate the EPUB
	validation := ValidateEPUB(filePath)
	if !validation.IsValid {
		return NormalizeResult{
			Success: false,
			Message: fmt.Sprintf("Cannot normalize invalid EPUB: %s", validation.Reason),
			Modified: false,
		}
	}

	// Create backup
	backupPath := filePath + ".backup"
	if err := copyFile(filePath, backupPath); err != nil {
		return NormalizeResult{
			Success: false,
			Message: fmt.Sprintf("Failed to create backup: %v", err),
			Modified: false,
		}
	}

	// Open the EPUB (ZIP file)
	r, err := zip.OpenReader(filePath)
	if err != nil {
		os.Remove(backupPath)
		return NormalizeResult{
			Success: false,
			Message: fmt.Sprintf("Failed to open EPUB: %v", err),
			Modified: false,
		}
	}
	defer r.Close()

	// Create temporary file for the normalized EPUB
	tempFile, err := os.CreateTemp(filepath.Dir(filePath), "epub_normalize_*.zip")
	if err != nil {
		r.Close()
		os.Remove(backupPath)
		return NormalizeResult{
			Success: false,
			Message: fmt.Sprintf("Failed to create temp file: %v", err),
			Modified: false,
		}
	}
	defer os.Remove(tempFile.Name())

	// Create new ZIP writer
	w := zip.NewWriter(tempFile)

	var changes []string
	changesCount := 0
	manifestItems := make(map[string]EPUBManItem)
	fileRenames := make(map[string]string) // oldPath -> newPath

	// First pass: identify OPF file and collect manifest items
	for _, f := range r.File {
		if strings.HasSuffix(f.Name, ".opf") {
			// Parse OPF to get manifest
			rc, err := f.Open()
			if err != nil {
				continue
			}
			content, err := io.ReadAll(rc)
			rc.Close()
			if err != nil {
				continue
			}

			var manifest EPUBManifest
			if err := xml.Unmarshal(content, &manifest); err == nil {
				for _, item := range manifest.Manifest.Items {
					manifestItems[item.Href] = item
				}
			}
			break
		}
	}

	// Second pass: normalize files
	for _, f := range r.File {
		var newContent []byte
		var modified bool
		var fileChanges []string

		// Determine if file should be renamed for standard extensions
		newFileName := normalizeFileName(f.Name)
		shouldRename := newFileName != f.Name

		if shouldRename {
			fileRenames[f.Name] = newFileName
			fileChanges = append(fileChanges, fmt.Sprintf("Renamed: %s -> %s", f.Name, newFileName))
		}

		rc, err := f.Open()
		if err != nil {
			continue
		}
		originalContent, err := io.ReadAll(rc)
		rc.Close()
		if err != nil {
			continue
		}

		// Apply normalization based on file type
		switch {
		case f.Name == "mimetype":
			// Ensure mimetype is correct
			expectedMimetype := "application/epub+zip"
			if string(originalContent) != expectedMimetype {
				newContent = []byte(expectedMimetype)
				modified = true
				fileChanges = append(fileChanges, "Fixed mimetype content")
			} else {
				newContent = originalContent
			}

		case strings.HasSuffix(f.Name, ".opf"):
			// Normalize OPF file
			newContent, fileChanges = normalizeOPF(originalContent, manifestItems, fileRenames)
			modified = len(fileChanges) > 0

		case strings.HasSuffix(f.Name, ".html") || strings.HasSuffix(f.Name, ".xhtml") || strings.HasSuffix(f.Name, ".htm"):
			// Normalize HTML files
			newContent, fileChanges = normalizeHTML(originalContent)
			modified = len(fileChanges) > 0

		case strings.HasSuffix(f.Name, ".css"):
			// Normalize CSS files
			newContent, fileChanges = normalizeCSS(originalContent)
			modified = len(fileChanges) > 0

		default:
			// Copy other files as-is
			newContent = originalContent
		}

		// Determine final filename to use
		finalFileName := newFileName

		// Write to new ZIP
		writer, err := w.Create(finalFileName)
		if err != nil {
			continue
		}

		if modified || shouldRename {
			writer.Write(newContent)
			for _, change := range fileChanges {
				changes = append(changes, fmt.Sprintf("%s: %s", f.Name, change))
			}
			changesCount++
		} else {
			writer.Write(originalContent)
		}
	}

	// Close ZIP writer
	if err := w.Close(); err != nil {
		tempFile.Close()
		os.Remove(backupPath)
		return NormalizeResult{
			Success: false,
			Message: fmt.Sprintf("Failed to finalize normalized EPUB: %v", err),
			Modified: false,
		}
	}
	tempFile.Close()

	// Replace original file with normalized version if changes were made
	if changesCount > 0 {
		if err := os.Rename(tempFile.Name(), filePath); err != nil {
			os.Remove(backupPath)
			return NormalizeResult{
				Success: false,
				Message: fmt.Sprintf("Failed to replace original file: %v", err),
				Modified: false,
			}
		}

		result := NormalizeResult{
			Success:      true,
			Message:      "EPUB successfully normalized",
			Modified:     true,
			ChangesCount: changesCount,
			Details:      changes,
		}

		// Handle backup cleanup based on keepBackups flag
		if !keepBackups {
			os.Remove(backupPath)
			result.Details = append(result.Details, "Backup file removed after successful normalization")
		} else {
			result.Details = append(result.Details, fmt.Sprintf("Backup preserved at: %s", backupPath))
		}

		return result
	}

	// No changes needed, remove backup
	os.Remove(backupPath)
	return NormalizeResult{
		Success: true,
		Message: "EPUB is already normalized",
		Modified: false,
	}
}

// normalizeOPF normalizes the OPF package file according to Sigil standards
func normalizeOPF(content []byte, manifestItems map[string]EPUBManItem, fileRenames map[string]string) ([]byte, []string) {
	var changes []string

	// Parse the OPF
	var manifest EPUBManifest
	if err := xml.Unmarshal(content, &manifest); err != nil {
		return content, changes
	}

	modified := false

	// Normalize manifest IDs based on filenames
	for i, item := range manifest.Manifest.Items {
		// Check if this file was renamed
		finalHref := item.Href
		if newName, wasRenamed := fileRenames[item.Href]; wasRenamed {
			finalHref = newName
			manifest.Manifest.Items[i].Href = finalHref
			modified = true
			changes = append(changes, fmt.Sprintf("Updated href due to rename: %s -> %s", item.Href, finalHref))
		}

		// Generate ID from final filename
		normalizedID := generateIDFromFilename(finalHref)
		if item.ID != normalizedID {
			manifest.Manifest.Items[i].ID = normalizedID
			modified = true
			changes = append(changes, fmt.Sprintf("Rebased manifest ID: %s -> %s", item.ID, normalizedID))
		}

		// Ensure proper media types
		correctMediaType := getCorrectMediaType(finalHref)
		if item.MediaType != correctMediaType {
			manifest.Manifest.Items[i].MediaType = correctMediaType
			modified = true
			changes = append(changes, fmt.Sprintf("Fixed media type for %s: %s -> %s", finalHref, item.MediaType, correctMediaType))
		}
	}

	// Sort manifest items for consistency
	sort.Slice(manifest.Manifest.Items, func(i, j int) bool {
		return manifest.Manifest.Items[i].Href < manifest.Manifest.Items[j].Href
	})

	if modified {
		// Marshal back to XML with proper formatting
		output, err := xml.MarshalIndent(manifest, "", "  ")
		if err != nil {
			return content, changes
		}

		// Add XML declaration
		result := []byte(xml.Header + string(output))
		return result, changes
	}

	return content, changes
}

// normalizeHTML normalizes HTML/XHTML files according to Sigil standards
func normalizeHTML(content []byte) ([]byte, []string) {
	var changes []string

	// Parse HTML
	doc, err := html.Parse(bytes.NewReader(content))
	if err != nil {
		return content, changes
	}

	modified := false

	// Apply HTML normalization
	var normalizeNode func(*html.Node)
	normalizeNode = func(n *html.Node) {
		if n.Type == html.ElementNode {
			// Normalize tag names to lowercase
			if n.Data != strings.ToLower(n.Data) {
				n.Data = strings.ToLower(n.Data)
				modified = true
			}

			// Normalize attributes
			for i, attr := range n.Attr {
				// Normalize attribute names to lowercase
				if attr.Key != strings.ToLower(attr.Key) {
					n.Attr[i].Key = strings.ToLower(attr.Key)
					modified = true
				}

				// Clean up common attribute values
				switch attr.Key {
				case "class":
					// Remove extra whitespace in class attributes
					cleanClass := strings.Join(strings.Fields(attr.Val), " ")
					if attr.Val != cleanClass {
						n.Attr[i].Val = cleanClass
						modified = true
					}
				}
			}

			// Sort attributes for consistency
			sort.Slice(n.Attr, func(i, j int) bool {
				return n.Attr[i].Key < n.Attr[j].Key
			})
		}

		// Recursively process child nodes
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			normalizeNode(c)
		}
	}

	normalizeNode(doc)

	if modified {
		// Render the normalized HTML
		var buf bytes.Buffer
		html.Render(&buf, doc)
		changes = append(changes, "Prettified and normalized HTML structure")
		return buf.Bytes(), changes
	}

	return content, changes
}

// normalizeCSS performs basic CSS normalization
func normalizeCSS(content []byte) ([]byte, []string) {
	var changes []string
	text := string(content)
	original := text

	// Remove excessive whitespace
	re := regexp.MustCompile(`\s+`)
	text = re.ReplaceAllString(text, " ")

	// Format CSS rules (basic formatting)
	re = regexp.MustCompile(`\s*{\s*`)
	text = re.ReplaceAllString(text, " {\n  ")

	re = regexp.MustCompile(`;\s*`)
	text = re.ReplaceAllString(text, ";\n  ")

	re = regexp.MustCompile(`\s*}\s*`)
	text = re.ReplaceAllString(text, "\n}\n")

	// Remove trailing whitespace from lines
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		lines[i] = strings.TrimRight(line, " \t")
	}
	text = strings.Join(lines, "\n")

	if text != original {
		changes = append(changes, "Prettified CSS formatting")
		return []byte(text), changes
	}

	return content, changes
}

// generateIDFromFilename creates a normalized ID from a filename
func generateIDFromFilename(href string) string {
	// Remove path and extension
	base := filepath.Base(href)
	ext := filepath.Ext(base)
	name := strings.TrimSuffix(base, ext)

	// Normalize: lowercase, replace non-alphanumeric with underscore
	re := regexp.MustCompile(`[^a-zA-Z0-9]+`)
	normalized := re.ReplaceAllString(name, "_")
	normalized = strings.Trim(normalized, "_")
	normalized = strings.ToLower(normalized)

	// Ensure it starts with a letter
	if len(normalized) > 0 && !regexp.MustCompile(`^[a-z]`).MatchString(normalized) {
		normalized = "id_" + normalized
	}

	// Add suffix based on file type
	switch strings.ToLower(ext) {
	case ".html", ".xhtml", ".htm":
		normalized += "_html"
	case ".css":
		normalized += "_css"
	case ".js":
		normalized += "_js"
	case ".jpg", ".jpeg":
		normalized += "_jpg"
	case ".png":
		normalized += "_png"
	case ".gif":
		normalized += "_gif"
	case ".svg":
		normalized += "_svg"
	default:
		// For other files, use the extension as suffix
		if ext != "" {
			normalized += "_" + strings.TrimPrefix(strings.ToLower(ext), ".")
		}
	}

	return normalized
}

// getCorrectMediaType returns the correct media type for a file based on its extension
func getCorrectMediaType(href string) string {
	ext := strings.ToLower(filepath.Ext(href))

	switch ext {
	case ".html", ".xhtml", ".htm":
		return "application/xhtml+xml"
	case ".css":
		return "text/css"
	case ".js":
		return "text/javascript"
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".gif":
		return "image/gif"
	case ".svg":
		return "image/svg+xml"
	case ".ttf":
		return "font/ttf"
	case ".otf":
		return "font/otf"
	case ".woff":
		return "font/woff"
	case ".woff2":
		return "font/woff2"
	case ".xml":
		return "application/xml"
	case ".ncx":
		return "application/x-dtbncx+xml"
	default:
		return "application/octet-stream"
	}
}

// normalizeFileName normalizes file extensions to standard formats
func normalizeFileName(fileName string) string {
	dir := filepath.Dir(fileName)
	base := filepath.Base(fileName)
	ext := strings.ToLower(filepath.Ext(base))
	nameWithoutExt := strings.TrimSuffix(base, filepath.Ext(base))

	// Normalize extensions to standard formats
	switch ext {
	case ".htm":
		// Convert .htm to .xhtml
		if dir == "." {
			return nameWithoutExt + ".xhtml"
		}
		return filepath.Join(dir, nameWithoutExt + ".xhtml")
	case ".jpeg":
		// Convert .jpeg to .jpg for consistency
		if dir == "." {
			return nameWithoutExt + ".jpg"
		}
		return filepath.Join(dir, nameWithoutExt + ".jpg")
	default:
		// No change needed
		return fileName
	}
}

// cleanExistingBackups removes all .backup files in the given directory
func cleanExistingBackups(directory string) error {
	return filepath.Walk(directory, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Continue on errors
		}

		// Skip directories
		if info.IsDir() {
			return nil
		}

		// Remove .backup files
		if strings.HasSuffix(path, ".backup") {
			fmt.Printf("Removing backup: %s\n", path)
			if err := os.Remove(path); err != nil {
				fmt.Printf("Warning: Failed to remove %s: %v\n", path, err)
			}
		}

		return nil
	})
}

package main

import (
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// CorruptedFile represents a corrupted ebook file
type CorruptedFile struct {
	Path   string
	Reason string
	Size   int64
}

// ScanResult holds the results of scanning operations
type ScanResult struct {
	TotalFiles        int
	CorruptedFiles    []CorruptedFile
	EPUBTotal         int
	EPUBCorrupted     int
	MOBITotal         int
	MOBICorrupted     int
	AZW3Total         int
	AZW3Corrupted     int
	AZW4Total         int
	AZW4Corrupted     int
	PDFTotal          int
	PDFCorrupted      int
	EmptyFolders      []string
	TotalFolders      int
	FoldersWithEbooks int
}

// FileScanner handles file scanning operations
type FileScanner struct {
	RootDir          string
	CorruptedDir     string
	EbookExtensions  map[string]bool
	Result           *ScanResult
	mu               sync.Mutex
	progressCallback func(current, total int, item string)
}

// NewFileScanner creates a new file scanner
func NewFileScanner(rootDir, corruptedDir string) *FileScanner {
	return &FileScanner{
		RootDir:      rootDir,
		CorruptedDir: corruptedDir,
		EbookExtensions: map[string]bool{
			".epub": true,
			".mobi": true,
			".azw3": true,
			".azw4": true,
			".pdf":  true,
		},
		Result: &ScanResult{
			CorruptedFiles: make([]CorruptedFile, 0),
			EmptyFolders:   make([]string, 0),
		},
	}
}

// SetProgressCallback sets the callback for progress updates
func (fs *FileScanner) SetProgressCallback(callback func(current, total int, item string)) {
	fs.progressCallback = callback
}

// ScanForCorruption scans for corrupted ebook files
func (fs *FileScanner) ScanForCorruption() error {
	// First pass: count files
	var allFiles []string
	corruptedDirAbs := filepath.Join(fs.RootDir, fs.CorruptedDir)

	err := filepath.Walk(fs.RootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Skip errors
		}

		// Skip corrupted directory
		if strings.HasPrefix(path, corruptedDirAbs) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		if !info.IsDir() {
			ext := strings.ToLower(filepath.Ext(path))
			if fs.EbookExtensions[ext] {
				allFiles = append(allFiles, path)
			}
		}
		return nil
	})

	if err != nil {
		return err
	}

	// Second pass: validate files
	for i, filePath := range allFiles {
		ext := strings.ToLower(filepath.Ext(filePath))

		// Update statistics
		fs.mu.Lock()
		fs.Result.TotalFiles++
		switch ext {
		case ".epub":
			fs.Result.EPUBTotal++
		case ".mobi":
			fs.Result.MOBITotal++
		case ".azw3":
			fs.Result.AZW3Total++
		case ".azw4":
			fs.Result.AZW4Total++
		case ".pdf":
			fs.Result.PDFTotal++
		}
		fs.mu.Unlock()

		// Validate file
		result := ValidateFile(filePath, ext)

		if !result.IsValid {
			stat, _ := os.Stat(filePath)
			corrupted := CorruptedFile{
				Path:   filePath,
				Reason: result.Reason,
				Size:   stat.Size(),
			}

			fs.mu.Lock()
			fs.Result.CorruptedFiles = append(fs.Result.CorruptedFiles, corrupted)
			switch ext {
			case ".epub":
				fs.Result.EPUBCorrupted++
			case ".mobi":
				fs.Result.MOBICorrupted++
			case ".azw3":
				fs.Result.AZW3Corrupted++
			case ".azw4":
				fs.Result.AZW4Corrupted++
			case ".pdf":
				fs.Result.PDFCorrupted++
			}
			fs.mu.Unlock()
		}

		// Progress callback
		if fs.progressCallback != nil {
			fs.progressCallback(i+1, len(allFiles), filepath.Base(filePath))
		}
	}

	return nil
}

// hasEbooks checks if a directory contains any ebook files
func (fs *FileScanner) hasEbooks(dirPath string) bool {
	hasEbook := false

	_ = filepath.Walk(dirPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}

		if !info.IsDir() {
			ext := strings.ToLower(filepath.Ext(path))
			if fs.EbookExtensions[ext] {
				hasEbook = true
				return filepath.SkipAll
			}
		}
		return nil
	})

	return hasEbook
}

// ScanForEmptyFolders scans for folders without ebook files
func (fs *FileScanner) ScanForEmptyFolders() error {
	var allDirs []string
	corruptedDirAbs := filepath.Join(fs.RootDir, fs.CorruptedDir)

	// Collect all directories bottom-up
	err := filepath.Walk(fs.RootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}

		// Skip corrupted directory
		if strings.HasPrefix(path, corruptedDirAbs) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		if info.IsDir() && path != fs.RootDir {
			allDirs = append(allDirs, path)
		}
		return nil
	})

	if err != nil {
		return err
	}

	// Reverse to process bottom-up
	for i := len(allDirs)/2 - 1; i >= 0; i-- {
		opp := len(allDirs) - 1 - i
		allDirs[i], allDirs[opp] = allDirs[opp], allDirs[i]
	}

	fs.Result.TotalFolders = len(allDirs)

	// Check each directory
	for i, dirPath := range allDirs {
		if fs.hasEbooks(dirPath) {
			fs.mu.Lock()
			fs.Result.FoldersWithEbooks++
			fs.mu.Unlock()
		} else {
			fs.mu.Lock()
			fs.Result.EmptyFolders = append(fs.Result.EmptyFolders, dirPath)
			fs.mu.Unlock()
		}

		// Progress callback
		if fs.progressCallback != nil {
			fs.progressCallback(i+1, len(allDirs), filepath.Base(dirPath))
		}
	}

	return nil
}

// MoveCorruptedFiles moves corrupted files to the corrupted directory
func (fs *FileScanner) MoveCorruptedFiles() error {
	corruptedDirAbs := filepath.Join(fs.RootDir, fs.CorruptedDir)

	// Create corrupted directory
	if err := os.MkdirAll(corruptedDirAbs, 0755); err != nil {
		return err
	}

	for i, corrupted := range fs.Result.CorruptedFiles {
		relPath, err := filepath.Rel(fs.RootDir, corrupted.Path)
		if err != nil {
			continue
		}

		destPath := filepath.Join(corruptedDirAbs, relPath)

		// Create destination directory
		destDir := filepath.Dir(destPath)
		if err := os.MkdirAll(destDir, 0755); err != nil {
			continue
		}

		// Move file
		if err := os.Rename(corrupted.Path, destPath); err != nil {
			continue
		}

		// Progress callback
		if fs.progressCallback != nil {
			fs.progressCallback(i+1, len(fs.Result.CorruptedFiles), filepath.Base(corrupted.Path))
		}
	}

	return nil
}

// DeleteEmptyFolders deletes folders without ebooks
func (fs *FileScanner) DeleteEmptyFolders() error {
	for i, folderPath := range fs.Result.EmptyFolders {
		os.RemoveAll(folderPath)

		// Progress callback
		if fs.progressCallback != nil {
			fs.progressCallback(i+1, len(fs.Result.EmptyFolders), filepath.Base(folderPath))
		}
	}

	return nil
}

// ScanForAllEPUBs finds all EPUB files in the directory tree for normalization
func (fs *FileScanner) ScanForAllEPUBs() []string {
	var epubFiles []string

	err := filepath.Walk(fs.RootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}

		// Skip corrupted directory
		if info.IsDir() && filepath.Base(path) == fs.CorruptedDir {
			return filepath.SkipDir
		}

		// Check if it's an EPUB file
		if !info.IsDir() && strings.ToLower(filepath.Ext(path)) == ".epub" {
			epubFiles = append(epubFiles, path)
		}

		return nil
	})

	if err != nil {
		return []string{}
	}

	return epubFiles
}

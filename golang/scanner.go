package main

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
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
	EPUBPaths         []string
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
	epubCacheDirty   bool
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
			EPUBPaths:      make([]string, 0),
		},
		epubCacheDirty: true,
	}
}

// SetProgressCallback sets the callback for progress updates
func (fs *FileScanner) SetProgressCallback(callback func(current, total int, item string)) {
	fs.progressCallback = callback
}

// ScanForCorruption scans for corrupted ebook files
func (fs *FileScanner) ScanForCorruption() error {
	fs.Result = &ScanResult{
		CorruptedFiles: make([]CorruptedFile, 0),
		EmptyFolders:   make([]string, 0),
		EPUBPaths:      make([]string, 0),
	}
	fs.mu.Lock()
	fs.epubCacheDirty = true
	fs.mu.Unlock()

	type validationJob struct {
		path string
		ext  string
		size int64
	}

	corruptedDirAbs := filepath.Join(fs.RootDir, fs.CorruptedDir)
	workerCount := runtime.NumCPU()
	if workerCount < 1 {
		workerCount = 1
	}
	jobs := make(chan validationJob, workerCount*4)
	var discovered atomic.Int64
	var processed atomic.Int64

	var wg sync.WaitGroup
	for i := 0; i < workerCount; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for job := range jobs {
				fs.mu.Lock()
				fs.Result.TotalFiles++
				switch job.ext {
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

				result := ValidateFile(job.path, job.ext)

				if !result.IsValid {
					corrupted := CorruptedFile{
						Path:   job.path,
						Reason: result.Reason,
						Size:   job.size,
					}

					fs.mu.Lock()
					fs.Result.CorruptedFiles = append(fs.Result.CorruptedFiles, corrupted)
					switch job.ext {
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

				if fs.progressCallback != nil {
					current := int(processed.Add(1))
					total := int(discovered.Load())
					fs.progressCallback(current, total, filepath.Base(job.path))
				}
			}
		}()
	}

	walkErr := filepath.WalkDir(fs.RootDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}

		if strings.HasPrefix(path, corruptedDirAbs) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		if d.IsDir() {
			return nil
		}

		ext := strings.ToLower(filepath.Ext(path))
		if !fs.EbookExtensions[ext] {
			return nil
		}

		info, infoErr := d.Info()
		if infoErr != nil {
			return nil
		}

		discovered.Add(1)
		if ext == ".epub" {
			fs.mu.Lock()
			fs.Result.EPUBPaths = append(fs.Result.EPUBPaths, path)
			fs.mu.Unlock()
		}

		jobs <- validationJob{path: path, ext: ext, size: info.Size()}
		return nil
	})

	close(jobs)
	wg.Wait()

	fs.mu.Lock()
	fs.epubCacheDirty = false
	fs.mu.Unlock()

	return walkErr
}

// ScanForEmptyFolders scans for folders without ebook files
func (fs *FileScanner) ScanForEmptyFolders() error {
	corruptedDirAbs := filepath.Join(fs.RootDir, fs.CorruptedDir)
	dirs := make([]string, 0)
	parents := make(map[string]string)
	dirHasEbooks := make(map[string]bool)

	err := filepath.WalkDir(fs.RootDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}

		if strings.HasPrefix(path, corruptedDirAbs) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		if d.IsDir() {
			if path != fs.RootDir {
				dirs = append(dirs, path)
				parents[path] = filepath.Dir(path)
			}
			return nil
		}

		ext := strings.ToLower(filepath.Ext(path))
		if fs.EbookExtensions[ext] {
			dir := filepath.Dir(path)
			dirHasEbooks[dir] = true
		}

		return nil
	})

	if err != nil {
		return err
	}

	fs.mu.Lock()
	fs.Result.EmptyFolders = fs.Result.EmptyFolders[:0]
	fs.Result.FoldersWithEbooks = 0
	fs.Result.TotalFolders = len(dirs)
	fs.mu.Unlock()

	for i := len(dirs) - 1; i >= 0; i-- {
		dirPath := dirs[i]
		if dirHasEbooks[dirPath] {
			if parent, ok := parents[dirPath]; ok {
				dirHasEbooks[parent] = true
			}
			fs.mu.Lock()
			fs.Result.FoldersWithEbooks++
			fs.mu.Unlock()
		} else {
			fs.mu.Lock()
			fs.Result.EmptyFolders = append(fs.Result.EmptyFolders, dirPath)
			fs.mu.Unlock()
		}

		if fs.progressCallback != nil {
			processed := len(dirs) - i
			fs.progressCallback(processed, len(dirs), filepath.Base(dirPath))
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

	fs.markEPUBCacheDirty()

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
	if cached := fs.snapshotEPUBCache(); cached != nil {
		return cached
	}

	var epubFiles []string
	err := filepath.WalkDir(fs.RootDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}

		if d.IsDir() && filepath.Base(path) == fs.CorruptedDir {
			return filepath.SkipDir
		}

		if !d.IsDir() && strings.ToLower(filepath.Ext(path)) == ".epub" {
			epubFiles = append(epubFiles, path)
		}

		return nil
	})

	if err != nil {
		return []string{}
	}

	fs.mu.Lock()
	fs.Result.EPUBPaths = append(fs.Result.EPUBPaths[:0], epubFiles...)
	fs.epubCacheDirty = false
	fs.mu.Unlock()

	return epubFiles
}

func (fs *FileScanner) snapshotEPUBCache() []string {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	if fs.epubCacheDirty || fs.Result == nil || len(fs.Result.EPUBPaths) == 0 {
		return nil
	}
	return append([]string(nil), fs.Result.EPUBPaths...)
}

func (fs *FileScanner) markEPUBCacheDirty() {
	fs.mu.Lock()
	fs.epubCacheDirty = true
	if fs.Result != nil {
		fs.Result.EPUBPaths = fs.Result.EPUBPaths[:0]
	}
	fs.mu.Unlock()
}

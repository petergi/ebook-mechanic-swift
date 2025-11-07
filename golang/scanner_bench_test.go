package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

func BenchmarkScanForCorruption(b *testing.B) {
	authors := envInt("EBOOK_BENCH_AUTHORS", 20)
	booksPerAuthor := envInt("EBOOK_BENCH_BOOKS", 25)

	root := buildBenchmarkLibrary(b, authors, booksPerAuthor)
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		scanner := NewFileScanner(root, "CORRUPTED")
		if err := scanner.ScanForCorruption(); err != nil {
			b.Fatalf("scan failed: %v", err)
		}
	}
}

func buildBenchmarkLibrary(b *testing.B, authors, booksPerAuthor int) string {
	b.Helper()
	root := b.TempDir()

	for author := 0; author < authors; author++ {
		authorDir := filepath.Join(root, fmt.Sprintf("author-%03d", author))
		if err := os.MkdirAll(authorDir, 0o755); err != nil {
			b.Fatalf("mkdir failed: %v", err)
		}

		for idx := 0; idx < booksPerAuthor; idx++ {
			base := fmt.Sprintf("book-%03d", idx)
			epubPath := filepath.Join(authorDir, base+".epub")
			pdfPath := filepath.Join(authorDir, base+".pdf")
			mobiPath := filepath.Join(authorDir, base+".mobi")

			createValidEPUB(b, epubPath)
			createValidPDF(b, pdfPath)
			createValidMOBI(b, mobiPath, "BOOKMOBI")

			if idx%5 == 0 {
				// sprinkle a corrupted PDF to keep workloads mixed
				corruptPDF := filepath.Join(authorDir, base+"-broken.pdf")
				createPDFWithoutEOF(b, corruptPDF)
			}
		}
	}

	return root
}

func envInt(key string, fallback int) int {
	if val := os.Getenv(key); val != "" {
		if parsed, err := strconv.Atoi(val); err == nil && parsed > 0 {
			return parsed
		}
	}
	return fallback
}

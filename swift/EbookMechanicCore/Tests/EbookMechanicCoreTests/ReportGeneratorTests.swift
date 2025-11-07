import XCTest
@testable import EbookMechanicCore

final class ReportGeneratorTests: XCTestCase {
    func testReportGenerationProducesFile() throws {
        let tempDir = try temporaryRoot()

        let result = ScanResult(
            totalFiles: 2,
            corruptedFiles: [
                CorruptedFile(url: tempDir.appendingPathComponent("Broken/book1.epub"), reason: "Missing mimetype file", size: 5120),
                CorruptedFile(url: tempDir.appendingPathComponent("Broken/book2.pdf"), reason: "Missing %%EOF marker", size: 8096),
            ],
            breakdowns: [
                .epub: FormatBreakdown(total: 1, corrupted: 1),
                .pdf: FormatBreakdown(total: 1, corrupted: 1),
            ],
            emptyFolders: [tempDir.appendingPathComponent("Empty")],
            totalFolders: 3,
            foldersWithEbooks: 2
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "report.md")

        XCTAssertTrue(FileManager.default.fileExists(atPath: reportURL.path))
        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("## Corrupted Files Details"))
        XCTAssertTrue(contents.contains("book1.epub"))
        XCTAssertTrue(contents.contains("book2.pdf"))
        XCTAssertTrue(contents.contains("Folders Without Ebooks"))

        // Ensure file can be overwritten without throwing.
        let secondURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "report.md")
        XCTAssertEqual(secondURL, reportURL)
    }

    // MARK: - Empty Result Tests

    func testReportWithEmptyScanResult() throws {
        let tempDir = try temporaryRoot()
        let result = ScanResult()

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "empty.md")

        XCTAssertTrue(FileManager.default.fileExists(atPath: reportURL.path))
        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("No corrupted files found"))
        XCTAssertTrue(contents.contains("No empty folders found"))
    }

    func testReportWithNoCorruptedFiles() throws {
        let tempDir = try temporaryRoot()
        let result = ScanResult(
            totalFiles: 10,
            emptyFolders: [tempDir.appendingPathComponent("Empty1"), tempDir.appendingPathComponent("Empty2")],
            totalFolders: 5,
            foldersWithEbooks: 3
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "no_corruption.md")

        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("No corrupted files found"))
        XCTAssertTrue(contents.contains("Empty1"))
        XCTAssertTrue(contents.contains("Empty2"))
    }

    func testReportWithNoEmptyFolders() throws {
        let tempDir = try temporaryRoot()
        let result = ScanResult(
            totalFiles: 10,
            corruptedFiles: [
                CorruptedFile(url: tempDir.appendingPathComponent("bad.epub"), reason: "Invalid", size: 1024)
            ],
            totalFolders: 5,
            foldersWithEbooks: 5
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "no_empty.md")

        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("bad.epub"))
        XCTAssertTrue(contents.contains("No empty folders found"))
    }

    // MARK: - Format Breakdown Tests

    func testReportWithAllFileTypes() throws {
        let tempDir = try temporaryRoot()
        let result = ScanResult(
            totalFiles: 10,
            corruptedFiles: [
                CorruptedFile(url: tempDir.appendingPathComponent("book.epub"), reason: "Bad EPUB", size: 1024),
                CorruptedFile(url: tempDir.appendingPathComponent("book.mobi"), reason: "Bad MOBI", size: 2048),
                CorruptedFile(url: tempDir.appendingPathComponent("book.azw3"), reason: "Bad AZW3", size: 3072),
                CorruptedFile(url: tempDir.appendingPathComponent("book.azw4"), reason: "Bad AZW4", size: 4096),
                CorruptedFile(url: tempDir.appendingPathComponent("book.pdf"), reason: "Bad PDF", size: 5120),
            ],
            breakdowns: [
                .epub: FormatBreakdown(total: 2, corrupted: 1),
                .mobi: FormatBreakdown(total: 2, corrupted: 1),
                .azw3: FormatBreakdown(total: 2, corrupted: 1),
                .azw4: FormatBreakdown(total: 2, corrupted: 1),
                .pdf: FormatBreakdown(total: 2, corrupted: 1),
            ],
            totalFolders: 5,
            foldersWithEbooks: 5
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "all_types.md")

        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("book.epub"))
        XCTAssertTrue(contents.contains("book.mobi"))
        XCTAssertTrue(contents.contains("book.azw3"))
        XCTAssertTrue(contents.contains("book.azw4"))
        XCTAssertTrue(contents.contains("book.pdf"))
    }

    func testReportWithMultipleCorruptedFilesShowsBreakdown() throws {
        let tempDir = try temporaryRoot()
        let result = ScanResult(
            totalFiles: 20,
            corruptedFiles: [
                CorruptedFile(url: tempDir.appendingPathComponent("book1.epub"), reason: "Bad", size: 1024),
                CorruptedFile(url: tempDir.appendingPathComponent("book2.epub"), reason: "Bad", size: 1024),
                CorruptedFile(url: tempDir.appendingPathComponent("book3.epub"), reason: "Bad", size: 1024),
                CorruptedFile(url: tempDir.appendingPathComponent("book1.pdf"), reason: "Bad", size: 2048),
                CorruptedFile(url: tempDir.appendingPathComponent("book2.pdf"), reason: "Bad", size: 2048),
            ],
            breakdowns: [
                .epub: FormatBreakdown(total: 10, corrupted: 3),
                .pdf: FormatBreakdown(total: 10, corrupted: 2),
            ],
            totalFolders: 5,
            foldersWithEbooks: 5
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "breakdown.md")

        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("Format Breakdown"))
        XCTAssertTrue(contents.contains("epub"))
        XCTAssertTrue(contents.contains("pdf"))
    }

    // MARK: - Large Dataset Tests

    func testReportWithManyCorruptedFiles() throws {
        let tempDir = try temporaryRoot()
        var corrupted: [CorruptedFile] = []
        for i in 1...25 {
            corrupted.append(CorruptedFile(
                url: tempDir.appendingPathComponent("book\(i).epub"),
                reason: "Corruption \(i)",
                size: Int64(i * 1024)
            ))
        }

        let result = ScanResult(
            totalFiles: 100,
            corruptedFiles: corrupted,
            breakdowns: [.epub: FormatBreakdown(total: 100, corrupted: 25)],
            totalFolders: 20,
            foldersWithEbooks: 15
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "many.md")

        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("book1.epub"))
        XCTAssertTrue(contents.contains("book25.epub"))
    }

    func testReportWithManyEmptyFolders() throws {
        let tempDir = try temporaryRoot()
        var empty: [URL] = []
        for i in 1...15 {
            empty.append(tempDir.appendingPathComponent("EmptyFolder\(i)"))
        }

        let result = ScanResult(
            totalFiles: 50,
            emptyFolders: empty,
            totalFolders: 30,
            foldersWithEbooks: 15
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "many_empty.md")

        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("EmptyFolder1"))
        XCTAssertTrue(contents.contains("EmptyFolder15"))
    }

    // MARK: - Custom Configuration Tests

    func testReportWithCustomCorruptedDirectoryName() throws {
        let tempDir = try temporaryRoot()
        let result = ScanResult(
            totalFiles: 5,
            corruptedFiles: [
                CorruptedFile(url: tempDir.appendingPathComponent("bad.epub"), reason: "Invalid", size: 1024)
            ]
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(
            from: result,
            rootDirectory: tempDir,
            corruptedDirectoryName: "BROKEN_FILES",
            into: tempDir,
            fileName: "custom.md"
        )

        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("BROKEN_FILES"))
    }

    func testReportWithCustomFileName() throws {
        let tempDir = try temporaryRoot()
        let result = ScanResult(totalFiles: 1)

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(
            from: result,
            rootDirectory: tempDir,
            corruptedDirectoryName: "CORRUPTED",
            into: tempDir,
            fileName: "my_custom_report.md"
        )

        XCTAssertTrue(reportURL.lastPathComponent.contains("my_custom_report"))
    }

    // MARK: - Content Structure Tests

    func testReportContainsRequiredSections() throws {
        let tempDir = try temporaryRoot()
        let result = ScanResult(
            totalFiles: 10,
            corruptedFiles: [
                CorruptedFile(url: tempDir.appendingPathComponent("bad.epub"), reason: "Invalid", size: 1024)
            ],
            breakdowns: [.epub: FormatBreakdown(total: 10, corrupted: 1)],
            emptyFolders: [tempDir.appendingPathComponent("Empty")],
            totalFolders: 5,
            foldersWithEbooks: 4
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "sections.md")

        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("# Ebook Library Report"))
        XCTAssertTrue(contents.contains("## Summary"))
        XCTAssertTrue(contents.contains("## Format Breakdown"))
        XCTAssertTrue(contents.contains("## Corrupted Files Details"))
        XCTAssertTrue(contents.contains("## Folders Without Ebooks"))
    }

    func testReportContainsSummaryStatistics() throws {
        let tempDir = try temporaryRoot()
        let result = ScanResult(
            totalFiles: 100,
            corruptedFiles: [
                CorruptedFile(url: tempDir.appendingPathComponent("bad.epub"), reason: "Invalid", size: 1024)
            ],
            totalFolders: 20,
            foldersWithEbooks: 18
        )

        let generator = MarkdownReportGenerator()
        let reportURL = try generator.generate(from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED", into: tempDir, fileName: "stats.md")

        let contents = try String(contentsOf: reportURL)
        XCTAssertTrue(contents.contains("100") || contents.contains("Total Files"))
        XCTAssertTrue(contents.contains("20") || contents.contains("Total Folders"))
    }

    private func temporaryRoot() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}

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

    private func temporaryRoot() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}

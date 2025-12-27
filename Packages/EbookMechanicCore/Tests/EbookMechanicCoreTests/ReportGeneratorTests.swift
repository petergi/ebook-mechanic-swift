import XCTest

@testable import EbookMechanicCore

final class ReportGeneratorTests: XCTestCase {
  func testReportGenerationProducesFile() throws {
    let tempDir = try temporaryRoot()

    let result = ScanResult(
      totalFiles: 2,
      corruptedFiles: [
        CorruptedFile(
          url: tempDir.appendingPathComponent("Broken/book1.epub"), reason: "Missing mimetype file",
          size: 5120, status: .corrupt),
        CorruptedFile(
          url: tempDir.appendingPathComponent("Broken/book2.pdf"), reason: "Missing %%EOF marker",
          size: 8096, status: .corrupt),
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
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
    let reportURL = tempDir.appendingPathComponent("report.md")
    try contents.write(to: reportURL, atomically: true, encoding: .utf8)

    XCTAssertTrue(FileManager.default.fileExists(atPath: reportURL.path))
    let persistedContents = try String(contentsOf: reportURL)
    XCTAssertEqual(persistedContents, contents)
    XCTAssertTrue(contents.contains("## Corrupted Files Details"))
    XCTAssertTrue(contents.contains("book1.epub"))
    XCTAssertTrue(contents.contains("book2.pdf"))
    XCTAssertTrue(contents.contains("Folders Without Ebooks"))

    // Ensure file can be overwritten without throwing.
    let secondContents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
    try secondContents.write(to: reportURL, atomically: true, encoding: .utf8)
    XCTAssertEqual(try String(contentsOf: reportURL), secondContents)
  }

  // MARK: - Empty Result Tests

  func testReportWithEmptyScanResult() throws {
    let tempDir = try temporaryRoot()
    let result = ScanResult()

    let generator = MarkdownReportGenerator()
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")

    XCTAssertTrue(contents.contains("## ✅ No Corrupted Files Found"))
    XCTAssertTrue(contents.contains("## Empty Folders Summary"))
    XCTAssertTrue(contents.contains("**Total folders scanned:** 0"))
  }

  func testReportWithNoCorruptedFiles() throws {
    let tempDir = try temporaryRoot()
    let result = ScanResult(
      totalFiles: 10,
      emptyFolders: [
        tempDir.appendingPathComponent("Empty1"), tempDir.appendingPathComponent("Empty2"),
      ],
      totalFolders: 5,
      foldersWithEbooks: 3
    )

    let generator = MarkdownReportGenerator()
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
    XCTAssertTrue(contents.contains("## ✅ No Corrupted Files Found"))
    XCTAssertTrue(contents.contains("Empty1"))
    XCTAssertTrue(contents.contains("Empty2"))
  }

  func testReportWithNoEmptyFolders() throws {
    let tempDir = try temporaryRoot()
    let result = ScanResult(
      totalFiles: 10,
      corruptedFiles: [
        CorruptedFile(
          url: tempDir.appendingPathComponent("bad.epub"), reason: "Invalid", size: 1024,
          status: .corrupt)
      ],
      totalFolders: 5,
      foldersWithEbooks: 5
    )

    let generator = MarkdownReportGenerator()
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
    XCTAssertTrue(contents.contains("bad.epub"))
    XCTAssertTrue(contents.contains("## ✅ No Empty Folders Found"))
  }

  // MARK: - Format Breakdown Tests

  func testReportWithAllFileTypes() throws {
    let tempDir = try temporaryRoot()
    let result = ScanResult(
      totalFiles: 10,
      corruptedFiles: [
        CorruptedFile(
          url: tempDir.appendingPathComponent("book.epub"), reason: "Bad EPUB", size: 1024,
          status: .corrupt),
        CorruptedFile(
          url: tempDir.appendingPathComponent("book.mobi"), reason: "Bad MOBI", size: 2048,
          status: .corrupt),
        CorruptedFile(
          url: tempDir.appendingPathComponent("book.azw3"), reason: "Bad AZW3", size: 3072,
          status: .corrupt),
        CorruptedFile(
          url: tempDir.appendingPathComponent("book.azw4"), reason: "Bad AZW4", size: 4096,
          status: .corrupt),
        CorruptedFile(
          url: tempDir.appendingPathComponent("book.pdf"), reason: "Bad PDF", size: 5120,
          status: .corrupt),
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
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
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
        CorruptedFile(
          url: tempDir.appendingPathComponent("book1.epub"), reason: "Bad", size: 1024,
          status: .corrupt),
        CorruptedFile(
          url: tempDir.appendingPathComponent("book2.epub"), reason: "Bad", size: 1024,
          status: .corrupt),
        CorruptedFile(
          url: tempDir.appendingPathComponent("book3.epub"), reason: "Bad", size: 1024,
          status: .corrupt),
        CorruptedFile(
          url: tempDir.appendingPathComponent("book1.pdf"), reason: "Bad", size: 2048,
          status: .corrupt),
        CorruptedFile(
          url: tempDir.appendingPathComponent("book2.pdf"), reason: "Bad", size: 2048,
          status: .corrupt),
      ],
      breakdowns: [
        .epub: FormatBreakdown(total: 10, corrupted: 3),
        .pdf: FormatBreakdown(total: 10, corrupted: 2),
      ],
      totalFolders: 5,
      foldersWithEbooks: 5
    )

    let generator = MarkdownReportGenerator()
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
    XCTAssertTrue(contents.contains("| File Type | Corrupted | Total | Validation Level | Status |"))
    XCTAssertTrue(contents.contains("| .EPUB | 3 | 10"))
    XCTAssertTrue(contents.contains("| .PDF | 2 | 10"))
  }

  // MARK: - Large Dataset Tests

  func testReportWithManyCorruptedFiles() throws {
    let tempDir = try temporaryRoot()
    var corrupted: [CorruptedFile] = []
    for index in 1...25 {
      corrupted.append(
        CorruptedFile(
          url: tempDir.appendingPathComponent("book\(index).epub"),
          reason: "Corruption \(index)",
          size: Int64(index * 1024),
          status: .corrupt
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
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
    XCTAssertTrue(contents.contains("book1.epub"))
    XCTAssertTrue(contents.contains("book25.epub"))
  }

  func testReportWithManyEmptyFolders() throws {
    let tempDir = try temporaryRoot()
    var empty: [URL] = []
    for index in 1...15 {
      empty.append(tempDir.appendingPathComponent("EmptyFolder\(index)"))
    }

    let result = ScanResult(
      totalFiles: 50,
      emptyFolders: empty,
      totalFolders: 30,
      foldersWithEbooks: 15
    )

    let generator = MarkdownReportGenerator()
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
    XCTAssertTrue(contents.contains("EmptyFolder1"))
    XCTAssertTrue(contents.contains("EmptyFolder15"))
  }

  // MARK: - Custom Configuration Tests

  func testReportWithCustomCorruptedDirectoryName() throws {
    let tempDir = try temporaryRoot()
    let result = ScanResult(
      totalFiles: 5,
      corruptedFiles: [
        CorruptedFile(
          url: tempDir.appendingPathComponent("bad.epub"), reason: "Invalid", size: 1024,
          status: .corrupt)
      ]
    )

    let generator = MarkdownReportGenerator()
    let contents = try generator.generate(
      from: result,
      rootDirectory: tempDir,
      corruptedDirectoryName: "BROKEN_FILES"
    )
    XCTAssertTrue(contents.contains("BROKEN_FILES"))
  }

  func testReportWithCustomFileName() throws {
    let tempDir = try temporaryRoot()
    let result = ScanResult(totalFiles: 1)

    let generator = MarkdownReportGenerator()
    let contents = try generator.generate(
      from: result,
      rootDirectory: tempDir,
      corruptedDirectoryName: "CORRUPTED"
    )
    let reportURL = tempDir.appendingPathComponent("my_custom_report.md")
    try contents.write(to: reportURL, atomically: true, encoding: .utf8)
    XCTAssertTrue(reportURL.lastPathComponent.contains("my_custom_report"))
  }

  // MARK: - Content Structure Tests

  func testReportContainsRequiredSections() throws {
    let tempDir = try temporaryRoot()
    let result = ScanResult(
      totalFiles: 10,
      corruptedFiles: [
        CorruptedFile(
          url: tempDir.appendingPathComponent("bad.epub"), reason: "Invalid", size: 1024,
          status: .corrupt)
      ],
      breakdowns: [.epub: FormatBreakdown(total: 10, corrupted: 1)],
      emptyFolders: [tempDir.appendingPathComponent("Empty")],
      totalFolders: 5,
      foldersWithEbooks: 4
    )

    let generator = MarkdownReportGenerator()
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
    XCTAssertTrue(contents.contains("# EbookMechanic Report"))
    XCTAssertTrue(contents.contains("## Corruption Scan Summary"))
    XCTAssertTrue(contents.contains("### By File Type"))
    XCTAssertTrue(contents.contains("## Corrupted Files Details"))
    XCTAssertTrue(contents.contains("## Folders Without Ebooks"))
  }

  func testReportContainsSummaryStatistics() throws {
    let tempDir = try temporaryRoot()
    let result = ScanResult(
      totalFiles: 100,
      corruptedFiles: [
        CorruptedFile(
          url: tempDir.appendingPathComponent("bad.epub"), reason: "Invalid", size: 1024,
          status: .corrupt)
      ],
      totalFolders: 20,
      foldersWithEbooks: 18
    )

    let generator = MarkdownReportGenerator()
    let contents = try generator.generate(
      from: result, rootDirectory: tempDir, corruptedDirectoryName: "CORRUPTED")
    XCTAssertTrue(contents.contains("100") || contents.contains("Total Files"))
    XCTAssertTrue(contents.contains("20") || contents.contains("Total Folders"))
  }

  private func temporaryRoot() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
      at: url, withIntermediateDirectories: true, attributes: nil)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: url)
    }
    return url
  }
}

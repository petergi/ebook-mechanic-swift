import XCTest

@testable import EbookMechanicCore

final class HTMLReportGeneratorTests: XCTestCase {

  var reportGenerator: HTMLReportGenerator!
  var mockScanResult: ScanResult!
  var mockRootDirectory: URL!
  var mockCorruptedDirectoryName: String!
  var mockRepairs: [RepairResult]!

  override func setUpWithError() throws {
    reportGenerator = HTMLReportGenerator()
    mockRootDirectory = URL(fileURLWithPath: "/Users/test/Library")
    mockCorruptedDirectoryName = "CorruptedBooks"

    let corruptedFile1 = CorruptedFile(
      url: mockRootDirectory.appendingPathComponent("book with <tags>.epub"),
      reason: "Missing mimetype <script>alert(1)</script>", size: 1024, status: .nonCompliant)
    let corruptedFile2 = CorruptedFile(
      url: mockRootDirectory.appendingPathComponent("path/to/book&name.pdf"),
      reason: "Invalid EOF & special chars", size: 2048, status: .corrupt)

    mockScanResult = ScanResult(
      totalFiles: 2,
      corruptedFiles: [corruptedFile1, corruptedFile2],
      breakdowns: [
        .epub: FormatBreakdown(total: 1, corrupted: 1),
        .pdf: FormatBreakdown(total: 1, corrupted: 1)
      ],
      emptyFolders: [mockRootDirectory.appendingPathComponent("empty/folder")],
      totalFolders: 1,
      foldersWithEbooks: 0
    )

    mockRepairs = [
      RepairResult(
        success: true, message: "Fixed mimetype", fixed: true, fileURL: corruptedFile1.url),
      RepairResult(
        success: false, message: "Could not fix PDF & Co.", fixed: false,
        fileURL: corruptedFile2.url)
    ]
  }

  func testHTMLStructureAndContent() throws {
    let htmlString = try reportGenerator.generate(
      from: mockScanResult, rootDirectory: mockRootDirectory,
      corruptedDirectoryName: mockCorruptedDirectoryName, repairs: mockRepairs)

    XCTAssertTrue(htmlString.contains("<!DOCTYPE html>"))
    XCTAssertTrue(htmlString.contains("<html lang=\"en\">"))
    XCTAssertTrue(htmlString.contains("<title>EbookMechanic Report - "))
    XCTAssertTrue(htmlString.contains("<h1>EbookMechanic Report</h1>"))
    XCTAssertTrue(htmlString.contains("<footer>"))

    // Check for presence of key sections
    XCTAssertTrue(htmlString.contains("<h2 class=\"section-header\">Corruption Scan Summary</h2>"))
    XCTAssertTrue(htmlString.contains("<h3 class=\"section-header\">By File Type</h3>"))
    XCTAssertTrue(htmlString.contains("<h2 class=\"section-header\">Empty Folders Summary</h2>"))
    XCTAssertTrue(htmlString.contains("<h2 class='section-header'>Corrupted Files Details</h2>"))
    XCTAssertTrue(htmlString.contains("<h2 class='section-header'>Repair Attempts</h2>"))
  }

  func testEmbeddedCSSEmbedded() throws {
    let htmlString = try reportGenerator.generate(
      from: mockScanResult, rootDirectory: mockRootDirectory,
      corruptedDirectoryName: mockCorruptedDirectoryName, repairs: mockRepairs)
    XCTAssertTrue(htmlString.contains("<style>"))
    XCTAssertTrue(htmlString.contains("body { font-family:"))
    XCTAssertTrue(htmlString.contains(".badge.ok {"))
  }

  func testXSSPreventionInFilePathsAndReasons() throws {
    let htmlString = try reportGenerator.generate(
      from: mockScanResult, rootDirectory: mockRootDirectory,
      corruptedDirectoryName: mockCorruptedDirectoryName, repairs: mockRepairs)

    // Test file paths
    XCTAssertFalse(htmlString.contains("book with <tags>.epub"))
    XCTAssertTrue(htmlString.contains("book with &lt;tags&gt;.epub"))
    XCTAssertFalse(htmlString.contains("path/to/book&name.pdf"))
    XCTAssertTrue(htmlString.contains("path/to/book&amp;name.pdf"))

    // Test reasons
    XCTAssertFalse(htmlString.contains("Missing mimetype <script>alert(1)</script>"))
    XCTAssertTrue(htmlString.contains("Missing mimetype &lt;script&gt;alert(1)&lt;/script&gt;"))
    XCTAssertFalse(htmlString.contains("Invalid EOF & special chars"))
    XCTAssertTrue(htmlString.contains("Invalid EOF &amp; special chars"))

    // Test repair messages
    XCTAssertFalse(htmlString.contains("Could not fix PDF & Co."))
    XCTAssertTrue(htmlString.contains("Could not fix PDF &amp; Co."))
  }

  func testStatusBadgesAndCollapsibleDetails() throws {
    let htmlString = try reportGenerator.generate(
      from: mockScanResult, rootDirectory: mockRootDirectory,
      corruptedDirectoryName: mockCorruptedDirectoryName, repairs: mockRepairs)

    // Check for badge classes
    XCTAssertTrue(htmlString.contains("<span class=\"badge corrupt\">❌ Corrupted</span>"))
    XCTAssertTrue(htmlString.contains("class=\"file-detail status-nonCompliant\""))

    // Check for collapsible headers and content
    XCTAssertTrue(htmlString.contains("<div class=\"collapsible-header\">"))
    XCTAssertTrue(htmlString.contains("<div class=\"collapsible-content\">"))
  }
}

// Add extension for HTML escaping if not already present in EbookMechanicCore
extension String {
  fileprivate func htmlEscaped() -> String {
    var result = self
    result = result.replacingOccurrences(of: "&", with: "&amp;")
    result = result.replacingOccurrences(of: "<", with: "&lt;")
    result = result.replacingOccurrences(of: ">", with: "&gt;")
    result = result.replacingOccurrences(of: "\"", with: "&quot;")
    result = result.replacingOccurrences(of: "'", with: "&#039;")
    return result
  }
}

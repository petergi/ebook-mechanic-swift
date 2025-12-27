import XCTest

@testable import EbookMechanicCore

final class JSONReportGeneratorTests: XCTestCase {

  var reportGenerator: JSONReportGenerator!
  var mockScanResult: ScanResult!
  var mockRootDirectory: URL!
  var mockCorruptedDirectoryName: String!
  var mockRepairs: [RepairResult]!

  override func setUpWithError() throws {
    reportGenerator = JSONReportGenerator()
    mockRootDirectory = URL(fileURLWithPath: "/Users/test/Library")
    mockCorruptedDirectoryName = "CorruptedBooks"

    let corruptedFile1 = CorruptedFile(
      url: mockRootDirectory.appendingPathComponent("book1.epub"), reason: "Missing mimetype",
      size: 1024, status: .nonCompliant)
    let corruptedFile2 = CorruptedFile(
      url: mockRootDirectory.appendingPathComponent("path/to/book,2.pdf"),
      reason: "Invalid EOF marker", size: 2048, status: .corrupt)

    mockScanResult = ScanResult(
      totalFiles: 2,
      corruptedFiles: [corruptedFile1, corruptedFile2],
      breakdowns: [
        .epub: FormatBreakdown(total: 1, corrupted: 1),
        .pdf: FormatBreakdown(total: 1, corrupted: 1),
      ],
      emptyFolders: [mockRootDirectory.appendingPathComponent("empty/folder")],
      totalFolders: 1,
      foldersWithEbooks: 0
    )

    mockRepairs = [
      RepairResult(
        success: true, message: "Fixed mimetype", fixed: true, fileURL: corruptedFile1.url),
      RepairResult(
        success: false, message: "Could not fix PDF", fixed: false, fileURL: corruptedFile2.url),
    ]
  }

  func testJSONStructureAndContent() throws {
    let jsonString = try reportGenerator.generate(
      from: mockScanResult, rootDirectory: mockRootDirectory,
      corruptedDirectoryName: mockCorruptedDirectoryName, repairs: mockRepairs)

    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try decoder.decode(JSONReportGenerator.Report.self, from: jsonData)

    // Metadata checks
    XCTAssertEqual(report.metadata.rootDirectory, mockRootDirectory.path)
    XCTAssertEqual(report.metadata.corruptedDirectoryName, mockCorruptedDirectoryName)
    XCTAssertEqual(report.metadata.validationLevel, "standard")

    // Summary checks
    XCTAssertEqual(report.summary.totalFiles, mockScanResult.totalFiles)
    XCTAssertEqual(report.summary.corruptedFiles, mockScanResult.corruptedFiles.count)
    XCTAssertEqual(report.summary.emptyFolders, mockScanResult.emptyFolders.count)
    XCTAssertEqual(report.summary.breakdowns[.epub]?.total, 1)
    XCTAssertEqual(report.summary.breakdowns[.epub]?.corrupted, 1)

    // Corrupted Files checks
    XCTAssertEqual(report.corruptedFiles.count, mockScanResult.corruptedFiles.count)
    XCTAssertEqual(report.corruptedFiles[0].url, mockScanResult.corruptedFiles[0].url.path)
    XCTAssertEqual(report.corruptedFiles[0].reason, mockScanResult.corruptedFiles[0].reason)
    XCTAssertEqual(report.corruptedFiles[0].size, mockScanResult.corruptedFiles[0].size)
    XCTAssertEqual(report.corruptedFiles[0].status, mockScanResult.corruptedFiles[0].status)

    XCTAssertEqual(report.corruptedFiles[1].url, mockScanResult.corruptedFiles[1].url.path)
    XCTAssertEqual(report.corruptedFiles[1].reason, mockScanResult.corruptedFiles[1].reason)
    XCTAssertEqual(report.corruptedFiles[1].size, mockScanResult.corruptedFiles[1].size)
    XCTAssertEqual(report.corruptedFiles[1].status, mockScanResult.corruptedFiles[1].status)

    // Repairs checks
    XCTAssertEqual(report.repairs.count, mockRepairs.count)
    XCTAssertEqual(report.repairs[0].success, mockRepairs[0].success)
    XCTAssertEqual(report.repairs[0].message, mockRepairs[0].message)
    XCTAssertEqual(report.repairs[0].fixed, mockRepairs[0].fixed)
    XCTAssertEqual(report.repairs[0].fileURL, mockRepairs[0].fileURL?.path)
  }

  func testEmptyScanResult() throws {
    let emptyResult = ScanResult()
    let jsonString = try reportGenerator.generate(
      from: emptyResult, rootDirectory: mockRootDirectory,
      corruptedDirectoryName: mockCorruptedDirectoryName, repairs: [])

    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try decoder.decode(JSONReportGenerator.Report.self, from: jsonData)

    XCTAssertEqual(report.corruptedFiles.count, 0)
    XCTAssertEqual(report.repairs.count, 0)
  }

  func testSpecialCharactersInPathsAndReasons() throws {
    let specialCharURL = mockRootDirectory.appendingPathComponent(
      "book with spaces & other-chars/book,name's.pdf")
    let specialCharReason = "Reason with, commas\"quotes\"and\nnewlines."

    let corruptedFile = CorruptedFile(
      url: specialCharURL, reason: specialCharReason, size: 100, status: .corrupt)
    let specialResult = ScanResult(totalFiles: 1, corruptedFiles: [corruptedFile])

    let jsonString = try reportGenerator.generate(
      from: specialResult, rootDirectory: mockRootDirectory,
      corruptedDirectoryName: mockCorruptedDirectoryName, repairs: [])

    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try decoder.decode(JSONReportGenerator.Report.self, from: jsonData)

    XCTAssertEqual(report.corruptedFiles[0].url, specialCharURL.path)
    XCTAssertEqual(report.corruptedFiles[0].reason, specialCharReason)
  }
}

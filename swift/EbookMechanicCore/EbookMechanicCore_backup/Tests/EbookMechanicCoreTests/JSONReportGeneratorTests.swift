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
    let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]

    // Metadata checks
    XCTAssertNotNil(json["metadata"])
    let metadata = json["metadata"] as! [String: Any]
    XCTAssertEqual(metadata["rootDirectory"] as? String, mockRootDirectory.path)
    XCTAssertEqual(metadata["corruptedDirectoryName"] as? String, mockCorruptedDirectoryName)
    XCTAssertNotNil(metadata["timestamp"])
    XCTAssertNotNil(metadata["elapsedTime"])
    XCTAssertEqual(metadata["validationLevel"] as? String, "standard")  // Default from generator

    // Summary checks
    XCTAssertNotNil(json["summary"])
    let summary = json["summary"] as! [String: Any]
    XCTAssertEqual(summary["totalFiles"] as? Int, mockScanResult.totalFiles)
    XCTAssertEqual(summary["corruptedFiles"] as? Int, mockScanResult.corruptedFiles.count)
    XCTAssertEqual(summary["emptyFolders"] as? Int, mockScanResult.emptyFolders.count)

    XCTAssertNotNil(summary["breakdowns"])
    let breakdowns = summary["breakdowns"] as! [String: Any]
    XCTAssertNotNil(breakdowns["epub"])
    let epubBreakdown = breakdowns["epub"] as! [String: Int]
    XCTAssertEqual(epubBreakdown["total"], 1)
    XCTAssertEqual(epubBreakdown["corrupted"], 1)

    // Corrupted Files checks
    XCTAssertNotNil(json["corruptedFiles"])
    let corruptedFiles = json["corruptedFiles"] as! [[String: Any]]
    XCTAssertEqual(corruptedFiles.count, mockScanResult.corruptedFiles.count)

    let file1 = corruptedFiles[0]
    XCTAssertEqual(file1["url"] as? String, mockScanResult.corruptedFiles[0].url.path)
    XCTAssertEqual(file1["reason"] as? String, mockScanResult.corruptedFiles[0].reason)
    XCTAssertEqual(file1["size"] as? Int64, mockScanResult.corruptedFiles[0].size)
    XCTAssertEqual(file1["status"] as? String, mockScanResult.corruptedFiles[0].status.rawValue)

    let file2 = corruptedFiles[1]
    XCTAssertEqual(file2["url"] as? String, mockScanResult.corruptedFiles[1].url.path)
    XCTAssertEqual(file2["reason"] as? String, mockScanResult.corruptedFiles[1].reason)
    XCTAssertEqual(file2["size"] as? Int64, mockScanResult.corruptedFiles[1].size)
    XCTAssertEqual(file2["status"] as? String, mockScanResult.corruptedFiles[1].status.rawValue)

    // Repairs checks
    XCTAssertNotNil(json["repairs"])
    let repairsJSON = json["repairs"] as! [[String: Any]]
    XCTAssertEqual(repairsJSON.count, mockRepairs.count)

    let repair1 = repairsJSON[0]
    XCTAssertEqual(repair1["success"] as? Bool, mockRepairs[0].success)
    XCTAssertEqual(repair1["message"] as? String, mockRepairs[0].message)
    XCTAssertEqual(repair1["fixed"] as? Bool, mockRepairs[0].fixed)
    XCTAssertEqual(repair1["fileURL"] as? String, mockRepairs[0].fileURL?.path)
  }

  func testEmptyScanResult() throws {
    let emptyResult = ScanResult()
    let jsonString = try reportGenerator.generate(
      from: emptyResult, rootDirectory: mockRootDirectory,
      corruptedDirectoryName: mockCorruptedDirectoryName, repairs: [])

    let jsonData = jsonString.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]

    XCTAssertNotNil(json["metadata"])
    XCTAssertNotNil(json["summary"])
    XCTAssertEqual((json["corruptedFiles"] as! [[String: Any]]).count, 0)
    XCTAssertEqual((json["repairs"] as! [[String: Any]]).count, 0)
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
    let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]

    let corruptedFiles = json["corruptedFiles"] as! [[String: Any]]
    XCTAssertEqual(corruptedFiles[0]["url"] as? String, specialCharURL.path)
    XCTAssertEqual(corruptedFiles[0]["reason"] as? String, specialCharReason)
  }
}

import EbookMechanicCore
import Foundation
import XCTest

@testable import EbookMechanicCLI

// swiftlint:disable type_body_length
final class ProgressPrinterTests: XCTestCase {

  // MARK: - Initialization Tests

  func testInitWithVerboseTrue() {
    let printer = ProgressPrinter(verbose: true)
    XCTAssertTrue(printer.verbose)
  }

  func testInitWithVerboseFalse() {
    let printer = ProgressPrinter(verbose: false)
    XCTAssertFalse(printer.verbose)
  }

  // MARK: - Progress Event Handling Tests

  func testHandleValidatingFileEvent() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let url = URL(fileURLWithPath: "/test/book.epub")
    let event = ProgressEvent(
      stage: .validatingFile(url),
      completed: 5,
      total: 100,
      currentItem: "book.epub"
    )

    printer.handle(event)
    XCTAssertTrue(hooks.contains("book.epub"))
  }

  func testHandleScanningFilesEvent() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let event = ProgressEvent(
      stage: .scanningFiles,
      completed: 50,
      total: 100,
      currentItem: ""
    )

    printer.handle(event)
    XCTAssertTrue(hooks.contains("Progress: 50/100"))
  }

  func testHandleScanningFoldersEvent() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let event = ProgressEvent(
      stage: .scanningFolders,
      completed: 10,
      total: 20,
      currentItem: "/test/folder"
    )

    printer.handle(event)
    XCTAssertTrue(hooks.contains("Checking folders (10/20)"))
  }

  func testHandleMovingCorruptedFilesEvent() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let event = ProgressEvent(
      stage: .movingCorruptedFiles,
      completed: 3,
      total: 10,
      currentItem: "corrupted.epub"
    )

    printer.handle(event)
    XCTAssertTrue(hooks.contains("corrupted.epub"))
  }

  func testHandleDeletingEmptyFoldersEvent() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let event = ProgressEvent(
      stage: .deletingEmptyFolders,
      completed: 1,
      total: 5,
      currentItem: "/empty/folder"
    )

    printer.handle(event)
    XCTAssertTrue(hooks.contains("/empty/folder"))
  }

  func testHandleRepairingFilesEvent() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let event = ProgressEvent(
      stage: .repairingFiles,
      completed: 2,
      total: 5,
      currentItem: "broken.pdf"
    )

    printer.handle(event)
    XCTAssertTrue(hooks.contains("broken.pdf"))
  }

  func testHandleNormalizingFilesEvent() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let event = ProgressEvent(
      stage: .normalizingFiles,
      completed: 15,
      total: 30,
      currentItem: "book.epub"
    )

    printer.handle(event)
    XCTAssertTrue(hooks.contains("Normalizing (15/30) book.epub"))
  }

  func testHandleEventWhenNotVerbose() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: false)
    let url = URL(fileURLWithPath: "/test/book.epub")
    let event = ProgressEvent(
      stage: .validatingFile(url),
      completed: 5,
      total: 100,
      currentItem: "book.epub"
    )

    printer.handle(event)
    XCTAssertTrue(hooks.messages.isEmpty)
  }

  // MARK: - Print Method Tests

  func testPrintHeader() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    printer.printHeader("Test Header")
    XCTAssertEqual(hooks.messages.last, "\n=== Test Header ===")
  }

  func testPrintFooter() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    printer.printFooter("Test Footer")
    XCTAssertEqual(hooks.messages.last, "\n✅ Test Footer\n")
  }

  func testPrintInfo() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    printer.printInfo("Test info message")
    XCTAssertEqual(hooks.messages.last, "• Test info message")
  }

  func testPrintSuccess() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    printer.printSuccess("Test success message")
    XCTAssertEqual(hooks.messages.last, "✅ Test success message")
  }

  func testPrintBullet() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    printer.printBullet("Test bullet point")
    XCTAssertEqual(hooks.messages.last, "  - Test bullet point")
  }

  func testPrintPerformanceMetrics() throws {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let metrics = try makePerformanceMetrics(
      filesPerSecond: 3.21,
      totalValidationTime: 12.345,
      averageValidationTimePerFile: 0.1234,
      externalToolCallCount: 0,
      cacheHitRate: 0.5,
      parallelEfficiencyRatio: 0.0,
      validationTimeByFormat: [:]
    )

    printer.printPerformanceMetrics(metrics)

    XCTAssertTrue(hooks.contains("Total validation time: 12.35s"))
    XCTAssertTrue(hooks.contains("Files per second: 3.21"))
    XCTAssertTrue(hooks.contains("Average validation time: 0.123s"))
    XCTAssertTrue(hooks.contains("Cache hit rate: 50.00%"))
  }

  // MARK: - Scan Result Printing Tests

  func testPrintScanResultEmpty() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let result = ScanResult(totalFiles: 0)

    printer.printScanResult(result)
    XCTAssertTrue(hooks.contains("Files scanned: 0"))
    XCTAssertTrue(hooks.contains("Corrupted files: 0"))
  }

  func testPrintScanResultWithCorruptedFiles() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    var result = ScanResult(totalFiles: 100)

    // Add some corrupted files
    let url1 = URL(fileURLWithPath: "/test/corrupted1.epub")
    let url2 = URL(fileURLWithPath: "/test/corrupted2.pdf")
    result.corruptedFiles.append(
      CorruptedFile(url: url1, reason: "Invalid ZIP structure", size: 1024, status: .corrupt))
    result.corruptedFiles.append(
      CorruptedFile(url: url2, reason: "Missing EOF marker", size: 2048, status: .corrupt))

    printer.printScanResult(result)
    XCTAssertTrue(hooks.contains("/test/corrupted1.epub"))
    XCTAssertTrue(hooks.contains("/test/corrupted2.pdf"))
  }

  func testPrintScanResultWithManyCorruptedFiles() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    var result = ScanResult(totalFiles: 100)

    // Add more than 10 corrupted files to test truncation
    for index in 1...15 {
      let url = URL(fileURLWithPath: "/test/corrupted\(index).epub")
      result.corruptedFiles.append(
        CorruptedFile(
          url: url,
          reason: "Test reason \(index)",
          size: Int64(index * 1024),
          status: .corrupt
        ))
    }

    printer.printScanResult(result)
    XCTAssertTrue(hooks.contains("… and 5 more"))
  }

  func testPrintScanResultWithBreakdownByType() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    var result = ScanResult(totalFiles: 100)

    // Add corrupted files of different types
    result.corruptedFiles.append(
      CorruptedFile(
        url: URL(fileURLWithPath: "/test/file1.epub"),
        reason: "Bad EPUB",
        size: 1024,
        status: .corrupt
      ))
    result.corruptedFiles.append(
      CorruptedFile(
        url: URL(fileURLWithPath: "/test/file2.pdf"),
        reason: "Bad PDF",
        size: 2048,
        status: .corrupt
      ))
    result.corruptedFiles.append(
      CorruptedFile(
        url: URL(fileURLWithPath: "/test/file3.mobi"),
        reason: "Bad MOBI",
        size: 3072,
        status: .corrupt
      ))

    printer.printScanResult(result)
    XCTAssertTrue(hooks.contains("EPUB"))
    XCTAssertTrue(hooks.contains("PDF"))
    XCTAssertTrue(hooks.contains("MOBI"))
  }

  // MARK: - Repair Summary Tests

  func testPrintRepairSummaryEmpty() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    printer.printRepairSummary(results: [], repairedCount: 0)
    XCTAssertTrue(hooks.contains("No corrupted files required repair."))
  }

  func testPrintRepairSummaryWithSuccessfulRepairs() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let results = [
      RepairResult(success: true, message: "Added EOF marker", fixed: true),
      RepairResult(success: true, message: "Fixed mimetype", fixed: true)
    ]

    printer.printRepairSummary(results: results, repairedCount: 2)
    XCTAssertTrue(hooks.contains("Repair attempts: 2 – fixed: 2"))
    XCTAssertTrue(hooks.contains("Added EOF marker"))
    XCTAssertTrue(hooks.contains("Fixed mimetype"))
  }

  func testPrintRepairSummaryWithMixedResults() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let results = [
      RepairResult(success: true, message: "Repaired", fixed: true),
      RepairResult(success: true, message: "Already valid", fixed: false),
      RepairResult(success: false, message: "Cannot repair MOBI", fixed: false)
    ]

    printer.printRepairSummary(results: results, repairedCount: 1)
    XCTAssertTrue(hooks.contains("Repair attempts: 3 – fixed: 1"))
    XCTAssertTrue(hooks.contains("Repaired"))
    XCTAssertTrue(hooks.contains("Already valid"))
    XCTAssertTrue(hooks.contains("Cannot repair MOBI"))
  }

  func testPrintRepairSummaryNonVerbose() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: false)
    let results = [
      RepairResult(success: true, message: "Repaired", fixed: true)
    ]

    printer.printRepairSummary(results: results, repairedCount: 1)
    XCTAssertTrue(hooks.contains("Repair attempts: 1 – fixed: 1"))
  }

  // MARK: - Edge Case Tests

  func testHandleEventWithZeroTotal() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let event = ProgressEvent(
      stage: .scanningFiles,
      completed: 0,
      total: 0,
      currentItem: ""
    )

    printer.handle(event)
    XCTAssertTrue(hooks.contains("Progress: 0/0"))
  }

  func testHandleEventWithCompletedGreaterThanTotal() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    let event = ProgressEvent(
      stage: .scanningFiles,
      completed: 150,
      total: 100,
      currentItem: ""
    )

    printer.handle(event)
    XCTAssertTrue(hooks.contains("Progress: 150/100"))
  }

  func testPrintScanResultWithAllFileTypes() {
    let (printer, hooks) = ProgressPrinter.makeTestable(verbose: true)
    var result = ScanResult(totalFiles: 100)

    // Add at least one file of each type
    for fileType in EbookFileType.allCases {
      let filename = "test\(fileType.fileExtension)"
      result.corruptedFiles.append(
        CorruptedFile(
          url: URL(fileURLWithPath: "/test/\(filename)"),
          reason: "Test corruption",
          size: 1024,
          status: .corrupt
        )
      )
    }

    printer.printScanResult(result)
    for fileType in EbookFileType.allCases {
      XCTAssertTrue(hooks.contains(fileType.fileExtension.dropFirst().uppercased()))
    }
  }
}
// swiftlint:enable type_body_length

// swiftlint:disable:next function_parameter_count
private func makePerformanceMetrics(
  filesPerSecond: Double,
  totalValidationTime: TimeInterval,
  averageValidationTimePerFile: TimeInterval,
  externalToolCallCount: Int,
  cacheHitRate: Double,
  parallelEfficiencyRatio: Double,
  validationTimeByFormat: [EbookFileType: TimeInterval]
) throws -> PerformanceMetrics {
  let json: [String: Any] = [
    "filesPerSecond": filesPerSecond,
    "totalValidationTime": totalValidationTime,
    "averageValidationTimePerFile": averageValidationTimePerFile,
    "externalToolCallCount": externalToolCallCount,
    "cacheHitRate": cacheHitRate,
    "parallelEfficiencyRatio": parallelEfficiencyRatio,
    "validationTimeByFormat": validationTimeByFormat.map {
      ["key": $0.key.rawValue, "value": $0.value]
    }
  ]
  let data = try JSONSerialization.data(withJSONObject: json, options: [])
  return try JSONDecoder().decode(PerformanceMetrics.self, from: data)
}

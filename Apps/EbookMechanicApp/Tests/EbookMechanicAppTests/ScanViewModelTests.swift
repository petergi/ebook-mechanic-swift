import EbookMechanicCore
import Foundation
import XCTest

@testable import EbookMechanicApp

final class ScanViewModelTests: XCTestCase {
  @MainActor
  func testGenerateReportThrowsWithoutSummary() async {
    let viewModel = ScanViewModel()
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let options = ScanOptions(directory: tempDir)

    do {
      _ = try await viewModel.generateReport(into: tempDir, options: options, formats: [.markdown])
      XCTFail("Expected noScanData error")
    } catch let error as ScanViewModel.ScanViewModelError {
      guard case .noScanData = error else {
        XCTFail("Unexpected error: \(error)")
        return
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  @MainActor
  func testGenerateReportCreatesFilesForFormats() async throws {
    let tempDir = try makeTemporaryDirectory()
    addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }

    let viewModel = ScanViewModel()
    viewModel.summary = ScanResult(totalFiles: 0)
    let formats: Set<ReportFormat> = [.markdown, .json, .csv]
    let options = ScanOptions(directory: tempDir)

    let urls = try await viewModel.generateReport(into: tempDir, options: options, formats: formats)
    XCTAssertEqual(urls.count, formats.count)

    let expectedExtensions = Set(formats.map { $0.rawValue })
    for url in urls {
      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
      XCTAssertTrue(expectedExtensions.contains(url.pathExtension))
    }
  }

  @MainActor
  func testNonCompliantFilesFilter() {
    let viewModel = ScanViewModel()
    let nonCompliant = ValidationResult(
      originalIndex: 0,
      url: URL(fileURLWithPath: "/tmp/noncompliant.epub"),
      size: 123,
      isValid: true,
      reason: "Spec issue",
      status: .nonCompliant
    )
    let okResult = ValidationResult(
      originalIndex: 1,
      url: URL(fileURLWithPath: "/tmp/ok.epub"),
      size: 456,
      isValid: true,
      reason: "OK",
      status: .ok
    )

    viewModel.validationResults = [
      nonCompliant.url: nonCompliant,
      okResult.url: okResult
    ]

    XCTAssertEqual(viewModel.nonCompliantFiles, [nonCompliant])
  }

  @MainActor
  // swiftlint:disable:next function_body_length
  func testFilesWithWarningsFilter() {
    let viewModel = ScanViewModel()
    let epubComplianceJSON = """
    {
      "isCompliant": false,
      "hasWarnings": true,
      "errors": [],
      "warnings": [
        {
          "severity": "warning",
          "message": "Minor issue",
          "filePath": null,
          "lineNumber": null,
          "ruleId": null
        }
      ],
      "epubVersion": "3.2",
      "epubcheckVersion": "5.0",
      "features": [],
      "conformsToAccessibility": false
    }
    """
    let epubCompliance = try? JSONDecoder().decode(
      EPUBComplianceResult.self, from: Data(epubComplianceJSON.utf8))
    let epubWarning = ValidationResult(
      originalIndex: 0,
      url: URL(fileURLWithPath: "/tmp/warn.epub"),
      size: 123,
      isValid: true,
      reason: "Warnings",
      status: .ok,
      epubComplianceDetails: epubCompliance
    )
    let pdfWarning = ValidationResult(
      originalIndex: 1,
      url: URL(fileURLWithPath: "/tmp/warn.pdf"),
      size: 456,
      isValid: true,
      reason: "Stream warnings",
      status: .ok,
      pdfValidationDetails: PDFValidationResult(
        structureValid: true,
        xrefValid: true,
        pageTreeValid: true,
        streamErrors: ["Missing stream end"],
        encryptionInfo: nil,
        conformsToStandard: nil
      )
    )

    viewModel.validationResults = [
      epubWarning.url: epubWarning,
      pdfWarning.url: pdfWarning
    ]

    XCTAssertEqual(viewModel.filesWithWarnings.count, 2)
  }

  @MainActor
  func testRunScanWithExternalValidatorFlagsDoesNotFail() async throws {
    let tempDir = try makeTemporaryDirectory()
    addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
    try writeTinyCorruptedPDF(named: "bad.pdf", in: tempDir)
    try writeStubEPUB(named: "bad.epub", in: tempDir)

    let viewModel = ScanViewModel()
    let options = ScanOptions(directory: tempDir)
    options.dryRun = true
    options.useExternalTools = true

    await viewModel.runScan(options: options)

    XCTAssertEqual(viewModel.summary?.totalFiles, 2)
    XCTAssertEqual(viewModel.corruptedFiles.count, 2)
    XCTAssertNil(viewModel.errorMessage)
  }

  @MainActor
  func testRunScanWithPerformanceMetricsPopulatesMetrics() async throws {
    let tempDir = try makeTemporaryDirectory()
    addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
    try writeValidPDF(named: "ok.pdf", in: tempDir)

    let viewModel = ScanViewModel()
    let options = ScanOptions(directory: tempDir)
    options.dryRun = true
    options.showPerformanceStats = true

    await viewModel.runScan(options: options)

    XCTAssertNotNil(viewModel.performanceMetrics)
  }

  @MainActor
  func testRunScanWithValidPDFReportsNoCorruptionMessage() async throws {
    let tempDir = try makeTemporaryDirectory()
    addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
    try writeValidPDF(named: "ok.pdf", in: tempDir)

    let viewModel = ScanViewModel()
    let options = ScanOptions(directory: tempDir)
    options.dryRun = true

    await viewModel.runScan(options: options)

    XCTAssertEqual(viewModel.summary?.totalFiles, 1)
    XCTAssertTrue(viewModel.corruptedFiles.isEmpty)
    XCTAssertTrue(viewModel.statusMessages.contains { $0.contains("No corrupted files found") })
  }

  @MainActor
  func testDryRunSkipsMoveAndDeleteAutomation() async throws {
    let tempDir = try makeTemporaryDirectory()
    addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
    try writeTinyCorruptedPDF(named: "broken.pdf", in: tempDir)
    let emptyFolder = tempDir.appendingPathComponent("Unused")
    try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)

    let viewModel = ScanViewModel()
    let options = ScanOptions(directory: tempDir)
    options.dryRun = true
    options.autoMoveCorrupted = true
    options.autoDeleteEmptyFolders = true

    await viewModel.runScan(options: options)

    let movedCorruptedURL = tempDir.appendingPathComponent("CORRUPTED/broken.pdf")
    XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("broken.pdf").path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: movedCorruptedURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: emptyFolder.path))
    XCTAssertFalse(
      viewModel.statusMessages.contains { $0.contains("Moved corrupted files to") })
    XCTAssertFalse(
      viewModel.statusMessages.contains { $0.contains("Deleted") && $0.contains("empty folder") })
  }

  @MainActor
  func testPerformanceMetricsDisabledLeavesNil() async throws {
    let tempDir = try makeTemporaryDirectory()
    addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
    try writeValidPDF(named: "ok.pdf", in: tempDir)

    let viewModel = ScanViewModel()
    let options = ScanOptions(directory: tempDir)
    options.dryRun = true
    options.showPerformanceStats = false

    await viewModel.runScan(options: options)

    XCTAssertNil(viewModel.performanceMetrics)
  }

  @MainActor
  func testStartScanNoopsWhenAlreadyScanning() {
    let viewModel = ScanViewModel()
    viewModel.isScanning = true
    viewModel.progressHeadline = "Existing"
    let options = ScanOptions(directory: URL(fileURLWithPath: "/tmp"))

    viewModel.startScan(options: options)

    XCTAssertEqual(viewModel.progressHeadline, "Existing")
  }

  @MainActor
  func testEmptyFoldersOnlySkipsCorruptionScan() async throws {
    let tempDir = try makeTemporaryDirectory()
    addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
    let emptyFolder = tempDir.appendingPathComponent("Empty")
    try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
    try writeTinyCorruptedPDF(named: "bad.pdf", in: tempDir)

    let viewModel = ScanViewModel()
    let options = ScanOptions(directory: tempDir)
    options.emptyFoldersOnly = true
    options.corruptionOnly = false

    await viewModel.runScan(options: options)

    XCTAssertTrue(viewModel.corruptedFiles.isEmpty)
    XCTAssertEqual(viewModel.emptyFolders.count, 1)
  }

  @MainActor
  func testCorruptionOnlySkipsEmptyFolderScan() async throws {
    let tempDir = try makeTemporaryDirectory()
    addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
    let emptyFolder = tempDir.appendingPathComponent("Empty")
    try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
    try writeTinyCorruptedPDF(named: "bad.pdf", in: tempDir)

    let viewModel = ScanViewModel()
    let options = ScanOptions(directory: tempDir)
    options.corruptionOnly = true
    options.emptyFoldersOnly = false

    await viewModel.runScan(options: options)

    XCTAssertEqual(viewModel.corruptedFiles.count, 1)
    XCTAssertTrue(viewModel.emptyFolders.isEmpty)
  }

  @MainActor
  func testPauseResumeCancelStateTransitions() {
    let viewModel = ScanViewModel()
    viewModel.isScanning = true

    viewModel.pauseScan()
    XCTAssertTrue(viewModel.isPaused)
    XCTAssertEqual(viewModel.progressHeadline, "Paused")

    viewModel.resumeScan()
    XCTAssertFalse(viewModel.isPaused)
    XCTAssertEqual(viewModel.progressHeadline, "Resuming")

    viewModel.cancelScan()
    XCTAssertTrue(viewModel.isCancelling)
    XCTAssertEqual(viewModel.progressHeadline, "Cancelling")
  }
}

// MARK: - Test helpers

private func makeTemporaryDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "EbookMechanicAppTests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}

@discardableResult
private func writeTinyCorruptedPDF(named: String, in directory: URL) throws -> URL {
  let url = directory.appendingPathComponent(named)
  var data = Data("%PDF-1.7\n".utf8)
  data.append(Data(repeating: 0x41, count: 32))
  try data.write(to: url)
  return url
}

@discardableResult
private func writeValidPDF(named: String, in directory: URL) throws -> URL {
  let url = directory.appendingPathComponent(named)
  var data = Data("%PDF-1.7\n".utf8)
  data.append(Data(repeating: 0x43, count: 160))
  data.append(Data("\n%%EOF\n".utf8))
  try data.write(to: url)
  return url
}

@discardableResult
private func writeStubEPUB(named: String, in directory: URL) throws -> URL {
  let url = directory.appendingPathComponent(named)
  try Data("not-a-zip".utf8).write(to: url)
  return url
}

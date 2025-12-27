import Foundation
import XCTest

@testable import EbookMechanicCore

final class ExternalPDFValidatorTests: XCTestCase {

  var tempDir: URL!
  var mockPdfcpuPath: URL!

  override func setUpWithError() throws {
    tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
      at: tempDir, withIntermediateDirectories: true, attributes: nil)

    // Create a mock pdfcpu executable
    mockPdfcpuPath = tempDir.appendingPathComponent("pdfcpu")
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: tempDir)
  }

  // Helper to create a dummy pdfcpu executable
  private func createMockPdfcpu(
    exitCode: Int, stdout: String = "", stderr: String = "", delay: TimeInterval = 0
  ) throws {
    let scriptContent = """
      #!/bin/bash
      sleep \(delay)
      echo "\(stdout)"
      echo "\(stderr)" >&2
      exit \(exitCode)
      """
    try scriptContent.write(to: mockPdfcpuPath, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: mockPdfcpuPath.path)
  }

  func testIsPdfcpuInstalled() async throws {
    try createMockPdfcpu(exitCode: 0)
    // Add tempDir to PATH for the test
    let oldPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
    setenv("PATH", (tempDir.path + ":" + oldPath).cString(using: .utf8), 1)
    defer { setenv("PATH", oldPath.cString(using: .utf8), 1) }

    let isInstalled = await ExternalPDFValidator.isPdfcpuInstalled()
    XCTAssertTrue(isInstalled)
  }

  func testValidPDFDetection() async throws {
    try createMockPdfcpu(exitCode: 0, stdout: "validate: success")
    let dummyFileURL = tempDir.appendingPathComponent("valid.pdf")
    try "dummy content".write(to: dummyFileURL, atomically: true, encoding: .utf8)

    let validator = ExternalPDFValidator()
    let result = await validator.validate(fileURL: dummyFileURL, pdfcpuPath: mockPdfcpuPath.path)

    XCTAssertTrue(result.isValid)
    XCTAssertEqual(result.status, .ok)
    XCTAssertTrue(result.reason.contains("PDF is valid."))
    XCTAssertEqual(result.validationLevel, .comprehensive)
  }

  func testStructureErrorDetection() async throws {
    let errorOutput = "validate: corrupt or malformed PDF: EOF marker missing"
    try createMockPdfcpu(exitCode: 1, stderr: errorOutput)
    let dummyFileURL = tempDir.appendingPathComponent("corrupt.pdf")
    try "dummy content".write(to: dummyFileURL, atomically: true, encoding: .utf8)

    let validator = ExternalPDFValidator()
    let result = await validator.validate(fileURL: dummyFileURL, pdfcpuPath: mockPdfcpuPath.path)

    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.status, .corrupt)
    XCTAssertTrue(result.reason.contains("PDF validation failed."))
    XCTAssertTrue(result.reason.contains(errorOutput))
    XCTAssertNotNil(result.pdfValidationDetails)
    XCTAssertTrue(
      result.pdfValidationDetails!.streamErrors.contains(where: {
        $0.contains("EOF marker missing")
      }))
    XCTAssertEqual(result.validationLevel, .comprehensive)
  }

  func testPdfcpuNotInstalledFallback() async throws {
    // Do NOT create mockPdfcpu, so it won't be found
    let dummyFileURL = tempDir.appendingPathComponent("no_pdfcpu.pdf")
    try "dummy content".write(to: dummyFileURL, atomically: true, encoding: .utf8)

    let validator = ExternalPDFValidator()
    // Pass a non-existent path to ensure it doesn't accidentally find a real pdfcpu
    let result = await validator.validate(
      fileURL: dummyFileURL, pdfcpuPath: "/nonexistent/path/pdfcpu")

    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.status, .validationError)
    XCTAssertTrue(result.reason.contains("pdfcpu not installed."))
    XCTAssertEqual(result.validationLevel, .comprehensive)
  }
}

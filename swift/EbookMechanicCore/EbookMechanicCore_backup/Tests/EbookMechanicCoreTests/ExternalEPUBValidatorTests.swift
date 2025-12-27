import Foundation
import XCTest

@testable import EbookMechanicCore

final class ExternalEPUBValidatorTests: XCTestCase {

  var tempDir: URL!
  var mockEpubcheckPath: URL!

  override func setUpWithError() throws {
    tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
      at: tempDir, withIntermediateDirectories: true, attributes: nil)

    // Create a mock epubcheck executable
    mockEpubcheckPath = tempDir.appendingPathComponent("epubcheck")
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: tempDir)
  }

  // Helper to create a dummy epubcheck executable
  private func createMockEpubcheck(
    exitCode: Int, stdout: String = "", stderr: String = "", delay: TimeInterval = 0
  ) throws {
    let scriptContent = """
      #!/bin/bash
      sleep \(delay)
      echo "\(stdout)"
      echo "\(stderr)" >&2
      exit \(exitCode)
      """
    try scriptContent.write(to: mockEpubcheckPath, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: mockEpubcheckPath.path)
  }

  func testIsEpubcheckInstalled() async throws {
    try createMockEpubcheck(exitCode: 0)
    // Add tempDir to PATH for the test
    let oldPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
    setenv("PATH", (tempDir.path + ":" + oldPath).cString(using: .utf8), 1)
    defer { setenv("PATH", oldPath.cString(using: .utf8), 1) }

    XCTAssertTrue(await ExternalEPUBValidator.isEpubcheckInstalled())
  }

  func testValidEPUBDetection() async throws {
    try createMockEpubcheck(exitCode: 0, stdout: "No errors or warnings found.")
    let dummyFileURL = tempDir.appendingPathComponent("valid.epub")
    try "dummy content".write(to: dummyFileURL, atomically: true, encoding: .utf8)  // File needs to exist

    let validator = ExternalEPUBValidator()
    let result = await validator.validate(
      fileURL: dummyFileURL, epubcheckPath: mockEpubcheckPath.path)

    XCTAssertTrue(result.isValid)
    XCTAssertEqual(result.status, .ok)
    XCTAssertTrue(result.reason.contains("EPUB is valid."))
    XCTAssertEqual(result.validationLevel, .comprehensive)
  }

  func testNonCompliantEPUBHandlingWithWarnings() async throws {
    let warningOutput = "WARNING(OPF_001): Missing unique-identifier attribute."
    try createMockEpubcheck(exitCode: 1, stderr: warningOutput)
    let dummyFileURL = tempDir.appendingPathComponent("warnings.epub")
    try "dummy content".write(to: dummyFileURL, atomically: true, encoding: .utf8)

    let validator = ExternalEPUBValidator()
    let result = await validator.validate(
      fileURL: dummyFileURL, epubcheckPath: mockEpubcheckPath.path)

    XCTAssertTrue(result.isValid)  // Still considered valid by epubcheck exit code 1
    XCTAssertEqual(result.status, .nonCompliant)
    XCTAssertTrue(result.reason.contains("EPUB is valid with warnings."))
    XCTAssertTrue(result.reason.contains(warningOutput))
    XCTAssertEqual(result.validationLevel, .comprehensive)
  }

  func testCorruptFileHandlingWithErrors() async throws {
    let errorOutput = "ERROR(RSC_005): File missing from manifest."
    try createMockEpubcheck(exitCode: 2, stderr: errorOutput)
    let dummyFileURL = tempDir.appendingPathComponent("corrupt.epub")
    try "dummy content".write(to: dummyFileURL, atomically: true, encoding: .utf8)

    let validator = ExternalEPUBValidator()
    let result = await validator.validate(
      fileURL: dummyFileURL, epubcheckPath: mockEpubcheckPath.path)

    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.status, .corrupt)
    XCTAssertTrue(result.reason.contains("EPUB validation failed."))
    XCTAssertTrue(result.reason.contains(errorOutput))
    XCTAssertEqual(result.validationLevel, .comprehensive)
  }

  func testEpubcheckNotInstalledFallback() async throws {
    // Do NOT create mockEpubcheck, so it won't be found
    let dummyFileURL = tempDir.appendingPathComponent("no_epubcheck.epub")
    try "dummy content".write(to: dummyFileURL, atomically: true, encoding: .utf8)

    let validator = ExternalEPUBValidator()
    // Pass a non-existent path to ensure it doesn't accidentally find a real epubcheck
    let result = await validator.validate(
      fileURL: dummyFileURL, epubcheckPath: "/nonexistent/path/epubcheck")

    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.status, .validationError)
    XCTAssertTrue(result.reason.contains("Epubcheck not installed."))
    XCTAssertEqual(result.validationLevel, .comprehensive)
  }
}

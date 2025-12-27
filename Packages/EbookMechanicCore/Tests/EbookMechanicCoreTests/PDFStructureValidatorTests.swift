import XCTest

@testable import EbookMechanicCore

final class PDFStructureValidatorTests: XCTestCase {
  private var validator: PDFStructureValidator!

  override func setUp() {
    super.setUp()
    validator = PDFStructureValidator()
  }

  func testValidPDFStructure() {
    let result = validator.parsePdfcpuOutput(stdout: "", stderr: "", exitCode: 0)

    XCTAssertTrue(result.structureValid)
    XCTAssertTrue(result.xrefValid)
    XCTAssertTrue(result.pageTreeValid)
    XCTAssertTrue(result.streamErrors.isEmpty)
    XCTAssertNil(result.encryptionInfo)
    XCTAssertNil(result.conformsToStandard)
  }

  func testCorruptXrefTable() {
    let stderr = "xref table corrupted"
    let result = validator.parsePdfcpuOutput(stdout: "", stderr: stderr, exitCode: 1)

    XCTAssertFalse(result.structureValid)
    XCTAssertFalse(result.xrefValid)
    XCTAssertTrue(result.streamErrors.contains("Xref table is corrupt"))
  }

  func testInvalidPageTree() {
    let stderr = "page tree invalid"
    let result = validator.parsePdfcpuOutput(stdout: "", stderr: stderr, exitCode: 1)

    XCTAssertFalse(result.structureValid)
    XCTAssertFalse(result.pageTreeValid)
    XCTAssertTrue(result.streamErrors.contains("Invalid page tree structure"))
  }

  func testMalformedStreams() {
    let stderr = "EOF marker missing"
    let result = validator.parsePdfcpuOutput(stdout: "", stderr: stderr, exitCode: 1)

    XCTAssertFalse(result.structureValid)
    XCTAssertTrue(result.streamErrors.contains("EOF marker missing"))
  }

  func testEncryptedPDFHandling() {
    let stderr = "file is encrypt and requires password"
    let result = validator.parsePdfcpuOutput(stdout: "", stderr: stderr, exitCode: 1)

    XCTAssertEqual(result.encryptionInfo, stderr)
  }
}

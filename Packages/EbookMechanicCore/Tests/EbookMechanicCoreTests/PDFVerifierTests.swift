import Foundation
import XCTest

@testable import EbookMechanicCore

#if canImport(PDFKit)
  import PDFKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

final class PDFVerifierTests: XCTestCase {

  var pdfStructureValidator: PDFStructureValidator!

  override func setUpWithError() throws {
    pdfStructureValidator = PDFStructureValidator()
  }

  func getFixtureURL(for fileName: String) throws -> URL {
    let currentFileURL = URL(fileURLWithPath: #file)
    let currentDirectoryURL = currentFileURL.deletingLastPathComponent()
    let resourcesURL = currentDirectoryURL.appendingPathComponent("Resources/PDFs")
    let fixtureURL = resourcesURL.appendingPathComponent(fileName)
    try XCTSkipIf(
      !FileManager.default.fileExists(atPath: fixtureURL.path),
      "Missing PDF fixture: \(fileName)")
    return fixtureURL
  }

  func testValidPDFStructure() async throws {
    try await requirePdfcpu()
    let url = try getFixtureURL(for: "valid-structure.pdf")
    let result = pdfStructureValidator.validate(url: url)

    switch result {
    case .success(let validationResult):
      XCTAssertTrue(validationResult.structureValid, "Valid PDF should have valid structure")
      XCTAssertTrue(validationResult.xrefValid, "Valid PDF should have valid xref")
      XCTAssertTrue(validationResult.pageTreeValid, "Valid PDF should have valid page tree")
      XCTAssertTrue(validationResult.streamErrors.isEmpty, "Valid PDF should have no stream errors")
      XCTAssertNil(validationResult.encryptionInfo, "Valid PDF should not be encrypted")
      XCTAssertNil(validationResult.conformsToStandard, "Valid PDF should not have conformity info")
    case .failure(let error):
      XCTFail("Validation failed with error: \(error.localizedDescription)")
    }
  }

  func testCorruptXrefPDFStructure() async throws {
    try await requirePdfcpu()
    let url = try getFixtureURL(for: "corrupt-xref.pdf")
    let result = pdfStructureValidator.validate(url: url)

    switch result {
    case .success(let validationResult):
      XCTAssertFalse(
        validationResult.structureValid, "Corrupt xref PDF should have invalid structure")
      XCTAssertFalse(validationResult.xrefValid, "Corrupt xref PDF should have invalid xref")
      XCTAssertTrue(
        validationResult.pageTreeValid, "Corrupt xref PDF may have valid page tree data")
      XCTAssertFalse(
        validationResult.streamErrors.isEmpty, "Corrupt xref PDF should have stream errors")
      XCTAssertTrue(validationResult.streamErrors.contains("Xref table is corrupt"))
    case .failure(let error):
      XCTFail("Validation failed with error: \(error.localizedDescription)")
    }
  }

  func testInvalidPagesPDFStructure() async throws {
    try await requirePdfcpu()
    let url = try getFixtureURL(for: "invalid-pages.pdf")
    let result = pdfStructureValidator.validate(url: url)

    switch result {
    case .success(let validationResult):
      XCTAssertFalse(
        validationResult.structureValid, "Invalid pages PDF should have invalid structure")
      XCTAssertTrue(validationResult.xrefValid, "Invalid pages PDF may have valid xref")
      XCTAssertFalse(
        validationResult.pageTreeValid, "Invalid pages PDF should have invalid page tree")
      XCTAssertFalse(
        validationResult.streamErrors.isEmpty, "Invalid pages PDF should have stream errors")
      XCTAssertTrue(validationResult.streamErrors.contains("Invalid page tree structure"))
    case .failure(let error):
      XCTFail("Validation failed with error: \(error.localizedDescription)")
    }
  }

  func testMalformedStreamPDFStructure() async throws {
    try await requirePdfcpu()
    let url = try getFixtureURL(for: "malformed-stream.pdf")
    let result = pdfStructureValidator.validate(url: url)

    switch result {
    case .success(let validationResult):
      XCTAssertFalse(
        validationResult.structureValid, "Malformed stream PDF should have invalid structure")
      XCTAssertTrue(validationResult.xrefValid, "Malformed stream PDF may have valid xref")
      XCTAssertTrue(validationResult.pageTreeValid, "Malformed stream PDF may have valid page tree")
      XCTAssertFalse(
        validationResult.streamErrors.isEmpty, "Malformed stream PDF should have stream errors")
      XCTAssertTrue(validationResult.streamErrors.contains("Malformed stream content"))
    case .failure(let error):
      XCTFail("Validation failed with error: \(error.localizedDescription)")
    }
  }

  private func requirePdfcpu() async throws {
    let isInstalled = await ExternalPDFValidator.isPdfcpuInstalled()
    try XCTSkipIf(!isInstalled, "pdfcpu not installed.")
  }
}

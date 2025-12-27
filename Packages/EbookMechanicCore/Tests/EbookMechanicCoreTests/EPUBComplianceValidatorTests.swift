import XCTest

@testable import EbookMechanicCore

final class EPUBComplianceValidatorTests: XCTestCase {

  func getFixtureURL(for fileName: String) throws -> URL {
    let currentFileURL = URL(fileURLWithPath: #file)
    let currentDirectoryURL = currentFileURL.deletingLastPathComponent()
    let resourcesURL = currentDirectoryURL.appendingPathComponent("Resources/EPUBs")
    return resourcesURL.appendingPathComponent(fileName)
  }

  private func requireEpubcheck() async throws {
    if await ExternalToolRunner.isCommandAvailable("epubcheck") == false {
      throw XCTSkip("epubcheck not installed; skipping EPUB compliance tests.")
    }
  }

  private func validateCompliance(
    for url: URL, showWarnings: Bool = false, accessibility: Bool = false
  ) async -> EPUBComplianceResult? {
    let result = await ExternalValidators.validateEpub(
      at: url.path, showWarnings: showWarnings, checkAccessibility: accessibility)
    return result.epubComplianceDetails
  }

  func testValidEPUB2() async throws {
    try await requireEpubcheck()
    let url = try getFixtureURL(for: "valid-epub2.epub")
    guard let compliance = await validateCompliance(for: url, showWarnings: true) else {
      throw XCTSkip("epubcheck did not return compliance details.")
    }
    XCTAssertTrue(compliance.isCompliant)
    XCTAssertFalse(compliance.hasWarnings)
    XCTAssertTrue(compliance.epubVersion.hasPrefix("2"))
  }

  func testValidEPUB3() async throws {
    try await requireEpubcheck()
    let url = try getFixtureURL(for: "valid-epub3.epub")
    guard let compliance = await validateCompliance(for: url, showWarnings: true) else {
      throw XCTSkip("epubcheck did not return compliance details.")
    }
    XCTAssertTrue(compliance.isCompliant)
    XCTAssertFalse(compliance.hasWarnings)
    XCTAssertTrue(compliance.epubVersion.hasPrefix("3"))
  }

  func testMissingMetadata() async throws {
    try await requireEpubcheck()
    let url = try getFixtureURL(for: "missing-metadata.epub")
    guard let compliance = await validateCompliance(for: url, showWarnings: true) else {
      throw XCTSkip("epubcheck did not return compliance details.")
    }
    XCTAssertFalse(compliance.isCompliant)
    XCTAssertTrue(compliance.errors.contains { ($0.ruleId ?? "").hasPrefix("OPF-") })
  }

  func testBrokenLinks() async throws {
    try await requireEpubcheck()
    let url = try getFixtureURL(for: "broken-links.epub")
    guard let compliance = await validateCompliance(for: url, showWarnings: true) else {
      throw XCTSkip("epubcheck did not return compliance details.")
    }
    XCTAssertFalse(compliance.isCompliant)
    XCTAssertTrue(compliance.errors.contains { ($0.ruleId ?? "").hasPrefix("RSC-") })
  }

  func testInvalidXHTML() async throws {
    try await requireEpubcheck()
    let url = try getFixtureURL(for: "invalid-xhtml.epub")
    guard let compliance = await validateCompliance(for: url, showWarnings: true) else {
      throw XCTSkip("epubcheck did not return compliance details.")
    }
    XCTAssertFalse(compliance.isCompliant)
    XCTAssertTrue(compliance.errors.contains { ($0.ruleId ?? "").hasPrefix("RSC-") })
  }

  func testAccessibilityViolations() async throws {
    try await requireEpubcheck()
    let url = try getFixtureURL(for: "accessibility-violations.epub")
    guard let compliance = await validateCompliance(for: url, showWarnings: true, accessibility: true) else {
      throw XCTSkip("epubcheck did not return compliance details.")
    }
    XCTAssertTrue(compliance.isCompliant)
    if compliance.hasWarnings {
      XCTAssertTrue(compliance.warnings.contains { $0.ruleId?.hasPrefix("ACC-") ?? false })
    }
  }
}

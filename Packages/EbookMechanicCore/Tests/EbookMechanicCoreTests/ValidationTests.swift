import XCTest

@testable import EbookMechanicCore

final class ValidationTests: XCTestCase {
  private var validator: FileValidator!

  override func setUp() {
    super.setUp()
    validator = FileValidator()
  }

  func testValidateEPUB() async throws {
    let tempDir = try temporaryDirectory()
    let valid = tempDir.appendingPathComponent("valid.epub")
    try TestFixtures.createValidEPUB(at: valid)
    let validResult = await validator.validate(url: valid, as: .epub)
    XCTAssertTrue(validResult.isValid)

    let noMimetype = tempDir.appendingPathComponent("no_mimetype.epub")
    try TestFixtures.createEPUBWithoutMimetype(at: noMimetype)
    let missingMime = await validator.validate(url: noMimetype, as: .epub)
    XCTAssertFalse(missingMime.isValid)
    XCTAssertEqual(missingMime.reason, "Missing mimetype file")

    let wrongMime = tempDir.appendingPathComponent("wrong_mimetype.epub")
    try TestFixtures.createEPUBWithWrongMimetype(at: wrongMime)
    let wrongMimeResult = await validator.validate(url: wrongMime, as: .epub)
    XCTAssertFalse(wrongMimeResult.isValid)

    let noContainer = tempDir.appendingPathComponent("no_container.epub")
    try TestFixtures.createEPUBWithoutContainer(at: noContainer)
    let missingContainer = await validator.validate(url: noContainer, as: .epub)
    XCTAssertFalse(missingContainer.isValid)
    XCTAssertEqual(missingContainer.reason, "Missing META-INF/container.xml")

    let onlyContent = tempDir.appendingPathComponent("only_content.epub")
    try TestFixtures.createEPUBWithOnlyContent(at: onlyContent)
    let onlyContentResult = await validator.validate(url: onlyContent, as: .epub)
    XCTAssertFalse(onlyContentResult.isValid)
    XCTAssertEqual(onlyContentResult.reason, "Missing mimetype file")

    let lateMime = tempDir.appendingPathComponent("late_mimetype.epub")
    try TestFixtures.createEPUBWithLateMimetype(at: lateMime)
    let lateMimeResult = await validator.validate(url: lateMime, as: .epub)
    XCTAssertFalse(lateMimeResult.isValid)
    XCTAssertEqual(lateMimeResult.reason, "mimetype must be first entry")

    let notZip = tempDir.appendingPathComponent("not_zip.epub")
    try "This is not a ZIP file".data(using: .utf8)!.write(to: notZip)
    let invalidZip = await validator.validate(url: notZip, as: .epub)
    XCTAssertFalse(invalidZip.isValid)
    XCTAssertTrue(
      invalidZip.reason.hasPrefix("Not a valid ZIP file"), "Reason: \(invalidZip.reason)")
  }

  func testValidateMOBI() async throws {
    let tempDir = try temporaryDirectory()
    let validMobi = tempDir.appendingPathComponent("valid.mobi")
    try TestFixtures.createMOBI(with: "BOOKMOBI", at: validMobi)
    let validMobiResult = await validator.validate(url: validMobi, as: .mobi)
    XCTAssertTrue(validMobiResult.isValid)

    let validText = tempDir.appendingPathComponent("valid_text.mobi")
    try TestFixtures.createMOBI(with: "TEXtREAd", at: validText)
    let validTextResult = await validator.validate(url: validText, as: .mobi)
    XCTAssertTrue(validTextResult.isValid)

    let invalid = tempDir.appendingPathComponent("invalid.mobi")
    try TestFixtures.createInvalidMOBI(at: invalid)
    let invalidResult = await validator.validate(url: invalid, as: .mobi)
    XCTAssertFalse(invalidResult.isValid)

    let tooSmall = tempDir.appendingPathComponent("small.mobi")
    try Data("short".utf8).write(to: tooSmall)
    let smallResult = await validator.validate(url: tooSmall, as: .mobi)
    XCTAssertFalse(smallResult.isValid)
    XCTAssertEqual(smallResult.reason, "File too small")

    let zeroHeader = tempDir.appendingPathComponent("zero_header.mobi")
    try TestFixtures.createMOBIWithZeroHeader(at: zeroHeader)
    let zeroResult = await validator.validate(url: zeroHeader, as: .mobi)
    XCTAssertFalse(zeroResult.isValid)
    XCTAssertEqual(zeroResult.reason, "Invalid PalmDB header")
  }

  func testValidatePDF() async throws {
    let tempDir = try temporaryDirectory()
    let validPDF = tempDir.appendingPathComponent("valid.pdf")
    try TestFixtures.createValidPDF(at: validPDF)
    let validPdfResult = await validator.validate(url: validPDF, as: .pdf)
    XCTAssertTrue(validPdfResult.isValid)

    let noHeader = tempDir.appendingPathComponent("no_header.pdf")
    try Data(
      "Not a PDF file with enough content to pass size check but no header marker at all".utf8
    ).write(to: noHeader)
    let noHeaderResult = await validator.validate(url: noHeader, as: .pdf)
    XCTAssertFalse(noHeaderResult.isValid)
    XCTAssertEqual(noHeaderResult.reason, "Missing PDF header")

    let small = tempDir.appendingPathComponent("small.pdf")
    try Data("%PDF-1.4\nsmall".utf8).write(to: small)
    let smallResult = await validator.validate(url: small, as: .pdf)
    XCTAssertFalse(smallResult.isValid)
    XCTAssertEqual(smallResult.reason, "File too small to be valid PDF")

    let noEOF = tempDir.appendingPathComponent("no_eof.pdf")
    try TestFixtures.createPDFWithoutEOF(at: noEOF)
    let noEOFResult = await validator.validate(url: noEOF, as: .pdf)
    XCTAssertFalse(noEOFResult.isValid)
    XCTAssertEqual(noEOFResult.reason, "Missing %%EOF marker")
  }

  func testValidateAliases() async throws {
    let tempDir = try temporaryDirectory()
    let azw3 = tempDir.appendingPathComponent("book.azw3")
    try TestFixtures.createMOBI(with: "BOOKMOBI", at: azw3)
    let azw3Result = await validator.validate(url: azw3, as: .azw3)
    XCTAssertTrue(azw3Result.isValid)

    let azw4 = tempDir.appendingPathComponent("book.azw4")
    try TestFixtures.createValidPDF(at: azw4)
    let azw4Result = await validator.validate(url: azw4, as: .azw4)
    XCTAssertTrue(azw4Result.isValid)
  }

  private func temporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
      at: url, withIntermediateDirectories: true, attributes: nil)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: url)
    }
    return url
  }
}

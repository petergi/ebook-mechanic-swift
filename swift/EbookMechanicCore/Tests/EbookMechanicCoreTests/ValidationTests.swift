import XCTest
@testable import EbookMechanicCore

final class ValidationTests: XCTestCase {
    private var validator: FileValidator!

    override func setUp() {
        super.setUp()
        validator = FileValidator()
    }

    func testValidateEPUB() throws {
        let tempDir = try temporaryDirectory()
        let valid = tempDir.appendingPathComponent("valid.epub")
        try TestFixtures.createValidEPUB(at: valid)
        XCTAssertTrue(validator.validate(url: valid, as: .epub).isValid)

        let noMimetype = tempDir.appendingPathComponent("no_mimetype.epub")
        try TestFixtures.createEPUBWithoutMimetype(at: noMimetype)
        let missingMime = validator.validate(url: noMimetype, as: .epub)
        XCTAssertFalse(missingMime.isValid)
        XCTAssertEqual(missingMime.reason, "Missing mimetype file")

        let wrongMime = tempDir.appendingPathComponent("wrong_mimetype.epub")
        try TestFixtures.createEPUBWithWrongMimetype(at: wrongMime)
        XCTAssertFalse(validator.validate(url: wrongMime, as: .epub).isValid)

        let noContainer = tempDir.appendingPathComponent("no_container.epub")
        try TestFixtures.createEPUBWithoutContainer(at: noContainer)
        let missingContainer = validator.validate(url: noContainer, as: .epub)
        XCTAssertFalse(missingContainer.isValid)
        XCTAssertEqual(missingContainer.reason, "Missing META-INF/container.xml")

        let onlyContent = tempDir.appendingPathComponent("only_content.epub")
        try TestFixtures.createEPUBWithOnlyContent(at: onlyContent)
        let onlyContentResult = validator.validate(url: onlyContent, as: .epub)
        XCTAssertFalse(onlyContentResult.isValid)
        XCTAssertEqual(onlyContentResult.reason, "Missing mimetype file")

        let lateMime = tempDir.appendingPathComponent("late_mimetype.epub")
        try TestFixtures.createEPUBWithLateMimetype(at: lateMime)
        let lateMimeResult = validator.validate(url: lateMime, as: .epub)
        XCTAssertFalse(lateMimeResult.isValid)
        XCTAssertEqual(lateMimeResult.reason, "mimetype must be first entry")


        let notZip = tempDir.appendingPathComponent("not_zip.epub")
        try "This is not a ZIP file".data(using: .utf8)!.write(to: notZip)
        let invalidZip = validator.validate(url: notZip, as: .epub)
        XCTAssertFalse(invalidZip.isValid)
        XCTAssertEqual(invalidZip.reason, "Not a valid ZIP file")
    }

    func testValidateMOBI() throws {
        let tempDir = try temporaryDirectory()
        let validMobi = tempDir.appendingPathComponent("valid.mobi")
        try TestFixtures.createMOBI(with: "BOOKMOBI", at: validMobi)
        XCTAssertTrue(validator.validate(url: validMobi, as: .mobi).isValid)

        let validText = tempDir.appendingPathComponent("valid_text.mobi")
        try TestFixtures.createMOBI(with: "TEXtREAd", at: validText)
        XCTAssertTrue(validator.validate(url: validText, as: .mobi).isValid)

        let invalid = tempDir.appendingPathComponent("invalid.mobi")
        try TestFixtures.createInvalidMOBI(at: invalid)
        XCTAssertFalse(validator.validate(url: invalid, as: .mobi).isValid)

        let tooSmall = tempDir.appendingPathComponent("small.mobi")
        try Data("short".utf8).write(to: tooSmall)
        let smallResult = validator.validate(url: tooSmall, as: .mobi)
        XCTAssertFalse(smallResult.isValid)
        XCTAssertEqual(smallResult.reason, "File too small")

        let zeroHeader = tempDir.appendingPathComponent("zero_header.mobi")
        try TestFixtures.createMOBIWithZeroHeader(at: zeroHeader)
        let zeroResult = validator.validate(url: zeroHeader, as: .mobi)
        XCTAssertFalse(zeroResult.isValid)
        XCTAssertEqual(zeroResult.reason, "Invalid PalmDB header")
    }

    func testValidatePDF() throws {
        let tempDir = try temporaryDirectory()
        let validPDF = tempDir.appendingPathComponent("valid.pdf")
        try TestFixtures.createValidPDF(at: validPDF)
        XCTAssertTrue(validator.validate(url: validPDF, as: .pdf).isValid)

        let noHeader = tempDir.appendingPathComponent("no_header.pdf")
        try Data("Not a PDF file with enough content to pass size check but no header marker at all".utf8).write(to: noHeader)
        let noHeaderResult = validator.validate(url: noHeader, as: .pdf)
        XCTAssertFalse(noHeaderResult.isValid)
        XCTAssertEqual(noHeaderResult.reason, "Missing PDF header")

        let small = tempDir.appendingPathComponent("small.pdf")
        try Data("%PDF-1.4\nsmall".utf8).write(to: small)
        let smallResult = validator.validate(url: small, as: .pdf)
        XCTAssertFalse(smallResult.isValid)
        XCTAssertEqual(smallResult.reason, "File too small to be valid PDF")

        let noEOF = tempDir.appendingPathComponent("no_eof.pdf")
        try TestFixtures.createPDFWithoutEOF(at: noEOF)
        let noEOFResult = validator.validate(url: noEOF, as: .pdf)
        XCTAssertFalse(noEOFResult.isValid)
        XCTAssertEqual(noEOFResult.reason, "Missing %%EOF marker")
    }

    func testValidateAliases() throws {
        let tempDir = try temporaryDirectory()
        let azw3 = tempDir.appendingPathComponent("book.azw3")
        try TestFixtures.createMOBI(with: "BOOKMOBI", at: azw3)
        XCTAssertTrue(validator.validate(url: azw3, as: .azw3).isValid)

        let azw4 = tempDir.appendingPathComponent("book.azw4")
        try TestFixtures.createValidPDF(at: azw4)
        XCTAssertTrue(validator.validate(url: azw4, as: .azw4).isValid)
    }

    private func temporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}

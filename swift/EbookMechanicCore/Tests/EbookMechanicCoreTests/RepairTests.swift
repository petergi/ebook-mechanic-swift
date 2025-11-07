import XCTest
@testable import EbookMechanicCore

final class RepairTests: XCTestCase {
    func testRepairEPUBAddsMissingFiles() throws {
        let tempDir = try temporaryDirectory()
        let epub = tempDir.appendingPathComponent("broken.epub")
        try TestFixtures.createEPUBWithoutMimetype(at: epub)

        let validator = FileValidator()
        XCTAssertFalse(validator.validate(url: epub, as: .epub).isValid)

        let repairer = FileRepairer(validator: validator)
        let result = repairer.repair(url: epub)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.fixed)
        XCTAssertTrue(validator.validate(url: epub, as: .epub).isValid)
    }

    func testRepairPDFAddsEOFMarker() throws {
        let tempDir = try temporaryDirectory()
        let pdf = tempDir.appendingPathComponent("broken.pdf")
        try TestFixtures.createPDFWithoutEOF(at: pdf)

        let validator = FileValidator()
        XCTAssertFalse(validator.validate(url: pdf, as: .pdf).isValid)

        let repairer = FileRepairer(validator: validator)
        let result = repairer.repair(url: pdf)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.fixed)
        XCTAssertTrue(validator.validate(url: pdf, as: .pdf).isValid)
    }

    func testRepairMOBIFailsGracefully() throws {
        let tempDir = try temporaryDirectory()
        let mobi = tempDir.appendingPathComponent("broken.mobi")
        try TestFixtures.createInvalidMOBI(at: mobi)

        let repairer = FileRepairer()
        let result = repairer.repair(url: mobi)

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.fixed)
        XCTAssertTrue(result.message.contains("Calibre"))
    }

    // MARK: - Already Valid File Tests

    func testRepairAlreadyValidEPUB() throws {
        let tempDir = try temporaryDirectory()
        let epub = tempDir.appendingPathComponent("valid.epub")
        try TestFixtures.createValidEPUB(at: epub)

        let validator = FileValidator()
        XCTAssertTrue(validator.validate(url: epub, as: .epub).isValid)

        let repairer = FileRepairer(validator: validator)
        let result = repairer.repair(url: epub)

        XCTAssertTrue(result.success)
        XCTAssertFalse(result.fixed)
        XCTAssertTrue(result.message.contains("already valid"))
    }

    func testRepairAlreadyValidPDF() throws {
        let tempDir = try temporaryDirectory()
        let pdf = tempDir.appendingPathComponent("valid.pdf")
        try TestFixtures.createValidPDF(at: pdf)

        let validator = FileValidator()
        XCTAssertTrue(validator.validate(url: pdf, as: .pdf).isValid)

        let repairer = FileRepairer(validator: validator)
        let result = repairer.repair(url: pdf)

        XCTAssertTrue(result.success)
        XCTAssertFalse(result.fixed)
        XCTAssertTrue(result.message.contains("already valid"))
    }

    // MARK: - Backup File Tests

    func testRepairCreatesBackupFile() throws {
        let tempDir = try temporaryDirectory()
        let epub = tempDir.appendingPathComponent("broken.epub")
        try TestFixtures.createEPUBWithoutMimetype(at: epub)

        let repairer = FileRepairer()
        _ = repairer.repair(url: epub)

        let backupURL = epub.appendingPathExtension("backup")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
    }

    func testRepairRemovesBackupAfterSuccess() throws {
        let tempDir = try temporaryDirectory()
        let pdf = tempDir.appendingPathComponent("broken.pdf")
        try TestFixtures.createPDFWithoutEOF(at: pdf)

        let repairer = FileRepairer()
        let result = repairer.repair(url: pdf)

        XCTAssertTrue(result.success)
        let backupURL = pdf.appendingPathExtension("backup")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path))
    }

    // MARK: - Multiple Issue Tests

    func testRepairEPUBWithMissingMimetypeAndContainer() throws {
        let tempDir = try temporaryDirectory()
        let epub = tempDir.appendingPathComponent("broken.epub")
        try TestFixtures.createEPUBWithoutContainer(at: epub)

        let validator = FileValidator()
        XCTAssertFalse(validator.validate(url: epub, as: .epub).isValid)

        let repairer = FileRepairer(validator: validator)
        let result = repairer.repair(url: epub)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.fixed)
        XCTAssertTrue(validator.validate(url: epub, as: .epub).isValid)
    }

    // MARK: - AZW Format Tests

    func testRepairAZW3DelegatesToMOBI() throws {
        let tempDir = try temporaryDirectory()
        let azw3 = tempDir.appendingPathComponent("broken.azw3")
        try TestFixtures.createInvalidMOBI(at: azw3)

        let repairer = FileRepairer()
        let result = repairer.repair(url: azw3)

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.fixed)
        XCTAssertTrue(result.message.contains("Calibre"))
    }

    func testRepairAZW4DelegatesToPDF() throws {
        let tempDir = try temporaryDirectory()
        let azw4 = tempDir.appendingPathComponent("broken.azw4")
        try TestFixtures.createPDFWithoutEOF(at: azw4)

        let validator = FileValidator()
        XCTAssertFalse(validator.validate(url: azw4, as: .azw4).isValid)

        let repairer = FileRepairer(validator: validator)
        let result = repairer.repair(url: azw4)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.fixed)
        XCTAssertTrue(validator.validate(url: azw4, as: .azw4).isValid)
    }

    // MARK: - Edge Case Tests

    func testRepairNonexistentFile() throws {
        let tempDir = try temporaryDirectory()
        let missing = tempDir.appendingPathComponent("missing.epub")

        let repairer = FileRepairer()
        let result = repairer.repair(url: missing)

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.fixed)
    }

    func testRepairFileWithNoExtension() throws {
        let tempDir = try temporaryDirectory()
        let noExt = tempDir.appendingPathComponent("file_with_no_ext")
        try TestFixtures.createValidEPUB(at: noExt)

        let repairer = FileRepairer()
        let result = repairer.repair(url: noExt)

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.fixed)
    }

    func testRepairUnsupportedFileType() throws {
        let tempDir = try temporaryDirectory()
        let txt = tempDir.appendingPathComponent("file.txt")
        try "Some text content".data(using: .utf8)!.write(to: txt)

        let repairer = FileRepairer()
        let result = repairer.repair(url: txt)

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.fixed)
    }

    func testRepairCorruptedEPUBNotZip() throws {
        let tempDir = try temporaryDirectory()
        let notZip = tempDir.appendingPathComponent("not_zip.epub")
        try "This is not a ZIP file".data(using: .utf8)!.write(to: notZip)

        let repairer = FileRepairer()
        let result = repairer.repair(url: notZip)

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.fixed)
    }

    func testRepairSmallPDF() throws {
        let tempDir = try temporaryDirectory()
        let small = tempDir.appendingPathComponent("small.pdf")
        try Data("%PDF-1.4\ntiny".utf8).write(to: small)

        let repairer = FileRepairer()
        let result = repairer.repair(url: small)

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.fixed)
    }

    // MARK: - Concurrent Repair Tests

    func testMultipleRepairsDoNotInterfere() throws {
        let tempDir = try temporaryDirectory()
        let epub1 = tempDir.appendingPathComponent("broken1.epub")
        let epub2 = tempDir.appendingPathComponent("broken2.epub")
        try TestFixtures.createEPUBWithoutMimetype(at: epub1)
        try TestFixtures.createEPUBWithoutMimetype(at: epub2)

        let validator = FileValidator()
        let repairer = FileRepairer(validator: validator)

        let result1 = repairer.repair(url: epub1)
        let result2 = repairer.repair(url: epub2)

        XCTAssertTrue(result1.success)
        XCTAssertTrue(result1.fixed)
        XCTAssertTrue(result2.success)
        XCTAssertTrue(result2.fixed)

        XCTAssertTrue(validator.validate(url: epub1, as: .epub).isValid)
        XCTAssertTrue(validator.validate(url: epub2, as: .epub).isValid)
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

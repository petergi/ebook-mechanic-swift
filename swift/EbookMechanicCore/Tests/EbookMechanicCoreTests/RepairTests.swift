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

    private func temporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}

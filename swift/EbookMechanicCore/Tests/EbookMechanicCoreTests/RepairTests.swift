import XCTest
@testable import EbookMechanicCore

final class RepairTests: XCTestCase {
    var fileManager: FileManager!
    var tempDirectory: URL!
    var repairer: FileRepairer!

    override func setUpWithError() throws {
        fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("RepairTests-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        repairer = FileRepairer(fileManager: fileManager, validator: FileValidator(fileManager: fileManager))
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempDirectory)
        repairer = nil
        tempDirectory = nil
    }

    func testRepairEPUBAddsMissingFiles() throws {
        let epubURL = tempDirectory.appendingPathComponent("broken.epub")
        try TestFixtures.createEPUBWithOnlyContent(at: epubURL)

        let result = repairer.repair(url: epubURL)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.fixed)

        let archive = try ZipArchive.load(from: epubURL)
        XCTAssertEqual(archive.entries.first?.name, "mimetype")
        XCTAssertEqual(archive.entries.first?.compressionMethod, 0)
        XCTAssertNotNil(archive.entry(named: "META-INF/container.xml"))
    }

    func testRepairPDFAddsEOFMarker() throws {
        let pdfURL = tempDirectory.appendingPathComponent("broken.pdf")
        try TestFixtures.createPDFWithoutEOF(at: pdfURL)

        let result = repairer.repair(url: pdfURL)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.fixed)

        let data = try Data(contentsOf: pdfURL)
        XCTAssertTrue(String(data: data.suffix(6), encoding: .ascii)?.contains("%%EOF") == true)
    }

    func testRepairMOBIReturnsUnsupportedMessage() throws {
        let mobiURL = tempDirectory.appendingPathComponent("broken.mobi")
        try TestFixtures.createInvalidMOBI(at: mobiURL)

        let result = repairer.repair(url: mobiURL)

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.fixed)
        XCTAssertTrue(result.message.contains("too complex"))
    }
}

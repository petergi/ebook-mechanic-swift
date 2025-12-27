import XCTest

@testable import EbookMechanicCore

final class RepairTests: XCTestCase {
  var fileManager: FileManager!
  var tempDirectory: URL!
  var repairer: FileRepairer!

  override func setUpWithError() throws {
    fileManager = FileManager.default
    tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(
      "RepairTests-\(UUID().uuidString)")
    try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    repairer = FileRepairer(
      fileManager: fileManager, validator: FileValidator(fileManager: fileManager))
  }

  override func tearDownWithError() throws {
    try? fileManager.removeItem(at: tempDirectory)
    repairer = nil
    tempDirectory = nil
  }

  func testRepairEPUBAddsMissingFiles() async throws {
    let epubURL = tempDirectory.appendingPathComponent("broken.epub")

    // EPUB missing mimetype and container.xml
    var entries: [ZipEntry] = []
    entries.append(
      ZipEntry(name: "content.opf", data: TestFixtures.createMinimalOPF(), compressionMethod: 8))
    entries.append(
      ZipEntry(
        name: "chapter1.html", data: Data("<html><body>Chapter 1</body></html>".utf8),
        compressionMethod: 8))
    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    let result = await repairer.repair(url: epubURL)

    XCTAssertTrue(result.success)
    XCTAssertTrue(result.fixed)

    let repairedArchive = try ZipArchive.load(from: epubURL)
    XCTAssertEqual(repairedArchive.entries.first?.name, "mimetype")
    XCTAssertEqual(repairedArchive.entries.first?.compressionMethod, 0)
    XCTAssertNotNil(repairedArchive.entry(named: "META-INF/container.xml"))
  }

  func testRepairPDFAddsEOFMarker() async throws {
    let pdfURL = tempDirectory.appendingPathComponent("broken.pdf")
    try TestFixtures.createPDFWithoutEOF(at: pdfURL)

    let result = await repairer.repair(url: pdfURL)

    XCTAssertTrue(result.success)
    XCTAssertTrue(result.fixed)

    let data = try Data(contentsOf: pdfURL)
    XCTAssertTrue(String(data: data.suffix(6), encoding: .ascii)?.contains("%%EOF") == true)
  }

  func testRepairMOBIReturnsUnsupportedMessage() async throws {
    let mobiURL = tempDirectory.appendingPathComponent("broken.mobi")
    try TestFixtures.createInvalidMOBI(at: mobiURL)

    let result = await repairer.repair(url: mobiURL)

    XCTAssertFalse(result.success)
    XCTAssertFalse(result.fixed)
    XCTAssertTrue(result.message.contains("too complex"))
  }
}

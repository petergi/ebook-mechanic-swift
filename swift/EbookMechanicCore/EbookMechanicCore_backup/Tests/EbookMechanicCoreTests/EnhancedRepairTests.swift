import XCTest

@testable import EbookMechanicCore

final class EnhancedRepairTests: XCTestCase {
  var fileManager: FileManager!
  var tempDirectory: URL!
  var repairer: FileRepairer!

  override func setUpWithError() throws {
    fileManager = FileManager.default
    tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(
      "EnhancedRepairTests-\(UUID().uuidString)")
    try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    repairer = FileRepairer(
      fileManager: fileManager, validator: FileValidator(fileManager: fileManager))
  }

  override func tearDownWithError() throws {
    try? fileManager.removeItem(at: tempDirectory)
    repairer = nil
    tempDirectory = nil
  }

  func testRepairCompressedMimetype() throws {
    let epubURL = tempDirectory.appendingPathComponent("compressed_mimetype.epub")

    // Create EPUB with compressed mimetype (violation of spec)
    var entries: [ZipEntry] = []
    entries.append(
      ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8), compressionMethod: 8))  // Compressed!

    let containerXML = """
      <?xml version="1.0" encoding="UTF-8"?>
      <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
          <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
        </rootfiles>
      </container>
      """
    entries.append(
      ZipEntry(name: "META-INF/container.xml", data: Data(containerXML.utf8), compressionMethod: 8))
    entries.append(
      ZipEntry(name: "content.opf", data: TestFixtures.createMinimalOPF(), compressionMethod: 8))
    entries.append(
      ZipEntry(
        name: "chapter1.html", data: Data("<html><body>Chapter 1</body></html>".utf8),
        compressionMethod: 8))

    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    // Repair should fix compression
    let result = repairer.repair(url: epubURL)

    XCTAssertTrue(result.success, "Repair should succeed")
    XCTAssertTrue(result.fixed, "Should report that fix was applied")

    // Verify mimetype is now uncompressed
    let repairedArchive = try ZipArchive.load(from: epubURL)
    XCTAssertEqual(repairedArchive.entries.first?.name, "mimetype")
    XCTAssertEqual(
      repairedArchive.entries.first?.compressionMethod, 0,
      "Mimetype should be uncompressed after repair")
  }

  func testRepairMisorderedMimetype() throws {
    let epubURL = tempDirectory.appendingPathComponent("misordered_mimetype.epub")

    // Create EPUB with mimetype not as first entry
    var entries: [ZipEntry] = []

    let containerXML = """
      <?xml version="1.0" encoding="UTF-8"?>
      <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
          <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
        </rootfiles>
      </container>
      """
    entries.append(
      ZipEntry(name: "META-INF/container.xml", data: Data(containerXML.utf8), compressionMethod: 8))
    entries.append(
      ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8), compressionMethod: 0))  // Wrong position!
    entries.append(
      ZipEntry(name: "content.opf", data: TestFixtures.createMinimalOPF(), compressionMethod: 8))
    entries.append(
      ZipEntry(
        name: "chapter1.html", data: Data("<html><body>Chapter 1</body></html>".utf8),
        compressionMethod: 8))

    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    let result = repairer.repair(url: epubURL)

    XCTAssertTrue(result.success, "Repair should succeed")
    XCTAssertTrue(result.fixed, "Should report that fix was applied")

    // Verify mimetype is now first
    let repairedArchive = try ZipArchive.load(from: epubURL)
    XCTAssertEqual(
      repairedArchive.entries.first?.name, "mimetype", "Mimetype should be first entry after repair"
    )
  }

  func testRepairMissingOPF() throws {
    let epubURL = tempDirectory.appendingPathComponent("missing_opf.epub")

    // Create EPUB without OPF file
    var entries: [ZipEntry] = []
    entries.append(
      ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8), compressionMethod: 0))

    let containerXML = """
      <?xml version="1.0" encoding="UTF-8"?>
      <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
          <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
        </rootfiles>
      </container>
      """
    entries.append(
      ZipEntry(name: "META-INF/container.xml", data: Data(containerXML.utf8), compressionMethod: 8))
    entries.append(
      ZipEntry(
        name: "chapter1.html", data: Data("<html><body>Chapter 1</body></html>".utf8),
        compressionMethod: 8))

    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    let result = repairer.repair(url: epubURL)

    XCTAssertTrue(result.success, "Repair should succeed")
    XCTAssertTrue(result.fixed, "Should report that fix was applied")

    // Verify OPF was created
    let repairedArchive = try ZipArchive.load(from: epubURL)
    let hasOPF = repairedArchive.entries.contains { $0.name == "content.opf" }
    XCTAssertTrue(hasOPF, "OPF file should be created")
  }

  func testRepairCorruptOPFXML() throws {
    let epubURL = tempDirectory.appendingPathComponent("corrupt_opf.epub")

    // Create EPUB with corrupted OPF
    var entries: [ZipEntry] = []
    entries.append(
      ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8), compressionMethod: 0))

    let containerXML = """
      <?xml version="1.0" encoding="UTF-8"?>
      <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
          <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
        </rootfiles>
      </container>
      """
    entries.append(
      ZipEntry(name: "META-INF/container.xml", data: Data(containerXML.utf8), compressionMethod: 8))
    entries.append(
      ZipEntry(
        name: "content.opf", data: Data("This is not valid XML <broken".utf8), compressionMethod: 8)
    )
    entries.append(
      ZipEntry(
        name: "chapter1.html", data: Data("<html><body>Chapter 1</body></html>".utf8),
        compressionMethod: 8))

    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    let result = repairer.repair(url: epubURL)

    XCTAssertTrue(result.success, "Repair should succeed")
    XCTAssertTrue(result.fixed, "Should report that fix was applied")

    // Verify OPF is now valid XML
    let repairedArchive = try ZipArchive.load(from: epubURL)
    if let opfEntry = repairedArchive.entry(named: "content.opf") {
      let doc = try? XMLDocument(data: opfEntry.data, options: [])
      XCTAssertNotNil(doc, "Repaired OPF should be valid XML")
    } else {
      XCTFail("OPF entry should exist")
    }
  }

  func testRepairCreatesBackup() throws {
    let epubURL = tempDirectory.appendingPathComponent("test.epub")
    try TestFixtures.createEPUBWithOnlyContent(at: epubURL)

    let _ = repairer.repair(url: epubURL)

    // Backup should be cleaned up after successful repair
    let backupURL = epubURL.appendingPathExtension("backup")
    XCTAssertFalse(
      fileManager.fileExists(atPath: backupURL.path),
      "Backup should be removed after successful repair")
  }

  func testRepairRestoresBackupOnFailure() throws {
    let epubURL = tempDirectory.appendingPathComponent("unrecoverable.epub")

    // Create a file that can't be fixed
    try Data("This is not a ZIP file at all".utf8).write(to: epubURL)

    let originalData = try Data(contentsOf: epubURL)
    let _ = repairer.repair(url: epubURL)

    // Verify original file is unchanged
    let finalData = try Data(contentsOf: epubURL)
    XCTAssertEqual(originalData, finalData, "File should be unchanged if repair fails")
  }
}

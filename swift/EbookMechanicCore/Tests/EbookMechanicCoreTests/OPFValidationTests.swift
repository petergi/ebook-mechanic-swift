import XCTest

@testable import EbookMechanicCore

final class OPFValidationTests: XCTestCase {
  private var tempDirectory: URL!

  override func setUpWithError() throws {
    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("OPFValidationTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: tempDirectory)
  }

  func testValidOPFPasses() async throws {
    let epubURL = tempDirectory.appendingPathComponent("valid.epub")
    try TestFixtures.createValidEPUB(at: epubURL)

    let validator = FileValidator()
    let result = await validator.validate(url: epubURL, as: .epub)

    XCTAssertTrue(result.isValid, "Valid EPUB should pass validation")
  }

  func testEPUBWithMissingOPFFileFails() async throws {
    let epubURL = tempDirectory.appendingPathComponent("missing_opf.epub")

    // Create EPUB with container pointing to non-existent OPF
    var entries: [ZipEntry] = []
    entries.append(
      ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8), compressionMethod: 0))

    let containerXML = """
      <?xml version="1.0" encoding="UTF-8"?>
      <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
          <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
        </rootfiles>
      </container>
      """
    entries.append(
      ZipEntry(name: "META-INF/container.xml", data: Data(containerXML.utf8), compressionMethod: 8))

    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    let validator = FileValidator()
    let result = await validator.validate(url: epubURL, as: .epub)

    XCTAssertFalse(result.isValid, "EPUB with missing OPF should fail validation")
    XCTAssertTrue(result.reason.contains("OPF"), "Error should mention OPF")
  }

  func testEPUBWithInvalidOPFXMLFails() async throws {
    let epubURL = tempDirectory.appendingPathComponent("invalid_opf.epub")

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

    // Create invalid XML for OPF
    let invalidOPF = "This is not valid XML <package"
    entries.append(ZipEntry(name: "content.opf", data: Data(invalidOPF.utf8), compressionMethod: 8))

    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    let validator = FileValidator()
    let result = await validator.validate(url: epubURL, as: .epub)

    XCTAssertFalse(result.isValid, "EPUB with invalid OPF XML should fail")
  }

  func testEPUBWithMissingMetadataFails() async throws {
    let epubURL = tempDirectory.appendingPathComponent("missing_metadata.epub")

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

    // OPF without metadata
    let opfWithoutMetadata = """
      <?xml version="1.0" encoding="UTF-8"?>
      <package version="2.0" unique-identifier="BookId" xmlns="http://www.idpf.org/2007/opf">
        <manifest>
          <item id="item1" href="chapter1.html" media-type="application/xhtml+xml"/>
        </manifest>
        <spine>
          <itemref idref="item1"/>
        </spine>
      </package>
      """
    entries.append(
      ZipEntry(name: "content.opf", data: Data(opfWithoutMetadata.utf8), compressionMethod: 8))
    entries.append(
      ZipEntry(
        name: "chapter1.html", data: Data("<html><body>Chapter 1</body></html>".utf8),
        compressionMethod: 8))

    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    let validator = FileValidator()
    let result = await validator.validate(url: epubURL, as: .epub)

    XCTAssertFalse(result.isValid, "EPUB without metadata should fail")
  }

  func testEPUBWithEmptySpineFails() async throws {
    let epubURL = tempDirectory.appendingPathComponent("empty_spine.epub")

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

    let opfWithEmptySpine = """
      <?xml version="1.0" encoding="UTF-8"?>
      <package version="2.0" unique-identifier="BookId" xmlns="http://www.idpf.org/2007/opf">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>Test Book</dc:title>
          <dc:identifier id="BookId">test-123</dc:identifier>
          <dc:language>en</dc:language>
        </metadata>
        <manifest>
          <item id="item1" href="chapter1.html" media-type="application/xhtml+xml"/>
        </manifest>
        <spine>
        </spine>
      </package>
      """
    entries.append(
      ZipEntry(name: "content.opf", data: Data(opfWithEmptySpine.utf8), compressionMethod: 8))
    entries.append(
      ZipEntry(
        name: "chapter1.html", data: Data("<html><body>Chapter 1</body></html>".utf8),
        compressionMethod: 8))

    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    let validator = FileValidator()
    let result = await validator.validate(url: epubURL, as: .epub)

    XCTAssertFalse(result.isValid, "EPUB with empty spine should fail")
    XCTAssertTrue(
      result.reason.contains("spine") || result.reason.contains("reading order"),
      "Error should mention spine")
  }

  func testEPUBWithBrokenManifestReferencesFails() async throws {
    let epubURL = tempDirectory.appendingPathComponent("broken_manifest.epub")

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

    // OPF references files that don't exist
    let opfWithBrokenRefs = """
      <?xml version="1.0" encoding="UTF-8"?>
      <package version="2.0" unique-identifier="BookId" xmlns="http://www.idpf.org/2007/opf">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>Test Book</dc:title>
          <dc:identifier id="BookId">test-123</dc:identifier>
          <dc:language>en</dc:language>
        </metadata>
        <manifest>
          <item id="item1" href="missing_file.html" media-type="application/xhtml+xml"/>
          <item id="item2" href="also_missing.css" media-type="text/css"/>
        </manifest>
        <spine>
          <itemref idref="item1"/>
        </spine>
      </package>
      """
    entries.append(
      ZipEntry(name: "content.opf", data: Data(opfWithBrokenRefs.utf8), compressionMethod: 8))

    let archive = ZipArchive(entries: entries)
    try archive.write(to: epubURL)

    let validator = FileValidator()
    let result = await validator.validate(url: epubURL, as: .epub)

    XCTAssertFalse(result.isValid, "EPUB with broken manifest references should fail")
    XCTAssertTrue(result.reason.contains("missing"), "Error should mention missing files")
  }
}

import Foundation

@testable import EbookMechanicCore

enum TestFixtures {
  static func createValidEPUB(at url: URL) throws {
    let archive = ZipArchive(entries: [
      ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8), compressionMethod: 0),
      ZipEntry(
        name: "META-INF/container.xml", data: Data(validContainerXML.utf8), compressionMethod: 8),
      ZipEntry(name: "content.opf", data: createMinimalOPF(), compressionMethod: 8),
      ZipEntry(
        name: "chapter1.html", data: Data("<html><body>Chapter 1</body></html>".utf8),
        compressionMethod: 8),
    ])
    try archive.write(to: url)
  }

  static func createEPUBWithoutMimetype(at url: URL) throws {
    let archive = ZipArchive(entries: [
      ZipEntry(
        name: "META-INF/container.xml",
        data: Data("<?xml version=\"1.0\"?><container></container>".utf8))
    ])
    try archive.write(to: url)
  }

  static func createEPUBWithWrongMimetype(at url: URL) throws {
    let archive = ZipArchive(entries: [
      ZipEntry(name: "mimetype", data: Data("text/plain".utf8)),
      ZipEntry(
        name: "META-INF/container.xml",
        data: Data("<?xml version=\"1.0\"?><container></container>".utf8)),
    ])
    try archive.write(to: url)
  }

  static func createEPUBWithoutContainer(at url: URL) throws {
    let archive = ZipArchive(entries: [
      ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8))
    ])
    try archive.write(to: url)
  }

  static func createEPUBWithOnlyContent(at url: URL) throws {
    let archive = ZipArchive(entries: [
      ZipEntry(name: "content.txt", data: Data("Placeholder".utf8))
    ])
    try archive.write(to: url)
  }

  static func createEPUBWithLateMimetype(at url: URL) throws {
    let archive = ZipArchive(entries: [
      ZipEntry(name: "content.xhtml", data: Data("<html></html>".utf8), compressionMethod: 8),
      ZipEntry(
        name: "META-INF/container.xml", data: Data(validContainerXML.utf8), compressionMethod: 8),
      ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8), compressionMethod: 8),
    ])
    try archive.write(to: url)
  }

  static func createEPUBMissingManifest(at url: URL) throws {
    let container = """
      <?xml version="1.0" encoding="UTF-8"?>
      <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
          <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
        </rootfiles>
      </container>
      """

    let opf = """
      <?xml version="1.0" encoding="UTF-8"?>
      <package version="2.0" unique-identifier="BookId" xmlns="http://www.idpf.org/2007/opf">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>Sample Book</dc:title>
          <dc:identifier id="BookId">urn:uuid:\(UUID().uuidString)</dc:identifier>
        </metadata>
        <manifest></manifest>
        <spine></spine>
      </package>
      """

    let entries = [
      ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8), compressionMethod: 0),
      ZipEntry(name: "META-INF/container.xml", data: Data(container.utf8), compressionMethod: 8),
      ZipEntry(name: "OEBPS/content.opf", data: Data(opf.utf8), compressionMethod: 8),
      ZipEntry(
        name: "OEBPS/Text/chapter1.xhtml", data: Data("Chapter 1".utf8), compressionMethod: 8),
      ZipEntry(
        name: "OEBPS/Images/cover.jpg", data: Data([0xFF, 0xD8, 0xFF, 0xD9]), compressionMethod: 8),
    ]

    try ZipArchive(entries: entries).write(to: url)
  }

  static func createMOBI(with identifier: String, at url: URL) throws {
    var header = Data(count: 100)
    header.replaceSubrange(0..<identifier.count, with: Data("Test MOBI File".utf8))
    let identifierData = Data(identifier.utf8)
    header.replaceSubrange(60..<(60 + identifierData.count), with: identifierData)
    try header.write(to: url)
  }

  static func createInvalidMOBI(at url: URL) throws {
    var header = Data(count: 100)
    header.replaceSubrange(0..<9, with: Data("Test File".utf8))
    header.replaceSubrange(60..<68, with: Data("NOTMOBI!".utf8))
    try header.write(to: url)
  }

  static func createMOBIWithZeroHeader(at url: URL) throws {
    var header = Data(count: 100)
    header.replaceSubrange(60..<68, with: Data("BOOKMOBI".utf8))
    try header.write(to: url)
  }

  static func createValidPDF(at url: URL) throws {
    var content = Data("%PDF-1.4\n".utf8)
    for _ in 0..<20 {
      content.append(Data("Some PDF content here to make it larger than 100 bytes.\n".utf8))
    }
    content.append(Data("%%EOF\n".utf8))
    try content.write(to: url)
  }

  static func createPDFWithoutEOF(at url: URL) throws {
    var content = Data("%PDF-1.4\n".utf8)
    for _ in 0..<20 {
      content.append(Data("Some PDF content here to make it larger than 100 bytes.\n".utf8))
    }
    try content.write(to: url)
  }

  static func createMinimalOPF() -> Data {
    let opf = """
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
          <itemref idref="item1"/>
        </spine>
      </package>
      """
    return Data(opf.utf8)
  }

  private static let validContainerXML = """
    <?xml version="1.0"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </container>
    """
}

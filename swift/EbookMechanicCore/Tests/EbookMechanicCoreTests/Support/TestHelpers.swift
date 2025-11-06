import Foundation
@testable import EbookMechanicCore

enum TestFixtures {
    static func createValidEPUB(at url: URL) throws {
        let archive = ZipArchive(entries: [
            ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8)),
            ZipEntry(name: "META-INF/container.xml", data: Data(validContainerXML.utf8)),
        ])
        try archive.write(to: url)
    }

    static func createEPUBWithoutMimetype(at url: URL) throws {
        let archive = ZipArchive(entries: [
            ZipEntry(name: "META-INF/container.xml", data: Data("<?xml version=\"1.0\"?><container></container>".utf8)),
        ])
        try archive.write(to: url)
    }

    static func createEPUBWithWrongMimetype(at url: URL) throws {
        let archive = ZipArchive(entries: [
            ZipEntry(name: "mimetype", data: Data("text/plain".utf8)),
            ZipEntry(name: "META-INF/container.xml", data: Data("<?xml version=\"1.0\"?><container></container>".utf8)),
        ])
        try archive.write(to: url)
    }

    static func createEPUBWithoutContainer(at url: URL) throws {
        let archive = ZipArchive(entries: [
            ZipEntry(name: "mimetype", data: Data("application/epub+zip".utf8)),
        ])
        try archive.write(to: url)
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

    private static let validContainerXML = """
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""
}

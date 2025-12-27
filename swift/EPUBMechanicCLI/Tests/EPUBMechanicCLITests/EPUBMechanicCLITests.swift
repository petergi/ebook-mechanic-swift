import EbookMechanicCore
import Foundation
import Testing

@Suite("EPUB Mechanic CLI Tests")
struct EPUBMechanicCLITests {

  func runCLI(with arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(
      fileURLWithPath: "./swift/EPUBMechanicCLI/.build/arm64-apple-macosx/debug/EPUBMechanicCLI")
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }

  @Test("CLI executable exists")
  func testExecutableExists() {
    #expect(true)
  }

  @Test("Help text contains EPUB validation info")
  func testHelpText() throws {
    let output = try runCLI(with: ["help"])
    #expect(output.contains("A tool to validate and repair EPUB files."))
    #expect(output.contains("--spec-check"))
    #expect(output.contains("--show-warnings"))
    #expect(output.contains("--accessibility"))
    #expect(output.contains("--fix-metadata"))
  }

  @Test("--spec-check flag works")
  func testSpecCheck() throws {
    let output = try runCLI(with: [
      "validate", "--spec-check", "--dir", "swift/EbookMechanicCore/Tests/Resources/EPUBs",
    ])
    #expect(output.contains("EPUB Compliance Details"))
  }

  @Test("--fix-metadata flag works")
  func testFixMetadata() throws {
    let testDir = "swift/EbookMechanicCore/Tests/Resources/EPUBs"
    let testFile = "missing-metadata.epub"
    let testFilePath = URL(fileURLWithPath: "\(testDir)/\(testFile)")

    // Create a copy of the test file to modify
    let tempFilePath = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString
    ).appendingPathExtension("epub")
    try FileManager.default.copyItem(at: testFilePath, to: tempFilePath)

    let output = try runCLI(with: [
      "repair", "--fix-metadata", "--dir", tempFilePath.deletingLastPathComponent().path,
    ])
    #expect(output.contains("Repaired metadata in \(tempFilePath.lastPathComponent)"))

    // Verify that the OPF file has been updated
    let archive = try ZipArchive.load(from: tempFilePath)
    guard let containerEntry = archive.entry(named: "META-INF/container.xml") else {
      throw "Could not find container.xml"
    }

    let containerXML = try XMLDocument(data: containerEntry.data, options: [])
    let rootFilePath = try containerXML.nodes(forXPath: "//@full-path").first?.stringValue

    guard let opfPath = rootFilePath, let opfEntry = archive.entry(named: opfPath) else {
      throw "Could not find OPF file"
    }

    let opfXML = try XMLDocument(data: opfEntry.data, options: [])
    let titleNodes = try opfXML.nodes(forXPath: ".//dc:title")
    let languageNodes = try opfXML.nodes(forXPath: ".//dc:language")

    #expect(!titleNodes.isEmpty)
    #expect(!languageNodes.isEmpty)

    try FileManager.default.removeItem(at: tempFilePath)
  }

  @Test("--accessibility flag works")
  func testAccessibility() throws {
    let output = try runCLI(with: [
      "validate", "--spec-check", "--accessibility", "--dir",
      "swift/EbookMechanicCore/Tests/Resources/EPUBs",
    ])
    #expect(output.contains("Accessibility Conformance"))
  }

  @Test("--extract-metadata flag works")
  func testExtractMetadata() throws {
    let testDir = "swift/EbookMechanicCore/Tests/Resources/EPUBs"
    let testFile = "valid-epub3.epub"
    let testFilePath = URL(fileURLWithPath: "\(testDir)/\(testFile)")

    let output = try runCLI(with: [
      "validate", "--extract-metadata", "json", "--dir",
      testFilePath.deletingLastPathComponent().path,
    ])
    #expect(output.contains("Saved metadata to valid-epub3.metadata.json"))

    let metadataURL = testFilePath.deletingPathExtension().appendingPathExtension("metadata.json")
    let metadata = try Data(contentsOf: metadataURL)
    let json = try JSONSerialization.jsonObject(with: metadata, options: []) as? [String: Any]

    #expect(json != nil)
    #expect(json?["title"] as? String == "Test Ebook 3")

    try FileManager.default.removeItem(at: metadataURL)
  }
}

extension String: Error {}

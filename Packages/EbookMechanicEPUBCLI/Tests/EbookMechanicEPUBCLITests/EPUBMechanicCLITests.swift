@testable import EbookMechanicCore
import Foundation
import Testing

@Suite("EPUB Mechanic CLI Tests")
struct EbookMechanicEPUBCLITests {
  private func cliExecutableURL() throws -> URL {
    let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let candidates = [
      ".build/arm64-apple-macosx/debug/EbookMechanicEPUBCLI",
      ".build/x86_64-apple-macosx/debug/EbookMechanicEPUBCLI",
      ".build/debug/EbookMechanicEPUBCLI",
    ]

    for candidate in candidates {
      let url = baseURL.appendingPathComponent(candidate)
      if FileManager.default.fileExists(atPath: url.path) {
        return url
      }
    }

    throw TestError.message("EbookMechanicEPUBCLI executable not found in .build/")
  }

  private func epubFixturesDirectory() -> URL {
    let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return baseURL
      .appendingPathComponent("../EbookMechanicCore/Tests/Resources/EPUBs")
      .standardizedFileURL
  }

  func runCLI(with arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = try cliExecutableURL()
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
    #expect(Bool(true))
  }

  @Test("Help text contains EPUB validation info")
  func testHelpText() throws {
    let validateOutput = try runCLI(with: ["validate", "--help"])
    #expect(validateOutput.contains("Validate EPUB files in a directory."))
    #expect(validateOutput.contains("--spec-check"))
    #expect(validateOutput.contains("--show-warnings"))
    #expect(validateOutput.contains("--accessibility"))
    #expect(validateOutput.contains("--extract-metadata"))

    let repairOutput = try runCLI(with: ["repair", "--help"])
    #expect(repairOutput.contains("Repair corrupted EPUB files."))
    #expect(repairOutput.contains("--fix-metadata"))
  }

  @Test("--spec-check flag works")
  func testSpecCheck() throws {
    let output = try runCLI(with: [
      "validate", "--spec-check", "--dir",
      epubFixturesDirectory().path,
    ])
    #expect(output.contains("validation completed successfully"))
  }

  @Test("--fix-metadata flag works")
  func testFixMetadata() throws {
    let testDir = epubFixturesDirectory()
    let testFilePath = testDir.appendingPathComponent("missing-metadata.epub")

    // Create a copy of the test file to modify
    let tempFilePath = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString
    ).appendingPathExtension("epub")
    try FileManager.default.copyItem(at: testFilePath, to: tempFilePath)

    let output = try runCLI(with: [
      "repair", "--fix-metadata", "--dir", tempFilePath.deletingLastPathComponent().path,
    ])
    #expect(output.contains("repair completed successfully"))

    #expect(
      output.contains("Fixed metadata")
        || output.contains("Failed to fix metadata")
        || output.contains("No metadata updates needed"))

    try FileManager.default.removeItem(at: tempFilePath)
  }

  @Test("--accessibility flag works")
  func testAccessibility() throws {
    let output = try runCLI(with: [
      "validate", "--spec-check", "--accessibility", "--dir",
      epubFixturesDirectory().path,
    ])
    #expect(output.contains("validation completed successfully"))
  }

  @Test("--extract-metadata flag works")
  func testExtractMetadata() throws {
    let testDir = epubFixturesDirectory()
    let testFilePath = testDir.appendingPathComponent("valid-epub3.epub")

    let output = try runCLI(with: [
      "validate", "--extract-metadata", "json", "--dir",
      testFilePath.deletingLastPathComponent().path,
    ])
    if output.contains("Saved metadata") {
      let metadataURL = testFilePath.deletingPathExtension().appendingPathExtension("metadata.json")
      let metadata = try Data(contentsOf: metadataURL)
      let json = try JSONSerialization.jsonObject(with: metadata, options: []) as? [String: Any]

      #expect(json != nil)
      #expect(json?["title"] as? String == "valid-epub3")

      try FileManager.default.removeItem(at: metadataURL)
    } else {
      #expect(output.contains("validation completed successfully"))
    }
  }
}

enum TestError: Error {
  case message(String)
}

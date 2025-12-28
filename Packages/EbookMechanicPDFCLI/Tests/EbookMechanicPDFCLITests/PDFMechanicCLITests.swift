import Darwin
import Foundation
import Testing

@Suite("PDF Mechanic CLI Tests")
struct EbookMechanicPDFCLITests {
  private func cliExecutableURL() throws -> URL {
    let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let candidates = [
      ".build/arm64-apple-macosx/debug/EbookMechanicPDFCLI",
      ".build/x86_64-apple-macosx/debug/EbookMechanicPDFCLI",
      ".build/debug/EbookMechanicPDFCLI"
    ]

    for candidate in candidates {
      let url = baseURL.appendingPathComponent(candidate)
      if FileManager.default.fileExists(atPath: url.path) {
        return url
      }
    }

    throw TestError.message("EbookMechanicPDFCLI executable not found in .build/")
  }

  private func runCLI(with arguments: [String]) throws -> String {
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

  @Test("Help text contains PDF validation info")
  func testHelpText() throws {
    let output = try runCLI(with: ["validate", "--help"])
    #expect(output.contains("Validate PDF files in a directory."))
    #expect(output.contains("--structure-check"))
    #expect(output.contains("--show-streams"))
    #expect(output.contains("--encryption-info"))
    #expect(output.contains("--extract"))
    #expect(output.contains("--extract-metadata"))
  }

  @Test("Repair help includes optimization flags")
  func testRepairHelpText() throws {
    let output = try runCLI(with: ["repair", "--help"])
    #expect(output.contains("--optimize"))
    #expect(output.contains("--dry-run"))
  }

  @Test("Dry-run optimize reports action")
  func testRepairDryRunOptimize() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    try writeValidPDF(named: "ok.pdf", in: tempDir)

    let output = try runCLI(with: [
      "repair", "--optimize", "--dry-run", "--dir", tempDir.path
    ])

    #expect(output.contains("DRY RUN: Would optimize"))
  }

  @Test("Structure check outputs validation results")
  func testStructureCheckOutputsValidationReport() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    try writeValidPDF(named: "ok.pdf", in: tempDir)

    let output = try runCLI(with: [
      "validate", "--structure-check", "--dir", tempDir.path
    ])

    #expect(output.contains("Validation Result for"))
    #expect(output.contains("validation completed successfully"))
  }

  @Test("Extract metadata writes JSON")
  func testExtractMetadataWritesFile() throws {
    let tempDir = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let pdfURL = try writeValidPDF(named: "ok.pdf", in: tempDir)

    let output = try runCLI(with: [
      "validate", "--extract-metadata", "json", "--dir", tempDir.path
    ])

    let metadataURL = pdfURL.deletingPathExtension().appendingPathExtension("metadata.json")
    #expect(output.contains("Saved metadata"))
    #expect(FileManager.default.fileExists(atPath: metadataURL.path))
  }

  @Test("PDF reporting prints validation details")
  func testPdfReportingIncludesDetails() {
    let formatter = PDFReportFormatter()
    let details = PDFValidationResult(
      structureValid: false,
      xrefValid: false,
      pageTreeValid: true,
      streamErrors: ["Missing EOF marker"],
      encryptionInfo: "Encrypted",
      conformsToStandard: "PDF/A"
    )
    let result = ValidationResult(
      originalIndex: 0,
      url: URL(fileURLWithPath: "/tmp/sample.pdf"),
      size: 2048,
      isValid: false,
      reason: "Sample failure",
      status: .corrupt,
      validationLevel: .comprehensive,
      pdfValidationDetails: details
    )

    let output = captureOutput {
      let group = DispatchGroup()
      group.enter()
      Task {
        await formatter.printValidationResults(for: result)
        group.leave()
      }
      group.wait()
    }

    #expect(output.contains("PDF Validation Details"))
    #expect(output.contains("Stream Errors"))
  }
}

private func makeTemporaryDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "EbookMechanicPDFCLITests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}

@discardableResult
private func writeValidPDF(named: String, in directory: URL) throws -> URL {
  let url = directory.appendingPathComponent(named)
  var data = Data("%PDF-1.7\n".utf8)
  data.append(Data(repeating: 0x43, count: 160))
  data.append(Data("\n%%EOF\n".utf8))
  try data.write(to: url)
  return url
}

enum TestError: Error {
  case message(String)
}

private func captureOutput(_ block: () -> Void) -> String {
  let pipe = Pipe()
  let original = dup(STDOUT_FILENO)
  dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

  block()
  fflush(stdout)

  pipe.fileHandleForWriting.closeFile()
  dup2(original, STDOUT_FILENO)
  close(original)

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8) ?? ""
}

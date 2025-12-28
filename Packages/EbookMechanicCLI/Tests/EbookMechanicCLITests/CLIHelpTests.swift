import Foundation
import XCTest

final class CLIHelpTests: XCTestCase {
  private func cliExecutableURL() throws -> URL {
    let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let candidates = [
      ".build/arm64-apple-macosx/debug/EbookMechanicCLI",
      ".build/x86_64-apple-macosx/debug/EbookMechanicCLI",
      ".build/debug/EbookMechanicCLI"
    ]

    for candidate in candidates {
      let url = baseURL.appendingPathComponent(candidate)
      if FileManager.default.fileExists(atPath: url.path) {
        return url
      }
    }

    throw TestError.message("EbookMechanicCLI executable not found in .build/")
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

  func testHelpIncludesKeyFlags() throws {
    let output = try runCLI(with: ["--help"])

    XCTAssertTrue(output.contains("--report"))
    XCTAssertTrue(output.contains("--report-format"))
    XCTAssertTrue(output.contains("--normalize-epubs"))
    XCTAssertTrue(output.contains("--force-normalize"))
    XCTAssertTrue(output.contains("--dry-run"))
    XCTAssertTrue(output.contains("--performance-stats"))
  }

  func testDryRunOutputsMessage() throws {
    let tempDir = try makeTemporaryDirectory()
    addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
    try writeValidPDF(named: "ok.pdf", in: tempDir)

    let output = try runCLI(with: [
      "--dry-run",
      "--corruption-only",
      "--dir", tempDir.path
    ])

    XCTAssertTrue(output.contains("Dry run enabled"))
  }
}

private func makeTemporaryDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "EbookMechanicCLITests-\(UUID().uuidString)")
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

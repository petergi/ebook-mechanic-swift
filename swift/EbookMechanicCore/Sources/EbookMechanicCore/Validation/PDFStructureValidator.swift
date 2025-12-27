import Foundation

struct PDFStructureValidator {
  func validate(url: URL) -> Result<PDFValidationResult, Error> {
    do {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = ["pdfcpu", "validate", "-m", "json", url.path]

      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe

      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()

      if process.terminationStatus == 0 {
        let validationResult = try JSONDecoder().decode(PDFValidationResult.self, from: data)
        return .success(validationResult)
      } else {
        let output = String(data: data, encoding: .utf8) ?? ""
        return .failure(PDFValidationError.cliError(output))
      }
    } catch {
      return .failure(error)
    }
  }
  func parsePdfcpuOutput(stdout: String, stderr: String, exitCode: Int32) -> PDFValidationResult {
    var structureValid = exitCode == 0
    var xrefValid = exitCode == 0
    var pageTreeValid = exitCode == 0
    var streamErrors: [String] = []
    var encryptionInfo: String?
    var conformsToStandard: String?

    // Parse stderr for specific errors
    let errorLines = stderr.components(separatedBy: .newlines)
    for line in errorLines {
      let lowercaseLine = line.lowercased()

      // Check for cross-reference table errors
      if lowercaseLine.contains("xref") || lowercaseLine.contains("cross-reference") {
        xrefValid = false
        streamErrors.append("Cross-reference table error: \(line)")
      }

      // Check for page tree errors
      if lowercaseLine.contains("page tree") || lowercaseLine.contains("page object") {
        pageTreeValid = false
        streamErrors.append("Page tree error: \(line)")
      }

      // Check for stream errors
      if lowercaseLine.contains("stream") && !lowercaseLine.contains("page tree") {
        streamErrors.append("Stream error: \(line)")
      }
      if lowercaseLine.contains("eof marker missing") {
        streamErrors.append("Stream error: \(line)")
      }

      // Check for encryption information
      if lowercaseLine.contains("encrypt") {
        encryptionInfo = line
      }

      // Check for PDF/A or PDF/X conformance
      if lowercaseLine.contains("pdf/a") || lowercaseLine.contains("pdf/x") {
        conformsToStandard = line
      }
    }

    // Parse stdout for additional information (if JSON mode was not used)
    if !stdout.isEmpty {
      let outputLines = stdout.components(separatedBy: .newlines)
      for line in outputLines {
        let lowercaseLine = line.lowercased()

        if lowercaseLine.contains("encryption") {
          encryptionInfo = line
        }

        if lowercaseLine.contains("conforms to") {
          conformsToStandard = line
        }
      }
    }

    // Update overall structure validity based on specific checks
    structureValid = xrefValid && pageTreeValid && streamErrors.isEmpty

    return PDFValidationResult(
      structureValid: structureValid,
      xrefValid: xrefValid,
      pageTreeValid: pageTreeValid,
      streamErrors: streamErrors,
      encryptionInfo: encryptionInfo,
      conformsToStandard: conformsToStandard
    )
  }
}

enum PDFValidationError: Error {
  case cliError(String)
  case libraryError(String)
}

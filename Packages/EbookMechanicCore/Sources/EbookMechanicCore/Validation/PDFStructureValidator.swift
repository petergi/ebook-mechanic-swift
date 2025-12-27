import Foundation

struct PDFStructureValidator {
  func validate(url: URL) -> Result<PDFValidationResult, Error> {
    do {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = ["pdfcpu", "validate", "-m", "strict", url.path]

      let stdoutPipe = Pipe()
      let stderrPipe = Pipe()
      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe

      try process.run()
      process.waitUntilExit()

      let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
      let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
      let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
      let stderr = String(data: stderrData, encoding: .utf8) ?? ""

      if process.terminationStatus == 0 {
        let validationResult = PDFValidationResult(
          structureValid: true,
          xrefValid: true,
          pageTreeValid: true,
          streamErrors: [],
          encryptionInfo: nil,
          conformsToStandard: nil
        )
        return .success(validationResult)
      }
      let validationResult = parsePdfcpuOutput(
        stdout: stdout,
        stderr: stderr,
        exitCode: process.terminationStatus
      )
      return .success(validationResult)
    } catch {
      return .failure(error)
    }
  }
  func parsePdfcpuOutput(stdout: String, stderr: String, exitCode: Int32) -> PDFValidationResult {
    var xrefValid = true
    var pageTreeValid = true
    var streamErrors: [String] = []
    var encryptionInfo: String?
    var conformsToStandard: String?
    var reportedXrefError = false
    var reportedPageTreeError = false
    var reportedStreamError = false

    // Parse stderr for specific errors
    let diagnostics = stderr.isEmpty ? stdout : stderr
    let errorLines = diagnostics.components(separatedBy: .newlines)
    for line in errorLines {
      let lowercaseLine = line.lowercased()

      // Check for cross-reference table errors
      if lowercaseLine.contains("xref")
        || lowercaseLine.contains("cross-reference")
        || lowercaseLine.contains("xreftable")
        || lowercaseLine.contains("startxref")
        || lowercaseLine.contains("rootdict")
        || lowercaseLine.contains("trailer")
      {
        xrefValid = false
        if reportedXrefError == false {
          streamErrors.append("Xref table is corrupt")
          reportedXrefError = true
        }
      }

      // Check for page tree errors
      if lowercaseLine.contains("page tree")
        || lowercaseLine.contains("pagesdict")
        || lowercaseLine.contains("missing \"pages\"")
      {
        pageTreeValid = false
        if reportedPageTreeError == false {
          streamErrors.append("Invalid page tree structure")
          reportedPageTreeError = true
        }
      }

      // Check for stream errors
      if lowercaseLine.contains("eof marker missing") {
        if reportedStreamError == false {
          streamErrors.append("EOF marker missing")
          reportedStreamError = true
        }
      } else if lowercaseLine.contains("stream") || lowercaseLine.contains("page content") {
        if reportedStreamError == false {
          streamErrors.append("Malformed stream content")
          reportedStreamError = true
        }
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
    let structureValid = xrefValid && pageTreeValid && streamErrors.isEmpty && exitCode == 0

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

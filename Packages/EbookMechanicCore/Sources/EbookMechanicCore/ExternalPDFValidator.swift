import Foundation

public struct ExternalPDFValidator {
  public init() {}

  public static func isPdfcpuInstalled() async -> Bool {
    return await ExternalToolRunner.isCommandAvailable("pdfcpu")
  }

  public func validate(fileURL: URL, pdfcpuPath: String? = nil) async -> ValidationResult {
    let toolURL: URL
    var arguments: [String] = []
    if let pdfcpuPath, !pdfcpuPath.isEmpty {
      let explicitURL = URL(fileURLWithPath: pdfcpuPath)
      guard FileManager.default.isExecutableFile(atPath: explicitURL.path) else {
        return ValidationResult(
          originalIndex: 0, url: fileURL, size: 0, isValid: false,
          reason: "pdfcpu not installed.", status: .validationError,
          validationLevel: .comprehensive)
      }
      toolURL = explicitURL
    } else {
      guard await Self.isPdfcpuInstalled() else {
        return ValidationResult(
          originalIndex: 0, url: fileURL, size: 0, isValid: false,
          reason: "pdfcpu not installed.", status: .validationError,
          validationLevel: .comprehensive)
      }
      toolURL = URL(fileURLWithPath: "/usr/bin/env")
      arguments.append("pdfcpu")
    }

    arguments.append("validate")
    arguments.append(fileURL.path)

    do {
      let (exitCode, stdout, stderr) = try await ExternalToolRunner().run(
        executableURL: toolURL,
        arguments: arguments
      )
      let trimmedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
      let output = trimmedStdout.isEmpty ? trimmedStderr : trimmedStdout

      let isValid: Bool
      let status: ValidationStatus
      var reason: String = ""
      var pdfValidationDetails: PDFValidationResult? = nil

      let pdfStructureValidator = PDFStructureValidator()
      pdfValidationDetails = pdfStructureValidator.parsePdfcpuOutput(
        stdout: stdout, stderr: stderr, exitCode: exitCode)

      if exitCode == 0 {
        isValid = true
        status = .ok
        reason = "PDF is valid."
      } else {
        isValid = false
        // Determine status and reason based on parsed details
        if !pdfValidationDetails!.structureValid || !pdfValidationDetails!.xrefValid
          || !pdfValidationDetails!.pageTreeValid || !pdfValidationDetails!.streamErrors.isEmpty
        {
          status = .corrupt
          reason = "PDF validation failed."
          if !pdfValidationDetails!.streamErrors.isEmpty {
            reason +=
              " Stream errors: \(pdfValidationDetails!.streamErrors.joined(separator: ", "))"
          }
        } else {
          status = .nonCompliant  // Or some other specific non-compliant status if the tool indicates it
          reason = "PDF validation failed with exit code \(exitCode). Details: \(output)"
        }
      }

      return ValidationResult(
        originalIndex: 0, url: fileURL, size: 0, isValid: isValid, reason: reason, status: status,
        validationLevel: .comprehensive, pdfValidationDetails: pdfValidationDetails)
    } catch {
      return ValidationResult(
        originalIndex: 0, url: fileURL, size: 0, isValid: false,
        reason: "Unexpected error during pdfcpu validation: \(error.localizedDescription)",
        status: .validationError, validationLevel: .comprehensive)
    }
  }
}

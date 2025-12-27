import Foundation

public struct ExternalPDFValidator {
  public init() {}

  public static func isPdfcpuInstalled() async -> Bool {
    return await ExternalToolRunner.isCommandAvailable("pdfcpu")
  }

  public func validate(fileURL: URL, pdfcpuPath: String? = nil) async -> ValidationResult {
    let size =
      (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?
      .int64Value ?? 0

    if let pdfcpuPath, !pdfcpuPath.isEmpty {
      let explicitURL = URL(fileURLWithPath: pdfcpuPath)
      guard FileManager.default.isExecutableFile(atPath: explicitURL.path) else {
        return ValidationResult(
          originalIndex: 0, url: fileURL, size: size, isValid: false,
          reason: "pdfcpu not installed.", status: .validationError,
          validationLevel: .comprehensive)
      }

      return await validateWithCLI(fileURL: fileURL, toolURL: explicitURL, size: size)
    }

    guard await Self.isPdfcpuInstalled() else {
      return ValidationResult(
        originalIndex: 0, url: fileURL, size: size, isValid: false,
        reason: "pdfcpu not installed.", status: .validationError,
        validationLevel: .comprehensive)
    }

    let structureValidator = PDFStructureValidator()
    switch structureValidator.validate(url: fileURL) {
    case .success(let details):
      let outcome = summarize(details: details)
      return ValidationResult(
        originalIndex: 0,
        url: fileURL,
        size: size,
        isValid: outcome.isValid,
        reason: outcome.reason,
        status: outcome.status,
        validationLevel: .comprehensive,
        pdfValidationDetails: details
      )
    case .failure(let error):
      return ValidationResult(
        originalIndex: 0, url: fileURL, size: size, isValid: false,
        reason: "Unexpected error during pdfcpu validation: \(error.localizedDescription)",
        status: .validationError, validationLevel: .comprehensive)
    }
  }

  private func validateWithCLI(fileURL: URL, toolURL: URL, size: Int64) async -> ValidationResult {
    do {
      let (exitCode, stdout, stderr) = try await ExternalToolRunner().run(
        executableURL: toolURL,
        arguments: ["validate", "-q", fileURL.path],
        toolName: "pdfcpu"
      )

      let pdfStructureValidator = PDFStructureValidator()
      let details = pdfStructureValidator.parsePdfcpuOutput(
        stdout: stdout, stderr: stderr, exitCode: exitCode)
      let outcome = summarize(details: details)
      let reason = outcome.isValid
        ? "PDF is valid."
        : outcome.reason

      return ValidationResult(
        originalIndex: 0,
        url: fileURL,
        size: size,
        isValid: outcome.isValid,
        reason: reason,
        status: outcome.status,
        validationLevel: .comprehensive,
        pdfValidationDetails: details
      )
    } catch {
      return ValidationResult(
        originalIndex: 0, url: fileURL, size: size, isValid: false,
        reason: "Unexpected error during pdfcpu validation: \(error.localizedDescription)",
        status: .validationError, validationLevel: .comprehensive)
    }
  }

  // swiftlint:disable:next large_tuple
  private func summarize(details: PDFValidationResult) -> (isValid: Bool, status: ValidationStatus, reason: String) {
    var issues: [String] = []
    if !details.structureValid { issues.append("Invalid structure") }
    if !details.xrefValid { issues.append("Invalid cross-reference table") }
    if !details.pageTreeValid { issues.append("Invalid page tree") }
    if !details.streamErrors.isEmpty {
      issues.append("Stream errors: \(details.streamErrors.joined(separator: ", "))")
    }
    if let encryption = details.encryptionInfo {
      issues.append("Encryption: \(encryption)")
    }
    if let conforms = details.conformsToStandard {
      issues.append("Conforms to: \(conforms)")
    }

    if issues.isEmpty {
      return (true, .ok, "PDF is valid.")
    }
    let reason = "PDF validation issues: \(issues.joined(separator: ", "))"
    let status: ValidationStatus = details.structureValid ? .nonCompliant : .corrupt
    return (false, status, reason)
  }
}

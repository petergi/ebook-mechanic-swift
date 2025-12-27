import Foundation

public struct ExternalEPUBValidator {
  public init() {}

  public static func isEpubcheckInstalled() async -> Bool {
    return await ExternalToolRunner.isCommandAvailable("epubcheck")
  }

  public func validate(
    fileURL: URL, epubcheckPath: String? = nil, showWarnings: Bool = false,
    accessibility: Bool = false
  ) async -> ValidationResult {
    let toolURL: URL
    var arguments: [String] = []
    if let epubcheckPath, !epubcheckPath.isEmpty {
      let explicitURL = URL(fileURLWithPath: epubcheckPath)
      guard FileManager.default.isExecutableFile(atPath: explicitURL.path) else {
        return ValidationResult(
          originalIndex: 0, url: fileURL, size: 0, isValid: false,
          reason: "Epubcheck not installed.", status: .validationError,
          validationLevel: .comprehensive)
      }
      toolURL = explicitURL
    } else {
      guard await Self.isEpubcheckInstalled() else {
        return ValidationResult(
          originalIndex: 0, url: fileURL, size: 0, isValid: false,
          reason: "Epubcheck not installed.", status: .validationError,
          validationLevel: .comprehensive)
      }
      toolURL = URL(fileURLWithPath: "/usr/bin/env")
      arguments.append("epubcheck")
    }

    _ = showWarnings
    if accessibility {
      arguments.append("--accessibility")  // Placeholder for actual epubcheck accessibility flag
    }
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

      switch exitCode {
      case 0:
        isValid = true
        status = .ok
        reason = "EPUB is valid."
      case 1:
        isValid = true  // Still considered valid, but with warnings
        status = .nonCompliant
        reason = "EPUB is valid with warnings. Details: \(output)"
      case 2...:
        isValid = false
        status = .corrupt  // Or validationError, depending on severity of epubcheck's >1 exit codes
        reason = "EPUB validation failed. Exit code \(exitCode). Details: \(output)"
      default:
        isValid = false
        status = .validationError
        reason = "Epubcheck returned unexpected exit code \(exitCode). Details: \(output)"
      }

      return ValidationResult(
        originalIndex: 0, url: fileURL, size: 0, isValid: isValid, reason: reason, status: status,
        validationLevel: .comprehensive, epubComplianceDetails: nil)  // TODO: Parse stderr for more details for epubComplianceDetails
    } catch {
      return ValidationResult(
        originalIndex: 0, url: fileURL, size: 0, isValid: false,
        reason: "Unexpected error during epubcheck validation: \(error.localizedDescription)",
        status: .validationError, validationLevel: .comprehensive)
    }
  }
}

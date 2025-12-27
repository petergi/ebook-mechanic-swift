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
      guard let resolved = ExternalToolRunner.resolvedExecutableURL(for: "epubcheck") else {
        return ValidationResult(
          originalIndex: 0, url: fileURL, size: 0, isValid: false,
          reason: "Epubcheck not installed.", status: .validationError,
          validationLevel: .comprehensive)
      }
      toolURL = resolved
    }

    var arguments: [String] = []
    if !showWarnings {
      arguments.append("-q")
    }
    if accessibility {
      arguments.append("--accessibility")
    }
    arguments.append(fileURL.path)

    do {
      let (exitCode, stdout, stderr) = try await ExternalToolRunner().run(
        executableURL: toolURL,
        arguments: arguments,
        toolName: "epubcheck"
      )
      let trimmedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
      let output = trimmedStdout.isEmpty ? trimmedStderr : trimmedStdout
      let complianceDetails = await buildComplianceDetails(
        output: output,
        toolURL: toolURL,
        includeWarnings: showWarnings
      )

      let isValid: Bool
      let status: ValidationStatus
      var reason: String = ""

      switch exitCode {
      case 0:
        isValid = true
        status = .ok
        reason = "EPUB is valid."
      case 1:
        isValid = true
        status = .nonCompliant
        reason = "EPUB is valid with warnings. Details: \(output)"
      case 2...:
        isValid = false
        status = .corrupt
        reason = "EPUB validation failed. Exit code \(exitCode). Details: \(output)"
      default:
        isValid = false
        status = .validationError
        reason = "Epubcheck returned unexpected exit code \(exitCode). Details: \(output)"
      }

      return ValidationResult(
        originalIndex: 0, url: fileURL, size: 0, isValid: isValid, reason: reason, status: status,
        validationLevel: .comprehensive, epubComplianceDetails: complianceDetails)
    } catch {
      return ValidationResult(
        originalIndex: 0, url: fileURL, size: 0, isValid: false,
        reason: "Unexpected error during epubcheck validation: \(error.localizedDescription)",
        status: .validationError, validationLevel: .comprehensive)
    }
  }

  private func fetchEpubcheckVersion(toolURL: URL) async -> String {
    let runner = ExternalToolRunner()
    let versionArguments = ["-version"]
    if let versionOutput = try? await runner.run(
      executableURL: toolURL,
      arguments: versionArguments,
      timeout: 5,
      toolName: "epubcheck"
    ) {
      let output = versionOutput.1.isEmpty ? versionOutput.2 : versionOutput.1
      let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }

    if let fallbackOutput = try? await runner.run(
      executableURL: toolURL,
      arguments: ["--version"],
      timeout: 5,
      toolName: "epubcheck"
    ) {
      let output = fallbackOutput.1.isEmpty ? fallbackOutput.2 : fallbackOutput.1
      let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }

    return "Unknown"
  }

  private func buildComplianceDetails(
    output: String,
    toolURL: URL,
    includeWarnings: Bool
  ) async -> EPUBComplianceResult {
    let epubcheckVersion = await fetchEpubcheckVersion(toolURL: toolURL)
    let issues = parseIssues(from: output)
    let errors = issues.filter { $0.severity == "ERROR" || $0.severity == "FATAL" }
    let warnings = issues.filter { $0.severity == "WARNING" }
    let epubVersion = extractEpubVersion(from: output) ?? "Unknown"
    let hasWarnings = includeWarnings ? !warnings.isEmpty : false

    return EPUBComplianceResult(
      isCompliant: errors.isEmpty,
      hasWarnings: hasWarnings,
      errors: errors,
      warnings: warnings,
      epubVersion: epubVersion,
      epubcheckVersion: epubcheckVersion,
      features: [],
      conformsToAccessibility: false
    )
  }

  private func parseIssues(from output: String) -> [EPUBValidationIssue] {
    var issues: [EPUBValidationIssue] = []
    let lines = output.components(separatedBy: .newlines)
    let issuePattern = #"^(FATAL|ERROR|WARNING)\s*(?:\(([^\)]+)\))?:\s*(.*)$"#
    let filePattern = #"^(.+?)\((\d+)(?:,(\d+))?\):\s*(.+)$"#
    let issueRegex = try? NSRegularExpression(pattern: issuePattern, options: [])
    let fileRegex = try? NSRegularExpression(pattern: filePattern, options: [])

    for rawLine in lines {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }

      let issueMatch = issueRegex?.firstMatch(
        in: line,
        options: [],
        range: NSRange(location: 0, length: line.utf16.count))
      guard let issueMatch else { continue }

      let severity = line.capturingGroup(issueMatch, at: 1)?.uppercased() ?? "ERROR"
      let ruleId = line.capturingGroup(issueMatch, at: 2)
      let remainder = line.capturingGroup(issueMatch, at: 3) ?? line

      var message = remainder
      var filePath: String?
      var lineNumber: Int?
      var context: String?

      if let fileMatch = fileRegex?.firstMatch(
        in: remainder,
        options: [],
        range: NSRange(location: 0, length: remainder.utf16.count))
      {
        filePath = remainder.capturingGroup(fileMatch, at: 1)
        if let lineValue = remainder.capturingGroup(fileMatch, at: 2) {
          lineNumber = Int(lineValue)
        }
        if let column = remainder.capturingGroup(fileMatch, at: 3) {
          context = "column \(column)"
        }
        message = remainder.capturingGroup(fileMatch, at: 4) ?? remainder
      }

      issues.append(
        EPUBValidationIssue(
          severity: severity,
          message: message,
          filePath: filePath,
          lineNumber: lineNumber,
          ruleId: ruleId,
          context: context
        )
      )
    }

    return issues
  }

  private func extractEpubVersion(from output: String) -> String? {
    let pattern = #"EPUB\s+version[:\s]+([0-9.]+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return nil
    }
    let range = NSRange(location: 0, length: output.utf16.count)
    guard let match = regex.firstMatch(in: output, options: [], range: range) else { return nil }
    return output.capturingGroup(match, at: 1)
  }
}

private extension String {
  func capturingGroup(_ match: NSTextCheckingResult, at index: Int) -> String? {
    let range = match.range(at: index)
    guard range.location != NSNotFound, let stringRange = Range(range, in: self) else {
      return nil
    }
    return String(self[stringRange])
  }
}

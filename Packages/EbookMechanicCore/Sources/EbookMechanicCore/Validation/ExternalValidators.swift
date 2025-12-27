//
//  ExternalValidators.swift
//  EbookMechanic
//
//  Created by Gemini on 2025-12-20.
//

import Foundation

public struct ExternalValidators {
  private static let toolRunner = ExternalToolRunner()

  public static func validateEpub(
    at path: String, showWarnings: Bool = false, checkAccessibility: Bool = false
  ) async -> ValidationResult {
    let url = URL(fileURLWithPath: path)
    let size =
      (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value ?? 0
    let epubCheckVersion = await getEpubCheckVersion() ?? "Unknown"

    do {
      var arguments = ["epubcheck", path, "--json", "-"]
      if showWarnings {
        arguments.append("--warn")
      }
      if checkAccessibility {
        arguments.append("--usage")
      }

      let (_, stdout, stderr) = try await toolRunner.run(
        executableURL: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: arguments
      )
      let output = stdout.isEmpty ? stderr : stdout

      let jsonPayload = extractJSONPayload(from: output)
      guard let jsonData = jsonPayload.data(using: .utf8) else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "Failed to read epubcheck output.",
          status: ValidationStatus.validationError, validationLevel: .comprehensive)
      }

      let decoder = JSONDecoder()
      let report = try decoder.decode(EpubCheckReport.self, from: jsonData)

      var errors: [EPUBValidationIssue] = []
      var warnings: [EPUBValidationIssue] = []

      for item in report.messages {
        let issue = EPUBValidationIssue(
          severity: item.severity,
          message: item.message,
          filePath: item.file,
          lineNumber: item.line,
          ruleId: item.id,
          context: item.suggestion
        )
        if item.severity == "ERROR" || item.severity == "FATAL" {
          errors.append(issue)
        } else if item.severity == "WARNING" || item.severity == "USAGE" {
          warnings.append(issue)
        }
      }

      let complianceResult = EPUBComplianceResult(
        isCompliant: errors.isEmpty,
        hasWarnings: !warnings.isEmpty,
        errors: errors,
        warnings: warnings,
        epubVersion: report.epubVersion ?? "Unknown",
        epubcheckVersion: epubCheckVersion,
        features: report.features ?? [],
        conformsToAccessibility: report.accessibility?.conformsTo.contains("wcag-aa") ?? false
      )

      if !complianceResult.isCompliant {
        let reason = "EPUB is not compliant. Found \(errors.count) errors."
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false, reason: reason,
          status: ValidationStatus.nonCompliant, validationLevel: .comprehensive,
          epubComplianceDetails: complianceResult)
      } else if complianceResult.hasWarnings {
        let reason = "EPUB is compliant but has \(warnings.count) warnings."
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true, reason: reason,
          status: ValidationStatus.nonCompliant, validationLevel: .comprehensive,
          epubComplianceDetails: complianceResult)
      } else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true, reason: "EPUB is compliant.",
          status: ValidationStatus.ok, validationLevel: .comprehensive,
          epubComplianceDetails: complianceResult)
      }

    } catch {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false,
        reason: "Failed to run or parse epubcheck output: \(error.localizedDescription)",
        status: ValidationStatus.validationError, validationLevel: .comprehensive)
    }
  }

  private static func getEpubCheckVersion() async -> String? {
    do {
      let (terminationStatus, stdout, stderr) = try await toolRunner.run(
        executableURL: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: ["epubcheck", "--version"]
      )

      guard terminationStatus == 0 else { return nil }
      let output = stdout.isEmpty ? stderr : stdout
      return output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    } catch {
      return nil
    }
  }

  public static func validatePdf(at path: String) async -> ValidationResult {
    let url = URL(fileURLWithPath: path)
    let size =
      (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value ?? 0
    do {
      let (terminationStatus, stdout, stderr) = try await toolRunner.run(
        executableURL: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: ["pdfcpu", "validate", path]
      )
      let output = stdout.isEmpty ? stderr : stdout

      if terminationStatus == 0 {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true, reason: "File is a valid PDF.",
          status: ValidationStatus.ok, validationLevel: .comprehensive)
      } else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "File is not a valid PDF. pdfcpu output:\n\(output)",
          status: ValidationStatus.validationError, validationLevel: .comprehensive)
      }
    } catch {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false,
        reason: "Failed to run pdfcpu: \(error.localizedDescription)",
        status: ValidationStatus.validationError, validationLevel: .comprehensive)
    }
  }

  public static func optimizePDF(at path: String, outputPath: String? = nil) async -> (Bool, String)
  {
    do {
      var arguments = ["pdfcpu", "optimize", path]
      if let outputPath {
        arguments.append(outputPath)
      }
      let (terminationStatus, stdout, stderr) = try await toolRunner.run(
        executableURL: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: arguments
      )
      let output = stdout.isEmpty ? stderr : stdout
      return (terminationStatus == 0, output)
    } catch {
      return (false, "Failed to run pdfcpu: \(error.localizedDescription)")
    }
  }

  public static func getPdfInfo(at path: String) async -> [String: Any] {
    do {
      let (terminationStatus, stdout, stderr) = try await toolRunner.run(
        executableURL: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: ["pdfcpu", "info", "-j", path]
      )
      let output = stdout.isEmpty ? stderr : stdout

      guard terminationStatus == 0, let jsonData = output.data(using: .utf8) else {
        return [:]
      }

      return (try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]) ?? [:]
    } catch {
      return [:]
    }
  }

  public static func getPdfStreamInfo(at path: String) async -> String {
    do {
      let (terminationStatus, stdout, stderr) = try await toolRunner.run(
        executableURL: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: ["pdfcpu", "optimize", "--stats", path]
      )
      let output = stdout.isEmpty ? stderr : stdout

      return terminationStatus == 0 ? output : "Unable to retrieve stream information: \(output)"
    } catch {
      return "Failed to run pdfcpu: \(error.localizedDescription)"
    }
  }

  public static func getPdfEncryptionInfo(at path: String) async -> String {
    let info = await getPdfInfo(at: path)

    var encryptionDetails = "Encryption: "
    if let encrypted = info["Encrypted"] as? Bool, encrypted {
      encryptionDetails += "Yes\n"
      if let permissions = info["Permissions"] as? [String: Any] {
        encryptionDetails += "Permissions:\n"
        for (key, value) in permissions.sorted(by: { $0.key < $1.key }) {
          encryptionDetails += "  \(key): \(value)\n"
        }
      }
    } else {
      encryptionDetails += "No"
    }

    return encryptionDetails
  }
}

private func extractJSONPayload(from output: String) -> String {
  guard let start = output.firstIndex(of: "{"),
        let end = output.lastIndex(of: "}") else {
    return output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
  }
  return String(output[start...end])
}

// MARK: - EpubCheck JSON Structures

private struct EpubCheckReport: Decodable {
  let checker: CheckerInfo?
  let epubVersion: String?
  let publisher: String?
  let title: String?
  let date: String?
  let features: [String]?
  let accessibility: AccessibilityInfo?
  let messages: [Message]

  private enum CodingKeys: String, CodingKey {
    case checker
    case epubVersion
    case publisher
    case title
    case date
    case features
    case accessibility
    case messages
    case publication
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    checker = try container.decodeIfPresent(CheckerInfo.self, forKey: .checker)
    publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
    title = try container.decodeIfPresent(String.self, forKey: .title)
    date = try container.decodeIfPresent(String.self, forKey: .date)
    features = try container.decodeIfPresent([String].self, forKey: .features)
    accessibility = try container.decodeIfPresent(AccessibilityInfo.self, forKey: .accessibility)
    messages = try container.decodeIfPresent([Message].self, forKey: .messages) ?? []

    if let version = try container.decodeIfPresent(String.self, forKey: .epubVersion) {
      epubVersion = version
    } else if let publication = try container.decodeIfPresent(Publication.self, forKey: .publication) {
      epubVersion = publication.ePubVersion
    } else {
      epubVersion = nil
    }
  }
}

private struct CheckerInfo: Decodable {
  let name: String?
  let version: String?
  let buildDate: String?
  let checkerVersion: String?
  let checkDate: String?
}

private struct AccessibilityInfo: Decodable {
  let conformsTo: [String]
  let summary: String?
}

private struct Publication: Decodable {
  let ePubVersion: String?
}

private struct Message: Decodable {
  let id: String
  let severity: String
  let file: String?
  let line: Int?
  let col: Int?
  let message: String
  let suggestion: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case ID
    case severity
    case file
    case line
    case col
    case message
    case suggestion
    case locations
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id)
      ?? container.decode(String.self, forKey: .ID)
    severity = try container.decode(String.self, forKey: .severity)
    message = try container.decode(String.self, forKey: .message)
    suggestion = try container.decodeIfPresent(String.self, forKey: .suggestion)

    if let file = try container.decodeIfPresent(String.self, forKey: .file) {
      self.file = file
      line = try container.decodeIfPresent(Int.self, forKey: .line)
      col = try container.decodeIfPresent(Int.self, forKey: .col)
    } else if let locations = try container.decodeIfPresent([MessageLocation].self, forKey: .locations),
              let firstLocation = locations.first {
      self.file = firstLocation.path
      line = firstLocation.line
      col = firstLocation.column
    } else {
      file = nil
      line = nil
      col = nil
    }
  }
}

private struct MessageLocation: Decodable {
  let path: String?
  let line: Int?
  let column: Int?
}

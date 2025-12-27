//
//  ExternalValidators.swift
//  EbookMechanic
//
//  Created by Gemini on 2025-12-20.
//

import Foundation

public struct ExternalValidators {
  private static let toolRunner = ExternalToolRunner()

  public static func validateEpub(at path: String) async -> ValidationResult {
    let url = URL(fileURLWithPath: path)
    let size =
      (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value ?? 0
    let epubCheckVersion = await getEpubCheckVersion() ?? "Unknown"

    do {
      let (terminationStatus, output) = try await toolRunner.runTool(
        executableURL: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: ["epubcheck", "-j", path, "-"]
      )

      // Even with errors, epubcheck can exit with 0, so we need to parse the JSON.
      // A non-zero exit code is a more severe failure.
      if terminationStatus != 0 {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "epubcheck tool failed to run: \(output)", status: .validationError)
      }

      let decoder = JSONDecoder()
      let report = try decoder.decode(EpubCheckReport.self, from: output.data(using: .utf8)!)

      var errors: [EPUBValidationIssue] = []
      var warnings: [EPUBValidationIssue] = []

      for item in report.messages {
        let issue = EPUBValidationIssue(
          severity: item.severity,
          message: item.message,
          filePath: item.file,
          lineNumber: item.line,
          ruleId: item.id
        )
        if item.severity == "ERROR" || item.severity == "FATAL" {
          errors.append(issue)
        } else if item.severity == "WARNING" {
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
        conformsToAccessibility: report.accessibility?.conformsTo.contains("wcag-aa") ?? false
      )

      if !complianceResult.isCompliant {
        let reason = "EPUB is not compliant. Found \(errors.count) errors."
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false, reason: reason,
          status: .nonCompliant, epubComplianceDetails: complianceResult)
      } else if complianceResult.hasWarnings {
        let reason = "EPUB is compliant but has \(warnings.count) warnings."
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true, reason: reason,
          status: .nonCompliant, epubComplianceDetails: complianceResult)
      } else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true, reason: "EPUB is compliant.",
          status: .ok, epubComplianceDetails: complianceResult)
      }

    } catch {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false,
        reason: "Failed to run or parse epubcheck output: \(error.localizedDescription)",
        status: .validationError)
    }
  }

  private static func getEpubCheckVersion() async -> String? {
    do {
      let (terminationStatus, output) = try await toolRunner.runTool(
        executableURL: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: ["epubcheck", "--version"]
      )

      guard terminationStatus == 0 else { return nil }
      return output.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      return nil
    }
  }

  public static func validatePdf(at path: String) async -> ValidationResult {
    let url = URL(fileURLWithPath: path)
    let size =
      (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value ?? 0
    do {
      let (terminationStatus, output) = try await toolRunner.runTool(
        executableURL: URL(fileURLWithPath: "/usr/bin/env"),
        arguments: ["pdfcpu", "validate", path]
      )

      if terminationStatus == 0 {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true, reason: "File is a valid PDF.",
          status: .ok)
      } else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "File is not a valid PDF. pdfcpu output:\n\(output)", status: .validationError)
      }
    } catch {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false,
        reason: "Failed to run pdfcpu: \(error.localizedDescription)", status: .validationError)
    }
  }
}

// MARK: - EpubCheck JSON Structures

private struct EpubCheckReport: Codable {
  let checker: CheckerInfo
  let epubVersion: String?
  let publisher: String?
  let title: String?
  let date: String?
  let features: [String]?
  let accessibility: AccessibilityInfo?
  let messages: [Message]
}

private struct CheckerInfo: Codable {
  let name: String
  let version: String
  let buildDate: String
}

private struct AccessibilityInfo: Codable {
  let conformsTo: [String]
  let summary: String?
}

private struct Message: Codable {
  let id: String
  let severity: String
  let file: String?
  let line: Int?
  let col: Int?
  let message: String
  let suggestion: String?
}

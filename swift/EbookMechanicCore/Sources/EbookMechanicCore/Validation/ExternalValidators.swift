//
//  ExternalValidators.swift
//  EbookMechanic
//
//  Created by Gemini on 2025-12-20.
//

import Foundation

public struct ExternalValidators {
    public static func validateEpub(at path: String) -> ValidationResult {
        let epubCheckVersion = getEpubCheckVersion() ?? "Unknown"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        // Use -j for JSON output and -o for output file (we'll redirect to stdout)
        process.arguments = ["epubcheck", "-j", path, "-"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            // Even with errors, epubcheck can exit with 0, so we need to parse the JSON.
            // A non-zero exit code is a more severe failure.
            if process.terminationStatus != 0 {
                 let errorOutput = String(data: data, encoding: .utf8) ?? ""
                 return ValidationResult(isValid: false, reason: "epubcheck tool failed to run: \(errorOutput)", status: .validationError)
            }

            let decoder = JSONDecoder()
            let report = try decoder.decode(EpubCheckReport.self, from: data)

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
                return ValidationResult(isValid: false, reason: reason, status: .nonCompliant, epubComplianceDetails: complianceResult)
            } else if complianceResult.hasWarnings {
                let reason = "EPUB is compliant but has \(warnings.count) warnings."
                return ValidationResult(isValid: true, reason: reason, status: .nonCompliant, epubComplianceDetails: complianceResult)
            } else {
                return ValidationResult(isValid: true, reason: "EPUB is compliant.", status: .ok, epubComplianceDetails: complianceResult)
            }
            
        } catch {
            return ValidationResult(isValid: false, reason: "Failed to run or parse epubcheck output: \(error.localizedDescription)", status: .validationError)
        }
    }

    private static func getEpubCheckVersion() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["epubcheck", "--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
    
    public static func validatePdf(at path: String) -> ValidationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pdfcpu", "validate", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return ValidationResult(isValid: true, reason: "File is a valid PDF.", status: .ok)
            } else {
                return ValidationResult(isValid: false, reason: "File is not a valid PDF. pdfcpu output:\n\(output)", status: .validationError)
            }
        } catch {
            return ValidationResult(isValid: false, reason: "Failed to run pdfcpu: \(error.localizedDescription)", status: .validationError)
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

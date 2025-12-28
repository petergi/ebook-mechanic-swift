import Foundation
import EbookMechanicCore

struct EPUBReportFormatter {
    func printValidationResults(for result: ValidationResult) {
        print("🔍 Validation Result for: \(result.url.lastPathComponent)")
        print("--------------------------------------------------")
        print("Is Valid: \(result.isValid)")
        print("Status: \(result.status.rawValue)")
        print("Validation Level: \(result.validationLevel.rawValue)")
        print("File Size: \(result.size) bytes")
        if let fingerprint = result.fingerprint {
            print("Fingerprint: \(fingerprint.description)")
        }
        print("Reason: \(result.reason)")

        if let compliance = result.epubComplianceDetails {
            print("\n📚 EPUB Compliance Details:")
            print("  - EPUB Version: \(compliance.epubVersion)")
            print("  - EpubCheck Version: \(compliance.epubcheckVersion)")
            print("  - Compliant: \(compliance.isCompliant)")
            print("  - Has Warnings: \(compliance.hasWarnings)")
            print("  - Accessibility Conformance: \(compliance.conformsToAccessibility)")
            if !compliance.features.isEmpty {
                print("  - Features: \(compliance.features.sorted().joined(separator: ", "))")
            }

            if !compliance.errors.isEmpty {
                print("\n  🚨 Errors:")
                printGroupedIssues(compliance.errors)
            }

            if !compliance.warnings.isEmpty {
                print("\n  ⚠️ Warnings:")
                printGroupedIssues(compliance.warnings)
            }
        }
        print("--------------------------------------------------")
    }

    private func printGroupedIssues(_ issues: [EPUBValidationIssue]) {
        let grouped = Dictionary(grouping: issues) { issue in
            issue.filePath ?? "General"
        }

        for key in grouped.keys.sorted() {
            print("    • \(key)")
            for issue in grouped[key, default: []] {
                var detail = "[\(issue.severity)] \(issue.message)"
                if let ruleId = issue.ruleId {
                    detail += " (\(ruleId))"
                }
                if let line = issue.lineNumber {
                    detail += " at line \(line)"
                }
                print("      - \(detail)")
            }
        }
    }
}

import Foundation
import EbookMechanicCore

struct EPUBReportFormatter {
    func printValidationResults(for result: ValidationResult) {
        print("🔍 Validation Result for: \(result.url.lastPathComponent)")
        print("--------------------------------------------------")
        print("Is Valid: \(result.isValid)")
        print("Reason: \(result.reason)")
        
        if let compliance = result.epubComplianceDetails {
            print("\n📚 EPUB Compliance Details:")
            print("  - EPUB Version: \(compliance.epubVersion)")
            print("  - EpubCheck Version: \(compliance.epubcheckVersion)")
            print("  - Compliant: \(compliance.isCompliant)")
            print("  - Has Warnings: \(compliance.hasWarnings)")
            print("  - Accessibility Conformance: \(compliance.conformsToAccessibility)")
            
            if !compliance.errors.isEmpty {
                print("\n  🚨 Errors:")
                for error in compliance.errors {
                    print("    - [\(error.severity)] \(error.message) (at \(error.filePath ?? "N/A"):\(error.lineNumber ?? 0))")
                }
            }
            
            if !compliance.warnings.isEmpty {
                print("\n  ⚠️ Warnings:")
                for warning in compliance.warnings {
                    print("    - [\(warning.severity)] \(warning.message) (at \(warning.filePath ?? "N/A"):\(warning.lineNumber ?? 0))")
                }
            }
        }
        print("--------------------------------------------------")
    }
}

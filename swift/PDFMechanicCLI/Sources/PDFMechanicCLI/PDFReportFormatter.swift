import Foundation
import EbookMechanicCore

struct PDFReportFormatter {
    func printValidationResults(for result: ValidationResult) {
        print("🔍 Validation Result for: \(result.url.lastPathComponent)")
        print("--------------------------------------------------")
        print("Is Valid: \(result.isValid)")
        print("Reason: \(result.reason)")
        
        if let pdfDetails = result.pdfValidationDetails {
            print("\n📄 PDF Validation Details:")
            print("  - Structure Valid: \(pdfDetails.structureValid)")
            print("  - XRef Valid: \(pdfDetails.xrefValid)")
            print("  - Page Tree Valid: \(pdfDetails.pageTreeValid)")
            
            if let encryption = pdfDetails.encryptionInfo {
                print("  - Encryption: \(encryption)")
            }
            
            if let standard = pdfDetails.conformsToStandard {
                print("  - Conforms to Standard: \(standard)")
            }
            
            if !pdfDetails.streamErrors.isEmpty {
                print("\n  🚨 Stream Errors:")
                for error in pdfDetails.streamErrors {
                    print("    - \(error)")
                }
            }
        }
        print("--------------------------------------------------")
    }
}


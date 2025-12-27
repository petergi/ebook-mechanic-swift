import EbookMechanicCore
import Foundation

struct PDFReportFormatter {
  func printValidationResults(for result: ValidationResult) async {
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

    let info = await ExternalValidators.getPdfInfo(at: result.url.path)
    if !info.isEmpty {
      print("\n📘 PDF Info:")
      if let version = info["PDFVersion"] ?? info["Version"] ?? info["PDFVersionString"] {
        printValue("  - PDF Version", version)
      }
      if let pageCount = info["Pages"] ?? info["PageCount"] {
        printValue("  - Page Count", pageCount)
      }
      if let features = info["Features"] ?? info["FeatureSet"] {
        printValue("  - Features", features)
      }
      if let formFields = info["FormFields"] ?? info["Fields"] ?? info["AcroForm"] {
        printValue("  - Form Fields", formFields)
      }
      if let annotations = info["Annotations"] ?? info["AnnotationCount"] {
        printValue("  - Annotations", annotations)
      }
      if let encrypted = info["Encrypted"] ?? info["Encryption"] {
        printValue("  - Encrypted", encrypted)
      }
      if let permissions = info["Permissions"] as? [String: Any] {
        print("  - Permissions:")
        for key in permissions.keys.sorted() {
          let value = permissions[key] ?? "Unknown"
          print("    • \(key): \(formatValue(value))")
        }
      }
      if let conformance = info["Conformance"] ?? info["PDF/A"] ?? info["PDFX"] {
        printValue("  - Conformance", conformance)
      } else if let standard = result.pdfValidationDetails?.conformsToStandard {
        printValue("  - Conformance", standard)
      }
    }
    print("--------------------------------------------------")
  }

  private func printValue(_ label: String, _ value: Any) {
    print("\(label): \(formatValue(value))")
  }

  private func formatValue(_ value: Any) -> String {
    switch value {
    case let string as String:
      return string
    case let number as NSNumber:
      return number.stringValue
    case let array as [Any]:
      return array.map { formatValue($0) }.joined(separator: ", ")
    case let dict as [String: Any]:
      let parts = dict.keys.sorted().map { key in
        let value = dict[key] ?? "Unknown"
        return "\(key)=\(formatValue(value))"
      }
      return parts.joined(separator: ", ")
    default:
      return String(describing: value)
    }
  }
}

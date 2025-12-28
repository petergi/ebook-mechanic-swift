import EbookMechanicCore
import SwiftUI

struct ValidationDetailView: View {
  var validationResult: ValidationResult
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          headerSection
          generalInfoSection
          formatSpecificDetailsSection
          buttonsSection
        }
        .padding()
      }
      .navigationTitle(validationResult.url.lastPathComponent)
      .toolbar {
        ToolbarItem(placement: .navigation) {  // Use .navigation for macOS
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }

  private var headerSection: some View {
    HStack {
      Image(systemName: validationResult.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
        .font(.largeTitle)
        .foregroundColor(validationResult.isValid ? .green : .red)

      VStack(alignment: .leading) {
        Text(validationResult.isValid ? "Valid" : "Corrupted / Non-Compliant")
          .font(.title2)
          .fontWeight(.bold)
        Text(validationResult.reason)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
  }

  private var generalInfoSection: some View {
    VStack(alignment: .leading) {
      Text("General Information")
        .font(.headline)
      Divider()
      InfoRow(label: "File Path", value: validationResult.url.path)
      InfoRow(
        label: "Size",
        value: ByteCountFormatter.string(
          fromByteCount: validationResult.size, countStyle: .file))
      InfoRow(label: "Status", value: validationResult.status.rawValue.capitalized)
      if let fingerprint = validationResult.fingerprint {
        InfoRow(label: "Fingerprint", value: fingerprint.description)
      }
    }
  }

  @ViewBuilder
  private var formatSpecificDetailsSection: some View {
    if let epubDetails = validationResult.epubComplianceDetails {
      EPUBDetailsView(epubDetails: epubDetails)
    } else if let pdfDetails = validationResult.pdfValidationDetails {
      PDFDetailsView(pdfDetails: pdfDetails)
    }
  }

  private var buttonsSection: some View {
    VStack {
      Button("Copy Reason to Clipboard") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(validationResult.reason, forType: .string)
      }
    }
  }
}

struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text("\(label):")
        .fontWeight(.medium)
      Spacer()
      Text(value)
        .font(.callout)
    }
  }
}

struct EPUBDetailsView: View {
  var epubDetails: EPUBComplianceResult
  @State private var showingErrors = false
  @State private var showingWarnings = false

  var body: some View {
    VStack(alignment: .leading) {
      Text("EPUB Compliance Details")
        .font(.headline)
      Divider()
      InfoRow(label: "EPUB Version", value: epubDetails.epubVersion)
      InfoRow(label: "EpubCheck Version", value: epubDetails.epubcheckVersion)
      InfoRow(label: "Compliant", value: epubDetails.isCompliant ? "Yes" : "No")
      InfoRow(label: "Has Warnings", value: epubDetails.hasWarnings ? "Yes" : "No")
      InfoRow(
        label: "Accessibility Conformance",
        value: epubDetails.conformsToAccessibility ? "Yes" : "No")

      if !epubDetails.errors.isEmpty {
        DisclosureGroup("Errors (\(epubDetails.errors.count))", isExpanded: $showingErrors) {
          ForEach(epubDetails.errors, id: \.message) { error in
            VStack(alignment: .leading) {
              HStack {
                Text(error.message)
                Spacer()
                CopyButton(text: error.message)
              }
              Text(
                "File: \(error.filePath ?? "N/A"), Line: \(error.lineNumber ?? 0)"
              )
                .font(.caption)
                .foregroundColor(.red)
              if let context = error.context, !context.isEmpty {
                Text(context)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
        .tint(.red)
      }

      if !epubDetails.warnings.isEmpty {
        DisclosureGroup("Warnings (\(epubDetails.warnings.count))", isExpanded: $showingWarnings) {
          ForEach(epubDetails.warnings, id: \.message) { warning in
            VStack(alignment: .leading) {
              HStack {
                Text(warning.message)
                Spacer()
                CopyButton(text: warning.message)
              }
              Text(
                "File: \(warning.filePath ?? "N/A"), Line: \(warning.lineNumber ?? 0)"
              )
                .font(.caption)
                .foregroundColor(.orange)
              if let context = warning.context, !context.isEmpty {
                Text(context)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
        .tint(.orange)
      }
    }
  }
}

struct PDFDetailsView: View {
  var pdfDetails: PDFValidationResult
  @State private var showingStreamErrors = false

  var body: some View {
    VStack(alignment: .leading) {
      Text("PDF Structure Details")
        .font(.headline)
      Divider()
      InfoRow(label: "Structure Valid", value: pdfDetails.structureValid ? "Yes" : "No")
      InfoRow(label: "XRef Valid", value: pdfDetails.xrefValid ? "Yes" : "No")
      InfoRow(label: "Page Tree Valid", value: pdfDetails.pageTreeValid ? "Yes" : "No")

      if let encryption = pdfDetails.encryptionInfo {
        InfoRow(label: "Encryption", value: encryption)
      }
      if let conforms = pdfDetails.conformsToStandard {
        InfoRow(label: "Conforms to Standard", value: conforms)
      }

      if !pdfDetails.streamErrors.isEmpty {
        DisclosureGroup(
          "Stream Errors (\(pdfDetails.streamErrors.count))", isExpanded: $showingStreamErrors
        ) {
          ForEach(pdfDetails.streamErrors, id: \.self) { error in
            HStack {
              Text(error)
                .font(.caption)
                .foregroundColor(.red)
              Spacer()
              CopyButton(text: error)
            }
          }
        }
        .tint(.red)
      }
    }
  }
}

struct CopyButton: View {
  let text: String

  var body: some View {
    Button {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    } label: {
      Image(systemName: "doc.on.doc")
    }
    .buttonStyle(.bordered)
    .help("Copy to clipboard")
  }
}

// #Preview {
//    ValidationDetailView(validationResult: ValidationResult(
//        originalIndex: 0,
//        url: URL(fileURLWithPath: "/Users/test/book.epub"),
//        size: 1024 * 1024,
//        isValid: false,
//        reason: "Missing mimetype file",
//        status: .nonCompliant,
//        epubComplianceDetails: EPUBComplianceResult(
//            isCompliant: false,
//            hasWarnings: true,
//            errors: [
//                EPUBValidationIssue(
//                    severity: "ERROR", message: "Mimetype not found", filePath: "mimetype",
//                    lineNumber: 0
//                )
//            ],
//            warnings: [
//                EPUBValidationIssue(
//                    severity: "WARNING", message: "Image resolution too low",
//                    filePath: "images/cover.jpg", lineNumber: 10
//                )
//            ],
//            epubVersion: "3.0",
//            epubcheckVersion: "4.2.0",
//            conformsToAccessibility: false
//        )
//    ))
// }

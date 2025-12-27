import EbookMechanicCore
import SwiftUI

struct ResultsListView: View {
  @ObservedObject var viewModel: ScanViewModel
  @Environment(\.dismiss) var dismiss
  @State private var selectedValidationResult: ValidationResult?
  @State private var showDetailView: Bool = false

  var body: some View {
    NavigationView {
      List {
        Section(header: Text("Corrupted Files (\(viewModel.corruptedFiles.count))")) {
          if viewModel.corruptedFiles.isEmpty {
            Text("No corrupted files detected.")
              .foregroundColor(.secondary)
          } else {
            ForEach(viewModel.corruptedFiles, id: \.url) { file in
              Button {
                selectedValidationResult = ValidationResult(
                  originalIndex: 0, url: file.url, size: file.size, isValid: false,
                  reason: file.reason, status: file.status, fingerprint: file.fingerprint,
                  pdfValidationDetails: file.pdfValidationDetails,
                  epubComplianceDetails: file.epubComplianceDetails)
                showDetailView = true
              } label: {
                HStack {
                  Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                  Text(file.url.lastPathComponent)
                  Spacer()
                  Text(file.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .buttonStyle(.plain)
            }
          }
        }

        Section(header: Text("Non-Compliant Files (\(viewModel.nonCompliantFiles.count))")) {
          if viewModel.nonCompliantFiles.isEmpty {
            Text("No non-compliant files detected.")
              .foregroundColor(.secondary)
          } else {
            ForEach(viewModel.nonCompliantFiles, id: \.url) { result in
              Button {
                selectedValidationResult = result
                showDetailView = true
              } label: {
                HStack {
                  Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                  Text(result.url.lastPathComponent)
                  Spacer()
                  Text(result.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .buttonStyle(.plain)
            }
          }
        }

        Section(header: Text("Files with Warnings (\(viewModel.filesWithWarnings.count))")) {
          if viewModel.filesWithWarnings.isEmpty {
            Text("No files with warnings detected.")
              .foregroundColor(.secondary)
          } else {
            ForEach(viewModel.filesWithWarnings, id: \.url) { result in
              Button {
                selectedValidationResult = result
                showDetailView = true
              } label: {
                HStack {
                  Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.yellow)
                  Text(result.url.lastPathComponent)
                  Spacer()
                  Text(result.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .listStyle(.plain)
      .navigationTitle("Scan Results")
      .toolbar {
        ToolbarItem(placement: .navigation) {  // Use .navigation for macOS
          Button("Done") {
            dismiss()
          }
        }
      }
      .sheet(isPresented: $showDetailView) {
        if let selectedValidationResult {
          ValidationDetailView(validationResult: selectedValidationResult)
        }
      }
    }
  }
}

extension Collection where Element == ValidationResult {
  func sortedByURL() -> [Element] {
    self.sorted {
      $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent)
        == .orderedAscending
    }
  }
}

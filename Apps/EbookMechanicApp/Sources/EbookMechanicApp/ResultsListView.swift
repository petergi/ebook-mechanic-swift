import EbookMechanicCore
import SwiftUI

struct ResultsListView: View {
  @ObservedObject var viewModel: ScanViewModel
  @Environment(\.dismiss) var dismiss
  @State private var selectedValidationResult: ValidationResult?
  @State private var showDetailView: Bool = false
  @State private var showCorruptedSection: Bool = true
  @State private var showNonCompliantSection: Bool = true
  @State private var showWarningsSection: Bool = true

  var body: some View {
    let groups = ResultsListGroups(viewModel: viewModel)
    NavigationView {
      List {
        DisclosureGroup(isExpanded: $showCorruptedSection) {
          if groups.corrupted.isEmpty {
            Text("No corrupted files detected.")
              .foregroundColor(.secondary)
          } else {
            ForEach(groups.corrupted.sortedByURL(), id: \.url) { result in
              resultsRow(
                result,
                icon: "xmark.circle.fill",
                tint: .red
              )
            }
          }
        } label: {
          sectionHeader(title: "Corrupted Files", count: groups.corrupted.count)
        }

        DisclosureGroup(isExpanded: $showNonCompliantSection) {
          if groups.nonCompliant.isEmpty {
            Text("No non-compliant files detected.")
              .foregroundColor(.secondary)
          } else {
            ForEach(groups.nonCompliant.sortedByURL(), id: \.url) { result in
              resultsRow(
                result,
                icon: "exclamationmark.triangle.fill",
                tint: .orange
              )
            }
          }
        } label: {
          sectionHeader(title: "Non-Compliant Files", count: groups.nonCompliant.count)
        }

        DisclosureGroup(isExpanded: $showWarningsSection) {
          if groups.warnings.isEmpty {
            Text("No files with warnings detected.")
              .foregroundColor(.secondary)
          } else {
            ForEach(groups.warnings.sortedByURL(), id: \.url) { result in
              resultsRow(
                result,
                icon: "exclamationmark.circle.fill",
                tint: .yellow
              )
            }
          }
        } label: {
          sectionHeader(title: "Files with Warnings", count: groups.warnings.count)
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

  private func resultsRow(_ result: ValidationResult, icon: String, tint: Color) -> some View {
    Button {
      selectedValidationResult = result
      showDetailView = true
    } label: {
      HStack {
        Image(systemName: icon)
          .foregroundColor(tint)
        Text(result.url.lastPathComponent)
        Spacer()
        Text(result.reason)
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .buttonStyle(.plain)
  }

  private func sectionHeader(title: String, count: Int) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text("\(count)")
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.2))
        .clipShape(Capsule())
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

struct ResultsListGroups {
  let corrupted: [ValidationResult]
  let nonCompliant: [ValidationResult]
  let warnings: [ValidationResult]

  @MainActor
  init(viewModel: ScanViewModel) {
    let resultsByURL = viewModel.validationResults
    let corruptedResults = viewModel.corruptedFiles.enumerated().map { index, file in
      resultsByURL[file.url] ?? ValidationResult(corruptedFile: file, originalIndex: index)
    }

    corrupted = corruptedResults
    nonCompliant = resultsByURL.values.filter { $0.status == .nonCompliant }
    warnings = resultsByURL.values.filter { result in
      let statusAllowsWarnings = result.status == .ok || result.status == .nonCompliant
      guard statusAllowsWarnings else { return false }
      return result.epubComplianceDetails?.hasWarnings == true
        || !(result.pdfValidationDetails?.streamErrors.isEmpty ?? true)
    }
  }
}

extension ValidationResult {
  init(corruptedFile: CorruptedFile, originalIndex: Int) {
    self.init(
      originalIndex: originalIndex,
      url: corruptedFile.url,
      size: corruptedFile.size,
      isValid: false,
      reason: corruptedFile.reason,
      status: corruptedFile.status,
      validationLevel: corruptedFile.validationLevel,
      fingerprint: corruptedFile.fingerprint,
      pdfValidationDetails: corruptedFile.pdfValidationDetails,
      epubComplianceDetails: corruptedFile.epubComplianceDetails
    )
  }
}

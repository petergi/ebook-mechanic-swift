import EbookMechanicCore
import SwiftUI

struct ReportExportView: View {
  @ObservedObject var viewModel: ScanViewModel
  @ObservedObject var options: ScanOptions
  @Environment(\.dismiss) var dismiss

  @State private var selectedFormats: Set<ReportFormat>
  @State private var destinationFolder: URL
  @State private var isExporting: Bool = false
  @State private var exportComplete: Bool = false
  @State private var exportedURLs: [URL] = []
  @State private var exportError: String?

  init(viewModel: ScanViewModel, options: ScanOptions) {
    self._viewModel = ObservedObject(wrappedValue: viewModel)
    self._options = ObservedObject(wrappedValue: options)
    _selectedFormats = State(initialValue: options.selectedReportFormats)
    _destinationFolder = State(initialValue: options.directory)
  }

  var body: some View {
    NavigationView {
      Form {
        Section("Report Formats") {
          ForEach(ReportFormat.allCases, id: \.self) { format in
            Toggle(
              isOn: Binding(
                get: { selectedFormats.contains(format) },
                set: {
                  if $0 { selectedFormats.insert(format) } else { selectedFormats.remove(format) }
                }
              )
            ) {
              Text(format.rawValue.capitalized)
            }
          }
        }

        Section("Destination Folder") {
          HStack {
            Text(destinationFolder.lastPathComponent)
            Spacer()
            Button("Choose…") {
              selectDestinationFolder()
            }
          }
          Text(destinationFolder.path)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Section {
          Button {
            exportReports()
          } label: {
            HStack {
              if isExporting {
                ProgressView()
              }
              Text("Export All")
            }
            .frame(maxWidth: .infinity)
          }
          .disabled(selectedFormats.isEmpty || isExporting)
        }

        if exportComplete {
          Section {
            VStack(alignment: .leading) {
              Text("Export Complete!")
                .font(.headline)
              ForEach(exportedURLs, id: \.self) { url in
                Button("Reveal \(url.lastPathComponent) in Finder") {
                  NSWorkspace.shared.activateFileViewerSelecting([url])
                }
              }
            }
          }
        }

        if let exportError {
          Section {
            Text("Error: \(exportError)")
              .foregroundColor(.red)
          }
        }
      }
      .navigationTitle("Export Reports")
      .onAppear {
        selectedFormats = options.selectedReportFormats
        destinationFolder = options.directory
      }
      .toolbar {
        ToolbarItem(placement: .navigation) {  // Use .navigation for macOS
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }

  private func selectDestinationFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose Destination Folder"

    if panel.runModal() == .OK, let url = panel.url {
      destinationFolder = url
    }
  }

  private func exportReports() {
    isExporting = true
    exportComplete = false
    exportError = nil
    exportedURLs = []

    Task {
      do {
        guard viewModel.summary != nil else {
          throw ScanViewModel.ScanViewModelError.noScanData
        }

        let urls = try await viewModel.generateReport(
          into: destinationFolder, options: options, formats: selectedFormats)

        await MainActor.run {
          exportedURLs = urls
          exportComplete = true
        }
      } catch {
        await MainActor.run {
          exportError = error.localizedDescription
        }
      }
      await MainActor.run {
        isExporting = false
      }
    }
  }

}

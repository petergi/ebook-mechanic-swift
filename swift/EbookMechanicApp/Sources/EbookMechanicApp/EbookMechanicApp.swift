import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct EbookMechanicApp: App {
    @StateObject private var viewModel = ScanViewModel()
    @State private var selectedDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var options = ScanOptions(directory: FileManager.default.homeDirectoryForCurrentUser)
    @State private var showError: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: viewModel,
                selectedDirectory: $selectedDirectory,
                options: $options,
                onSelectDirectory: selectDirectory,
                onRunScan: runScan
            )
            .frame(minWidth: 900, minHeight: 600)
            .alert(isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
                Alert(
                    title: Text("Unexpected Error"),
                    message: Text(viewModel.errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func selectDirectory() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectedDirectory
        if panel.runModal() == .OK, let url = panel.url {
            selectedDirectory = url
            options.directory = url
        }
        #endif
    }

    private func runScan() {
        Task {
            await viewModel.runScan(options: options)
        }
    }
}

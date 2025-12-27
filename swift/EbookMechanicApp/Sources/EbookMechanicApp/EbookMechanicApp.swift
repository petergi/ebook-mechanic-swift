/// EbookMechanicApp.swift
///
/// The main application entry point for Ebook Mechanic. This file defines the
/// `EbookMechanicApp` conforming to `App`, sets up app-wide state objects, and
/// wires the main window scene to `ContentView`. It also provides helper methods
/// for selecting a directory on macOS and running a scan using the current
/// `ScanOptions`.
import SwiftUI

#if os(macOS)
  import AppKit
#endif

/// The main SwiftUI app type for Ebook Mechanic.
///
/// Responsible for:
/// - Holding shared state such as the `ScanViewModel`, the currently selected directory,
///   and the active `ScanOptions`.
/// - Presenting the primary `ContentView` inside the main window scene.
/// - Handling directory selection on macOS via an `NSOpenPanel`.
/// - Initiating scans using the current options and surfacing unexpected errors.
@main
struct EbookMechanicApp: App {
  /// The shared view model that performs scans and exposes progress and errors.
  @StateObject private var viewModel = ScanViewModel()
  /// The currently selected directory used as the default for scans and as the
  /// starting location for the open panel on macOS.
  @State private var selectedDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  /// The set of options that control how scans are performed, including the target directory.
  @State private var options = ScanOptions(
    directory: FileManager.default.homeDirectoryForCurrentUser)
  /// A convenience flag that can be used to drive error presentation if needed.
  @State private var showError: Bool = false

  /// The main app scene that hosts `ContentView`, applies window sizing constraints,
  /// and presents unexpected error alerts sourced from `viewModel.errorMessage`.
  var body: some Scene {
    WindowGroup {
      ContentView(
        viewModel: viewModel,
        selectedDirectory: $selectedDirectory,
        options: $options,
        onSelectDirectory: selectDirectory,
        onRunScan: runScan,
        onCancelScan: cancelScan,
        onTogglePause: togglePause
      )
      .frame(minWidth: 900, minHeight: 600)
      .alert(
        isPresented: Binding(
          get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })
      ) {
        Alert(
          title: Text("Unexpected Error"),
          message: Text(viewModel.errorMessage ?? "Unknown error"),
          dismissButton: .default(Text("OK"))
        )
      }
    }
  }

  /// Presents a native directory picker to choose a folder to scan. (macOS only)
  ///
  /// On macOS, this method opens an `NSOpenPanel` configured to select directories.
  /// When the user confirms a selection, both `selectedDirectory` and
  /// `options.directory` are updated to the chosen URL. On other platforms, this
  /// method is a no-op.
  ///
  /// - Note: The panel starts at `selectedDirectory`.
  /// - SeeAlso: `runScan()`
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

  /// Starts a scan using the current `options`.
  ///
  /// The scan is performed asynchronously via Swift concurrency. Any errors are
  /// surfaced through `viewModel.errorMessage`, which is bound to an alert in the
  /// main scene.
  ///
  /// - SeeAlso: `selectDirectory()`
  private func runScan() {
    viewModel.startScan(options: options)
  }

  private func cancelScan() {
    viewModel.cancelScan()
  }

  private func togglePause() {
    if viewModel.isPaused {
      viewModel.resumeScan()
    } else {
      viewModel.pauseScan()
    }
  }
}

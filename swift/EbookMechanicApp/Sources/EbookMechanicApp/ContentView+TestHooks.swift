#if DEBUG
  import Foundation
  import SwiftUI
  import EbookMechanicCore

  /// Lightweight snapshot of data the UI renders, exposed only in debug/testing builds.
  struct ContentViewTestHooks {
    let directoryPath: String
    let progressHeadline: String
    let progressDetail: String
    let isProgressVisible: Bool
    let statusMessages: [String]
    let reportFileName: String?
    let corruptedFileNames: [String]
    let corruptedReasons: [String]
    let emptyFolderPaths: [String]
    let summary: ScanResult?
    let attemptRepairToggleDisabled: Bool
    let dryRunToggleDisabled: Bool
    let generateReportToggleDisabled: Bool
    let corruptionOnlyToggleDisabled: Bool
    let emptyFoldersOnlyToggleDisabled: Bool
    let autoMoveToggleDisabled: Bool
    let autoDeleteToggleDisabled: Bool
    let runButtonTitle: String
  }

  extension ContentView {
    var testHooks: ContentViewTestHooks {
      ContentViewTestHooks(
        directoryPath: selectedDirectory.path,
        progressHeadline: viewModel.progressHeadline,
        progressDetail: viewModel.progressDetail,
        isProgressVisible: viewModel.isScanning,
        statusMessages: viewModel.statusMessages,
        reportFileName: viewModel.reportURLs?.first?.lastPathComponent,
        corruptedFileNames: viewModel.corruptedFiles.map { $0.url.lastPathComponent },
        corruptedReasons: viewModel.corruptedFiles.map { $0.reason },
        emptyFolderPaths: viewModel.emptyFolders.map { $0.path },
        summary: viewModel.summary,
        attemptRepairToggleDisabled: viewModel.isScanning,
        dryRunToggleDisabled: viewModel.isScanning,
        generateReportToggleDisabled: viewModel.isScanning,
        corruptionOnlyToggleDisabled: viewModel.isScanning,
        emptyFoldersOnlyToggleDisabled: viewModel.isScanning,
        autoMoveToggleDisabled: viewModel.isScanning || options.dryRun,
        autoDeleteToggleDisabled: viewModel.isScanning || options.dryRun,
        runButtonTitle: viewModel.isScanning ? "Working…" : "Run Scan"
      )
    }
  }
#endif

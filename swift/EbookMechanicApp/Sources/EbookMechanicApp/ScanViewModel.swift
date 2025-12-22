import Foundation
import SwiftUI
import EbookMechanicCore

/// Options that control how a scan operates.
///
/// Use `ScanOptions` to configure the behavior of a scan, including the root
/// directory to scan, whether to attempt repairs, whether the run is a dry-run,
/// and automation flags for moving corrupted files or deleting empty folders.
///
/// Example:
/// ```swift
/// var options = ScanOptions(directory: URL(fileURLWithPath: "/ebooks"))
/// options.dryRun = true
/// options.repair = false
/// options.generateReport = true
/// ```
struct ScanOptions {
    /// Root directory to scan.
    var directory: URL
    /// Name of the folder where corrupted files are moved when automation is enabled.
    var corruptedDirectoryName: String = "CORRUPTED"
    /// Whether to attempt to repair corrupted files after scanning.
    var repair: Bool = false
    /// If true, only performs corruption checks and skips empty-folder scanning.
    var corruptionOnly: Bool = false
    /// If true, only scans for empty folders and skips corruption checks.
    var emptyFoldersOnly: Bool = false
    /// When true, performs a simulation without writing changes to disk.
    var dryRun: Bool = true
    /// Automatically move corrupted files into `corruptedDirectoryName` when not a dry run.
    var autoMoveCorrupted: Bool = false
    /// Automatically delete empty folders when not a dry run.
    var autoDeleteEmptyFolders: Bool = false
    /// Generate a Markdown report summarizing the scan.
    var generateReport: Bool = false
    /// Normalize EPUB files into a canonical ZIP layout.
    var normalizeEPUBs: Bool = false
    /// Re-normalize EPUBs even if they appear already normalized.
    var forceNormalize: Bool = false
    /// Use epubcheck for EPUB validation.
    var useExternalEPUBValidator: Bool = false
    /// Use pdfcpu for PDF validation.
    var useExternalPDFValidator: Bool = false
    /// The maximum number of concurrent validations to run.
    var maxConcurrentValidations: Int = 1
    /// Whether to use the validation cache.
    var useCache: Bool = true
    /// Whether to show performance metrics after the scan.
    var showPerformanceMetrics: Bool = false
}

/// View model that orchestrates scanning and exposes UI-facing state.
///
/// `ScanViewModel` performs scans using `EbookMechanicCore.FileScanner`, tracks
/// progress and results, and publishes values suitable for binding in SwiftUI
/// views like `ContentView`. Use `runScan(options:)` to start a scan and
/// observe published properties for updates.
@MainActor
final class ScanViewModel: ObservableObject {
    /// Indicates whether a scan is currently in progress.
    @Published var isScanning: Bool = false
    /// High-level progress message (e.g., current phase).
    @Published var progressHeadline: String = ""
    /// Detailed progress message (e.g., current file or counts).
    @Published var progressDetail: String = ""
    /// List of corrupted files discovered during scanning.
    @Published var corruptedFiles: [CorruptedFile] = []
    /// List of empty folders discovered during scanning.
    @Published var emptyFolders: [URL] = []
    /// Summary of the scan, including totals and per-format breakdowns.
    @Published var summary: ScanResult?
    /// Human-readable log of notable events during the scan.
    @Published var statusMessages: [String] = []
    /// Location of the generated Markdown report, when `generateReport` is enabled.
    @Published var reportURL: URL?
    /// User-presentable error message if a failure occurs.
    @Published var errorMessage: String?
    /// Performance metrics from the scan.
    @Published var performanceMetrics: PerformanceMetrics?

    /// Resets all published state to defaults in preparation for a new scan.
    func reset() {
        corruptedFiles = []
        emptyFolders = []
        summary = nil
        statusMessages.removeAll()
        reportURL = nil
        errorMessage = nil
        performanceMetrics = nil
        progressHeadline = ""
        progressDetail = ""
    }

    /// Runs a scan with the provided options.
    ///
    /// This method coordinates file and folder scanning via `FileScanner`, updates
    /// progress and results on the main actor, and conditionally performs repair,
    /// normalization, and automation steps based on the given `options`.
    ///
    /// - Parameter options: The configuration that controls scanning behavior.
    /// - Important: This method is `async` and should be awaited from an asynchronous context.
    func runScan(options: ScanOptions) async {
        guard !isScanning else { return }
        reset()
        isScanning = true
        defer { isScanning = false }

        do {
            let validator = FileValidator(
                useExternalEPUBValidator: options.useExternalEPUBValidator,
                useExternalPDFValidator: options.useExternalPDFValidator,
                useCache: options.useCache
            )
            let scanner = FileScanner(
                rootDirectory: options.directory,
                corruptedDirectoryName: options.corruptedDirectoryName,
                validator: validator,
                maxConcurrentValidations: options.maxConcurrentValidations
            )

            let progressHandler: FileScanner.ProgressHandler = { [weak self] event in
                Task { @MainActor in
                    guard let self else { return }
                    switch event.stage {
                    case .validatingFile(let url):
                        self.progressHeadline = "Validating Files"
                        self.progressDetail = url.lastPathComponent
                    case .scanningFiles:
                        self.progressHeadline = "Scanning Files"
                        let concurrentCount = event.concurrentValidationCount > 0 ? " (\(event.concurrentValidationCount) concurrent)" : ""
                        self.progressDetail = "\(event.completed)/\(event.total) processed\(concurrentCount)"
                    case .scanningFolders:
                        self.progressHeadline = "Scanning Folders"
                        self.progressDetail = "\(event.completed)/\(event.total)"
                    case .movingCorruptedFiles:
                        self.progressHeadline = "Moving Corrupted Files"
                        self.progressDetail = event.currentItem
                    case .deletingEmptyFolders:
                        self.progressHeadline = "Deleting Empty Folders"
                        self.progressDetail = event.currentItem
                    case .repairingFiles:
                        self.progressHeadline = "Repairing Files"
                        self.progressDetail = event.currentItem
                    case .normalizingFiles:
                        self.progressHeadline = "Normalizing EPUBs"
                        self.progressDetail = event.currentItem
                    }
                }
            }

            var scanResult: ScanResult?
            if !options.emptyFoldersOnly {
                let result = try await scanner.scanForCorruption(progress: progressHandler)
                await MainActor.run {
                    self.summary = result
                    self.corruptedFiles = result.corruptedFiles
                    self.statusMessages.append("Scanned \(result.totalFiles) files")
                    if result.corruptedFiles.isEmpty {
                        self.statusMessages.append("No corrupted files found")
                    }
                    else {
                        self.statusMessages.append("Detected \(result.corruptedFiles.count) corrupted file(s)")
                    }
                }
                scanResult = result

                if options.repair, let scanResult, !scanResult.corruptedFiles.isEmpty {
                    let (repairs, repairedCount) = await scanner.repairCorruptedFiles(progress: progressHandler)
                    await MainActor.run {
                        self.statusMessages.append("Repair attempts: \(repairs.count), fixed: \(repairedCount)")
                        self.corruptedFiles = repairs.enumerated().compactMap { index, result in
                            guard index < scanResult.corruptedFiles.count else { return nil }
                            var file = scanResult.corruptedFiles[index]
                            if result.fixed {
                                file = CorruptedFile(url: file.url, reason: "Fixed", size: file.size)
                            }
                            return file
                        }
                    }
                }

                if !options.dryRun, (scanResult?.corruptedFiles.isEmpty == false), options.autoMoveCorrupted {
                    try await scanner.moveCorruptedFiles(progress: progressHandler)
                    await MainActor.run {
                        self.statusMessages.append("Moved corrupted files to \(options.corruptedDirectoryName)")
                    }
                }

                if options.normalizeEPUBs {
                    let (normalized, skipped) = await scanner.normalizeEPUBs(force: options.forceNormalize, dryRun: options.dryRun, progress: progressHandler)
                    await MainActor.run {
                        self.statusMessages.append("EPUB normalization: normalized=\(normalized), skipped=\(skipped)")
                    }
                }
            }

            if !options.corruptionOnly {
                let folderResult = try await scanner.scanForEmptyFolders(progress: progressHandler)
                await MainActor.run {
                    self.emptyFolders = folderResult.emptyFolders
                    self.statusMessages.append("Discovered \(folderResult.emptyFolders.count) empty folder(s)")
                }

                if !options.dryRun, !folderResult.emptyFolders.isEmpty, options.autoDeleteEmptyFolders {
                    try await scanner.deleteEmptyFolders(progress: progressHandler)
                    await MainActor.run {
                        self.statusMessages.append("Deleted \(folderResult.emptyFolders.count) empty folder(s)")
                    }
                }
            }

            if options.generateReport {
                let url = try await scanner.generateReport(into: options.directory)
                await MainActor.run {
                    self.reportURL = url
                    self.statusMessages.append("Report generated at \(url.lastPathComponent)")
                }
            }

            if options.showPerformanceMetrics {
                let metrics = await scanner.performanceMetrics
                await MainActor.run {
                    self.performanceMetrics = metrics
                }
            }

            await MainActor.run {
                self.progressHeadline = ""
                self.progressDetail = ""
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}


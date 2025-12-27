import EbookMechanicCore
import Foundation
import SwiftUI

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
  /// Indicates whether a cancellation request is in progress.
  @Published var isCancelling: Bool = false
  /// Indicates whether a scan is currently paused.
  @Published var isPaused: Bool = false
  /// High-level progress message (e.g., current phase).
  @Published var progressHeadline: String = ""
  /// Detailed progress message (e.g., current file or counts).
  @Published var progressDetail: String = ""
  /// List of corrupted files discovered during scanning.
  @Published var corruptedFiles: [CorruptedFile] = []
  /// Results of repair attempts when repair is enabled.
  @Published var repairResults: [RepairResult] = []
  /// List of empty folders discovered during scanning.
  @Published var emptyFolders: [URL] = []
  /// Summary of the scan, including totals and per-format breakdowns.
  @Published var summary: ScanResult?
  /// Human-readable log of notable events during the scan.
  @Published var statusMessages: [String] = []
  /// Location of the generated Markdown report, when `generateReport` is enabled.
  @Published var reportURLs: [URL]?
  /// Validation results keyed by file URL.
  @Published var validationResults: [URL: ValidationResult] = [:]
  /// EPUB compliance details keyed by file URL.
  @Published var epubComplianceResults: [URL: EPUBComplianceResult] = [:]
  /// PDF structure details keyed by file URL.
  @Published var pdfValidationResults: [URL: PDFValidationResult] = [:]
  @Published var errorMessage: String?
  @Published var performanceMetrics: PerformanceMetrics?
  private var scanTask: Task<Void, Never>?
  private var scanControl: ScanControl?

  /// Files that passed structure validation but failed spec compliance
  var nonCompliantFiles: [ValidationResult] {
    validationResults.values.filter { $0.status == .nonCompliant }
  }

  /// Files that have warnings but are otherwise valid
  var filesWithWarnings: [ValidationResult] {
    validationResults.values.filter { result in
      let statusAllowsWarnings = result.status == .ok || result.status == .nonCompliant
      guard statusAllowsWarnings else { return false }
      return result.epubComplianceDetails?.hasWarnings == true
        || !(result.pdfValidationDetails?.streamErrors.isEmpty ?? true)
    }
  }

  /// Errors that can occur during scan view model operations
  enum ScanViewModelError: LocalizedError {
    case noScanData
    case reportGenerationFailed(String)

    var errorDescription: String? {
      switch self {
      case .noScanData:
        return "No scan data available. Please run a scan first."
      case .reportGenerationFailed(let reason):
        return "Failed to generate report: \(reason)"
      }
    }
  }

  /// Resets all published state to defaults in preparation for a new scan.
  func reset() {
    corruptedFiles = []
    repairResults = []
    emptyFolders = []
    summary = nil
    statusMessages.removeAll()
    reportURLs = nil
    validationResults = [:]
    epubComplianceResults = [:]
    pdfValidationResults = [:]
    errorMessage = nil
    performanceMetrics = nil
    progressHeadline = ""
    progressDetail = ""
    isPaused = false
  }

  /// Starts a scan in a cancellable task.
  func startScan(options: ScanOptions) {
    guard !isScanning else { return }
    scanTask?.cancel()
    scanTask = Task { [weak self] in
      guard let self else { return }
      await self.runScan(options: options)
      await MainActor.run {
        self.scanTask = nil
      }
    }
  }

  /// Cancels an in-flight scan.
  func cancelScan() {
    guard isScanning else { return }
    isCancelling = true
    isPaused = false
    progressHeadline = "Cancelling"
    progressDetail = "Stopping current scan..."
    Task { [scanControl] in
      await scanControl?.resume()
    }
    scanTask?.cancel()
  }

  /// Pauses an in-flight scan.
  func pauseScan() {
    guard isScanning, !isPaused else { return }
    isPaused = true
    progressHeadline = "Paused"
    progressDetail = "Scan paused"
    Task { [scanControl] in
      await scanControl?.pause()
    }
  }

  /// Resumes a paused scan.
  func resumeScan() {
    guard isScanning, isPaused else { return }
    isPaused = false
    progressHeadline = "Resuming"
    progressDetail = "Continuing scan..."
    Task { [scanControl] in
      await scanControl?.resume()
    }
  }

  /// Runs a scan with the provided options.
  ///
  /// This method coordinates file and folder scanning via `FileScanner`, updates
  /// progress and results on the main actor, and conditionally performs repair,
  /// normalization, and automation steps based on the given `options`.
  ///
  /// - Parameter options: The configuration that controls scanning behavior.
  /// - Important: This method is `async` and should be awaited from an asynchronous context.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  func runScan(options: ScanOptions) async {
    guard !isScanning else { return }
    reset()
    isScanning = true
    isCancelling = false
    isPaused = false
    scanControl = ScanControl()
    defer {
      isScanning = false
      isCancelling = false
      isPaused = false
      scanControl = nil
    }

    do {
      try Task.checkCancellation()
      let validator = FileValidator(
        useExternalEPUBValidator: options.useExternalTools,
        useExternalPDFValidator: options.useExternalTools,
        cacheSize: options.useCache ? 1000 : 0
      )
      let scanner = FileScanner(
        rootDirectory: options.directory,
        corruptedDirectoryName: options.corruptedDirectoryName,
        reportFormats: Array(options.selectedReportFormats),
        maxConcurrentValidations: options.maxConcurrentValidations,
        validator: validator,
        scanControl: scanControl
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
            let concurrentCount =
              (event.concurrentValidationCount ?? 0) > 0
              ? " (\(event.concurrentValidationCount ?? 0) concurrent)" : ""
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
        await scanControl?.waitIfPaused()
        try Task.checkCancellation()
        let result = try await scanner.scanForCorruption(progress: progressHandler)
        await MainActor.run {
          self.summary = result
          self.corruptedFiles = result.corruptedFiles
          self.updateValidationCaches(using: result)
          self.statusMessages.append("Scanned \(result.totalFiles) files")
          if result.corruptedFiles.isEmpty {
            self.statusMessages.append("No corrupted files found")
          } else {
            self.statusMessages.append("Detected \(result.corruptedFiles.count) corrupted file(s)")
          }
        }
        scanResult = result

        if options.repair, let scanResult, !scanResult.corruptedFiles.isEmpty {
          await scanControl?.waitIfPaused()
          try Task.checkCancellation()
          let (repairs, repairedCount) = await scanner.repairCorruptedFiles(
            progress: progressHandler)
          await MainActor.run {
            self.statusMessages.append("Repair attempts: \(repairs.count), fixed: \(repairedCount)")
            self.corruptedFiles = repairs.enumerated().compactMap {
              (index, result) -> CorruptedFile? in
              guard index < scanResult.corruptedFiles.count else { return nil }
              var file = scanResult.corruptedFiles[index]
              if result.fixed {
                file = CorruptedFile(
                  url: file.url,
                  reason: "Fixed",
                  size: file.size,
                  status: .ok,
                  validationLevel: file.validationLevel
                )
              }
              return file
            }
            self.repairResults = repairs
            if let scanResult {
              self.updateValidationCaches(
                using: ScanResult(
                  totalFiles: scanResult.totalFiles,
                  corruptedFiles: self.corruptedFiles,
                  okFiles: scanResult.okFiles,
                  breakdowns: scanResult.breakdowns,
                  emptyFolders: scanResult.emptyFolders,
                  totalFolders: scanResult.totalFolders,
                  foldersWithEbooks: scanResult.foldersWithEbooks,
                  totalProcessedFiles: scanResult.totalProcessedFiles,
                  totalCorruptedFiles: scanResult.totalCorruptedFiles,
                  totalWarnings: scanResult.totalWarnings,
                  totalErrors: scanResult.totalErrors
                )
              )
            }
          }
        }

        if !options.dryRun, scanResult?.corruptedFiles.isEmpty == false, options.autoMoveCorrupted {
          await scanControl?.waitIfPaused()
          try Task.checkCancellation()
          try await scanner.moveCorruptedFiles(progress: progressHandler)
          await MainActor.run {
            self.statusMessages.append("Moved corrupted files to \(options.corruptedDirectoryName)")
          }
        }

        if options.normalizeEPUBs {
          await scanControl?.waitIfPaused()
          try Task.checkCancellation()
          let (normalized, skipped) = await scanner.normalizeEPUBs(
            force: options.forceNormalize, dryRun: options.dryRun, progress: progressHandler)
          await MainActor.run {
            self.statusMessages.append(
              "EPUB normalization: normalized=\(normalized), skipped=\(skipped)")
          }
        }
      }

      if !options.corruptionOnly {
        await scanControl?.waitIfPaused()
        try Task.checkCancellation()
        let folderResult = try await scanner.scanForEmptyFolders(progress: progressHandler)
        await MainActor.run {
          self.emptyFolders = folderResult.emptyFolders
          self.statusMessages.append(
            "Discovered \(folderResult.emptyFolders.count) empty folder(s)")
        }

        if !options.dryRun, !folderResult.emptyFolders.isEmpty, options.autoDeleteEmptyFolders {
          await scanControl?.waitIfPaused()
          try Task.checkCancellation()
          try await scanner.deleteEmptyFolders(progress: progressHandler)
          await MainActor.run {
            self.statusMessages.append("Deleted \(folderResult.emptyFolders.count) empty folder(s)")
          }
        }
      }

      if options.generateReport {
        await scanControl?.waitIfPaused()
        try Task.checkCancellation()
        let urls = try await scanner.generateReport(into: options.directory)
        await MainActor.run {
          self.reportURLs = urls
          for url in urls {
            self.statusMessages.append("Report generated at \(url.lastPathComponent)")
          }
        }
      }

      if options.showPerformanceStats {
        await scanControl?.waitIfPaused()
        try Task.checkCancellation()
        let metrics = await scanner.getPerformanceMetrics()
        await MainActor.run {
          self.performanceMetrics = metrics
        }
      }

      await MainActor.run {
        self.progressHeadline = ""
        self.progressDetail = ""
      }
    } catch is CancellationError {
      await MainActor.run {
        self.statusMessages.append("Scan cancelled")
        self.progressHeadline = ""
        self.progressDetail = ""
      }
    } catch {
      await MainActor.run {
        self.errorMessage = error.localizedDescription
      }
    }
  }

  /// Generates reports in the specified formats and returns their URLs.
  ///
  /// - Parameters:
  ///   - directory: The directory where reports should be saved
  ///   - options: Scan options containing directory and corrupted directory name
  ///   - formats: Set of report formats to generate
  /// - Returns: Array of URLs pointing to the generated report files
  /// - Throws: ScanViewModelError.noScanData if no scan has been performed
  func generateReport(into directory: URL, options: ScanOptions, formats: Set<ReportFormat>)
    async throws -> [URL]
  {
    guard summary != nil else {
      throw ScanViewModelError.noScanData
    }

    // Use the FileScanner's generateReport method by creating a temporary scanner
    // with the formats we want to generate
    let validator = FileValidator(
      useExternalEPUBValidator: options.useExternalTools,
      useExternalPDFValidator: options.useExternalTools,
      cacheSize: options.useCache ? 1000 : 0
    )
    let scanner = FileScanner(
      rootDirectory: options.directory,
      corruptedDirectoryName: options.corruptedDirectoryName,
      reportFormats: Array(formats),
      maxConcurrentValidations: options.maxConcurrentValidations,
      validator: validator
    )

    return try await scanner.generateReport(into: directory)
  }

  private func updateValidationCaches(using result: ScanResult) {
    var results: [URL: ValidationResult] = [:]

    for validation in result.okFiles {
      results[validation.url] = validation
    }

    for (index, corrupted) in result.corruptedFiles.enumerated() {
      if results[corrupted.url] == nil {
        results[corrupted.url] = ValidationResult(
          originalIndex: index,
          url: corrupted.url,
          size: corrupted.size,
          isValid: false,
          reason: corrupted.reason,
          status: corrupted.status,
          validationLevel: corrupted.validationLevel,
          fingerprint: corrupted.fingerprint,
          pdfValidationDetails: corrupted.pdfValidationDetails,
          epubComplianceDetails: corrupted.epubComplianceDetails
        )
      }
    }

    validationResults = results
    epubComplianceResults = results.compactMapValues { $0.epubComplianceDetails }
    pdfValidationResults = results.compactMapValues { $0.pdfValidationDetails }
  }
}

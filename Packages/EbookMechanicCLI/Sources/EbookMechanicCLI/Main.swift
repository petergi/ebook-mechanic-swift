import ArgumentParser
import EbookMechanicCore
import Foundation

@main
struct EbookMechanicCLI: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ebook-mechanic",
    abstract: "A tool to validate, repair, and organize ebook libraries.",
    version: "2.0.0"
  )

  @Option(name: .shortAndLong, help: "The directory to scan for ebooks.")
  var dir: String = "."

  @Option(name: .shortAndLong, help: "The directory to move corrupted files to.")
  var corruptedDir: String = "CORRUPTED"

  @Flag(name: .long, help: "Scan for corrupted files only, skip empty folder analysis.")
  var corruptionOnly: Bool = false

  @Flag(name: .long, help: "Scan for empty folders only, skip corruption scan.")
  var emptyFoldersOnly: Bool = false

  @Flag(name: .shortAndLong, help: "Attempt to repair corrupted files.")
  var repair: Bool = false

  @Flag(name: .long, help: "Don't actually make any changes to the files.")
  var dryRun: Bool = false

  @Flag(name: .long, help: "Automatically confirm any prompts.")
  var autoConfirm: Bool = false

  @Flag(name: .long, help: "Enable verbose logging.")
  var verbose: Bool = false

  @Flag(name: .long, help: "Generate a report of the scan results.")
  var report: Bool = false

  @Option(
    name: .long, help: "The format of the report to generate.",
    completion: .list(["markdown", "json", "csv", "html"]))
  var reportFormat: String = "markdown"

  @Option(
    name: .long,
    help: "Comma-separated list of report formats to generate (markdown,json,csv,html).",
    completion: .list(["markdown,json,csv,html"]))
  var reportFormats: String?

  @Flag(name: .long, help: "Normalize EPUB files.")
  var normalizeEpubs: Bool = false

  @Flag(
    name: .long, help: "Force normalization of EPUB files, even if they appear to be normalized.")
  var forceNormalize: Bool = false

  @Flag(name: .long, help: "Use epubcheck for more detailed EPUB validation.")
  var useEpubcheck: Bool = false

  @Flag(
    name: .long,
    help: "Use external validation tools (epubcheck, pdfcpu) for comprehensive validation.")
  var externalTools: Bool = false

  @Option(name: .long, help: "Maximum number of concurrent validations.")
  var maxConcurrent: Int = ProcessInfo.processInfo.activeProcessorCount

  @Flag(name: .long, help: "Disable the validation cache.")
  var noCache: Bool = false

  @Flag(name: .long, help: "Show performance statistics at the end of the scan.")
  var performanceStats: Bool = false

  // swiftlint:disable:next function_body_length
  func run() throws {
    let group = DispatchGroup()
    group.enter()

    Task {
      do {
        let rootURL = URL(fileURLWithPath: dir).resolvingSymlinksInPath()
        let useExternalEpub = useEpubcheck || externalTools
        let useExternalPdf = externalTools
        let reportFormats = parseReportFormats()
        let validator = FileValidator(
          useExternalEPUBValidator: useExternalEpub, useExternalPDFValidator: useExternalPdf,
          cacheSize: noCache ? 0 : 1000)
        let scanner = FileScanner(
          rootDirectory: rootURL,
          corruptedDirectoryName: corruptedDir,
          reportFormats: reportFormats,
          maxConcurrentValidations: maxConcurrent,
          validator: validator
        )

        let printer = ProgressPrinter(verbose: verbose)
        await warnIfExternalToolsMissing(
          printer: printer,
          useExternalEpub: useExternalEpub,
          useExternalPdf: useExternalPdf
        )

        if emptyFoldersOnly {
          _ = try await scanner.scanForEmptyFolders(progress: printer.handle)
          printer.printHeader("Empty Folder Analysis")
          // reportEmptyFolders(folders, printer: printer)
          // try await handleEmptyFolderCleanup(
          //   configuration: self, scanner: scanner, result: folders, printer: printer)
          group.leave()
          return
        }

        let scanResult = try await scanner.scanForCorruption(progress: printer.handle)
        printer.printHeader("Corruption Scan Summary")
        printer.printScanResult(scanResult)
        printEpubComplianceSummary(scanResult, printer: printer)

        if repair, !scanResult.corruptedFiles.isEmpty {
          printer.printHeader("Repairing Corrupted Files")
          let (repairs, repairedCount) = await scanner.repairCorruptedFiles(
            progress: printer.handle)
          printer.printRepairSummary(results: repairs, repairedCount: repairedCount)
        }

        if normalizeEpubs {
          printer.printHeader("Normalizing EPUBs")
          let (normalized, skipped) = await scanner.normalizeEPUBs(
            force: forceNormalize, dryRun: dryRun, progress: printer.handle)
          printer.printInfo("EPUB normalization: normalized=\(normalized), skipped=\(skipped)")
        }

        if !corruptionOnly {
          _ = try await scanner.scanForEmptyFolders(progress: printer.handle)
          printer.printHeader("Folder Analysis")
          // reportEmptyFolders(folders, printer: printer)
          // try await handleEmptyFolderCleanup(
          //   configuration: self, scanner: scanner, result: folders, printer: printer)
        }

        if !dryRun {
          // try await handleCorruptedMoves(configuration: self, scanner: scanner, printer: printer)
        } else {
          printer.printInfo("Dry run enabled – no files were moved or deleted.")
        }

        if report {
          let generatedReportURLs = try await scanner.generateReport(
            into: URL(fileURLWithPath: dir))
          printer.printHeader("Reports Generated")
          for reportURL in generatedReportURLs {
            printer.printSuccess("Report generated at \(reportURL.path)")
          }
        }

        if performanceStats {
          let metrics = await scanner.performanceMetrics
          printer.printHeader("Performance Statistics")
          printer.printPerformanceMetrics(metrics)
        }

        printer.printFooter("EbookMechanic completed successfully")
      } catch {
        print("❌ Error: \(error)")
      }
      group.leave()
    }

    group.wait()
  }

  private func parseReportFormats() -> [ReportFormat] {
    if let reportFormats, !reportFormats.isEmpty {
      let values = reportFormats.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      }
      let formats = values.compactMap { ReportFormat(rawValue: $0) }
      return formats.isEmpty ? [ReportFormat(rawValue: reportFormat) ?? .markdown] : formats
    }
    return [ReportFormat(rawValue: reportFormat) ?? .markdown]
  }

  private func warnIfExternalToolsMissing(
    printer: ProgressPrinter,
    useExternalEpub: Bool,
    useExternalPdf: Bool
  ) async {
    if useExternalEpub, await ExternalEPUBValidator.isEpubcheckInstalled() == false {
      printer.printInfo("⚠️ epubcheck not found. Falling back to built-in EPUB validation.")
    }
    if useExternalPdf, await ExternalPDFValidator.isPdfcpuInstalled() == false {
      printer.printInfo("⚠️ pdfcpu not found. Falling back to built-in PDF validation.")
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func printEpubComplianceSummary(_ result: ScanResult, printer: ProgressPrinter) {
    let epubOkFiles = result.okFiles.filter {
      $0.url.pathExtension.lowercased() == "epub"
    }
    let epubCorruptedFiles = result.corruptedFiles.filter {
      $0.url.pathExtension.lowercased() == "epub"
    }
    let total = epubOkFiles.count + epubCorruptedFiles.count
    guard total > 0 else { return }

    var compliant = 0
    var warnings = 0
    var nonCompliant = 0

    for file in epubOkFiles {
      if let details = file.epubComplianceDetails {
        if details.isCompliant {
          details.hasWarnings ? (warnings += 1) : (compliant += 1)
        } else {
          nonCompliant += 1
        }
        continue
      }
      switch file.status {
      case .ok:
        compliant += 1
      case .nonCompliant:
        warnings += 1
      case .corrupt, .validationError:
        nonCompliant += 1
      }
    }

    for file in epubCorruptedFiles {
      if let details = file.epubComplianceDetails {
        if details.isCompliant {
          details.hasWarnings ? (warnings += 1) : (compliant += 1)
        } else {
          nonCompliant += 1
        }
        continue
      }
      switch file.status {
      case .ok:
        compliant += 1
      case .nonCompliant:
        warnings += 1
      case .corrupt, .validationError:
        nonCompliant += 1
      }
    }

    printer.printInfo(
      "Found \(total) EPUB files: \(compliant) compliant, \(warnings) with warnings, \(nonCompliant) non-compliant"
    )
  }
}

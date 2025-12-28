import ArgumentParser
import EbookMechanicCore
import Foundation

struct EbookMechanicEPUBCLI: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "epub-mechanic",
    abstract: "A tool to validate and repair EPUB files.",
    version: "2.0.0",
    subcommands: [Validate.self, Repair.self],
    defaultSubcommand: Validate.self
  )
}

extension EbookMechanicEPUBCLI {
  struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "validate",
      abstract: "Validate EPUB files in a directory."
    )

    @Option(name: .shortAndLong, help: "The directory to scan for EPUB files.")
    var dir: String = "."

    @Flag(name: .long, help: "Enable verbose logging.")
    var verbose: Bool = false

    @Flag(
      name: .long, help: "Perform a detailed EPUB specification compliance check using epubcheck.")
    var specCheck: Bool = false

    @Flag(name: .long, help: "Display detailed warnings from EPUB specification checks")
    var showWarnings: Bool = false

    @Flag(name: .long, help: "Perform EPUB accessibility compliance checks")
    var accessibility: Bool = false

    @Option(name: .long, help: "Extract EPUB metadata to file (json or yaml)")
    var extractMetadata: String?

    func run() throws {
      let group = DispatchGroup()
      group.enter()

      Task {
        do {
          let rootURL = URL(fileURLWithPath: dir).resolvingSymlinksInPath()
          let scanner = FileScanner(
            rootDirectory: rootURL, corruptedDirectoryName: "CORRUPTED", validator: FileValidator())
          let isVerbose = verbose

          print("📂 Scanning directory: \(dir)")

          let result = try await scanner.scanForCorruption(
            progress: makeValidationProgressHandler(verbose: isVerbose))
          let epubFiles = filterEpubCorrupted(from: result.corruptedFiles)
          let epubValidations = filterEpubValidations(from: result.okFiles)
          let formatter = EPUBReportFormatter()

          if specCheck {
            await validateWithSpecCheck(
              files: epubValidations,
              formatter: formatter
            )
          } else {
            printCorruptionResults(for: epubFiles, formatter: formatter)
          }

          await extractMetadataIfNeeded(
            from: epubValidations,
            format: extractMetadata
          )

          print("✅ EPUB Mechanic validation completed successfully")
        } catch {
          print("❌ Error: \(error)")
        }
        group.leave()
      }

      group.wait()
    }

    private func makeValidationProgressHandler(verbose: Bool) -> FileScanner.ProgressHandler {
      { event in
        guard verbose else { return }
        switch event.stage {
        case .scanningFiles:
          print("🔎 Scanning for EPUB files...")
        case .validatingFile(let url):
          if url.pathExtension.lowercased() == "epub" {
            print("  Validating: \(url.lastPathComponent)")
          }
        default:
          break
        }
      }
    }

    private func filterEpubCorrupted(from files: [CorruptedFile]) -> [CorruptedFile] {
      files.filter { $0.url.pathExtension.lowercased() == "epub" }
    }

    private func filterEpubValidations(from files: [ValidationResult]) -> [ValidationResult] {
      files.filter { $0.url.pathExtension.lowercased() == "epub" }
    }

    private func validateWithSpecCheck(
      files: [ValidationResult],
      formatter: EPUBReportFormatter
    ) async {
      for file in files {
        let validationResult = await ExternalValidators.validateEpub(
          at: file.url.path,
          showWarnings: showWarnings,
          checkAccessibility: accessibility
        )
        formatter.printValidationResults(for: validationResult)
      }
    }

    private func printCorruptionResults(
      for files: [CorruptedFile],
      formatter: EPUBReportFormatter
    ) {
      for file in files {
        let validationResult = ValidationResult(
          originalIndex: 0, url: file.url, size: file.size, isValid: false,
          reason: file.reason, status: file.status, fingerprint: file.fingerprint,
          pdfValidationDetails: file.pdfValidationDetails,
          epubComplianceDetails: file.epubComplianceDetails
        )
        formatter.printValidationResults(for: validationResult)
      }
    }

    private func extractMetadataIfNeeded(
      from files: [ValidationResult],
      format: String?
    ) async {
      guard let format else { return }

      for file in files {
        do {
          try await extractEPUBMetadata(at: file.url, format: format)
        } catch {
          print("Failed to extract metadata from \(file.url.lastPathComponent): \(error)")
        }
      }
    }

    private func extractEPUBMetadata(at url: URL, format: String) async throws {
      // Placeholder: full metadata extraction requires ZipArchive access.
      let metadata: [String: String] = [
        "title": url.deletingPathExtension().lastPathComponent,
        "format": "EPUB",
        "note": "Full metadata extraction requires ZipArchive access"
      ]

      let outputURL = url.deletingPathExtension().appendingPathExtension("metadata.\(format)")

      if format == "json" {
        let jsonData = try JSONSerialization.data(
          withJSONObject: metadata, options: [.prettyPrinted])
        try jsonData.write(to: outputURL)
      } else if format == "yaml" {
        var yamlString = ""
        for (key, value) in metadata {
          yamlString += "\(key): \(value)\n"
        }
        try yamlString.write(to: outputURL, atomically: true, encoding: .utf8)
      }

      print("✓ Saved metadata: \(outputURL.lastPathComponent)")
    }
  }

  struct Repair: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "repair",
      abstract: "Repair corrupted EPUB files."
    )

    @Option(name: .shortAndLong, help: "The directory to scan for EPUB files.")
    var dir: String = "."

    @Flag(name: .long, help: "Enable verbose logging.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Don't actually make any changes to the files.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Repair EPUB metadata.")
    var fixMetadata: Bool = false

    func run() throws {
      let group = DispatchGroup()
      group.enter()

      Task {
        do {
          let rootURL = URL(fileURLWithPath: dir).resolvingSymlinksInPath()
          let scanner = FileScanner(
            rootDirectory: rootURL, corruptedDirectoryName: "CORRUPTED", validator: FileValidator())
          let isVerbose = verbose
          let isDryRun = dryRun

          print("📂 Scanning directory: \(dir)")
          print("🔧 Repair mode: enabled")
          print("🔍 Dry run: \(isDryRun ? "yes" : "no")")

          let result = try await scanner.scanForCorruption(
            progress: makeRepairProgressHandler(verbose: isVerbose))
          let epubFiles = filterEpubCorrupted(from: result.corruptedFiles)
          let epubValidations = filterEpubValidations(from: result.okFiles)

          await repairCorruptedFilesIfNeeded(
            scanner: scanner,
            files: epubFiles,
            isDryRun: isDryRun,
            verbose: isVerbose
          )

          await repairMetadataIfNeeded(
            files: epubValidations,
            isDryRun: isDryRun
          )

          print("✅ EPUB Mechanic repair completed successfully")
        } catch {
          print("❌ Error: \(error)")
        }
        group.leave()
      }

      group.wait()
    }

    private func makeRepairProgressHandler(verbose: Bool) -> FileScanner.ProgressHandler {
      { event in
        guard verbose else { return }
        switch event.stage {
        case .scanningFiles:
          print("🔎 Scanning for EPUB files...")
        case .validatingFile(let url):
          if url.pathExtension.lowercased() == "epub" {
            print("  Validating: \(url.lastPathComponent)")
          }
        case .repairingFiles:
          print("🔧 Repairing EPUB files...")
        default:
          break
        }
      }
    }

    private func filterEpubCorrupted(from files: [CorruptedFile]) -> [CorruptedFile] {
      files.filter { $0.url.pathExtension.lowercased() == "epub" }
    }

    private func filterEpubValidations(from files: [ValidationResult]) -> [ValidationResult] {
      files.filter { $0.url.pathExtension.lowercased() == "epub" }
    }

    private func repairCorruptedFilesIfNeeded(
      scanner: FileScanner,
      files: [CorruptedFile],
      isDryRun: Bool,
      verbose: Bool
    ) async {
      guard !isDryRun, !files.isEmpty else { return }

      let (_, repairedCount) = await scanner.repairCorruptedFiles { event in
        guard verbose else { return }
        switch event.stage {
        case .repairingFiles:
          print("  🔧 Repairing: \(event.currentItem)")
        default:
          break
        }
      }
      print("📈 Repair Summary: \(repairedCount) files repaired.")
    }

    private func repairMetadataIfNeeded(
      files: [ValidationResult],
      isDryRun: Bool
    ) async {
      guard fixMetadata, !isDryRun else { return }

      print("🔧 Fixing metadata in EPUB files...")
      for file in files {
        do {
          let result = try await repairEPUBMetadata(at: file.url)
          if result.fixed {
            print("✓ Fixed metadata: \(file.url.lastPathComponent)")
          } else {
            print("• No metadata updates needed: \(file.url.lastPathComponent)")
          }
        } catch {
          print("✗ Failed to fix metadata for \(file.url.lastPathComponent): \(error)")
        }
      }
    }

    private func repairEPUBMetadata(at url: URL) async throws -> RepairResult {
      let repairer = EPUBMetadataRepairer()
      return try repairer.repair(at: url)
    }
  }
}

EbookMechanicEPUBCLI.main()

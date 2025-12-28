// swiftlint:disable file_length
import ArgumentParser
import EbookMechanicCore
import Foundation

struct EbookMechanicPDFCLI: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "pdf-mechanic",
    abstract: "A tool to validate and repair PDF files.",
    version: "2.0.0",
    subcommands: [Validate.self, Repair.self],
    defaultSubcommand: Validate.self
  )
}

extension EbookMechanicPDFCLI {
  struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "validate",
      abstract: "Validate PDF files in a directory."
    )

    @Option(name: .shortAndLong, help: "The directory to scan for PDF files.")
    var dir: String = "."

    @Flag(name: .long, help: "Enable verbose logging.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Perform a detailed PDF structure compliance check using pdfcpu.")
    var structureCheck: Bool = false

    @Flag(name: .long, help: "Display PDF object stream compression analysis")
    var showStreams: Bool = false

    @Flag(name: .long, help: "Display PDF encryption and security details")
    var encryptionInfo: Bool = false

    @Option(
      name: .long, help: "Extract metadata from the PDF.",
      completion: .list(["info", "pages", "permissions"]))
    var extract: String?

    @Option(
      name: .customLong("extract-metadata"), help: "Extract metadata from the PDF to json or yaml.",
      completion: .list(["json", "yaml"]))
    var extractMetadata: String?

    func run() throws {
      let group = DispatchGroup()
      group.enter()

      Task {
        defer { group.leave() }
        do {
          let rootURL = URL(fileURLWithPath: dir).resolvingSymlinksInPath()
          let scanner = FileScanner(
            rootDirectory: rootURL, corruptedDirectoryName: "CORRUPTED", validator: FileValidator())
          let isVerbose = verbose

          print("📂 Scanning directory: \(dir)")

          let result = try await scanner.scanForCorruption(
            progress: makeValidationProgressHandler(verbose: isVerbose))
          let pdfFiles = filterPdfCorrupted(from: result.corruptedFiles)
          let pdfValidations = filterPdfValidations(from: result.okFiles)
          let formatter = PDFReportFormatter()

          await handleValidationMode(
            mode: validationMode(),
            pdfValidations: pdfValidations,
            corruptedFiles: pdfFiles,
            formatter: formatter
          )

          print("✅ PDF Mechanic validation completed successfully")
        } catch {
          print("❌ Error: \(error)")
        }
      }

      group.wait()
    }

    private func validationMode() -> PDFValidationMode {
      if structureCheck {
        return .structure
      }
      if showStreams {
        return .streams
      }
      if encryptionInfo {
        return .encryption
      }
      if let extractMetadata {
        return .extractMetadata(extractMetadata)
      }
      if let extract {
        return .extract(extract)
      }
      return .corrupted
    }

    private func makeValidationProgressHandler(verbose: Bool) -> FileScanner.ProgressHandler {
      { event in
        guard verbose else { return }
        switch event.stage {
        case .scanningFiles:
          print("🔎 Scanning for PDF files...")
        case .validatingFile(let url):
          if isPdfFile(url) {
            print("  Validating: \(url.lastPathComponent)")
          }
        default:
          break
        }
      }
    }

    private func isPdfFile(_ url: URL) -> Bool {
      let ext = url.pathExtension.lowercased()
      return ext == "pdf" || ext == "azw4"
    }

    private func filterPdfValidations(from files: [ValidationResult]) -> [ValidationResult] {
      files.filter { isPdfFile($0.url) }
    }

    private func filterPdfCorrupted(from files: [CorruptedFile]) -> [CorruptedFile] {
      files.filter { isPdfFile($0.url) }
    }

    private func handleValidationMode(
      mode: PDFValidationMode,
      pdfValidations: [ValidationResult],
      corruptedFiles: [CorruptedFile],
      formatter: PDFReportFormatter
    ) async {
      switch mode {
      case .structure:
        await validateStructure(for: pdfValidations, formatter: formatter)
      case .streams:
        await printStreamInfo(for: pdfValidations)
      case .encryption:
        await printEncryptionInfo(for: pdfValidations)
      case .extractMetadata(let format):
        await extractMetadata(for: pdfValidations, format: format)
      case .extract(let option):
        await extractInfo(for: pdfValidations, option: option)
      case .corrupted:
        await printCorruptionResults(for: corruptedFiles, formatter: formatter)
      }
    }

    private func validateStructure(
      for files: [ValidationResult],
      formatter: PDFReportFormatter
    ) async {
      for file in files {
        let validationResult = await ExternalValidators.validatePdf(at: file.url.path)
        await formatter.printValidationResults(for: validationResult)
      }
    }

    private func printStreamInfo(for files: [ValidationResult]) async {
      for file in files {
        let streamInfo = await ExternalValidators.getPdfStreamInfo(at: file.url.path)
        print("\n📊 Stream analysis for \(file.url.lastPathComponent):")
        print(streamInfo)
      }
    }

    private func printEncryptionInfo(for files: [ValidationResult]) async {
      for file in files {
        let encryption = await ExternalValidators.getPdfEncryptionInfo(at: file.url.path)
        print("\n🔒 Encryption details for \(file.url.lastPathComponent):")
        print(encryption)
      }
    }

    private func extractMetadata(for files: [ValidationResult], format: String) async {
      for file in files {
        do {
          try await extractPDFMetadata(at: file.url, format: format)
        } catch {
          print("✗ Failed to extract metadata from \(file.url.lastPathComponent): \(error)")
        }
      }
    }

    private func extractInfo(for files: [ValidationResult], option: String) async {
      for file in files {
        let metadata = await ExternalValidators.getPdfInfo(at: file.url.path)
        let outputData = metadataForExtractOption(option, metadata: metadata)
        let outputURL = file.url.deletingPathExtension().appendingPathExtension("metadata.json")

        do {
          let jsonData = try JSONSerialization.data(
            withJSONObject: outputData, options: [.prettyPrinted])
          try jsonData.write(to: outputURL)
          print("✓ Saved metadata: \(outputURL.lastPathComponent)")
        } catch {
          print("✗ Failed to save metadata: \(error)")
        }
      }
    }

    private func metadataForExtractOption(
      _ option: String,
      metadata: [String: Any]
    ) -> [String: Any] {
      switch option {
      case "info":
        return metadata
      case "pages":
        return ["pageCount": metadata["Pages"] ?? 0]
      case "permissions":
        return ["permissions": metadata["Permissions"] ?? "None"]
      default:
        return metadata
      }
    }

    private func printCorruptionResults(
      for files: [CorruptedFile],
      formatter: PDFReportFormatter
    ) async {
      for file in files {
        let validationResult = ValidationResult(
          originalIndex: 0, url: file.url, size: file.size, isValid: false,
          reason: file.reason, status: file.status, fingerprint: file.fingerprint,
          pdfValidationDetails: file.pdfValidationDetails,
          epubComplianceDetails: file.epubComplianceDetails)
        await formatter.printValidationResults(for: validationResult)
      }
    }

    private func extractPDFMetadata(at url: URL, format: String) async throws {
      let metadata = await ExternalValidators.getPdfInfo(at: url.path)
      let normalized = format.lowercased()

      let outputExtension: String
      switch normalized {
      case "yaml", "yml":
        outputExtension = "yaml"
      default:
        outputExtension = "json"
      }

      let outputURL = url.deletingPathExtension().appendingPathExtension(
        "metadata.\(outputExtension)")

      if outputExtension == "json" {
        let jsonData = try JSONSerialization.data(
          withJSONObject: metadata, options: [.prettyPrinted])
        try jsonData.write(to: outputURL)
      } else {
        let yaml = YAMLSerializer.serialize(metadata)
        try yaml.write(to: outputURL, atomically: true, encoding: .utf8)
      }

      print("✓ Saved metadata: \(outputURL.lastPathComponent)")
    }
  }

  struct Repair: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "repair",
      abstract: "Repair corrupted PDF files."
    )

    @Option(name: .shortAndLong, help: "The directory to scan for PDF files.")
    var dir: String = "."

    @Flag(name: .long, help: "Enable verbose logging.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Don't actually make any changes to the files.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Optimize the PDF for size and performance.")
    var optimize: Bool = false

    func run() throws {
      let group = DispatchGroup()
      group.enter()

      Task {
        defer { group.leave() }
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
          let pdfFiles = filterPdfCorrupted(from: result.corruptedFiles)
          let pdfValidations = filterPdfValidations(from: result.okFiles)

          await optimizeFilesIfNeeded(files: pdfValidations, isDryRun: isDryRun)
          await repairCorruptedFilesIfNeeded(
            scanner: scanner,
            files: pdfFiles,
            isDryRun: isDryRun,
            verbose: isVerbose
          )

          print("✅ PDF Mechanic repair completed successfully")
        } catch {
          print("❌ Error: \(error)")
        }
      }

      group.wait()
    }

    private func makeRepairProgressHandler(verbose: Bool) -> FileScanner.ProgressHandler {
      { event in
        guard verbose else { return }
        switch event.stage {
        case .scanningFiles:
          print("🔎 Scanning for PDF files...")
        case .validatingFile(let url):
          if isPdfFile(url) {
            print("  Validating: \(url.lastPathComponent)")
          }
        case .repairingFiles:
          print("🔧 Repairing PDF files...")
        default:
          break
        }
      }
    }

    private func isPdfFile(_ url: URL) -> Bool {
      let ext = url.pathExtension.lowercased()
      return ext == "pdf" || ext == "azw4"
    }

    private func filterPdfValidations(from files: [ValidationResult]) -> [ValidationResult] {
      files.filter { isPdfFile($0.url) }
    }

    private func filterPdfCorrupted(from files: [CorruptedFile]) -> [CorruptedFile] {
      files.filter { isPdfFile($0.url) }
    }

    private func optimizeFilesIfNeeded(files: [ValidationResult], isDryRun: Bool) async {
      guard optimize else { return }

      for file in files {
        let optimizedURL = file.url.deletingPathExtension().appendingPathExtension("optimized.pdf")
        if isDryRun {
          print(
            "DRY RUN: Would optimize \(file.url.lastPathComponent) → \(optimizedURL.lastPathComponent)"
          )
          continue
        }

        let (success, output) = await ExternalValidators.optimizePDF(
          at: file.url.path, outputPath: optimizedURL.path)
        if success {
          print(
            "✅ Optimized \(file.url.lastPathComponent) → \(optimizedURL.lastPathComponent)")
        } else {
          print("❌ Failed to optimize \(file.url.lastPathComponent): \(output)")
        }
      }
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
  }
}

EbookMechanicPDFCLI.main()

private enum PDFValidationMode {
  case structure
  case streams
  case encryption
  case extractMetadata(String)
  case extract(String)
  case corrupted
}

private enum YAMLSerializer {
  static func serialize(_ value: Any) -> String {
    serialize(value, indent: 0)
  }

  private static func serialize(_ value: Any, indent: Int) -> String {
    let prefix = String(repeating: "  ", count: indent)
    switch value {
    case let dict as [String: Any]:
      if dict.isEmpty { return "{}" }
      return dict.keys.sorted().map { key in
        let entryValue = dict[key] ?? ""
        let rendered = serialize(entryValue, indent: indent + 1)
        if rendered.contains("\n") {
          return "\(prefix)\(key):\n\(rendered)"
        }
        return "\(prefix)\(key): \(rendered)"
      }.joined(separator: "\n")
    case let array as [Any]:
      if array.isEmpty { return "[]" }
      return array.map { item in
        let rendered = serialize(item, indent: indent + 1)
        if rendered.contains("\n") {
          return "\(prefix)-\n\(rendered)"
        }
        return "\(prefix)- \(rendered)"
      }.joined(separator: "\n")
    case let string as String:
      return escape(string)
    case let number as NSNumber:
      return number.stringValue
    case let bool as Bool:
      return bool ? "true" : "false"
    default:
      return escape(String(describing: value))
    }
  }

  private static func escape(_ value: String) -> String {
    if value.isEmpty { return "\"\"" }
    if value.contains(where: { $0.isWhitespace || $0 == ":" || $0 == "-" }) {
      return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
    return value
  }
}
// swiftlint:enable file_length

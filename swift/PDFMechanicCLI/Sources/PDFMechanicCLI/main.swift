import ArgumentParser
import EbookMechanicCore
import Foundation

struct PDFMechanicCLI: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "pdf-mechanic",
    abstract: "A tool to validate and repair PDF files.",
    version: "2.0.0",
    subcommands: [Validate.self, Repair.self],
    defaultSubcommand: Validate.self
  )
}

extension PDFMechanicCLI {
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
        do {
          let rootURL = URL(fileURLWithPath: dir).resolvingSymlinksInPath()
          let scanner = FileScanner(
            rootDirectory: rootURL, corruptedDirectoryName: "CORRUPTED", validator: FileValidator())
          let isVerbose = verbose

          print("📂 Scanning directory: \(dir)")

          let result = try await scanner.scanForCorruption { event in
            if isVerbose {
              switch event.stage {
              case .scanningFiles:
                print("🔎 Scanning for PDF files...")
              case .validatingFile(let url):
                let ext = url.pathExtension.lowercased()
                if ext == "pdf" || ext == "azw4" {
                  print("  Validating: \(url.lastPathComponent)")
                }
              default:
                break
              }
            }
          }

          let pdfFiles = result.corruptedFiles.filter {
            let ext = $0.url.pathExtension.lowercased()
            return ext == "pdf" || ext == "azw4"
          }
          let formatter = PDFReportFormatter()

          if structureCheck {
            for file in result.okFiles.filter({
              let ext = $0.url.pathExtension.lowercased()
              return ext == "pdf" || ext == "azw4"
            }) {
              let validationResult = await ExternalValidators.validatePdf(at: file.url.path)
              await formatter.printValidationResults(for: validationResult)
            }
          } else if showStreams {
            for file in result.okFiles.filter({
              let ext = $0.url.pathExtension.lowercased()
              return ext == "pdf" || ext == "azw4"
            }) {
              let streamInfo = await ExternalValidators.getPdfStreamInfo(at: file.url.path)
              print("\n📊 Stream analysis for \(file.url.lastPathComponent):")
              print(streamInfo)
            }
          } else if encryptionInfo {
            for file in result.okFiles.filter({
              let ext = $0.url.pathExtension.lowercased()
              return ext == "pdf" || ext == "azw4"
            }) {
              let encryption = await ExternalValidators.getPdfEncryptionInfo(at: file.url.path)
              print("\n🔒 Encryption details for \(file.url.lastPathComponent):")
              print(encryption)
            }
          } else if let extractOption = extractMetadata {
            for file in result.okFiles.filter({
              let ext = $0.url.pathExtension.lowercased()
              return ext == "pdf" || ext == "azw4"
            }) {
              do {
                try await extractPDFMetadata(at: file.url, format: extractOption)
              } catch {
                print("✗ Failed to extract metadata from \(file.url.lastPathComponent): \(error)")
              }
            }
          } else if let extractOption = extract {
            for file in result.okFiles.filter({
              let ext = $0.url.pathExtension.lowercased()
              return ext == "pdf" || ext == "azw4"
            }) {
              let metadata = await ExternalValidators.getPdfInfo(at: file.url.path)
              let outputURL = file.url.deletingPathExtension().appendingPathExtension(
                "metadata.json")

              var outputData: [String: Any] = [:]
              switch extractOption {
              case "info":
                outputData = metadata
              case "pages":
                outputData["pageCount"] = metadata["Pages"] ?? 0
              case "permissions":
                outputData["permissions"] = metadata["Permissions"] ?? "None"
              default:
                outputData = metadata
              }

              do {
                let jsonData = try JSONSerialization.data(
                  withJSONObject: outputData, options: [.prettyPrinted])
                try jsonData.write(to: outputURL)
                print("✓ Saved metadata: \(outputURL.lastPathComponent)")
              } catch {
                print("✗ Failed to save metadata: \(error)")
              }
            }
          } else {
            for file in pdfFiles {
              let validationResult = ValidationResult(
                originalIndex: 0, url: file.url, size: file.size, isValid: false,
                reason: file.reason, status: file.status, fingerprint: file.fingerprint,
                pdfValidationDetails: file.pdfValidationDetails,
                epubComplianceDetails: file.epubComplianceDetails)
              await formatter.printValidationResults(for: validationResult)
            }
          }

          print("✅ PDF Mechanic validation completed successfully")
        } catch {
          print("❌ Error: \(error)")
        }
        group.leave()
      }

      group.wait()
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
        do {
          let rootURL = URL(fileURLWithPath: dir).resolvingSymlinksInPath()
          let scanner = FileScanner(
            rootDirectory: rootURL, corruptedDirectoryName: "CORRUPTED", validator: FileValidator())
          let isVerbose = verbose
          let isDryRun = dryRun

          print("📂 Scanning directory: \(dir)")
          print("🔧 Repair mode: enabled")
          print("🔍 Dry run: \(isDryRun ? "yes" : "no")")

          let result = try await scanner.scanForCorruption { event in
            if isVerbose {
              switch event.stage {
              case .scanningFiles:
                print("🔎 Scanning for PDF files...")
              case .validatingFile(let url):
                let ext = url.pathExtension.lowercased()
                if ext == "pdf" || ext == "azw4" {
                  print("  Validating: \(url.lastPathComponent)")
                }
              case .repairingFiles:
                print("🔧 Repairing PDF files...")
              default:
                break
              }
            }
          }

          let pdfFiles = result.corruptedFiles.filter {
            let ext = $0.url.pathExtension.lowercased()
            return ext == "pdf" || ext == "azw4"
          }

          if optimize {
            for file in result.okFiles.filter({
              let ext = $0.url.pathExtension.lowercased()
              return ext == "pdf" || ext == "azw4"
            }) {
              if !isDryRun {
                let optimizedURL = file.url.deletingPathExtension().appendingPathExtension(
                  "optimized.pdf")
                let (success, output) = await ExternalValidators.optimizePDF(
                  at: file.url.path, outputPath: optimizedURL.path)
                if success {
                  print(
                    "✅ Optimized \(file.url.lastPathComponent) → \(optimizedURL.lastPathComponent)")
                } else {
                  print("❌ Failed to optimize \(file.url.lastPathComponent): \(output)")
                }
              } else {
                let optimizedURL = file.url.deletingPathExtension().appendingPathExtension(
                  "optimized.pdf")
                print(
                  "DRY RUN: Would optimize \(file.url.lastPathComponent) → \(optimizedURL.lastPathComponent)"
                )
              }
            }
          }

          if !isDryRun && !pdfFiles.isEmpty {
            let (_, repairedCount) = await scanner.repairCorruptedFiles { event in
              if isVerbose {
                switch event.stage {
                case .repairingFiles:
                  print("  🔧 Repairing: \(event.currentItem)")
                default:
                  break
                }
              }
            }
            print("📈 Repair Summary: \(repairedCount) files repaired.")
          }

          print("✅ PDF Mechanic repair completed successfully")
        } catch {
          print("❌ Error: \(error)")
        }
        group.leave()
      }

      group.wait()
    }
  }
}

PDFMechanicCLI.main()

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

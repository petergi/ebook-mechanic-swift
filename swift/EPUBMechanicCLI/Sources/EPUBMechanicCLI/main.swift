import Foundation
import ArgumentParser
import EbookMechanicCore

struct EPUBMechanicCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "epub-mechanic",
        abstract: "A tool to validate and repair EPUB files.",
        version: "2.0.0",
        subcommands: [Validate.self, Repair.self],
        defaultSubcommand: Validate.self
    )
}

extension EPUBMechanicCLI {
    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "validate",
            abstract: "Validate EPUB files in a directory."
        )

        @Option(name: .shortAndLong, help: "The directory to scan for EPUB files.")
        var dir: String = "."

        @Flag(name: .long, help: "Enable verbose logging.")
        var verbose: Bool = false

        @Flag(name: .long, help: "Perform a detailed EPUB specification compliance check using epubcheck.")
        var specCheck: Bool = false

        func run() throws {
            let group = DispatchGroup()
            group.enter()
            
            Task {
                do {
                    let rootURL = URL(fileURLWithPath: dir).resolvingSymlinksInPath()
                    let scanner = FileScanner(rootDirectory: rootURL, corruptedDirectoryName: "CORRUPTED", validator: FileValidator())
                    let isVerbose = verbose
                    
                    print("📂 Scanning directory: \(dir)")
                    
                    let result = try await scanner.scanForCorruption { event in
                        if isVerbose {
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
                    
                    let epubFiles = result.corruptedFiles.filter { $0.url.pathExtension.lowercased() == "epub" }
                    let formatter = EPUBReportFormatter()
                    
                    if specCheck {
                        for file in result.okFiles.filter({ $0.url.pathExtension.lowercased() == "epub" }) {
                            let validationResult = await ExternalValidators.validateEpub(at: file.url.path)
                            formatter.printValidationResults(for: validationResult)
                        }
                    } else {
                         for file in epubFiles {
                             let validationResult = ValidationResult(originalIndex: 0, url: file.url, size: file.size, isValid: false, reason: file.reason, status: file.status, fingerprint: file.fingerprint, pdfValidationDetails: file.pdfValidationDetails, epubComplianceDetails: file.epubComplianceDetails)
                             formatter.printValidationResults(for: validationResult)
                         }
                    }
                    
                    print("✅ EPUB Mechanic validation completed successfully")
                } catch {
                    print("❌ Error: \(error)")
                }
                group.leave()
            }
            
            group.wait()
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
                    let scanner = FileScanner(rootDirectory: rootURL, corruptedDirectoryName: "CORRUPTED", validator: FileValidator())
                    let isVerbose = verbose
                    let isDryRun = dryRun
                    
                    print("📂 Scanning directory: \(dir)")
                    print("🔧 Repair mode: enabled")
                    print("🔍 Dry run: \(isDryRun ? "yes" : "no")")
                    
                    let result = try await scanner.scanForCorruption { event in
                        if isVerbose {
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
                    
                    let epubFiles = result.corruptedFiles.filter { $0.url.pathExtension.lowercased() == "epub" }
                    
                    if !isDryRun && !epubFiles.isEmpty {
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
                    
                    print("✅ EPUB Mechanic repair completed successfully")
                } catch {
                    print("❌ Error: \(error)")
                }
                group.leave()
            }
            
            group.wait()
        }
    }
}

EPUBMechanicCLI.main()

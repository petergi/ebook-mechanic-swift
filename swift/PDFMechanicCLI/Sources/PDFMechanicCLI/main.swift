import Foundation
import ArgumentParser
import EbookMechanicCore

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
        
        @Option(name: .long, help: "Extract metadata from the PDF.", completion: .list(["info", "pages", "permissions"]))
        var extract: String?


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
                        for file in result.okFiles.filter({ let ext = $0.url.pathExtension.lowercased(); return ext == "pdf" || ext == "azw4" }) {
                            let validationResult = await ExternalValidators.validatePdf(at: file.url.path)
                            formatter.printValidationResults(for: validationResult)
                        }
                    } else if let extractOption = extract {
                        // Implement extraction logic here
                        print("Extracting \(extractOption)...")
                    } else {
                        for file in pdfFiles {
                            let validationResult = ValidationResult(originalIndex: 0, url: file.url, size: file.size, isValid: false, reason: file.reason, status: file.status, fingerprint: file.fingerprint, pdfValidationDetails: file.pdfValidationDetails, epubComplianceDetails: file.epubComplianceDetails)
                            formatter.printValidationResults(for: validationResult)
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
                        for file in result.okFiles.filter({ let ext = $0.url.pathExtension.lowercased(); return ext == "pdf" || ext == "azw4" }) {
                            if !isDryRun {
                                let (success, output) = await ExternalValidators.optimizePDF(at: file.url.path)
                                if success {
                                    print("✅ Optimized \(file.url.lastPathComponent)")
                                } else {
                                    print("❌ Failed to optimize \(file.url.lastPathComponent): \(output)")
                                }
                            } else {
                                print("DRY RUN: Would optimize \(file.url.lastPathComponent)")
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

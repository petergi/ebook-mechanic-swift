import Foundation
import EbookMechanicCore

@main
struct PDFMechanicCLI {
    static func main() async {
        print("📄 PDF Mechanic - PDF Validation and Repair Tool")
        print("Version 1.0.0")
        print()

        // Parse command line arguments
        let args = CommandLine.arguments

        // Show help if no arguments or --help
        if args.count < 2 || args.contains("--help") || args.contains("-h") {
            printHelp()
            return
        }

        // Basic configuration
        var directory = "."
        var repair = false
        var dryRun = false
        var verbose = false

        // Parse arguments
        var i = 1
        while i < args.count {
            switch args[i] {
            case "-d", "--dir":
                if i + 1 < args.count {
                    directory = args[i + 1]
                    i += 1
                }
            case "-r", "--repair":
                repair = true
            case "--dry-run":
                dryRun = true
            case "-v", "--verbose":
                verbose = true
            default:
                break
            }
            i += 1
        }

        do {
            let rootURL = URL(fileURLWithPath: directory).resolvingSymlinksInPath()
            let scanner = FileScanner(rootDirectory: rootURL, corruptedDirectoryName: "CORRUPTED")

            // Capture configuration as constants for Sendable closures
            let isVerbose = verbose
            let shouldRepair = repair
            let isDryRun = dryRun

            print("📂 Scanning directory: \(directory)")
            print("🔧 Repair mode: \(shouldRepair ? "enabled" : "disabled")")
            print("🔍 Dry run: \(isDryRun ? "yes" : "no")")
            print()

            // Scan for PDF files only
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

            // Filter for PDF and AZW4 files only
            let pdfFiles = result.corruptedFiles.filter {
                let ext = $0.url.pathExtension.lowercased()
                return ext == "pdf" || ext == "azw4"
            }

            print("📊 PDF Scan Results")
            print("───────────────────────────────")
            print("Total PDF files scanned: \(result.totalFiles)")
            print("Corrupted PDF files: \(pdfFiles.count)")
            print()

            if !pdfFiles.isEmpty {
                print("📋 Corrupted PDF files:")
                for file in pdfFiles {
                    print("  • \(file.url.lastPathComponent): \(file.reason)")
                }
                print()
            }

            if shouldRepair && !pdfFiles.isEmpty && !isDryRun {
                print("🔧 Attempting repairs...")
                let (repairs, repairedCount) = await scanner.repairCorruptedFiles { event in
                    if isVerbose {
                        switch event.stage {
                        case .repairingFiles:
                            print("  🔧 Repairing: \(event.currentItem)")
                        default:
                            break
                        }
                    }
                }

                print()
                print("📈 Repair Summary")
                print("───────────────────────────────")
                print("Successfully repaired: \(repairedCount)")
                print("Failed repairs: \(repairs.count - repairedCount)")
            }

            print()
            print("✅ PDF Mechanic completed successfully")

        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }

    static func printHelp() {
        print("""
        USAGE: pdf-mechanic [OPTIONS]

        OPTIONS:
          -d, --dir <path>     Directory to scan (default: current directory)
          -r, --repair         Attempt to repair corrupted PDF files
          --dry-run            Scan only, don't make changes
          -v, --verbose        Show detailed progress
          -h, --help           Show this help message

        EXAMPLES:
          pdf-mechanic -d ~/Documents
          pdf-mechanic -d ~/Documents --repair
          pdf-mechanic -d ~/Documents --repair --dry-run

        PDF VALIDATION:
          - Checks for valid PDF header (%PDF-)
          - Verifies EOF marker (%%EOF) in last 1KB
          - Detects header corruption (junk prefixes, UTF-8 BOM, email wrappers)
          - Validates PDF version format (1.0-2.0)

        PDF REPAIR:
          - Advanced header corruption repair (searches first 8KB)
          - Strips corrupted prefix bytes
          - Adds missing binary markers
          - Appends missing EOF markers
          - Preserves original with .backup extension

        SUPPORTED FORMATS:
          - PDF (.pdf)
          - AZW4 (.azw4) - Kindle PDF wrapper format
        """)
    }
}

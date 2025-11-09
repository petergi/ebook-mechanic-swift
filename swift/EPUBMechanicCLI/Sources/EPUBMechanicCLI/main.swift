import Foundation
import EbookMechanicCore

@main
struct EPUBMechanicCLI {
    static func main() async {
        print("📚 EPUB Mechanic - EPUB Validation and Repair Tool")
        print("Version 1.0.0")
        print()

        // Parse command line arguments
        let args = CommandLine.arguments

        // Show help if no arguments or --help
        if args.count < 2 || args.contains("--help") || args.contains("-h") {
            printHelp()
            return
        }

        // Basic configuration (mutable during parsing)
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

            // Scan for EPUB files only
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

            // Filter for EPUB files only
            let epubFiles = result.corruptedFiles.filter { $0.url.pathExtension.lowercased() == "epub" }

            print("📊 EPUB Scan Results")
            print("───────────────────────────────")
            print("Total EPUB files scanned: \(result.totalFiles)")
            print("Corrupted EPUB files: \(epubFiles.count)")
            print()

            if !epubFiles.isEmpty {
                print("📋 Corrupted EPUB files:")
                for file in epubFiles {
                    print("  • \(file.url.lastPathComponent): \(file.reason)")
                }
                print()
            }

            if shouldRepair && !epubFiles.isEmpty && !isDryRun {
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
            print("✅ EPUB Mechanic completed successfully")

        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }

    static func printHelp() {
        print("""
        USAGE: epub-mechanic [OPTIONS]

        OPTIONS:
          -d, --dir <path>     Directory to scan (default: current directory)
          -r, --repair         Attempt to repair corrupted EPUB files
          --dry-run            Scan only, don't make changes
          -v, --verbose        Show detailed progress
          -h, --help           Show this help message

        EXAMPLES:
          epub-mechanic -d ~/Books
          epub-mechanic -d ~/Books --repair
          epub-mechanic -d ~/Books --repair --dry-run

        EPUB VALIDATION:
          - Validates ZIP structure
          - Checks for required mimetype file
          - Verifies META-INF/container.xml exists

        EPUB REPAIR:
          - Adds missing mimetype file
          - Creates missing META-INF/container.xml
          - Preserves original with .backup extension
        """)
    }
}

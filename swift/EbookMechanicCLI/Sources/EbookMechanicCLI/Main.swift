import Foundation
import EbookMechanicCore

@main
struct EbookMechanicCLI {
    static func main() async {
        do {
            let configuration = try CLIConfiguration.parse()
            let rootURL = URL(fileURLWithPath: configuration.directory).resolvingSymlinksInPath()
            let scanner = FileScanner(
                rootDirectory: rootURL,
                corruptedDirectoryName: configuration.corruptedDirectory
            )

            let printer = ProgressPrinter(verbose: configuration.verbose)

            if configuration.emptyFoldersOnly {
                let folders = try await scanner.scanForEmptyFolders(progress: printer.handle)
                printer.printHeader("Empty Folder Analysis")
                reportEmptyFolders(folders, printer: printer)
                try await handleEmptyFolderCleanup(configuration: configuration, scanner: scanner, result: folders, printer: printer)
                if configuration.generateReport {
                    try await generateReport(using: scanner, configuration: configuration, printer: printer)
                }
                return
            }

            let scanResult = try await scanner.scanForCorruption(progress: printer.handle)
            printer.printHeader("Corruption Scan Summary")
            printer.printScanResult(scanResult)

            if configuration.repair, !scanResult.corruptedFiles.isEmpty {
                printer.printHeader("Repairing Corrupted Files")
                let (repairs, repairedCount) = await scanner.repairCorruptedFiles(progress: printer.handle)
                printer.printRepairSummary(results: repairs, repairedCount: repairedCount)
            }

            if !configuration.corruptionOnly {
                let folders = try await scanner.scanForEmptyFolders(progress: printer.handle)
                printer.printHeader("Folder Analysis")
                reportEmptyFolders(folders, printer: printer)
                try await handleEmptyFolderCleanup(configuration: configuration, scanner: scanner, result: folders, printer: printer)
            }

            if !configuration.dryRun {
                try await handleCorruptedMoves(configuration: configuration, scanner: scanner, printer: printer)
            } else {
                printer.printInfo("Dry run enabled – no files were moved or deleted.")
            }

            if configuration.generateReport {
                try await generateReport(using: scanner, configuration: configuration, printer: printer)
            }

            printer.printFooter("EbookMechanic completed successfully")
        } catch let error as CLIError {
            switch error {
            case .userRequestedHelp:
                CLIConfiguration.printHelp()
            case .userRequestedVersion:
                print("EbookMechanicCLI 1.0.0")
            case .invalidArgument(let message):
                fputs("Error: \(message)\n", stderr)
                exit(EXIT_FAILURE)
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func handleCorruptedMoves(configuration: CLIConfiguration, scanner: FileScanner, printer: ProgressPrinter) async throws {
        let result = await scanner.lastResult
        guard !result.corruptedFiles.isEmpty else {
            printer.printInfo("No corrupted files detected – nothing to move.")
            return
        }

        if configuration.autoConfirm || promptYesNo("Move corrupted files to \(configuration.corruptedDirectory)?") {
            try await scanner.moveCorruptedFiles(progress: printer.handle)
            printer.printSuccess("Corrupted files moved to \(configuration.corruptedDirectory).")
        } else {
            printer.printInfo("Skipping move step at user request.")
        }
    }

    private static func handleEmptyFolderCleanup(configuration: CLIConfiguration, scanner: FileScanner, result: ScanResult, printer: ProgressPrinter) async throws {
        guard !configuration.dryRun, !result.emptyFolders.isEmpty else { return }

        if configuration.autoConfirm || promptYesNo("Delete \(result.emptyFolders.count) empty folder(s)?") {
            try await scanner.deleteEmptyFolders(progress: printer.handle)
            printer.printSuccess("Removed \(result.emptyFolders.count) empty folder(s).")
        } else {
            printer.printInfo("Empty folders left untouched.")
        }
    }

    private static func generateReport(using scanner: FileScanner, configuration: CLIConfiguration, printer: ProgressPrinter) async throws {
        let reportURL = try await scanner.generateReport(into: URL(fileURLWithPath: configuration.directory))
        printer.printSuccess("Report generated at \(reportURL.path)")
    }

    private static func reportEmptyFolders(_ result: ScanResult, printer: ProgressPrinter) {
        printer.printInfo("Total folders scanned: \(result.totalFolders)")
        printer.printInfo("Folders with ebooks: \(result.foldersWithEbooks)")
        printer.printInfo("Empty folders: \(result.emptyFolders.count)")
        if !result.emptyFolders.isEmpty {
            printer.printInfo("Empty folders:")
            for folder in result.emptyFolders.prefix(10) {
                printer.printBullet(folder.path)
            }
            if result.emptyFolders.count > 10 {
                printer.printInfo("… and \(result.emptyFolders.count - 10) more")
            }
        }
    }

    @discardableResult
    private static func promptYesNo(_ message: String) -> Bool {
        print("\n\(message) [y/N] ", terminator: "")
        guard let response = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return ["y", "yes"].contains(response.lowercased())
    }
}

// MARK: - CLI Configuration

enum CLIError: Error {
    case invalidArgument(String)
    case userRequestedHelp
    case userRequestedVersion
}

struct CLIConfiguration {
    var directory: String = FileManager.default.currentDirectoryPath
    var corruptedDirectory: String = "CORRUPTED"
    var corruptionOnly: Bool = false
    var emptyFoldersOnly: Bool = false
    var repair: Bool = false
    var dryRun: Bool = false
    var autoConfirm: Bool = false
    var verbose: Bool = true
    var generateReport: Bool = false

    static func parse(arguments: [String] = CommandLine.arguments) throws -> CLIConfiguration {
        var config = CLIConfiguration()
        var iterator = arguments.dropFirst().makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "-h", "--help":
                throw CLIError.userRequestedHelp
            case "-V", "--version":
                throw CLIError.userRequestedVersion
            case "-d", "--dir":
                guard let value = iterator.next() else { throw CLIError.invalidArgument("Missing value for \(argument)") }
                config.directory = value
            case "-c", "--corrupted-dir":
                guard let value = iterator.next() else { throw CLIError.invalidArgument("Missing value for \(argument)") }
                config.corruptedDirectory = value
            case "--corruption-only":
                config.corruptionOnly = true
            case "--empty-folders-only":
                config.emptyFoldersOnly = true
            case "-r", "--repair":
                config.repair = true
            case "--dry-run":
                config.dryRun = true
            case "--no-confirm":
                config.autoConfirm = true
            case "--quiet":
                config.verbose = false
            case "--report":
                config.generateReport = true
            default:
                throw CLIError.invalidArgument("Unknown argument: \(argument)")
            }
        }

        if config.emptyFoldersOnly {
            config.corruptionOnly = false
        }

        return config
    }

    static func printHelp() {
        print(
            """
            📚 EbookMechanic CLI

            Usage: ebook-mechanic [options]

            Options:
              -h, --help              Show this help message
              -V, --version           Print version and exit
              -d, --dir <path>        Directory to scan (default: current directory)
              -c, --corrupted-dir     Destination for corrupted files (default: CORRUPTED)
              --corruption-only       Skip empty folder analysis
              --empty-folders-only    Only analyze empty folders
              -r, --repair            Attempt to repair corrupted files
              --dry-run               Perform analysis without modifying the filesystem
              --no-confirm            Skip confirmation prompts and proceed automatically
              --quiet                 Reduce console output
              --report                Generate a Markdown report in the scan directory
            """
        )
    }
}

// MARK: - Progress Printing

struct ProgressPrinter {
    let verbose: Bool

    init(verbose: Bool) {
        self.verbose = verbose
    }

    func handle(_ event: ProgressEvent) {
        guard verbose else { return }
        switch event.stage {
        case .validatingFile(let url):
            print("🔍 Inspecting \(url.lastPathComponent)...")
        case .scanningFiles:
            print("   Progress: \(event.completed)/\(event.total)")
        case .scanningFolders:
            print("📂 Checking folders (\(event.completed)/\(event.total))")
        case .movingCorruptedFiles:
            print("📦 Moving (\(event.completed)/\(event.total)): \(event.currentItem)")
        case .deletingEmptyFolders:
            print("🧹 Deleting folder: \(event.currentItem)")
        case .repairingFiles:
            print("🛠️ Repairing (\(event.completed)/\(event.total)): \(event.currentItem)")
        }
    }

    func printHeader(_ title: String) {
        print("\n=== \(title) ===")
    }

    func printFooter(_ message: String) {
        print("\n✅ \(message)\n")
    }

    func printInfo(_ message: String) {
        print("• \(message)")
    }

    func printSuccess(_ message: String) {
        print("✅ \(message)")
    }

    func printBullet(_ message: String) {
        print("  - \(message)")
    }

    func printScanResult(_ result: ScanResult) {
        print("• Files scanned: \(result.totalFiles)")
        print("• Corrupted files: \(result.corruptedFiles.count)")
        for type in EbookFileType.allCases {
            let breakdown = result.breakdown(for: type)
            let status = breakdown.corrupted > 0 ? "❌" : "✅"
            let label = type.fileExtension.dropFirst().uppercased()
            print("  \(status) \(label): \(breakdown.corrupted)/\(breakdown.total) corrupted")
        }
        if !result.corruptedFiles.isEmpty {
            print("\nCorrupted files:")
            for file in result.corruptedFiles.prefix(10) {
                print("  - \(file.url.path) [\(file.reason)]")
            }
            if result.corruptedFiles.count > 10 {
                print("  … and \(result.corruptedFiles.count - 10) more")
            }
        }
    }

    func printRepairSummary(results: [RepairResult], repairedCount: Int) {
        guard !results.isEmpty else {
            printInfo("No corrupted files required repair.")
            return
        }
        printInfo("Repair attempts: \(results.count) – fixed: \(repairedCount)")
        for (index, result) in results.enumerated() where verbose {
            let icon = result.fixed ? "✅" : (result.success ? "ℹ️" : "❌")
            print("  \(icon) [\(index + 1)] \(result.message)")
        }
    }
}

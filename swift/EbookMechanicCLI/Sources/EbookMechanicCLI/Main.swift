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

            if configuration.normalizeEPUBs {
                printer.printHeader("Normalizing EPUBs")
                let (normalized, skipped) = await scanner.normalizeEPUBs(force: configuration.forceNormalize, dryRun: configuration.dryRun, progress: printer.handle)
                printer.printInfo("EPUB normalization: normalized=\(normalized), skipped=\(skipped)")
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
            case .userRequestedCompletion(let shell):
                ShellCompletion.generate(for: shell)
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
    case userRequestedCompletion(ShellType)
}

enum ShellType: String, CaseIterable {
    case bash
    case zsh
    case fish
    case powershell
    
    var displayName: String {
        switch self {
        case .bash: return "bash"
        case .zsh: return "zsh"
        case .fish: return "fish"
        case .powershell: return "PowerShell"
        }
    }
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
    var normalizeEPUBs: Bool = false
    var forceNormalize: Bool = false

    static func parse(arguments: [String] = CommandLine.arguments) throws -> CLIConfiguration {
        var config = CLIConfiguration()
        var iterator = arguments.dropFirst().makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "-h", "--help":
                throw CLIError.userRequestedHelp
            case "-V", "--version":
                throw CLIError.userRequestedVersion
            case "--generate-completion":
                guard let shellName = iterator.next()?.lowercased() else {
                    throw CLIError.invalidArgument("Missing shell type. Available: bash, zsh, fish, powershell")
                }
                guard let shell = ShellType(rawValue: shellName) else {
                    throw CLIError.invalidArgument("Unknown shell '\(shellName)'. Available: bash, zsh, fish, powershell")
                }
                throw CLIError.userRequestedCompletion(shell)
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
            case "--normalize-epubs":
                config.normalizeEPUBs = true
            case "--force-normalize":
                config.forceNormalize = true
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
              -h, --help                      Show this help message
              -V, --version                   Print version and exit
              --generate-completion <shell>   Generate shell completion script (bash, zsh, fish, powershell)
              -d, --dir <path>                Directory to scan (default: current directory)
              -c, --corrupted-dir             Destination for corrupted files (default: CORRUPTED)
              --corruption-only               Skip empty folder analysis
              --empty-folders-only            Only analyze empty folders
              -r, --repair                    Attempt to repair corrupted files
              --dry-run                       Perform analysis without modifying the filesystem
              --no-confirm                    Skip confirmation prompts and proceed automatically
              --quiet                         Reduce console output
              --report                        Generate a Markdown report in the scan directory
              --normalize-epubs               Normalize EPUB files into canonical form
              --force-normalize               Force normalization even if already normalized
            
            Shell Completion:
              To enable shell completion, run the appropriate command:
              
              Bash:
                ebook-mechanic --generate-completion bash > /usr/local/etc/bash_completion.d/ebook-mechanic
              
              Zsh:
                ebook-mechanic --generate-completion zsh > /usr/local/share/zsh/site-functions/_ebook-mechanic
              
              Fish:
                ebook-mechanic --generate-completion fish > ~/.config/fish/completions/ebook-mechanic.fish
              
              PowerShell:
                ebook-mechanic --generate-completion powershell > ebook-mechanic.ps1
            """
        )
    }
}

// MARK: - Progress Printing

struct ProgressPrinter: @unchecked Sendable {
    let verbose: Bool
    private let sink: @Sendable (String) -> Void

    init(verbose: Bool, sink: (@Sendable (String) -> Void)? = nil) {
        self.verbose = verbose
        self.sink = sink ?? ProgressPrinter.defaultSink
    }

    @Sendable
    func handle(_ event: ProgressEvent) {
        guard verbose else { return }
        switch event.stage {
        case .validatingFile(let url):
            emit("🔍 Inspecting \(url.lastPathComponent)...")
        case .scanningFiles:
            emit("   Progress: \(event.completed)/\(event.total)")
        case .scanningFolders:
            emit("📂 Checking folders (\(event.completed)/\(event.total))")
        case .movingCorruptedFiles:
            emit("📦 Moving (\(event.completed)/\(event.total)): \(event.currentItem)")
        case .deletingEmptyFolders:
            emit("🧹 Deleting folder: \(event.currentItem)")
        case .repairingFiles:
            emit("🛠️ Repairing (\(event.completed)/\(event.total)): \(event.currentItem)")
        case .normalizingFiles:
            emit("✨ Normalizing (\(event.completed)/\(event.total)) \(event.currentItem)")
        }
    }

    func printHeader(_ title: String) {
        emit("\n=== \(title) ===")
    }

    func printFooter(_ message: String) {
        emit("\n✅ \(message)\n")
    }

    func printInfo(_ message: String) {
        emit("• \(message)")
    }

    func printSuccess(_ message: String) {
        emit("✅ \(message)")
    }

    func printBullet(_ message: String) {
        emit("  - \(message)")
    }

    func printScanResult(_ result: ScanResult) {
        emit("• Files scanned: \(result.totalFiles)")
        emit("• Corrupted files: \(result.corruptedFiles.count)")
        for type in EbookFileType.allCases {
            let breakdown = result.breakdown(for: type)
            let status = breakdown.corrupted > 0 ? "❌" : "✅"
            let label = type.fileExtension.dropFirst().uppercased()
            emit("  \(status) \(label): \(breakdown.corrupted)/\(breakdown.total) corrupted")
        }
        if !result.corruptedFiles.isEmpty {
            emit("\nCorrupted files:")
            for file in result.corruptedFiles.prefix(10) {
                emit("  - \(file.url.path) [\(file.reason)]")
            }
            if result.corruptedFiles.count > 10 {
                emit("  … and \(result.corruptedFiles.count - 10) more")
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
            emit("  \(icon) [\(index + 1)] \(result.message)")
        }
    }

    private func emit(_ text: String) {
        sink(text)
    }

    private static func defaultSink(_ text: String) {
        print(text)
    }
}

// MARK: - Shell Completion

struct ShellCompletion {
    static func generate(for shell: ShellType) {
        switch shell {
        case .bash:
            print(bashCompletion)
        case .zsh:
            print(zshCompletion)
        case .fish:
            print(fishCompletion)
        case .powershell:
            print(powershellCompletion)
        }
    }
    
    private static let bashCompletion = """
        # bash completion for ebook-mechanic
        
        _ebook_mechanic_completions() {
            local cur prev opts
            COMPREPLY=()
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"
            
            opts="-h --help -V --version --generate-completion -d --dir -c --corrupted-dir --corruption-only --empty-folders-only -r --repair --dry-run --no-confirm --quiet --report --normalize-epubs --force-normalize"
            
            case "${prev}" in
                -d|--dir|-c|--corrupted-dir)
                    # Complete directory paths
                    COMPREPLY=( $(compgen -d -- "${cur}") )
                    return 0
                    ;;
                --generate-completion)
                    # Complete shell types
                    COMPREPLY=( $(compgen -W "bash zsh fish powershell" -- "${cur}") )
                    return 0
                    ;;
                *)
                    ;;
            esac
            
            if [[ ${cur} == -* ]] ; then
                COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
                return 0
            fi
            
            # Default to directory completion
            COMPREPLY=( $(compgen -d -- "${cur}") )
        }
        
        complete -F _ebook_mechanic_completions ebook-mechanic
        """
    
    private static let zshCompletion = """
        #compdef ebook-mechanic
        
        _ebook_mechanic() {
            local -a options
            options=(
                '(- :)'{-h,--help}'[Show help message]'
                '(- :)'{-V,--version}'[Print version and exit]'
                '(- :)--generate-completion[Generate shell completion script]:shell:(bash zsh fish powershell)'
                '(-d --dir)'{-d,--dir}'[Directory to scan]:directory:_directories'
                '(-c --corrupted-dir)'{-c,--corrupted-dir}'[Destination for corrupted files]:directory:_directories'
                '--corruption-only[Skip empty folder analysis]'
                '--empty-folders-only[Only analyze empty folders]'
                '(-r --repair)'{-r,--repair}'[Attempt to repair corrupted files]'
                '--dry-run[Perform analysis without modifying the filesystem]'
                '--no-confirm[Skip confirmation prompts]'
                '--quiet[Reduce console output]'
                '--report[Generate a Markdown report]'
                '--normalize-epubs[Normalize EPUB files]'
                '--force-normalize[Force normalization even if already normalized]'
            )
            
            _arguments -s -S $options
        }
        
        _ebook_mechanic "$@"
        """
    
    private static let fishCompletion = """
        # fish completion for ebook-mechanic
        
        # Help and version
        complete -c ebook-mechanic -s h -l help -d 'Show help message'
        complete -c ebook-mechanic -s V -l version -d 'Print version and exit'
        
        # Shell completion generation
        complete -c ebook-mechanic -l generate-completion -d 'Generate shell completion script' -xa 'bash zsh fish powershell'
        
        # Directory options
        complete -c ebook-mechanic -s d -l dir -d 'Directory to scan' -r -F
        complete -c ebook-mechanic -s c -l corrupted-dir -d 'Destination for corrupted files' -r -F
        
        # Scanning modes
        complete -c ebook-mechanic -l corruption-only -d 'Skip empty folder analysis'
        complete -c ebook-mechanic -l empty-folders-only -d 'Only analyze empty folders'
        
        # Actions
        complete -c ebook-mechanic -s r -l repair -d 'Attempt to repair corrupted files'
        complete -c ebook-mechanic -l dry-run -d 'Perform analysis without modifying filesystem'
        complete -c ebook-mechanic -l no-confirm -d 'Skip confirmation prompts'
        complete -c ebook-mechanic -l quiet -d 'Reduce console output'
        complete -c ebook-mechanic -l report -d 'Generate a Markdown report'
        
        # EPUB normalization
        complete -c ebook-mechanic -l normalize-epubs -d 'Normalize EPUB files'
        complete -c ebook-mechanic -l force-normalize -d 'Force normalization even if already normalized'
        """
    
    private static let powershellCompletion = """
        # PowerShell completion for ebook-mechanic
        
        Register-ArgumentCompleter -Native -CommandName ebook-mechanic -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            
            $commands = @(
                @{ Name = '-h'; Description = 'Show help message' }
                @{ Name = '--help'; Description = 'Show help message' }
                @{ Name = '-V'; Description = 'Print version and exit' }
                @{ Name = '--version'; Description = 'Print version and exit' }
                @{ Name = '--generate-completion'; Description = 'Generate shell completion script' }
                @{ Name = '-d'; Description = 'Directory to scan' }
                @{ Name = '--dir'; Description = 'Directory to scan' }
                @{ Name = '-c'; Description = 'Destination for corrupted files' }
                @{ Name = '--corrupted-dir'; Description = 'Destination for corrupted files' }
                @{ Name = '--corruption-only'; Description = 'Skip empty folder analysis' }
                @{ Name = '--empty-folders-only'; Description = 'Only analyze empty folders' }
                @{ Name = '-r'; Description = 'Attempt to repair corrupted files' }
                @{ Name = '--repair'; Description = 'Attempt to repair corrupted files' }
                @{ Name = '--dry-run'; Description = 'Perform analysis without modifying filesystem' }
                @{ Name = '--no-confirm'; Description = 'Skip confirmation prompts' }
                @{ Name = '--quiet'; Description = 'Reduce console output' }
                @{ Name = '--report'; Description = 'Generate a Markdown report' }
                @{ Name = '--normalize-epubs'; Description = 'Normalize EPUB files' }
                @{ Name = '--force-normalize'; Description = 'Force normalization even if already normalized' }
            )
            
            # Get previous token to provide context-aware completion
            $tokens = $commandAst.ToString() -split '\\s+'
            $previousToken = if ($tokens.Count -gt 1) { $tokens[-2] } else { '' }
            
            # Context-aware completions
            if ($previousToken -eq '--generate-completion') {
                @('bash', 'zsh', 'fish', 'powershell') | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            }
            elseif ($previousToken -in @('-d', '--dir', '-c', '--corrupted-dir')) {
                # Directory completion (handled by PowerShell's native file completion)
                return
            }
            else {
                # Complete command options
                $commands | Where-Object { $_.Name -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterName', $_.Description)
                }
            }
        }
        """
}

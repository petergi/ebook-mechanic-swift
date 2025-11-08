import XCTest
@testable import EbookMechanicCLI

final class ShellCompletionTests: XCTestCase {

    // MARK: - ShellType Tests

    func testShellTypeRawValues() {
        XCTAssertEqual(ShellType.bash.rawValue, "bash")
        XCTAssertEqual(ShellType.zsh.rawValue, "zsh")
        XCTAssertEqual(ShellType.fish.rawValue, "fish")
        XCTAssertEqual(ShellType.powershell.rawValue, "powershell")
    }

    func testShellTypeDisplayNames() {
        XCTAssertEqual(ShellType.bash.displayName, "bash")
        XCTAssertEqual(ShellType.zsh.displayName, "zsh")
        XCTAssertEqual(ShellType.fish.displayName, "fish")
        XCTAssertEqual(ShellType.powershell.displayName, "PowerShell")
    }

    func testShellTypeAllCases() {
        let allCases = ShellType.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.bash))
        XCTAssertTrue(allCases.contains(.zsh))
        XCTAssertTrue(allCases.contains(.fish))
        XCTAssertTrue(allCases.contains(.powershell))
    }

    func testShellTypeInitFromString() {
        XCTAssertEqual(ShellType(rawValue: "bash"), .bash)
        XCTAssertEqual(ShellType(rawValue: "zsh"), .zsh)
        XCTAssertEqual(ShellType(rawValue: "fish"), .fish)
        XCTAssertEqual(ShellType(rawValue: "powershell"), .powershell)
        XCTAssertNil(ShellType(rawValue: "unknown"))
        XCTAssertNil(ShellType(rawValue: "cmd"))
    }

    // MARK: - Bash Completion Tests

    func testBashCompletionNotEmpty() {
        let output = captureStdout {
            ShellCompletion.generate(for: .bash)
        }
        XCTAssertFalse(output.isEmpty)
    }

    func testBashCompletionContainsHeader() {
        let output = captureStdout {
            ShellCompletion.generate(for: .bash)
        }
        XCTAssertTrue(output.contains("# bash completion for ebook-mechanic"))
    }

    func testBashCompletionContainsFunction() {
        let output = captureStdout {
            ShellCompletion.generate(for: .bash)
        }
        XCTAssertTrue(output.contains("_ebook_mechanic_completions()"))
        XCTAssertTrue(output.contains("complete -F _ebook_mechanic_completions ebook-mechanic"))
    }

    func testBashCompletionContainsAllFlags() {
        let output = captureStdout {
            ShellCompletion.generate(for: .bash)
        }

        let requiredFlags = [
            "--help", "-h",
            "--version", "-V",
            "--generate-completion",
            "--dir", "-d",
            "--corrupted-dir", "-c",
            "--corruption-only",
            "--empty-folders-only",
            "--repair", "-r",
            "--dry-run",
            "--no-confirm",
            "--quiet",
            "--report",
            "--normalize-epubs",
            "--force-normalize"
        ]

        for flag in requiredFlags {
            XCTAssertTrue(output.contains(flag), "Missing flag: \(flag)")
        }
    }

    func testBashCompletionContainsShellTypes() {
        let output = captureStdout {
            ShellCompletion.generate(for: .bash)
        }
        XCTAssertTrue(output.contains("bash zsh fish powershell"))
    }

    // MARK: - Zsh Completion Tests

    func testZshCompletionNotEmpty() {
        let output = captureStdout {
            ShellCompletion.generate(for: .zsh)
        }
        XCTAssertFalse(output.isEmpty)
    }

    func testZshCompletionContainsCompdef() {
        let output = captureStdout {
            ShellCompletion.generate(for: .zsh)
        }
        XCTAssertTrue(output.contains("#compdef ebook-mechanic"))
    }

    func testZshCompletionContainsFunction() {
        let output = captureStdout {
            ShellCompletion.generate(for: .zsh)
        }
        XCTAssertTrue(output.contains("_ebook_mechanic()"))
        XCTAssertTrue(output.contains("_arguments -s -S $options"))
    }

    func testZshCompletionContainsAllFlags() {
        let output = captureStdout {
            ShellCompletion.generate(for: .zsh)
        }

        let requiredFlags = [
            "--help", "-h",
            "--version", "-V",
            "--generate-completion",
            "--dir", "-d",
            "--corrupted-dir", "-c",
            "--corruption-only",
            "--empty-folders-only",
            "--repair", "-r",
            "--dry-run",
            "--no-confirm",
            "--quiet",
            "--report"
        ]

        for flag in requiredFlags {
            XCTAssertTrue(output.contains(flag), "Missing flag: \(flag)")
        }
    }

    func testZshCompletionContainsDirectoryCompletion() {
        let output = captureStdout {
            ShellCompletion.generate(for: .zsh)
        }
        XCTAssertTrue(output.contains(":directory:_directories"))
    }

    // MARK: - Fish Completion Tests

    func testFishCompletionNotEmpty() {
        let output = captureStdout {
            ShellCompletion.generate(for: .fish)
        }
        XCTAssertFalse(output.isEmpty)
    }

    func testFishCompletionContainsHeader() {
        let output = captureStdout {
            ShellCompletion.generate(for: .fish)
        }
        XCTAssertTrue(output.contains("# fish completion for ebook-mechanic"))
    }

    func testFishCompletionUsesCompleteCommands() {
        let output = captureStdout {
            ShellCompletion.generate(for: .fish)
        }
        XCTAssertTrue(output.contains("complete -c ebook-mechanic"))
    }

    func testFishCompletionContainsAllFlags() {
        let output = captureStdout {
            ShellCompletion.generate(for: .fish)
        }

        let requiredFlags = [
            "-s h", "-l help",
            "-s V", "-l version",
            "-l generate-completion",
            "-s d", "-l dir",
            "-s c", "-l corrupted-dir",
            "-l corruption-only",
            "-l empty-folders-only",
            "-s r", "-l repair",
            "-l dry-run",
            "-l no-confirm",
            "-l quiet",
            "-l report"
        ]

        for flag in requiredFlags {
            XCTAssertTrue(output.contains(flag), "Missing flag: \(flag)")
        }
    }

    func testFishCompletionContainsShellChoices() {
        let output = captureStdout {
            ShellCompletion.generate(for: .fish)
        }
        XCTAssertTrue(output.contains("-xa 'bash zsh fish powershell'"))
    }

    func testFishCompletionContainsDescriptions() {
        let output = captureStdout {
            ShellCompletion.generate(for: .fish)
        }
        XCTAssertTrue(output.contains("-d 'Show help message'"))
        XCTAssertTrue(output.contains("-d 'Directory to scan'"))
        XCTAssertTrue(output.contains("-d 'Attempt to repair corrupted files'"))
    }

    // MARK: - PowerShell Completion Tests

    func testPowerShellCompletionNotEmpty() {
        let output = captureStdout {
            ShellCompletion.generate(for: .powershell)
        }
        XCTAssertFalse(output.isEmpty)
    }

    func testPowerShellCompletionContainsHeader() {
        let output = captureStdout {
            ShellCompletion.generate(for: .powershell)
        }
        XCTAssertTrue(output.contains("# PowerShell completion for ebook-mechanic"))
    }

    func testPowerShellCompletionContainsRegisterCommand() {
        let output = captureStdout {
            ShellCompletion.generate(for: .powershell)
        }
        XCTAssertTrue(output.contains("Register-ArgumentCompleter -Native -CommandName ebook-mechanic"))
    }

    func testPowerShellCompletionContainsAllFlags() {
        let output = captureStdout {
            ShellCompletion.generate(for: .powershell)
        }

        let requiredFlags = [
            "'-h'", "'--help'",
            "'-V'", "'--version'",
            "'--generate-completion'",
            "'-d'", "'--dir'",
            "'-c'", "'--corrupted-dir'",
            "'--corruption-only'",
            "'--empty-folders-only'",
            "'-r'", "'--repair'",
            "'--dry-run'",
            "'--no-confirm'",
            "'--quiet'",
            "'--report'"
        ]

        for flag in requiredFlags {
            XCTAssertTrue(output.contains(flag), "Missing flag: \(flag)")
        }
    }

    func testPowerShellCompletionContainsDescriptions() {
        let output = captureStdout {
            ShellCompletion.generate(for: .powershell)
        }
        XCTAssertTrue(output.contains("'Show help message'"))
        XCTAssertTrue(output.contains("'Directory to scan'"))
        XCTAssertTrue(output.contains("'Attempt to repair corrupted files'"))
    }

    func testPowerShellCompletionContainsShellTypes() {
        let output = captureStdout {
            ShellCompletion.generate(for: .powershell)
        }
        XCTAssertTrue(output.contains("@('bash', 'zsh', 'fish', 'powershell')"))
    }

    // MARK: - Content Validation Tests

    func testBashCompletionIsValidScript() {
        let output = captureStdout {
            ShellCompletion.generate(for: .bash)
        }

        XCTAssertTrue(output.contains("COMPREPLY"))
        XCTAssertTrue(output.contains("compgen"))
    }

    func testZshCompletionIsValidScript() {
        let output = captureStdout {
            ShellCompletion.generate(for: .zsh)
        }

        XCTAssertTrue(output.contains("_arguments"))
        XCTAssertTrue(output.contains("compdef"))
    }

    func testFishCompletionIsValidScript() {
        let output = captureStdout {
            ShellCompletion.generate(for: .fish)
        }

        XCTAssertTrue(output.contains("complete -c"))
        XCTAssertTrue(output.contains("-d '"))
    }

    func testPowerShellCompletionIsValidScript() {
        let output = captureStdout {
            ShellCompletion.generate(for: .powershell)
        }

        XCTAssertTrue(output.contains("Register-ArgumentCompleter"))
    }

    // MARK: - Consistency Tests

    func testAllShellCompletionsContainSameFlags() {
        let bashOutput = captureStdout { ShellCompletion.generate(for: .bash) }
        let zshOutput = captureStdout { ShellCompletion.generate(for: .zsh) }
        let fishOutput = captureStdout { ShellCompletion.generate(for: .fish) }
        let pwshOutput = captureStdout { ShellCompletion.generate(for: .powershell) }

        let coreFlags = ["--help", "--version", "--dir", "--repair", "--dry-run", "--quiet"]

        for flag in coreFlags {
            XCTAssertTrue(bashOutput.contains(flag), "Bash missing: \(flag)")
            XCTAssertTrue(zshOutput.contains(flag), "Zsh missing: \(flag)")
            XCTAssertTrue(pwshOutput.contains(flag), "PowerShell missing: \(flag)")
        }

        // Fish completions describe flags using -l/-s descriptors instead of --flag strings.
        let fishExpectations = [
            "-l help",
            "-l version",
            "-l dir",
            "-l repair",
            "-l dry-run",
            "-l quiet"
        ]
        for expectation in fishExpectations {
            XCTAssertTrue(fishOutput.contains(expectation), "Fish missing: \(expectation)")
        }
    }

    // MARK: - Helper Methods

    private func captureStdout(_ closure: () -> Void) -> String {
        // Create a pipe to capture stdout
        let pipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)

        // Redirect stdout to our pipe
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        // Execute the closure
        closure()

        // Flush and restore stdout
        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        pipe.fileHandleForWriting.closeFile()

        // Read the captured output
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        pipe.fileHandleForReading.closeFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

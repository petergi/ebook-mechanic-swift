import XCTest

@testable import EbookMechanicCLI

// swiftlint:disable type_body_length

final class CLIConfigurationTests: XCTestCase {
  func testDefaultsWhenNoArgumentsProvided() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic"])
    XCTAssertEqual(config.directory, FileManager.default.currentDirectoryPath)
    XCTAssertEqual(config.corruptedDirectory, "CORRUPTED")
    XCTAssertFalse(config.corruptionOnly)
    XCTAssertFalse(config.emptyFoldersOnly)
    XCTAssertFalse(config.repair)
    XCTAssertFalse(config.dryRun)
    XCTAssertFalse(config.autoConfirm)
    XCTAssertTrue(config.verbose)
    XCTAssertFalse(config.generateReport)
  }

  func testParsingVariousFlags() throws {
    let arguments = [
      "ebook-mechanic",
      "--dir", "/tmp/library",
      "--corrupted-dir", "BROKEN",
      "--corruption-only",
      "--repair",
      "--dry-run",
      "--no-confirm",
      "--quiet",
      "--report",
    ]
    let config = try CLIConfiguration.parse(arguments: arguments)
    XCTAssertEqual(config.directory, "/tmp/library")
    XCTAssertEqual(config.corruptedDirectory, "BROKEN")
    XCTAssertTrue(config.corruptionOnly)
    XCTAssertFalse(config.emptyFoldersOnly)
    XCTAssertTrue(config.repair)
    XCTAssertTrue(config.dryRun)
    XCTAssertTrue(config.autoConfirm)
    XCTAssertFalse(config.verbose)
    XCTAssertTrue(config.generateReport)
  }

  func testEmptyFoldersOnlyResetsCorruptionOnly() throws {
    let arguments = [
      "ebook-mechanic",
      "--corruption-only",
      "--empty-folders-only",
    ]
    let config = try CLIConfiguration.parse(arguments: arguments)
    XCTAssertFalse(config.corruptionOnly)
    XCTAssertTrue(config.emptyFoldersOnly)
  }

  func testUnknownArgumentThrows() {
    let arguments = ["ebook-mechanic", "--unknown"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.invalidArgument(let message) = error else {
        return XCTFail("Unexpected error type: \(error)")
      }
      XCTAssertTrue(message.contains("--unknown"))
    }
  }

  func testHelpFlagThrowsUserRequestedHelp() {
    let arguments = ["ebook-mechanic", "--help"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.userRequestedHelp = error else {
        return XCTFail("Expected userRequestedHelp, got \(error)")
      }
    }
  }

  func testVersionFlagThrowsUserRequestedVersion() {
    let arguments = ["ebook-mechanic", "--version"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.userRequestedVersion = error else {
        return XCTFail("Expected userRequestedVersion, got \(error)")
      }
    }
  }

  // MARK: - Short Flag Tests

  func testShortHelpFlag() {
    let arguments = ["ebook-mechanic", "-h"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.userRequestedHelp = error else {
        return XCTFail("Expected userRequestedHelp, got \(error)")
      }
    }
  }

  func testShortVersionFlag() {
    let arguments = ["ebook-mechanic", "-V"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.userRequestedVersion = error else {
        return XCTFail("Expected userRequestedVersion, got \(error)")
      }
    }
  }

  func testShortDirFlag() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-d", "/tmp/books"])
    XCTAssertEqual(config.directory, "/tmp/books")
  }

  func testShortCorruptedDirFlag() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-c", "BAD_FILES"])
    XCTAssertEqual(config.corruptedDirectory, "BAD_FILES")
  }

  func testShortRepairFlag() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-r"])
    XCTAssertTrue(config.repair)
  }

  // MARK: - Missing Value Tests

  func testDirFlagWithMissingValue() {
    let arguments = ["ebook-mechanic", "--dir"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.invalidArgument(let message) = error else {
        return XCTFail("Expected invalidArgument, got \(error)")
      }
      XCTAssertTrue(message.contains("Missing value"))
    }
  }

  func testShortDirFlagWithMissingValue() {
    let arguments = ["ebook-mechanic", "-d"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.invalidArgument(let message) = error else {
        return XCTFail("Expected invalidArgument, got \(error)")
      }
      XCTAssertTrue(message.contains("Missing value"))
    }
  }

  func testCorruptedDirFlagWithMissingValue() {
    let arguments = ["ebook-mechanic", "--corrupted-dir"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.invalidArgument(let message) = error else {
        return XCTFail("Expected invalidArgument, got \(error)")
      }
      XCTAssertTrue(message.contains("Missing value"))
    }
  }

  func testShortCorruptedDirFlagWithMissingValue() {
    let arguments = ["ebook-mechanic", "-c"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.invalidArgument(let message) = error else {
        return XCTFail("Expected invalidArgument, got \(error)")
      }
      XCTAssertTrue(message.contains("Missing value"))
    }
  }

  func testGenerateCompletionWithMissingShellType() {
    let arguments = ["ebook-mechanic", "--generate-completion"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.invalidArgument(let message) = error else {
        return XCTFail("Expected invalidArgument, got \(error)")
      }
      XCTAssertTrue(message.contains("Missing shell type"))
    }
  }

  // MARK: - Shell Completion Tests

  func testGenerateCompletionForBash() {
    let arguments = ["ebook-mechanic", "--generate-completion", "bash"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.userRequestedCompletion(let shell) = error else {
        return XCTFail("Expected userRequestedCompletion, got \(error)")
      }
      XCTAssertEqual(shell, .bash)
    }
  }

  func testGenerateCompletionForZsh() {
    let arguments = ["ebook-mechanic", "--generate-completion", "zsh"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.userRequestedCompletion(let shell) = error else {
        return XCTFail("Expected userRequestedCompletion, got \(error)")
      }
      XCTAssertEqual(shell, .zsh)
    }
  }

  func testGenerateCompletionForFish() {
    let arguments = ["ebook-mechanic", "--generate-completion", "fish"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.userRequestedCompletion(let shell) = error else {
        return XCTFail("Expected userRequestedCompletion, got \(error)")
      }
      XCTAssertEqual(shell, .fish)
    }
  }

  func testGenerateCompletionForPowerShell() {
    let arguments = ["ebook-mechanic", "--generate-completion", "powershell"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.userRequestedCompletion(let shell) = error else {
        return XCTFail("Expected userRequestedCompletion, got \(error)")
      }
      XCTAssertEqual(shell, .powershell)
    }
  }

  func testGenerateCompletionWithInvalidShell() {
    let arguments = ["ebook-mechanic", "--generate-completion", "cmd"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.invalidArgument(let message) = error else {
        return XCTFail("Expected invalidArgument, got \(error)")
      }
      XCTAssertTrue(message.contains("Unknown shell"))
      XCTAssertTrue(message.contains("cmd"))
    }
  }

  func testGenerateCompletionCaseInsensitive() {
    let arguments = ["ebook-mechanic", "--generate-completion", "BASH"]
    XCTAssertThrowsError(try CLIConfiguration.parse(arguments: arguments)) { error in
      guard case CLIError.userRequestedCompletion(let shell) = error else {
        return XCTFail("Expected userRequestedCompletion, got \(error)")
      }
      XCTAssertEqual(shell, .bash)
    }
  }

  // MARK: - Special Character and Path Tests

  func testDirectoryWithSpaces() throws {
    let config = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic", "-d", "/Users/test/My Books",
    ])
    XCTAssertEqual(config.directory, "/Users/test/My Books")
  }

  func testDirectoryWithSpecialCharacters() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-d", "/tmp/books@2024!"])
    XCTAssertEqual(config.directory, "/tmp/books@2024!")
  }

  func testDirectoryWithUnicode() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-d", "/tmp/图书馆"])
    XCTAssertEqual(config.directory, "/tmp/图书馆")
  }

  func testCorruptedDirWithSpaces() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-c", "Bad Files"])
    XCTAssertEqual(config.corruptedDirectory, "Bad Files")
  }

  func testVeryLongPath() throws {
    let longPath = String(repeating: "a", count: 500)
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-d", "/\(longPath)"])
    XCTAssertEqual(config.directory, "/\(longPath)")
  }

  func testEmptyStringDirectory() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-d", ""])
    XCTAssertEqual(config.directory, "")
  }

  // MARK: - Flag Order and Combination Tests

  func testFlagsInDifferentOrders() throws {
    let config1 = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic", "-r", "-d", "/tmp", "--quiet",
    ])
    let config2 = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic", "--quiet", "-d", "/tmp", "-r",
    ])
    let config3 = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic", "-d", "/tmp", "--quiet", "-r",
    ])

    XCTAssertEqual(config1.directory, "/tmp")
    XCTAssertTrue(config1.repair)
    XCTAssertFalse(config1.verbose)

    XCTAssertEqual(config2.directory, "/tmp")
    XCTAssertTrue(config2.repair)
    XCTAssertFalse(config2.verbose)

    XCTAssertEqual(config3.directory, "/tmp")
    XCTAssertTrue(config3.repair)
    XCTAssertFalse(config3.verbose)
  }

  func testMixingShortAndLongFlags() throws {
    let config = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic",
      "-d", "/tmp/library",
      "--corruption-only",
      "-r",
      "--no-confirm",
      "-c", "BROKEN",
    ])
    XCTAssertEqual(config.directory, "/tmp/library")
    XCTAssertEqual(config.corruptedDirectory, "BROKEN")
    XCTAssertTrue(config.corruptionOnly)
    XCTAssertTrue(config.repair)
    XCTAssertTrue(config.autoConfirm)
  }

  func testAllFlagsTogether() throws {
    let config = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic",
      "-d", "/books",
      "-c", "BAD",
      "-r",
      "--dry-run",
      "--no-confirm",
      "--quiet",
      "--report",
      "--normalize-epubs",
      "--force-normalize",
    ])
    XCTAssertEqual(config.directory, "/books")
    XCTAssertEqual(config.corruptedDirectory, "BAD")
    XCTAssertTrue(config.repair)
    XCTAssertTrue(config.dryRun)
    XCTAssertTrue(config.autoConfirm)
    XCTAssertFalse(config.verbose)
    XCTAssertTrue(config.generateReport)
    XCTAssertTrue(config.normalizeEPUBs)
    XCTAssertTrue(config.forceNormalize)
  }

  // MARK: - Normalization Flag Tests

  func testNormalizeEPUBsFlag() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "--normalize-epubs"])
    XCTAssertTrue(config.normalizeEPUBs)
    XCTAssertFalse(config.forceNormalize)
  }

  func testForceNormalizeFlag() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "--force-normalize"])
    XCTAssertTrue(config.forceNormalize)
    XCTAssertTrue(config.normalizeEPUBs)  // --force-normalize implicitly enables --normalize-epubs
  }

  func testBothNormalizationFlags() throws {
    let config = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic",
      "--normalize-epubs",
      "--force-normalize",
    ])
    XCTAssertTrue(config.normalizeEPUBs)
    XCTAssertTrue(config.forceNormalize)
  }

  // MARK: - Corruption/Empty Folder Interaction Tests

  func testCorruptionOnlyResetsWhenEmptyFoldersOnlySet() throws {
    let arguments = [
      "ebook-mechanic",
      "--empty-folders-only",
      "--corruption-only",
    ]
    let config = try CLIConfiguration.parse(arguments: arguments)
    XCTAssertTrue(config.emptyFoldersOnly)
    XCTAssertFalse(config.corruptionOnly)
  }

  func testEmptyFoldersOnlyAlone() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "--empty-folders-only"])
    XCTAssertTrue(config.emptyFoldersOnly)
    XCTAssertFalse(config.corruptionOnly)
  }

  func testCorruptionOnlyAlone() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "--corruption-only"])
    XCTAssertTrue(config.corruptionOnly)
    XCTAssertFalse(config.emptyFoldersOnly)
  }

  // MARK: - Edge Case Tests

  func testMultipleSameFlagsLastOneWins() throws {
    let config = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic",
      "-d", "/first",
      "-d", "/second",
      "-d", "/third",
    ])
    XCTAssertEqual(config.directory, "/third")
  }

  func testQuietFlagOverridesVerboseDefault() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "--quiet"])
    XCTAssertFalse(config.verbose)
  }

  func testDryRunDoesNotAffectOtherFlags() throws {
    let config = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic",
      "--dry-run",
      "-r",
      "--report",
    ])
    XCTAssertTrue(config.dryRun)
    XCTAssertTrue(config.repair)
    XCTAssertTrue(config.generateReport)
  }

  func testNoConfirmFlagSetsAutoConfirm() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "--no-confirm"])
    XCTAssertTrue(config.autoConfirm)
  }

  func testReportFlagSetsGenerateReport() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "--report"])
    XCTAssertTrue(config.generateReport)
  }

  // MARK: - Relative Path Tests

  func testRelativePath() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-d", "./books"])
    XCTAssertEqual(config.directory, "./books")
  }

  func testParentDirectoryPath() throws {
    let config = try CLIConfiguration.parse(arguments: ["ebook-mechanic", "-d", "../books"])
    XCTAssertEqual(config.directory, "../books")
  }

  func testHomeDirectoryPath() throws {
    let config = try CLIConfiguration.parse(arguments: [
      "ebook-mechanic", "-d", "~/Documents/Books",
    ])
    XCTAssertEqual(config.directory, "~/Documents/Books")
  }
}
// swiftlint:enable type_body_length

import XCTest
@testable import EbookMechanicCLI

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
            "--report"
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
            "--empty-folders-only"
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
}

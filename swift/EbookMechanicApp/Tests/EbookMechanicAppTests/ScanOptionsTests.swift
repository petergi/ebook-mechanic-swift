import XCTest
import Foundation
@testable import EbookMechanicApp
import EbookMechanicCore

final class ScanOptionsTests: XCTestCase {
    func testDefaults() {
        let options = ScanOptions(directory: URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(options.directory.path, "/tmp")
        XCTAssertEqual(options.corruptedDirectoryName, "CORRUPTED")
        XCTAssertFalse(options.repair)
        XCTAssertFalse(options.corruptionOnly)
        XCTAssertFalse(options.emptyFoldersOnly)
        XCTAssertTrue(options.dryRun)
        XCTAssertFalse(options.autoMoveCorrupted)
        XCTAssertFalse(options.autoDeleteEmptyFolders)
        XCTAssertFalse(options.generateReport)
        XCTAssertFalse(options.normalizeEPUBs)
        XCTAssertFalse(options.forceNormalize)
    }

    @MainActor
    func testViewModelResetClearsState() {
        let viewModel = ScanViewModel()
        viewModel.progressHeadline = "Progress"
        viewModel.progressDetail = "Detail"
        viewModel.corruptedFiles = [CorruptedFile(url: URL(fileURLWithPath: "/tmp/file.epub"), reason: "Invalid", size: 10)]
        viewModel.emptyFolders = [URL(fileURLWithPath: "/tmp/empty")]
        viewModel.summary = ScanResult(totalFiles: 1)
        viewModel.statusMessages = ["Message"]
        viewModel.reportURL = URL(fileURLWithPath: "/tmp/report.md")
        viewModel.errorMessage = "error"

        viewModel.reset()

        XCTAssertTrue(viewModel.progressHeadline.isEmpty)
        XCTAssertTrue(viewModel.progressDetail.isEmpty)
        XCTAssertTrue(viewModel.corruptedFiles.isEmpty)
        XCTAssertTrue(viewModel.emptyFolders.isEmpty)
        XCTAssertNil(viewModel.summary)
        XCTAssertTrue(viewModel.statusMessages.isEmpty)
        XCTAssertNil(viewModel.reportURL)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testRunScanOnEmptyDirectoryProducesSummary() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let viewModel = ScanViewModel()

        var options = ScanOptions(directory: tempDir)
        options.generateReport = false
        options.dryRun = true

        await viewModel.runScan(options: options)

        XCTAssertNotNil(viewModel.summary)
        XCTAssertEqual(viewModel.summary?.totalFiles, 0)
        XCTAssertTrue(viewModel.corruptedFiles.isEmpty)
        XCTAssertTrue(viewModel.emptyFolders.isEmpty)
        XCTAssertTrue(viewModel.statusMessages.contains { $0.contains("Scanned") })

        try? FileManager.default.removeItem(at: tempDir)
    }
}


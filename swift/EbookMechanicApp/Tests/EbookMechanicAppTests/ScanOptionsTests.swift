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

    @MainActor
    func testRunScanDetectsCorruptedPDFAndStatusMessages() async throws {
        let tempDir = try makeTemporaryDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
        try writeTinyCorruptedPDF(named: "bad.pdf", in: tempDir)

        let viewModel = ScanViewModel()
        var options = ScanOptions(directory: tempDir)
        options.dryRun = true

        await viewModel.runScan(options: options)

        XCTAssertEqual(viewModel.summary?.totalFiles, 1)
        XCTAssertEqual(viewModel.corruptedFiles.count, 1)
        XCTAssertEqual(viewModel.corruptedFiles.first?.reason, "File too small to be valid PDF")
        XCTAssertTrue(viewModel.statusMessages.contains { $0.contains("Scanned 1 files") })
        XCTAssertTrue(viewModel.statusMessages.contains { $0.contains("Detected 1 corrupted file") })
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testRunScanWithRepairMarksFilesAsFixed() async throws {
        let tempDir = try makeTemporaryDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
        let pdfURL = try writeLargePDFMissingEOF(named: "needs-repair.pdf", in: tempDir)

        let viewModel = ScanViewModel()
        var options = ScanOptions(directory: tempDir)
        options.dryRun = false
        options.repair = true

        await viewModel.runScan(options: options)

        XCTAssertEqual(viewModel.corruptedFiles.count, 1)
        XCTAssertEqual(viewModel.corruptedFiles.first?.reason, "Fixed")
        XCTAssertTrue(viewModel.statusMessages.contains { $0.contains("Repair attempts: 1, fixed: 1") })

        let data = try Data(contentsOf: pdfURL)
        XCTAssertTrue(String(data: data.suffix(6), encoding: .ascii)?.contains("%%EOF") == true)
    }

    @MainActor
    func testRunScanAutomationMovesCorruptedFilesAndDeletesEmptyFolders() async throws {
        let tempDir = try makeTemporaryDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
        let shelf = tempDir.appendingPathComponent("Shelf")
        try FileManager.default.createDirectory(at: shelf, withIntermediateDirectories: true)
        try writeValidPDF(named: "reference.pdf", in: shelf)
        try writeTinyCorruptedPDF(named: "broken.pdf", in: tempDir)
        let emptyFolder = tempDir.appendingPathComponent("Unused")
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)

        let viewModel = ScanViewModel()
        var options = ScanOptions(directory: tempDir)
        options.dryRun = false
        options.autoMoveCorrupted = true
        options.autoDeleteEmptyFolders = true

        await viewModel.runScan(options: options)

        let movedCorruptedURL = tempDir.appendingPathComponent("CORRUPTED/broken.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: movedCorruptedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyFolder.path))
        XCTAssertTrue(viewModel.statusMessages.contains { $0.contains("Moved corrupted files to CORRUPTED") })
        XCTAssertTrue(viewModel.statusMessages.contains { $0.contains("Deleted 1 empty folder") })
    }

    @MainActor
    func testRunScanWithNormalizationAndReportProducesArtifacts() async throws {
        let tempDir = try makeTemporaryDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }
        try writeStubEPUB(named: "invalid.epub", in: tempDir)

        let viewModel = ScanViewModel()
        var options = ScanOptions(directory: tempDir)
        options.dryRun = true
        options.normalizeEPUBs = true
        options.generateReport = true

        await viewModel.runScan(options: options)

        XCTAssertEqual(viewModel.summary?.totalFiles, 1)
        XCTAssertEqual(viewModel.corruptedFiles.first?.reason, "Not a valid ZIP file (ZIP archive has invalid signature)")
        XCTAssertTrue(viewModel.statusMessages.contains { $0.contains("EPUB normalization:") })
        XCTAssertTrue(viewModel.statusMessages.contains { $0.contains("Report generated at") })

        let reportURL = try XCTUnwrap(viewModel.reportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: reportURL.path))
        XCTAssertEqual(reportURL.deletingLastPathComponent().standardizedFileURL, tempDir.standardizedFileURL)
        XCTAssertEqual(reportURL.pathExtension, "md")
    }
}

// MARK: - Test helpers

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("EbookMechanicAppTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

@discardableResult
private func writeTinyCorruptedPDF(named: String, in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent(named)
    var data = Data("%PDF-1.7\n".utf8)
    data.append(Data(repeating: 0x41, count: 32))
    try data.write(to: url)
    return url
}

@discardableResult
private func writeLargePDFMissingEOF(named: String, in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent(named)
    var data = Data("%PDF-1.7\n".utf8)
    data.append(Data(repeating: 0x42, count: 256))
    try data.write(to: url)
    return url
}

@discardableResult
private func writeValidPDF(named: String, in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent(named)
    var data = Data("%PDF-1.7\n".utf8)
    data.append(Data(repeating: 0x43, count: 160))
    data.append(Data("\n%%EOF\n".utf8))
    try data.write(to: url)
    return url
}

@discardableResult
private func writeStubEPUB(named: String, in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent(named)
    try Data("not-a-zip".utf8).write(to: url)
    return url
}

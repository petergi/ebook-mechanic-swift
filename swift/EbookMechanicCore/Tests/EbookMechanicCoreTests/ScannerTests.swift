import XCTest
@testable import EbookMechanicCore

final class ScannerTests: XCTestCase {
    func testScanForCorruptionAndEmptyFolders() async throws {
        let tempDir = try temporaryRoot()
        let goodEPUB = tempDir.appendingPathComponent("Books/Valid/ok.epub")
        let badEPUB = tempDir.appendingPathComponent("Books/Broken/bad.epub")
        let emptyFolder = tempDir.appendingPathComponent("Books/Empty")
        try FileManager.default.createDirectory(at: goodEPUB.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: badEPUB.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true, attributes: nil)

        try TestFixtures.createValidEPUB(at: goodEPUB)
        try TestFixtures.createEPUBWithoutMimetype(at: badEPUB)

        let scanner = FileScanner(rootDirectory: tempDir)
        let result = try await scanner.scanForCorruption()

        XCTAssertEqual(result.totalFiles, 2)
        XCTAssertEqual(result.corruptedFiles.count, 1)
        XCTAssertEqual(result.breakdown(for: .epub).total, 2)
        XCTAssertEqual(result.breakdown(for: .epub).corrupted, 1)

        let foldersResult = try await scanner.scanForEmptyFolders()
        let normalizedEmpty = normalize(emptyFolder)
        XCTAssertTrue(
            foldersResult.emptyFolders.contains { normalize($0) == normalizedEmpty },
            "Empty folders: \(foldersResult.emptyFolders)"
        )
        XCTAssertEqual(
            foldersResult.foldersWithEbooks,
            foldersResult.totalFolders - 1,
            "Folders with ebooks: \(foldersResult.foldersWithEbooks), total: \(foldersResult.totalFolders), empty: \(foldersResult.emptyFolders.count)"
        )

        try await scanner.moveCorruptedFiles()
        let corruptedDir = tempDir.appendingPathComponent("CORRUPTED/Books/Broken")
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptedDir.appendingPathComponent("bad.epub").path))

        try await scanner.deleteEmptyFolders()
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyFolder.path))
    }

    func testRepairCorruptedFiles() async throws {
        let tempDir = try temporaryRoot()
        let badPDF = tempDir.appendingPathComponent("Broken/bad.pdf")
        try FileManager.default.createDirectory(at: badPDF.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try TestFixtures.createPDFWithoutEOF(at: badPDF)

        let scanner = FileScanner(rootDirectory: tempDir)
        _ = try await scanner.scanForCorruption()

        let (results, repairedCount) = await scanner.repairCorruptedFiles()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(repairedCount, 1)

        let validator = FileValidator()
        XCTAssertTrue(validator.validate(url: badPDF, as: .pdf).isValid)
    }

    private func temporaryRoot() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func normalize(_ url: URL) -> String {
        var path = url.resolvingSymlinksInPath().path
        while path.hasSuffix("/") { path.removeLast() }
        return path
    }
}

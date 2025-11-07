import XCTest
@testable import EbookMechanicCLI
import EbookMechanicCore
import Foundation

final class ProgressPrinterTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitWithVerboseTrue() {
        let printer = ProgressPrinter(verbose: true)
        XCTAssertTrue(printer.verbose)
    }

    func testInitWithVerboseFalse() {
        let printer = ProgressPrinter(verbose: false)
        XCTAssertFalse(printer.verbose)
    }

    // MARK: - Progress Event Handling Tests

    func testHandleValidatingFileEvent() {
        let printer = ProgressPrinter(verbose: true)
        let url = URL(fileURLWithPath: "/test/book.epub")
        let event = ProgressEvent(
            stage: .validatingFile(url),
            completed: 5,
            total: 100,
            currentItem: "book.epub"
        )

        // Should not crash
        XCTAssertNoThrow(printer.handle(event))
    }

    func testHandleScanningFilesEvent() {
        let printer = ProgressPrinter(verbose: true)
        let event = ProgressEvent(
            stage: .scanningFiles,
            completed: 50,
            total: 100,
            currentItem: ""
        )

        XCTAssertNoThrow(printer.handle(event))
    }

    func testHandleScanningFoldersEvent() {
        let printer = ProgressPrinter(verbose: true)
        let event = ProgressEvent(
            stage: .scanningFolders,
            completed: 10,
            total: 20,
            currentItem: "/test/folder"
        )

        XCTAssertNoThrow(printer.handle(event))
    }

    func testHandleMovingCorruptedFilesEvent() {
        let printer = ProgressPrinter(verbose: true)
        let event = ProgressEvent(
            stage: .movingCorruptedFiles,
            completed: 3,
            total: 10,
            currentItem: "corrupted.epub"
        )

        XCTAssertNoThrow(printer.handle(event))
    }

    func testHandleDeletingEmptyFoldersEvent() {
        let printer = ProgressPrinter(verbose: true)
        let event = ProgressEvent(
            stage: .deletingEmptyFolders,
            completed: 1,
            total: 5,
            currentItem: "/empty/folder"
        )

        XCTAssertNoThrow(printer.handle(event))
    }

    func testHandleRepairingFilesEvent() {
        let printer = ProgressPrinter(verbose: true)
        let event = ProgressEvent(
            stage: .repairingFiles,
            completed: 2,
            total: 5,
            currentItem: "broken.pdf"
        )

        XCTAssertNoThrow(printer.handle(event))
    }

    func testHandleNormalizingFilesEvent() {
        let printer = ProgressPrinter(verbose: true)
        let event = ProgressEvent(
            stage: .normalizingFiles,
            completed: 15,
            total: 30,
            currentItem: "book.epub"
        )

        XCTAssertNoThrow(printer.handle(event))
    }

    func testHandleEventWhenNotVerbose() {
        let printer = ProgressPrinter(verbose: false)
        let url = URL(fileURLWithPath: "/test/book.epub")
        let event = ProgressEvent(
            stage: .validatingFile(url),
            completed: 5,
            total: 100,
            currentItem: "book.epub"
        )

        // Should silently do nothing when not verbose
        XCTAssertNoThrow(printer.handle(event))
    }

    // MARK: - Print Method Tests

    func testPrintHeader() {
        let printer = ProgressPrinter(verbose: true)
        XCTAssertNoThrow(printer.printHeader("Test Header"))
    }

    func testPrintFooter() {
        let printer = ProgressPrinter(verbose: true)
        XCTAssertNoThrow(printer.printFooter("Test Footer"))
    }

    func testPrintInfo() {
        let printer = ProgressPrinter(verbose: true)
        XCTAssertNoThrow(printer.printInfo("Test info message"))
    }

    func testPrintSuccess() {
        let printer = ProgressPrinter(verbose: true)
        XCTAssertNoThrow(printer.printSuccess("Test success message"))
    }

    func testPrintBullet() {
        let printer = ProgressPrinter(verbose: true)
        XCTAssertNoThrow(printer.printBullet("Test bullet point"))
    }

    // MARK: - Scan Result Printing Tests

    func testPrintScanResultEmpty() {
        let printer = ProgressPrinter(verbose: true)
        let result = ScanResult(totalFiles: 0)

        XCTAssertNoThrow(printer.printScanResult(result))
    }

    func testPrintScanResultWithCorruptedFiles() {
        let printer = ProgressPrinter(verbose: true)
        var result = ScanResult(totalFiles: 100)

        // Add some corrupted files
        let url1 = URL(fileURLWithPath: "/test/corrupted1.epub")
        let url2 = URL(fileURLWithPath: "/test/corrupted2.pdf")
        result.corruptedFiles.append(CorruptedFile(url: url1, reason: "Invalid ZIP structure", size: 1024))
        result.corruptedFiles.append(CorruptedFile(url: url2, reason: "Missing EOF marker", size: 2048))

        XCTAssertNoThrow(printer.printScanResult(result))
    }

    func testPrintScanResultWithManyCorruptedFiles() {
        let printer = ProgressPrinter(verbose: true)
        var result = ScanResult(totalFiles: 100)

        // Add more than 10 corrupted files to test truncation
        for i in 1...15 {
            let url = URL(fileURLWithPath: "/test/corrupted\(i).epub")
            result.corruptedFiles.append(CorruptedFile(url: url, reason: "Test reason \(i)", size: Int64(i * 1024)))
        }

        XCTAssertNoThrow(printer.printScanResult(result))
    }

    func testPrintScanResultWithBreakdownByType() {
        let printer = ProgressPrinter(verbose: true)
        var result = ScanResult(totalFiles: 100)

        // Add corrupted files of different types
        result.corruptedFiles.append(CorruptedFile(url: URL(fileURLWithPath: "/test/file1.epub"), reason: "Bad EPUB", size: 1024))
        result.corruptedFiles.append(CorruptedFile(url: URL(fileURLWithPath: "/test/file2.pdf"), reason: "Bad PDF", size: 2048))
        result.corruptedFiles.append(CorruptedFile(url: URL(fileURLWithPath: "/test/file3.mobi"), reason: "Bad MOBI", size: 3072))

        XCTAssertNoThrow(printer.printScanResult(result))
    }

    // MARK: - Repair Summary Tests

    func testPrintRepairSummaryEmpty() {
        let printer = ProgressPrinter(verbose: true)
        XCTAssertNoThrow(printer.printRepairSummary(results: [], repairedCount: 0))
    }

    func testPrintRepairSummaryWithSuccessfulRepairs() {
        let printer = ProgressPrinter(verbose: true)
        let results = [
            RepairResult(success: true, message: "Added EOF marker", fixed: true),
            RepairResult(success: true, message: "Fixed mimetype", fixed: true)
        ]

        XCTAssertNoThrow(printer.printRepairSummary(results: results, repairedCount: 2))
    }

    func testPrintRepairSummaryWithMixedResults() {
        let printer = ProgressPrinter(verbose: true)
        let results = [
            RepairResult(success: true, message: "Repaired", fixed: true),
            RepairResult(success: true, message: "Already valid", fixed: false),
            RepairResult(success: false, message: "Cannot repair MOBI", fixed: false)
        ]

        XCTAssertNoThrow(printer.printRepairSummary(results: results, repairedCount: 1))
    }

    func testPrintRepairSummaryNonVerbose() {
        let printer = ProgressPrinter(verbose: false)
        let results = [
            RepairResult(success: true, message: "Repaired", fixed: true)
        ]

        // Should still print summary info even when not verbose
        XCTAssertNoThrow(printer.printRepairSummary(results: results, repairedCount: 1))
    }

    // MARK: - Edge Case Tests

    func testHandleEventWithZeroTotal() {
        let printer = ProgressPrinter(verbose: true)
        let event = ProgressEvent(
            stage: .scanningFiles,
            completed: 0,
            total: 0,
            currentItem: ""
        )

        XCTAssertNoThrow(printer.handle(event))
    }

    func testHandleEventWithCompletedGreaterThanTotal() {
        let printer = ProgressPrinter(verbose: true)
        let event = ProgressEvent(
            stage: .scanningFiles,
            completed: 150,
            total: 100,
            currentItem: ""
        )

        XCTAssertNoThrow(printer.handle(event))
    }

    func testPrintScanResultWithAllFileTypes() {
        let printer = ProgressPrinter(verbose: true)
        var result = ScanResult(totalFiles: 100)

        // Add at least one file of each type
        for fileType in EbookFileType.allCases {
            let filename = "test\(fileType.fileExtension)"
            result.corruptedFiles.append(
                CorruptedFile(
                    url: URL(fileURLWithPath: "/test/\(filename)"),
                    reason: "Test corruption",
                    size: 1024
                )
            )
        }

        XCTAssertNoThrow(printer.printScanResult(result))
    }
}

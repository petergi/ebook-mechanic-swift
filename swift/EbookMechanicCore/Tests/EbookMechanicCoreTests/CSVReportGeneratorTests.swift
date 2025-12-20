import XCTest
@testable import EbookMechanicCore

final class CSVReportGeneratorTests: XCTestCase {

    var reportGenerator: CSVReportGenerator!
    var mockScanResult: ScanResult!
    var mockRootDirectory: URL!
    var mockCorruptedDirectoryName: String!
    var mockRepairs: [RepairResult]!

    override func setUpWithError() throws {
        reportGenerator = CSVReportGenerator()
        mockRootDirectory = URL(fileURLWithPath: "/Users/test/Library")
        mockCorruptedDirectoryName = "CorruptedBooks"
        
        let corruptedFile1 = CorruptedFile(url: mockRootDirectory.appendingPathComponent("book with,comma.epub"), reason: "Missing mimetype", size: 1024, status: .nonCompliant)
        let corruptedFile2 = CorruptedFile(url: mockRootDirectory.appendingPathComponent("path/to/book\"quotes\".pdf"), reason: "Invalid EOF, marker\nwith newline", size: 2048, status: .corrupt)
        
        mockScanResult = ScanResult(
            totalFiles: 2,
            corruptedFiles: [corruptedFile1, corruptedFile2],
            breakdowns: [
                .epub: FormatBreakdown(total: 1, corrupted: 1),
                .pdf: FormatBreakdown(total: 1, corrupted: 1)
            ],
            emptyFolders: [mockRootDirectory.appendingPathComponent("empty/folder")],
            totalFolders: 1,
            foldersWithEbooks: 0
        )
        
        mockRepairs = [
            RepairResult(success: true, message: "Fixed mimetype", fixed: true, fileURL: corruptedFile1.url),
            RepairResult(success: false, message: "Could not fix PDF: reason, with \"quotes\"", fixed: false, fileURL: corruptedFile2.url)
        ]
    }

    func testCSVHeadersAndContent() throws {
        let csvString = try reportGenerator.generate(from: mockScanResult, rootDirectory: mockRootDirectory, corruptedDirectoryName: mockCorruptedDirectoryName, repairs: mockRepairs)
        
        let lines = csvString.split(separator: "\n")
        XCTAssertTrue(lines.count > 0)
        
        // Test header row
        XCTAssertEqual(lines[0], "FilePath,Status,Format,Reason,FileSize,Fingerprint")
        
        // Test data rows
        XCTAssertTrue(lines[1].contains("\"book with,comma.epub\""))
        XCTAssertTrue(lines[1].contains("\"nonCompliant\""))
        XCTAssertTrue(lines[1].contains("\"epub\""))
        XCTAssertTrue(lines[1].contains("\"Missing mimetype\""))
        XCTAssertTrue(lines[1].contains("1024"))

        XCTAssertTrue(lines[2].contains("\"path/to/book\"\"quotes\".pdf\""))
        XCTAssertTrue(lines[2].contains("\"corrupt\""))
        XCTAssertTrue(lines[2].contains("\"pdf\""))
        XCTAssertTrue(lines[2].contains("\"Invalid EOF, marker\nwith newline\"")) // Newline escaped in CSV standard way
        XCTAssertTrue(lines[2].contains("2048"))
    }

    func testSummaryRows() throws {
        let csvString = try reportGenerator.generate(from: mockScanResult, rootDirectory: mockRootDirectory, corruptedDirectoryName: mockCorruptedDirectoryName, repairs: mockRepairs)
        
        XCTAssertTrue(csvString.contains("\nSummary: Corrupted Files\n"))
        XCTAssertTrue(csvString.contains("Format,Corrupted,Total\n"))
        XCTAssertTrue(csvString.contains("epub,1,1\n"))
        XCTAssertTrue(csvString.contains("pdf,1,1\n"))
        XCTAssertTrue(csvString.contains("Total,2,2\n"))
        
        XCTAssertTrue(csvString.contains("\nSummary: Empty Folders\n"))
        XCTAssertTrue(csvString.contains("Empty Folders,1\n"))
        XCTAssertTrue(csvString.contains("Total Folders,1\n"))
        XCTAssertTrue(csvString.contains("Folders with Ebooks,0\n"))
    }

    func testCSVEscaping() throws {
        let specialCharReason = "Reason with, commas\"quotes\"and\nnewlines."
        let corruptedFile = CorruptedFile(url: mockRootDirectory.appendingPathComponent("file,name.epub"), reason: specialCharReason, size: 123, status: .corrupt)
        let customScanResult = ScanResult(totalFiles: 1, corruptedFiles: [corruptedFile])
        
        let csvString = try reportGenerator.generate(from: customScanResult, rootDirectory: mockRootDirectory, corruptedDirectoryName: mockCorruptedDirectoryName, repairs: [])
        
        XCTAssertTrue(csvString.contains("\"Reason with, commas\"\"quotes\"\"and\nnewlines.\""))
    }
    
    func testRepairResultsSection() throws {
        let csvString = try reportGenerator.generate(from: mockScanResult, rootDirectory: mockRootDirectory, corruptedDirectoryName: mockCorruptedDirectoryName, repairs: mockRepairs)
        
        XCTAssertTrue(csvString.contains("\nRepair Results\n"))
        XCTAssertTrue(csvString.contains("File,Success,Fixed,Message\n"))
        XCTAssertTrue(csvString.contains("\"book1.epub\",true,true,\"Fixed mimetype\"\n"))
        XCTAssertTrue(csvString.contains("\"path/to/book\"\"quotes\".pdf\",false,false,\"Could not fix PDF: reason, with \"\"quotes\"\"\"\n"))
    }
}

import Foundation

struct JSONReportGenerator: ReportGenerating {
    func generate(from result: ScanResult, rootDirectory: URL, corruptedDirectoryName: String, repairs: [EbookMechanicCore.RepairResult]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let report = Report(
            metadata: ReportMetadata(
                timestamp: Date(),
                rootDirectory: rootDirectory.path,
                corruptedDirectoryName: corruptedDirectoryName,
                elapsedTime: 0.0, // This will be calculated and passed in from the scanner
                validationLevel: "standard" // This will be passed in from the scanner
            ),
            summary: ReportSummary(
                totalFiles: result.totalFiles,
                corruptedFiles: result.corruptedFiles.count,
                breakdowns: result.breakdowns.mapValues { FormatBreakdown(total: $0.total, corrupted: $0.corrupted) },
                emptyFolders: result.emptyFolders.count
            ),
            corruptedFiles: result.corruptedFiles.map { CorruptedFile(from: $0) },
            repairs: repairs.map { RepairResultInternal(from: $0) }
        )

        let data = try encoder.encode(report)
        return String(data: data, encoding: .utf8)!
    }

    struct Report: Codable {
        let metadata: ReportMetadata
        let summary: ReportSummary
        let corruptedFiles: [CorruptedFile]
        let repairs: [RepairResultInternal]
    }

    struct ReportMetadata: Codable {
        let timestamp: Date
        let rootDirectory: String
        let corruptedDirectoryName: String
        let elapsedTime: TimeInterval
        let validationLevel: String
    }

    struct ReportSummary: Codable {
        let totalFiles: Int
        let corruptedFiles: Int
        let breakdowns: [EbookFileType: FormatBreakdown]
        let emptyFolders: Int
    }

    struct FormatBreakdown: Codable {
        let total: Int
        let corrupted: Int
    }

    struct CorruptedFile: Codable {
        let url: String
        let reason: String
        let size: Int64
        let status: ValidationStatus
        let fingerprint: FingerprintResult?
        let pdfValidationDetails: PDFValidationResult?

        init(from corruptedFile: EbookMechanicCore.CorruptedFile) {
            self.url = corruptedFile.url.path
            self.reason = corruptedFile.reason
            self.size = corruptedFile.size
            self.status = corruptedFile.status
            self.fingerprint = corruptedFile.fingerprint
            self.pdfValidationDetails = corruptedFile.pdfValidationDetails
        }
    }
    
    struct RepairResultInternal: Codable {
        let success: Bool
        let message: String
        let fixed: Bool
        let fileURL: String?
        
        init(from repairResult: EbookMechanicCore.RepairResult) {
            self.success = repairResult.success
            self.message = repairResult.message
            self.fixed = repairResult.fixed
            self.fileURL = repairResult.fileURL?.path
        }
    }
}

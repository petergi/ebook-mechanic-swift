import Foundation
import EbookMechanicCore

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
            let concurrentCount = (event.concurrentValidationCount ?? 0) > 0 ? " (\(event.concurrentValidationCount ?? 0) concurrent)" : ""
            emit("   Progress: \(event.completed)/\(event.total)\(concurrentCount)")
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
            let path = result.fileURL?.path ?? "unknown file"
            emit("  \(icon) [\(index + 1)] \(path)")
            emit("     ↳ \(result.message)")
        }
    }

    func printPerformanceMetrics(_ metrics: PerformanceMetrics) {
        emit("• Total validation time: \(String(format: "%.2f", metrics.totalValidationTime))s")
        emit("• Files per second: \(String(format: "%.2f", metrics.filesPerSecond))")
        emit("• Average validation time: \(String(format: "%.3f", metrics.averageValidationTimePerFile))s")
        emit("• Cache hit rate: \(String(format: "%.2f", metrics.cacheHitRate * 100))%")
    }

    private func emit(_ text: String) {
        sink(text)
    }

    private static func defaultSink(_ text: String) {
        print(text)
    }
}

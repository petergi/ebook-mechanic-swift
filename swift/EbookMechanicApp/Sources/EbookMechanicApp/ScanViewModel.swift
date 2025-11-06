import Foundation
import SwiftUI
import EbookMechanicCore

struct ScanOptions {
    var directory: URL
    var corruptedDirectoryName: String = "CORRUPTED"
    var repair: Bool = false
    var corruptionOnly: Bool = false
    var emptyFoldersOnly: Bool = false
    var dryRun: Bool = true
    var autoMoveCorrupted: Bool = false
    var autoDeleteEmptyFolders: Bool = false
    var generateReport: Bool = false
}

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var progressHeadline: String = ""
    @Published var progressDetail: String = ""
    @Published var corruptedFiles: [CorruptedFile] = []
    @Published var emptyFolders: [URL] = []
    @Published var summary: ScanResult?
    @Published var statusMessages: [String] = []
    @Published var reportURL: URL?
    @Published var errorMessage: String?

    func reset() {
        corruptedFiles = []
        emptyFolders = []
        summary = nil
        statusMessages.removeAll()
        reportURL = nil
        errorMessage = nil
        progressHeadline = ""
        progressDetail = ""
    }

    func runScan(options: ScanOptions) async {
        guard !isScanning else { return }
        reset()
        isScanning = true
        defer { isScanning = false }

        do {
            let scanner = FileScanner(
                rootDirectory: options.directory,
                corruptedDirectoryName: options.corruptedDirectoryName
            )

            let progressHandler: FileScanner.ProgressHandler = { [weak self] event in
                Task { @MainActor in
                    guard let self else { return }
                    switch event.stage {
                    case .validatingFile(let url):
                        self.progressHeadline = "Validating Files"
                        self.progressDetail = url.lastPathComponent
                    case .scanningFiles:
                        self.progressHeadline = "Scanning Files"
                        self.progressDetail = "\(event.completed)/\(event.total) processed"
                    case .scanningFolders:
                        self.progressHeadline = "Scanning Folders"
                        self.progressDetail = "\(event.completed)/\(event.total)"
                    case .movingCorruptedFiles:
                        self.progressHeadline = "Moving Corrupted Files"
                        self.progressDetail = event.currentItem
                    case .deletingEmptyFolders:
                        self.progressHeadline = "Deleting Empty Folders"
                        self.progressDetail = event.currentItem
                    case .repairingFiles:
                        self.progressHeadline = "Repairing Files"
                        self.progressDetail = event.currentItem
                    }
                }
            }

            var scanResult: ScanResult?
            if !options.emptyFoldersOnly {
                let result = try await scanner.scanForCorruption(progress: progressHandler)
                await MainActor.run {
                    self.summary = result
                    self.corruptedFiles = result.corruptedFiles
                    self.statusMessages.append("Scanned \(result.totalFiles) files")
                    if result.corruptedFiles.isEmpty {
                        self.statusMessages.append("No corrupted files found")
                    } else {
                        self.statusMessages.append("Detected \(result.corruptedFiles.count) corrupted file(s)")
                    }
                }
                scanResult = result

                if options.repair, let scanResult, !scanResult.corruptedFiles.isEmpty {
                    let (repairs, repairedCount) = await scanner.repairCorruptedFiles(progress: progressHandler)
                    await MainActor.run {
                        self.statusMessages.append("Repair attempts: \(repairs.count), fixed: \(repairedCount)")
                        self.corruptedFiles = repairs.enumerated().compactMap { index, result in
                            guard index < scanResult.corruptedFiles.count else { return nil }
                            var file = scanResult.corruptedFiles[index]
                            if result.fixed {
                                file = CorruptedFile(url: file.url, reason: "Fixed", size: file.size)
                            }
                            return file
                        }
                    }
                }

                if !options.dryRun, (scanResult?.corruptedFiles.isEmpty == false), options.autoMoveCorrupted {
                    try await scanner.moveCorruptedFiles(progress: progressHandler)
                    await MainActor.run {
                        self.statusMessages.append("Moved corrupted files to \(options.corruptedDirectoryName)")
                    }
                }
            }

            if !options.corruptionOnly {
                let folderResult = try await scanner.scanForEmptyFolders(progress: progressHandler)
                await MainActor.run {
                    self.emptyFolders = folderResult.emptyFolders
                    self.statusMessages.append("Discovered \(folderResult.emptyFolders.count) empty folder(s)")
                }

                if !options.dryRun, !folderResult.emptyFolders.isEmpty, options.autoDeleteEmptyFolders {
                    try await scanner.deleteEmptyFolders(progress: progressHandler)
                    await MainActor.run {
                        self.statusMessages.append("Deleted \(folderResult.emptyFolders.count) empty folder(s)")
                    }
                }
            }

            if options.generateReport {
                let url = try await scanner.generateReport(into: options.directory)
                await MainActor.run {
                    self.reportURL = url
                    self.statusMessages.append("Report generated at \(url.lastPathComponent)")
                }
            }

            await MainActor.run {
                self.progressHeadline = ""
                self.progressDetail = ""
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

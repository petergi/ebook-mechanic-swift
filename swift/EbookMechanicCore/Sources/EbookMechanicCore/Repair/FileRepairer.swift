import Foundation

/// Provides best-effort automated fixes for common ebook issues.
public struct FileRepairer: @unchecked Sendable {
    private let fileManager: FileManager
    private let validator: FileValidator

    public init(fileManager: FileManager = .default, validator: FileValidator = FileValidator()) {
        self.fileManager = fileManager
        self.validator = validator
    }

    /// Attempts to repair the file located at `url`.
    public func repair(url: URL) -> RepairResult {
        guard let type = EbookFileType(pathExtension: url.pathExtension) else {
            return RepairResult(success: false, message: "Unknown file type, cannot repair", fixed: false)
        }

        switch type {
        case .epub:
            return repairEPUB(at: url)
        case .pdf, .azw4:
            return repairPDF(at: url)
        case .mobi, .azw3:
            return repairMOBI(at: url)
        }
    }

    private func repairEPUB(at url: URL) -> RepairResult {
        let validation = validator.validate(url: url, as: .epub)
        guard !validation.isValid else {
            return RepairResult(success: true, message: "File is already valid, no repair needed", fixed: false)
        }

        let backupURL = url.appendingPathExtension("backup")
        do {
            try copyFile(from: url, to: backupURL)
        } catch {
            return RepairResult(success: false, message: "Failed to create backup: \(error.localizedDescription)", fixed: false)
        }

        do {
            var archive = try ZipArchive.load(from: url)
            var fixed = false

            let expectedMimeData = Data("application/epub+zip".utf8)
            var entries = archive.entries

            func ensureMimetypeIsFirstStored() {
                var needsInsert = true
                if let index = entries.firstIndex(where: { $0.name == "mimetype" }) {
                    if index == 0, entries[index].compressionMethod == 0, entries[index].data == expectedMimeData {
                        needsInsert = false
                    } else {
                        entries.remove(at: index)
                    }
                }

                if needsInsert {
                    entries.insert(ZipEntry(name: "mimetype", data: expectedMimeData, compressionMethod: 0), at: 0)
                    fixed = true
                }
            }

            func ensureContainerExists() {
                let normalizedName = "META-INF/container.xml"
                if let idx = entries.firstIndex(where: { $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame }) {
                    if entries[idx].name != normalizedName {
                        entries[idx].name = normalizedName
                        fixed = true
                    }
                } else {
                    entries.append(ZipEntry(name: normalizedName, data: Data(Self.defaultContainerXML.utf8), compressionMethod: 8))
                    fixed = true
                }
            }

            ensureMimetypeIsFirstStored()
            ensureContainerExists()

            archive.entries = entries

            guard fixed else {
                try? fileManager.removeItem(at: backupURL)
                return RepairResult(success: false, message: "No repairable issues found", fixed: false)
            }

            let tempURL = url.appendingPathExtension("repair.tmp")
            defer { try? fileManager.removeItem(at: tempURL) }
            try archive.write(to: tempURL)

            try fileManager.removeItem(at: url)
            try fileManager.moveItem(at: tempURL, to: url)

            if validator.validate(url: url, as: .epub).isValid {
                try? fileManager.removeItem(at: backupURL)
                return RepairResult(success: true, message: "EPUB repaired successfully", fixed: true)
            }

            try? restoreBackup(from: backupURL, to: url)
            return RepairResult(success: false, message: "Repair attempted but file still invalid", fixed: false)
        } catch {
            try? restoreBackup(from: backupURL, to: url)
            return RepairResult(success: false, message: "Failed to repair EPUB: \(error.localizedDescription)", fixed: false)
        }
    }

    private func repairPDF(at url: URL) -> RepairResult {
        let validation = validator.validate(url: url, as: .pdf)
        guard !validation.isValid else {
            return RepairResult(success: true, message: "File is already valid, no repair needed", fixed: false)
        }

        guard var data = try? Data(contentsOf: url) else {
            return RepairResult(success: false, message: "Failed to read file", fixed: false)
        }

        guard data.starts(with: Data("%PDF-".utf8)) else {
            return RepairResult(success: false, message: "Missing PDF header, cannot repair", fixed: false)
        }

        guard data.count >= 5 else {
            return RepairResult(success: false, message: "File too small to repair", fixed: false)
        }

        let tail = data.suffix(1024)
        guard String(data: tail, encoding: .ascii)?.contains("%%EOF") == false else {
            return RepairResult(success: false, message: "No repairable issues found", fixed: false)
        }

        let backupURL = url.appendingPathExtension("backup")
        do {
            try copyFile(from: url, to: backupURL)
        } catch {
            return RepairResult(success: false, message: "Failed to create backup: \(error.localizedDescription)", fixed: false)
        }

        data.append(contentsOf: Array("\n%%EOF\n".utf8))

        do {
            try data.write(to: url)
        } catch {
            try? restoreBackup(from: backupURL, to: url)
            return RepairResult(success: false, message: "Failed to write repaired file: \(error.localizedDescription)", fixed: false)
        }

        if validator.validate(url: url, as: .pdf).isValid {
            try? fileManager.removeItem(at: backupURL)
            return RepairResult(success: true, message: "PDF repaired successfully (added EOF marker)", fixed: true)
        } else {
            try? restoreBackup(from: backupURL, to: url)
            return RepairResult(success: false, message: "Adding EOF marker didn't fix the file", fixed: false)
        }
    }

    private func repairMOBI(at url: URL) -> RepairResult {
        let validation = validator.validate(url: url, as: .mobi)
        guard !validation.isValid else {
            return RepairResult(success: true, message: "File is already valid, no repair needed", fixed: false)
        }

        guard (try? Data(contentsOf: url).count) ?? 0 >= 68 else {
            return RepairResult(success: false, message: "File too small to repair", fixed: false)
        }

        return RepairResult(
            success: false,
            message: "MOBI/AZW3 format is too complex for automatic repair. Consider using Calibre's convert function.",
            fixed: false
        )
    }

    private func copyFile(from source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private func restoreBackup(from backup: URL, to original: URL) throws {
        if fileManager.fileExists(atPath: original.path) {
            try fileManager.removeItem(at: original)
        }
        try fileManager.moveItem(at: backup, to: original)
    }

    private static let defaultContainerXML = """
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""
}

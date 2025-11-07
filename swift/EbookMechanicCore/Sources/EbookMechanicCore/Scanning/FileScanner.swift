import Foundation

/// Scans directories to detect corrupted ebooks, empty folders and performs file maintenance.
public actor FileScanner {
    public typealias ProgressHandler = @Sendable (ProgressEvent) -> Void

    private let fileManager: FileManager
    private let validator: FileValidator
    private let repairer: FileRepairer

    private let rootDirectory: URL
    private let corruptedDirectoryName: String

    private(set) public var lastResult: ScanResult = ScanResult()

    public init(
        rootDirectory: URL,
        corruptedDirectoryName: String = "CORRUPTED",
        fileManager: FileManager = .default,
        validator: FileValidator = FileValidator(),
        repairer: FileRepairer? = nil
    ) {
        self.rootDirectory = rootDirectory
        self.corruptedDirectoryName = corruptedDirectoryName
        self.fileManager = fileManager
        self.validator = validator
        self.repairer = repairer ?? FileRepairer(fileManager: fileManager, validator: validator)
    }

    /// Performs a corruption scan across the root directory.
    @discardableResult
    public func scanForCorruption(progress: ProgressHandler? = nil) throws -> ScanResult {
        let enumerator = fileManager.enumerator(at: rootDirectory, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])
        guard let enumerator else {
            return lastResult
        }

        let corruptedDirURL = rootDirectory.appendingPathComponent(corruptedDirectoryName, isDirectory: true).standardizedFileURL

        var selectedFiles: [URL] = []

        for case let fileURL as URL in enumerator {
            if fileURL.standardizedFileURL.path.hasPrefix(corruptedDirURL.path) {
                enumerator.skipDescendants()
                continue
            }

            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            if EbookFileType(pathExtension: fileURL.pathExtension) != nil {
                selectedFiles.append(fileURL)
            }
        }

        var result = ScanResult(
            totalFiles: 0,
            corruptedFiles: [],
            breakdowns: Dictionary(uniqueKeysWithValues: EbookFileType.allCases.map { ($0, FormatBreakdown()) })
        )

        for (index, fileURL) in selectedFiles.enumerated() {
            let type = EbookFileType(pathExtension: fileURL.pathExtension)!

            result.totalFiles += 1
            result.breakdowns[type, default: FormatBreakdown()].total += 1

            progress?(ProgressEvent(
                stage: .validatingFile(fileURL),
                completed: index,
                total: selectedFiles.count,
                currentItem: fileURL.lastPathComponent
            ))

            let validation = validator.validate(url: fileURL, as: type)
            if !validation.isValid {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                result.corruptedFiles.append(CorruptedFile(url: fileURL, reason: validation.reason, size: size))
                var breakdown = result.breakdowns[type] ?? FormatBreakdown()
                breakdown.corrupted += 1
                result.breakdowns[type] = breakdown
            }

            progress?(ProgressEvent(
                stage: .scanningFiles,
                completed: index + 1,
                total: selectedFiles.count,
                currentItem: fileURL.lastPathComponent
            ))
        }

        lastResult = result
        return result
    }

    /// Scans for directories that do not contain any supported ebook files.
    @discardableResult
    public func scanForEmptyFolders(progress: ProgressHandler? = nil) throws -> ScanResult {
        let enumerator = fileManager.enumerator(at: rootDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        guard let enumerator else { return lastResult }

        let corruptedDirURL = rootDirectory.appendingPathComponent(corruptedDirectoryName, isDirectory: true).standardizedFileURL

        var directories: [URL] = []

        for case let url as URL in enumerator {
            if url.standardizedFileURL == rootDirectory.standardizedFileURL {
                continue
            }

            if url.standardizedFileURL.path.hasPrefix(corruptedDirURL.path) {
                enumerator.skipDescendants()
                continue
            }

            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                directories.append(url)
            }
        }

        directories.sort(by: { $0.path > $1.path })

        var result = lastResult
        result.totalFolders = directories.count
        result.emptyFolders = []
        result.foldersWithEbooks = 0

        for (index, directoryURL) in directories.enumerated() {
            let containsEbook = try directoryContainsEbookFiles(directoryURL)
            if containsEbook {
                result.foldersWithEbooks += 1
            } else {
                result.emptyFolders.append(directoryURL)
            }

            progress?(ProgressEvent(
                stage: .scanningFolders,
                completed: index + 1,
                total: directories.count,
                currentItem: directoryURL.lastPathComponent
            ))
        }

        lastResult = result
        return result
    }

    /// Moves the corrupted files recorded in `lastResult` into the dedicated corrupted directory.
    public func moveCorruptedFiles(progress: ProgressHandler? = nil) throws {
        let corruptedDirURL = rootDirectory.appendingPathComponent(corruptedDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: corruptedDirURL, withIntermediateDirectories: true, attributes: nil)

        let rootComponents = rootDirectory.resolvingSymlinksInPath().pathComponents

        for (index, corrupted) in lastResult.corruptedFiles.enumerated() {
            let fileComponents = corrupted.url.resolvingSymlinksInPath().pathComponents
            guard fileComponents.starts(with: rootComponents) else { continue }
            let relativeComponents = fileComponents.dropFirst(rootComponents.count)
            let relativePath = relativeComponents.joined(separator: "/")
            let destinationURL = corruptedDirURL.appendingPathComponent(relativePath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

            try? fileManager.removeItem(at: destinationURL)
            try fileManager.moveItem(at: corrupted.url, to: destinationURL)

            progress?(ProgressEvent(
                stage: .movingCorruptedFiles,
                completed: index + 1,
                total: lastResult.corruptedFiles.count,
                currentItem: corrupted.url.lastPathComponent
            ))
        }
    }

    /// Deletes empty folders recorded in `lastResult`.
    public func deleteEmptyFolders(progress: ProgressHandler? = nil) throws {
        for (index, folder) in lastResult.emptyFolders.enumerated() {
            try? fileManager.removeItem(at: folder)
            progress?(ProgressEvent(
                stage: .deletingEmptyFolders,
                completed: index + 1,
                total: lastResult.emptyFolders.count,
                currentItem: folder.lastPathComponent
            ))
        }
    }

    /// Normalizes EPUB files by rebuilding archives into a canonical form.
    /// - Parameters:
    ///   - force: If true, normalize all EPUBs even if they appear already normalized.
    ///   - dryRun: If true, do not write changes; only report what would be changed.
    ///   - progress: Optional progress callback for UI/CLI.
    /// - Returns: A tuple of counts (normalized, skipped).
    public func normalizeEPUBs(force: Bool = false, dryRun: Bool = true, progress: ProgressHandler? = nil) async -> (normalized: Int, skipped: Int) {
        let corruptedDirURL = rootDirectory.appendingPathComponent(corruptedDirectoryName, isDirectory: true).standardizedFileURL
        let mimetypeData = Data("application/epub+zip".utf8)
        let defaultContainerXML = """
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""

        var epubs: [URL] = []
        if let enumerator = fileManager.enumerator(at: rootDirectory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            while let next = enumerator.nextObject() as? URL {
                let fileURL = next
                if fileURL.standardizedFileURL.path.hasPrefix(corruptedDirURL.path) {
                    enumerator.skipDescendants()
                    continue
                }
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                if EbookFileType(pathExtension: fileURL.pathExtension) == .epub {
                    epubs.append(fileURL)
                }
            }
        }

        var normalized = 0
        var skipped = 0

        func isExtraneousFile(name: String) -> Bool {
            let lower = name.lowercased()
            if lower.hasPrefix("__macosx") { return true }
            if lower.contains("/._") { return true }
            if lower.contains(".ds_store") { return true }
            if lower.contains("thumbs.db") { return true }
            if lower.contains("desktop.ini") { return true }
            return false
        }

        for (index, url) in epubs.enumerated() {
            progress?(ProgressEvent(stage: .normalizingFiles, completed: index, total: epubs.count, currentItem: url.lastPathComponent))
            do {
                let archive = try ZipArchive.load(from: url)
                guard let first = archive.entries.first else {
                    skipped += 1
                    progress?(ProgressEvent(stage: .normalizingFiles, completed: index + 1, total: epubs.count, currentItem: url.lastPathComponent))
                    continue
                }
                let hasMimetypeFirst = (first.name == "mimetype")
                let mimetypeUncompressed = (first.compressionMethod == 0)
                let mimetypeCorrect = (first.data == mimetypeData)

                // Case-insensitive container.xml lookup
                let containerEntry = archive.entries.first(where: { $0.name.lowercased() == "meta-inf/container.xml" })
                let hasContainer = (containerEntry != nil)

                // All non-mimetype entries have compressionMethod == 8
                let nonMimetypeEntries = archive.entries.filter { $0.name != "mimetype" }
                let allNonMimetypeDeflate = nonMimetypeEntries.allSatisfy { $0.compressionMethod == 8 }

                // Check for extraneous files
                let hasExtraneousFiles = archive.entries.contains { isExtraneousFile(name: $0.name) }

                // Path casing check for container.xml (must be exactly "META-INF/container.xml")
                let containerCasingCorrect = containerEntry?.name == "META-INF/container.xml"

                let alreadyNormalized = hasMimetypeFirst && mimetypeUncompressed && mimetypeCorrect && hasContainer && allNonMimetypeDeflate && !hasExtraneousFiles && containerCasingCorrect

                if alreadyNormalized && !force {
                    skipped += 1
                    progress?(ProgressEvent(stage: .normalizingFiles, completed: index + 1, total: epubs.count, currentItem: url.lastPathComponent))
                    continue
                }

                // Build new entries

                // Filter out extraneous files and mimetype entry
                var filteredEntries = archive.entries.filter {
                    $0.name != "mimetype" && !isExtraneousFile(name: $0.name)
                }

                // Normalize names
                func normalizeName(_ name: String) -> String {
                    var name = name
                    if name.hasPrefix("./") {
                        name.removeFirst(2)
                    }
                    if name.lowercased() == "meta-inf/container.xml" {
                        return "META-INF/container.xml"
                    }
                    return name
                }

                // Normalize container entry and handle data
                var containerData: Data? = nil
                if let containerOriginal = filteredEntries.first(where: { $0.name.lowercased() == "meta-inf/container.xml" }) {
                    // Re-encode container.xml data for UTF-8 normalization if possible
                    if let str = String(data: containerOriginal.data, encoding: .utf8),
                       let reencoded = str.data(using: .utf8) {
                        containerData = reencoded
                    } else {
                        containerData = containerOriginal.data
                    }
                }

                // Remove old container entry from filteredEntries
                filteredEntries.removeAll(where: { $0.name.lowercased() == "meta-inf/container.xml" })

                // Synthesize container if missing
                if containerData == nil {
                    containerData = Data(defaultContainerXML.utf8)
                }

                // Compose new entries with normalized names and compression
                var newEntries: [ZipEntry] = [ZipEntry(name: "mimetype", data: mimetypeData, compressionMethod: 0)]
                // Add container.xml entry
                if let containerData = containerData {
                    newEntries.append(ZipEntry(name: "META-INF/container.xml", data: containerData, compressionMethod: 8))
                }
                // Add the rest, normalized and compressionMethod 8
                let normalizedOthers = filteredEntries.map { entry in
                    ZipEntry(name: normalizeName(entry.name), data: entry.data, compressionMethod: 8)
                }

                // Deduplicate by name (last wins)
                for entry in normalizedOthers {
                    if let existingIndex = newEntries.firstIndex(where: { $0.name == entry.name }) {
                        newEntries[existingIndex] = entry
                    } else {
                        newEntries.append(entry)
                    }
                }

                // Sort by name ascending
                newEntries.sort { $0.name < $1.name }

                let newArchive = ZipArchive(entries: newEntries)

                if dryRun {
                    normalized += 1
                } else {
                    let tempURL = url.appendingPathExtension("normalize.tmp")
                    defer { try? fileManager.removeItem(at: tempURL) }
                    try newArchive.write(to: tempURL)
                    try fileManager.removeItem(at: url)
                    try fileManager.moveItem(at: tempURL, to: url)
                    normalized += 1
                }
            } catch {
                // If we cannot read the archive, treat it as skipped for normalization purposes.
                skipped += 1
            }
            progress?(ProgressEvent(stage: .normalizingFiles, completed: index + 1, total: epubs.count, currentItem: url.lastPathComponent))
        }

        return (normalized, skipped)
    }

    /// Attempts to repair the corrupted files recorded in `lastResult`.
    public func repairCorruptedFiles(progress: ProgressHandler? = nil) async -> (results: [RepairResult], repairedCount: Int) {
        var outcomes: [RepairResult] = []
        var repairedCount = 0

        for (index, corrupted) in lastResult.corruptedFiles.enumerated() {
            progress?(ProgressEvent(
                stage: .repairingFiles,
                completed: index,
                total: lastResult.corruptedFiles.count,
                currentItem: corrupted.url.lastPathComponent
            ))

            let result = repairer.repair(url: corrupted.url)
            outcomes.append(result)
            if result.fixed {
                repairedCount += 1
            }

            progress?(ProgressEvent(
                stage: .repairingFiles,
                completed: index + 1,
                total: lastResult.corruptedFiles.count,
                currentItem: corrupted.url.lastPathComponent
            ))
        }

        return (outcomes, repairedCount)
    }

    /// Generates a Markdown report summarising the scan.
    public func generateReport(into directory: URL, fileName: String? = nil) throws -> URL {
        try MarkdownReportGenerator().generate(from: lastResult, rootDirectory: rootDirectory, corruptedDirectoryName: corruptedDirectoryName, into: directory, fileName: fileName)
    }

    private func directoryContainsEbookFiles(_ url: URL) throws -> Bool {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return false
        }

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true, EbookFileType(pathExtension: fileURL.pathExtension) != nil {
                return true
            }
        }
        return false
    }
}


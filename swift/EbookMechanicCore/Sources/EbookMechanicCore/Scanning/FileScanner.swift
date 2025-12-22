import Foundation

/// Scans directories to detect corrupted ebooks, empty folders and performs file maintenance.
public actor FileScanner {
    public typealias ProgressHandler = @Sendable (ProgressEvent) -> Void

    private let fileManager: FileManager
    private let validator: FileValidatorProtocol
    private let repairer: FileRepairer

    private let rootDirectory: URL
    private let corruptedDirectoryName: String
    private let reportFormats: [ReportFormat]
    private let maxConcurrentValidations: Int
    private let validationBatchSize: Int

    private(set) public var lastResult: ScanResult = ScanResult()
    private(set) public var lastRepairResults: [RepairResult] = []
    private(set) public var performanceMetrics = PerformanceMetrics()

    public init(
        rootDirectory: URL,
        corruptedDirectoryName: String = "CORRUPTED",
        fileManager: FileManager = .default,
        reportFormats: [ReportFormat] = [.markdown],
        maxConcurrentValidations: Int = ProcessInfo.processInfo.activeProcessorCount,
        validationBatchSize: Int? = nil,
        validator: FileValidatorProtocol,
        repairer: FileRepairer? = nil
    ) {
        self.rootDirectory = rootDirectory
        self.corruptedDirectoryName = corruptedDirectoryName
        self.fileManager = fileManager
        self.reportFormats = reportFormats
        self.maxConcurrentValidations = maxConcurrentValidations
        self.validationBatchSize = validationBatchSize ?? maxConcurrentValidations * 2
        self.validator = validator
        self.repairer = repairer ?? FileRepairer(fileManager: fileManager, validator: validator)
    }

    /// Performs a corruption scan across the root directory.
    @discardableResult
    public func scanForCorruption(progress: ProgressHandler? = nil) async throws -> ScanResult {
        let startTime = Date()
        let enumerator = fileManager.enumerator(at: rootDirectory, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])
        guard let enumerator else {
            return lastResult
        }

        let corruptedDirURL = rootDirectory.appendingPathComponent(corruptedDirectoryName, isDirectory: true).standardizedFileURL

        var selectedFiles: [URL] = []

        while let fileURL = enumerator.nextObject() as? URL {
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
            totalFiles: selectedFiles.count,
            corruptedFiles: [],
            breakdowns: Dictionary(uniqueKeysWithValues: EbookFileType.allCases.map { ($0, FormatBreakdown()) })
        )
        
        var validatedFiles: [ValidationResult] = []
        let semaphore = SimpleSemaphore(count: maxConcurrentValidations)
        var validationTimes: [EbookFileType: [TimeInterval]] = [:]
        var externalToolCalls = 0
        var cacheHits = 0


        await withThrowingTaskGroup(of: ValidationResult.self) { group in
            var filesToProcess = selectedFiles.map { (false, $0) } // (isSubmitted, fileURL)
            var submittedCount = 0
            var completedCount = 0

            // Function to submit a new task if available and within batch limit
            func submitNextTask() async {
                guard submittedCount < selectedFiles.count else { return }

                if let indexToSubmit = filesToProcess.firstIndex(where: { !$0.0 }) {
                    filesToProcess[indexToSubmit].0 = true
                    submittedCount += 1
                    
                    let fileURL = filesToProcess[indexToSubmit].1

                    group.addTask {
                        await semaphore.wait() // Wait for a slot in the concurrency limit
                        
                        let concurrentCount = await self.maxConcurrentValidations - semaphore.currentCount
                        progress?(ProgressEvent(
                            stage: .validatingFile(fileURL),
                            completed: completedCount, // Use completed count for progress
                            total: selectedFiles.count,
                            currentItem: fileURL.lastPathComponent,
                            concurrentValidationCount: concurrentCount
                        ))
                        
                        let validationStartTime = Date()
                        
                        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
                        let modDate = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                        
                        if let cachedResult = await self.validator.cache.get(forKey: ValidationCache.cacheKey(for: fileURL, size: size, modDate: modDate)) {
                            cacheHits += 1
                            semaphore.signal()
                            return cachedResult
                        }

                        let validation = await self.validator.validate(url: fileURL)
                        let validationTime = Date().timeIntervalSince(validationStartTime)

                        if self.validator.useExternalEPUBValidator || self.validator.useExternalPDFValidator {
                            externalToolCalls += 1
                        }

                        let fileType = EbookFileType(pathExtension: fileURL.pathExtension)!
                        if validationTimes[fileType] == nil {
                            validationTimes[fileType] = []
                        }
                        validationTimes[fileType]?.append(validationTime)
                        
                        semaphore.signal()
                        return validation
                    }
                }
            }

            // Initially fill the task group up to the batch size
            for _ in 0..<min(validationBatchSize, selectedFiles.count) {
                await submitNextTask()
            }
            
            // Process results as they come and submit new tasks
            do {
                for try await validation in group {
                    validatedFiles.append(validation)
                    completedCount += 1
                    
                    let concurrentCount = await self.maxConcurrentValidations - semaphore.currentCount
                    progress?(ProgressEvent(
                        stage: .scanningFiles, // Or a more specific 'validationComplete' stage
                        completed: completedCount,
                        total: selectedFiles.count,
                        currentItem: validation.url.lastPathComponent,
                        concurrentValidationCount: concurrentCount
                    ))
                    
                    await submitNextTask() // Submit a new task to keep the pipeline full
                }
            } catch {
                // Handle or propagate the error
                print("Error during validation: \(error)")
            }
        }
        
        for validation in validatedFiles {
            let type = EbookFileType(pathExtension: validation.url.pathExtension)!
            result.breakdowns[type, default: FormatBreakdown()].total += 1
            if !validation.isValid {
                result.corruptedFiles.append(CorruptedFile(url: validation.url, reason: validation.reason, size: validation.size, status: validation.status, fingerprint: validation.fingerprint, pdfValidationDetails: validation.pdfValidationDetails, epubComplianceDetails: validation.epubComplianceDetails))
                var breakdown = result.breakdowns[type] ?? FormatBreakdown()
                breakdown.corrupted += 1
                result.breakdowns[type] = breakdown
            }
        }

        let totalValidationTime = Date().timeIntervalSince(startTime)
        let totalFiles = Double(selectedFiles.count)
        
        self.performanceMetrics = PerformanceMetrics(
            filesPerSecond: totalFiles / totalValidationTime,
            totalValidationTime: totalValidationTime,
            averageValidationTimePerFile: totalValidationTime / totalFiles,
            externalToolCallCount: externalToolCalls,
            cacheHitRate: totalFiles > 0 ? Double(cacheHits) / totalFiles : 0,
            parallelEfficiencyRatio: totalFiles > 0 ? (totalValidationTime / totalFiles) / (totalValidationTime / (totalFiles * Double(maxConcurrentValidations))) : 0,
            validationTimeByFormat: validationTimes.mapValues { $0.reduce(0, +) / Double($0.count) }
        )

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

                // Filter out extraneous files and mimetype entry
                var filteredEntries = archive.entries.filter {
                    $0.name != "mimetype" && !isExtraneousFile(name: $0.name)
                }

                // Normalize container entry and handle data
                var containerData: Data? = nil
                if let containerOriginal = filteredEntries.first(where: { $0.name.lowercased() == "meta-inf/container.xml" }) {
                    if let str = String(data: containerOriginal.data, encoding: .utf8),
                       let reencoded = str.data(using: .utf8) {
                        containerData = reencoded
                    } else {
                        containerData = containerOriginal.data
                    }
                }

                filteredEntries.removeAll(where: { $0.name.lowercased() == "meta-inf/container.xml" })

                let archiveNormalizer = EPUBArchiveNormalizer(defaultContainerXML: defaultContainerXML)
                let normalization = archiveNormalizer.normalize(entries: filteredEntries, containerData: containerData)
                let normalizedEntries = normalization.entries

                // Compose new entries with canonical ordering (mimetype must remain first)
                var newEntries: [ZipEntry] = [
                    ZipEntry(name: "mimetype", data: mimetypeData, compressionMethod: 0),
                    ZipEntry(name: "META-INF/container.xml", data: normalization.containerData, compressionMethod: 8),
                ]

                let payloadEntries = normalizedEntries
                    .filter {
                        let lower = $0.name.lowercased()
                        return lower != "mimetype"
                            && lower != "meta-inf/container.xml"
                            && !lower.hasSuffix("/")
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                for entry in payloadEntries {
                    var normalizedEntry = entry
                    normalizedEntry.compressionMethod = 8
                    if let existingIndex = newEntries.firstIndex(where: { $0.name == normalizedEntry.name }) {
                        newEntries[existingIndex] = normalizedEntry
                    } else {
                        newEntries.append(normalizedEntry)
                    }
                }

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

            let result = await repairer.repair(url: corrupted.url)
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

        lastRepairResults = outcomes
        return (outcomes, repairedCount)
    }

    /// Generates a Markdown report summarising the scan.
    public func generateReport(into directory: URL) throws -> [URL] {
        var generatedReportURLs: [URL] = []
        let timestamp = ISO8601DateFormatter.threadLocalString()

        for format in reportFormats {
            let reportFileName = "ebook_mechanic_report_\(timestamp).\(format.rawValue)"
            let reportURL = directory.appendingPathComponent(reportFileName)
            
            let generator = ReportGeneratorFactory.generator(for: format)
            let reportContent = try generator.generate(from: lastResult, rootDirectory: rootDirectory, corruptedDirectoryName: corruptedDirectoryName, repairs: lastRepairResults)
            
            try reportContent.write(to: reportURL, atomically: true, encoding: .utf8)
            generatedReportURLs.append(reportURL)
        }
        return generatedReportURLs
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

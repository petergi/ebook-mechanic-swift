import Foundation

/// Validates ebook containers and reports structural issues.
public struct FileValidator: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Validates the file located at `url`, inferring the type from its extension.
    @discardableResult
    public func validate(url: URL) -> ValidationResult {
        guard let type = EbookFileType(pathExtension: url.pathExtension) else {
            return ValidationResult(isValid: true, reason: "Unknown file type")
        }
        return validate(url: url, as: type)
    }

    /// Validates a file as a specific ebook type.
    public func validate(url: URL, as type: EbookFileType) -> ValidationResult {
        switch type {
        case .epub:
            return validateEPUB(url: url)
        case .mobi:
            return validateMOBI(url: url)
        case .azw3:
            return validateAZW3(url: url)
        case .azw4:
            return validateAZW4(url: url)
        case .pdf:
            return validatePDF(url: url)
        }
    }

    private func validateEPUB(url: URL) -> ValidationResult {
        do {
            let archive = try ZipArchive.load(from: url)
            guard let mimetype = archive.entry(named: "mimetype") else {
                return ValidationResult(isValid: false, reason: "Missing mimetype file")
            }

            guard let container = archive.entry(named: "META-INF/container.xml") else {
                return ValidationResult(isValid: false, reason: "Missing META-INF/container.xml")
            }

            let mimetypeValue = String(data: mimetype.data, encoding: .utf8) ?? ""
            guard mimetypeValue == "application/epub+zip" else {
                return ValidationResult(isValid: false, reason: "Invalid mimetype: \(mimetypeValue)")
            }

            guard !container.data.isEmpty else {
                return ValidationResult(isValid: false, reason: "Missing META-INF/container.xml")
            }

            return ValidationResult(isValid: true, reason: "Valid EPUB")
        } catch {
            return ValidationResult(isValid: false, reason: "Not a valid ZIP file")
        }
    }

    private func validateMOBI(url: URL) -> ValidationResult {
        guard let handle = FileHandle(forReadingAtPath: url.path) else {
            return ValidationResult(isValid: false, reason: "Cannot open file")
        }
        defer { try? handle.close() }

        do {
            let header = try handle.read(upToCount: 68) ?? Data()
            guard header.count >= 68 else {
                return ValidationResult(isValid: false, reason: "File too small")
            }

            let identifierData = header.subdata(in: 60..<68)
            let identifier = String(data: identifierData, encoding: .ascii) ?? ""
            if !identifier.hasPrefix("BOOKMOBI") && !identifier.hasPrefix("TEXtREAd") {
                return ValidationResult(isValid: false, reason: "Invalid MOBI identifier: \(identifier)")
            }

            let palmHeader = header.subdata(in: 0..<32)
            if palmHeader.allSatisfy({ $0 == 0 }) {
                return ValidationResult(isValid: false, reason: "Invalid PalmDB header")
            }

            return ValidationResult(isValid: true, reason: "Valid MOBI")
        } catch {
            return ValidationResult(isValid: false, reason: "Cannot read file header")
        }
    }

    private func validatePDF(url: URL) -> ValidationResult {
        guard fileManager.fileExists(atPath: url.path) else {
            return ValidationResult(isValid: false, reason: "File does not exist")
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ValidationResult(isValid: false, reason: "Cannot open file")
        }
        defer { try? handle.close() }

        do {
            let header = try handle.read(upToCount: 5) ?? Data()
            guard header.count == 5, header.starts(with: Data("%PDF-".utf8)) else {
                return ValidationResult(isValid: false, reason: "Missing PDF header")
            }

            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize >= 100 else {
                return ValidationResult(isValid: false, reason: "File too small to be valid PDF")
            }

            let tailLength = min(Int64(1024), fileSize)
            try handle.seekToEnd()
            try handle.seek(toOffset: UInt64(max(0, fileSize - tailLength)))
            let tail = try handle.readToEnd() ?? Data()

            guard String(data: tail, encoding: .ascii)?.contains("%%EOF") == true else {
                return ValidationResult(isValid: false, reason: "Missing %%EOF marker")
            }

            return ValidationResult(isValid: true, reason: "Valid PDF")
        } catch {
            return ValidationResult(isValid: false, reason: "Cannot read tail")
        }
    }

    private func validateAZW3(url: URL) -> ValidationResult {
        validateMOBI(url: url)
    }

    private func validateAZW4(url: URL) -> ValidationResult {
        validatePDF(url: url)
    }
}

private extension Data {
    func allSatisfy(_ predicate: (UInt8) -> Bool) -> Bool {
        for byte in self where !predicate(byte) {
            return false
        }
        return true
    }
}

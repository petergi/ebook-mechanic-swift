import Foundation

/// Validates ebook containers and reports structural issues.
public struct FileValidator: @unchecked Sendable {
    private let fileManager: FileManager
    private let deepValidation: Bool
    private let useExternalEPUBValidator: Bool
    private let useExternalPDFValidator: Bool
    private let useExternalPDFValidator: Bool

    public init(fileManager: FileManager = .default, deepValidation: Bool = false, useExternalEPUBValidator: Bool = false, useExternalPDFValidator: Bool = false) {
        self.fileManager = fileManager
        self.deepValidation = deepValidation
        self.useExternalEPUBValidator = useExternalEPUBValidator
        self.useExternalPDFValidator = useExternalPDFValidator
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
                return ValidationResult(isValid: false, reason: "Missing mimetype file", status: .nonCompliant)
            }

            guard let container = archive.entry(named: "META-INF/container.xml") else {
                return ValidationResult(isValid: false, reason: "Missing META-INF/container.xml", status: .nonCompliant)
            }

            if let firstEntry = archive.entries.first, firstEntry.name != "mimetype" {
                return ValidationResult(isValid: false, reason: "mimetype must be first entry", status: .nonCompliant)
            }

            if let firstEntry = archive.entries.first, firstEntry.compressionMethod != 0 {
                return ValidationResult(isValid: false, reason: "mimetype must be stored uncompressed", status: .nonCompliant)
            }

            let mimetypeValue = String(data: mimetype.data, encoding: .utf8) ?? ""
            guard mimetypeValue == "application/epub+zip" else {
                return ValidationResult(isValid: false, reason: "Invalid mimetype: \(mimetypeValue)", status: .nonCompliant)
            }

            guard !container.data.isEmpty else {
                return ValidationResult(isValid: false, reason: "Missing META-INF/container.xml", status: .nonCompliant)
            }

            // Perform deep OPF validation
            let opfValidator = OPFValidator()
            let opfResult = opfValidator.validate(archive: archive, containerData: container.data)

            if !opfResult.isValid {
                let errorSummary = opfResult.errorMessages.first ?? "OPF validation failed"
                return ValidationResult(isValid: false, reason: "Invalid HTML/XHTML content: \(errorSummary)", status: .nonCompliant)
            }

            // Optionally perform deep HTML validation
            var htmlWarnings = 0
            if deepValidation {
                let htmlValidator = HTMLValidator()
                let htmlResult = htmlValidator.validate(archive: archive)
                htmlWarnings = htmlResult.warningCount

                // HTML errors are critical
                if !htmlResult.isValid {
                    let errorSummary = htmlResult.issues.first(where: { $0.severity == .error })?.message ?? "HTML validation failed"
                    return ValidationResult(isValid: false, reason: "Invalid HTML/XHTML content: \(errorSummary)", status: .nonCompliant)
                }
            }
            
            if useExternalEPUBValidator {
                let externalResult = ExternalValidators.validateEpub(at: url.path)
                if !externalResult.isValid {
                    return ValidationResult(isValid: false, reason: externalResult.reason, status: .validationError)
                }
            }

            // Include warnings as informational in the reason if needed
            let totalWarnings = opfResult.warningMessages.count + htmlWarnings
            if totalWarnings > 0 {
                return ValidationResult(isValid: true, reason: "Valid EPUB (\(totalWarnings) warning\(totalWarnings == 1 ? "" : "s"))", status: .nonCompliant)
            }

            return ValidationResult(isValid: true, reason: "Valid EPUB", status: .ok)
        } catch let zipError as ZipError {
            return ValidationResult(isValid: false, reason: "Not a valid ZIP file (\(zipError))", status: .corrupt)
        } catch {
            return ValidationResult(isValid: false, reason: "Not a valid ZIP file (\(error.localizedDescription))", status: .corrupt)
        }
    }

    private func validateMOBI(url: URL) -> ValidationResult {
        guard let handle = FileHandle(forReadingAtPath: url.path) else {
            return ValidationResult(isValid: false, reason: "Cannot open file", status: .corrupt)
        }
        defer { try? handle.close() }

        do {
            let header = try handle.read(upToCount: 68) ?? Data()
            guard header.count >= 68 else {
                return ValidationResult(isValid: false, reason: "File too small", status: .corrupt)
            }

            let identifierData = header.subdata(in: 60..<68)
            let identifier = String(data: identifierData, encoding: .ascii) ?? ""
            if !identifier.hasPrefix("BOOKMOBI") && !identifier.hasPrefix("TEXtREAd") {
                return ValidationResult(isValid: false, reason: "Invalid MOBI identifier: \(identifier)", status: .corrupt)
            }

            let palmHeader = header.subdata(in: 0..<32)
            if palmHeader.allSatisfy({ $0 == 0 }) {
                return ValidationResult(isValid: false, reason: "Invalid PalmDB header", status: .corrupt)
            }

            return ValidationResult(isValid: true, reason: "Valid MOBI", status: .ok)
        } catch {
            return ValidationResult(isValid: false, reason: "Cannot read file header", status: .corrupt)
        }
    }

    private func validatePDF(url: URL) -> ValidationResult {
        guard fileManager.fileExists(atPath: url.path) else {
            return ValidationResult(isValid: false, reason: "File does not exist", status: .corrupt)
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ValidationResult(isValid: false, reason: "Cannot open file", status: .corrupt)
        }
        defer { try? handle.close() }

        do {
            let header = try handle.read(upToCount: 5) ?? Data()
            guard header.count == 5, header.starts(with: Data("%PDF-".utf8)) else {
                return ValidationResult(isValid: false, reason: "Missing PDF header", status: .corrupt)
            }

            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize >= 100 else {
                return ValidationResult(isValid: false, reason: "File too small to be valid PDF", status: .corrupt)
            }

            let tailLength = min(Int64(1024), fileSize)
            try handle.seekToEnd()
            try handle.seek(toOffset: UInt64(max(0, fileSize - tailLength)))
            let tail = try handle.readToEnd() ?? Data()

            guard String(data: tail, encoding: .ascii)?.contains("%%EOF") == true else {
                return ValidationResult(isValid: false, reason: "Missing %%EOF marker", status: .corrupt)
            }

            if useExternalPDFValidator {
                let structureValidator = PDFStructureValidator()
                switch structureValidator.validate(url: url) {
                case .success(let pdfValidationResult):
                    // If pdfcpu says it's valid, return success with details
                    if pdfValidationResult.structureValid && pdfValidationResult.xrefValid && pdfValidationResult.pageTreeValid && pdfValidationResult.streamErrors.isEmpty {
                        return ValidationResult(isValid: true, reason: "Valid PDF (pdfcpu validation)", status: .ok, fingerprint: fp, pdfValidationDetails: pdfValidationResult)
                    } else {
                        // If pdfcpu finds issues, mark as non-compliant
                        var reasons: [String] = []
                        if !pdfValidationResult.structureValid { reasons.append("Invalid structure") }
                        if !pdfValidationResult.xrefValid { reasons.append("Invalid cross-reference table") }
                        if !pdfValidationResult.pageTreeValid { reasons.append("Invalid page tree") }
                        reasons.append(contentsOf: pdfValidationResult.streamErrors)
                        if let encryption = pdfValidationResult.encryptionInfo { reasons.append("Encrypted: \(encryption)") }
                        if let conforms = pdfValidationResult.conformsToStandard { reasons.append("Conforms to: \(conforms)") }
                        return ValidationResult(isValid: false, reason: "PDF validation issues: \(reasons.joined(separator: ", "))", status: .nonCompliant, fingerprint: fp, pdfValidationDetails: pdfValidationResult)
                    }
                case .failure(let error):
                    // If pdfcpu CLI execution fails, report as validation error
                    return ValidationResult(isValid: false, reason: "PDF validation tool error: \(error.localizedDescription)", status: .validationError, fingerprint: fp)
                }
            }
            // Compute content fingerprint (or fallback) and attach it to the validation result.
            let fp = PDFVerifier.fingerprintResult(for: url)
            switch fp {
            case .content:
                return ValidationResult(isValid: true, reason: "Valid PDF", status: .ok, fingerprint: fp)
            case .fileHash:
                return ValidationResult(isValid: true, reason: "Valid PDF (fingerprint fallback used)", status: .ok, fingerprint: fp)
            case .encrypted:
                return ValidationResult(isValid: true, reason: "Encrypted PDF - content fingerprint unavailable", status: .ok, fingerprint: fp)
            case .unavailable(let reason):
                return ValidationResult(isValid: true, reason: "Valid PDF - fingerprint unavailable: \(reason)", status: .ok, fingerprint: fp)
            }

        } catch {
            return ValidationResult(isValid: false, reason: "Cannot read tail", status: .corrupt)
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

// swiftlint:disable type_body_length cyclomatic_complexity function_body_length identifier_name opening_brace
import Foundation

/// Protocol for validating ebook containers.
public protocol FileValidatorProtocol {
  var cache: ValidationCache { get }
  func validate(url: URL) async -> ValidationResult
  func validate(url: URL, as type: EbookFileType) async -> ValidationResult
}

/// Validates ebook containers and reports structural issues.
public struct FileValidator: FileValidatorProtocol, @unchecked Sendable {
  private let fileManager: FileManager
  private let deepValidation: Bool
  public let useExternalEPUBValidator: Bool
  public let useExternalPDFValidator: Bool
  public let cache: ValidationCache

  public init(
    fileManager: FileManager = .default, deepValidation: Bool = false,
    useExternalEPUBValidator: Bool = false, useExternalPDFValidator: Bool = false,
    cacheSize: Int = 1000
  ) {
    self.fileManager = fileManager
    self.deepValidation = deepValidation
    self.useExternalEPUBValidator = useExternalEPUBValidator
    self.useExternalPDFValidator = useExternalPDFValidator
    self.cache = ValidationCache(cacheSize: cacheSize)
  }

  /// Validates the file located at `url`, inferring the type from its extension.
  @discardableResult
  public func validate(url: URL) async -> ValidationResult {
    await validate(url: url, useExternalTools: false)
  }

  /// Validates the file located at `url`, optionally using external tools.
  @discardableResult
  public func validate(url: URL, useExternalTools: Bool = false) async -> ValidationResult {
    let attributes = try? fileManager.attributesOfItem(atPath: url.path)
    let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    let modDate = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

    if let cachedResult = await cache.get(
      forKey: ValidationCache.cacheKey(for: url, size: size, modDate: modDate))
    {
      return cachedResult
    }

    guard let type = EbookFileType(pathExtension: url.pathExtension) else {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: true, reason: "Unknown file type")
    }

    let result = await validate(url: url, as: type, useExternalTools: useExternalTools)

    await cache.set(
      value: result, forKey: ValidationCache.cacheKey(for: url, size: size, modDate: modDate))

    return result
  }

  /// Validates a file as a specific ebook type.
  public func validate(url: URL, as type: EbookFileType) async -> ValidationResult {
    await validate(url: url, as: type, useExternalTools: false)
  }

  /// Validates a file as a specific ebook type, optionally using external tools.
  public func validate(
    url: URL,
    as type: EbookFileType,
    useExternalTools: Bool = false
  ) async -> ValidationResult {
    switch type {
    case .epub:
      return await validateEPUB(url: url, useExternalTools: useExternalTools)
    case .mobi:
      return validateMOBI(url: url)
    case .azw3:
      return validateAZW3(url: url)
    case .azw4:
      return await validatePDF(url: url, useExternalTools: useExternalTools)
    case .pdf:
      return await validatePDF(url: url, useExternalTools: useExternalTools)
    }
  }

  private func validateEPUB(url: URL, useExternalTools: Bool) async -> ValidationResult {
    do {
      let attributes = try fileManager.attributesOfItem(atPath: url.path)
      let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
      let validationLevel: ValidationLevel = deepValidation ? .standard : .basic

      let archive = try ZipArchive.load(from: url)
      guard let mimetype = archive.entry(named: "mimetype") else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false, reason: "Missing mimetype file",
          status: .nonCompliant, validationLevel: validationLevel)
      }

      guard let container = archive.entry(named: "META-INF/container.xml") else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "Missing META-INF/container.xml", status: .nonCompliant,
          validationLevel: validationLevel)
      }

      if let firstEntry = archive.entries.first, firstEntry.name != "mimetype" {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "mimetype must be first entry", status: .nonCompliant,
          validationLevel: validationLevel)
      }

      if let firstEntry = archive.entries.first, firstEntry.compressionMethod != 0 {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "mimetype must be stored uncompressed", status: .nonCompliant,
          validationLevel: validationLevel)
      }

      let mimetypeValue = String(data: mimetype.data, encoding: .utf8) ?? ""
      guard mimetypeValue == "application/epub+zip" else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "Invalid mimetype: \(mimetypeValue)", status: .nonCompliant,
          validationLevel: validationLevel)
      }

      guard !container.data.isEmpty else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "Missing META-INF/container.xml", status: .nonCompliant,
          validationLevel: validationLevel)
      }

      // Perform deep OPF validation
      let opfValidator = OPFValidator()
      let opfResult = opfValidator.validate(archive: archive, containerData: container.data)

      if !opfResult.isValid {
        let errorSummary = opfResult.errorMessages.first ?? "OPF validation failed"
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "Invalid HTML/XHTML content: \(errorSummary)", status: .nonCompliant,
          validationLevel: validationLevel)
      }

      // Optionally perform deep HTML validation
      var htmlWarnings = 0
      if deepValidation {
        let htmlValidator = HTMLValidator()
        let htmlResult = htmlValidator.validate(archive: archive)
        htmlWarnings = htmlResult.warningCount

        // HTML errors are critical
        if !htmlResult.isValid {
          let errorSummary =
            htmlResult.issues.first(where: { $0.severity == .error })?.message
            ?? "HTML validation failed"
          return ValidationResult(
            originalIndex: 0, url: url, size: size, isValid: false,
            reason: "Invalid HTML/XHTML content: \(errorSummary)", status: .nonCompliant,
            validationLevel: validationLevel)
        }
      }

      let shouldUseExternal = useExternalTools || useExternalEPUBValidator
      if shouldUseExternal, await ExternalEPUBValidator.isEpubcheckInstalled() {
        return await ExternalValidators.validateEpub(at: url.path)
      }

      // Include warnings as informational in the reason if needed
      let totalWarnings = opfResult.warningMessages.count + htmlWarnings
      if totalWarnings > 0 {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true,
          reason: "Valid EPUB (\(totalWarnings) warning\(totalWarnings == 1 ? "" : "s"))",
          status: .nonCompliant, validationLevel: validationLevel)
      }

      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: true, reason: "Valid EPUB", status: .ok,
        validationLevel: validationLevel)
    } catch let zipError as ZipError {
      let size =
        (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false,
        reason: "Not a valid ZIP file (\(zipError))", status: .corrupt, validationLevel: .basic)
    } catch {
      let size =
        (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false,
        reason: "Not a valid ZIP file (\(error.localizedDescription))", status: .corrupt,
        validationLevel: .basic)
    }
  }

  private func validateMOBI(url: URL) -> ValidationResult {
    let size =
      (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    guard let handle = FileHandle(forReadingAtPath: url.path) else {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false, reason: "Cannot open file",
        status: .corrupt, validationLevel: .basic)
    }
    defer { try? handle.close() }

    do {
      let header = try handle.read(upToCount: 68) ?? Data()
      guard header.count >= 68 else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false, reason: "File too small",
          status: .corrupt, validationLevel: .basic)
      }

      let identifierData = header.subdata(in: 60..<68)
      let identifier = String(data: identifierData, encoding: .ascii) ?? ""
      if !identifier.hasPrefix("BOOKMOBI") && !identifier.hasPrefix("TEXtREAd") {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "Invalid MOBI identifier: \(identifier)", status: .corrupt,
          validationLevel: .basic)
      }

      let palmHeader = header.subdata(in: 0..<32)
      if palmHeader.allSatisfy({ $0 == 0 }) {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false, reason: "Invalid PalmDB header",
          status: .corrupt, validationLevel: .basic)
      }

      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: true, reason: "Valid MOBI", status: .ok,
        validationLevel: .basic)
    } catch {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false, reason: "Cannot read file header",
        status: .corrupt, validationLevel: .basic)
    }
  }

  private func validatePDF(url: URL, useExternalTools: Bool) async -> ValidationResult {
    let size =
      (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    guard fileManager.fileExists(atPath: url.path) else {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false, reason: "File does not exist",
        status: .corrupt, validationLevel: .basic)
    }

    guard let handle = try? FileHandle(forReadingFrom: url) else {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false, reason: "Cannot open file",
        status: .corrupt, validationLevel: .basic)
    }
    defer { try? handle.close() }

    do {
      let header = try handle.read(upToCount: 5) ?? Data()
      guard header.count == 5, header.starts(with: Data("%PDF-".utf8)) else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false, reason: "Missing PDF header",
          status: .corrupt, validationLevel: .basic)
      }

      let attributes = try fileManager.attributesOfItem(atPath: url.path)
      let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
      guard fileSize >= 100 else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false,
          reason: "File too small to be valid PDF", status: .corrupt, validationLevel: .basic)
      }

      let tailLength = min(Int64(1024), fileSize)
      try handle.seekToEnd()
      try handle.seek(toOffset: UInt64(max(0, fileSize - tailLength)))
      let tail = try handle.readToEnd() ?? Data()

      guard String(data: tail, encoding: .ascii)?.contains("%%EOF") == true else {
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: false, reason: "Missing %%EOF marker",
          status: .corrupt, validationLevel: .basic)
      }

      let fp = PDFVerifier.fingerprintResult(for: url)

      let shouldUseExternal = useExternalTools || useExternalPDFValidator
      if shouldUseExternal, await ExternalPDFValidator.isPdfcpuInstalled() {
        let externalResult = await ExternalPDFValidator().validate(fileURL: url)
        return ValidationResult(
          originalIndex: 0,
          url: url,
          size: size,
          isValid: externalResult.isValid,
          reason: externalResult.reason,
          status: externalResult.status,
          validationLevel: .comprehensive,
          fingerprint: fp,
          pdfValidationDetails: externalResult.pdfValidationDetails
        )
      }

      // Compute content fingerprint (or fallback) and attach it to the validation result.
      switch fp {
      case .content:
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true, reason: "Valid PDF", status: .ok,
          validationLevel: .basic, fingerprint: fp)
      case .fileHash:
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true,
          reason: "Valid PDF (fingerprint fallback used)", status: .ok, validationLevel: .basic,
          fingerprint: fp)
      case .encrypted:
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true,
          reason: "Encrypted PDF - content fingerprint unavailable", status: .ok,
          validationLevel: .basic, fingerprint: fp)
      case .unavailable(let reason):
        return ValidationResult(
          originalIndex: 0, url: url, size: size, isValid: true,
          reason: "Valid PDF - fingerprint unavailable: \(reason)", status: .ok,
          validationLevel: .basic, fingerprint: fp)
      }

    } catch {
      return ValidationResult(
        originalIndex: 0, url: url, size: size, isValid: false, reason: "Cannot read tail",
        status: .corrupt, validationLevel: .basic)
    }
  }

  private func validateAZW3(url: URL) -> ValidationResult {
    validateMOBI(url: url)
  }

  private func validateAZW4(url: URL) async -> ValidationResult {
    await validatePDF(url: url, useExternalTools: false)
  }
}

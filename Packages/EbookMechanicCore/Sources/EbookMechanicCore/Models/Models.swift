import Foundation

/// Supported ebook formats that EbookMechanic can inspect.
///
/// Supported formats include EPUB, MOBI, AZW3/AZW4, and PDF.
public enum EbookFileType: String, CaseIterable, Codable, Hashable, Sendable {
  case epub
  case mobi
  case azw3
  case azw4
  case pdf

  /// File extension (including the leading dot) for the format.
  public var fileExtension: String {
    "." + rawValue
  }

  /// Creates a `EbookFileType` from a plain file extension.
  public init?(pathExtension: String) {
    let normalized = pathExtension.lowercased()
    switch normalized {
    case "epub": self = .epub
    case "mobi": self = .mobi
    case "azw3": self = .azw3
    case "azw4": self = .azw4
    case "pdf": self = .pdf
    default: return nil
    }
  }
}

/// Counts for a specific ebook format.
///
/// Used inside ``ScanResult`` to report totals and number of corrupted files
/// per ``EbookFileType``.
public struct FormatBreakdown: Sendable, Codable, Equatable {
  public var total: Int
  public var corrupted: Int

  public init(total: Int = 0, corrupted: Int = 0) {
    self.total = total
    self.corrupted = corrupted
  }
}

/// A file that failed validation or integrity checks.
///
/// Contains the file URL, a human-readable reason, and the file size.
public struct CorruptedFile: Sendable, Codable, Equatable {
  public var url: URL
  public var reason: String
  public var size: Int64
  public var status: ValidationStatus
  public var validationLevel: ValidationLevel
  public var fingerprint: FingerprintResult?
  public var pdfValidationDetails: PDFValidationResult?
  public var epubComplianceDetails: EPUBComplianceResult?

  public init(
    url: URL, reason: String, size: Int64, status: ValidationStatus,
    validationLevel: ValidationLevel = .basic,
    fingerprint: FingerprintResult? = nil, pdfValidationDetails: PDFValidationResult? = nil,
    epubComplianceDetails: EPUBComplianceResult? = nil
  ) {
    self.url = url
    self.reason = reason
    self.size = size
    self.status = status
    self.validationLevel = validationLevel
    self.fingerprint = fingerprint
    self.pdfValidationDetails = pdfValidationDetails
    self.epubComplianceDetails = epubComplianceDetails
  }
}

/// Aggregated results from a scan operation.
///
/// Includes file totals, per-format breakdowns, empty folders, and folder counts.
/// Use ``breakdown(for:)`` to fetch a format’s breakdown with sensible defaults.
public struct ScanResult: Sendable, Codable, Equatable {
  public var totalFiles: Int
  public var corruptedFiles: [CorruptedFile]
  public var okFiles: [ValidationResult]
  public var breakdowns: [EbookFileType: FormatBreakdown]
  public var emptyFolders: [URL]
  public var totalFolders: Int
  public var foldersWithEbooks: Int
  public var totalProcessedFiles: Int = 0  // New property
  public var totalCorruptedFiles: Int = 0  // New property
  public var totalWarnings: Int = 0  // New property
  public var totalErrors: Int = 0  // New property

  public init(
    totalFiles: Int = 0,
    corruptedFiles: [CorruptedFile] = [],
    okFiles: [ValidationResult] = [],
    breakdowns: [EbookFileType: FormatBreakdown] = [:],
    emptyFolders: [URL] = [],
    totalFolders: Int = 0,
    foldersWithEbooks: Int = 0,
    totalProcessedFiles: Int = 0,
    totalCorruptedFiles: Int = 0,
    totalWarnings: Int = 0,
    totalErrors: Int = 0
  ) {
    self.totalFiles = totalFiles
    self.corruptedFiles = corruptedFiles
    self.okFiles = okFiles
    self.breakdowns = breakdowns
    self.emptyFolders = emptyFolders
    self.totalFolders = totalFolders
    self.foldersWithEbooks = foldersWithEbooks
    self.totalProcessedFiles = totalProcessedFiles
    self.totalCorruptedFiles = totalCorruptedFiles
    self.totalWarnings = totalWarnings
    self.totalErrors = totalErrors
  }

  /// Convenience accessor for a format's breakdown, defaulting to zero counts when absent.
  public func breakdown(for type: EbookFileType) -> FormatBreakdown {
    breakdowns[type] ?? FormatBreakdown()
  }
}

/// Represents the level of validation performed.
public enum ValidationLevel: String, Codable, Sendable, CaseIterable, Equatable {
  case basic
  case standard
  case comprehensive
}

/// Outcome of validating a single file.
///
/// Indicates whether the file is valid and may include a content fingerprint
/// for supported formats.
public struct ValidationResult: Sendable, Codable, Equatable {
  public var originalIndex: Int
  public var url: URL
  public var size: Int64
  public var isValid: Bool
  public var reason: String
  public var status: ValidationStatus
  public var validationLevel: ValidationLevel
  public var fingerprint: FingerprintResult?
  public var pdfValidationDetails: PDFValidationResult?
  public var epubComplianceDetails: EPUBComplianceResult?

  public init(
    originalIndex: Int, url: URL, size: Int64, isValid: Bool, reason: String,
    status: ValidationStatus = .validationError, validationLevel: ValidationLevel = .basic,
    fingerprint: FingerprintResult? = nil, pdfValidationDetails: PDFValidationResult? = nil,
    epubComplianceDetails: EPUBComplianceResult? = nil
  ) {
    self.originalIndex = originalIndex
    self.url = url
    self.size = size
    self.isValid = isValid
    self.reason = reason
    self.status = status
    self.validationLevel = validationLevel
    self.fingerprint = fingerprint
    self.pdfValidationDetails = pdfValidationDetails
    self.epubComplianceDetails = epubComplianceDetails
  }
}

/// Represents a single validation issue found in an EPUB file.
public struct EPUBValidationIssue: Sendable, Codable, Equatable {
  public var severity: String
  public var message: String
  public var filePath: String?
  public var lineNumber: Int?
  public var ruleId: String?
  public var context: String?
}

/// Represents the detailed results of an EPUB compliance validation.
public struct EPUBComplianceResult: Sendable, Codable, Equatable {
  public var isCompliant: Bool
  public var hasWarnings: Bool
  public var errors: [EPUBValidationIssue]
  public var warnings: [EPUBValidationIssue]
  public var epubVersion: String
  public var epubcheckVersion: String
  public var features: [String]
  public var conformsToAccessibility: Bool
}

/// Represents the detailed status of a validation check.
public enum ValidationStatus: String, Codable, Sendable, CaseIterable {
  case ok  // File is valid and compliant
  case nonCompliant  // File is valid but does not meet spec (e.g., OPF issues)
  case corrupt  // File structure is unreadable or severely damaged
  case validationError  // The validation tool itself failed to run
}

/// Content fingerprinting outcomes for supported formats.
///
/// Prefer ``content(_:)`` when available; fall back to ``fileHash(_:)`` when
/// content-based signatures cannot be produced.
public enum FingerprintResult: Sendable, Equatable, Codable {
  case content(String)  // content-based fingerprint (stable across metadata changes)
  case fileHash(String)  // raw file hash fallback
  case encrypted  // file is encrypted/password-protected
  case unavailable(String)  // reason why fingerprint couldn't be computed

  public var description: String {
    switch self {
    case .content(let hash): return "Content: \(hash)"
    case .fileHash(let hash): return "File Hash: \(hash)"
    case .encrypted: return "Encrypted"
    case .unavailable(let reason): return "Unavailable: \(reason)"
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case value
  }

  private enum Kind: String, Codable {
    case content, fileHash, encrypted, unavailable
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(Kind.self, forKey: .type)
    switch kind {
    case .content:
      let v = try container.decode(String.self, forKey: .value)
      self = .content(v)
    case .fileHash:
      let v = try container.decode(String.self, forKey: .value)
      self = .fileHash(v)
    case .encrypted:
      self = .encrypted
    case .unavailable:
      let v = try container.decode(String.self, forKey: .value)
      self = .unavailable(v)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .content(let v):
      try container.encode(Kind.content, forKey: .type)
      try container.encode(v, forKey: .value)
    case .fileHash(let v):
      try container.encode(Kind.fileHash, forKey: .type)
      try container.encode(v, forKey: .value)
    case .encrypted:
      try container.encode(Kind.encrypted, forKey: .type)
    case .unavailable(let v):
      try container.encode(Kind.unavailable, forKey: .type)
      try container.encode(v, forKey: .value)
    }
  }
}

/// Progress signal emitted during lengthy operations.
///
/// Use the nested ``Stage`` to understand the current phase and map it to UI.
public struct ProgressEvent: Sendable, Equatable {
  public enum Stage: Sendable, Equatable {
    case scanningFiles
    case validatingFile(URL)
    case scanningFolders
    case movingCorruptedFiles
    case deletingEmptyFolders
    case repairingFiles
    case normalizingFiles
  }

  public var stage: Stage
  public var completed: Int
  public var total: Int
  public var currentItem: String
  public var concurrentValidationCount: Int?
  public var validationLevel: ValidationLevel?

  public init(
    stage: Stage, completed: Int, total: Int, currentItem: String,
    concurrentValidationCount: Int? = nil,
    validationLevel: ValidationLevel? = nil
  ) {
    self.stage = stage
    self.completed = completed
    self.total = total
    self.currentItem = currentItem
    self.concurrentValidationCount = concurrentValidationCount
    self.validationLevel = validationLevel
  }
}

/// Result of a repair attempt for a single file.
///
/// Indicates success, a human-readable message, and whether the file was fixed.
public struct RepairResult: Sendable, Codable, Equatable {
  public var success: Bool
  public var message: String
  public var fixed: Bool
  public var fileURL: URL?

  public init(success: Bool, message: String, fixed: Bool, fileURL: URL? = nil) {
    self.success = success
    self.message = message
    self.fixed = fixed
    self.fileURL = fileURL
  }
}

/// Supported formats for generated reports.
public enum ReportFormat: String, CaseIterable, Codable, Hashable, Sendable {
  case markdown
  case json
  case csv
  case html
}

/// Represents detailed results of a PDF structure validation.
public struct PDFValidationResult: Sendable, Codable, Equatable {
  public var structureValid: Bool
  public var xrefValid: Bool
  public var pageTreeValid: Bool
  public var streamErrors: [String]
  public var encryptionInfo: String?
  public var conformsToStandard: String?

  // Manually implement init(from:) and encode(to:) to handle missing/optional fields gracefully
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    structureValid = try container.decode(Bool.self, forKey: .structureValid)
    xrefValid = try container.decode(Bool.self, forKey: .xrefValid)
    pageTreeValid = try container.decode(Bool.self, forKey: .pageTreeValid)
    streamErrors = try container.decodeIfPresent([String].self, forKey: .streamErrors) ?? []
    encryptionInfo = try container.decodeIfPresent(String.self, forKey: .encryptionInfo)
    conformsToStandard = try container.decodeIfPresent(String.self, forKey: .conformsToStandard)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(structureValid, forKey: .structureValid)
    try container.encode(xrefValid, forKey: .xrefValid)
    try container.encode(pageTreeValid, forKey: .pageTreeValid)
    try container.encode(streamErrors, forKey: .streamErrors)
    try container.encodeIfPresent(encryptionInfo, forKey: .encryptionInfo)
    try container.encodeIfPresent(conformsToStandard, forKey: .conformsToStandard)
  }

  enum CodingKeys: String, CodingKey {
    case structureValid
    case xrefValid
    case pageTreeValid
    case streamErrors
    case encryptionInfo
    case conformsToStandard
  }

  public init(
    structureValid: Bool, xrefValid: Bool, pageTreeValid: Bool, streamErrors: [String],
    encryptionInfo: String?, conformsToStandard: String?
  ) {
    self.structureValid = structureValid
    self.xrefValid = xrefValid
    self.pageTreeValid = pageTreeValid
    self.streamErrors = streamErrors
    self.encryptionInfo = encryptionInfo
    self.conformsToStandard = conformsToStandard
  }
}

extension ISO8601DateFormatter {
  public static func threadLocalString() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime,
    ]
    return formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
  }
}

extension String {
  public func htmlEscaped() -> String {
    var result = self
    result = result.replacingOccurrences(of: "&", with: "&amp;")
    result = result.replacingOccurrences(of: "<", with: "&lt;")
    result = result.replacingOccurrences(of: ">", with: "&gt;")
    result = result.replacingOccurrences(of: "\"", with: "&quot;")
    result = result.replacingOccurrences(of: "'", with: "&#039;")
    return result
  }
}

/// Struct to hold performance metrics from a scan.
public struct PerformanceMetrics: Sendable, Codable, Equatable {
  public var filesPerSecond: Double = 0.0
  public var totalValidationTime: TimeInterval = 0.0
  public var averageValidationTimePerFile: TimeInterval = 0.0
  public var externalToolCallCount: Int = 0
  public var cacheHitRate: Double = 0.0
  public var parallelEfficiencyRatio: Double = 0.0
  public var validationTimeByFormat: [EbookFileType: TimeInterval] = [:]
}

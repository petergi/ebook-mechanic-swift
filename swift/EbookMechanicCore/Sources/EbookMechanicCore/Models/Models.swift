import Foundation

/// Supported ebook formats that EbookMechanic can inspect.
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

/// Summary statistics for a specific ebook format.
public struct FormatBreakdown: Sendable, Codable, Equatable {
    public var total: Int
    public var corrupted: Int

    public init(total: Int = 0, corrupted: Int = 0) {
        self.total = total
        self.corrupted = corrupted
    }
}

/// Represents a corrupt ebook discovered during a scan.
public struct CorruptedFile: Sendable, Codable, Equatable {
    public var url: URL
    public var reason: String
    public var size: Int64

    public init(url: URL, reason: String, size: Int64) {
        self.url = url
        self.reason = reason
        self.size = size
    }
}

/// Contains the aggregated results of a full scan operation.
public struct ScanResult: Sendable, Codable, Equatable {
    public var totalFiles: Int
    public var corruptedFiles: [CorruptedFile]
    public var breakdowns: [EbookFileType: FormatBreakdown]
    public var emptyFolders: [URL]
    public var totalFolders: Int
    public var foldersWithEbooks: Int

    public init(
        totalFiles: Int = 0,
        corruptedFiles: [CorruptedFile] = [],
        breakdowns: [EbookFileType: FormatBreakdown] = [:],
        emptyFolders: [URL] = [],
        totalFolders: Int = 0,
        foldersWithEbooks: Int = 0
    ) {
        self.totalFiles = totalFiles
        self.corruptedFiles = corruptedFiles
        self.breakdowns = breakdowns
        self.emptyFolders = emptyFolders
        self.totalFolders = totalFolders
        self.foldersWithEbooks = foldersWithEbooks
    }

    /// Convenience accessor for a format's breakdown, defaulting to zero counts when absent.
    public func breakdown(for type: EbookFileType) -> FormatBreakdown {
        breakdowns[type] ?? FormatBreakdown()
    }
}

/// Result describing whether a file passed validation along with a human readable reason.
public struct ValidationResult: Sendable, Codable, Equatable {
    public var isValid: Bool
    public var reason: String
    /// Optional fingerprint result for formats where a content fingerprint can be computed (PDF).
    public var fingerprint: FingerprintResult?

    public init(isValid: Bool, reason: String, fingerprint: FingerprintResult? = nil) {
        self.isValid = isValid
        self.reason = reason
        self.fingerprint = fingerprint
    }
}

/// Represents the outcome of attempting to compute a content-based fingerprint for a file.
public enum FingerprintResult: Sendable, Equatable, Codable {
    case content(String)   // content-based fingerprint (stable across metadata changes)
    case fileHash(String)  // raw file hash fallback
    case encrypted         // file is encrypted/password-protected
    case unavailable(String) // reason why fingerprint couldn't be computed

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

/// Lightweight event emitted during lengthy operations.
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

    public init(stage: Stage, completed: Int, total: Int, currentItem: String) {
        self.stage = stage
        self.completed = completed
        self.total = total
        self.currentItem = currentItem
    }
}

/// Outcome of an attempted repair.
public struct RepairResult: Sendable, Codable, Equatable {
    public var success: Bool
    public var message: String
    public var fixed: Bool

    public init(success: Bool, message: String, fixed: Bool) {
        self.success = success
        self.message = message
        self.fixed = fixed
    }
}

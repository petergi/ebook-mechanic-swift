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

    public init(isValid: Bool, reason: String) {
        self.isValid = isValid
        self.reason = reason
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

/// Lightweight event emitted during lengthy operations.
public struct ProgressEvent: Sendable, Equatable {
    public enum Stage: Sendable, Equatable {
        case scanningFiles
        case validatingFile(URL)
        case scanningFolders
        case movingCorruptedFiles
        case deletingEmptyFolders
        case repairingFiles
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

import Foundation

/// An actor that manages the distribution of validation tasks.
public actor ValidationQueue {
    public enum Priority: Int, Comparable {
        case high = 0
        case low = 1

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    private var queue: [EbookFileType: [(url: URL, priority: Priority)]] = [:]
    private var previouslyCorrupted: Set<URL> = []
    private var fileTypeRotation: [EbookFileType] = EbookFileType.allCases

    public func setPreviouslyCorrupted(urls: [URL]) {
        self.previouslyCorrupted = Set(urls)
    }

    public func addTask(url: URL) {
        guard let fileType = EbookFileType(pathExtension: url.pathExtension) else {
            return
        }

        let priority: Priority = previouslyCorrupted.contains(url) ? .low : .high
        
        if queue[fileType] == nil {
            queue[fileType] = []
        }
        
        queue[fileType]?.append((url, priority))
        queue[fileType]?.sort { $0.priority < $1.priority }
    }

    public func next() -> URL? {
        for fileType in fileTypeRotation {
            if let url = next(for: fileType) {
                // Rotate file types to ensure fairness
                fileTypeRotation.append(fileTypeRotation.removeFirst())
                return url
            }
        }
        return nil
    }

    private func next(for fileType: EbookFileType) -> URL? {
        guard var fileTypeQueue = queue[fileType], !fileTypeQueue.isEmpty else {
            return nil
        }
        
        let url = fileTypeQueue.removeFirst().url
        queue[fileType] = fileTypeQueue
        
        return url
    }
}

import Foundation

/// Actor responsible for managing a queue of validation tasks,
/// applying priority, and handling rate limiting for external tool calls.
public actor ValidationQueue {
    
    public enum Priority: Comparable {
        case high       // e.g., files not previously scanned or known good
        case normal     // default priority
        case low        // e.g., files known to be corrupt or problematic from previous scans
    }

    /// Represents a task to be validated.
    public struct ValidationTask: Identifiable, Comparable {
        public let id = UUID()
        public let url: URL
        public let priority: Priority
        public let type: EbookFileType // For fair distribution
        
        public init(url: URL, priority: Priority = .normal, type: EbookFileType) {
            self.url = url
            self.priority = priority
            self.type = type
        }

        public static func < (lhs: ValidationTask, rhs: ValidationTask) -> Bool {
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority // Higher priority comes first
            }
            return lhs.url.lastPathComponent < rhs.url.lastPathComponent // Stable sort
        }
    }

    public var queue: [ValidationTask] = []
    private let maxConcurrentExternalToolCalls: Int
    private var currentExternalToolCalls: Int = 0
    private var externalToolCallSemaphore: AsyncSemaphore

    public init(maxConcurrentExternalToolCalls: Int = 4) {
        self.maxConcurrentExternalToolCalls = maxConcurrentExternalToolCalls
        self.externalToolCallSemaphore = AsyncSemaphore(value: maxConcurrentExternalToolCalls)
    }

    /// Adds a validation task to the queue.
    public func addTask(_ task: ValidationTask) {
        queue.append(task)
        queue.sort() // Maintain sorted priority queue
    }

    /// Retrieves the next highest priority task from the queue.
    public func nextTask() -> ValidationTask? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }
    
    /// Acquires a slot for an external tool call.
    public func acquireExternalToolSlot() async {
        await externalToolCallSemaphore.wait()
        currentExternalToolCalls += 1
    }
    
    /// Releases a slot for an external tool call.
    public func releaseExternalToolSlot() async {
        currentExternalToolCalls -= 1
        await externalToolCallSemaphore.signal()
    }
    
    /// Current number of tasks in the queue.
    public var count: Int {
        queue.count
    }
}


/// A simple asynchronous semaphore for controlling concurrent access.
fileprivate actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.count = value
    }

    func wait() async {
        if count > 0 {
            count -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func signal() {
        if let continuation = waiters.first {
            waiters.removeFirst()
            continuation.resume()
        } else {
            count += 1
        }
    }
}
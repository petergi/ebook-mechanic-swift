import Foundation

public actor SimpleSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public var currentCount: Int {
        return count
    }

    public init(count: Int) {
        self.count = count
    }

    public func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    public nonisolated func signal() {
        Task {
            await self.doSignal()
        }
    }

    private func doSignal() {
        if waiters.isEmpty {
            count += 1
        } else {
            let continuation = waiters.removeFirst()
            continuation.resume()
        }
    }
}

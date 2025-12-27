import Foundation

actor ExternalToolRunner {
    private let semaphore: SimpleSemaphore
    private let maxConcurrentExternalTools: Int
    
    internal var maxConcurrentExecutions = 0
    private var concurrentExecutions = 0
    private let executionLock = NSLock()

    init(maxConcurrentExternalTools: Int = 4) {
        self.maxConcurrentExternalTools = maxConcurrentExternalTools
        self.semaphore = SimpleSemaphore(count: maxConcurrentExternalTools)
    }

    func runTool(executableURL: URL, arguments: [String]) async throws -> (Int32, String) {
        await semaphore.wait()
        defer { semaphore.signal() }

        executionLock.lock()
        concurrentExecutions += 1
        maxConcurrentExecutions = max(maxConcurrentExecutions, concurrentExecutions)
        executionLock.unlock()

        defer {
            executionLock.lock()
            concurrentExecutions -= 1
            executionLock.unlock()
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, output))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

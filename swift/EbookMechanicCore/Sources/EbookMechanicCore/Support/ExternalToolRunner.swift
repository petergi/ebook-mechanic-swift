import Foundation

actor ExecutionLock {
    private(set) var concurrentExecutions = 0
    private(set) var maxConcurrentExecutions = 0
    
    func increment() {
        concurrentExecutions += 1
        maxConcurrentExecutions = max(maxConcurrentExecutions, concurrentExecutions)
    }
    
    func decrement() {
        concurrentExecutions -= 1
    }
}

actor ExternalToolRunner {
    private let semaphore: SimpleSemaphore
    private let maxConcurrentExternalTools: Int
    private let executionLock = ExecutionLock()

    init(maxConcurrentExternalTools: Int = 4) {
        self.maxConcurrentExternalTools = maxConcurrentExternalTools
        self.semaphore = SimpleSemaphore(count: maxConcurrentExternalTools)
    }

    func run(executableURL: URL, arguments: [String]) async throws -> (Int32, String, String) {
        await semaphore.wait()
        defer { semaphore.signal() }

        await executionLock.increment()

        defer {
            Task {
                await executionLock.decrement()
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, stdout, stderr))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public static func isCommandAvailable(_ command: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

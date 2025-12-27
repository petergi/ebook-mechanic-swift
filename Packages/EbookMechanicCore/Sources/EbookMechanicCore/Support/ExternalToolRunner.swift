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
  enum ExternalToolRunnerError: Error, LocalizedError {
    case toolNotFound(String)
    case executionFailed(String, Int32, String)
    case timeout(String)

    var errorDescription: String? {
      switch self {
      case .toolNotFound(let name):
        return "Tool not found: \(name)"
      case .executionFailed(let name, let code, let stderr):
        return "Tool \(name) exited with code \(code). \(stderr)"
      case .timeout(let name):
        return "Tool timed out: \(name)"
      }
    }
  }

  private let semaphore: SimpleSemaphore
  private let maxConcurrentExternalTools: Int
  private let executionLock = ExecutionLock()

  init(maxConcurrentExternalTools: Int = 4) {
    self.maxConcurrentExternalTools = maxConcurrentExternalTools
    self.semaphore = SimpleSemaphore(count: maxConcurrentExternalTools)
  }

  func run(
    executableURL: URL,
    arguments: [String],
    timeout: TimeInterval? = nil,
    toolName: String? = nil
  ) async throws -> (Int32, String, String) {
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

      let lock = NSLock()
      var didResume = false

      let timeoutWorkItem: DispatchWorkItem? = timeout.map { timeout in
        let item = DispatchWorkItem {
          lock.lock()
          if didResume {
            lock.unlock()
            return
          }
          didResume = true
          lock.unlock()

          if process.isRunning {
            process.terminate()
          }
          let name = toolName ?? executableURL.lastPathComponent
          continuation.resume(throwing: ExternalToolRunnerError.timeout(name))
        }
        DispatchQueue.global(qos: .userInitiated)
          .asyncAfter(deadline: .now() + timeout, execute: item)
        return item
      }

      process.terminationHandler = { process in
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        lock.lock()
        if didResume {
          lock.unlock()
          return
        }
        didResume = true
        lock.unlock()

        timeoutWorkItem?.cancel()
        continuation.resume(returning: (process.terminationStatus, stdout, stderr))
      }

      do {
        try process.run()
      } catch {
        timeoutWorkItem?.cancel()
        continuation.resume(throwing: error)
      }
    }
  }

  func peakConcurrentExecutions() async -> Int {
    await executionLock.maxConcurrentExecutions
  }

  public static func resolvedExecutableURL(
    for toolName: String,
    additionalSearchPaths: [String] = []
  ) -> URL? {
    var searchPaths = additionalSearchPaths
    if let pathValue = ProcessInfo.processInfo.environment["PATH"] {
      searchPaths.append(contentsOf: pathValue.split(separator: ":").map(String.init))
    }
    searchPaths.append(contentsOf: ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin"])

    var seen = Set<String>()
    for path in searchPaths {
      guard seen.insert(path).inserted else { continue }
      let candidate = URL(fileURLWithPath: path).appendingPathComponent(toolName)
      if FileManager.default.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
    }
    return nil
  }

  public static func isCommandAvailable(_ command: String) async -> Bool {
    resolvedExecutableURL(for: command) != nil
  }

  public static func run(
    toolName: String,
    arguments: [String],
    timeout: TimeInterval? = nil
  ) async throws -> (String, String, Int32) {
    guard let executableURL = resolvedExecutableURL(for: toolName) else {
      throw ExternalToolRunnerError.toolNotFound(toolName)
    }

    let runner = ExternalToolRunner()
    let (exitCode, stdout, stderr) = try await runner.run(
      executableURL: executableURL,
      arguments: arguments,
      timeout: timeout,
      toolName: toolName
    )

    if exitCode != 0 {
      let details = stderr.isEmpty ? stdout : stderr
      throw ExternalToolRunnerError.executionFailed(toolName, exitCode, details)
    }

    return (stdout, stderr, exitCode)
  }
}

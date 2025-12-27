import XCTest

@testable import EbookMechanicCore

private class MockFileValidator: FileValidatorProtocol {
  let validationTime: TimeInterval
  let cache: ValidationCache = ValidationCache(cacheSize: 10)

  init(validationTime: TimeInterval) {
    self.validationTime = validationTime
  }

  func validate(url: URL) async -> ValidationResult {
    try? await Task.sleep(nanoseconds: UInt64(validationTime * 1_000_000_000))
    return ValidationResult(
      originalIndex: 0, url: url, size: 0, isValid: true, reason: "Mocked validation")
  }

  func validate(url: URL, as type: EbookFileType) async -> ValidationResult {
    try? await Task.sleep(nanoseconds: UInt64(validationTime * 1_000_000_000))
    return ValidationResult(
      originalIndex: 0, url: url, size: 0, isValid: true, reason: "Mocked validation")
  }
}

final class ParallelValidationTests: XCTestCase {

  private var testDirectory: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    testDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      UUID().uuidString)
    try FileManager.default.createDirectory(
      at: testDirectory, withIntermediateDirectories: true, attributes: nil)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: testDirectory)
    try super.tearDownWithError()
  }

  func testParallelExecution() async throws {
    let fileCount = 20
    let validationTime: TimeInterval = 0.1

    for i in 0..<fileCount {
      let fileURL = testDirectory.appendingPathComponent("file\(i).epub")
      FileManager.default.createFile(
        atPath: fileURL.path, contents: Data("test".utf8), attributes: nil)
    }

    let validator = MockFileValidator(validationTime: validationTime)
    let scanner = FileScanner(
      rootDirectory: testDirectory, maxConcurrentValidations: 4, validator: validator)

    let expectation = XCTestExpectation(description: "Scanning finished")

    let startTime = Date()

    Task {
      _ = try await scanner.scanForCorruption()
      let duration = Date().timeIntervalSince(startTime)

      // With 4 concurrent validations, 20 files taking 0.1s each should take roughly 20/4 * 0.1 = 0.5s
      // Adding some buffer for overhead.
      XCTAssertLessThan(duration, 1.0)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testProgressEventAccuracy() async throws {
    let fileCount = 10
    let validationTime: TimeInterval = 0.1
    let maxConcurrentValidations = 2

    for i in 0..<fileCount {
      let fileURL = testDirectory.appendingPathComponent("file\(i).epub")
      FileManager.default.createFile(
        atPath: fileURL.path, contents: Data("test".utf8), attributes: nil)
    }

    let validator = MockFileValidator(validationTime: validationTime)
    let scanner = FileScanner(
      rootDirectory: testDirectory, maxConcurrentValidations: maxConcurrentValidations,
      validator: validator)

    let expectation = XCTestExpectation(description: "Scanning finished")

    var progressEvents: [ProgressEvent] = []
    let progressHandler: FileScanner.ProgressHandler = { event in
      progressEvents.append(event)
    }

    Task {
      _ = try await scanner.scanForCorruption(progress: progressHandler)

      var lastCompletedCount = 0
      for event in progressEvents {
        if case .scanningFiles = event.stage {
          XCTAssertGreaterThanOrEqual(event.completed, lastCompletedCount)
          lastCompletedCount = event.completed
        }
        if let concurrentCount = event.concurrentValidationCount {
          XCTAssertLessThanOrEqual(concurrentCount, maxConcurrentValidations)
        }
      }

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testCacheCorrectness() async throws {
    let fileCount = 10
    let validationTime: TimeInterval = 0.1

    for i in 0..<fileCount {
      let fileURL = testDirectory.appendingPathComponent("file\(i).epub")
      FileManager.default.createFile(
        atPath: fileURL.path, contents: Data("test".utf8), attributes: nil)
    }

    let validator = MockFileValidator(validationTime: validationTime)
    let scanner = FileScanner(
      rootDirectory: testDirectory, maxConcurrentValidations: 4, validator: validator)

    let expectation1 = XCTestExpectation(description: "First scan finished")

    let startTime1 = Date()

    Task {
      _ = try await scanner.scanForCorruption()
      let duration1 = Date().timeIntervalSince(startTime1)
      XCTAssertGreaterThan(duration1, validationTime * Double(fileCount) / 4.0)
      expectation1.fulfill()
    }

    wait(for: [expectation1], timeout: 2.0)

    let expectation2 = XCTestExpectation(description: "Second scan finished")

    let startTime2 = Date()

    Task {
      _ = try await scanner.scanForCorruption()
      let duration2 = Date().timeIntervalSince(startTime2)
      XCTAssertLessThan(duration2, validationTime)
      expectation2.fulfill()
    }

    wait(for: [expectation2], timeout: 1.0)

    // Modify a file and check that the cache is invalidated
    let fileURL = testDirectory.appendingPathComponent("file0.epub")
    try "modified".data(using: .utf8)?.write(to: fileURL)

    let expectation3 = XCTestExpectation(description: "Third scan finished")

    let startTime3 = Date()

    Task {
      _ = try await scanner.scanForCorruption()
      let duration3 = Date().timeIntervalSince(startTime3)
      XCTAssertGreaterThan(duration3, validationTime)
      expectation3.fulfill()
    }

    wait(for: [expectation3], timeout: 2.0)
  }

  func testExternalToolRateLimiting() async throws {
    let toolRunner = ExternalToolRunner(maxConcurrentExternalTools: 2)

    let expectation = XCTestExpectation(description: "Tool running finished")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      Task {
        _ = try await toolRunner.runTool(
          executableURL: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
        expectation.fulfill()
      }
    }

    await fulfillment(of: [expectation], timeout: 2.0)

    let maxConcurrentExecutions = await toolRunner.maxConcurrentExecutions
    XCTAssertLessThanOrEqual(maxConcurrentExecutions, 2)
  }
}

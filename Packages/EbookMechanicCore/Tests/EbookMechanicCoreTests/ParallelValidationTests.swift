import XCTest
@testable import EbookMechanicCore

private actor ProgressCollector {
    private var events: [ProgressEvent] = []

    func append(_ event: ProgressEvent) {
        events.append(event)
    }

    func all() -> [ProgressEvent] {
        events
    }
}

final class ParallelValidationTests: XCTestCase {
    private var testDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: testDirectory)
        try super.tearDownWithError()
    }

    func testParallelExecution() async throws {
        let fileCount = 20

        for index in 0..<fileCount {
            let fileURL = testDirectory.appendingPathComponent("file\(index).epub")
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: Data("test".utf8),
                attributes: nil
            )
        }

        let validator = FileValidator()
        let scanner = FileScanner(
            rootDirectory: testDirectory,
            maxConcurrentValidations: 4,
            validator: validator
        )
        let result = try await scanner.scanForCorruption()
        XCTAssertEqual(result.totalFiles, fileCount)
        XCTAssertEqual(result.corruptedFiles.count, fileCount)
    }

    func testProgressEventAccuracy() async throws {
        let fileCount = 10
        let maxConcurrentValidations = 2

        for index in 0..<fileCount {
            let fileURL = testDirectory.appendingPathComponent("file\(index).epub")
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: Data("test".utf8),
                attributes: nil
            )
        }

        let validator = FileValidator()
        let scanner = FileScanner(
            rootDirectory: testDirectory,
            maxConcurrentValidations: maxConcurrentValidations,
            validator: validator
        )

        let collector = ProgressCollector()
        let progressHandler: FileScanner.ProgressHandler = { event in
            Task {
                await collector.append(event)
            }
        }

        _ = try await scanner.scanForCorruption(progress: progressHandler)

        let progressEvents = await collector.all()
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
    }

    func testCacheCorrectness() async throws {
        let fileCount = 10

        for index in 0..<fileCount {
            let fileURL = testDirectory.appendingPathComponent("file\(index).epub")
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: Data("test".utf8),
                attributes: nil
            )
        }

        let validator = FileValidator()
        let scanner = FileScanner(
            rootDirectory: testDirectory,
            maxConcurrentValidations: 4,
            validator: validator
        )
        _ = try await scanner.scanForCorruption()
        let firstMetrics = await scanner.performanceMetrics
        XCTAssertEqual(firstMetrics.cacheHitRate, 0)

        _ = try await scanner.scanForCorruption()
        let secondMetrics = await scanner.performanceMetrics
        XCTAssertGreaterThan(secondMetrics.cacheHitRate, 0)

        let fileURL = testDirectory.appendingPathComponent("file0.epub")
        try Data("modified".utf8).write(to: fileURL)

        _ = try await scanner.scanForCorruption()
        let thirdMetrics = await scanner.performanceMetrics
        XCTAssertLessThan(thirdMetrics.cacheHitRate, 1.0)
    }

    func testExternalToolRateLimiting() async throws {
        let toolRunner = ExternalToolRunner(maxConcurrentExternalTools: 2)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    _ = try? await toolRunner.run(
                        executableURL: URL(fileURLWithPath: "/bin/sleep"),
                        arguments: ["0.1"]
                    )
                }
            }
        }

        let peakConcurrentExecutions = await toolRunner.peakConcurrentExecutions()
        XCTAssertLessThanOrEqual(peakConcurrentExecutions, 2)
    }
}

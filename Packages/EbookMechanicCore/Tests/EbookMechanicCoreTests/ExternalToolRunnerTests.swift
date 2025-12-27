import XCTest
import Foundation
@testable import EbookMechanicCore

final class ExternalToolRunnerTests: XCTestCase {

    // Helper to create a dummy executable in a temporary directory
    private func createDummyExecutable(
        named toolName: String,
        in tempDir: URL,
        exitCode: Int,
        stdout: String = "",
        stderr: String = "",
        delay: TimeInterval = 0
    ) throws -> URL {
        let scriptContent = """
        #!/bin/bash
        sleep \(delay)
        echo "\(stdout)"
        echo "\(stderr)" >&2
        exit \(exitCode)
        """
        let scriptURL = tempDir.appendingPathComponent(toolName)
        try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

        let fileManager = FileManager.default
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        return scriptURL
    }

    func testSuccessfulExecution() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let expectedStdout = "Hello from stdout"
        let expectedStderr = "Hello from stderr"
        let toolName = "testtool_success"
        _ = try createDummyExecutable(
            named: toolName,
            in: tempDir,
            exitCode: 0,
            stdout: expectedStdout,
            stderr: expectedStderr
        )

        let oldPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        setenv("PATH", (tempDir.path + ":" + oldPath).cString(using: .utf8), 1)
        defer { setenv("PATH", oldPath.cString(using: .utf8), 1) }

        let toolRunner = ExternalToolRunner()
        let (exitCode, stdout, stderr) = try await toolRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [toolName]
        )

        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(stdout.trimmingCharacters(in: .whitespacesAndNewlines), expectedStdout)
        XCTAssertEqual(stderr.trimmingCharacters(in: .whitespacesAndNewlines), expectedStderr)
    }

    func testNonZeroExitCode() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let expectedStdout = "Operation failed"
        let expectedStderr = "Error details here"
        let expectedExitCode: Int32 = 1
        let toolName = "testtool_fail"
        _ = try createDummyExecutable(
            named: toolName,
            in: tempDir,
            exitCode: Int(expectedExitCode),
            stdout: expectedStdout,
            stderr: expectedStderr
        )

        let oldPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        setenv("PATH", (tempDir.path + ":" + oldPath).cString(using: .utf8), 1)
        defer { setenv("PATH", oldPath.cString(using: .utf8), 1) }

        let toolRunner = ExternalToolRunner()
        let (exitCode, stdout, stderr) = try await toolRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [toolName]
        )

        XCTAssertEqual(exitCode, expectedExitCode)
        XCTAssertEqual(stdout.trimmingCharacters(in: .whitespacesAndNewlines), expectedStdout)
        XCTAssertEqual(stderr.trimmingCharacters(in: .whitespacesAndNewlines), expectedStderr)
    }

    func testToolNotFound() async throws {
        let nonExistentTool = "nonexistent_tool_\(UUID().uuidString)"
        let toolRunner = ExternalToolRunner()
        let (exitCode, stdout, stderr) = try await toolRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [nonExistentTool]
        )

        XCTAssertNotEqual(exitCode, 0)
        XCTAssertTrue(stdout.isEmpty)
        XCTAssertFalse(stderr.isEmpty)
    }

    func testTimeout() async throws {
        let toolRunner = ExternalToolRunner()
        let start = Date()
        let (exitCode, _, _) = try await toolRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["1"]
        )
        let duration = Date().timeIntervalSince(start)
        XCTAssertEqual(exitCode, 0)
        XCTAssertGreaterThanOrEqual(duration, 1.0)
    }

    func testIsCommandAvailable() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let toolName = "available_tool"
        _ = try createDummyExecutable(named: toolName, in: tempDir, exitCode: 0)

        let oldPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        setenv("PATH", (tempDir.path + ":" + oldPath).cString(using: .utf8), 1)
        defer { setenv("PATH", oldPath.cString(using: .utf8), 1) }

        let isAvailable = await ExternalToolRunner.isCommandAvailable(toolName)
        XCTAssertTrue(isAvailable, "Command should be available")
        let missing = await ExternalToolRunner.isCommandAvailable("definitely_not_available_\(UUID().uuidString)")
        XCTAssertFalse(missing, "Command should not be available")
    }
}

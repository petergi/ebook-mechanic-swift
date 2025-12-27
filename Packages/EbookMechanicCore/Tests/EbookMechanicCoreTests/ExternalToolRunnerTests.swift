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

        let (stdout, stderr, exitCode) = try await ExternalToolRunner.run(
            toolName: toolName,
            arguments: []
        )

        XCTAssertEqual(stdout.trimmingCharacters(in: .whitespacesAndNewlines), expectedStdout)
        XCTAssertEqual(stderr.trimmingCharacters(in: .whitespacesAndNewlines), expectedStderr)
        XCTAssertEqual(exitCode, 0)
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

        do {
            _ = try await ExternalToolRunner.run(
                toolName: toolName,
                arguments: []
            )
            XCTFail("Expected ExternalToolRunnerError.executionFailed to be thrown")
        } catch let error as ExternalToolRunner.ExternalToolRunnerError {
            if case .executionFailed(let name, let code, let stderr) = error {
                XCTAssertEqual(name, toolName)
                XCTAssertEqual(code, expectedExitCode)
                XCTAssertTrue(stderr.contains(expectedStderr))
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testToolNotFound() async throws {
        let nonExistentTool = "nonexistent_tool_\(UUID().uuidString)"
        do {
            _ = try await ExternalToolRunner.run(toolName: nonExistentTool, arguments: [])
            XCTFail("Expected ExternalToolRunnerError.toolNotFound to be thrown")
        } catch let error as ExternalToolRunner.ExternalToolRunnerError {
            if case .toolNotFound(let name) = error {
                XCTAssertEqual(name, nonExistentTool)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTimeout() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let toolName = "testtool_timeout"
        _ = try createDummyExecutable(
            named: toolName,
            in: tempDir,
            exitCode: 0,
            delay: 2
        )

        let oldPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        setenv("PATH", (tempDir.path + ":" + oldPath).cString(using: .utf8), 1)
        defer { setenv("PATH", oldPath.cString(using: .utf8), 1) }

        let timeout: TimeInterval = 0.5
        let start = Date()
        do {
            _ = try await ExternalToolRunner.run(
                toolName: toolName,
                arguments: [],
                timeout: timeout
            )
            XCTFail("Expected ExternalToolRunnerError.timeout to be thrown")
        } catch let error as ExternalToolRunner.ExternalToolRunnerError {
            if case .timeout(let name) = error {
                XCTAssertEqual(name, toolName)
                let duration = Date().timeIntervalSince(start)
                XCTAssertGreaterThanOrEqual(duration, timeout)
                XCTAssertLessThan(duration, timeout + 2.0)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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

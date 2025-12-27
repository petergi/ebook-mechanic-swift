import Foundation

public struct ExternalEPUBValidator {
    public init() {}

    public static func isEpubcheckInstalled() async -> Bool {
        return await ExternalToolRunner.isCommandAvailable("epubcheck")
    }

    public func validate(fileURL: URL, epubcheckPath: String? = nil, timeout: TimeInterval = 60, showWarnings: Bool = false, accessibility: Bool = false) async -> ValidationResult {
        guard await Self.isEpubcheckInstalled() else {
            return ValidationResult(url: fileURL, size: 0, isValid: false, reason: "Epubcheck not installed.", status: .validationError, validationLevel: .comprehensive)
        }

        let toolName = epubcheckPath ?? "epubcheck"
        var arguments = [fileURL.path]
        if !showWarnings {
            arguments.insert("-q", at: 0) // Keep quiet if not showing warnings
        }
        if accessibility {
            arguments.append("--accessibility") // Placeholder for actual epubcheck accessibility flag
        }

        do {
            let (stdout, stderr, exitCode) = try await ExternalToolRunner.run(
                toolName: toolName,
                arguments: arguments,
                timeout: timeout
            )

            let isValid: Bool
            let status: ValidationStatus
            var reason: String = ""

            switch exitCode {
            case 0:
                isValid = true
                status = .ok
                reason = "EPUB is valid."
            case 1:
                isValid = true // Still considered valid, but with warnings
                status = .nonCompliant
                reason = "EPUB is valid with warnings. Details: \(stderr)"
            case 2...:
                isValid = false
                status = .corrupt // Or validationError, depending on severity of epubcheck's >1 exit codes
                reason = "EPUB validation failed. Exit code \(exitCode). Details: \(stderr)"
            default:
                isValid = false
                status = .validationError
                reason = "Epubcheck returned unexpected exit code \(exitCode). Details: \(stderr)"
            }
            
            return ValidationResult(url: fileURL, size: 0, isValid: isValid, reason: reason, status: status, validationLevel: .comprehensive, epubComplianceDetails: nil) // TODO: Parse stderr for more details for epubComplianceDetails
        } catch let error as ExternalToolRunner.ExternalToolRunnerError {
            let reason: String
            switch error {
            case .toolNotFound(let name):
                reason = "Epubcheck tool '\(name)' not found."
            case .executionFailed(_, let exitCode, let stderr):
                reason = "Epubcheck execution failed with exit code \(exitCode). Error: \(stderr)"
            case .timeout:
                reason = "Epubcheck timed out."
            }
            return ValidationResult(url: fileURL, size: 0, isValid: false, reason: reason, status: .validationError, validationLevel: .comprehensive)
        } catch {
            return ValidationResult(url: fileURL, size: 0, isValid: false, reason: "Unexpected error during epubcheck validation: \(error.localizedDescription)", status: .validationError, validationLevel: .comprehensive)
        }
    }
}
import Foundation

public struct ExternalEPUBValidator {
    public init() {}

    public static func isEpubcheckInstalled() async -> Bool {
        return await ExternalToolRunner.isCommandAvailable("epubcheck")
    }

    public func validate(fileURL: URL, epubcheckPath: String? = nil, showWarnings: Bool = false, accessibility: Bool = false) async -> ValidationResult {
        guard await Self.isEpubcheckInstalled() else {
            return ValidationResult(originalIndex: 0, url: fileURL, size: 0, isValid: false, reason: "Epubcheck not installed.", status: .validationError)
        }

        let toolURL = URL(fileURLWithPath: "/usr/bin/env")
        var arguments = ["epubcheck", fileURL.path]
        if !showWarnings {
            arguments.insert("-q", at: 1) // Keep quiet if not showing warnings
        }
        if accessibility {
            arguments.append("--accessibility") // Placeholder for actual epubcheck accessibility flag
        }

        do {
            let (exitCode, stdout, stderr) = try await ExternalToolRunner().run(
                executableURL: toolURL,
                arguments: arguments
            )
            let output = stdout.isEmpty ? stderr : stdout

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
                reason = "EPUB is valid with warnings. Details: \(output)"
            case 2...:
                isValid = false
                status = .corrupt // Or validationError, depending on severity of epubcheck's >1 exit codes
                reason = "EPUB validation failed. Exit code \(exitCode). Details: \(output)"
            default:
                isValid = false
                status = .validationError
                reason = "Epubcheck returned unexpected exit code \(exitCode). Details: \(output)"
            }
            
            return ValidationResult(originalIndex: 0, url: fileURL, size: 0, isValid: isValid, reason: reason, status: status, epubComplianceDetails: nil) // TODO: Parse stderr for more details for epubComplianceDetails
        } catch {
            return ValidationResult(originalIndex: 0, url: fileURL, size: 0, isValid: false, reason: "Unexpected error during epubcheck validation: \(error.localizedDescription)", status: .validationError)
        }
    }
}

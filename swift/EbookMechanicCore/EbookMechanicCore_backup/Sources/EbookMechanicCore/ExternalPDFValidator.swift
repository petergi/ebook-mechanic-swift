import Foundation

public struct ExternalPDFValidator {
    public init() {}

    public static func isPdfcpuInstalled() async -> Bool {
        return await ExternalToolRunner.isCommandAvailable("pdfcpu")
    }

    public func validate(fileURL: URL, pdfcpuPath: String? = nil, timeout: TimeInterval = 60) async -> ValidationResult {
        guard await Self.isPdfcpuInstalled() else {
            return ValidationResult(url: fileURL, size: 0, isValid: false, reason: "pdfcpu not installed.", status: .validationError, validationLevel: .comprehensive)
        }

        let toolName = pdfcpuPath ?? "pdfcpu"
        // pdfcpu validate does not have a -q flag; its output indicates success/failure.
        // It exits with 0 on success, non-zero on failure.
        // Errors are printed to stderr, warnings/info to stdout.
        let arguments = ["validate", fileURL.path]

        do {
            let (stdout, stderr, exitCode) = try await ExternalToolRunner.run(
                toolName: toolName,
                arguments: arguments,
                timeout: timeout
            )

            let isValid: Bool
            let status: ValidationStatus
            var reason: String = ""
            var pdfValidationDetails: PDFValidationResult? = nil

            let pdfStructureValidator = PDFStructureValidator()
            pdfValidationDetails = pdfStructureValidator.parsePdfcpuOutput(stdout: stdout, stderr: stderr, exitCode: exitCode)

            if exitCode == 0 {
                isValid = true
                status = .ok
                reason = "PDF is valid."
            } else {
                isValid = false
                // Determine status and reason based on parsed details
                if !pdfValidationDetails!.structureValid || !pdfValidationDetails!.xrefValid || !pdfValidationDetails!.pageTreeValid || !pdfValidationDetails!.streamErrors.isEmpty {
                    status = .corrupt
                    reason = "PDF validation failed due to structural issues."
                    if !pdfValidationDetails!.streamErrors.isEmpty {
                        reason += " Stream errors: \(pdfValidationDetails!.streamErrors.joined(separator: ", "))"
                    }
                } else {
                    status = .nonCompliant // Or some other specific non-compliant status if the tool indicates it
                    reason = "PDF validation failed with exit code \(exitCode). Details: \(stderr.isEmpty ? stdout : stderr)"
                }
            }

            return ValidationResult(url: fileURL, size: 0, isValid: isValid, reason: reason, status: status, validationLevel: .comprehensive, pdfValidationDetails: pdfValidationDetails)
        } catch let error as ExternalToolRunner.ExternalToolRunnerError {
            let reason: String
            switch error {
            case .toolNotFound(let name):
                reason = "pdfcpu tool '\(name)' not found."
            case .executionFailed(_, let exitCode, let stderr):
                reason = "pdfcpu execution failed with exit code \(exitCode). Error: \(stderr)"
            case .timeout:
                reason = "pdfcpu timed out."
            }
            return ValidationResult(url: fileURL, size: 0, isValid: false, reason: reason, status: .validationError, validationLevel: .comprehensive)
        } catch {
            return ValidationResult(url: fileURL, size: 0, isValid: false, reason: "Unexpected error during pdfcpu validation: \(error.localizedDescription)", status: .validationError, validationLevel: .comprehensive)
        }

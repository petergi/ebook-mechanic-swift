import Foundation

public struct ExternalPDFValidator {
    public init() {}

    public static func isPdfcpuInstalled() async -> Bool {
        return await ExternalToolRunner.isCommandAvailable("pdfcpu")
    }

    public func validate(fileURL: URL, pdfcpuPath: String? = nil) async -> ValidationResult {
        guard await Self.isPdfcpuInstalled() else {
            return ValidationResult(originalIndex: 0, url: fileURL, size: 0, isValid: false, reason: "pdfcpu not installed.", status: .validationError)
        }

        let toolURL = URL(fileURLWithPath: "/usr/bin/env")
        let arguments = ["pdfcpu", "validate", fileURL.path]

        do {
            let (exitCode, stdout, stderr) = try await ExternalToolRunner().run(
                executableURL: toolURL,
                arguments: arguments
            )
            let output = stdout.isEmpty ? stderr : stdout

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
                    reason = "PDF validation failed with exit code \(exitCode). Details: \(output)"
                }
            }

            return ValidationResult(originalIndex: 0, url: fileURL, size: 0, isValid: isValid, reason: reason, status: status, pdfValidationDetails: pdfValidationDetails)
        } catch {
            return ValidationResult(originalIndex: 0, url: fileURL, size: 0, isValid: false, reason: "Unexpected error during pdfcpu validation: \(error.localizedDescription)", status: .validationError)
        }
    }
}

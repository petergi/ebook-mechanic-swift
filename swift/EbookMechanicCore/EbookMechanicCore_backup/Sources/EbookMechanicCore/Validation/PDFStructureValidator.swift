import Foundation

struct PDFStructureValidator {
    func validate(url: URL) -> Result<PDFValidationResult, Error> {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["pdfcpu", "validate", "-m", "json", url.path]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            if process.terminationStatus == 0 {
                let validationResult = try JSONDecoder().decode(PDFValidationResult.self, from: data)
                return .success(validationResult)
            } else {
                let output = String(data: data, encoding: .utf8) ?? ""
                return .failure(PDFValidationError.cliError(output))
            }
        } catch {
            return .failure(error)
        }
    }
}

enum PDFValidationError: Error {
    case cliError(String)
    case libraryError(String)
}
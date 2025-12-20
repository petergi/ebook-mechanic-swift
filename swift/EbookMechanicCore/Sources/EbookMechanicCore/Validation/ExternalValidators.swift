//
//  ExternalValidators.swift
//  EbookMechanic
//
//  Created by Gemini on 2025-12-20.
//

import Foundation

public struct ExternalValidators {
    public static func validateEpub(at path: String) -> ValidationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["epubcheck", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return ValidationResult(isValid: true, reason: "File is a valid EPUB.")
            } else {
                return ValidationResult(isValid: false, reason: "File is not a valid EPUB. epubcheck output:\n\(output)")
            }
        } catch {
            return ValidationResult(isValid: false, reason: "Failed to run epubcheck: \(error.localizedDescription)")
        }
    }

    public static func validatePdf(at path: String) -> ValidationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pdfcpu", "validate", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return ValidationResult(isValid: true, reason: "File is a valid PDF.")
            } else {
                return ValidationResult(isValid: false, reason: "File is not a valid PDF. pdfcpu output:\n\(output)")
            }
        } catch {
            return ValidationResult(isValid: false, reason: "Failed to run pdfcpu: \(error.localizedDescription)")
        }
    }
}

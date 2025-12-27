import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Validates HTML/XHTML content within EPUB files
struct HTMLValidator {

    struct ValidationIssue {
        let file: String
        let severity: Severity
        let message: String

        enum Severity {
            case error
            case warning
        }
    }

    struct HTMLValidationResult {
        let isValid: Bool
        let issues: [ValidationIssue]

        var errorCount: Int {
            issues.filter { $0.severity == .error }.count
        }

        var warningCount: Int {
            issues.filter { $0.severity == .warning }.count
        }
    }

    /// Validates all HTML/XHTML files in the archive
    func validate(archive: ZipArchive) -> HTMLValidationResult {
        var issues: [ValidationIssue] = []

        let htmlEntries = archive.entries.filter { entry in
            let lowercased = entry.name.lowercased()
            return lowercased.hasSuffix(".html") ||
                   lowercased.hasSuffix(".xhtml") ||
                   lowercased.hasSuffix(".htm")
        }

        for entry in htmlEntries {
            validateHTMLEntry(entry, issues: &issues)
        }

        let hasErrors = issues.contains { $0.severity == .error }
        return HTMLValidationResult(isValid: !hasErrors, issues: issues)
    }

    private func validateHTMLEntry(_ entry: ZipEntry, issues: inout [ValidationIssue]) {
        // Check if file can be parsed as UTF-8
        guard let content = String(data: entry.data, encoding: .utf8) else {
            issues.append(ValidationIssue(
                file: entry.name,
                severity: .error,
                message: "Cannot decode as UTF-8"
            ))
            return
        }

        // Check for minimum content
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ValidationIssue(
                file: entry.name,
                severity: .warning,
                message: "File is empty or contains only whitespace"
            ))
            return
        }

        // Try to parse as XML (XHTML should be well-formed XML)
        do {
            let document = try XMLDocument(data: entry.data, options: [.documentTidyHTML])

            // Check for required HTML structure elements
            guard let root = document.rootElement() else {
                issues.append(ValidationIssue(
                    file: entry.name,
                    severity: .error,
                    message: "No root element found"
                ))
                return
            }

            // Validate root element is <html>
            if root.name?.lowercased() != "html" {
                issues.append(ValidationIssue(
                    file: entry.name,
                    severity: .warning,
                    message: "Root element is not <html>, found: <\(root.name ?? "unknown")>"
                ))
            }

            // Check for <head> element
            let headElements = root.elements(forName: "head")
            if headElements.isEmpty {
                issues.append(ValidationIssue(
                    file: entry.name,
                    severity: .warning,
                    message: "Missing <head> element"
                ))
            }

            // Check for <body> element
            let bodyElements = root.elements(forName: "body")
            if bodyElements.isEmpty {
                issues.append(ValidationIssue(
                    file: entry.name,
                    severity: .warning,
                    message: "Missing <body> element"
                ))
            }

            // Check for DOCTYPE
            if content.range(of: "<!doctype", options: [.caseInsensitive]) == nil {
                issues.append(ValidationIssue(
                    file: entry.name,
                    severity: .warning,
                    message: "Missing DOCTYPE declaration"
                ))
            }

            // Check for xmlns attribute (required for XHTML)
            if entry.name.lowercased().hasSuffix(".xhtml") {
                if let xmlns = root.attribute(forName: "xmlns")?.stringValue {
                    if xmlns != "http://www.w3.org/1999/xhtml" {
                        issues.append(ValidationIssue(
                            file: entry.name,
                            severity: .warning,
                            message: "Invalid XHTML namespace: \(xmlns)"
                        ))
                    }
                } else {
                    issues.append(ValidationIssue(
                        file: entry.name,
                        severity: .warning,
                        message: "XHTML file missing xmlns attribute"
                    ))
                }
            }

            // Validate character encoding declaration
            if let head = headElements.first {
                let metaElements = head.elements(forName: "meta")
                let hasCharsetDeclaration = metaElements.contains { meta in
                    if let charset = meta.attribute(forName: "charset")?.stringValue {
                        return !charset.isEmpty
                    }
                    if let httpEquiv = meta.attribute(forName: "http-equiv")?.stringValue,
                       httpEquiv.lowercased() == "content-type" {
                        return true
                    }
                    return false
                }

                if !hasCharsetDeclaration {
                    issues.append(ValidationIssue(
                        file: entry.name,
                        severity: .warning,
                        message: "Missing character encoding declaration in <head>"
                    ))
                }
            }

        } catch {
            // XML parsing failed
            issues.append(ValidationIssue(
                file: entry.name,
                severity: .error,
                message: "Not well-formed XML/XHTML: \(error.localizedDescription)"
            ))
        }
    }
}

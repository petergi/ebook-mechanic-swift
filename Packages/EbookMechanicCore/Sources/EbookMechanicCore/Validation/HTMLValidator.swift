// swiftlint:disable nesting
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
      return lowercased.hasSuffix(".html") || lowercased.hasSuffix(".xhtml")
        || lowercased.hasSuffix(".htm")
    }

    for entry in htmlEntries {
      validateHTMLEntry(entry, issues: &issues)
    }

    let hasErrors = issues.contains { $0.severity == .error }
    return HTMLValidationResult(isValid: !hasErrors, issues: issues)
  }

  private func validateHTMLEntry(_ entry: ZipEntry, issues: inout [ValidationIssue]) {
    guard let content = String(data: entry.data, encoding: .utf8) else {
      appendIssue(
        file: entry.name,
        severity: .error,
        message: "Cannot decode as UTF-8",
        issues: &issues
      )
      return
    }

    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      appendIssue(
        file: entry.name,
        severity: .warning,
        message: "File is empty or contains only whitespace",
        issues: &issues
      )
      return
    }

    do {
      let document = try XMLDocument(data: entry.data, options: [.documentTidyHTML])
      validateDocument(
        document,
        content: content,
        entry: entry,
        issues: &issues
      )
    } catch {
      appendIssue(
        file: entry.name,
        severity: .error,
        message: "Not well-formed XML/XHTML: \(error.localizedDescription)",
        issues: &issues
      )
    }
  }

  private func validateDocument(
    _ document: XMLDocument,
    content: String,
    entry: ZipEntry,
    issues: inout [ValidationIssue]
  ) {
    guard let root = document.rootElement() else {
      appendIssue(
        file: entry.name,
        severity: .error,
        message: "No root element found",
        issues: &issues
      )
      return
    }

    validateRoot(root, entry: entry, issues: &issues)
    let headElements = root.elements(forName: "head")
    let bodyElements = root.elements(forName: "body")
    validateStructure(
      headElements: headElements,
      bodyElements: bodyElements,
      entry: entry,
      issues: &issues
    )
    validateDoctype(content, entry: entry, issues: &issues)
    validateXHTMLNamespace(root, entry: entry, issues: &issues)
    validateCharsetDeclaration(
      headElements: headElements,
      entry: entry,
      issues: &issues
    )
  }

  private func validateRoot(
    _ root: XMLElement,
    entry: ZipEntry,
    issues: inout [ValidationIssue]
  ) {
    guard root.name?.lowercased() != "html" else { return }
    appendIssue(
      file: entry.name,
      severity: .warning,
      message: "Root element is not <html>, found: <\(root.name ?? "unknown")>",
      issues: &issues
    )
  }

  private func validateStructure(
    headElements: [XMLElement],
    bodyElements: [XMLElement],
    entry: ZipEntry,
    issues: inout [ValidationIssue]
  ) {
    if headElements.isEmpty {
      appendIssue(
        file: entry.name,
        severity: .warning,
        message: "Missing <head> element",
        issues: &issues
      )
    }

    if bodyElements.isEmpty {
      appendIssue(
        file: entry.name,
        severity: .warning,
        message: "Missing <body> element",
        issues: &issues
      )
    }
  }

  private func validateDoctype(
    _ content: String,
    entry: ZipEntry,
    issues: inout [ValidationIssue]
  ) {
    guard content.range(of: "<!doctype", options: [.caseInsensitive]) == nil else { return }
    appendIssue(
      file: entry.name,
      severity: .warning,
      message: "Missing DOCTYPE declaration",
      issues: &issues
    )
  }

  private func validateXHTMLNamespace(
    _ root: XMLElement,
    entry: ZipEntry,
    issues: inout [ValidationIssue]
  ) {
    guard entry.name.lowercased().hasSuffix(".xhtml") else { return }
    if let xmlns = root.attribute(forName: "xmlns")?.stringValue {
      if xmlns != "http://www.w3.org/1999/xhtml" {
        appendIssue(
          file: entry.name,
          severity: .warning,
          message: "Invalid XHTML namespace: \(xmlns)",
          issues: &issues
        )
      }
    } else {
      appendIssue(
        file: entry.name,
        severity: .warning,
        message: "XHTML file missing xmlns attribute",
        issues: &issues
      )
    }
  }

  private func validateCharsetDeclaration(
    headElements: [XMLElement],
    entry: ZipEntry,
    issues: inout [ValidationIssue]
  ) {
    guard let head = headElements.first else { return }
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

    guard !hasCharsetDeclaration else { return }
    appendIssue(
      file: entry.name,
      severity: .warning,
      message: "Missing character encoding declaration in <head>",
      issues: &issues
    )
  }

  private func appendIssue(
    file: String,
    severity: ValidationIssue.Severity,
    message: String,
    issues: inout [ValidationIssue]
  ) {
    issues.append(ValidationIssue(file: file, severity: severity, message: message))
  }
}

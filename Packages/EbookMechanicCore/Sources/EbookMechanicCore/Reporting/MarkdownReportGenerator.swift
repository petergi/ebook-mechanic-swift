import Foundation

/// Renders a human-friendly Markdown summary of a scan result.
public struct MarkdownReportGenerator: Sendable {
  public init() {}

  public func generate(
    from result: ScanResult,
    rootDirectory: URL,
    corruptedDirectoryName: String,
    repairs: [RepairResult] = []
  ) throws -> String {

    let builder = MarkdownBuilder()
    builder.appendLine("# EbookMechanic Report")
    builder.appendEmptyLine()
    builder.appendLine("**Report Date:** \(DateFormatter.humanReadable.string(from: Date()))  ")
    builder.appendLine("**Root Directory:** `\(rootDirectory.path)`  ")
    builder.appendLine("**Corrupted Files Directory:** `\(corruptedDirectoryName)`")
    builder.appendLine("\n---\n")

    builder.appendLine("## Corruption Scan Summary\n")
    builder.appendLine("- **Total files scanned:** \(result.totalFiles)")
    builder.appendLine("- **Total corrupted files:** \(result.corruptedFiles.count)\n")

    builder.appendLine("### By File Type\n")
    builder.appendLine("| File Type | Corrupted | Total | Validation Level | Status |")
    builder.appendLine("|-----------|-----------|-------|------------------|--------|")
    for type in EbookFileType.allCases {
      let breakdown = result.breakdown(for: type)
      let status = statusSummary(for: type, in: result)
      let validationLevel = validationLevelSummary(for: type, in: result)
      builder.appendLine(
        "| \(type.fileExtension.uppercased()) | \(breakdown.corrupted) | \(breakdown.total) | \(validationLevel) | \(status) |"
      )
    }

    builder.appendLine("\n## Empty Folders Summary\n")
    builder.appendLine("- **Total folders scanned:** \(result.totalFolders)")
    builder.appendLine("- **Folders with ebooks:** \(result.foldersWithEbooks)")
    builder.appendLine("- **Folders without ebooks:** \(result.emptyFolders.count)\n")

    func relativePath(for url: URL) -> String {
      url.path.replacingOccurrences(of: rootDirectory.path, with: "").trimmingCharacters(
        in: CharacterSet(charactersIn: "/"))
    }

    if !result.corruptedFiles.isEmpty {
      builder.appendLine("---\n")
      builder.appendLine("## Corrupted Files Details\n")
      let grouped = Dictionary(
        grouping: result.corruptedFiles,
        by: { EbookFileType(pathExtension: $0.url.pathExtension) ?? .pdf })
      for type in EbookFileType.allCases {
        guard let files = grouped[type], !files.isEmpty else { continue }
        builder.appendLine("### \(type.fileExtension.uppercased()) Files\n")
        for file in files {
          let relative = relativePath(for: file.url)
          let statusEmoji = statusEmoji(for: file.status)
          builder.appendLine("#### \(statusEmoji) `\(relative)`\n")
          builder.appendLine("- **Size:** \(ByteCountFormatter.readableString(from: file.size))")
          builder.appendLine("- **Reason:** \(file.reason)")
          builder.appendLine("- **Validation Level:** \(file.validationLevel.rawValue.uppercased())")

          if let pdfDetails = file.pdfValidationDetails {
            builder.appendLine("- **PDF Structure Validation:**")
            builder.appendLine(
              "  - Structure: \(pdfDetails.structureValid ? "✅ Valid" : "❌ Invalid")")
            builder.appendLine(
              "  - Cross-Reference Table: \(pdfDetails.xrefValid ? "✅ Valid" : "❌ Invalid")")
            builder.appendLine(
              "  - Page Tree: \(pdfDetails.pageTreeValid ? "✅ Valid" : "❌ Invalid")")
            if !pdfDetails.streamErrors.isEmpty {
              builder.appendLine(
                "  - Stream Errors: \(pdfDetails.streamErrors.joined(separator: ", "))")
            }
            if let encryption = pdfDetails.encryptionInfo {
              builder.appendLine("  - Encryption: \(encryption)")
            }
            if let conforms = pdfDetails.conformsToStandard {
              builder.appendLine("  - Conforms To: \(conforms)")
            }
          }

          if let epubDetails = file.epubComplianceDetails {
            builder.appendLine("- **EPUB Compliance Details:**")
            appendEpubComplianceDetails(epubDetails, builder: builder)
          }
          builder.appendEmptyLine()
        }
      }
    } else {
      builder.appendLine("---\n")
      builder.appendLine("## ✅ No Corrupted Files Found\n")
    }

    if !result.emptyFolders.isEmpty {
      builder.appendLine("---\n")
      builder.appendLine("## Folders Without Ebooks\n")
      for folder in result.emptyFolders {
        let relative = relativePath(for: folder)
        builder.appendLine("### `\(relative)`\n")
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: folder.path),
          !contents.isEmpty
        {
          builder.appendLine("**Contents:** \(contents.count) items\n")
          for (idx, item) in contents.enumerated() where idx < 5 {
            builder.appendLine("- `\(item)`")
          }
          if contents.count > 5 {
            builder.appendLine("- *... and \(contents.count - 5) more items*\n")
          } else {
            builder.appendEmptyLine()
          }
        } else {
          builder.appendLine("**Status:** Empty folder\n")
        }
      }
    } else if result.totalFolders > 0 {
      builder.appendLine("---\n")
      builder.appendLine("## ✅ No Empty Folders Found\n")
    }

    if !repairs.isEmpty {
      builder.appendLine("---\n")
      builder.appendLine("## Repair Attempts\n")
      for (index, repair) in repairs.enumerated() {
        let label: String
        if repair.fixed {
          label = "Fixed"
        } else if repair.success {
          label = "No change"
        } else {
          label = "Failed"
        }
        let icon: String = repair.fixed ? "✅" : (repair.success ? "ℹ️" : "❌")
        let path = repair.fileURL.map { "`\(relativePath(for: $0))`" } ?? "*Unknown file*"
        builder.appendLine("### \(icon) Attempt \(index + 1): \(label)")
        builder.appendLine("- **File:** \(path)")
        builder.appendLine("- **Details:** \(repair.message)\n")
      }
    }

    builder.appendLine("---\n")
    builder.appendLine("*Report generated by EbookMechanic*\n")

    return builder.contents
  }
}

private func appendEpubComplianceDetails(
  _ details: EPUBComplianceResult,
  builder: MarkdownBuilder
) {
  let issues = details.errors + details.warnings
  guard !issues.isEmpty else {
    builder.appendLine("  - No EPUB compliance issues reported.")
    return
  }

  let severityOrder = ["FATAL", "ERROR", "WARNING"]
  for severity in severityOrder {
    let issuesForSeverity = issues.filter { $0.severity.uppercased() == severity }
    guard !issuesForSeverity.isEmpty else { continue }
    builder.appendLine("  - **\(severity)**")

    let grouped = Dictionary(grouping: issuesForSeverity, by: { $0.filePath ?? "Unknown File" })
    for filePath in grouped.keys.sorted() {
      let fileIssues = grouped[filePath] ?? []
      builder.appendLine("    - `\(filePath)`")
      for issue in fileIssues {
        let lineInfo = issue.lineNumber.map { ":\($0)" } ?? ""
        let contextInfo = issue.context.map { " (\($0))" } ?? ""
        let rule = issue.ruleId.map { "\($0) " } ?? ""
        builder.appendLine(
          "      - \(rule)\(lineInfo)\(contextInfo): \(issue.message)")
      }
    }
  }
}

private func validationLevelSummary(for type: EbookFileType, in result: ScanResult) -> String {
  let okLevels = result.okFiles
    .filter { EbookFileType(pathExtension: $0.url.pathExtension) == type }
    .map { $0.validationLevel }
  let corruptedLevels = result.corruptedFiles
    .filter { EbookFileType(pathExtension: $0.url.pathExtension) == type }
    .map { $0.validationLevel }
  let uniqueLevels = Set(okLevels + corruptedLevels)
  guard !uniqueLevels.isEmpty else { return "-" }
  if uniqueLevels.count == 1, let level = uniqueLevels.first {
    return level.rawValue.uppercased()
  }
  return "MIXED"
}

private func statusSummary(for type: EbookFileType, in result: ScanResult) -> String {
  let statuses = result.corruptedFiles
    .filter { EbookFileType(pathExtension: $0.url.pathExtension) == type }
    .map { $0.status }
  if statuses.contains(.corrupt) { return "❌ CORRUPT" }
  if statuses.contains(.validationError) { return "⚡ ERROR" }
  if statuses.contains(.nonCompliant) { return "⚠️ NON_COMPLIANT" }
  return "✅ OK"
}

private func statusEmoji(for status: ValidationStatus) -> String {
  switch status {
  case .ok: return "✅"
  case .nonCompliant: return "⚠️"
  case .corrupt: return "❌"
  case .validationError: return "⚡"
  }
}

private final class MarkdownBuilder {
  private(set) var contents: String = ""

  func appendLine(_ line: String) {
    contents.append(line)
    if !line.hasSuffix("\n") {
      contents.append("\n")
    }
  }

  func appendEmptyLine() {
    contents.append("\n")
  }
}

extension ByteCountFormatter {
  fileprivate static func readableString(from size: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .binary
    return formatter.string(fromByteCount: size)
  }
}

extension DateFormatter {
  fileprivate static let humanReadable: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
  }()
}

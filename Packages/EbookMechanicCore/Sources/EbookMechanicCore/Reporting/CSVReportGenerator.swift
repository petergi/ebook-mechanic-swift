import Foundation

struct CSVReportGenerator {
  func generate(
    from result: ScanResult, rootDirectory: URL, corruptedDirectoryName: String,
    repairs: [RepairResult]
  ) throws -> String {
    var csv = "FilePath,Status,Format,Reason,FileSize,Fingerprint\n"

    // Data rows
    for file in result.corruptedFiles {
      let relativePath = file.url.path.replacingOccurrences(of: rootDirectory.path, with: "")
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let format = EbookFileType(pathExtension: file.url.pathExtension)?.rawValue ?? "unknown"
      let fingerprint = file.fingerprint?.description ?? ""
      csv +=
        "\"\(escapeCSV(relativePath))\",\"\(escapeCSV(file.status.rawValue))\",\"\(escapeCSV(format))\",\"\(escapeCSV(file.reason))\",\"\(file.size)\",\"\(escapeCSV(fingerprint))\"\n"
    }

    // Summary row for corrupted files
    csv += "\nSummary: Corrupted Files\n"
    csv += "Format,Corrupted,Total\n"
    for type in EbookFileType.allCases {
      let breakdown = result.breakdown(for: type)
      csv += "\(type.rawValue),\(breakdown.corrupted),\(breakdown.total)\n"
    }
    csv += "Total,\(result.corruptedFiles.count),\(result.totalFiles)\n"

    // Summary row for empty folders
    csv += "\nSummary: Empty Folders\n"
    csv += "Empty Folders,\(result.emptyFolders.count)\n"
    csv += "Total Folders,\(result.totalFolders)\n"
    csv += "Folders with Ebooks,\(result.foldersWithEbooks)\n"

    // Repair Results
    if !repairs.isEmpty {
      csv += "\nRepair Results\n"
      csv += "File,Success,Fixed,Message\n"
      for repair in repairs {
        let filePath =
          repair.fileURL?.path.replacingOccurrences(of: rootDirectory.path, with: "")
          .trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? "Unknown"
        csv +=
          "\"\(escapeCSV(filePath))\",\(repair.success),\(repair.fixed),\"\(escapeCSV(repair.message))\"\n"
      }
    }

    return csv
  }

  private func escapeCSV(_ value: String) -> String {
    value.replacingOccurrences(of: "\"", with: "\"\"")
  }
}

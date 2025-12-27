import Foundation

struct HTMLReportGenerator {
  func generate(
    from result: ScanResult, rootDirectory: URL, corruptedDirectoryName: String,
    repairs: [RepairResult]
  ) throws -> String {
    let timestamp = DateFormatter.humanReadable.string(from: Date())
    let html = """
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>EbookMechanic Report - \(timestamp)</title>
          <style>
              body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background-color: #f4f7f6; }
              .container { max-width: 1000px; margin: 20px auto; background: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
              h1, h2, h3, h4 { color: #2c3e50; line-height: 1.3; }
              h1 { text-align: center; color: #2c3e50; margin-bottom: 30px; }
              .section-header { border-bottom: 2px solid #eee; padding-bottom: 10px; margin-top: 40px; margin-bottom: 20px; }
              table { width: 100%; border-collapse: collapse; margin-bottom: 20px; background-color: #fff; border-radius: 8px; overflow: hidden; }
              th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #e0e0e0; }
              th { background-color: #f8f8f8; font-weight: 600; cursor: pointer; }
              tr:hover { background-color: #f0f0f0; }
              .badge { display: inline-block; padding: 5px 10px; border-radius: 20px; font-weight: bold; font-size: 0.85em; text-transform: uppercase; }
              .badge.ok { background-color: #e6f7ed; color: #52c41a; }
              .badge.nonCompliant { background-color: #fffbe6; color: #faad14; }
              .badge.corrupt { background-color: #fff1f0; color: #f5222d; }
              .badge.validationError { background-color: #f0f5ff; color: #1890ff; }
              .file-detail { background-color: #f9f9f9; border-left: 4px solid #e0e0e0; padding: 15px; margin-top: 10px; border-radius: 4px; }
              .file-detail h4 { margin-top: 0; color: #555; }
              .file-detail p { margin: 5px 0; font-size: 0.9em; }
              .collapsible-header { cursor: pointer; display: flex; align-items: center; justify-content: space-between; padding: 10px 0; border-bottom: 1px dashed #eee; }
              .collapsible-header:hover { background-color: #f9f9f9; }
              .collapsible-content { display: none; padding-top: 10px; border-top: 1px dashed #eee; margin-top: 5px; }
              .collapsible-header.active + .collapsible-content { display: block; }
              .icon { font-size: 1.2em; margin-right: 5px; }
              .status-ok .icon { color: #52c41a; }
              .status-noncompliant .icon { color: #faad14; }
              .status-corrupt .icon { color: #f5222d; }
              .status-validationerror .icon { color: #1890ff; }
              footer { text-align: center; margin-top: 50px; font-size: 0.9em; color: #888; }
              .button {
                  background-color: #007bff;
                  color: white;
                  padding: 8px 15px;
                  border: none;
                  border-radius: 4px;
                  cursor: pointer;
                  font-size: 0.9em;
              }
              .button:hover {
                  background-color: #0056b3;
              }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>EbookMechanic Report</h1>
              <p><strong>Report Date:</strong> \(timestamp)</p>
              <p><strong>Root Directory:</strong> <code>\(rootDirectory.path)</code></p>
              <p><strong>Corrupted Files Directory:</strong> <code>\(corruptedDirectoryName)</code></p>

              <h2 class="section-header">Corruption Scan Summary</h2>
              <p><strong>Total files scanned:</strong> \(result.totalFiles)</p>
              <p><strong>Total corrupted files:</strong> \(result.corruptedFiles.count)</p>

              <h3 class="section-header">By File Type</h3>
              <table>
                  <thead>
                      <tr>
                          <th onclick="sortTable(0)">File Type</th>
                          <th onclick="sortTable(1)">Corrupted</th>
                          <th onclick="sortTable(2)">Total</th>
                          <th onclick="sortTable(3)">Status</th>
                      </tr>
                  </thead>
                  <tbody>
                      \(EbookFileType.allCases.map { type in
                            let breakdown = result.breakdown(for: type)
                            let statusEmoji: String
                            let statusClass: String
                            if breakdown.corrupted > 0 {
                                statusEmoji = "❌"
                                statusClass = "corrupt"
                            } else {
                                statusEmoji = "✅"
                                statusClass = "ok"
                            }
                            return """
                            <tr>
                                <td>\(type.fileExtension.uppercased())</td>
                                <td>\(breakdown.corrupted)</td>
                                <td>\(breakdown.total)</td>
                                <td><span class="badge \(statusClass)">\(statusEmoji) \(breakdown.corrupted > 0 ? "Corrupted" : "OK")</span></td>
                            </tr>
                            """
                        }.joined())
                  </tbody>
              </table>

              <h2 class="section-header">Empty Folders Summary</h2>
              <p><strong>Total folders scanned:</strong> \(result.totalFolders)</p>
              <p><strong>Folders with ebooks:</strong> \(result.foldersWithEbooks)</p>
              <p><strong>Folders without ebooks:</strong> \(result.emptyFolders.count)</p>

              \(result.corruptedFiles.isEmpty ? "<h2 class='section-header status-ok'>✅ No Corrupted Files Found</h2>" : generateCorruptedFilesDetails(result: result, rootDirectory: rootDirectory))

              \(result.emptyFolders.isEmpty ? (result.totalFolders > 0 ? "<h2 class='section-header status-ok'>✅ No Empty Folders Found</h2>" : "") : generateEmptyFoldersDetails(result: result, rootDirectory: rootDirectory))
              
              \(repairs.isEmpty ? "" : generateRepairAttempts(repairs: repairs, rootDirectory: rootDirectory))

              <footer>
                  <p>Report generated by EbookMechanic</p>
              </footer>
          </div>

          <script>
              function sortTable(n) {
                  var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
                  table = document.querySelector("table");
                  switching = true;
                  dir = "asc"; 
                  while (switching) {
                      switching = false;
                      rows = table.rows;
                      for (i = 1; i < (rows.length - 1); i++) {
                          shouldSwitch = false;
                          x = rows[i].getElementsByTagName("TD")[n];
                          y = rows[i + 1].getElementsByTagName("TD")[n];
                          if (dir == "asc") {
                              if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {
                                  shouldSwitch= true;
                                  break;
                              }
                          } else if (dir == "desc") {
                              if (x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) {
                                  shouldSwitch= true;
                                  break;
                              }
                          }
                      }
                      if (shouldSwitch) {
                          rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
                          switching = true;
                          switchcount ++;      
                      } else {
                          if (switchcount == 0 && dir == "asc") {
                              dir = "desc";
                              switching = true;
                          }
                      }
                  }
              }

              document.addEventListener('DOMContentLoaded', function() {
                  document.querySelectorAll('.collapsible-header').forEach(header => {
                      header.addEventListener('click', function() {
                          this.classList.toggle('active');
                          const content = this.nextElementSibling;
                          if (content.style.display === "block") {
                              content.style.display = "none";
                          } else {
                              content.style.display = "block";
                          }
                      });
                  });
              });
          </script>
      </body>
      </html>
      """
    return html
  }

  private func relativePath(for url: URL, rootDirectory: URL) -> String {
    url.path.replacingOccurrences(of: rootDirectory.path, with: "").trimmingCharacters(
      in: CharacterSet(charactersIn: "/"))
  }

  private func generateCorruptedFilesDetails(result: ScanResult, rootDirectory: URL) -> String {
    var details = "<h2 class='section-header'>Corrupted Files Details</h2>"
    let grouped = Dictionary(
      grouping: result.corruptedFiles,
      by: { EbookFileType(pathExtension: $0.url.pathExtension) ?? .pdf })
    for type in EbookFileType.allCases {
      guard let files = grouped[type], !files.isEmpty else { continue }
      details += "<h3>\(type.fileExtension.uppercased()) Files</h3>"
      for file in files {
        let relative = relativePath(for: file.url, rootDirectory: rootDirectory)
        let statusEmoji: String
        let statusClass: String
        switch file.status {
        case .ok:
          statusEmoji = "✅"
          statusClass = "ok"
        case .nonCompliant:
          statusEmoji = "⚠️"
          statusClass = "nonCompliant"
        case .corrupt:
          statusEmoji = "❌"
          statusClass = "corrupt"
        case .validationError:
          statusEmoji = "⚡"
          statusClass = "validationError"
        }

        var pdfDetailsHtml = ""
        if let pdfDetails = file.pdfValidationDetails {
          pdfDetailsHtml = """
            <div class="pdf-validation-details">
                <p><strong>PDF Structure Validation:</strong></p>
                <ul>
                    <li>Structure: <span class="badge \(pdfDetails.structureValid ? "ok" : "corrupt")">\(pdfDetails.structureValid ? "Valid" : "Invalid")</span></li>
                    <li>Cross-Reference Table: <span class="badge \(pdfDetails.xrefValid ? "ok" : "corrupt")">\(pdfDetails.xrefValid ? "Valid" : "Invalid")</span></li>
                    <li>Page Tree: <span class="badge \(pdfDetails.pageTreeValid ? "ok" : "corrupt")">\(pdfDetails.pageTreeValid ? "Valid" : "Invalid")</span></li>
                    <li>Stream Errors: \(pdfDetails.streamErrors.isEmpty ? "None" : "<span class=\"badge corrupt\">\(pdfDetails.streamErrors.joined(separator: ", ").htmlEscaped())</span>")</li>
                    <li>Encryption: \(pdfDetails.encryptionInfo?.htmlEscaped() ?? "None")</li>
                    <li>Conforms To: \(pdfDetails.conformsToStandard?.htmlEscaped() ?? "N/A")</li>
                </ul>
            </div>
            """
        }

        details += """
          <div class="file-detail status-\(statusClass)">
              <div class="collapsible-header">
                  <h4><span class="icon">\(statusEmoji)</span> <code>\(relative)</code></h4>
                  <button class="button">View Details</button>
              </div>
              <div class="collapsible-content">
                  <p><strong>Size:</strong> \(ByteCountFormatter.readableString(from: file.size))</p>
                  <p><strong>Reason:</strong> \(file.reason.htmlEscaped())</p>
                  \(file.fingerprint?.description.htmlEscaped() ?? "")
                  \(pdfDetailsHtml)
              </div>
          </div>
          """
      }
    }
    return details
  }

  private func generateEmptyFoldersDetails(result: ScanResult, rootDirectory: URL) -> String {
    var details = "<h2 class='section-header'>Folders Without Ebooks</h2>"
    for folder in result.emptyFolders {
      let relative = relativePath(for: folder, rootDirectory: rootDirectory)
      details += """
        <div class="file-detail">
            <h4><code>\(relative)</code></h4>
        </div>
        """
    }
    return details
  }

  private func generateRepairAttempts(repairs: [RepairResult], rootDirectory: URL) -> String {
    var details = "<h2 class='section-header'>Repair Attempts</h2>"
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
      let path =
        repair.fileURL.map { "<code>\(relativePath(for: $0, rootDirectory: rootDirectory))</code>" }
        ?? "<i>Unknown file</i>"

      details += """
        <div class="file-detail">
            <div class="collapsible-header">
                <h4>\(icon) Attempt \(index + 1): \(label)</h4>
                <button class="button">View Details</button>
            </div>
            <div class="collapsible-content">
                <p><strong>File:</strong> \(path)</p>
                <p><strong>Details:</strong> \(repair.message)</p>
            </div>
        </div>
        """
    }
    return details
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

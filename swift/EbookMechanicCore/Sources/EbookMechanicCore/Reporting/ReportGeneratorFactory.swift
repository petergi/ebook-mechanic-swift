import Foundation

enum ReportGeneratorFactory {
  static func generator(for format: ReportFormat) -> any ReportGenerating {
    switch format {
    case .markdown:
      return MarkdownReportGenerator()
    case .json:
      return JSONReportGenerator()
    case .csv:
      return CSVReportGenerator()
    case .html:
      return HTMLReportGenerator()
    }
  }
}

protocol ReportGenerating {
  func generate(
    from result: ScanResult, rootDirectory: URL, corruptedDirectoryName: String,
    repairs: [RepairResult]
  ) throws -> String
}

extension MarkdownReportGenerator: ReportGenerating {}

extension CSVReportGenerator: ReportGenerating {}
extension HTMLReportGenerator: ReportGenerating {}

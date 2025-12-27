import EbookMechanicCore
import Foundation
import SwiftUI

final class ScanOptions: ObservableObject {
  @Published var directory: URL
  @Published var corruptedDirectoryName: String = "CORRUPTED"
  @Published var repair: Bool = false
  @Published var corruptionOnly: Bool = false
  @Published var emptyFoldersOnly: Bool = false
  @Published var dryRun: Bool = true
  @Published var autoMoveCorrupted: Bool = false
  @Published var autoDeleteEmptyFolders: Bool = false
  @Published var generateReport: Bool = false
  @Published var normalizeEPUBs: Bool = false
  @Published var forceNormalize: Bool = false
  @Published var useExternalTools: Bool = false
  @Published var maxConcurrentValidations: Int = 1
  @Published var useCache: Bool = true
  @Published var selectedReportFormats: Set<ReportFormat> = [.markdown]
  @Published var showPerformanceStats: Bool = false

  init(directory: URL) {
    self.directory = directory
  }
}

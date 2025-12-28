import EbookMechanicCore
import SwiftUI
import XCTest

@testable import EbookMechanicApp

@MainActor
final class ContentViewUITests: XCTestCase {
  func testDirectoryLabelMatchesSelectedPath() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Library")
    let sut = makeSUT(selectedDirectory: directory)

    XCTAssertEqual(sut.testHooks.directoryPath, directory.path)
  }

  func testAutomationTogglesDisableDuringDryRun() {
    let options = ScanOptions(directory: FileManager.default.temporaryDirectory)
    options.dryRun = true
    let sut = makeSUT(options: options)

    XCTAssertTrue(sut.testHooks.autoMoveToggleDisabled)
    XCTAssertTrue(sut.testHooks.autoDeleteToggleDisabled)
  }

  func testAutomationTogglesEnableWhenLiveRun() {
    let options = ScanOptions(directory: FileManager.default.temporaryDirectory)
    options.dryRun = false
    let sut = makeSUT(options: options)

    XCTAssertFalse(sut.testHooks.autoMoveToggleDisabled)
    XCTAssertFalse(sut.testHooks.autoDeleteToggleDisabled)
  }

  func testPrimaryTogglesDisableWhileScanning() {
    let sut = makeSUT { viewModel in
      viewModel.isScanning = true
    }

    XCTAssertTrue(sut.testHooks.attemptRepairToggleDisabled)
    XCTAssertTrue(sut.testHooks.dryRunToggleDisabled)
    XCTAssertTrue(sut.testHooks.generateReportToggleDisabled)
    XCTAssertTrue(sut.testHooks.corruptionOnlyToggleDisabled)
    XCTAssertTrue(sut.testHooks.emptyFoldersOnlyToggleDisabled)
  }

  func testStatusMessagesVisibleInSummaryCard() {
    let sut = makeSUT { viewModel in
      viewModel.summary = ScanResult(totalFiles: 3)
      viewModel.statusMessages = ["Scanned 3 files", "No corrupted files"]
    }

    XCTAssertEqual(sut.testHooks.statusMessages, ["Scanned 3 files", "No corrupted files"])
    XCTAssertEqual(sut.testHooks.summary?.totalFiles, 3)
  }

  func testReportBadgeExposesFileName() {
    let sut = makeSUT { viewModel in
      viewModel.summary = ScanResult(totalFiles: 1)
      viewModel.reportURLs = [URL(fileURLWithPath: "/tmp/report.md")]
    }

    XCTAssertEqual(sut.testHooks.reportFileName, "report.md")
  }

  func testCorruptedFilesSectionSnapshot() {
    let sut = makeSUT { viewModel in
      viewModel.corruptedFiles = [
        CorruptedFile(
          url: URL(fileURLWithPath: "/tmp/bad1.epub"), reason: "Invalid mimetype", size: 10,
          status: .corrupt),
        CorruptedFile(
          url: URL(fileURLWithPath: "/tmp/bad2.pdf"), reason: "Missing EOF", size: 20,
          status: .corrupt)
      ]
    }

    XCTAssertEqual(sut.testHooks.corruptedFileNames, ["bad1.epub", "bad2.pdf"])
    XCTAssertEqual(sut.testHooks.corruptedReasons, ["Invalid mimetype", "Missing EOF"])
  }

  func testEmptyFoldersSectionSnapshot() {
    let sut = makeSUT { viewModel in
      viewModel.emptyFolders = [
        URL(fileURLWithPath: "/tmp/EmptyFolderA"),
        URL(fileURLWithPath: "/tmp/EmptyFolderB")
      ]
    }

    XCTAssertEqual(sut.testHooks.emptyFolderPaths, ["/tmp/EmptyFolderA", "/tmp/EmptyFolderB"])
  }

  func testProgressSectionWhenScanning() {
    let sut = makeSUT { viewModel in
      viewModel.isScanning = true
      viewModel.progressHeadline = "Scanning Files"
      viewModel.progressDetail = "2/10"
    }

    XCTAssertTrue(sut.testHooks.isProgressVisible)
    XCTAssertEqual(sut.testHooks.progressHeadline, "Scanning Files")
    XCTAssertEqual(sut.testHooks.progressDetail, "2/10")
    XCTAssertEqual(sut.testHooks.runButtonTitle, "Cancel Scan")
    XCTAssertTrue(sut.testHooks.pauseButtonVisible)
    XCTAssertEqual(sut.testHooks.pauseButtonTitle, "Pause")
  }

  func testRunButtonShowsIdleStateWhenNotScanning() {
    let sut = makeSUT()
    XCTAssertEqual(sut.testHooks.runButtonTitle, "Run Scan")
    XCTAssertFalse(sut.testHooks.isProgressVisible)
    XCTAssertFalse(sut.testHooks.pauseButtonVisible)
  }

  // MARK: - Helpers

  private func makeSUT(
    selectedDirectory: URL = FileManager.default.temporaryDirectory,
    options: ScanOptions? = nil,
    configureViewModel: ((ScanViewModel) -> Void)? = nil,
    onSelectDirectory: @escaping () -> Void = {},
    onRunScan: @escaping () -> Void = {},
    onCancelScan: @escaping () -> Void = {},
    onTogglePause: @escaping () -> Void = {}
  ) -> ContentView {
    let viewModel = ScanViewModel()
    configureViewModel?(viewModel)

    let selectedBox = Box(selectedDirectory)
    let optionsInstance = options ?? ScanOptions(directory: selectedDirectory)

    return ContentView(
      viewModel: viewModel,
      selectedDirectory: selectedBox.binding,
      options: optionsInstance,
      onSelectDirectory: onSelectDirectory,
      onRunScan: onRunScan,
      onCancelScan: onCancelScan,
      onTogglePause: onTogglePause
    )
  }
}

private final class Box<Value>: @unchecked Sendable {
  var value: Value
  init(_ value: Value) { self.value = value }

  var binding: Binding<Value> {
    Binding(get: { self.value }, set: { self.value = $0 })
  }
}

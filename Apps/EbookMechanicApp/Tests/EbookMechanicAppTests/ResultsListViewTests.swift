import EbookMechanicCore
import Foundation
import XCTest

@testable import EbookMechanicApp

final class ResultsListViewTests: XCTestCase {
  @MainActor
  func testResultsListGroupsBucketsCorruptedAndNonCompliant() {
    let viewModel = ScanViewModel()
    let corruptedFile = CorruptedFile(
      url: URL(fileURLWithPath: "/tmp/broken.epub"),
      reason: "Bad ZIP",
      size: 100,
      status: .corrupt
    )
    viewModel.corruptedFiles = [corruptedFile]

    let nonCompliant = ValidationResult(
      originalIndex: 0,
      url: URL(fileURLWithPath: "/tmp/noncompliant.epub"),
      size: 200,
      isValid: true,
      reason: "Spec issue",
      status: .nonCompliant
    )
    viewModel.validationResults = [nonCompliant.url: nonCompliant]

    let groups = ResultsListGroups(viewModel: viewModel)

    XCTAssertEqual(groups.corrupted.count, 1)
    XCTAssertEqual(groups.corrupted.first?.status, .corrupt)
    XCTAssertEqual(groups.nonCompliant, [nonCompliant])
    XCTAssertTrue(groups.warnings.isEmpty)
  }

  @MainActor
  func testResultsListGroupsBucketsWarnings() throws {
    let viewModel = ScanViewModel()
    let epubComplianceJSON = """
    {
      "isCompliant": true,
      "hasWarnings": true,
      "errors": [],
      "warnings": [
        {
          "severity": "warning",
          "message": "Minor issue",
          "filePath": null,
          "lineNumber": null,
          "ruleId": null
        }
      ],
      "epubVersion": "3.2",
      "epubcheckVersion": "5.0",
      "features": [],
      "conformsToAccessibility": false
    }
    """
    let epubCompliance = try JSONDecoder().decode(
      EPUBComplianceResult.self, from: Data(epubComplianceJSON.utf8))
    let warningResult = ValidationResult(
      originalIndex: 0,
      url: URL(fileURLWithPath: "/tmp/warn.epub"),
      size: 123,
      isValid: true,
      reason: "Warnings",
      status: .ok,
      epubComplianceDetails: epubCompliance
    )
    viewModel.validationResults = [warningResult.url: warningResult]

    let groups = ResultsListGroups(viewModel: viewModel)

    XCTAssertEqual(groups.warnings, [warningResult])
  }
}

import XCTest
@testable import EbookMechanicCore

final class EPUBComplianceValidatorTests: XCTestCase {

    var validator: EpubStructureValidator!

    override func setUpWithError() throws {
        validator = EpubStructureValidator()
    }

    func getFixtureURL(for fileName: String) throws -> URL {
        let currentFileURL = URL(fileURLWithPath: #file)
        let currentDirectoryURL = currentFileURL.deletingLastPathComponent()
        let resourcesURL = currentDirectoryURL.appendingPathComponent("Resources/EPUBs")
        return resourcesURL.appendingPathComponent(fileName)
    }

    func testValidEPUB2() throws {
        let url = try getFixtureURL(for: "valid-epub2.epub")
        let result = validator.validate(url: url)
        
        switch result {
        case .success(let validationResult):
            XCTAssertTrue(validationResult.isCompliant)
            XCTAssertFalse(validationResult.hasWarnings)
            XCTAssertEqual(validationResult.epubVersion, "2.0")
        case .failure(let error):
            XCTFail("Validation failed with error: \(error.localizedDescription)")
        }
    }

    func testValidEPUB3() throws {
        let url = try getFixtureURL(for: "valid-epub3.epub")
        let result = validator.validate(url: url)
        
        switch result {
        case .success(let validationResult):
            XCTAssertTrue(validationResult.isCompliant)
            XCTAssertFalse(validationResult.hasWarnings)
            XCTAssertEqual(validationResult.epubVersion, "3.0")
        case .failure(let error):
            XCTFail("Validation failed with error: \(error.localizedDescription)")
        }
    }

    func testMissingMetadata() throws {
        let url = try getFixtureURL(for: "missing-metadata.epub")
        let result = validator.validate(url: url)
        
        switch result {
        case .success(let validationResult):
            XCTAssertFalse(validationResult.isCompliant)
            XCTAssertTrue(validationResult.errors.contains { $0.ruleId == "OPF-001" })
        case .failure(let error):
            XCTFail("Validation failed with error: \(error.localizedDescription)")
        }
    }

    func testBrokenLinks() throws {
        let url = try getFixtureURL(for: "broken-links.epub")
        let result = validator.validate(url: url)
        
        switch result {
        case .success(let validationResult):
            XCTAssertFalse(validationResult.isCompliant)
            XCTAssertTrue(validationResult.errors.contains { $0.ruleId == "RSC-007" }) // Example rule for broken link
        case .failure(let error):
            XCTFail("Validation failed with error: \(error.localizedDescription)")
        }
    }

    func testInvalidXHTML() throws {
        let url = try getFixtureURL(for: "invalid-xhtml.epub")
        let result = validator.validate(url: url)
        
        switch result {
        case .success(let validationResult):
            XCTAssertFalse(validationResult.isCompliant)
            XCTAssertTrue(validationResult.errors.contains { $0.ruleId == "RSC-005" }) // Example rule for invalid XHTML
        case .failure(let error):
            XCTFail("Validation failed with error: \(error.localizedDescription)")
        }
    }

    func testAccessibilityViolations() throws {
        let url = try getFixtureURL(for: "accessibility-violations.epub")
        let result = validator.validate(url: url)
        
        switch result {
        case .success(let validationResult):
            XCTAssertTrue(validationResult.isCompliant) // May be compliant but with warnings
            XCTAssertTrue(validationResult.hasWarnings)
            XCTAssertTrue(validationResult.warnings.contains { $0.ruleId?.starts(with: "ACC-") ?? false })
        case .failure(let error):
            XCTFail("Validation failed with error: \(error.localizedDescription)")
        }
    }
}

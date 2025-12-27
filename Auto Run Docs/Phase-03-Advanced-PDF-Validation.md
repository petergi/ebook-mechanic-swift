# Phase 03: Advanced PDF Validation with pdfcpu Integration

This phase enhances PDF validation by integrating the pdfcpu library for deep structure validation beyond basic header/EOF checks. This brings EbookMechanic's PDF validation capabilities to match the reference pdfcheck project's comprehensive PDF spec compliance verification.

## Tasks

- [x] Add pdfcpu dependency to Packages/EbookMechanicCore/Package.swift as SPM package: url "https://github.com/pdfcpu/pdfcpu" with version requirement "~> 0.8.0" (note: this adds external dependency to previously dependency-free core)
- [x] Create Packages/EbookMechanicCore/Sources/EbookMechanicCore/PDFStructureValidator.swift with Swift wrapper around pdfcpu validation API, validate method that checks PDF structure, cross-reference table, object streams, page tree, and returns structured results with specific failure reasons
- [x] Update ExternalPDFValidator.swift to use PDFStructureValidator as primary validation method instead of Process-based pdfcpu CLI execution, fall back to CLI execution if library validation fails, preserve fallback to built-in validation if neither available
- [x] Create PDFValidationResult struct in Models.swift with properties: structureValid (bool), xrefValid (bool), pageTreeValid (bool), streamErrors (array of strings), encryptionInfo (optional string), and conformsToStandard (optional PDF/A, PDF/X identifier)
- [x] Update FileValidator.swift EPUB and PDF validation to return enhanced PDFValidationResult instead of simple boolean, include detailed structure validation results in ValidationResult.reason field
- [x] Add Packages/EbookMechanicCore/Tests/EbookMechanicCoreTests/PDFStructureValidatorTests.swift with tests for valid PDF with correct structure, PDF with corrupt xref table, PDF with invalid page tree, PDF with malformed streams, and encrypted PDF handling
- [x] Create test fixtures in Packages/EbookMechanicCore/Tests/Resources/PDFs/ directory: valid-structure.pdf (minimal valid PDF), corrupt-xref.pdf (broken cross-reference), invalid-pages.pdf (malformed page tree), malformed-stream.pdf (corrupt object stream)
- [x] Update PDFVerifierTests.swift to include structure validation tests alongside existing fingerprint tests, verify that structure errors are correctly identified and reported
- [x] Update JSONReportGenerator.swift to include pdfValidationDetails object in JSON output for PDF files with structure validation breakdown
- [x] Update HTMLReportGenerator.swift to add expandable details section for PDF files showing structure validation results with color-coded pass/fail indicators for each validation component
- [x] Update MarkdownReportGenerator.swift to add optional detailed PDF section with structure validation breakdown formatted as nested bullet list
- [x] Update CLI progress output in ProgressPrinter.swift to show "Deep PDF validation" message when validating PDF with structure checks vs "Basic PDF validation" for header-only checks

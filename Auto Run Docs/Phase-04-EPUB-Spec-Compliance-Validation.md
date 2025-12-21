# Phase 04: EPUB Spec Compliance Validation

This phase integrates full EPUB 3.x specification compliance checking via the external epubcheck tool, matching the reference epubcheck project's capabilities. The system will distinguish between EPUB files that are structurally valid (proper ZIP) but non-compliant with EPUB specs versus truly corrupt files.

## Tasks

- [ ] Update ExternalEPUBValidator.swift to capture full epubcheck output (not just exit code), parse warning vs error messages from output, categorize issues by severity (FATAL, ERROR, WARNING), extract line numbers and context from epubcheck messages
- [ ] Create EPUBComplianceResult struct in Models.swift with properties: isCompliant (bool), hasWarnings (bool), errors array of EPUBValidationIssue, warnings array of EPUBValidationIssue, epubVersion (2.0, 3.0, 3.1, 3.2), and conformsToAccessibility (bool for EPUB Accessibility spec)
- [ ] Create EPUBValidationIssue struct with properties: severity (fatal/error/warning), message (string), filePath (optional string for file within EPUB), lineNumber (optional int), ruleId (optional string for spec rule violated)
- [ ] Update FileValidator.swift EPUB validation to return EPUBComplianceResult with full issue breakdown, set ValidationStatus to nonCompliant for spec violations vs corrupt for ZIP/structure failures
- [ ] Add EPUBComplianceValidatorTests.swift with tests for EPUB 2.0 valid file, EPUB 3.0 valid file, EPUB with missing required metadata, EPUB with accessibility violations, EPUB with broken internal links, and EPUB with invalid HTML/XHTML content
- [ ] Create test fixtures in swift/EbookMechanicCore/Tests/Resources/EPUBs/: valid-epub2.epub, valid-epub3.epub, missing-metadata.epub, broken-links.epub, invalid-xhtml.epub, accessibility-violations.epub
- [ ] Update ExternalEPUBValidator.swift to detect epubcheck version (run epubcheck -version), store version info in validation results, handle version-specific output format differences
- [ ] Add installExternalTools target to swift/Makefile that checks for epubcheck and pdfcpu, provides installation instructions for missing tools (Homebrew commands for macOS, apt/dnf for Linux), optionally auto-install via Homebrew if user confirms
- [ ] Update JSONReportGenerator.swift to include epubComplianceDetails object with errors array, warnings array, version info, and accessibility compliance flag
- [ ] Update HTMLReportGenerator.swift to add expandable EPUB compliance section with color-coded issue severity, grouped by file within EPUB, linked line numbers for navigation
- [ ] Update MarkdownReportGenerator.swift to add EPUB Compliance Details section with hierarchical issue list grouped by severity then by file
- [ ] Update main.swift to display summary of EPUB compliance issues: "Found X EPUB files: Y compliant, Z with warnings, W non-compliant"
# Phase 02: Enhanced Reporting System

This phase implements multi-format reporting capabilities (JSON, CSV, HTML) matching the reference epubcheck project, while preserving the existing Markdown reports. The enhanced reporting system will categorize validation results more precisely and provide machine-readable output for integration with other tools.

## Tasks

- [x] Create ValidationStatus enum in Models.swift with cases: ok, nonCompliant (failed spec validation), corrupt (cannot read file structure), validationError (tool execution failed), and update ValidationResult to include status property derived from isValid and validation level
- [x] Create ReportFormat enum in Models.swift with cases: markdown, json, csv, html, and add reportFormats array parameter to scanning configuration
- [x] Create Packages/EbookMechanicCore/Sources/EbookMechanicCore/JSONReportGenerator.swift that generates JSON with metadata object (timestamp, rootDirectory, elapsedTime, validationLevel), results array with full file details including status enum, validationLevel, reason, fingerprint if available, and summary object with counts by status
- [x] Create CSVReportGenerator.swift that generates CSV with headers: FilePath, Status, Format, ValidationLevel, Reason, FileSize, Fingerprint, properly escapes commas and quotes in reason field, includes summary row at bottom with total counts
- [x] Create HTMLReportGenerator.swift that generates styled HTML report with embedded CSS (no external dependencies), responsive table layout with sortable columns using inline JavaScript, color-coded status badges (green=OK, yellow=NON_COMPLIANT, red=CORRUPT, gray=ERROR), collapsible details sections for error messages
- [x] Update Packages/EbookMechanicCore/Sources/EbookMechanicCore/MarkdownReportGenerator.swift to include validationLevel column in table, add status column with emoji indicators (✅ OK, ⚠️ NON_COMPLIANT, ❌ CORRUPT, ⚡ ERROR), preserve existing format while adding new fields
- [x] Create ReportGeneratorFactory.swift that provides static method to get appropriate generator for each format, handles multiple formats by generating all requested reports with format-specific filenames (ebook_mechanic_report_TIMESTAMP.md, .json, .csv, .html)
- [x] Add Packages/EbookMechanicCore/Tests/EbookMechanicCoreTests/JSONReportGeneratorTests.swift with tests for valid JSON structure, proper status encoding, metadata completeness, and handling of special characters in file paths
- [x] Add CSVReportGeneratorTests.swift with tests for proper CSV escaping, header row correctness, summary row formatting, and handling of commas/quotes in reasons
- [x] Add HTMLReportGeneratorTests.swift with tests for valid HTML structure, embedded CSS presence, JavaScript-free fallback rendering, and XSS prevention in file paths and reasons
- [x] Update CLIConfiguration.swift to add --report-formats flag accepting comma-separated values (markdown,json,csv,html), default to markdown only for backward compatibility
- [x] Update main.swift in EbookMechanicCLI to generate all requested report formats after scan completes, display list of generated report files with full paths

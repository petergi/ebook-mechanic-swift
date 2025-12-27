# Phase 06: Specialized CLI Enhancements

This phase enhances the specialized EbookMechanicEPUBCLI and EbookMechanicPDFCLI tools with the new validation capabilities, reporting formats, and format-specific features that leverage the comprehensive validation from previous phases.

## Tasks

- [ ] Update Packages/EbookMechanicEPUBCLI/Sources/EbookMechanicEPUBCLI/main.swift to add --spec-check flag that enables epubcheck integration, --show-warnings flag to display EPUB spec warnings in addition to errors, --accessibility flag to specifically check EPUB accessibility compliance
- [ ] Add EPUBReportFormatter.swift to EbookMechanicEPUBCLI with EPUB-specific report formatting: group issues by EPUB component (metadata, manifest, spine, content docs), show EPUB version and features detected, highlight accessibility compliance status, format validation rules with spec references
- [ ] Create --fix-metadata command in EbookMechanicEPUBCLI that auto-repairs common metadata issues: adds missing dc:title, dc:identifier, dc:language elements, fixes invalid date formats, adds minimal required metadata for EPUB 3 compliance, backs up EPUB before modification
- [ ] Update Packages/EbookMechanicPDFCLI/Sources/EbookMechanicPDFCLI/main.swift to add --structure-check flag enabling deep PDF structure validation, --show-streams flag to analyze object stream compression, --encryption-info flag to display PDF encryption/security details
- [ ] Add PDFReportFormatter.swift to EbookMechanicPDFCLI with PDF-specific report formatting: show PDF version and features, list form fields and annotations if present, display encryption and permissions, show page count and size information, highlight conformance to PDF/A or PDF/X standards
- [ ] Create --optimize command in EbookMechanicPDFCLI that calls pdfcpu optimize to reduce file size: removes unused objects, compresses object streams, linearizes for web viewing, creates .optimized.pdf output preserving original
- [ ] Add --extract-metadata command to both specialized CLIs: EbookMechanicEPUBCLI extracts OPF metadata to JSON/YAML, EbookMechanicPDFCLI extracts PDF Info dictionary and XMP metadata, output saved to .metadata.json or .metadata.yaml alongside file
- [ ] Update EbookMechanicEPUBCLI tests to verify spec-check integration, metadata repair functionality, accessibility checking, and EPUB-specific reporting
- [ ] Update EbookMechanicPDFCLI tests to verify structure validation integration, optimization command, metadata extraction, and PDF-specific reporting
- [ ] Create shell completion updates for new flags in both specialized CLIs: regenerate completions for Bash, Zsh, Fish, PowerShell with new command options
- [ ] Add usage examples to Packages/EbookMechanicEPUBCLI/README.md and Packages/EbookMechanicPDFCLI/README.md demonstrating new commands with real-world scenarios
- [ ] Update Makefile.swift to add specialized-test target that runs tests for both EbookMechanicEPUBCLI and EbookMechanicPDFCLI, plus new specialized-install target for installing both tools together
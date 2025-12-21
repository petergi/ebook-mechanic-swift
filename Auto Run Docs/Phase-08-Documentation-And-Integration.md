# Phase 08: Documentation and Integration Guide

This phase creates comprehensive documentation for the new features, updates the existing docs, and provides integration guides for users upgrading from the basic validation to the enhanced validation system.

## Tasks

- [ ] Update swift/README.md with new features section describing external tool integration, enhanced reporting formats, parallel validation performance, and specialized CLI enhancements
- [ ] Create swift/docs/ExternalToolsGuide.md documenting epubcheck and pdfcpu installation for macOS (Homebrew), Linux (apt/dnf), and manual installation, configuration options, troubleshooting common issues, version compatibility matrix
- [ ] Create swift/docs/ReportFormats.md with detailed specification of each report format: Markdown (enhanced with status columns), JSON schema with example, CSV format and Excel compatibility notes, HTML features and browser compatibility
- [ ] Create swift/docs/ValidationLevels.md explaining the three validation levels: basic (header/EOF only), standard (structure + manifest), comprehensive (external tools), when to use each level, performance implications, accuracy trade-offs
- [ ] Update swift/docs/Architecture.md to document new components: ExternalToolRunner architecture, ValidationQueue design, parallel validation TaskGroup pattern, validation result caching strategy, report generator factory pattern
- [ ] Create swift/docs/MigrationGuide.md for users upgrading: backward compatibility notes (old reports still work), new CLI flags and their defaults, opting into external tools, performance tuning recommendations, breaking changes if any
- [ ] Add swift/docs/EPUBValidation.md with deep dive on EPUB validation: ZIP structure requirements, EPUB 2.0 vs 3.x differences, common compliance issues and fixes, accessibility checking details, metadata repair capabilities
- [ ] Add swift/docs/PDFValidation.md with deep dive on PDF validation: PDF structure components, cross-reference table validation, object stream handling, encryption detection, PDF/A and PDF/X compliance, optimization strategies
- [ ] Update CLAUDE.md at project root to include new make targets, CLI flags for all tools, report format options, external tool installation instructions, performance benchmarking commands
- [ ] Create swift/examples/ directory with sample reports: example-report.md, example-report.json, example-report.csv, example-report.html showing realistic validation results with various file statuses
- [ ] Add swift/examples/sample-usage.sh script demonstrating common workflows: basic validation scan, comprehensive validation with external tools, generating all report formats, using specialized CLIs, performance benchmarking
- [ ] Update shell completions in swift/completions/ for all new CLI flags across EbookMechanicCLI, EPUBMechanicCLI, and PDFMechanicCLI for Bash, Zsh, Fish, and PowerShell
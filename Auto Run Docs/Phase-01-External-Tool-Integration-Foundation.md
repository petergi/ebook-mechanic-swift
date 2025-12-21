# Phase 01: External Tool Integration Foundation

This phase establishes the foundation for integrating external validation tools (epubcheck for EPUB validation and pdfcpu for PDF validation) into EbookMechanic. By the end of this phase, you'll have a working prototype that can call external tools and return enhanced validation results for both EPUB and PDF files. The system will demonstrate improved validation accuracy beyond basic header checks.

## Tasks

- [ ] Create swift/EbookMechanicCore/Sources/EbookMechanicCore/ExternalToolRunner.swift with Process-based execution, stdout/stderr capture, exit code handling, timeout support, and error types for tool not found, execution failed, and timeout
- [ ] Add ExternalEPUBValidator.swift to EbookMechanicCore with epubcheck integration: detect epubcheck installation (check PATH and common locations like /usr/local/bin, /opt/homebrew/bin), execute epubcheck with -q flag, parse exit codes (0=valid, 1=warnings, 2+=errors), return enhanced ValidationResult with compliance level
- [ ] Add ExternalPDFValidator.swift to EbookMechanicCore with pdfcpu integration: detect pdfcpu installation, execute pdfcpu validate command with -q flag, parse output for structure errors, return ValidationResult with detailed PDF compliance status
- [ ] Update FileValidator.swift to add optional useExternalTools parameter (default false) to validateFile method, when true call external validators for EPUB and PDF formats, fall back to built-in validation if external tools not available, preserve existing validation logic as fallback
- [ ] Create ValidationLevel enum in Models.swift with cases: basic (current header/EOF checks), standard (current + manifest validation), comprehensive (external tool validation), and update ValidationResult to include validationLevel property
- [ ] Add swift/EbookMechanicCore/Tests/EbookMechanicCoreTests/ExternalToolRunnerTests.swift with tests for successful execution with captured output, handling of non-zero exit codes, timeout behavior, and tool-not-found errors
- [ ] Add ExternalEPUBValidatorTests.swift with tests for valid EPUB detection, non-compliant EPUB handling, corrupt file handling, fallback to built-in validation when epubcheck missing, and exit code interpretation
- [ ] Add ExternalPDFValidatorTests.swift with tests for valid PDF detection, structure error detection, fallback to built-in validation when pdfcpu missing, and error output parsing
- [ ] Update swift/EbookMechanicCLI/Sources/EbookMechanicCLI/CLIConfiguration.swift to add --external-tools flag with description "Use external validation tools (epubcheck, pdfcpu) for comprehensive validation"
- [ ] Update swift/EbookMechanicCLI/Sources/EbookMechanicCLI/main.swift to pass useExternalTools parameter from CLI config to FileValidator, display validation level in progress output, show warning message if external tools requested but not found
- [ ] Create swift/test-external-tools.sh script that generates one valid EPUB, one invalid EPUB, one valid PDF, one corrupt PDF in temp directory, runs ebook-mechanic with and without --external-tools flag, displays side-by-side validation results comparing basic vs comprehensive validation
- [ ] Update swift/Makefile to add test-external-validation target that builds CLI in debug mode and executes test-external-tools.sh script
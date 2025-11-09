# EbookMechanic Swift - Development Tasks

This document tracks ongoing and planned development tasks for the Swift implementation of EbookMechanic.

## Current Status (November 2025)

### ✅ Completed

- [x] Core library implementation (EbookMechanicCore)
- [x] Full-featured CLI (EbookMechanicCLI)
- [x] macOS SwiftUI app (EbookMechanicApp)
- [x] EPUB-focused CLI utility (EPUBMechanicCLI)
- [x] PDF-focused CLI utility (PDFMechanicCLI)
- [x] Xcode workspace integration
- [x] Comprehensive test coverage (133+ tests)
- [x] Swift 6 strict concurrency compliance
- [x] Documentation and READMEs

## High Priority Tasks

### 🔴 Testing & Quality Assurance

- [ ] **Expand EPUBMechanicCLI test coverage**
  - Current: 2 basic tests
  - Target: 20+ tests covering validation, repair, edge cases
  - Priority: High
  - Files: `swift/EPUBMechanicCLI/Tests/`

- [ ] **Expand PDFMechanicCLI test coverage**
  - Current: 2 basic tests
  - Target: 20+ tests covering validation, repair, corruption patterns
  - Priority: High
  - Files: `swift/PDFMechanicCLI/Tests/`

- [ ] **Integration tests for specialized CLIs**
  - Test against real corrupted files
  - Verify repair functionality end-to-end
  - Test error handling and edge cases
  - Priority: High

### 🔴 Build & Distribution

- [ ] **Add Makefile targets for specialized CLIs**
  - Build targets: `make epub-build`, `make pdf-build`
  - Install targets: `make epub-install`, `make pdf-install`
  - Test targets: `make epub-test`, `make pdf-test`
  - Priority: High
  - Files: `swift/Makefile`

- [ ] **Create release builds**
  - Build optimized release versions
  - Test performance improvements
  - Document build artifacts
  - Priority: High

- [ ] **Shell completion generation**
  - Generate completions for EPUBMechanicCLI
  - Generate completions for PDFMechanicCLI
  - Install to standard locations
  - Priority: Medium
  - Reference: `swift/EbookMechanicCLI/Sources/EbookMechanicCLI/ShellCompletion.swift`

## Medium Priority Tasks

### 🟡 Feature Enhancements

- [ ] **Improve error reporting in specialized CLIs**
  - More detailed error messages
  - Suggestions for common issues
  - Color-coded output (optional)
  - Priority: Medium

- [ ] **Add progress bars to specialized CLIs**
  - Visual progress for large scans
  - Percentage completion
  - ETA calculations
  - Priority: Medium

- [ ] **Batch processing mode**
  - Process multiple directories
  - Parallel scanning with configurable concurrency
  - Aggregate reporting
  - Priority: Medium

- [ ] **Configuration file support**
  - JSON/YAML config files
  - User-specific defaults
  - Project-specific settings
  - Priority: Low

### 🟡 Documentation

- [ ] **Add usage examples to READMEs**
  - Common workflows
  - Troubleshooting guide
  - Performance tips
  - Priority: Medium

- [ ] **Create DocC documentation**
  - API documentation for EbookMechanicCore
  - Usage guides for CLIs
  - Architecture overview
  - Priority: Medium
  - Reference: `swift/Docs/DOCC_SETUP.md`

- [ ] **Video tutorials**
  - CLI usage demos
  - macOS app walkthrough
  - Common repair scenarios
  - Priority: Low

## Low Priority Tasks

### 🟢 Code Quality

- [ ] **Refactor duplicated code between CLIs**
  - Extract common argument parsing
  - Shared progress printing utilities
  - Unified error handling
  - Priority: Low

- [ ] **Performance profiling**
  - Identify bottlenecks
  - Optimize file I/O
  - Memory usage analysis
  - Priority: Low

- [ ] **Code coverage analysis**
  - Generate coverage reports
  - Identify untested code paths
  - Improve test coverage to 90%+
  - Priority: Low

### 🟢 Platform Support

- [ ] **iOS companion app**
  - Share code with macOS app
  - Document scanning integration
  - iCloud Drive support
  - Priority: Low

- [ ] **watchOS complications**
  - Quick scan status
  - Library health metrics
  - Priority: Very Low

## Future Ideas

### 💡 Advanced Features

- [ ] **Machine learning-based corruption detection**
  - Train model on corrupted vs valid files
  - Predict corruption likelihood
  - Suggest repair strategies
  - Priority: Research

- [ ] **Cloud storage integration**
  - Scan Dropbox/Google Drive
  - Automatic cloud backup
  - Sync repair status
  - Priority: Research

- [ ] **Web service API**
  - REST API for validation/repair
  - Docker container deployment
  - Rate limiting and authentication
  - Priority: Research

- [ ] **Plugin system**
  - Custom validators
  - Format-specific repairers
  - Third-party integrations
  - Priority: Research

## Task Management

### Adding New Tasks

1. Identify the task category (Testing, Features, Documentation, etc.)
2. Assign a priority (🔴 High, 🟡 Medium, 🟢 Low)
3. Add checkbox `- [ ]` for tracking
4. Include relevant file paths
5. Note any dependencies

### Completing Tasks

1. Mark checkbox `- [x]`
2. Add completion date
3. Link to relevant commit/PR
4. Move to "Completed" section if major

### Priority Levels

- **🔴 High**: Critical for stability, security, or usability
- **🟡 Medium**: Important for user experience or maintainability
- **🟢 Low**: Nice to have, quality of life improvements
- **💡 Ideas**: Future consideration, research needed

## Contributing

When working on tasks:

1. Check this file for available tasks
2. Assign yourself by adding `(Assigned: Your Name)`
3. Create a branch for your work
4. Update task status as you progress
5. Mark complete when done and committed
6. Update relevant documentation

## Related Documents

- [NEXT.md](NEXT.md) - Immediate next steps and priorities
- [CLAUDE.md](../CLAUDE.md) - Project overview and architecture
- [README.md](README.md) - User-facing documentation
- [Docs/PLAN.md](Docs/PLAN.md) - Long-term roadmap

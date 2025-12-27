# ADR 002: EPUBMechanicCLI Feature Enhancements

## Status
Proposed

## Context
The `EPUBMechanicCLI` has been enhanced with new features to provide more comprehensive EPUB validation and repair capabilities. These enhancements include new command-line flags for detailed specification checking, warning display, accessibility compliance, and a metadata repair function. This ADR documents the decisions behind these feature additions.

## Decision
The following features have been added to `EPUBMechanicCLI`:

1.  **`--spec-check` flag**: Enables detailed EPUB specification compliance checks using `epubcheck` integration.
2.  **`--show-warnings` flag**: Displays detailed warnings from EPUB specification compliance checks.
3.  **`--accessibility` flag**: Performs EPUB accessibility compliance checks.
4.  **Enhanced `EPUBReportFormatter.swift`**: Provides EPUB-specific report formatting, including grouping issues by EPUB component, showing EPUB version and features, highlighting accessibility compliance status, and formatting validation rules.
5.  **`--fix-metadata` command**: Automatically repairs common metadata issues in EPUB files, such as adding missing `dc:title`, `dc:identifier`, and `dc:language` elements, fixing invalid date formats, and ensuring minimal required metadata for EPUB 3 compliance. This command also creates a backup of the EPUB before modification.

## Consequences
*   **Positive**:
    *   **Improved Validation Depth**: Users can perform more thorough checks on EPUB files.
    *   **Better User Feedback**: Detailed warnings and accessibility checks provide more actionable information.
    *   **Automated Repair**: The `--fix-metadata` command automates common EPUB metadata issues, saving manual effort.
    *   **Enhanced Reporting**: EPUB-specific reporting makes it easier to understand validation results.
*   **Negative**:
    *   **Increased Complexity**: The CLI now has more options, potentially increasing the learning curve for new users.
    *   **Dependency on `epubcheck`**: `--spec-check` and `--accessibility` features rely on the `epubcheck` tool being installed and configured correctly.

## Alternatives Considered
*   **Internal EPUB Parser/Validator**: Instead of integrating `epubcheck`, an internal Swift-based EPUB parser and validator could have been developed. This was rejected due to the significant effort required to implement full EPUB specification compliance from scratch and maintain it with evolving standards.

## Specific Implementation Details
*   `EPUBMechanicCLI/Sources/EPUBMechanicCLI/main.swift`: Modified to include the new flags and logic for handling them.
*   `EPUBMechanicCLI/Sources/EPUBMechanicCLI/EPUBReportFormatter.swift`: Modified to enhance reporting capabilities.
*   `swift/EbookMechanicCore/Sources/EbookMechanicCore/Validation/ExternalValidators.swift`: Updated to accept `showWarnings` and `accessibility` parameters for `epubcheck` execution.
*   `swift/EbookMechanicCore/Sources/EbookMechanicCore/Support/ZipArchive.swift`: Used for reading and writing EPUB files during metadata repair.
*   `Foundation.XMLDocument`: Utilized for parsing and modifying the OPF XML content during metadata repair.
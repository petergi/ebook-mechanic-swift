# ADR 003: PDFMechanicCLI Feature Enhancements

## Status
Proposed

## Context
The `PDFMechanicCLI` has been enhanced with new features to provide more comprehensive PDF validation and utility capabilities. These enhancements include new command-line flags for detailed structure validation, stream information, encryption details, and commands for optimization and metadata extraction. This ADR documents the decisions behind these feature additions.

## Decision
The following features have been added to `PDFMechanicCLI`:

1.  **`--structure-check` flag**: Enables deep PDF structure validation using `pdfcpu`.
2.  **`--show-streams` flag**: Displays object stream compression analysis.
3.  **`--encryption-info` flag**: Displays PDF encryption and security details.
4.  **Enhanced `PDFReportFormatter.swift`**: Provides PDF-specific report formatting, including PDF version and features, form fields, annotations, encryption/permissions, page count, size, and conformance to PDF/A or PDF/X standards.
5.  **`--optimize` command**: Calls `pdfcpu optimize` to reduce file size by removing unused objects, compressing object streams, and linearizing for web viewing, creating a `.optimized.pdf` output while preserving the original.
6.  **`--extract-metadata` command**: Extracts PDF Info dictionary and XMP metadata, saving it to a `.metadata.json` or `.metadata.yaml` file alongside the original PDF.

## Consequences
*   **Positive**:
    *   **Improved Validation Depth**: Users can perform more thorough checks on PDF files, including structural integrity and security aspects.
    *   **Enhanced Information**: Provides detailed insights into PDF internals (streams, encryption).
    *   **Automated Optimization**: The `--optimize` command helps reduce file sizes for better distribution and performance.
    *   **Metadata Portability**: `--extract-metadata` allows easy access and integration of PDF metadata with other systems.
*   **Negative**:
    *   **Increased Complexity**: The CLI now has more options, potentially increasing the learning curve for new users.
    *   **Dependency on `pdfcpu`**: All these features rely heavily on the `pdfcpu` tool being installed and configured correctly.

## Alternatives Considered
*   **Internal PDF Parser/Validator**: Instead of integrating `pdfcpu`, an internal Swift-based PDF parser and validator could have been developed. This was rejected due to the significant effort required to implement full PDF specification compliance from scratch and maintain it, as well as the existing robust capabilities of `pdfcpu`.

## Specific Implementation Details
*   `PDFMechanicCLI/Sources/PDFMechanicCLI/main.swift`: Modified to include the new flags and logic for handling them, and to implement the `--optimize` and `--extract-metadata` commands.
*   `PDFMechanicCLI/Sources/PDFMechanicCLI/PDFReportFormatter.swift`: Modified to enhance reporting capabilities.
*   `swift/EbookMechanicCore/Sources/EbookMechanicCore/Validation/ExternalValidators.swift`: Updated to include functions for `getPdfInfo` and `getPdfStreamInfo` (though `getPdfStreamInfo` is a placeholder).
*   `Foundation.JSONSerialization` and custom YAML conversion logic: Utilized for metadata extraction to JSON/YAML formats.
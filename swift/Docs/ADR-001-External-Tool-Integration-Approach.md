# ADR 001: External Tool Integration Approach for `pdfcpu` and `epubcheck`

## Status
Accepted

## Context
EbookMechanic needs to integrate external validation tools (`epubcheck` for EPUB, `pdfcpu` for PDF) for comprehensive validation beyond basic internal checks. These tools are primarily command-line interfaces (CLIs), written in different languages (Java for `epubcheck`, Go for `pdfcpu`). The Swift project aims for a native, performant solution. Initial thoughts included direct library integration for better performance and API control.

## Decision
To integrate `pdfcpu` and `epubcheck` into `EbookMechanicCore` (Swift), the primary approach will be to execute their respective CLIs as external processes and parse their standard output and error streams.

## Consequences
*   **Positive**:
    *   **Simplicity of Integration**: Avoids complex FFI (Foreign Function Interface) or C bridging required for direct Go/Java library integration into Swift.
    *   **Tool Agnosticism**: Easier to swap out or upgrade external tools as long as their CLI interface remains compatible.
    *   **Leverages Existing Functionality**: Reuses the robust, feature-complete CLIs of `epubcheck` and `pdfcpu` directly.
    *   **Isolation**: External tools run in separate processes, preventing crashes in the external tool from directly affecting the EbookMechanic application.
*   **Negative**:
    *   **Performance Overhead**: Spawning new processes for each validation can introduce overhead compared to direct library calls, although mitigated by parallel processing.
    *   **Parsing Complexity**: Relies on parsing text output, which can be fragile if the external tools' output formats change.
    *   **Limited Direct Control**: Interaction is limited to CLI arguments and parsing output, without direct programmatic access to internal tool logic or data structures.
    *   **Dependency on System PATH**: Requires external tools to be installed and discoverable in the system's PATH.

## Alternative Considered
*   **Direct Library Integration**: Building `pdfcpu` as a C library and bridging to Swift, or finding a Swift/C/Objective-C wrapper for `epubcheck` (which is Java-based). This was rejected due to:
    *   Significant complexity and development effort for FFI/bridging.
    *   Maintenance burden of managing Go/Java build systems within a Swift project.
    *   Lack of readily available Swift-compatible wrappers for these specific tools.

## Specific Implementation Details
*   `ExternalToolRunner.swift`: A utility struct to abstract `Process`-based CLI execution, handling `stdout`, `stderr`, exit codes, and timeouts.
*   `ExternalEPUBValidator.swift` and `ExternalPDFValidator.swift`: Wrappers that use `ExternalToolRunner` to execute `epubcheck` and `pdfcpu` respectively.
*   `PDFStructureValidator.swift`: Acts as a dedicated parser for `pdfcpu` CLI output, structuring raw text into `PDFValidationResult` objects. This decouples parsing logic from CLI execution.
*   `ValidationQueue`: Introduced to manage concurrency and rate-limit external tool calls, mitigating performance overhead.
*   CLI Flags: Consolidated external tool flags (`--use-epubcheck`, `--use-pdfcpu`) into a single `--use-external-tools` flag for user simplicity.

# Gemini's Role in EbookMechanicCore

This file outlines the role of the Gemini AI assistant in the EbookMechanicCore package.

## Project Understanding

I understand that this directory contains the `EbookMechanicCore` package, which is the core library for the Swift implementation of the EbookMechanic project. This package provides the fundamental functionality for scanning, validating, and repairing ebook files.

Key components of this package include:

*   `FileScanner`: An actor-based component for concurrent file processing.
*   `FileValidator`: A set of validators for different ebook formats.
*   `FileRepairer`: An engine for automatically repairing corrupted files.
*   A custom `ZipArchive` implementation.
*   `MarkdownReportGenerator`: A component for generating Markdown reports.

This package is written in pure Swift, has no external dependencies, and is designed to be thread-safe using Swift's modern concurrency features.

## My Role

My purpose is to assist in the development and maintenance of the `EbookMechanicCore` package. I can help with a variety of tasks, including:

*   **Adding Support for New Formats:** Extending the validation and repair capabilities to support new ebook formats.
*   **Performance Optimization**: Implemented a parallel validation system using Swift actors and a `TaskGroup` in the `FileScanner`. This includes a `ValidationQueue` for fair task distribution and a caching mechanism in the `FileValidator` to avoid re-validating unchanged files.
*   **Improving Existing Algorithms:** Enhancing the performance and accuracy of the file scanning, validation, and repair algorithms.
*   **Writing Unit Tests:** Creating new unit tests to ensure the reliability and correctness of the core logic.
*   **Refactoring Code:** Improving the structure and quality of the codebase while maintaining its performance and correctness.
*   **Writing Documentation:** Documenting the public APIs of the package and providing detailed explanations of its internal workings.

I will follow the existing coding style and architectural patterns of the package, with a strong focus on performance, thread safety, and code quality.
# Gemini's Role in EbookMechanic

This file outlines the role of the Gemini AI assistant in the EbookMechanic project.

## Project Understanding

Based on the project's documentation, I understand that EbookMechanic is a comprehensive toolkit for managing ebook libraries. Its primary functions are to validate, repair, and organize ebook files in various formats (EPUB, MOBI, AZW3, AZW4, PDF).

The project has a modular architecture, with a core library in Swift (`EbookMechanicCore`) that provides the main functionality. This core library is used by several clients:

*   A full-featured command-line interface (`EbookMechanicCLI`).
*   Specialized command-line tools for EPUB (`EPUBMechanicCLI`) and PDF (`PDFMechanicCLI`) files.
*   A native macOS application with a SwiftUI interface (`EbookMechanicApp`).

The project is well-structured, with a clear separation of concerns, a comprehensive test suite, and a robust build system based on Makefiles.

## My Role

My purpose is to assist in the development and maintenance of the EbookMechanic project. I can help with a variety of tasks, including:

*   **Performance Optimization**: Implemented a parallel validation system using Swift actors and a `TaskGroup` to significantly improve scanning performance. This includes a `ValidationQueue` for fair task distribution and a caching mechanism in the `FileValidator` to avoid re-validating unchanged files.
*   **Code Generation:** Writing new code for features, bug fixes, or improvements in Swift.
*   **Code Refactoring:** Improving the structure and quality of the existing codebase.
*   **Test Generation:** Creating new unit tests and UI tests to ensure the project's reliability.
*   **Documentation:** Writing and updating documentation, including README files, comments, and other explanatory materials.
*   **Bug Fixing:** Identifying and fixing bugs in the code.
*   **Project Management:** Helping to manage tasks, track progress, and organize the project.

I will strive to adhere to the project's existing conventions, coding style, and architectural patterns. I will also make use of the project's build and test systems to ensure that my contributions are of high quality.

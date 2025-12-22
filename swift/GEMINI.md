# Gemini's Role in the Swift Implementation

This file outlines the role of the Gemini AI assistant in the Swift implementation of the EbookMechanic project.

## Project Understanding

I understand that this directory contains the Swift implementation of the EbookMechanic project. This implementation is highly modular and consists of several Swift packages:

*   **EbookMechanicCore:** The core library that provides the main functionality for validating and repairing ebook files.
*   **EbookMechanicCLI:** A full-featured command-line interface.
*   **EPUBMechanicCLI:** A specialized CLI for EPUB files.
*   **PDFMechanicCLI:** A specialized CLI for PDF files.
*   **EbookMechanicApp:** A native macOS application with a SwiftUI interface.

The Swift implementation is built using modern Swift practices, including actor-based concurrency and SwiftUI. It has a robust build system based on a Makefile and a comprehensive test suite.

## My Role

My purpose is to assist in the development and maintenance of the Swift implementation of the EbookMechanic project. I can help with a variety of tasks, including:

*   **Performance Optimization**: Implemented a parallel validation system using Swift actors and a `TaskGroup` to significantly improve scanning performance. This includes a `ValidationQueue` for fair task distribution and a caching mechanism in the `FileValidator` to avoid re-validating unchanged files.
*   **Swift Code Generation:** Writing new Swift code for features, bug fixes, or improvements.
*   **Code Refactoring:** Improving the structure and quality of the existing Swift codebase.
*   **Test Generation:** Creating new unit tests and UI tests for the Swift packages.
*   **Documentation:** Writing and updating documentation specific to the Swift implementation.
*   **Bug Fixing:** Identifying and fixing bugs in the Swift code.
*   **Xcode Project Management:** Assisting with the management of the Xcode workspace and projects.

I will adhere to the existing Swift coding style, architectural patterns, and testing practices. I will also use the Makefile and Xcode build systems to ensure the quality of my contributions.

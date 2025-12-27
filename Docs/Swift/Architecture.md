# Architecture

This document describes the Swift core architecture for validation, reporting, and external tool integration.

## Core Flow

1. **FileScanner** enumerates ebook files and dispatches validation tasks.
2. **ValidationQueue** prioritizes files and throttles external tool calls.
3. **FileValidator** runs format-specific validation (EPUB/MOBI/AZW/PDF).
4. **ExternalToolRunner** invokes epubcheck/pdfcpu when comprehensive validation is enabled.
5. **ValidationCache** avoids re-validating unchanged files.
6. **ReportGeneratorFactory** produces Markdown, JSON, CSV, and HTML reports.

## Concurrency Model

- `FileScanner` uses `TaskGroup` for concurrent validation.
- A semaphore limits the number of in-flight validations.
- External tool calls are rate-limited by `ValidationQueue` + `ExternalToolRunner`.

## Caching Strategy

- Fingerprints and validation outcomes are cached for unchanged files.
- Cache can be disabled with `--no-cache` or reduced by lower cache size.

## External Tools

- The runner resolves executables on PATH and common directories.
- Each invocation is time-bounded with optional timeout handling.
- Failures are reported as `validationError` to distinguish tool issues from corrupted files.

## Reporting

- Scan results are normalized into `ScanResult`.
- Format-specific report generators map the same data into each output.
- HTML reports include EPUB compliance sections with grouped errors/warnings.

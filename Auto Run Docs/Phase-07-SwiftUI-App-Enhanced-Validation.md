# Phase 07: SwiftUI App Enhanced Validation Display

This phase updates the native macOS SwiftUI app to display the enhanced validation results, compliance details, and multi-format reports with an improved UI that shows the comprehensive validation information.

## Tasks

- [ ] Update swift/EbookMechanicApp/Sources/EbookMechanicApp/ScanOptions.swift to add @Published properties: useExternalTools (bool), selectedReportFormats (Set of ReportFormat), maxConcurrentValidations (int), showPerformanceStats (bool)
- [ ] Add UI controls to ContentView.swift for external tools toggle with system check indicator (green dot if tools found, yellow if missing with "Install" button), report format multi-select picker using checkboxes, concurrency slider with label showing current value, performance stats toggle
- [ ] Create ValidationDetailView.swift as sheet/popover displaying full validation results for selected file: format-specific details (EPUB compliance issues, PDF structure validation), color-coded status with icons, expandable sections for errors/warnings, copy-to-clipboard buttons for error messages
- [ ] Update ScanViewModel.swift to expose validationResults dictionary mapping file URLs to full ValidationResult objects, track EPUBComplianceResult and PDFValidationResult separately, provide computed properties for result filtering and grouping
- [ ] Add ResultsListView.swift with three-section layout: corrupted files with expandable details, non-compliant files (passed structure but failed spec), files with warnings, each section collapsible with count badge, tap file to show ValidationDetailView
- [ ] Create ReportExportView.swift as sheet for report export options: checkboxes for each report format, destination folder picker, "Export All" button that generates selected report formats, progress indicator during export, completion notification with "Reveal in Finder" button
- [ ] Add PerformanceStatsView.swift displaying validation metrics when enabled: files validated per second chart, average time by format bar chart, external tool usage stats, cache hit rate indicator, parallel efficiency gauge
- [ ] Update ContentView.swift to add "View Results" button that presents ResultsListView after scan completes, "Export Reports" button that presents ReportExportView, "Performance" button that presents PerformanceStatsView if enabled
- [ ] Create InstallToolsView.swift as alert/sheet when external tools requested but not found: lists missing tools (epubcheck, pdfcpu), shows Homebrew install commands, "Copy Command" buttons for each tool, "Check Again" button to re-detect after installation
- [ ] Add app preferences window (Settings scene) with General tab for default options: default report formats, default concurrency level, enable external tools by default, show performance stats by default
- [ ] Update ScanViewModelTests.swift to test external tools integration, report format selection handling, performance metrics collection, validation result filtering
- [ ] Add ResultsListViewTests.swift to verify correct grouping of validation results, proper display of compliance vs corruption status, tap handling for detail view presentation
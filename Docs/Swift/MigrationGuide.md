# Migration Guide

This guide summarizes changes for users upgrading to the enhanced validation and reporting system.

## Backward Compatibility

- Existing Markdown reports still work and remain the default format.
- Core validation continues to run without external tools.

## New CLI Flags

- `--report-formats` replaces the older single-format flag.
- `--external-tools` enables epubcheck/pdfcpu validation.
- `--max-concurrent` controls parallel validation concurrency.
- `--no-cache` disables validation caching.
- `--performance-stats` emits throughput metrics.

## Flag Changes

| Old | New |
| --- | --- |
| `--report-format markdown` | `--report-formats markdown` (preferred; still supports `--report-format`) |
| `--use-epubcheck` | `--external-tools` (recommended for full EPUB + PDF checks) |

## Recommended Upgrade Steps

1. Update your scripts to use `--report-formats`.
2. Add `--external-tools` if you need spec compliance checks.
3. Tune concurrency with `--max-concurrent` if scans are CPU-bound.
4. Review new report outputs in `Docs/Swift/examples/`.

## App Updates

- New results view groups corrupted, non-compliant, and warning files.
- Report export supports multi-format generation.
- Performance stats are available when enabled in settings.

# Validation Levels

EbookMechanic reports a validation level for each file to indicate how deep the checks went. The level is derived from the validator strategy and whether external tools were used.

## Levels

### Basic

- Fast structural checks (e.g., headers, EOF markers, ZIP signatures).
- Ideal for large libraries where speed matters.
- Default when external tools are disabled.

### Standard

- Deeper structural checks (manifest/container validation, PDF structure probing).
- Balances accuracy with throughput.
- Used when built-in validators perform deeper checks.

### Comprehensive

- Includes external tools (epubcheck, pdfcpu).
- Best for spec compliance and detailed diagnostics.
- Slower per file; use `--max-concurrent` to tune throughput.

## When to Use

- **Quick triage:** Basic
- **Pre-publication QA:** Standard
- **Spec compliance audits:** Comprehensive

## Performance Notes

- External tools dominate runtime; consider lowering concurrency if CPU-bound.
- Cache hits can reduce repeat scans; disable with `--no-cache` if you need fresh checks.

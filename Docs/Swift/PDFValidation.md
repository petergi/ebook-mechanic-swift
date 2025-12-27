# PDF Validation

EbookMechanic validates PDF and AZW4 files with lightweight checks and optional deep structure inspection.

## Core PDF Checks

- `%PDF-` header detection
- EOF marker validation (`%%EOF`)
- Basic xref and page tree sanity checks

## Deep Validation (pdfcpu)

When `--external-tools` is enabled, pdfcpu performs:

- Cross-reference table verification
- Object stream parsing
- Page tree integrity checks
- Stream error detection

## Encryption and Standards

- Encryption is detected and reported in validation details.
- When pdfcpu reports PDF/A or PDF/X conformance, the result is surfaced in reports.

## AZW4 Notes

AZW4 files are treated as PDFs with Kindle-specific metadata. Structure checks mirror PDF validation, and repairs focus on header/EOF integrity.

## Optimization Tips

- Use `--max-concurrent` to balance CPU usage.
- External tools add accuracy but increase runtime; run them on final QA passes.

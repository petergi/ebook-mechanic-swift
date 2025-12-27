# Report Formats

EbookMechanic can emit multiple report formats in a single run. Use `--report-formats markdown,json,csv,html` to select output types.

## Markdown

- Human-readable summary table with validation level + status.
- Per-file sections include reasons, sizes, and compliance details.

Example snippet:

```markdown
| Format | Corrupted | Total | Validation Level | Status |
| --- | --- | --- | --- | --- |
| EPUB | 1 | 12 | COMPREHENSIVE | ⚠️ |
```

## JSON

- Structured data for automation.
- Encodes summary, corrupted files, and repair results.

Example:

```json
{
  "metadata": {
    "timestamp": "2025-01-01T12:00:00Z",
    "rootDirectory": "/Books",
    "corruptedDirectoryName": "CORRUPTED",
    "elapsedTime": 0.0,
    "validationLevel": "standard"
  },
  "summary": {
    "totalFiles": 42,
    "corruptedFiles": 2,
    "breakdowns": { "epub": { "total": 10, "corrupted": 1 } },
    "emptyFolders": 3
  },
  "corruptedFiles": [],
  "repairs": []
}
```

## CSV

- Spreadsheet-friendly output.
- First section lists corrupted files, followed by summary blocks.
- Use Excel/Numbers with comma delimiter.

Header:

```text
FilePath,Status,Format,Reason,FileSize,Fingerprint
```

## HTML

- Styled report with status badges and compliance sections.
- Includes grouped EPUB compliance details and PDF structure notes.
- Tested in Safari/Chrome/Firefox.

Sample files live in `Docs/Swift/examples/`.

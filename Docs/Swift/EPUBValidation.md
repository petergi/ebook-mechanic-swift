# EPUB Validation

EbookMechanic validates EPUB files at multiple depths, from ZIP structure checks to spec compliance with epubcheck.

## ZIP Structure Requirements

- `mimetype` must be the first entry and stored (no compression).
- `META-INF/container.xml` must exist and reference the OPF package.
- The archive must be a valid ZIP file without corruption.

## EPUB 2.0 vs 3.x

- **EPUB 2.0** uses NCX navigation and older metadata conventions.
- **EPUB 3.x** uses HTML5 nav documents and richer metadata.
- The validator accepts both but applies spec-specific expectations.

## Common Compliance Issues

- Missing or misplaced `mimetype` file.
- Broken manifest references in OPF.
- Invalid spine order or missing nav/NCX.
- Media type mismatches (e.g., incorrect `application/xhtml+xml`).

## Accessibility Checks

When epubcheck is enabled, accessibility conformance is reported alongside warnings:

- Missing landmarks or headings
- Missing alt text for images
- Incorrect ARIA roles

## Repair Capabilities

- Normalizes EPUB ZIP layout.
- Repairs missing container/OPF metadata when possible.
- Rewrites invalid manifest entries where safe.

## Tips

- Run `--external-tools` for comprehensive checks before publishing.
- Use `--normalize-epubs` to standardize archive layout for long-term stability.

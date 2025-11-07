add completion generation for the cli. suppport bash, zsh, fish, and powershell
=============

✅ **COMPLETED** — Shell completion generation is now available for the CLI.

Overview
--------
The new PDF verifier computes a content-based fingerprint for PDFs instead of relying on raw file hashes. This makes verification stable across metadata-only changes (title/author/date) while still detecting content changes.

Shell Completions
-----------------
The CLI now supports generating completion scripts for multiple shells:

**Supported shells:**
- Bash
- Zsh
- Fish
- PowerShell

**Generate completions:**
```bash
# Generate all completion scripts at once
make cli-completions

# Or generate individually
ebook-mechanic --generate-completion bash > ebook-mechanic.bash
ebook-mechanic --generate-completion zsh > _ebook-mechanic
ebook-mechanic --generate-completion fish > ebook-mechanic.fish
ebook-mechanic --generate-completion powershell > ebook-mechanic.ps1
```

**Install completions:**

*Bash:*
```bash
cp completions/ebook-mechanic.bash /usr/local/etc/bash_completion.d/
# or on Linux:
cp completions/ebook-mechanic.bash /etc/bash_completion.d/
```

*Zsh:*
```bash
cp completions/_ebook-mechanic /usr/local/share/zsh/site-functions/
# Then restart your shell or run: compinit
```

*Fish:*
```bash
cp completions/ebook-mechanic.fish ~/.config/fish/completions/
# Completions are loaded automatically
```

*PowerShell:*
```powershell
# Add to your PowerShell profile
. /path/to/completions/ebook-mechanic.ps1
```

PDF Verifier Overview
--------------------
The new PDF verifier computes a content-based fingerprint for PDFs instead of relying on raw file hashes. This makes verification stable across metadata-only changes (title/author/date) while still detecting content changes.

Behavior
--------
- Primary strategy: extract page text (if available), normalize Unicode (NFC), collapse whitespace, and hash the resulting normalized text in page order.
- Fallback: for pages with no text, render a thumbnail and hash the image bytes. The rendered thumbnail size is configurable.
- If the PDF is encrypted, the verifier returns an explicit `encrypted` status instead of attempting to extract content.
- If PDF parsing is unavailable (non-macOS CI) or fails, the verifier falls back to returning a raw file SHA256 hash.

API
---
- `PDFVerifier.Config(thumbnailSize: CGSize, useTextExtraction: Bool)` — configure rendering size and whether to attempt text extraction.
- `PDFVerifier.fingerprintResult(for: URL, config: Config = .default) -> FingerprintResult`
  - `FingerprintResult` cases:
    - `.content(String)` — content-based fingerprint (stable)
    - `.fileHash(String)` — raw file hash fallback
    - `.encrypted` — document is encrypted / password-protected
    - `.unavailable(String)` — could not compute fingerprint (reason)

Integration
-----------
`FileValidator.validatePDF` now calls `PDFVerifier.fingerprintResult` and attaches the `FingerprintResult` to the returned `ValidationResult.fingerprint` property. This allows higher-level callers to surface fingerprint information in reports.

Testing
-------
Unit tests were added to `EbookMechanicCoreTests`:
- `PDFVerifierTests` covers:
  - Stable fingerprint across metadata changes (text and image PDFs)
  - Fingerprint changes when content changes
  - Encrypted PDF detection (created using `PDFDocument.write(to:withOptions:)` and PDF write options)

How to run
----------
Run the core tests:

```bash
cd /path/to/EbookMechanic/swift
make core-test
```

Or run only the verifier tests:

```bash
swift test --package-path EbookMechanicCore --filter PDFVerifierTests
```

Generate shell completions:

```bash
make cli-completions
```

Notes and next steps
--------------------
- Encryption handling currently marks PDFs as encrypted and does not accept passwords; we may add a password callback or keychain integration later.
- On non-macOS platforms, PDFKit may be unavailable — the verifier will return a raw file hash in that case. Consider integrating a cross-platform PDF parsing library if needed.
- Rendering parameters can be tuned via `PDFVerifier.Config` to trade stability vs speed.

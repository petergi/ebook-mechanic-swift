# Swift Workspace – EbookMechanic

This directory contains a modular Swift rewrite of the Go-based EbookMechanic toolchain. It ships as an Xcode workspace with three components that share a common Swift package and expose runnable test suites:

- `EbookMechanicCore` – a Swift Package library with the scanning, validation, repair, and reporting engine. It exposes an actor-based `FileScanner`, format-specific validators, and a Markdown report generator. Comprehensive XCTest coverage mirrors the Go implementation’s behaviours.

### EPUB Normalization Details
- Rebuilds EPUBs into a canonical ZIP layout:
  - `mimetype` first and uncompressed, with exact contents `application/epub+zip`.
  - All other entries are deflated (compression method 8) for compact, deterministic output.
  - File names are UTF-8 with the language encoding flag set.
  - Timestamps/attributes are normalized to fixed values for reproducible builds.
- Ensures `META-INF/container.xml` exists and is correctly cased; synthesizes a minimal one if missing.
- Removes extraneous files (e.g. `__MACOSX/*`, `.*.DS_Store`, `Thumbs.db`, `desktop.ini`).
- Performs light metadata normalization on text-based OPF files (UTF-8 re-encoding, normalized newlines).
- Dry-run support reports what would change; `--force-normalize` re-normalizes even already normalized files.

- `EbookMechanicCLI` – a command-line application that wraps the core package, providing a fast text interface with progress feedback, optional repair/move/delete automation, Markdown report generation, and unit tests that exercise configuration parsing.
- `EbookMechanicApp` – a macOS SwiftUI experience that lets you run scans visually, toggle behaviours, review summaries, and see corrupted files/empty folders in a polished, gradient-backed UI. View-model tests ensure the UI state behaves predictably.

### EPUB Normalization Details (continued)
- OPF (content.opf) normalization:
  - Locate via META-INF/container.xml (rootfile@full-path)
  - Canonicalize XML declaration, UTF-8 encoding, LF newlines
  - Normalize metadata text (trim, collapse spaces, NFC)
  - Sort <metadata> children deterministically
  - Normalize <manifest> items:
    - Sort by id (then href)
    - Correct common media types (xhtml/css/images/opf)
    - Normalize hrefs (remove leading ./, fix casing to match ZIP entries)
    - Remove items for extraneous files
  - Normalize <spine> order to follow manifest and remove invalid references

## Workspace Layout


# CLI Usage Examples

```sh
$ ebookmechanic scan ~/ebooks
$ ebookmechanic validate ~/ebooks/mybook.epub
$ ebookmechanic normalize ~/ebooks/mybook.epub --dry-run
$ ebookmechanic normalize ~/ebooks/mybook.epub --force-normalize
```

## Shell Completion

The CLI supports shell completion for Bash, Zsh, Fish, and PowerShell. 

Generate all completions at once:
```bash
make cli-completions
```

Or generate individually:
```bash
ebook-mechanic --generate-completion bash > ebook-mechanic.bash
ebook-mechanic --generate-completion zsh > _ebook-mechanic
ebook-mechanic --generate-completion fish > ebook-mechanic.fish
ebook-mechanic --generate-completion powershell > ebook-mechanic.ps1
```

See [COMPLETIONS.md](COMPLETIONS.md) for detailed installation instructions.


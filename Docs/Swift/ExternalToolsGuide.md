# External Tools Guide

EbookMechanic can optionally use external command-line tools for comprehensive EPUB and PDF validation. When enabled, the core validator will invoke these tools to surface spec-level issues and deep PDF structure warnings.

## Supported Tools

| Tool | Purpose | Recommended Version |
| --- | --- | --- |
| epubcheck | EPUB spec compliance + accessibility checks | 5.x |
| pdfcpu | PDF structure validation + stream checks | 0.8.x |

> Notes: The core library runs without these tools. External tools are only required for comprehensive validation.

## Installation

### macOS (Homebrew)

```bash
brew install epubcheck
brew install pdfcpu
```

### Linux (apt / dnf)

```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install epubcheck

# Fedora
sudo dnf install epubcheck
```

pdfcpu ships as a single binary; download it from the release page for your distro and place it on your PATH.

### Manual Install

- **epubcheck:** Download from the official GitHub release, unzip, and add the `epubcheck` script to your PATH.
- **pdfcpu:** Download the `pdfcpu` binary for your OS/arch and place it in `/usr/local/bin` (or any directory on PATH).

## Configuration

CLI:

```bash
ebook-mechanic --dir ~/Books --external-tools
```

EPUB-only checks can still be requested with:

```bash
ebook-mechanic --dir ~/Books --use-epubcheck
```

App:

- Toggle **Use external tools** in the scan options panel.
- Use **Install** to open the helper sheet with copyable install commands.

## Troubleshooting

- **Tool not found:** Confirm `which epubcheck` and `which pdfcpu` return paths.
- **Permission errors:** Ensure the binary is executable: `chmod +x /path/to/pdfcpu`.
- **Older versions:** Upgrade if you see parsing errors; 5.x (epubcheck) and 0.8.x (pdfcpu) are recommended.
- **Slow scans:** External tools are comprehensive and can be slower; reduce `--max-concurrent` if CPU-bound.

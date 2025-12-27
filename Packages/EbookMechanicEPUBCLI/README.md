[38;2;216;222;233m─────┬──────────────────────────────────────────────────────────────────────────[0m
     [38;2;216;222;233m│ [0m[1mSTDIN[0m
[38;2;216;222;233m─────┼──────────────────────────────────────────────────────────────────────────[0m
[38;2;216;222;233m   1[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# EbookMechanicEPUBCLI[0m
[38;2;216;222;233m   2[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m   3[0m [38;2;216;222;233m│[0m [38;2;216;222;233mA specialized command-line tool for validating and repairing EPUB ebook files.[0m
[38;2;216;222;233m   4[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m   5[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Overview[0m
[38;2;216;222;233m   6[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m   7[0m [38;2;216;222;233m│[0m [38;2;216;222;233mEbookMechanicEPUBCLI is a focused utility that performs comprehensive validation and automatic repair of EPUB files. Built on top of the EbookMechanicCore library with a streamlined interface for EPUB-specific operations.[0m
[38;2;216;222;233m   8[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m   9[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Features[0m
[38;2;216;222;233m  10[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  11[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **EPUB Validation**[0m
[38;2;216;222;233m  12[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Validates ZIP archive structure[0m
[38;2;216;222;233m  13[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Checks for required `mimetype` file with correct content[0m
[38;2;216;222;233m  14[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Verifies `META-INF/container.xml` exists and is valid[0m
[38;2;216;222;233m  15[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  16[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **Automatic Repair**[0m
[38;2;216;222;233m  17[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Adds missing `mimetype` file (`application/epub+zip`)[0m
[38;2;216;222;233m  18[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Creates missing `META-INF/container.xml`[0m
[38;2;216;222;233m  19[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Preserves originals with `.backup` extension[0m
[38;2;216;222;233m  20[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  21[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Usage[0m
[38;2;216;222;233m  22[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  23[0m [38;2;216;222;233m│[0m [38;2;216;222;233m```bash[0m
[38;2;216;222;233m  24[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# Show help[0m
[38;2;216;222;233m  25[0m [38;2;216;222;233m│[0m [38;2;216;222;233mepub-mechanic --help[0m
[38;2;216;222;233m  26[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  27[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# Scan directory[0m
[38;2;216;222;233m  28[0m [38;2;216;222;233m│[0m [38;2;216;222;233mepub-mechanic -d ~/Books[0m
[38;2;216;222;233m  29[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  30[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# Repair corrupted EPUBs[0m
[38;2;216;222;233m  31[0m [38;2;216;222;233m│[0m [38;2;216;222;233mepub-mechanic -d ~/Books --repair[0m
[38;2;216;222;233m  32[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  33[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# Dry run[0m
[38;2;216;222;233m  34[0m [38;2;216;222;233m│[0m [38;2;216;222;233mepub-mechanic -d ~/Books --repair --dry-run -v[0m
[38;2;216;222;233m  35[0m [38;2;216;222;233m│[0m [38;2;216;222;233m```[0m
[38;2;216;222;233m  36[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  37[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Options[0m
[38;2;216;222;233m  38[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  39[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `-d, --dir <path>` - Directory to scan (default: current directory)[0m
[38;2;216;222;233m  40[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `-r, --repair` - Attempt to repair corrupted EPUB files[0m
[38;2;216;222;233m  41[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `--dry-run` - Scan only, don't make changes[0m
[38;2;216;222;233m  42[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `-v, --verbose` - Show detailed progress[0m
[38;2;216;222;233m  43[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `-h, --help` - Show help message[0m
[38;2;216;222;233m  44[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  45[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Installation[0m
[38;2;216;222;233m  46[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  47[0m [38;2;216;222;233m│[0m [38;2;216;222;233m```bash[0m
[38;2;216;222;233m  48[0m [38;2;216;222;233m│[0m [38;2;216;222;233mcd Packages/EbookMechanicEPUBCLI[0m
[38;2;216;222;233m  49[0m [38;2;216;222;233m│[0m [38;2;216;222;233mswift build -c release[0m
[38;2;216;222;233m  50[0m [38;2;216;222;233m│[0m [38;2;216;222;233m```[0m
[38;2;216;222;233m  51[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  52[0m [38;2;216;222;233m│[0m [38;2;216;222;233mExecutable: `.build/release/EbookMechanicEPUBCLI`[0m
[38;2;216;222;233m─────┴──────────────────────────────────────────────────────────────────────────[0m


## Examples

```bash
# Validate with epubcheck and show warnings
epub-mechanic validate --spec-check --show-warnings --dir ~/Books/EPUB

# Run accessibility checks
epub-mechanic validate --spec-check --accessibility --dir ~/Books/EPUB

# Extract metadata to JSON files
epub-mechanic validate --extract-metadata json --dir ~/Books/EPUB

# Repair EPUB metadata after a scan
epub-mechanic repair --fix-metadata --dir ~/Books/EPUB
```

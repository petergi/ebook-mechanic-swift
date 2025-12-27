[38;2;216;222;233m─────┬──────────────────────────────────────────────────────────────────────────[0m
     [38;2;216;222;233m│ [0m[1mSTDIN[0m
[38;2;216;222;233m─────┼──────────────────────────────────────────────────────────────────────────[0m
[38;2;216;222;233m   1[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# EbookMechanicPDFCLI[0m
[38;2;216;222;233m   2[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m   3[0m [38;2;216;222;233m│[0m [38;2;216;222;233mA specialized command-line tool for validating and repairing PDF and AZW4 files.[0m
[38;2;216;222;233m   4[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m   5[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Overview[0m
[38;2;216;222;233m   6[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m   7[0m [38;2;216;222;233m│[0m [38;2;216;222;233mEbookMechanicPDFCLI is a focused utility that performs comprehensive validation and automatic repair of PDF files. Built on top of the EbookMechanicCore library with advanced PDF header corruption detection and repair capabilities.[0m
[38;2;216;222;233m   8[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m   9[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Features[0m
[38;2;216;222;233m  10[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  11[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **PDF Validation**[0m
[38;2;216;222;233m  12[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Validates PDF header (`%PDF-`)[0m
[38;2;216;222;233m  13[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Checks EOF marker (`%%EOF`) in last 1KB[0m
[38;2;216;222;233m  14[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Detects header corruption (junk prefixes, UTF-8 BOM, email wrappers)[0m
[38;2;216;222;233m  15[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Validates PDF version format (1.0-2.0)[0m
[38;2;216;222;233m  16[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  17[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **Advanced Repair**[0m
[38;2;216;222;233m  18[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Searches first 8KB for corrupted headers[0m
[38;2;216;222;233m  19[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Strips corrupted prefix bytes[0m
[38;2;216;222;233m  20[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Adds missing binary markers[0m
[38;2;216;222;233m  21[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Appends missing EOF markers[0m
[38;2;216;222;233m  22[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - Preserves originals with `.backup` extension[0m
[38;2;216;222;233m  23[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  24[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **Supported Formats**[0m
[38;2;216;222;233m  25[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - PDF (.pdf)[0m
[38;2;216;222;233m  26[0m [38;2;216;222;233m│[0m [38;2;216;222;233m  - AZW4 (.azw4) - Kindle PDF wrapper format[0m
[38;2;216;222;233m  27[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  28[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Usage[0m
[38;2;216;222;233m  29[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  30[0m [38;2;216;222;233m│[0m [38;2;216;222;233m```bash[0m
[38;2;216;222;233m  31[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# Show help[0m
[38;2;216;222;233m  32[0m [38;2;216;222;233m│[0m [38;2;216;222;233mpdf-mechanic --help[0m
[38;2;216;222;233m  33[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  34[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# Scan directory[0m
[38;2;216;222;233m  35[0m [38;2;216;222;233m│[0m [38;2;216;222;233mpdf-mechanic -d ~/Documents[0m
[38;2;216;222;233m  36[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  37[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# Repair corrupted PDFs[0m
[38;2;216;222;233m  38[0m [38;2;216;222;233m│[0m [38;2;216;222;233mpdf-mechanic -d ~/Documents --repair[0m
[38;2;216;222;233m  39[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  40[0m [38;2;216;222;233m│[0m [38;2;216;222;233m# Dry run[0m
[38;2;216;222;233m  41[0m [38;2;216;222;233m│[0m [38;2;216;222;233mpdf-mechanic -d ~/Documents --repair --dry-run -v[0m
[38;2;216;222;233m  42[0m [38;2;216;222;233m│[0m [38;2;216;222;233m```[0m
[38;2;216;222;233m  43[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  44[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Options[0m
[38;2;216;222;233m  45[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  46[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `-d, --dir <path>` - Directory to scan (default: current directory)[0m
[38;2;216;222;233m  47[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `-r, --repair` - Attempt to repair corrupted PDF files[0m
[38;2;216;222;233m  48[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `--dry-run` - Scan only, don't make changes[0m
[38;2;216;222;233m  49[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `-v, --verbose` - Show detailed progress[0m
[38;2;216;222;233m  50[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- `-h, --help` - Show help message[0m
[38;2;216;222;233m  51[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  52[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## PDF Corruption Detection[0m
[38;2;216;222;233m  53[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  54[0m [38;2;216;222;233m│[0m [38;2;216;222;233mDetects and repairs common PDF corruption patterns:[0m
[38;2;216;222;233m  55[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **Junk prefixes** - Extra bytes before `%PDF-`[0m
[38;2;216;222;233m  56[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **UTF-8 BOM** - Byte order mark corruption[0m
[38;2;216;222;233m  57[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **Email wrappers** - Email headers prepended to PDF[0m
[38;2;216;222;233m  58[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **FTP corruption** - FTP transfer artifacts[0m
[38;2;216;222;233m  59[0m [38;2;216;222;233m│[0m [38;2;216;222;233m- **Missing EOF** - Truncated files without `%%EOF`[0m
[38;2;216;222;233m  60[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  61[0m [38;2;216;222;233m│[0m [38;2;216;222;233m## Installation[0m
[38;2;216;222;233m  62[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  63[0m [38;2;216;222;233m│[0m [38;2;216;222;233m```bash[0m
[38;2;216;222;233m  64[0m [38;2;216;222;233m│[0m [38;2;216;222;233mcd Packages/EbookMechanicPDFCLI[0m
[38;2;216;222;233m  65[0m [38;2;216;222;233m│[0m [38;2;216;222;233mswift build -c release[0m
[38;2;216;222;233m  66[0m [38;2;216;222;233m│[0m [38;2;216;222;233m```[0m
[38;2;216;222;233m  67[0m [38;2;216;222;233m│[0m 
[38;2;216;222;233m  68[0m [38;2;216;222;233m│[0m [38;2;216;222;233mExecutable: `.build/release/EbookMechanicPDFCLI`[0m
[38;2;216;222;233m─────┴──────────────────────────────────────────────────────────────────────────[0m


## Examples

```bash
# Validate PDFs with structure checks via pdfcpu
pdf-mechanic validate --structure-check --dir ~/Documents/PDFs

# Analyze object streams for size optimization
pdf-mechanic validate --show-streams --dir ~/Documents/PDFs

# Extract metadata to JSON/YAML files
pdf-mechanic validate --extract-metadata json --dir ~/Documents/PDFs

# Optimize PDFs in place (dry-run first)
pdf-mechanic repair --optimize --dry-run --dir ~/Documents/PDFs
```

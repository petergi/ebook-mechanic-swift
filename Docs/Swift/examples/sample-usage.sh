#!/usr/bin/env bash
set -euo pipefail

# Basic scan (defaults to markdown report if --report is enabled)
ebook-mechanic --dir "$HOME/Books" --dry-run

# Comprehensive scan with external tools and all report formats
ebook-mechanic --dir "$HOME/Books" --external-tools --report \
  --report-formats markdown,json,csv,html --performance-stats

# EPUB-only validation and repair
epub-mechanic validate --dir "$HOME/Books"
epub-mechanic repair --dir "$HOME/Books" --fix-metadata

# PDF/AZW4 validation
pdf-mechanic validate --dir "$HOME/Books"
pdf-mechanic validate --dir "$HOME/Books" --extract-metadata json

# Performance benchmarking (generates a sample library)
./Scripts/benchmark.sh --iterations 3 --formats epub,pdf

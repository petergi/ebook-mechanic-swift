# 📚 EbookMechanic - Python Implementation

A flexible, modular ebook library management toolkit with beautiful terminal output powered by [Rich](https://github.com/Textualize/rich).

## Overview

The Python implementation of EbookMechanic provides maximum flexibility, ease of modification, and cross-platform compatibility. Built with Python's standard library and the Rich terminal library, it offers a modular architecture perfect for customization and educational purposes.

## Features

- 🐍 **Pure Python** - No compilation required, easy to modify
- 🎨 **Beautiful TUI** - Powered by Rich library with color-coded panels
- 📊 **Real-time Progress** - Live progress bars and status updates
- 🔍 **Deep Validation** - Validates EPUB, MOBI, AZW3, AZW4, and PDF files
- 🗑️ **Smart Cleanup** - Removes empty folders while preserving structure
- 🔧 **Modular Design** - Separate scripts for different operations
- 🛠️ **Test Generator** - Comprehensive test library generator included
- 📄 **Console Output** - Rich formatted output with panels and tables
- 🔒 **Safe Operations** - Interactive confirmations and dry-run support
- 🌍 **Cross-Platform** - Works anywhere Python 3.7+ is available

## Installation

### Prerequisites

- Python 3.7 or higher
- `rich` library (for TUI features only)

### Install Dependencies

```bash
# Navigate to python directory
cd python

# Install Rich library (optional, for TUI)
pip3 install rich

# Or using system package manager (macOS)
brew install python3
pip3 install rich
```

## Quick Start

### Basic Usage

```bash
# Run full TUI implementation
python3 ebook_manager_tui.py ~/Books

# Run core validation without TUI
python3 ebook_manager.py ~/Books

# Check for corrupted ebooks only
python3 check_corrupted_ebooks.py ~/Books

# Clean empty folders only
python3 delete_empty_ebook_folders.py ~/Books
```

### Generate Test Library

```bash
# Generate sample library with 10 authors, all formats
python3 generate_test_library.py \
  --output test-library \
  --authors 10 \
  --formats pdf,epub,mobi,azw3,azw4 \
  --force

# Minimal library (PDF and EPUB only)
python3 generate_test_library.py \
  --output fixtures \
  --authors 3 \
  --formats pdf,epub \
  --force
```

## Available Scripts

### Main Tools

| Script | Description | Use Case |
|--------|-------------|----------|
| `ebook_manager_tui.py` | Full TUI implementation (33KB) | Complete interactive experience |
| `ebook_manager.py` | Core validation logic (21KB) | Command-line validation |
| `check_corrupted_ebooks.py` | Corruption checker (12KB) | Corruption detection only |
| `delete_empty_ebook_folders.py` | Folder cleanup (10KB) | Empty folder removal |
| `ebook_checker.py` | Simple validator (2.4KB) | Basic file checking |
| `generate_test_library.py` | Test generator (6.3KB) | Create test fixtures |

### Script Details

#### ebook_manager_tui.py

Complete TUI implementation with Rich library:

```bash
python3 ebook_manager_tui.py <directory>
```

Features:
- Interactive prompts using `rich.prompt.Confirm`
- Real-time progress tracking with `rich.progress.Progress`
- Color-coded panels for status (green success, red errors, yellow warnings)
- Modular design separating UI from validation logic

#### ebook_manager.py

Core validation logic and file operations:

```bash
python3 ebook_manager.py <directory>
```

Features:
- Validates all ebook formats
- Moves corrupted files to CORRUPTED/
- Console output with statistics
- No Rich library required (basic mode)

#### check_corrupted_ebooks.py

Standalone corruption detection:

```bash
python3 check_corrupted_ebooks.py <directory>
```

Features:
- Scans directory for corrupted ebooks
- Detailed corruption reports
- No file modifications
- Can be integrated into other workflows

#### delete_empty_ebook_folders.py

Standalone empty folder cleanup:

```bash
python3 delete_empty_ebook_folders.py <directory>
```

Features:
- Finds folders without ebook files
- Interactive confirmation
- Bottom-up traversal
- Preserves non-empty folders

#### generate_test_library.py

Test fixture generator:

```bash
python3 generate_test_library.py [options]

Options:
  --output DIR      Output directory (default: test-library)
  --authors N       Number of authors (default: 10)
  --formats LIST    Comma-separated formats (default: all)
  --force           Overwrite existing directory
```

Creates:
- Valid and corrupt file pairs for each format
- Nested author/book directory structures
- Empty folders for cleanup testing
- Configurable author count and format selection

## Usage Examples

### Basic Operations

```bash
# Full TUI scan
python3 ebook_manager_tui.py ~/Books

# Validate without modifications
python3 check_corrupted_ebooks.py ~/Books

# Clean empty folders
python3 delete_empty_ebook_folders.py ~/Books
```

### Test Library Generation

```bash
# Generate comprehensive test library
python3 generate_test_library.py \
  --output my-test-lib \
  --authors 20 \
  --formats pdf,epub,mobi \
  --force

# Generate minimal EPUB-only library
python3 generate_test_library.py \
  --output epub-tests \
  --authors 5 \
  --formats epub \
  --force
```

### Integration Examples

```bash
# Check for corruption, then clean empty folders
python3 check_corrupted_ebooks.py ~/Books
python3 delete_empty_ebook_folders.py ~/Books

# Generate library and test validation
python3 generate_test_library.py --output test-lib --authors 5
python3 ebook_manager_tui.py test-lib
```

## How It Works

### Validation Strategy

**EPUB Files:**
- ZIP validation using Python's `zipfile` module
- Check for `mimetype` file with content: `application/epub+zip`
- Verify `META-INF/container.xml` presence

**MOBI Files:**
- PalmDB header validation
- Identifier check at bytes 60-68 (`BOOKMOBI` or `TEXtREAd`)
- Minimum file size validation

**PDF Files:**
- Header validation (`%PDF-`)
- EOF marker check (`%%EOF` in last 1KB)
- Minimum file size validation

**AZW3 Files:**
- Delegates to MOBI validation (same structure)

**AZW4 Files:**
- Delegates to PDF validation (PDF wrapper)

### File Operations

**Corruption Handling:**
- Validates each ebook file
- Moves corrupted files to `CORRUPTED/` directory
- Preserves original directory structure
- Skips `CORRUPTED/` directory during scans

**Empty Folder Detection:**
- Uses `os.walk()` for recursive traversal
- Bottom-up processing (children before parents)
- Checks for ebook file extensions
- Interactive confirmation before deletion

**Progress Tracking:**
- Rich `Progress` context manager
- Multiple task tracking
- Real-time updates
- Completion percentage display

## TUI Features

The Rich library provides beautiful terminal output:

**Visual Elements:**
- 📦 **Panels** - Grouped information with borders
- 📊 **Progress Bars** - Real-time progress with multiple tasks
- 🎨 **Color Markup** - `[bold green]`, `[red]`, `[yellow]` styling
- ✅ **Interactive Prompts** - `Confirm.ask()` for yes/no questions
- 📋 **Tables** - Structured data display

**Output Example:**

```
╭─────────────────────────────────────╮
│ Scanning for Corrupted Ebooks       │
│                                     │
│ ⠋ Processing: book.epub             │
│ Progress: 42/100 files (42%)        │
╰─────────────────────────────────────╯
```

## Project Structure

```
python/
├── README.md                      # This file
├── ebook_manager_tui.py          # Full TUI implementation (33KB)
├── ebook_manager.py              # Core validation logic (21KB)
├── check_corrupted_ebooks.py     # Corruption detection (12KB)
├── delete_empty_ebook_folders.py # Empty folder cleanup (10KB)
├── ebook_checker.py              # Simple validator (2.4KB)
└── generate_test_library.py      # Test generator (6.3KB)
```

## Dependencies

### Required
- Python 3.7+ (standard library)

### Optional
- `rich` - For TUI features (highly recommended)
  ```bash
  pip3 install rich
  ```

### Standard Library Modules Used
- `os` - File system operations
- `pathlib` - Path manipulations
- `zipfile` - EPUB/ZIP validation
- `argparse` - Command-line parsing
- `shutil` - File operations
- `datetime` - Timestamps

## Performance

Python's interpreted nature makes it slower than compiled implementations, but offers other advantages:

**Advantages:**
- ✅ No compilation required
- ✅ Easy to modify and extend
- ✅ Excellent for prototyping
- ✅ Cross-platform compatibility
- ✅ Rich ecosystem of libraries

**Performance Characteristics:**
- **Speed:** ~30-45 seconds for 10,000 files
- **Memory:** ~50MB typical usage
- **Startup:** ~500ms (interpreter + library loading)

**Comparison with Other Implementations:**

| Feature | Python | Go | Swift |
|---------|--------|-----|-------|
| **Speed** | ~30s | ~8s | ~12s |
| **Memory** | ~50MB | ~15MB | ~20MB |
| **Flexibility** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Ease of Modification** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Deployment** | Script | Single binary | Single binary |

## Testing

Python implementation uses manual testing with generated test libraries:

```bash
# Generate test library
python3 generate_test_library.py --output test-lib --authors 10

# Test each script
python3 ebook_manager_tui.py test-lib
python3 check_corrupted_ebooks.py test-lib
python3 delete_empty_ebook_folders.py test-lib

# Verify results
ls -R test-lib/CORRUPTED
```

### Test Scenarios

1. **Valid Files** - Should not be moved
2. **Corrupt EPUBs** - Should be detected and moved
3. **Corrupt MOBIs** - Should be detected and moved
4. **Corrupt PDFs** - Should be detected and moved
5. **Empty Folders** - Should be identified for deletion
6. **Mixed Content** - Both valid and corrupt files

## Modular Architecture

The Python implementation uses a modular design where each script can run independently:

**Benefits:**
- Use only what you need
- Easy to integrate into other workflows
- Separate concerns (validation, cleanup, generation)
- Lightweight - no full TUI required for simple tasks

**Integration Example:**

```python
# Import validation logic from ebook_manager.py
from ebook_manager import check_ebook_file, validate_epub

# Use in your own script
result = check_ebook_file("path/to/book.epub")
if not result['is_valid']:
    print(f"Corrupted: {result['reason']}")
```

## Customization

### Modify Validation Logic

Edit `ebook_manager.py` to customize validation:

```python
# Add custom EPUB checks
def validate_epub(file_path):
    # Add your validation logic
    if custom_check_fails():
        return {'is_valid': False, 'reason': 'Custom check failed'}
    # ... existing validation
```

### Add New Formats

1. Add extension to supported formats list
2. Create validation function
3. Add case to validation dispatcher
4. Update test library generator
5. Test with sample files

### Customize Output

Modify Rich output in `ebook_manager_tui.py`:

```python
# Change panel styles
panel = Panel(
    content,
    title="[bold cyan]Custom Title[/bold cyan]",
    border_style="blue"
)

# Add custom progress bar
with Progress() as progress:
    task = progress.add_task("[green]Processing...", total=total)
    # ... your logic
```

## Troubleshooting

### Import Errors

```bash
# Install Rich library
pip3 install rich

# Or run without Rich (basic mode)
python3 ebook_manager.py <directory>
```

### Permission Errors

```bash
# Make scripts executable
chmod +x *.py

# Or always use python3 explicitly
python3 ebook_manager_tui.py
```

### Slow Performance

```bash
# Use faster implementations for large libraries
cd ../golang && make build && ./ebook-mechanic

# Or reduce test library size
python3 generate_test_library.py --authors 5
```

## Comparison with Other Implementations

### When to Use Python

**Choose Python when:**
- ✅ You need to modify or extend the code
- ✅ You're prototyping new features
- ✅ You prefer scripting languages
- ✅ You need easy integration with other Python tools
- ✅ Performance is not critical (< 10k files)

**Choose Go when:**
- ⚡ You need maximum performance
- 📦 You want a single binary deployment
- 🚀 You're processing large libraries (10k+ files)

**Choose Swift when:**
- 🍎 You need a native macOS app
- 📱 You want iOS integration
- 🎨 You prefer SwiftUI interfaces

## Integration Examples

### Use as a Module

```python
import sys
sys.path.append('/path/to/ebook-mechanic/python')

from ebook_manager import check_ebook_file

# Validate a single file
result = check_ebook_file('book.epub')
print(f"Valid: {result['is_valid']}")
```

### Batch Processing

```python
import os
from ebook_manager import check_ebook_file

for root, dirs, files in os.walk('/my/books'):
    for file in files:
        if file.endswith('.epub'):
            result = check_ebook_file(os.path.join(root, file))
            if not result['is_valid']:
                print(f"Corrupt: {file}")
```

### Custom Workflow

```bash
#!/bin/bash
# Custom validation workflow

# 1. Generate test library
python3 generate_test_library.py --output test-lib

# 2. Check for corruption
python3 check_corrupted_ebooks.py test-lib

# 3. Clean empty folders
python3 delete_empty_ebook_folders.py test-lib

# 4. Verify results
ls -R test-lib/CORRUPTED
```

## Contributing

Contributions are welcome! The Python implementation is ideal for:

- Adding new file format support
- Improving validation logic
- Enhancing Rich output
- Adding new utility scripts
- Improving documentation

### Development Workflow

```bash
# 1. Make changes to scripts
# 2. Test with generated library
python3 generate_test_library.py --output test-lib --authors 5

# 3. Run your modified script
python3 ebook_manager_tui.py test-lib

# 4. Verify expected behavior
ls -R test-lib/CORRUPTED
```

## License

Free to use and modify.

## Credits

- Built with [Rich](https://github.com/Textualize/rich) for beautiful terminal output
- Uses Python 3 standard library
- Created with ❤️ by the team

---

**Quick Links:** [Parent README](../README.md) | [Master Makefile](../Makefile) | [Go Implementation](../golang/README.md) | [Swift Implementation](../swift/README.md)

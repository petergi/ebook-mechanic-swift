# What's Next - Immediate Priorities

This document outlines the immediate next steps for the EbookMechanic Swift implementation after completing the specialized CLI utilities (EPUBMechanicCLI and PDFMechanicCLI).

## Immediate Next Steps (This Week)

### 1. 🎯 Makefile Integration (Priority: Critical)

**Why**: Users need easy commands to build and install the new CLIs.

**What to do**:
```bash
# Add these targets to swift/Makefile

# EPUB Mechanic CLI targets
epub-build:
	@cd EPUBMechanicCLI && swift build

epub-build-release:
	@cd EPUBMechanicCLI && swift build -c release

epub-test:
	@cd EPUBMechanicCLI && swift test

epub-install:
	@sudo cp EPUBMechanicCLI/.build/release/EPUBMechanicCLI /usr/local/bin/epub-mechanic

# PDF Mechanic CLI targets
pdf-build:
	@cd PDFMechanicCLI && swift build

pdf-build-release:
	@cd PDFMechanicCLI && swift build -c release

pdf-test:
	@cd PDFMechanicCLI && swift test

pdf-install:
	@sudo cp PDFMechanicCLI/.build/release/PDFMechanicCLI /usr/local/bin/pdf-mechanic

# Build all specialized CLIs
build-specialized:
	@$(MAKE) epub-build
	@$(MAKE) pdf-build

# Install all CLIs
install-all:
	@$(MAKE) install
	@$(MAKE) epub-install
	@$(MAKE) pdf-install
```

**Files to modify**:
- `swift/Makefile`

**Estimated time**: 30 minutes

---

### 2. 🧪 Expand Test Coverage (Priority: High)

**Why**: Current test coverage is minimal (2 tests each). Need comprehensive testing before production use.

#### EPUBMechanicCLI Tests Needed:

```swift
// swift/EPUBMechanicCLI/Tests/EPUBMechanicCLITests/

@Test("Validates correct EPUB files")
func testValidEPUB() async throws { ... }

@Test("Detects missing mimetype")
func testMissingMimetype() async throws { ... }

@Test("Detects missing container.xml")
func testMissingContainer() async throws { ... }

@Test("Repairs missing mimetype")
func testRepairMimetype() async throws { ... }

@Test("Repairs missing container.xml")
func testRepairContainer() async throws { ... }

@Test("Handles corrupted ZIP")
func testCorruptedZIP() async throws { ... }

@Test("Filters non-EPUB files")
func testFilterNonEPUB() async throws { ... }

@Test("Dry run mode")
func testDryRun() async throws { ... }

@Test("Verbose output")
func testVerboseMode() async throws { ... }

@Test("Command line argument parsing")
func testArgumentParsing() { ... }
```

#### PDFMechanicCLI Tests Needed:

```swift
// swift/PDFMechanicCLI/Tests/PDFMechanicCLITests/

@Test("Validates correct PDF files")
func testValidPDF() async throws { ... }

@Test("Detects missing PDF header")
func testMissingHeader() async throws { ... }

@Test("Detects missing EOF marker")
func testMissingEOF() async throws { ... }

@Test("Detects junk prefix corruption")
func testJunkPrefix() async throws { ... }

@Test("Detects UTF-8 BOM corruption")
func testUTF8BOM() async throws { ... }

@Test("Detects email wrapper corruption")
func testEmailWrapper() async throws { ... }

@Test("Repairs PDF header")
func testRepairHeader() async throws { ... }

@Test("Repairs missing EOF")
func testRepairEOF() async throws { ... }

@Test("Handles AZW4 files")
func testAZW4Support() async throws { ... }

@Test("Filters non-PDF files")
func testFilterNonPDF() async throws { ... }
```

**Estimated time**: 4-6 hours

---

### 3. 📝 Update Build Instructions (Priority: Medium)

**Why**: Users need to know how to use the new CLIs.

**What to update**:

1. **swift/README.md** - Add "Quick Start" section:
```markdown
## Quick Start

### Specialized CLI Tools

Build and install EPUB-specific tool:
```bash
cd swift
make epub-build-release
make epub-install
epub-mechanic --help
```

Build and install PDF-specific tool:
```bash
cd swift
make pdf-build-release
make pdf-install
pdf-mechanic --help
```
```

2. **Root README.md** (if exists) - Add Swift CLIs section

**Estimated time**: 1 hour

---

### 4. 🔧 Shell Completions (Priority: Medium)

**Why**: Improve user experience with tab completion.

**What to do**:

1. Study existing completion generation in `EbookMechanicCLI/Sources/EbookMechanicCLI/ShellCompletion.swift`

2. Create similar completion generators for EPUBMechanicCLI and PDFMechanicCLI

3. Add Makefile targets:
```makefile
epub-completions:
	@mkdir -p completions
	@EPUBMechanicCLI/.build/release/EPUBMechanicCLI --generate-completion bash > completions/epub-mechanic.bash
	# ... other shells

pdf-completions:
	@mkdir -p completions
	@PDFMechanicCLI/.build/release/PDFMechanicCLI --generate-completion bash > completions/pdf-mechanic.bash
	# ... other shells
```

**Estimated time**: 2-3 hours

---

## This Sprint (Next 2 Weeks)

### 5. 🎨 User Experience Improvements

- [ ] Add color output support (optional flag)
- [ ] Improve progress messages
- [ ] Add summary statistics at end
- [ ] Better error messages with suggestions

### 6. 📊 Real-World Testing

- [ ] Test on large ebook collections (1000+ files)
- [ ] Collect performance metrics
- [ ] Identify common corruption patterns
- [ ] Document edge cases

### 7. 📖 Documentation

- [ ] Create usage video/GIF demos
- [ ] Add troubleshooting guide
- [ ] Document common workflows
- [ ] Create FAQ section

---

## Known Issues to Address

1. **Total files count in specialized CLIs**
   - Currently shows all files scanned, not just EPUB/PDF
   - Should filter count to show only relevant format totals
   - Priority: Medium

2. **Error handling improvements**
   - Add more specific error types
   - Better error recovery
   - User-friendly error messages
   - Priority: Medium

3. **Performance optimization**
   - Profile file scanning performance
   - Optimize regex patterns
   - Consider parallel validation
   - Priority: Low

---

## Long-Term Goals (Next Month)

### iOS App Development
- [ ] Design iOS interface
- [ ] Share SwiftUI components with macOS
- [ ] Implement document picker
- [ ] iCloud Drive integration

### Advanced Features
- [ ] Batch processing mode
- [ ] Configuration file support
- [ ] Plugin system architecture
- [ ] REST API for headless operation

### Distribution
- [ ] Homebrew formula
- [ ] GitHub releases with binaries
- [ ] App Store submission (macOS)
- [ ] TestFlight beta program (iOS)

---

## How to Use This Document

1. **Starting work**: Pick a task from "Immediate Next Steps"
2. **Check dependencies**: Ensure prerequisites are met
3. **Time boxing**: Use the estimated time as a guide
4. **Update status**: Mark tasks as complete in TASKS.md
5. **Commit often**: Small, focused commits with clear messages

---

## Questions or Blockers?

If you encounter issues or need clarification:

1. Check [TASKS.md](TASKS.md) for detailed task descriptions
2. Review [CLAUDE.md](../CLAUDE.md) for architecture details
3. Check existing code in EbookMechanicCLI for patterns
4. Open an issue if blocked

---

## Success Metrics

**By end of this week**:
- ✅ Makefile targets added and tested
- ✅ Test coverage > 80% for specialized CLIs
- ✅ Documentation updated

**By end of this sprint**:
- ✅ Shell completions working
- ✅ Real-world testing on 1000+ files
- ✅ Performance baseline established
- ✅ All known issues documented

---

Last updated: November 9, 2025

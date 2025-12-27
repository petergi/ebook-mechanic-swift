# What's Next - Immediate Priorities

This document outlines the immediate next steps for the EbookMechanic Swift implementation after completing the specialized CLI utilities (EbookMechanicEPUBCLI and EbookMechanicPDFCLI).

## Immediate Next Steps (This Week)

### 1. ✅ Makefile Integration (Priority: Critical) - COMPLETED

**Status**: ✅ Completed and tested

**What was done**:
- Added comprehensive Makefile targets for both EbookMechanicEPUBCLI and EbookMechanicPDFCLI to `Makefile.swift`
- Fixed binary paths in specialized CLI Makefiles (EbookMechanicEPUBCLI/Makefile, EbookMechanicPDFCLI/Makefile)
- Corrected shell completion file names (epub-mechanic vs pdf-mechanic)
- Standardized shell configuration across all Makefiles (using `/bin/zsh`)
- Fixed package path references in build commands
- Updated all build artifact paths to use relative `.build` directories
- Added new targets: `build-specialized`, `install-specialized`, `uninstall-specialized`
- Individual targets: `epub-build`, `epub-test`, `epub-install`, `epub-install-release`, `epub-uninstall`
- Individual targets: `pdf-build`, `pdf-test`, `pdf-install`, `pdf-install-release`, `pdf-uninstall`
- Extended `build-all` and `test-all` to include specialized CLIs
- Updated `clean` and `clean-all` targets to remove specialized CLI build artifacts

**Verified commands**:
```bash
make -f Makefile.swift help              # ✅ Shows all new targets
make -f Makefile.swift build-epub        # ✅ Builds EbookMechanicEPUBCLI successfully
make -f Makefile.swift test-pdf          # ✅ Runs PDF Mechanic CLI tests (2 tests pass)
make -f Makefile.swift build-specialized # ✅ Builds both specialized CLIs
```

**Available targets**:
```bash
# Build
make -f Makefile.swift build-epub / make -f Makefile.swift build-pdf
make -f Makefile.swift build-epub-release / make -f Makefile.swift build-pdf-release
make -f Makefile.swift build-specialized

# Test
make -f Makefile.swift test-epub / make -f Makefile.swift test-pdf

# Run
make -f Makefile.swift run-epub ARGS="--help" / make -f Makefile.swift run-pdf ARGS="--help"

# Install
make -f Makefile.swift install-epub / make -f Makefile.swift install-pdf
make -f Makefile.swift install-epub-release / make -f Makefile.swift install-pdf-release
make -f Makefile.swift install-specialized

# Uninstall
make -f Makefile.swift uninstall-epub / make -f Makefile.swift uninstall-pdf
make -f Makefile.swift uninstall-specialized
```

---

### 2. 🧪 Expand Test Coverage (Priority: High)

**Why**: Current test coverage is minimal (2 tests each). Need comprehensive testing before production use.

#### EbookMechanicEPUBCLI Tests Needed:

```swift
// Packages/EbookMechanicEPUBCLI/Tests/EbookMechanicEPUBCLITests/

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

#### EbookMechanicPDFCLI Tests Needed:

```swift
// Packages/EbookMechanicPDFCLI/Tests/EbookMechanicPDFCLITests/

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

1. **Docs/Swift/README.md** - Add "Quick Start" section:
```markdown
## Quick Start

### Specialized CLI Tools

Build and install EPUB-specific tool:
```bash
make -f Makefile.swift build-epub-release
make -f Makefile.swift install-epub
epub-mechanic --help
```

Build and install PDF-specific tool:
```bash
make -f Makefile.swift build-pdf-release
make -f Makefile.swift install-pdf
pdf-mechanic --help
```
```

2. **Root README.md** (if exists) - Add Swift CLIs section

**Estimated time**: 1 hour

---

### 4. 🔧 Shell Completions (Priority: Medium)

**Why**: Improve user experience with tab completion.

**What to do**:

1. Study existing completion generation in `Packages/EbookMechanicCLI/Sources/EbookMechanicCLI/ShellCompletion.swift`

2. Create similar completion generators for EbookMechanicEPUBCLI and EbookMechanicPDFCLI

3. Add Makefile targets:
```makefile
epub-completions:
	@mkdir -p completions
	@Packages/EbookMechanicEPUBCLI/.build/release/EbookMechanicEPUBCLI --generate-completion bash > completions/epub-mechanic.bash
	# ... other shells

pdf-completions:
	@mkdir -p completions
	@Packages/EbookMechanicPDFCLI/.build/release/EbookMechanicPDFCLI --generate-completion bash > completions/pdf-mechanic.bash
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

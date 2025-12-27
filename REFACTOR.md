# Refactor Plan (Step-by-step, reversible)

This document is a play-by-play plan to refactor the repo into a cleaner, Apple/Xcode-friendly layout. Every step is isolated so we can revert at any point with `git checkout .` (or by resetting to the safety branch).

## Goals

- Align with common Apple/Xcode structure: `Apps/`, `Packages/`, `Docs/`, `Scripts/`.
- Keep all packages and targets working.
- Update scripts/Makefiles and the workspace with the new paths.
- Keep changes small and reversible, with validation after each phase.

## Target Layout (final)

```
EbookMechanic.xcworkspace
Apps/
  EbookMechanicApp/
Packages/
  EbookMechanicCore/
  EbookMechanicCLI/
  EbookMechanicEPUBCLI/
  EbookMechanicPDFCLI/
Docs/
Scripts/
```

Notes:

- `EbookMechanicEPUBCLI` and `EbookMechanicPDFCLI` are renamed for consistency.
- The existing `swift/` root is removed in favor of `Apps/` and `Packages/`.

---

## Step 0 - Safety branch (snapshot)

1. Ensure working tree is clean (or commit current changes).
   - `git status -sb`
2. Create the safety branch:
   - `git branch safety/pre-refactor`
   - `git push -u origin safety/pre-refactor` (optional, if you want it on remote)
3. Confirm branch exists:
   - `git branch --list | rg safety/pre-refactor`

Rollback:

- `git checkout safety/pre-refactor`

---

## Step 1 — Prep (baseline verification)

1. Confirm current builds/tests:
   - `make -C swift build-all`
   - `make -C swift test-all` (optional but recommended)
2. Open workspace to confirm current schemes are healthy:
   - `open swift/EbookMechanic.xcworkspace`

Rollback:

- No file changes; nothing to rollback.

---

## Step 2 — Create new top-level folders

1. Create new directories (no moves yet):
   - `mkdir -p Apps Packages Docs Scripts`
2. Verify structure:
   - `ls -la`

Rollback:

- `rmdir Apps Packages Docs Scripts` (if empty)

---

## Step 3 — Move Swift workspace + app

1. Move the workspace and app target:
   - `mv swift/EbookMechanic.xcworkspace ./EbookMechanic.xcworkspace`
   - `mv swift/EbookMechanicApp Apps/EbookMechanicApp`
2. Move shared Swift docs:
   - `mv swift/Docs Docs/Swift`

Rollback:

- `mv EbookMechanic.xcworkspace swift/`
- `mv Apps/EbookMechanicApp swift/`
- `mv Docs/Swift swift/Docs`

---

## Step 4 — Move and rename Swift packages

1. Move packages to `Packages/`:
   - `mv swift/EbookMechanicCore Packages/EbookMechanicCore`
   - `mv swift/EbookMechanicCLI Packages/EbookMechanicCLI`
   - `mv swift/EPUBMechanicCLI Packages/EbookMechanicEPUBCLI`
   - `mv swift/PDFMechanicCLI Packages/EbookMechanicPDFCLI`
2. Update package folder names inside any references (Package.swift paths, scripts).

Rollback:

- Move each package back to `swift/` with original names.

---

## Step 5 — Move scripts

1. Move root-level `scripts/` to `Scripts/`:
   - `mv scripts Scripts`

Rollback:

- `mv Scripts scripts`

---

## Step 6 — Update workspace references

1. Open `EbookMechanic.xcworkspace` and fix package references if broken.
2. Ensure schemes still resolve:
   - `EbookMechanicApp`
   - `EbookMechanicCore`
   - `EbookMechanicCLI`
   - `EbookMechanicEPUBCLI`
   - `EbookMechanicPDFCLI`

Rollback:

- Reopen the safety branch or restore the workspace file from it.

---

## Step 7 — Update Makefiles and scripts

1. Update top-level `Makefile` to new paths:
   - `SWIFT_DIR` -> remove or repoint to `Packages/` and `Apps/` as needed.
2. Update `swift/Makefile` equivalent:
   - Move to root as `Makefile.swift` or merge into main `Makefile`.
   - Adjust `swift run` and `swift build` paths.
3. Update any hardcoded paths in:
   - `Scripts/*`
   - `Docs/*`
   - `README.md`

Rollback:

- Revert Makefile and script changes with `git checkout -- <file>`

---

## Step 8 — Update test utilities / absolute paths

1. Fix any absolute references like:
   - `Packages/EbookMechanicEPUBCLI/Tests/EbookMechanicEPUBCLITests/TestUtils/Package.swift`
2. Replace absolute paths with relative paths to `Packages/EbookMechanicCore`.

Rollback:

- Restore the file to original via `git checkout -- <file>`

---

## Step 9 — Clean up legacy `swift/` directory

1. Verify `swift/` is empty or remove it:
   - `rmdir swift` (only when empty)

Rollback:

- Recreate if needed, or checkout from safety branch.

---

## Step 10 — Build + test after refactor

1. Build all targets:
   - `make build-all`
2. Run tests:
   - `make test-all`
3. Open app from Xcode and run.

Rollback:

- If anything fails, use `git checkout safety/pre-refactor`.

---

## Step 11 — Commit and finalize

1. Stage all refactor changes:
   - `git add -A`
2. Commit:
   - `git commit -S -m "refactor: reorganize workspace and packages"`

---

## Step 12 — Remove safety branch (after validation)

1. Confirm everything is good.
2. Delete safety branch:
   - `git branch -d safety/pre-refactor`
   - `git push origin --delete safety/pre-refactor` (if pushed)

Rollback:

- If you want to keep it, do nothing.

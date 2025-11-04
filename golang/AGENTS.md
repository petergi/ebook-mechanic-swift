# Repository Guidelines

## Project Structure & Module Organization
EbookMechanic is a single-module Go project rooted here. Core execution lives in `main.go` with supporting packages co-located: `scanner.go` handles directory traversal, `validator.go` guards format checks, and `repair.go`/`report.go` orchestrate remediation and summaries. Tests mirror sources as `*_test.go`. Build artifacts drop into `build/`, release bundles into `dist/`, and coverage reports into `coverage/`. The `python/` folder holds exploratory scripts—modify only when you can keep them aligned with the Go pipeline.

## Build, Test & Development Commands
Use the Makefile for repeatable workflows:
- `make build` compiles an optimized binary into `build/ebook-mechanic`.
- `make run` (or `go run .`) launches the TUI against the current directory.
- `make test` runs `go test -v ./...`; add `test-race` for race detection.
- `make check` chains `fmt`, `vet`, and `lint` (requires `golangci-lint`).
- `make test-coverage` produces `coverage/coverage.html` for review.
Keep Go modules tidy with `make deps`.

## Coding Style & Naming Conventions
Follow idiomatic Go, formatted with `make fmt` (`gofmt -s -w`). Exported symbols use PascalCase, internal helpers stay camelCase, and file names remain lowercase without spaces. Keep flag defaults in package-level constants, and locate CLI-facing logic in `main.go` so user experience remains centralized. Prefer clear, declarative variable names over abbreviations.

## Testing Guidelines
Author table-driven tests beside their sources. Use `t.Run` subtests for boundary cases, and cover repair/dry-run flows to prevent regressions. Maintain coverage via `make test-coverage`; review the HTML report before submitting. For longer-running scenarios, gate them with build tags so `make test` stays fast for contributors.

## Commit & Pull Request Guidelines
Commits follow an imperative, sentence-case summary (e.g., `Fix clean-all target`), optionally expanding with concise context or bullet points. For pull requests, link issues, describe behavioural changes, and list the Make targets you executed (`make check`, `make test-coverage`, etc.). Include terminal captures or screenshots when altering TUI output, and ensure the branch is rebased before requesting review.

## Release & Operations Notes
Version metadata is injected during builds; `make build` and `make release` bake `VERSION`, `BuildTime`, and `GitCommit` into the binary. Docker workflows live under `make docker-build`/`docker-run`; update `test-books/` fixtures if the container interface changes. Clean artifacts with `make clean`, reserving `clean-modcache` for rare situations because it touches the global Go module cache.

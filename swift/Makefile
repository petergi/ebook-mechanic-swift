# EbookMechanic Swift workspace make targets

SPM_ENV := SWIFT_MODULE_CACHE_PATH=.build/module-cache CLANG_MODULE_CACHE_PATH=.build/module-cache

.PHONY: help core-test core-build cli-build cli-run cli-test app-build app-run app-test workspace clean

help:
	@echo "EbookMechanic Make Targets"
	@echo "--------------------------------"
	@echo "make help          - Show this help message."
	@echo "make core-test     - Run the EbookMechanicCore XCTest suite."
	@echo "make core-build    - Build the core library without running tests."
	@echo "make cli-build     - Compile the EbookMechanicCLI executable."
	@echo "make cli-run ARGS= - Run the CLI with optional arguments (default: --help)."
	@echo "make cli-test      - Execute the shared test suite via the CLI target."
	@echo "make app-build     - Build the macOS SwiftUI app via SwiftPM."
	@echo "make app-run       - Launch the SwiftUI app from SwiftPM (debug build)."
	@echo "make app-test      - Execute the shared test suite via the app target."
	@echo "make workspace     - Open EbookMechanic.xcworkspace in Xcode."
	@echo "make clean         - Remove SwiftPM build artifacts for all packages."
	@echo ""
	@echo "Environment defaults:"
	@echo "  SWIFT_MODULE_CACHE_PATH and CLANG_MODULE_CACHE_PATH are pinned to .build/module-cache"
	@echo "  to keep sandboxed builds reproducible. Override SPM_ENV to customise."

core-test:
	$(SPM_ENV) swift test --disable-sandbox --package-path EbookMechanicCore

core-build:
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCore

cli-build:
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicCLI

cli-run:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicCLI EbookMechanicCLI $(if $(ARGS),$(ARGS),--help)

cli-test:
	$(SPM_ENV) swift test --disable-sandbox --package-path EbookMechanicCLI

app-build:
	$(SPM_ENV) swift build --disable-sandbox --package-path EbookMechanicApp

app-run:
	$(SPM_ENV) swift run --disable-sandbox --package-path EbookMechanicApp EbookMechanicApp

app-test:
	$(SPM_ENV) swift test --disable-sandbox --package-path EbookMechanicApp

workspace:
	open EbookMechanic.xcworkspace

clean:
	rm -rf EbookMechanicCore/.build EbookMechanicCLI/.build EbookMechanicApp/.build

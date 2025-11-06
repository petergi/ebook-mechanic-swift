# Outstanding Tasks

- Add integration tests that run the CLI against temporary library fixtures to exercise the entire pipeline end-to-end.
- Investigate additional EPUB edge cases in the custom `ZipArchive` implementation (e.g., encrypted archives, unusual compression flags) and consider pulling in a battle-tested dependency if the scope grows.
- Explore packaging the SwiftUI macOS app for distribution (codesigning, notarisation, app icon assets, Sparkle updates).
- Evaluate adding a cross-platform SwiftUI variant (iPad/iOS) once directory access requirements and sandbox permissions are clarified.
- Automate generation/synchronisation of the legacy `.xcodeproj` stubs to avoid manual drift when Makefile targets change.

# 📱 EbookMechanic macOS App

A beautiful native macOS application for ebook library management, built with SwiftUI and powered by the EbookMechanicCore library.

## Overview

The EbookMechanicApp provides a graphical interface for the EbookMechanic toolkit, offering the same powerful validation and repair capabilities in a polished, user-friendly macOS application. Built with SwiftUI and Swift's modern concurrency model, it delivers real-time progress updates and an intuitive workflow.

## Features

- 🎨 **Beautiful SwiftUI Interface** - Gradient-backed design with modern aesthetics
- 📂 **Native Directory Picker** - `NSOpenPanel` integration for file selection
- 📊 **Real-Time Progress** - Live progress bars during scanning and operations
- ⏯️ **Pause/Resume Scans** - Temporarily pause a scan and continue later
- ⏹️ **Cancelable Scans** - Stop an in-flight scan from the primary controls
- 🎚️ **Toggle Controls** - Easy switches for repair, dry-run, and confirmation settings
- 📋 **Scrollable Results** - View lists of corrupted files and empty folders
- 🔄 **Observable State** - Reactive updates using SwiftUI's state management
- 📱 **iOS Ready** - Architecture prepared for iOS 16+ deployment
- 🧪 **Tested** - View-model tests ensure predictable behavior

## Architecture

### Components

**EbookMechanicApp.swift**

- App entry point
- SwiftUI `App` protocol conformance
- Window group configuration

**ContentView.swift**

- Main UI layout
- Gradient background design
- Control panels and result displays
- Progress visualization

**ScanViewModel.swift**

- Observable view model (`ObservableObject`)
- Business logic and state management
- Integration with `FileScanner` from Core library
- `@Published` properties for reactive updates

**ScanOptions.swift**

- Configuration model for scan operations
- User preferences and settings
- Codable for persistence (future enhancement)

### Dependencies

- **EbookMechanicCore** - Core library with scanning and validation logic
- **SwiftUI** - Native UI framework (built-in)
- **AppKit** - For `NSOpenPanel` directory picker

## Installation

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Build from Source

```bash
# Navigate to swift directory
cd swift

# Build the app
make app-build

# Run the app
make app-run

# Or build and run in one step
make app-build app-run
```

### Using Xcode

```bash
# Open workspace in Xcode
make workspace

# Or open directly
open ../EbookMechanic.xcworkspace

# Select EbookMechanicApp scheme and run
```

## Usage

### Launching the App

```bash
# From swift directory
make app-run

# Or directly from build directory
open EbookMechanicApp/.build/debug/EbookMechanicApp.app
```

### Using the Interface

1. **Select Directory**
   - Click "Select Directory" button
   - Choose ebook library folder from picker
   - Path displays below button

2. **Configure Options**
   - Toggle "Repair corrupted files" for auto-repair
   - Toggle "Dry run" to preview without changes
   - Toggle "Confirm actions" for interactive prompts

3. **Start Scan**
   - Click "Run Scan" to begin
   - Watch real-time progress updates
   - View status messages as the scan progresses
   - Click "Pause" to temporarily halt processing
   - Click "Resume" to continue from where you paused
   - Click "Cancel Scan" to stop a scan in progress

4. **Review Results**
   - Scroll through "Corrupted Files" list
   - Review "Empty Folders" list
   - Check statistics panel

### Features in Detail

**Directory Selection:**

- Native macOS file picker
- Remembers last selected directory (session-based)
- Validates directory accessibility

**Progress Tracking:**

- Real-time progress bar (0-100%)
- Current operation status
- File count updates

**Results Display:**

- Corrupted files with full paths
- Empty folders identified for removal
- Color-coded lists for easy identification

**Configuration:**

- Repair: Automatically fix corrupted files
- Dry Run: Preview changes without modifications
- Confirm: Prompt before deletion operations

## Testing

The app includes view-model tests to ensure predictable state management:

```bash
# Run app tests
make app-test

# Or use Swift directly
swift test --package-path EbookMechanicApp
```

### Test Coverage

- **ScanOptionsTests.swift** - Configuration model tests (3 tests)
- View-model behavior validation
- State transition testing

## Development

### Project Structure

```
EbookMechanicApp/
├── Package.swift                 # Swift package manifest
├── README.md                     # This file
├── Sources/
│   └── EbookMechanicApp/
│       ├── EbookMechanicApp.swift     # App entry point
│       ├── ContentView.swift          # Main UI view
│       ├── ScanViewModel.swift        # Business logic
│       └── ScanOptions.swift          # Configuration model
└── Tests/
    └── EbookMechanicAppTests/
        └── ScanOptionsTests.swift     # Test suite
```

### Adding Features

**To add a new toggle option:**

1. Add property to `ScanOptions.swift`
2. Add `@Published` property to `ScanViewModel`
3. Add Toggle view in `ContentView.swift`
4. Update scan logic to use new option
5. Add tests in `ScanOptionsTests.swift`

**To modify the UI:**

1. Edit `ContentView.swift` for layout changes
2. Update `ScanViewModel` for state management
3. Test reactive updates with preview

### SwiftUI Previews

Enable live previews in Xcode for rapid UI iteration:

```swift
#Preview {
    ContentView()
}
```

## Design Philosophy

### SwiftUI Best Practices

- **Single Source of Truth** - ViewModel owns state
- **Reactive Updates** - `@Published` properties drive UI
- **Separation of Concerns** - UI vs business logic
- **Reusable Components** - Modular view design

### Color Scheme

- **Background** - Blue to purple gradient
- **Primary** - White text on gradient
- **Secondary** - Light gray for secondary elements
- **Accent** - System blue for interactive elements

### Layout

- **Vertical Stack** - Top-to-bottom flow
- **Grouped Sections** - Related controls together
- **Scrollable Lists** - For variable-length results
- **Responsive** - Adapts to window resizing

## Platform Support

### Current

- ✅ macOS 13.0+

### Future

- 📱 iOS 16.0+ (architecture ready)
- 📱 iPadOS 16.0+ (architecture ready)
- ⚙️ Configuration needed for iOS deployment

The app architecture uses platform-agnostic SwiftUI, making iOS/iPadOS ports straightforward with minimal changes.

## Performance

### Responsiveness

- **UI Updates** - Main thread via `@MainActor`
- **Heavy Operations** - Background tasks via `FileScanner` actor
- **Progress** - Smooth 60fps updates
- **Memory** - Efficient with large file lists

### Optimization

- Actor-based concurrency prevents UI freezing
- Lazy loading for large result lists
- Efficient state updates with `@Published`

## Troubleshooting

### Build Errors

```bash
# Clean and rebuild
make clean-all
make app-build
```

### App Won't Launch

```bash
# Check build output
make app-build

# Verify binary exists
ls -la EbookMechanicApp/.build/debug/

# Run with verbose output
swift run --package-path EbookMechanicApp EbookMechanicApp
```

### UI Not Updating

- Ensure `@Published` properties used in ViewModel
- Verify `@StateObject` usage in views
- Check `@MainActor` annotations for UI updates

## Future Enhancements

### Planned Features

- [ ] Preferences panel for default settings
- [ ] Persistent directory history
- [ ] Drag-and-drop directory selection
- [ ] Dark mode support
- [ ] Menubar icon and status
- [ ] Export reports as PDF
- [ ] Batch operation queue
- [ ] iOS/iPadOS versions

### Contribution Ideas

- Enhanced progress visualization
- Multiple directory support
- Custom color schemes
- Keyboard shortcuts
- AppleScript support
- Notification center integration

## Related Documentation

- [Swift Implementation README](../README.md) - Full Swift implementation docs
- [Core Library](../EbookMechanicCore/) - Underlying validation engine
- [CLI Tool](../EbookMechanicCLI/) - Command-line interface

## License

This project is licensed under the MIT License.

## Credits

- Built with SwiftUI and Swift Concurrency
- Powered by EbookMechanicCore library

---

**Quick Links:** [Swift README](../README.md) | [Parent README](../../README.md) | [Core Library](../EbookMechanicCore/) | [CLI Tool](../EbookMechanicCLI/)

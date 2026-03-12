# FileButler

Open-source file automation for macOS. Pure Swift menubar app, no external dependencies.

## Architecture

- `FileButler/` - Swift source code
  - `App/` - FileButlerApp.swift (menubar, @main), NotificationManager.swift
  - `Engine/` - Types.swift, Engine.swift (rule evaluation), Watcher.swift (FSEvents)
  - `Matchers/` - All matcher functions
  - `Actions/` - All action functions
  - `Utils/` - MacOSTags.swift, SpotlightMetadata.swift, Logger.swift
- `Rules/Rules.swift` - Personal rules (gitignored, compiled with app)
- `Rules/Rules.example.swift.template` - Example rules (committed, not compiled)
- `scripts/build.sh` - Build script (swiftc, icon generation)

## Build

```bash
sh scripts/build.sh               # Compile + generate icons + install to ~/Applications
open ~/Applications/FileButler.app # Launch
```

No Xcode project needed. swiftc compiles all .swift files from FileButler/ and Rules/.

## How Rules Work

Rules are evaluated in order. First matching rule wins. Each rule has:
- `name` - Human-readable name
- `watch` - Directory path to watch (supports ~)
- `match` - Array of Matchers (all must match)
- `action` - Array of Actions (executed sequentially)

Actions take `inout FileInfo` so rename() can update the path for subsequent actions.

## Available Matchers

`hasExtension`, `nameStartsWith`, `nameContains`, `nameMatches`, `isFolder`, `isFile`, `olderThan`, `addedBefore`, `notAddedToday`, `hasTag`, `lacksTag`, `hasGitRepo`, `isEmpty`, `downloadedFrom`, `shellPasses`, `not`

## Available Actions

`moveTo`, `moveToTrash`, `sortIntoSubfolder`, `rename`, `addTag`, `printFile`, `shell`, `openFile`

## macOS Native APIs

- Finder Tags: `URL.resourceValues` / `URL.setResourceValues` (tagNames)
- Spotlight: `MDItemCreateWithURL` + `MDItemCopyAttribute` (kMDItemDateAdded, kMDItemWhereFroms)
- File watching: FSEvents via `FSEventStreamCreate`
- Trash: `NSWorkspace.shared.recycle`
- Open: `NSWorkspace.shared.open`
- Notifications: `UNUserNotificationCenter`
- Launch at Login: `SMAppService.mainApp` (ServiceManagement framework)

## Target

macOS 26+, no legacy support needed.

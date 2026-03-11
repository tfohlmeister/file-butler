<p align="center">
  <img src="logo.svg" width="96" height="96" alt="FileButler logo" />
</p>

<h1 align="center">FileButler</h1>

<p align="center">
  Open-source file automation for macOS. A lightweight alternative to Hazel.
</p>

## Features

- **Pure Swift**, no external dependencies, single binary
- **FSEvents watching** with debounce for instant reactions to file changes
- **Native macOS APIs** for Finder tags, Spotlight metadata, notifications, trash
- **Menubar app** with status display and notification support
- **Periodic scans** every 30 minutes for time-based rules
- **All matching rules run**, so a file can trigger multiple rules (stops only if the file is moved or deleted)

## Quick Start

```bash
git clone https://github.com/tfohlmeister/file-butler.git
cd file-butler

# Create your personal rules
cp Rules/Rules.example.swift.template Rules/Rules.swift
$EDITOR Rules/Rules.swift

# Build and run
sh scripts/build.sh
open FileButler.app
```

## Install as launchd Service

```bash
cp com.tfohlmeister.file-butler.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.tfohlmeister.file-butler.plist
```

### Environment Variables

If your rules use `shell(...)` actions that reference environment variables (e.g. API tokens), create a `.env` file next to `FileButler.app`:

```bash
# .env (gitignored, never committed)
SEVDESK_TOKEN=your-token-here
ANOTHER_SECRET=foobar
```

FileButler loads this file on startup and makes all variables available to shell actions. Rebuild is not required when changing `.env`, just restart the app.

To uninstall:

```bash
launchctl bootout gui/$(id -u)/com.tfohlmeister.file-butler
rm ~/Library/LaunchAgents/com.tfohlmeister.file-butler.plist
```

## Writing Rules

Rules are defined in `Rules/Rules.swift`. They are compiled into the app, so rebuild after editing.

```swift
import Foundation

enum Rules {
    static let all: [Rule] = [
        Rule(name: "Clean old DMGs", watch: "~/Downloads",
             match: [hasExtension("dmg"), olderThan(.init(days: 7))],
             action: [moveToTrash()]),

        Rule(name: "Sort old downloads", watch: "~/Downloads",
             match: [isFile(), notAddedToday()],
             action: [sortIntoSubfolder { f in formatDate(f.dateAdded) }]),
    ]
}
```

Rules are evaluated **in order**. All matching rules are applied, unless the file is moved or deleted by a previous rule.

## Available Matchers

| Matcher | Description |
|---------|-------------|
| `hasExtension("stl", "obj")` | File has one of the given extensions |
| `nameStartsWith("DHL")` | Filename starts with prefix |
| `nameContains("invoice")` | Filename contains substring (case-insensitive) |
| `nameMatches("\\d{4}-\\d{2}")` | Filename matches regex |
| `isFolder()` | Entry is a directory |
| `isFile()` | Entry is a file |
| `olderThan(.init(days: 7))` | dateModified is older than duration |
| `addedBefore(.init(hours: 2))` | dateAdded is older than duration |
| `notAddedToday()` | dateAdded is not today |
| `hasTag("Yellow")` | Has macOS Finder tag |
| `lacksTag("Keep")` | Does not have macOS Finder tag |
| `hasGitRepo()` | Directory contains a .git folder |
| `isEmpty()` | Directory has no visible items |
| `downloadedFrom("https://...")` | kMDItemWhereFroms starts with URL |
| `shellPasses("test -f {path}")` | Shell command exits with 0 |
| `not(matcher)` | Negates a matcher |

## Available Actions

| Action | Description |
|--------|-------------|
| `moveTo("~/Archive")` | Move file to destination directory |
| `moveToTrash()` | Move to Trash via NSWorkspace |
| `sortIntoSubfolder { f in ... }` | Create subfolder from closure and move file into it |
| `rename { f in ... }` | Rename file using closure |
| `addTag("Yellow")` | Add macOS Finder tag |
| `printFile()` | Print via `lpr` |
| `shell("command {path}")` | Run shell command (`{path}` and `{name}` are replaced) |
| `openFile()` | Open with default macOS app |

## Notifications

FileButler sends macOS notifications for every rule match. The notification shows the rule name and filename.

## Requirements

macOS 26+

## License

MIT

---

<sub>Hazel is a trademark of Noodlesoft. FileButler is not affiliated with or endorsed by Noodlesoft.</sub>

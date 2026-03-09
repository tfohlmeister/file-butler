---
description: Add a new file automation rule to FileButler
---

# Add Rule

When the user wants to add a new rule:

1. Read `Rules/Rules.swift` to see existing rules
2. Read `FileButler/Matchers/Matchers.swift` and `FileButler/Actions/Actions.swift` for available functions
3. Add the new rule to the `all` array in `Rules/Rules.swift`

## Rule Structure

```swift
Rule(name: "Human readable name", watch: "~/path/to/watch",
     match: [matcher1(), matcher2()],
     action: [action1(), action2()])
```

## Important

- Rule ORDER matters: specific rules before catch-all rules
- First matching rule wins, subsequent rules are skipped for that file
- Use `~` prefix for home directory paths
- After editing, rebuild with `sh scripts/build.sh` and relaunch the app

## Common Patterns

- Move files by extension: `match: [hasExtension("pdf")], action: [moveTo("~/dest")]`
- Tag + process: `match: [hasExtension("pdf"), hasTag("Yellow")], action: [shell("..."), moveTo("...")]`
- Time-based cleanup: `match: [isFile(), olderThan(.init(days: 7))], action: [moveToTrash()]`
- Rename with closure: `rename { f in "prefix-\(f.name)" }`

---
description: Modify an existing FileButler rule
---

# Modify Rule

When the user wants to modify an existing rule:

1. Read `Rules/Rules.swift` to find the rule by name
2. Read `FileButler/Matchers/Matchers.swift` and `FileButler/Actions/Actions.swift` if new matchers/actions are needed
3. Edit the rule in place using the Edit tool
4. Remind the user to rebuild (`sh scripts/build.sh`) and relaunch the app

## Tips

- Keep rule names descriptive
- When changing match conditions, consider if the rule order still makes sense
- When changing actions, remember they execute sequentially (e.g., rename before move)
- The `rename` action updates the FileInfo path in-place for subsequent actions (inout parameter)

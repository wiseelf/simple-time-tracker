# CLAUDE.md — Simple Time Tracker

## What this project is

A native macOS menu bar time tracker (no Dock icon, no background monitoring). Swift + SwiftUI, minimum macOS 13, Swift Package Manager only.

## Build & Run

```bash
swift run                  # development
swift build -c release     # release binary → .build/release/TimeTracker
```

## Working in this codebase

- **Patterns & gotchas** — see [`.claude/rules/patterns.md`](.claude/rules/patterns.md)
- **Git workflow & commit conventions** — see [`.claude/rules/workflow.md`](.claude/rules/workflow.md)
- **Full architecture detail** — see [`README.md`](README.md#architecture)
- **Key implementation notes** — see [`README.md`](README.md#key-implementation-notes)

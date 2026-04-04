# CLAUDE.md — Simple Time Tracker

## What this project is
A native macOS menu bar time tracker (no Dock icon, no background monitoring). Swift + SwiftUI, minimum macOS 13, Swift Package Manager only.

## Build & Run
```bash
swift run          # development
swift build -c release   # release binary → .build/release/TimeTracker
```

## Architecture at a glance

| File | Role |
|---|---|
| `main.swift` | Entry point — NSApplication, `.accessory` policy, no `@main` |
| `AppDelegate.swift` | NSStatusItem, main panel, detail panel, About window, context menu |
| `ContentView.swift` | Two-tab layout (Timer / Stats) |
| `StatsView.swift` | Bar-chart stats, export/import |
| `SessionsListView.swift` | Per-day session list, inline edit/delete |
| `SessionDetailView.swift` | Floating detail panel (opens beside main panel) |
| `SessionDetailState.swift` | ObservableObject shared by AppDelegate + SessionDetailView |
| `TimerManager.swift` | Timer logic singleton (`TimerManager.shared`) |
| `SessionStore.swift` | Persistence to `~/Library/Application Support/TimeTracker/sessions.json` |
| `TimeSession.swift` | `Codable` model (`id`, `startDate`, `duration`, `isManual`, `note?`) |
| `NoteButton.swift` | Reusable note preview + popover TextEditor |
| `DayTimelineView.swift` | 24-hour Canvas timeline |
| `TimePickerField.swift` | Custom HH:MM NSViewRepresentable |

## Key constraints & gotchas

- **No `@main`** — conflicts with `main.swift`. Always use `AppDelegate`.
- **`onChange(of:)`** — single-arg form `{ newValue in }` for macOS 13. Two-arg requires macOS 14+.
- **Borderless NSPanel + text fields** — subclass and override `canBecomeKey`/`canBecomeMain` to `true`.
- **SF Symbol coloring in NSImage** — use `NSImage.SymbolConfiguration(paletteColors:)`, not `contentTintColor`.
- **`UNUserNotificationCenter`** — guard every call with `Bundle.main.bundleIdentifier != nil` (crashes without a bundle ID when running via `swift run`).
- **Modal dialogs (NSSavePanel/NSOpenPanel/NSAlert)** — use `withPanelLowered(_:)` and set `suppressAutoClose = true` before showing any modal; restore after.
- **Panel height** — always clamp to `panelAnchorTop - screen.visibleFrame.minY - 10` to prevent content going above the menu bar.
- **`MenuBarExtra` label colors** are stripped by macOS — always draw a custom `NSImage` for the status item.
- **Right-click on NSStatusBarButton** — assign `statusItem.menu` temporarily, call `performClick`, then clear immediately so left-click keeps its custom action.
- **Import JSON** — use `JSONDecoder` with `.iso8601` date strategy to match the encoder.
- **`note` on `TimeSession`** is optional in JSON; pass `nil` (not empty string) at call sites — trim and nil-coalesce before calling `SessionStore.update`.

## Git workflow

- **All work on dedicated branches** — never commit directly to `main`.
- Branch names: `feature/<short-description>` or `fix/<short-description>`.
- Open a PR against `main` when done; merge only after review.

## Commit messages (Conventional Commits)

```
<type>[optional scope]: <short description>
```

| Type | Version bump |
|---|---|
| `fix:` | patch |
| `feat:` | minor |
| `feat!:` / `BREAKING CHANGE:` | major |
| `chore:`, `docs:`, `refactor:`, `test:`, `style:` | patch |

The CI release workflow auto-picks the highest bump from commits since the last tag.

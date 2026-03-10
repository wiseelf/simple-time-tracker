# Simple Time Tracker

A lightweight native macOS menu bar app for tracking time. No Dock icon, no background monitoring — just a clean timer with manual entry and daily/weekly/monthly statistics.

## Features

- **Menu bar timer** — lives entirely in the menu bar, no Dock icon
- **Start / Stop / Reset** — track time for any task with a single click or `Space`
- **Manual entry** — add time retroactively (hours + minutes)
- **Persistent sessions** — time is saved automatically; today's total is restored on relaunch
- **Statistics** — view totals by day, week, or month with backwards navigation
- **Adaptive icon** — green (running), orange (paused with time), default (idle)

## Requirements

- macOS 13 Ventura or later
- Swift 5.9+ / Xcode 15+ (or command-line tools)

## Getting Started

```bash
# Clone
git clone https://github.com/wiseelf/simple-time-tracker.git
cd simple-time-tracker

# Run in development
swift run

# Build a release binary
swift build -c release
# Binary output: .build/release/TimeTracker
```

No additional dependencies — the project uses only Apple frameworks (AppKit, SwiftUI, Combine, Foundation).

## Project Structure

```
simple-time-tracker/
├── Package.swift
└── Sources/TimeTracker/
    ├── main.swift          # Entry point — NSApplication setup
    ├── AppDelegate.swift   # Status bar item + popup panel lifecycle
    ├── ContentView.swift   # Main SwiftUI view (Timer tab + Stats tab)
    ├── StatsView.swift     # Statistics view with week/month navigation
    ├── TimerManager.swift  # Timer logic (ObservableObject singleton)
    ├── SessionStore.swift  # Persistence layer (ObservableObject singleton)
    └── TimeSession.swift   # Codable model for a single tracked session
```

## Architecture

### Entry point — `main.swift`

Creates `NSApplication`, sets the activation policy to `.accessory` (hides the Dock icon), attaches `AppDelegate`, and calls `app.run()`.

> **Note:** `@main` App struct is intentionally avoided — it conflicts with `main.swift`.

### `AppDelegate`

Owns the `NSStatusItem` and the floating `NSPanel` popup.

- **Status bar button** — a custom-drawn `NSImage` (non-template) rendered off-screen. Contains a pill border, an SF Symbol icon, and the current time text, all colored according to timer state.
- **Popup panel** — an `NSPanel` with `.borderless` + `.nonactivatingPanel` style masks. The background is an `NSVisualEffectView` with `.popover` material and a 12 pt corner radius (frosted glass effect).
- **Panel positioning** — placed flush below the menu bar button using `button.window?.convertToScreen(...)` + `setFrameTopLeftPoint`.
- **Panel dismissal** — a global `NSEvent` monitor handles outside clicks; `NSApplication.didResignActiveNotification` handles Cmd+Tab / app switches. Both are cleaned up in `closePanel()`.

### `TimerManager` (singleton)

`TimerManager.shared` — `ObservableObject`.

| Method | Description |
|---|---|
| `start()` | Starts a `Timer` firing every second, records `segmentStartDate` |
| `stop()` | Invalidates timer, calculates delta since last save, writes a `TimeSession` |
| `reset()` | Stops and zeroes all counters |
| `addTime(hours:minutes:)` | Records a manual `TimeSession` immediately |
| `loadTodayTime()` | Called once at launch to seed `elapsedSeconds` with today's saved total |

### `SessionStore` (singleton)

`SessionStore.shared` — `ObservableObject`.

- Persists to `~/Library/Application Support/TimeTracker/sessions.json` (ISO-8601 dates).
- Sessions are always kept sorted by `startDate`.

| Query | Description |
|---|---|
| `sessions(on:)` | All sessions for a given calendar day |
| `sessions(weekOffset:)` | Sessions for the week at `offset` from the current week (0 = this week, -1 = last week, …) |
| `sessions(monthOffset:)` | Sessions for the month at `offset` from the current month |
| `totalSeconds(in:)` | Sums `duration` across a session array |

### `TimeSession`

```swift
struct TimeSession: Codable, Identifiable {
    let id: UUID
    let startDate: Date   // ISO-8601 in JSON
    let duration: Int     // seconds
    let isManual: Bool    // true for manually entered time
}
```

### `ContentView`

Two-tab layout (Timer / Stats) using a `.segmented` `Picker`.

- **Timer tab** — large monospaced countdown display, Start/Stop button (`Space` shortcut), manual time entry form.
- **Stats tab** — delegates to `StatsView`.

### `StatsView`

- Always shows "Today" total at the top.
- `Picker` to switch between Week and Month views.
- Navigation row: `‹ label ⌄ ›` — arrows step ±1 period; the label opens a `Menu` listing all periods that contain data.
- Week and month offsets are independent — switching between them preserves the last viewed position.
- Forward navigation is disabled when `offset >= 0` (can't navigate into the future).

## Menu Bar Icon States

| State | Color |
|---|---|
| Idle (no time recorded) | `labelColor` (adapts to light/dark mode) |
| Running | `systemGreen` |
| Paused with time | `systemOrange` |

The icon is rendered with `NSImage.SymbolConfiguration(paletteColors:)` to bake the color in before drawing.

## Key Implementation Notes

- **SF Symbol coloring** in off-screen `NSImage`: use `NSImage.SymbolConfiguration(paletteColors:)` — **not** `contentTintColor`, `attributedTitle`, or `destinationIn` compositing.
- **Menu bar label colors** are stripped by macOS — always use `NSStatusItem` with a custom-drawn `NSImage` for colored items.
- **`onChange(of:)`** — use the single-argument form `{ newValue in }` for macOS 13 compatibility. The two-argument form `{ _, new in }` requires macOS 14+.

## Contributing

Every new feature or bug fix must be developed on a dedicated branch and submitted as a merge (pull) request for review before merging into `main`. See [CONTRIBUTING](#contributing-workflow) below.

### Contributing Workflow

1. Create a new branch from `main`:
   ```bash
   git checkout main && git pull
   git checkout -b feature/your-feature-name
   # or: fix/your-bug-name
   ```
2. Make your changes, commit with clear messages.
3. Push the branch and open a pull request against `main`.
4. Address review comments, then merge after approval.

Direct commits to `main` are not allowed.

## Data & Privacy

All data is stored locally at `~/Library/Application Support/TimeTracker/sessions.json`. Nothing is sent over the network.

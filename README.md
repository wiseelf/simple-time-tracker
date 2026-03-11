# Simple Time Tracker

A lightweight native macOS menu bar app for tracking time. No Dock icon, no background monitoring — just a clean timer with manual entry, visual timeline, and daily/weekly/monthly statistics.

## Features

- **Menu bar timer** — lives entirely in the menu bar, no Dock icon
- **Start / Stop / Reset** — track time with a single click or `Space`
- **Manual entry (duration)** — add time retroactively by specifying hours + minutes
- **Manual entry (range)** — pick a day, From, and To time with a custom HH:MM picker and a 24-hour visual timeline; supports any past day
- **Edit / Delete sessions** — tap any day in the Stats bar chart to open a session detail panel; edit start/end times or delete sessions for any past day
- **Auto-stop on sleep / screensaver** — timer stops automatically when the Mac sleeps or the screensaver activates; a system notification is sent
- **Automatic day reset** — at midnight the timer resets to `00:00:00`; if it was running, the previous day's session is saved and the timer restarts fresh for the new day
- **Persistent sessions** — time is saved automatically; today's total is restored on relaunch
- **Statistics** — bar chart per day (week view) or per calendar week (month view), with period total and daily average; navigation labels show date ranges
- **Export / Import** — back up all sessions to a JSON file and restore (merge or replace) on any machine
- **System notifications** — notified when the timer starts, stops, or is auto-stopped
- **Right-click menu** — right-click the menu bar icon to access About and Quit without opening the main panel
- **App icon** — custom clock-face icon; green (running), orange (paused), default (idle)
- **About window** — shows app icon, version, description, and author info

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

No additional dependencies — the project uses only Apple frameworks (AppKit, SwiftUI, Combine, Foundation, UserNotifications).

> **Note:** System notifications require a proper `.app` bundle with a bundle identifier. They are silently skipped when running via `swift run`.

## Project Structure

```
simple-time-tracker/
├── Package.swift
├── scripts/
│   └── generate_icon.swift         # CoreGraphics script — generates AppIcon PNG assets
└── Sources/TimeTracker/
    ├── main.swift                  # Entry point — NSApplication setup
    ├── AppDelegate.swift           # Status bar item, main panel, detail panel, context menu, About window
    ├── ContentView.swift           # Main SwiftUI view (Timer tab + Stats tab)
    ├── StatsView.swift             # Bar-chart statistics view with export/import
    ├── SessionsListView.swift      # Per-day session list with inline edit/delete
    ├── SessionDetailView.swift     # Floating detail panel shown alongside the main panel
    ├── SessionDetailState.swift    # ObservableObject shared between AppDelegate and SessionDetailView
    ├── AboutView.swift             # About window content
    ├── DayTimelineView.swift       # 24-hour visual timeline for range entry
    ├── TimePickerField.swift       # Custom NSViewRepresentable HH:MM time input
    ├── TimerManager.swift          # Timer logic (ObservableObject singleton)
    ├── SessionStore.swift          # Persistence layer (ObservableObject singleton)
    ├── TimeSession.swift           # Codable model for a single tracked session
    └── Assets.xcassets/            # App icon asset catalog
```

## Architecture

### Entry point — `main.swift`

Creates `NSApplication`, sets the activation policy to `.accessory` (hides the Dock icon), attaches `AppDelegate`, and calls `app.run()`.

> **Note:** `@main` App struct is intentionally avoided — it conflicts with `main.swift`.

### `AppDelegate`

Owns the `NSStatusItem`, the main `NSPanel` popup, the session detail panel, and the About window.

- **Status bar button** — a custom-drawn `NSImage` (non-template) rendered off-screen. Contains a pill border, an SF Symbol icon, and the current time text, all colored according to timer state. Left-click toggles the main panel; right-click shows a context menu (About / Quit).
- **Main panel** — a `KeyablePanel: NSPanel` subclass (overrides `canBecomeKey` / `canBecomeMain` to `true`) with `.borderless` + `.nonactivatingPanel` style masks. The background is an `NSVisualEffectView` with `.popover` material and a 12 pt corner radius (frosted glass effect). Height is capped to the available screen space below the menu bar.
- **Session detail panel** — a second `KeyablePanel` that opens to the right of the main panel when tapping a day in Stats. Uses `orderFront` (not `makeKeyAndOrderFront`) to avoid stealing key focus. Backed by `SessionDetailState` so the date updates in place without recreating the panel. Closes automatically when the main panel closes.
- **Panel dismissal** — a global `NSEvent` monitor closes both panels on outside clicks; `NSApplication.didResignActiveNotification` handles Cmd+Tab / app switches. Both are suppressed via `suppressAutoClose` while modals are open.
- **About window** — a standard titled `NSPanel` (singleton) hosting `AboutView`. Reads version from `CFBundleShortVersionString`; falls back to `"dev"` when running via `swift run`.
- **Auto-stop** — observes `NSWorkspace.willSleepNotification` and `com.apple.screensaver.didstart` (via `DistributedNotificationCenter`), calling `TimerManager.stop(reason:)`.
- **Notifications** — sets itself as `UNUserNotificationCenterDelegate` and requests `.alert` + `.sound` authorization on launch (when a bundle identifier is present).

### `TimerManager` (singleton)

`TimerManager.shared` — `ObservableObject`.

| Method | Description |
|---|---|
| `start()` | Starts a `Timer` firing every second, records `segmentStartDate`, sends a start notification |
| `stop(reason:)` | Invalidates timer, calculates delta since last save, writes a `TimeSession`, sends a stop notification |
| `reset()` | Stops and zeroes all counters |
| `addTime(hours:minutes:)` | Finds the latest free slot today and records a manual `TimeSession` (throws `ManualEntryError`) |
| `addTimeRange(start:end:)` | Records a manual `TimeSession` for an explicit time range on any past day; validates same-day, start < end, not in future, no overlap (throws `ManualEntryError`) |
| `loadTodayTime()` | Called once at launch to seed `elapsedSeconds` with today's saved total and register the midnight day-change observer |
| `resyncFromStore()` | Resyncs elapsed/accumulated/saved counters from stored sessions without stopping the timer; call after any session edit or delete |

### `SessionStore` (singleton)

`SessionStore.shared` — `ObservableObject`.

- Persists to `~/Library/Application Support/TimeTracker/sessions.json` (ISO-8601 dates).
- Sessions are always kept sorted by `startDate`.

| Method | Description |
|---|---|
| `sessions(on:)` | All sessions for a given calendar day |
| `sessions(weekOffset:)` | Sessions for the week at `offset` from the current week |
| `sessions(monthOffset:)` | Sessions for the month at `offset` from the current month |
| `totalSeconds(in:)` | Sums `duration` across a session array |
| `hasOverlap(start:end:)` | Returns `true` if a time range overlaps any existing session on the same day |
| `findFreeSlot(duration:before:)` | Finds the latest free gap today that fits the given duration |
| `update(_:startDate:duration:)` | Replaces a session's start time and duration in-place, preserving its `id` |
| `exportData()` | Encodes all sessions to JSON `Data` |
| `importSessions(from:)` | Decodes and merges sessions (deduped by `id`) |
| `replaceAll(with:)` | Replaces all sessions with the provided array |

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
  - *Duration mode* — enter hours + minutes; the session is placed in the latest free slot today.
  - *Range mode* — pick a **Day** (any past date), **From**, and **To** using a `DatePicker` and `TimePickerField`; a `DayTimelineView` shows existing sessions and the selected range (blue = valid, red = conflict).
- **Stats tab** — delegates to `StatsView`.

### `StatsView`

- **Week view** — bar chart with one row per day (Mon–Sun). Today's bar is full accent color; other days are dimmed. Tapping a row with data opens the session detail panel for that day.
- **Month view** — bar chart with one row per calendar week within the month. Tapping a row navigates to the corresponding week in week view.
- Navigation labels show date ranges: `This Week · Mar 9–15`, `Last Month · Feb 2026`, etc.
- Footer shows **Total** and **Avg / day** (averaged over days/weeks with tracked time only).
- **Export** — opens `NSSavePanel`; saves all sessions as a JSON file.
- **Import** — opens `NSOpenPanel`; decodes the file, shows a confirmation alert with new/duplicate counts, and offers **Merge** (add new sessions only) or **Replace** (erase existing data).

### `SessionsListView`

Shows all sessions for a given `date` with inline edit and delete. Edit expands a row with two `TimePickerField` pickers (same validation rules as range entry, but restricted to the session's original calendar day). Calls `SessionStore.update()` + `TimerManager.resyncFromStore()` on save, and `SessionStore.delete()` + `resyncFromStore()` on delete.

### `SessionDetailView` + `SessionDetailState`

`SessionDetailState` is an `ObservableObject` held by `AppDelegate` with a `@Published var date`. `SessionDetailView` observes it, so tapping a different day in Stats updates the panel content instantly without recreating it. The panel uses `orderFront` (not `makeKeyAndOrderFront`) so it never steals key focus from the main panel.

### `DayTimelineView`

A 24-hour horizontal timeline rendered with `Canvas`. Shows:
- Existing sessions as gray blocks.
- Selected range as a blue (valid) or red (overlapping) highlight.
- A "now" marker at the current time.
- Hour labels every 3 hours (`00`, `03`, `06` … `21`, `00`) and grid lines.

### `TimePickerField`

`NSViewRepresentable` wrapping a custom `TimePickerNSView`:
- Displays `HH:MM` with a highlighted segment (hours or minutes).
- Keyboard: digit input, arrow keys to adjust, Tab / colon to switch segments, Esc to deactivate.
- Mouse: click to activate / switch segment; stepper ▲▼ buttons to adjust.
- Uses `NSEvent` local monitors instead of AppKit's first-responder chain to avoid conflicts with SwiftUI focus.

## Menu Bar Icon States

| State | Color |
|---|---|
| Idle (no time recorded) | `labelColor` (adapts to light/dark mode) |
| Running | `systemGreen` |
| Paused with time | `systemOrange` |

## Key Implementation Notes

- **SF Symbol coloring** in off-screen `NSImage`: use `NSImage.SymbolConfiguration(paletteColors:)` — **not** `contentTintColor`, `attributedTitle`, or `destinationIn` compositing.
- **Menu bar label colors** are stripped by macOS — always use `NSStatusItem` with a custom-drawn `NSImage` for colored items.
- **`onChange(of:)`** — use the single-argument form `{ newValue in }` for macOS 13 compatibility. The two-argument form `{ _, new in }` requires macOS 14+.
- **Borderless panel + text fields** — a borderless `NSPanel` returns `canBecomeKey = false` by default; subclass and override to `true` so SwiftUI `TextField` can receive focus.
- **`UNUserNotificationCenter`** requires a bundle identifier — guard with `Bundle.main.bundleIdentifier != nil` before calling `.current()` to avoid a crash when running via `swift run`.
- **Modal panels (NSSavePanel / NSOpenPanel / NSAlert) and window levels** — the popup panel sits at `.popUpMenu` level. Set `panel.level = .normal` before running any modal so it can appear on top, then restore the level after.
- **Panel height cap** — always clamp panel height to `panelAnchorTop - screen.visibleFrame.minY - 10`; if a panel is taller than the available space, macOS shifts it upward and the top content disappears above the menu bar.
- **Right-click on `NSStatusBarButton`** — call `button.sendAction(on: [.leftMouseUp, .rightMouseUp])`, check `NSApp.currentEvent?.type` in the action, then temporarily assign `statusItem.menu` and call `button.performClick(nil)` to show it; clear `statusItem.menu` immediately after so left-click keeps its custom action.
- **`NSCalendarDayChanged`** — post by the system at midnight; subscribe in `TimerManager` to reset counters and restart the timer for the new day.
- **App icon** — generated by `scripts/generate_icon.swift` (CoreGraphics, no external tools). Re-run the script after design changes, then commit the updated PNG assets in `Assets.xcassets/AppIcon.appiconset/`.

## Install

Download the latest **TimeTracker.dmg** from the [Releases](../../releases) page. Each release includes full install and Gatekeeper bypass instructions.

## Contributing

Every new feature or bug fix must be developed on a dedicated branch and submitted as a pull request against `main`. Direct commits to `main` are not allowed.

### Branch naming

| Type | Pattern | Example |
|---|---|---|
| New feature | `feature/<short-description>` | `feature/pomodoro-mode` |
| Bug fix | `fix/<short-description>` | `fix/new-day-timer-reset` |

### Commit message conventions

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <short description>
```

| Type | When to use | Version bump |
|---|---|---|
| `fix:` | Bug fix | patch (`1.0.0` → `1.0.1`) |
| `feat:` | New feature | minor (`1.0.0` → `1.1.0`) |
| `feat!:` / `BREAKING CHANGE:` | Breaking change | major (`1.0.0` → `2.0.0`) |
| `chore:` | Maintenance, deps | patch |
| `docs:` | Documentation only | patch |
| `refactor:` | Code restructure, no behavior change | patch |

The CI release workflow reads all commits since the last tag and automatically picks the highest applicable version bump.

**Examples:**
```
fix: reset timer to 00:00:00 on new day
feat: add Pomodoro mode
feat!: replace session storage format
docs: update README contributing section
chore: update dependencies
```

### Workflow

1. Create a branch from `main`:
   ```bash
   git checkout main && git pull
   git checkout -b feature/your-feature   # or fix/your-bug
   ```
2. Commit using conventional commit messages.
3. Push and open a pull request against `main`.
4. Address review comments, then merge after approval.

## Data & Privacy

All data is stored locally at `~/Library/Application Support/TimeTracker/sessions.json`. Nothing is sent over the network.

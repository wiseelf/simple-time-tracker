# Simple Time Tracker

A lightweight native macOS menu bar app for tracking time. No Dock icon, no background monitoring — just a clean timer with manual entry, visual timeline, and daily/weekly/monthly statistics.

## Features

- **Menu bar timer** — lives entirely in the menu bar, no Dock icon
- **Start / Stop / Reset** — track time with a single click or `Space`
- **Manual entry (duration)** — add time retroactively by specifying hours + minutes
- **Manual entry (range)** — add time by picking a From / To time with a custom HH:MM picker and a 24-hour visual timeline
- **Auto-stop on sleep / screensaver** — timer stops automatically when the Mac sleeps or the screensaver activates; a system notification is sent
- **Persistent sessions** — time is saved automatically; today's total is restored on relaunch
- **Automatic day reset** — at midnight the timer resets to `00:00:00`; if it was running, the previous day's session is saved and the timer restarts fresh for the new day
- **Statistics** — bar chart of tracked time per day (week view) or per week (month view), with period total and daily average
- **Export / Import** — back up all sessions to a JSON file and restore (merge or replace) on any machine
- **System notifications** — notified when the timer starts, stops, or is auto-stopped
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

No additional dependencies — the project uses only Apple frameworks (AppKit, SwiftUI, Combine, Foundation, UserNotifications).

> **Note:** System notifications require a proper `.app` bundle with a bundle identifier. They are silently skipped when running via `swift run`.

## Project Structure

```
simple-time-tracker/
├── Package.swift
└── Sources/TimeTracker/
    ├── main.swift              # Entry point — NSApplication setup
    ├── AppDelegate.swift       # Status bar item + popup panel lifecycle + sleep/screensaver observers
    ├── ContentView.swift       # Main SwiftUI view (Timer tab + Stats tab)
    ├── StatsView.swift         # Bar-chart statistics view with export/import
    ├── DayTimelineView.swift   # 24-hour visual timeline for range entry
    ├── TimePickerField.swift   # Custom NSViewRepresentable HH:MM time input
    ├── TimerManager.swift      # Timer logic (ObservableObject singleton)
    ├── SessionStore.swift      # Persistence layer (ObservableObject singleton)
    └── TimeSession.swift       # Codable model for a single tracked session
```

## Architecture

### Entry point — `main.swift`

Creates `NSApplication`, sets the activation policy to `.accessory` (hides the Dock icon), attaches `AppDelegate`, and calls `app.run()`.

> **Note:** `@main` App struct is intentionally avoided — it conflicts with `main.swift`.

### `AppDelegate`

Owns the `NSStatusItem` and the floating `NSPanel` popup.

- **Status bar button** — a custom-drawn `NSImage` (non-template) rendered off-screen. Contains a pill border, an SF Symbol icon, and the current time text, all colored according to timer state.
- **Popup panel** — a `KeyablePanel: NSPanel` subclass (overrides `canBecomeKey` / `canBecomeMain` to `true`) with `.borderless` + `.nonactivatingPanel` style masks. The background is an `NSVisualEffectView` with `.popover` material and a 12 pt corner radius (frosted glass effect). `canBecomeKey = true` is required for SwiftUI `TextField` focus to work in a borderless panel.
- **Panel positioning** — placed flush below the menu bar button using `button.window?.convertToScreen(...)` + `setFrameTopLeftPoint`.
- **Panel dismissal** — a global `NSEvent` monitor handles outside clicks; `NSApplication.didResignActiveNotification` handles Cmd+Tab / app switches. Both are suppressed via `suppressAutoClose` while file-picker or alert modals are open.
- **Auto-stop** — observes `NSWorkspace.willSleepNotification` and `com.apple.screensaver.didstart` (via `DistributedNotificationCenter`), calling `TimerManager.stop(reason:)`.
- **Notifications** — sets itself as `UNUserNotificationCenterDelegate` and requests `.alert` + `.sound` authorization on launch (when a bundle identifier is present). The delegate allows banners to appear while the app is active.

### `TimerManager` (singleton)

`TimerManager.shared` — `ObservableObject`.

| Method | Description |
|---|---|
| `start()` | Starts a `Timer` firing every second, records `segmentStartDate`, sends a start notification |
| `stop(reason:)` | Invalidates timer, calculates delta since last save, writes a `TimeSession`, sends a stop notification |
| `reset()` | Stops and zeroes all counters |
| `addTime(hours:minutes:)` | Finds the latest free slot today and records a manual `TimeSession` (throws `ManualEntryError`) |
| `addTimeRange(start:end:)` | Records a manual `TimeSession` for an explicit time range; validates today-only, start < end, not in future, no overlap (throws `ManualEntryError`) |
| `loadTodayTime()` | Called once at launch to seed `elapsedSeconds` with today's saved total and register the midnight day-change observer |

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
| `hasOverlap(start:end:)` | Returns `true` if a time range overlaps any existing session today |
| `findFreeSlot(duration:before:)` | Finds the latest free gap today that fits the given duration |
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
  - *Range mode* — pick From / To using `TimePickerField` (custom HH:MM input); a `DayTimelineView` shows existing sessions and the selected range (blue = valid, red = conflict).
- **Stats tab** — delegates to `StatsView`.

### `StatsView`

- **Week view** — bar chart with one row per day (Mon–Sun). Today's bar is full accent color; other days are dimmed.
- **Month view** — bar chart with one row per calendar week within the month.
- Navigation: `‹ This Week ›` / `‹ This Month ›` — arrows step ±1 period; forward navigation disabled at current period.
- Footer shows **Total** and **Avg / day** (averaged over days/weeks with tracked time only).
- **Export** — opens `NSSavePanel`; saves all sessions as a JSON file.
- **Import** — opens `NSOpenPanel`; decodes the file, shows a confirmation alert with new/duplicate counts, and offers **Merge** (add new sessions only) or **Replace** (erase existing data).

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

## Install

Download the latest **TimeTracker.dmg** from the [Releases](../../releases) page, open it, and drag `TimeTracker.app` to your Applications folder.

### Gatekeeper — first launch

This build is ad-hoc signed (no Apple Developer certificate). macOS will block it on first launch. Use either option to allow it — you only need to do this once.

**Option A — System Settings** (macOS 14 Sonoma and later)
1. Try to open the app — it will be blocked.
2. Open **System Settings → Privacy & Security** and scroll down.
3. Click **"Open Anyway"** next to TimeTracker and confirm with your password.

**Option B — Terminal** (any macOS version)
```bash
xattr -dr com.apple.quarantine /Applications/TimeTracker.app
```
Then open the app normally.

> For a fully trusted build with no Gatekeeper prompt, the app must be signed with a Developer ID certificate and notarized with Apple ($99/year Apple Developer Program).

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

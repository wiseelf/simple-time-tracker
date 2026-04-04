# Patterns & Gotchas

> Full implementation notes are in [README.md](../../README.md#key-implementation-notes).

## Must-know constraints

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
- **`note` on `TimeSession`** — optional in JSON; trim and nil-coalesce before calling `SessionStore.update(_:startDate:duration:note:)`. Never pass an empty string.
- **osascript notifications** — use `tell application "System Events" to display notification …` (not bare `display notification`) so the "Show" button doesn't open Script Editor.

import AppKit
import SwiftUI
import Combine
import UserNotifications

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: KeyablePanel?
    private var panelAnchorTop: CGFloat = 0
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    var suppressAutoClose = false

    private var detailPanel: KeyablePanel?
    let detailState = SessionDetailState()
    private var aboutPanel: NSPanel?

    /// Temporarily lowers the panel below alerts/sheets, runs `block`, then restores the level.
    @discardableResult
    func withPanelLowered<T>(_ block: () -> T) -> T {
        let saved = panel?.level ?? .popUpMenu
        panel?.level = .normal
        let result = block()
        panel?.level = saved
        return result
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.bundleIdentifier != nil {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        let manager = TimerManager.shared
        manager.loadTodayTime()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification, object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(systemWillSleep),
            name: NSNotification.Name("com.apple.screensaver.didstart"), object: nil
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleButtonClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateButton()

        manager.$isRunning
            .combineLatest(manager.$elapsedSeconds)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &cancellables)
    }

    // MARK: - Status bar button

    private func updateButton() {
        guard let button = statusItem?.button else { return }
        let manager = TimerManager.shared

        let color: NSColor
        if manager.isRunning {
            color = .systemGreen
        } else if manager.elapsedSeconds > 0 {
            color = .systemOrange
        } else {
            color = .labelColor
        }

        let time = manager.elapsedSeconds > 0 ? manager.shortFormattedTime : "00:00"
        button.image = makeButtonImage(time: time, color: color)
        button.imagePosition = .imageOnly
        button.title = ""
    }

    private func makeButtonImage(time: String, color: NSColor) -> NSImage {
        let symConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)?
            .withSymbolConfiguration(symConfig) ?? NSImage()

        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        let attrText = NSAttributedString(string: time, attributes: [
            .font: font,
            .foregroundColor: color
        ])

        let symSize = symbol.size
        let txtSize = attrText.size()
        let padH: CGFloat = 6
        let padV: CGFloat = 2
        let gap: CGFloat = 4
        let pillWidth = symSize.width + gap + txtSize.width + padH * 2
        let pillHeight = max(symSize.height, txtSize.height) + padV * 2
        let height = max(pillHeight, 18)

        let image = NSImage(size: NSSize(width: pillWidth, height: height), flipped: false) { _ in
            let pillRect = NSRect(x: 0, y: (height - pillHeight) / 2, width: pillWidth, height: pillHeight)
            let radius = pillHeight / 2
            let pill = NSBezierPath(roundedRect: pillRect, xRadius: radius, yRadius: radius)
            color.withAlphaComponent(0.12).setFill()
            pill.fill()
            color.withAlphaComponent(0.55).setStroke()
            pill.lineWidth = 1
            pill.stroke()

            symbol.draw(in: NSRect(
                x: padH, y: (height - symSize.height) / 2,
                width: symSize.width, height: symSize.height
            ))
            attrText.draw(at: NSPoint(
                x: padH + symSize.width + gap,
                y: (height - txtSize.height) / 2
            ))
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Status bar click handling

    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            closePanel()
            showContextMenu(sender)
        } else {
            if let panel, panel.isVisible {
                closePanel()
            } else {
                openPanel()
            }
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "About TimeTracker", action: #selector(openAbout), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TimeTracker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // remove so left-click still uses our action
    }

    @objc private func openSettings() {
        AppUIState.shared.showSettings = true
        openPanel()
    }

    @objc private func openAbout() {
        if let existing = aboutPanel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let width: CGFloat = 320
        let hc = NSHostingController(rootView: AboutView())
        let size = hc.sizeThatFits(in: NSSize(width: width, height: 10_000))

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: size.height),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = "About TimeTracker"
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.contentView = hc.view
        p.center()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: p, queue: .main) { [weak self] _ in
            self?.aboutPanel = nil
        }
        aboutPanel = p
    }

    // MARK: - Panel

    private func openPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let panelWidth: CGFloat = 260

        let hc = NSHostingController(
            rootView: ContentView(onResize: { [weak self] height in
                self?.resizePanel(to: height)
            }).environmentObject(TimerManager.shared)
        )

        let screenMinY = NSScreen.main?.visibleFrame.minY ?? 0
        let buttonScreenY = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil)).minY
        let availableHeight = buttonScreenY - 6 - screenMinY - 10
        let idealSize = hc.sizeThatFits(in: NSSize(width: panelWidth, height: 10_000))
        let panelHeight = max(200, min(idealSize.height, availableHeight))

        let newPanel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.level = .popUpMenu
        newPanel.animationBehavior = .utilityWindow

        // Frosted-glass background with rounded corners
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true

        hc.view.frame = effect.bounds
        hc.view.autoresizingMask = [.width, .height]
        effect.addSubview(hc.view)
        newPanel.contentView = effect

        // Position: flush below the menu bar button, horizontally centered on it
        let btnInWindow = button.convert(button.bounds, to: nil)
        let btnOnScreen = buttonWindow.convertToScreen(btnInWindow)
        let anchorX = (btnOnScreen.midX - panelWidth / 2).rounded()
        let anchorTop = btnOnScreen.minY - 6
        panelAnchorTop = anchorTop
        newPanel.setFrameTopLeftPoint(NSPoint(x: anchorX, y: anchorTop))

        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = newPanel

        // Close on any click outside both panels
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, !self.suppressAutoClose else { return }
            let loc = event.locationInWindow
            let screenLoc = event.window?.convertToScreen(CGRect(origin: loc, size: .zero)).origin ?? loc
            let inMain   = self.panel?.frame.contains(screenLoc) ?? false
            let inDetail = self.detailPanel?.frame.contains(screenLoc) ?? false
            if !inMain && !inDetail { self.closePanel() }
        }

        // Close when switching apps via Cmd+Tab or Dock click
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appResignedActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    private func resizePanel(to height: CGFloat) {
        guard let panel else { return }
        let screenMinY = (panel.screen ?? NSScreen.main)?.visibleFrame.minY ?? 0
        let maxHeight = panelAnchorTop - screenMinY - 10
        let newHeight = max(200, min(height, maxHeight))
        let frame = panel.frame
        guard abs(frame.height - newHeight) > 2 else { return }
        panel.setFrame(
            NSRect(x: frame.minX, y: panelAnchorTop - newHeight, width: frame.width, height: newHeight),
            display: true, animate: false
        )
    }

    private func closePanel() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        NotificationCenter.default.removeObserver(self, name: NSApplication.didResignActiveNotification, object: nil)
        AppUIState.shared.showSettings = false
        panel?.orderOut(nil)
        panel = nil
        closeSessionsDetail()
    }

    @objc private func appResignedActive() {
        guard !suppressAutoClose else { return }
        closePanel()
    }

    // MARK: - Sessions detail panel

    func openSessionsDetail(for date: Date) {
        detailState.date = date

        // If already open, just update the date — no need to recreate the panel
        if detailPanel != nil { return }

        let panelWidth: CGFloat = 260
        let hc = NSHostingController(
            rootView: SessionDetailView()
                .environmentObject(TimerManager.shared)
                .environmentObject(detailState)
        )
        // Cap to the main panel's height so both panels look balanced side-by-side
        let idealSize = hc.sizeThatFits(in: NSSize(width: panelWidth, height: 10_000))
        let maxH = panel?.frame.height ?? 500
        let panelHeight = max(120, min(idealSize.height, maxH))

        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.animationBehavior = .utilityWindow

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true

        hc.view.frame = effect.bounds
        hc.view.autoresizingMask = [.width, .height]
        effect.addSubview(hc.view)
        p.contentView = effect

        // Align top edge with the main panel
        let anchorX = (panel?.frame.maxX ?? 0) + 8
        let anchorY = panelAnchorTop
        p.setFrameTopLeftPoint(NSPoint(x: anchorX, y: anchorY))

        // Don't steal key focus from the main panel
        p.orderFront(nil)
        detailPanel = p
    }

    func closeSessionsDetail() {
        detailPanel?.orderOut(nil)
        detailPanel = nil
    }

    var isShowingDetail: Bool { detailPanel != nil }

    @objc private func systemWillSleep(_ notification: Notification) {
        let reason = notification.name.rawValue.contains("screensaver")
            ? "Screensaver activated"
            : "Mac went to sleep"
        TimerManager.shared.stop(reason: reason)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async { self.openPanel() }
        completionHandler()
    }
}

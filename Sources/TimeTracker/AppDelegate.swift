import AppKit
import SwiftUI
import Combine

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = TimerManager.shared
        manager.loadTodayTime()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePanel(_:))
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

    // MARK: - Panel

    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        if let panel, panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let panelWidth: CGFloat = 260

        let hc = NSHostingController(
            rootView: ContentView(onResize: { [weak self] height in
                self?.resizePanel(to: height)
            }).environmentObject(TimerManager.shared)
        )

        let idealSize = hc.sizeThatFits(in: NSSize(width: panelWidth, height: 10_000))
        let panelHeight = max(200, idealSize.height)

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

        // Close on any click outside the panel
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
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
        let newHeight = max(200, height)
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
        panel?.orderOut(nil)
        panel = nil
    }

    @objc private func appResignedActive() {
        closePanel()
    }
}

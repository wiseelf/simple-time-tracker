import AppKit
import SwiftUI

// MARK: - SwiftUI wrapper

struct TimePickerField: NSViewRepresentable {
    @Binding var date: Date

    func makeNSView(context: Context) -> TimePickerNSView {
        let view = TimePickerNSView()
        view.onDateChange = { newDate in date = newDate }
        view.setDate(date)
        return view
    }

    func updateNSView(_ nsView: TimePickerNSView, context: Context) {
        nsView.setDate(date)
    }

    static func dismantleNSView(_ nsView: TimePickerNSView, coordinator: ()) {
        nsView.cleanup()
    }
}

// MARK: - Custom NSView

final class TimePickerNSView: NSView {
    var onDateChange: ((Date) -> Void)?

    private var hour: Int = 0
    private var minute: Int = 0
    private var dayComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    private var segment: Segment = .hour

    // "Active" means this picker is receiving input.
    // We use a local NSEvent monitor instead of fighting SwiftUI's first responder.
    private var isActive = false
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var pendingInput = ""

    private let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)

    // Layout
    private let segW: CGFloat     = 22
    private let colonW: CGFloat   = 10
    private let divX: CGFloat     = 66
    private let stepperW: CGFloat = 20

    private var totalW: CGFloat  { segW * 2 + colonW }
    private var hourX: CGFloat   { (divX - totalW) / 2 }
    private var colonX: CGFloat  { hourX + segW }
    private var minuteX: CGFloat { colonX + colonW }
    private var stepperMidX: CGFloat { divX + stepperW / 2 }

    enum Segment { case hour, minute }

    // MARK: - Init

    override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true }
    required init?(coder: NSCoder) { super.init(coder: coder); wantsLayer = true }

    override var intrinsicContentSize: NSSize { NSSize(width: divX + stepperW, height: 22) }

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowResignedKey),
                                                   name: NSWindow.didResignKeyNotification, object: window)
        }
    }

    override func removeFromSuperview() {
        cleanup()
        NotificationCenter.default.removeObserver(self)
        super.removeFromSuperview()
    }

    func cleanup() {
        setActive(false)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Active state & event monitors

    private func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            // Local key monitor — intercepts keyDown without stealing first responder
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isActive else { return event }
                return self.handleKey(event) ? nil : event
            }
            // Local mouse monitor — deactivate when user clicks outside this view
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self else { return event }
                let loc = self.convert(event.locationInWindow, from: nil)
                if !self.bounds.contains(loc) { self.setActive(false) }
                return event
            }
        } else {
            if let m = keyMonitor   { NSEvent.removeMonitor(m); keyMonitor   = nil }
            if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
            pendingInput = ""
        }
        needsDisplay = true
    }

    @objc private func windowResignedKey() { setActive(false) }

    // MARK: - Public

    func setDate(_ date: Date) {
        let cal = Calendar.current
        dayComponents = cal.dateComponents([.year, .month, .day], from: date)
        let c = cal.dateComponents([.hour, .minute], from: date)
        let h = c.hour ?? 0
        let m = c.minute ?? 0
        guard h != hour || m != minute else { return }
        hour = h; minute = m; needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let midY = bounds.midY
        let segH: CGFloat = 18
        let segY = midY - segH / 2

        // Background + border
        let bgPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        NSColor.controlBackgroundColor.setFill()
        bgPath.fill()
        (isActive ? NSColor.controlAccentColor.withAlphaComponent(0.9)
                  : NSColor.separatorColor.withAlphaComponent(0.5)).setStroke()
        bgPath.lineWidth = isActive ? 1.5 : 0.5
        bgPath.stroke()

        // Selected segment highlight when active
        if isActive {
            let hx = segment == .hour ? hourX : minuteX
            let hilite = NSBezierPath(roundedRect: NSRect(x: hx, y: segY, width: segW, height: segH),
                                      xRadius: 3, yRadius: 3)
            NSColor.selectedContentBackgroundColor.setFill()
            hilite.fill()
        }

        // Time text
        let hourSel = isActive && segment == .hour
        let minSel  = isActive && segment == .minute
        drawText(String(format: "%02d", hour),   at: hourX,   w: segW,   midY: midY,
                 color: hourSel ? .selectedMenuItemTextColor : .labelColor)
        drawText(":",                             at: colonX,  w: colonW, midY: midY,
                 color: .tertiaryLabelColor)
        drawText(String(format: "%02d", minute), at: minuteX, w: segW,   midY: midY,
                 color: minSel  ? .selectedMenuItemTextColor : .labelColor)

        // Divider
        NSColor.separatorColor.withAlphaComponent(0.5).setStroke()
        let div = NSBezierPath(); div.lineWidth = 0.5
        div.move(to: NSPoint(x: divX, y: 3)); div.line(to: NSPoint(x: divX, y: bounds.height - 3))
        div.stroke()

        // Stepper arrows ▲ ▼
        NSColor.secondaryLabelColor.setFill()
        let aw: CGFloat = 5, ah: CGFloat = 3.5
        let up = NSBezierPath()
        up.move(to: NSPoint(x: stepperMidX, y: midY + ah + 2))
        up.line(to: NSPoint(x: stepperMidX - aw, y: midY + 2))
        up.line(to: NSPoint(x: stepperMidX + aw, y: midY + 2))
        up.close(); up.fill()

        let dn = NSBezierPath()
        dn.move(to: NSPoint(x: stepperMidX, y: midY - ah - 2))
        dn.line(to: NSPoint(x: stepperMidX - aw, y: midY - 2))
        dn.line(to: NSPoint(x: stepperMidX + aw, y: midY - 2))
        dn.close(); dn.fill()
    }

    private func drawText(_ text: String, at x: CGFloat, w: CGFloat, midY: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let sz = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: x + (w - sz.width) / 2, y: midY - sz.height / 2),
                                withAttributes: attrs)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if p.x >= divX {
            setActive(true)
            adjust(by: p.y > bounds.midY ? 1 : -1)
        } else {
            segment = p.x < colonX ? .hour : .minute
            setActive(true)
            needsDisplay = true  // redraw even if setActive was a no-op (already active)
        }
    }

    // MARK: - Key handling (called from local monitor)

    @discardableResult
    private func handleKey(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        let chars = event.charactersIgnoringModifiers ?? ""
        switch event.keyCode {
        case 126: adjust(by:  1);    return true   // ↑
        case 125: adjust(by: -1);    return true   // ↓
        case 123: switchTo(.hour);   return true   // ←
        case 124: switchTo(.minute); return true   // →
        case 48:  advanceOrDeactivate(); return true // Tab
        case 53:  setActive(false);  return true   // Esc
        default:
            if let ch = chars.first, ch.isNumber { handleDigit(String(ch)); return true }
            if chars == ":" { switchTo(.minute); return true }
            return false
        }
    }

    private func adjust(by delta: Int) {
        if segment == .hour { hour   = (hour   + delta + 24) % 24 }
        else                { minute = (minute + delta + 60) % 60 }
        pendingInput = ""; needsDisplay = true; emit()
    }

    private func switchTo(_ target: Segment) {
        segment = target; pendingInput = ""; needsDisplay = true
    }

    private func advanceOrDeactivate() {
        if segment == .hour { switchTo(.minute) } else { setActive(false) }
    }

    private func handleDigit(_ digit: String) {
        guard let dv = Int(digit) else { return }
        let pending = pendingInput + digit
        if segment == .hour {
            if let val = Int(pending) {
                if pending.count == 2 || dv > 2 { hour = min(val, 23); pendingInput = ""; switchTo(.minute) }
                else                             { hour = val; pendingInput = pending }
            }
        } else {
            if let val = Int(pending) {
                if pending.count == 2 || dv > 5 { minute = min(val, 59); pendingInput = "" }
                else                             { minute = val; pendingInput = pending }
            }
        }
        needsDisplay = true; emit()
    }

    // MARK: - Helpers

    private func emit() {
        var c = dayComponents
        c.hour = hour; c.minute = minute; c.second = 0
        onDateChange?(Calendar.current.date(from: c) ?? Date())
    }
}

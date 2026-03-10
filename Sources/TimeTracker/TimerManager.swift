import Foundation
import Combine
import UserNotifications

enum ManualEntryError: LocalizedError {
    case noFreeSlot
    case overlap
    case invalidRange
    case futureTime
    case notToday

    var errorDescription: String? {
        switch self {
        case .noFreeSlot:    return "No free slot available today for this duration."
        case .overlap:       return "This range overlaps with an existing session."
        case .invalidRange:  return "Start time must be before end time."
        case .futureTime:    return "Cannot log time in the future."
        case .notToday:      return "Time range must be within today."
        }
    }
}

class TimerManager: ObservableObject {
    static let shared = TimerManager()

    @Published var isRunning = false
    @Published var elapsedSeconds: Int = 0

    private var timer: Timer?
    private var startDate: Date?
    private var segmentStartDate: Date?
    private var accumulatedSeconds: Int = 0
    private var savedSeconds: Int = 0

    var formattedTime: String {
        formatted(elapsedSeconds)
    }

    var shortFormattedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Stops the timer (discarding any in-progress segment) and resyncs all counters from the store.
    /// Call this after any external store mutation (import / replace).
    func reloadFromStore() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        startDate = nil
        segmentStartDate = nil
        let total = SessionStore.shared.totalSeconds(in: SessionStore.shared.sessions(on: .now))
        elapsedSeconds = total
        accumulatedSeconds = total
        savedSeconds = total
    }

    /// Called once on launch to seed the timer with today's already-tracked time.
    func loadTodayTime() {
        let total = SessionStore.shared.totalSeconds(in: SessionStore.shared.sessions(on: .now))
        guard total > 0 else { return }
        elapsedSeconds = total
        accumulatedSeconds = total
        savedSeconds = total
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        segmentStartDate = Date()
        startDate = Date()
        timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            self.elapsedSeconds = self.accumulatedSeconds + Int(Date().timeIntervalSince(start))
        }
        RunLoop.main.add(timer!, forMode: .common)
        notify(title: "Timer started", body: "Tracking time…")
    }

    func stop(reason: String? = nil) {
        guard isRunning else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil
        accumulatedSeconds = elapsedSeconds
        startDate = nil

        let delta = elapsedSeconds - savedSeconds
        if delta > 0, let seg = segmentStartDate {
            SessionStore.shared.record(TimeSession(startDate: seg, duration: delta))
        }
        savedSeconds = elapsedSeconds
        segmentStartDate = nil

        let sessionStr = formatDuration(max(0, delta))
        let todayStr   = formatDuration(elapsedSeconds)
        let prefix     = reason.map { "\($0) — " } ?? ""
        notify(title: "Timer stopped", body: "\(prefix)Session: \(sessionStr) · Today: \(todayStr)")
    }

    // MARK: - Notifications

    private func notify(title: String, body: String) {
        if Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        } else {
            // Fallback for swift run (no .app bundle)
            let safeTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
            let safeBody  = body.replacingOccurrences(of: "\"", with: "\\\"")
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments  = ["-e", "display notification \"\(safeBody)\" with title \"\(safeTitle)\""]
            try? task.run()
        }
    }

    func reset() {
        stop()
        elapsedSeconds = 0
        accumulatedSeconds = 0
        savedSeconds = 0
        segmentStartDate = nil
    }

    /// Finds the latest free slot today and places a session of the given duration there.
    func addTime(hours: Int, minutes: Int) throws {
        let seconds = hours * 3600 + minutes * 60
        guard seconds > 0 else { return }
        guard let slotStart = SessionStore.shared.findFreeSlot(duration: seconds, before: Date()) else {
            throw ManualEntryError.noFreeSlot
        }
        elapsedSeconds += seconds
        accumulatedSeconds += seconds
        savedSeconds += seconds
        SessionStore.shared.record(TimeSession(startDate: slotStart, duration: seconds, isManual: true))
    }

    /// Records an explicit time range; validates no overlap and that the range is today and not in the future.
    func addTimeRange(start: Date, end: Date) throws {
        let cal = Calendar.current
        guard cal.isDateInToday(start) && cal.isDateInToday(end) else { throw ManualEntryError.notToday }
        guard start < end else { throw ManualEntryError.invalidRange }
        guard end <= Date() else { throw ManualEntryError.futureTime }
        guard !SessionStore.shared.hasOverlap(start: start, end: end) else { throw ManualEntryError.overlap }

        let duration = Int(end.timeIntervalSince(start))
        elapsedSeconds += duration
        accumulatedSeconds += duration
        savedSeconds += duration
        SessionStore.shared.record(TimeSession(startDate: start, duration: duration, isManual: true))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private func formatted(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d:%02d", 0, m, s)
    }
}

import Foundation
import Combine

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
    }

    func stop() {
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

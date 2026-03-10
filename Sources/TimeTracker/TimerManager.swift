import Foundation
import Combine

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

    func addTime(hours: Int, minutes: Int) {
        let seconds = hours * 3600 + minutes * 60
        guard seconds > 0 else { return }
        elapsedSeconds += seconds
        accumulatedSeconds += seconds
        savedSeconds += seconds
        SessionStore.shared.record(TimeSession(startDate: Date(), duration: seconds, isManual: true))
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

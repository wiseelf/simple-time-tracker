import Foundation

class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published private(set) var sessions: [TimeSession] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TimeTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appendingPathComponent("sessions.json")
        load()
    }

    // MARK: - Write

    func record(_ session: TimeSession) {
        guard session.duration > 0 else { return }
        sessions.append(session)
        sessions.sort { $0.startDate < $1.startDate }
        persist()
    }

    func delete(_ session: TimeSession) {
        sessions.removeAll { $0.id == session.id }
        persist()
    }

    func update(_ session: TimeSession, startDate: Date, duration: Int) {
        guard let idx = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[idx] = TimeSession(id: session.id, startDate: startDate, duration: duration, isManual: session.isManual)
        sessions.sort { $0.startDate < $1.startDate }
        persist()
    }

    // MARK: - Queries

    func totalSeconds(in list: [TimeSession]) -> Int {
        list.reduce(0) { $0 + $1.duration }
    }

    func sessions(on date: Date) -> [TimeSession] {
        sessions.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    func sessions(weekOffset: Int) -> [TimeSession] {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
              let start = cal.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart),
              let end   = cal.date(byAdding: .weekOfYear, value: 1, to: start)
        else { return [] }
        return sessions.filter { $0.startDate >= start && $0.startDate < end }
    }

    func sessions(monthOffset: Int) -> [TimeSession] {
        let cal = Calendar.current
        guard let monthStart = cal.dateInterval(of: .month, for: .now)?.start,
              let start = cal.date(byAdding: .month, value: monthOffset, to: monthStart),
              let end   = cal.date(byAdding: .month, value: 1, to: start)
        else { return [] }
        return sessions.filter { $0.startDate >= start && $0.startDate < end }
    }

    // MARK: - Overlap & slot helpers

    /// Returns true if [start, end) overlaps any existing session on the same day.
    func hasOverlap(start: Date, end: Date) -> Bool {
        sessions(on: start).contains { session in
            let sessionEnd = session.startDate.addingTimeInterval(TimeInterval(session.duration))
            return start < sessionEnd && session.startDate < end
        }
    }

    /// Finds the latest free slot today (before `before`) that fits `duration` seconds.
    /// Returns the slot's start date, or nil if no gap is large enough.
    func findFreeSlot(duration: Int, before: Date) -> Date? {
        let needed = TimeInterval(duration)
        let dayStart = Calendar.current.startOfDay(for: before)
        let sorted = sessions(on: before).sorted { $0.startDate < $1.startDate }

        var cursor = dayStart
        var latestFit: Date?

        for session in sorted {
            let gapEnd = session.startDate
            if gapEnd.timeIntervalSince(cursor) >= needed {
                latestFit = gapEnd.addingTimeInterval(-needed)
            }
            let sessionEnd = session.startDate.addingTimeInterval(TimeInterval(session.duration))
            cursor = max(cursor, sessionEnd)
        }

        if before.timeIntervalSince(cursor) >= needed {
            latestFit = before.addingTimeInterval(-needed)
        }

        return latestFit
    }

    // MARK: - Backup

    func exportData() -> Data? {
        try? encoder.encode(sessions)
    }

    func importSessions(from data: Data) throws {
        let imported = try decoder.decode([TimeSession].self, from: data)
        let existingIDs = Set(sessions.map { $0.id })
        let incoming = imported.filter { !existingIDs.contains($0.id) }
        sessions.append(contentsOf: incoming)
        sessions.sort { $0.startDate < $1.startDate }
        persist()
    }

    func replaceAll(with imported: [TimeSession]) {
        sessions = imported.sorted { $0.startDate < $1.startDate }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? encoder.encode(sessions) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let loaded = try? decoder.decode([TimeSession].self, from: data) else { return }
        sessions = loaded
    }
}

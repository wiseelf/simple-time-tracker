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

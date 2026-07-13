import Foundation

/// File-backed persistence for `TimerCheckpoint`, sibling to `SessionStore`'s
/// `sessions.json` in the same Application Support directory.
enum TimerCheckpointStore {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let fileURL: URL = {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TimeTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("checkpoint.json")
    }()

    static func save(_ checkpoint: TimerCheckpoint) {
        guard let data = try? encoder.encode(checkpoint) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Reads and deletes the checkpoint file, if one exists. A leftover checkpoint
    /// means the previous run ended without calling `TimerManager.stop()`.
    static func loadAndClear() -> TimerCheckpoint? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        clear()
        return try? decoder.decode(TimerCheckpoint.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

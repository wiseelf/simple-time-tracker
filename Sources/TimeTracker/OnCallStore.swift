import Foundation
import Combine

class OnCallStore: ObservableObject {
    static let shared = OnCallStore()

    @Published var rotations:  [OnCallRotationBlock] = []
    @Published var settings:   OnCallSettings        = OnCallSettings()
    @Published var rules:      [RecurrenceRule]      = []
    @Published var exceptions: [ScheduleException]   = []

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
        fileURL = support.appendingPathComponent("oncall.json")
        load()
    }

    // MARK: - Rotation blocks

    func addRotation(_ block: OnCallRotationBlock) {
        rotations.append(block)
        rotations.sort { $0.startDate < $1.startDate }
        persist()
    }

    func updateRotation(_ block: OnCallRotationBlock) {
        guard let idx = rotations.firstIndex(where: { $0.id == block.id }) else { return }
        rotations[idx] = block
        rotations.sort { $0.startDate < $1.startDate }
        persist()
    }

    func deleteRotation(_ block: OnCallRotationBlock) {
        rotations.removeAll { $0.id == block.id }
        persist()
    }

    func updateSettings(_ newSettings: OnCallSettings) {
        settings = newSettings
        persist()
    }

    // MARK: - Recurrence rules

    func addRule(_ rule: RecurrenceRule) {
        rules.append(rule)
        rules.sort { $0.anchorDate < $1.anchorDate }
        persist()
    }

    func updateRule(_ rule: RecurrenceRule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx] = rule
        rules.sort { $0.anchorDate < $1.anchorDate }
        persist()
    }

    func deleteRule(_ rule: RecurrenceRule) {
        rules.removeAll { $0.id == rule.id }
        exceptions.removeAll()
        persist()
    }

    // MARK: - Schedule exceptions

    func upsertException(_ exc: ScheduleException) {
        let cal = Calendar.current
        let d = cal.startOfDay(for: exc.date)
        if let idx = exceptions.firstIndex(where: { cal.startOfDay(for: $0.date) == d }) {
            exceptions[idx] = exc
        } else {
            exceptions.append(exc)
        }
        persist()
    }

    func removeException(for date: Date) {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        exceptions.removeAll { cal.startOfDay(for: $0.date) == d }
        persist()
    }

    // MARK: - Persistence

    private struct Payload: Codable {
        var rotations:  [OnCallRotationBlock]
        var settings:   OnCallSettings
        var rules:      [RecurrenceRule]
        var exceptions: [ScheduleException]

        init(rotations: [OnCallRotationBlock], settings: OnCallSettings,
             rules: [RecurrenceRule], exceptions: [ScheduleException]) {
            self.rotations = rotations; self.settings = settings
            self.rules = rules; self.exceptions = exceptions
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            rotations  = try c.decode([OnCallRotationBlock].self, forKey: .rotations)
            settings   = try c.decode(OnCallSettings.self,        forKey: .settings)
            rules      = try c.decodeIfPresent([RecurrenceRule].self,     forKey: .rules)      ?? []
            exceptions = try c.decodeIfPresent([ScheduleException].self,  forKey: .exceptions) ?? []
        }
    }

    private func persist() {
        if let data = try? encoder.encode(
            Payload(rotations: rotations, settings: settings, rules: rules, exceptions: exceptions)
        ) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? decoder.decode(Payload.self, from: data) else { return }
        rotations  = payload.rotations
        settings   = payload.settings
        rules      = payload.rules
        exceptions = payload.exceptions
    }
}

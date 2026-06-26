import Foundation
import Combine

class OnCallStore: ObservableObject {
    static let shared = OnCallStore()

    @Published var rotations: [OnCallRotationBlock] = []
    @Published var settings: OnCallSettings = OnCallSettings()

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

    private struct Payload: Codable {
        var rotations: [OnCallRotationBlock]
        var settings: OnCallSettings
    }

    private func persist() {
        if let data = try? encoder.encode(Payload(rotations: rotations, settings: settings)) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? decoder.decode(Payload.self, from: data) else { return }
        rotations = payload.rotations
        settings  = payload.settings
    }
}

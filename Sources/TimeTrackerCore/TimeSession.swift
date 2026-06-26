import Foundation

public struct TimeSession: Codable, Identifiable {
    public let id: UUID
    public let startDate: Date
    public let duration: Int   // seconds
    public let isManual: Bool
    public var note: String?
    public var isOnCallActive: Bool

    public init(startDate: Date, duration: Int, isManual: Bool = false,
                note: String? = nil, isOnCallActive: Bool = false) {
        self.id = UUID()
        self.startDate = startDate
        self.duration = duration
        self.isManual = isManual
        self.note = note
        self.isOnCallActive = isOnCallActive
    }

    public init(id: UUID, startDate: Date, duration: Int, isManual: Bool,
                note: String? = nil, isOnCallActive: Bool = false) {
        self.id = id
        self.startDate = startDate
        self.duration = duration
        self.isManual = isManual
        self.note = note
        self.isOnCallActive = isOnCallActive
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self, forKey: .id)
        startDate      = try c.decode(Date.self, forKey: .startDate)
        duration       = try c.decode(Int.self, forKey: .duration)
        isManual       = try c.decode(Bool.self, forKey: .isManual)
        note           = try c.decodeIfPresent(String.self, forKey: .note)
        isOnCallActive = try c.decodeIfPresent(Bool.self, forKey: .isOnCallActive) ?? false
    }
}

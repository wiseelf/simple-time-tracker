import Foundation

struct TimeSession: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let duration: Int   // seconds
    let isManual: Bool
    var note: String?

    init(startDate: Date, duration: Int, isManual: Bool = false, note: String? = nil) {
        self.id = UUID()
        self.startDate = startDate
        self.duration = duration
        self.isManual = isManual
        self.note = note
    }

    init(id: UUID, startDate: Date, duration: Int, isManual: Bool, note: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.duration = duration
        self.isManual = isManual
        self.note = note
    }
}

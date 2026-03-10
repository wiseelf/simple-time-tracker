import Foundation

struct TimeSession: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let duration: Int   // seconds
    let isManual: Bool

    init(startDate: Date, duration: Int, isManual: Bool = false) {
        self.id = UUID()
        self.startDate = startDate
        self.duration = duration
        self.isManual = isManual
    }
}

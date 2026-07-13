import Foundation

/// Tracks the currently-running timer segment so it can be recovered if the
/// app terminates ungracefully (crash, force-kill) before `TimerManager.stop()`
/// runs. Written periodically while a segment is running, cleared by a clean
/// `stop()` — so its mere presence at next launch means the previous run
/// never reached `stop()`.
public struct TimerCheckpoint: Codable {
    public let segmentStartDate: Date
    public let duration: Int   // seconds elapsed in this segment as of the last checkpoint write
    public let isOnCallActive: Bool
    public var note: String?

    public init(segmentStartDate: Date, duration: Int, isOnCallActive: Bool = false, note: String? = nil) {
        self.segmentStartDate = segmentStartDate
        self.duration = duration
        self.isOnCallActive = isOnCallActive
        self.note = note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        segmentStartDate = try c.decode(Date.self, forKey: .segmentStartDate)
        duration          = try c.decode(Int.self, forKey: .duration)
        isOnCallActive    = try c.decodeIfPresent(Bool.self, forKey: .isOnCallActive) ?? false
        note              = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

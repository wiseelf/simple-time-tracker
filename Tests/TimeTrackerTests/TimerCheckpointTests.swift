import Testing
import Foundation
@testable import TimeTrackerCore

struct TimerCheckpointTests {

    @Test func roundTripsThroughCodable() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let checkpoint = TimerCheckpoint(segmentStartDate: start, duration: 42,
                                         isOnCallActive: true, note: "on call")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(checkpoint)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TimerCheckpoint.self, from: data)

        #expect(decoded.segmentStartDate == start)
        #expect(decoded.duration == 42)
        #expect(decoded.isOnCallActive == true)
        #expect(decoded.note == "on call")
    }

    @Test func decodingWithoutOptionalFieldsUsesDefaults() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let json = """
        {
            "segmentStartDate": "\(ISO8601DateFormatter().string(from: start))",
            "duration": 30
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TimerCheckpoint.self, from: json.data(using: .utf8)!)

        #expect(decoded.duration == 30)
        #expect(decoded.isOnCallActive == false)
        #expect(decoded.note == nil)
    }
}

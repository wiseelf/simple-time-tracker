import Foundation

public extension String {
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }
}

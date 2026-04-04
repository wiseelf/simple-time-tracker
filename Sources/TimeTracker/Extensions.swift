import Foundation

extension String {
    /// Returns the string trimmed of whitespace, or nil if empty after trimming.
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }
}

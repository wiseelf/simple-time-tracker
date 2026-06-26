import SwiftUI

extension View {
    /// Reliable day-toggle button style for both debug and release builds.
    /// Avoids .tint(.secondary) on .bordered which renders incorrectly in release.
    func dayToggleStyle(selected: Bool) -> some View {
        self
            .font(.system(size: 10))
            .buttonStyle(.plain)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(selected ? Color.accentColor : Color.secondary.opacity(0.15))
            )
            .foregroundStyle(selected ? Color.white : Color.primary)
    }
}

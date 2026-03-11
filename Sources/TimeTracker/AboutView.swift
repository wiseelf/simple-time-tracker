import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Icon + name
            VStack(spacing: 12) {
                if let image = NSImage(named: "AppIcon") {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                } else {
                    Image(systemName: "timer")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                }

                Text("TimeTracker")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 36)
            .padding(.bottom, 20)

            Divider()

            // Description
            VStack(spacing: 8) {
                Text("A lightweight native macOS menu bar app for tracking time. No Dock icon, no background monitoring — just a clean timer with manual entry, visual timeline, and statistics.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Divider()

            // Author
            VStack(spacing: 4) {
                Text("Made with ♥ by")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Serhii Kaidalov")
                    .font(.callout)
                    .fontWeight(.medium)

                Link("github.com/wiseelf", destination: URL(string: "https://github.com/wiseelf")!)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 16)
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}

import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

struct ContentView: View {
    @EnvironmentObject var manager: TimerManager

    var onResize: ((CGFloat) -> Void)?

    @State private var activeTab: Tab = .timer

    enum Tab { case timer, add, stats }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            tabPicker
            Divider()
            switch activeTab {
            case .timer:
                timerSection
            case .add:
                AddView()
            case .stats:
                StatsView()
            }
            Divider()
            footerSection
        }
        .frame(width: 260)
        .background(GeometryReader { geo in
            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
        })
        .onPreferenceChange(ContentHeightKey.self) { height in
            DispatchQueue.main.async { onResize?(height) }
        }
        .onChange(of: activeTab) { tab in
            if tab != .stats {
                (NSApp.delegate as? AppDelegate)?.closeSessionsDetail()
            }
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $activeTab) {
            Text("Timer").tag(Tab.timer)
            Text("Add").tag(Tab.add)
            Text("Stats").tag(Tab.stats)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)
            Text("Time Tracker")
                .font(.headline)
            Spacer()
            if activeTab == .timer && manager.elapsedSeconds > 0 && !manager.isRunning {
                Button("Reset") {
                    manager.reset()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.red.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var timerSection: some View {
        VStack(spacing: 14) {
            Text(manager.formattedTime)
                .font(.system(size: 34, weight: .thin, design: .monospaced))
                .foregroundStyle(manager.isRunning ? .primary : Color.gray)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: manager.elapsedSeconds)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            manager.isRunning ? Color.green : Color.gray.opacity(0.25),
                            lineWidth: 2
                        )
                        .shadow(
                            color: manager.isRunning ? Color.green.opacity(0.5) : .clear,
                            radius: 6
                        )
                        .animation(.easeInOut(duration: 0.3), value: manager.isRunning)
                )

            Button {
                if manager.isRunning { manager.stop() } else { manager.start() }
            } label: {
                Label(
                    manager.isRunning ? "Stop" : "Start",
                    systemImage: manager.isRunning ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
                .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(manager.isRunning ? .red : .green)
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])

            if manager.isRunning {
                NoteButton(note: $manager.pendingNote)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: manager.isRunning)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var footerSection: some View {
        HStack {
            Spacer()
            Button("Quit TimeTracker") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

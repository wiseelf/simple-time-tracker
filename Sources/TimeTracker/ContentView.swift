import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: TimerManager

    @State private var addHours: String = ""
    @State private var addMinutes: String = ""
    @State private var activeTab: Tab = .timer
    @FocusState private var focusedField: Field?

    enum Field { case hours, minutes }
    enum Tab { case timer, stats }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            tabPicker
            Divider()
            if activeTab == .timer {
                timerSection
                Divider()
                manualEntrySection
            } else {
                StatsView()
            }
            Divider()
            footerSection
        }
        .frame(width: 260)
    }

    private var tabPicker: some View {
        Picker("", selection: $activeTab) {
            Text("Timer").tag(Tab.timer)
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add time manually")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Group {
                    TextField("0", text: $addHours)
                        .focused($focusedField, equals: .hours)
                        .onChange(of: addHours) { v in addHours = sanitize(v, max: 99) }
                    Text("h")
                        .foregroundStyle(.secondary)
                    TextField("0", text: $addMinutes)
                        .focused($focusedField, equals: .minutes)
                        .onChange(of: addMinutes) { v in addMinutes = sanitize(v, max: 59) }
                    Text("m")
                        .foregroundStyle(.secondary)
                }
                .font(.system(.body, design: .monospaced))

                Spacer()

                Button("Add") {
                    commitManualEntry()
                }
                .buttonStyle(.bordered)
                .disabled(addHours.isEmpty && addMinutes.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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

    // MARK: - Helpers

    private func commitManualEntry() {
        let h = Int(addHours) ?? 0
        let m = Int(addMinutes) ?? 0
        manager.addTime(hours: h, minutes: m)
        addHours = ""
        addMinutes = ""
        focusedField = nil
    }

    private func sanitize(_ value: String, max maxVal: Int) -> String {
        let digits = value.filter(\.isNumber)
        if let n = Int(digits), n <= maxVal {
            return digits
        } else if digits.count > 2 {
            return String(digits.prefix(2))
        }
        return digits
    }
}

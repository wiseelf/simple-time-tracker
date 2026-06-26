import SwiftUI

struct OnCallView: View {
    @ObservedObject private var store        = OnCallStore.shared
    @ObservedObject private var sessionStore = SessionStore.shared

    enum OnCallTab { case week, month, schedule }
    @State private var tab:         OnCallTab = .week
    @State private var weekOffset:  Int       = 0
    @State private var monthOffset: Int       = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Week").tag(OnCallTab.week)
                Text("Month").tag(OnCallTab.month)
                Text("Schedule").tag(OnCallTab.schedule)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)

            Divider()

            switch tab {
            case .week:
                OnCallSummaryView(store: store, sessionStore: sessionStore,
                                  period: .week, offset: $weekOffset)
            case .month:
                OnCallSummaryView(store: store, sessionStore: sessionStore,
                                  period: .month, offset: $monthOffset)
            case .schedule:
                ScheduleTab(store: store)
            }
        }
    }
}

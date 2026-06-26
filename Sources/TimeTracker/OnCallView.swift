import SwiftUI

struct OnCallView: View {
    @ObservedObject private var store = OnCallStore.shared
    @ObservedObject private var sessionStore = SessionStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                OnCallSettingsSection(store: store)
                Divider()
                OnCallRotationListView(store: store)
                OnCallSummaryView(store: store, sessionStore: sessionStore)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

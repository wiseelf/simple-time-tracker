import SwiftUI

struct OnCallView: View {
    @ObservedObject private var store = OnCallStore.shared
    @ObservedObject private var sessionStore = SessionStore.shared

    var body: some View {
        VStack(spacing: 0) {
            OnCallRotationListView(store: store)
            OnCallSummaryView(store: store, sessionStore: sessionStore)
        }
    }
}

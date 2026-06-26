import SwiftUI

struct OnCallView: View {
    @ObservedObject private var store = OnCallStore.shared
    @ObservedObject private var sessionStore = SessionStore.shared

    var body: some View {
        OnCallSummaryView(store: store, sessionStore: sessionStore)
    }
}

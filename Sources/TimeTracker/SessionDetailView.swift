import SwiftUI

struct SessionDetailView: View {
    @EnvironmentObject var state: SessionDetailState

    private var title: String {
        let cal = Calendar.current
        if cal.isDateInToday(state.date)     { return "Today" }
        if cal.isDateInYesterday(state.date) { return "Yesterday" }
        return state.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    (NSApp.delegate as? AppDelegate)?.closeSessionsDetail()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                SessionsListView(date: state.date)
                    .padding(.vertical, 6)
            }
        }
        .frame(width: 260)
    }
}

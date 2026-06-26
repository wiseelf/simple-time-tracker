import Foundation

final class AppUIState: ObservableObject {
    static let shared = AppUIState()
    @Published var showSettings = false
}

import Foundation

@Observable
final class AppRouter {
    var selectedTab: Int = 0
    var pendingFragment: Fragment? = nil

    func open(_ fragment: Fragment) {
        selectedTab = 0
        // Brief delay lets the tab switch settle before pushing the destination
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            pendingFragment = fragment
        }
    }
}

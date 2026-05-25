import SwiftUI
import SwiftData

@main
struct SuipianApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Fragment.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

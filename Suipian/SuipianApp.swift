import SwiftUI
import SwiftData

@main
struct SuipianApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Fragment.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failed — log and attempt in-memory fallback so the app
            // stays usable rather than crashing. Data loss is preferable to a
            // crash only as an absolute last resort, so we never delete the store.
            print("[SuipianApp] ModelContainer error: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

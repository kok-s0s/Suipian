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
            // Schema incompatible with on-disk store — delete only the specific store files.
            let fm = FileManager.default
            let storeURL = config.url
            for url in [storeURL,
                        URL(fileURLWithPath: storeURL.path + "-wal"),
                        URL(fileURLWithPath: storeURL.path + "-shm")] {
                try? fm.removeItem(at: url)
            }
            return try! ModelContainer(for: schema, configurations: [config])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

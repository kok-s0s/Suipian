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
            // Schema changed (e.g. photosData → mediaIdentifiers) — delete old store
            let fm = FileManager.default
            if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let files = (try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil)) ?? []
                files.filter { $0.pathExtension == "store" || $0.pathExtension == "sqlite" }
                    .forEach { try? fm.removeItem(at: $0) }
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

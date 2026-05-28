import SwiftUI
import SwiftData

@main
struct SuipianApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Fragment.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try! ModelContainer(for: schema, configurations: [local])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color(red: 0.36, green: 0.44, blue: 0.64))
                .task { migrateAudioDataIfNeeded() }
        }
        .modelContainer(sharedModelContainer)
    }

    // One-time migration: populate audioData for fragments that have audio files but empty audioData.
    private func migrateAudioDataIfNeeded() {
        let ctx = sharedModelContainer.mainContext
        guard let fragments = try? ctx.fetch(FetchDescriptor<Fragment>()) else { return }
        var changed = false
        for fragment in fragments {
            guard !fragment.audioFileNames.isEmpty, fragment.audioData.isEmpty else { continue }
            fragment.audioData = fragment.audioFileNames.compactMap { AudioStore.data(for: $0) }
            changed = true
        }
        if changed { try? ctx.save() }
    }
}

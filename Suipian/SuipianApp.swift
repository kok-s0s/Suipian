import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct SuipianApp: App {
    @State private var syncMonitor = CloudKitSyncMonitor()
    @State private var appRouter = AppRouter()

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
                .task { await refreshNotificationIfNeeded() }
                .environment(syncMonitor)
                .environment(appRouter)
                .onContinueUserActivity(CSSearchableItemActionType) { [self] activity in
                    guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                    let ctx = sharedModelContainer.mainContext
                    guard let fragments = try? ctx.fetch(FetchDescriptor<Fragment>()) else { return }
                    guard let match = fragments.first(where: { SpotlightManager.itemID(for: $0) == id }) else { return }
                    appRouter.open(match)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // Refresh notification copy once per day when app launches — picks up new data-driven message.
    private func refreshNotificationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        let pending = await center.pendingNotificationRequests()
        guard let req = pending.first(where: { $0.identifier == "daily-reminder" }),
              let calTrigger = req.trigger as? UNCalendarNotificationTrigger,
              let comps = calTrigger.dateComponents.hour.map({ h -> (Int, Int) in
                  (h, calTrigger.dateComponents.minute ?? 0)
              }) else { return }
        let fragments = (try? sharedModelContainer.mainContext.fetch(FetchDescriptor<Fragment>())) ?? []
        NotificationScheduler.schedule(hour: comps.0, minute: comps.1, fragments: fragments)
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

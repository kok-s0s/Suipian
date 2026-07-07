import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct SuipianApp: App {
    @State private var syncMonitor = CloudKitSyncMonitor()
    @State private var appRouter = AppRouter()
    private let audioMigrationKey = "audioDataMigrationCompleted.v1"
    private let spotlightReindexKey = "spotlightReindexCompleted.v1"
    private let dailyNotificationRefreshKey = "dailyNotificationRefreshDate"
    private let importantDateRefreshKey = "importantDateRefreshDate"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Fragment.self, ImportantDate.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            UserDefaults.standard.set(false, forKey: "cloudKitFallbackToLocal")
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            UserDefaults.standard.set(true, forKey: "cloudKitFallbackToLocal")
            let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try! ModelContainer(for: schema, configurations: [local])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(AnimePalette.primary)
                .task { await runStartupMaintenance() }
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

    @MainActor
    private func runStartupMaintenance() async {
        try? await Task.sleep(nanoseconds: 750_000_000)
        guard !Task.isCancelled else { return }

        migrateAudioDataIfNeeded()
        reindexSpotlightItemsIfNeeded()
        await refreshNotificationIfNeeded()
        refreshImportantDateFeaturesIfNeeded()
    }

    // Refresh notification copy once per day when app launches — picks up new data-driven message.
    @MainActor
    private func refreshNotificationIfNeeded() async {
        guard shouldRunDailyTask(key: dailyNotificationRefreshKey) else { return }
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
        markDailyTaskRan(key: dailyNotificationRefreshKey)
    }

    // One-time migration: populate audioData for fragments that have audio files but empty audioData.
    @MainActor
    private func migrateAudioDataIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: audioMigrationKey) else { return }
        let ctx = sharedModelContainer.mainContext
        guard let fragments = try? ctx.fetch(FetchDescriptor<Fragment>()) else { return }
        var changed = false
        for fragment in fragments {
            guard !fragment.audioFileNames.isEmpty, fragment.audioData.isEmpty else { continue }
            fragment.audioData = fragment.audioFileNames.compactMap { AudioStore.data(for: $0) }
            changed = true
        }
        if changed { try? ctx.save() }
        UserDefaults.standard.set(true, forKey: audioMigrationKey)
    }

    @MainActor
    private func reindexSpotlightItemsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: spotlightReindexKey) else { return }
        let ctx = sharedModelContainer.mainContext
        guard let fragments = try? ctx.fetch(FetchDescriptor<Fragment>()) else { return }
        SpotlightManager.reindexAll(fragments)
        UserDefaults.standard.set(true, forKey: spotlightReindexKey)
    }

    @MainActor
    private func refreshImportantDateFeaturesIfNeeded() {
        guard shouldRunDailyTask(key: importantDateRefreshKey) else { return }
        let ctx = sharedModelContainer.mainContext
        let dates = (try? ctx.fetch(FetchDescriptor<ImportantDate>())) ?? []
        WidgetDataStore.updateImportantDates(dates)
        ImportantDateNotifier.rescheduleAll(dates)
        ImportantDateFragmentRecorder.recordTodayItems(dates, in: ctx)
        markDailyTaskRan(key: importantDateRefreshKey)
    }

    private func shouldRunDailyTask(key: String) -> Bool {
        UserDefaults.standard.string(forKey: key) != Self.todayKey
    }

    private func markDailyTaskRan(key: String) {
        UserDefaults.standard.set(Self.todayKey, forKey: key)
    }

    private static var todayKey: String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
}

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Open `Suipian.xcodeproj` in Xcode 15+, select a simulator or device running iOS 17+, and build/run normally. There are no scripts, Makefiles, or test targets. The widget extension (`SuipianWidget`) is a separate target in the same project.

## Architecture

### Entry point & persistence

`SuipianApp.swift` bootstraps the single `ModelContainer` with `cloudKitDatabase: .automatic` (CloudKit sync is already wired up via the entitlement `iCloud.com.kok-s0s.Suipian`). The fallback path silently drops CloudKit and uses local-only storage.

`Fragment` and `ImportantDate` are registered in the SwiftData schema — `Schema([Fragment.self, ImportantDate.self])`.

### Tab structure

`ContentView.swift` owns a 4-tab `TabView`:
- **碎片** → `FragmentFeedView` — main feed with list/grid toggle, FAB, search, tag filter, date sections, random review, On This Day banner, and the map entry
- **故事线** → `StoryListView` → `StoryDetailView` — stories are implicit groups of fragments sharing the same `storyName` string
- **日期** → `ImportantDatesTabView` — important-date countdowns, advance/day-of notifications, and automatic day-of fragment recording
- **统计** → `StatsView` — heatmap, mood curve, tag distribution, Wrapped full-screen cover

### Fragment model

`Fragment.swift` is the only persisted model. Notable fields:
- `mediaIdentifiers: [String]` — PHAsset local identifiers (photos live in the user's Photos library, not in the app)
- `audioFileNames: [String]` + `audioData: [Data]` — dual storage: file path for local playback, embedded `Data` for cross-device portability (needed because CloudKit syncs `Data` but not file paths)
- `storyName: String` — implicit story grouping key; no Story model exists
- `coverIdentifier: String?` — optional override for which photo shows as the card thumbnail

### Key design patterns

**Audio dual-storage**: Audio is recorded to `~/Documents/audio/<uuid>.m4a` via `AudioStore` (enum with static helpers). The raw `Data` is also saved into `fragment.audioData` so that when CloudKit syncs to another device, `AudioStore.restore(_:as:)` can recreate the local file. `SuipianApp` runs a one-time migration on launch to backfill `audioData` for older fragments that only have file names.

**Widget bridge**: `WidgetDataStore` writes to `UserDefaults(suiteName: "group.com.kok-s0s.Suipian")`. The widget target reads from the same suite. `WidgetFragmentData` and `WidgetImportantDateData` must stay in sync between the app and widget target files.

**App lock**: `ContentView` listens to `scenePhase`; on `.background` it sets `isLocked = true`. `LockScreenView` calls `LocalAuthentication` to unlock. Individual private fragments also show `LockScreenView` inline in `FragmentDetailView`.

### Theme & styling

`AnimeTheme.swift` defines the shared design language:
- `.animeCard()` / `.animeSecondaryCard()` — frosted glass card with border + shadow
- `.glassToolbarIcon()` — toolbar button style
- `.gradientTagStyle()` — tag chip pill
- `PressScaleButtonStyle` — spring scale on press (used on all cards)

**Brand colors**:
- Amber accent (heatmap, tags, charts): `Color(red: 0.780, green: 0.624, blue: 0.384)`
- Blue accent (interactive elements, FAB): `Color(red: 0.36, green: 0.44, blue: 0.64)` — set as `.tint` at app level

### Identifiers

| Thing | Value |
|---|---|
| Bundle ID | `com.kok-s0s.Suipian` |
| App Group | `group.com.kok-s0s.Suipian` |
| iCloud container | `iCloud.com.kok-s0s.Suipian` |
| Widget kind (tag feed) | `com.kok-s0s.Suipian.tagFeed` |
| Widget kind (important date countdown) | `com.kok-s0s.Suipian.importantDateCountdown` |
| Daily notification | `"daily-reminder"` |

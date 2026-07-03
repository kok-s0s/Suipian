import SwiftUI
import SwiftData
import PhotosUI
import Photos

struct FragmentFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSyncMonitor.self) private var syncMonitor
    @Environment(AppRouter.self) private var appRouter
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]
    @Query private var importantDates: [ImportantDate]

    @State private var deepLinkFragment: Fragment? = nil

    @AppStorage("fragmentViewIsGrid") private var isGridView = false
    @AppStorage("fragmentSortAscending") private var sortAscending = false
    @AppStorage("cloudKitFallbackToLocal") private var cloudKitFallbackToLocal = false

    @State private var selectedTag: String? = nil
    @State private var createRequest: CreateRequest? = nil
    @State private var showingTagPicker = false
    @State private var searchText = ""
    @State private var showingQuickPicker = false
    @State private var showingCamera = false
    @State private var pendingPickerIDs: [String] = []
    @State private var cameraID: String? = nil
    @State private var mediaEditRequest: MediaEditRequest? = nil
    @State private var showingSettings = false
    @State private var randomReviewRequest: RandomReviewRequest? = nil
    @State private var hasDraft = false
    @State private var fabExpanded = false
    @State private var showingVoiceInput = false
    @State private var pendingVoiceTranscript = ""
    @State private var fragmentToEdit: Fragment? = nil
    @State private var fragmentToDelete: Fragment? = nil
    @State private var showDeleteAlert = false
    @State private var showingMap = false
    @State private var showConfetti = false
    @State private var milestoneText: String? = nil

    private static let milestones: Set<Int> = [1, 10, 50, 100, 200, 365, 500, 1000]

    static let draftKey = "fragmentDraft_new"
    private func refreshDraftStatus() {
        hasDraft = UserDefaults.standard.data(forKey: Self.draftKey) != nil
    }

    // MARK: - Cached derived state (rebuilt only when inputs change, not on every render)

    @State private var cachedSortedTags: [(tag: String, count: Int)] = []
    @State private var cachedFilteredFragments: [Fragment] = []
    @State private var cachedListSections: [FeedSection] = []
    @State private var cachedOnThisDay: [Fragment] = []
    @State private var cachedReviewable: [Fragment] = []
    @State private var rebuildTask: Task<Void, Never>? = nil

    // Use cached values in the view
    var filteredFragments: [Fragment] { cachedFilteredFragments }
    var onThisDayFragments: [Fragment] { cachedOnThisDay }
    private var reviewableFragments: [Fragment] { cachedReviewable }

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy 年 M 月"; return f
    }()

    private func rebuildAll(fragments: [Fragment]) {
        // Tag frequency
        var freq: [String: Int] = [:]
        for f in fragments { for t in f.tags { freq[t, default: 0] += 1 } }
        cachedSortedTags = freq.sorted { $0.value > $1.value }.map { (tag: $0.key, count: $0.value) }

        // On this day
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let thisYear = cal.component(.year, from: Date())
        cachedOnThisDay = fragments.filter {
            let c = cal.dateComponents([.month, .day], from: $0.date)
            return c.month == today.month && c.day == today.day
                && cal.component(.year, from: $0.date) < thisYear
        }

        // Reviewable
        let todayStart = cal.startOfDay(for: Date())
        cachedReviewable = fragments.filter { $0.date < todayStart }

        // Filtered + sorted
        rebuildFiltered(fragments: fragments)
    }

    private func rebuildFiltered(fragments: [Fragment]) {
        var result = fragments
        if let tag = selectedTag { result = result.filter { $0.tags.contains(tag) } }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.content.lowercased().contains(q) ||
                $0.tags.contains { $0.lowercased().contains(q) } ||
                $0.locationName.lowercased().contains(q) ||
                $0.storyName.lowercased().contains(q) ||
                $0.mood.contains(q)
            }
        }
        result.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return sortAscending ? lhs.date < rhs.date : lhs.date > rhs.date
        }
        cachedFilteredFragments = result
        rebuildSections(filtered: result)
    }

    private func rebuildSections(filtered: [Fragment]) {
        guard !filtered.isEmpty else { cachedListSections = []; return }
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!
        let weekStart = cal.date(byAdding: .day, value: -7, to: todayStart)!
        let pinned = filtered.filter { $0.isPinned }
        let unpinned = filtered.filter { !$0.isPinned }
        var todayF: [Fragment] = [], yesterdayF: [Fragment] = [], weekF: [Fragment] = []
        var monthMap: [String: [Fragment]] = [:]
        var monthFirst: [String: Date] = [:]
        for f in unpinned {
            if f.date >= todayStart { todayF.append(f) }
            else if f.date >= yesterdayStart { yesterdayF.append(f) }
            else if f.date >= weekStart { weekF.append(f) }
            else {
                let key = Self.monthFmt.string(from: f.date)
                if monthFirst[key] == nil { monthFirst[key] = f.date }
                monthMap[key, default: []].append(f)
            }
        }
        let monthSections = monthMap.keys
            .sorted { (monthFirst[$0] ?? .distantPast) > (monthFirst[$1] ?? .distantPast) }
            .map { FeedSection(id: $0, fragments: monthMap[$0]!) }
        var dateSections: [FeedSection] = []
        if !todayF.isEmpty     { dateSections.append(FeedSection(id: "今天",    fragments: todayF)) }
        if !yesterdayF.isEmpty { dateSections.append(FeedSection(id: "昨天",    fragments: yesterdayF)) }
        if !weekF.isEmpty      { dateSections.append(FeedSection(id: "本周",    fragments: weekF)) }
        dateSections.append(contentsOf: monthSections)
        if sortAscending { dateSections = dateSections.reversed() }
        var result: [FeedSection] = []
        if !pinned.isEmpty { result.append(FeedSection(id: "置顶", fragments: pinned)) }
        result.append(contentsOf: dateSections)
        cachedListSections = result
    }

    private func pickRandomFragment() {
        let pool = reviewableFragments
        guard let fragment = pool.randomElement() else { return }
        randomReviewRequest = RandomReviewRequest(initialFragment: fragment, allFragments: pool)
    }

    // MARK: - Date sections

    private struct FeedSection: Identifiable {
        let id: String
        let fragments: [Fragment]
    }

    private var listSections: [FeedSection] { cachedListSections }

    private var todayFragments: [Fragment] {
        let start = Calendar.current.startOfDay(for: Date())
        return fragments.filter { $0.date >= start }
    }

    private var recentImportantDate: ImportantDate? {
        importantDates
            .filter { $0.daysUntil >= 0 && $0.daysUntil <= 7 }
            .min { $0.daysUntil < $1.daysUntil }
    }

    private var daysSinceLastFragment: Int? {
        guard let latest = fragments.map(\.date).max() else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day],
                                  from: cal.startOfDay(for: latest),
                                  to: cal.startOfDay(for: Date())).day
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    TodayEntryCard(
                        todayCount: todayFragments.count,
                        daysSinceLastFragment: daysSinceLastFragment,
                        onThisDayCount: onThisDayFragments.count,
                        upcomingDate: recentImportantDate
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Upcoming important date banner (today or within 7 days)
                    if let upcoming = recentImportantDate {
                        ImportantDateBanner(item: upcoming)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    // Draft banner
                    if hasDraft {
                        DraftBanner(
                            onResume: { createRequest = CreateRequest() },
                            onDiscard: {
                                UserDefaults.standard.removeObject(forKey: FragmentFeedView.draftKey)
                                refreshDraftStatus()
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    if cloudKitFallbackToLocal {
                        LocalOnlySyncBanner()
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    // On This Day banner
                    if !onThisDayFragments.isEmpty {
                        OnThisDayBanner(fragments: onThisDayFragments)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    FeedFilterSummaryLine(
                        totalCount: fragments.count,
                        filteredCount: filteredFragments.count,
                        searchText: searchText,
                        selectedTag: selectedTag,
                        sortAscending: sortAscending,
                        isGridView: isGridView
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    // Fragment cards
                    if isGridView {
                        LazyVStack(spacing: 0) {
                            ForEach(listSections) { section in
                                if !section.id.isEmpty {
                                    Text(section.id)
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 18)
                                        .padding(.bottom, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                let frags = section.fragments
                                let leftItems = frags.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
                                let rightItems = frags.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
                                HStack(alignment: .top, spacing: 12) {
                                    LazyVStack(spacing: 12) {
                                        ForEach(leftItems) { fragment in
                                            GridCell(fragment: fragment, highlight: searchText,
                                                     onEdit: { fragmentToEdit = fragment },
                                                     onDelete: { fragmentToDelete = fragment; showDeleteAlert = true })
                                        }
                                    }
                                    LazyVStack(spacing: 12) {
                                        ForEach(rightItems) { fragment in
                                            GridCell(fragment: fragment, highlight: searchText,
                                                     onEdit: { fragmentToEdit = fragment },
                                                     onDelete: { fragmentToDelete = fragment; showDeleteAlert = true })
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                        .transition(.opacity)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(listSections) { section in
                                if !section.id.isEmpty {
                                    Text(section.id)
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 18)
                                        .padding(.bottom, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                ForEach(section.fragments) { fragment in
                                    NavigationLink {
                                        FragmentDetailView(fragment: fragment)
                                    } label: {
                                        FragmentCardView(fragment: fragment, highlight: searchText)
                                    }
                                    .buttonStyle(PressScaleButtonStyle())
                                    .contextMenu {
                                        Button { fragmentToEdit = fragment } label: {
                                            Label("编辑", systemImage: "pencil")
                                        }
                                        Button {
                                            fragment.isPinned.toggle()
                                            HapticFeedback.impact(.light)
                                        } label: {
                                            Label(fragment.isPinned ? "取消置顶" : "置顶",
                                                  systemImage: fragment.isPinned ? "pin.slash" : "pin")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            fragmentToDelete = fragment
                                            showDeleteAlert = true
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    .scrollTransition(.animated(.spring(response: 0.5, dampingFraction: 0.88))) { content, phase in
                                        content
                                            .opacity(phase.isIdentity ? 1 : max(0, 1 - abs(phase.value) * 0.72))
                                            .scaleEffect(phase.isIdentity ? 1 : max(0.88, 1 - abs(phase.value) * 0.1))
                                            .rotation3DEffect(
                                                .degrees(phase.value * 12),
                                                axis: (x: 1, y: 0, z: 0),
                                                anchor: .center,
                                                perspective: 0.35
                                            )
                                    }
                                    .padding(.bottom, 14)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                        .transition(.opacity)
                    }
                } // VStack
            }
            .background { AppBackgroundCanvas().ignoresSafeArea() }
            .navigationTitle(selectedTag.map { "#\($0)" } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "搜索内容、标签、地点")
            .navigationDestination(item: $deepLinkFragment) { fragment in
                FragmentDetailView(fragment: fragment)
            }
            .onChange(of: appRouter.pendingFragment) { _, fragment in
                guard let fragment else { return }
                deepLinkFragment = fragment
                appRouter.pendingFragment = nil
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let tag = selectedTag {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.accentColor)
                            Text("#\(tag)")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        }
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "square.on.square.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.accentColor)
                            Text("碎片")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .glassToolbarIcon()
                    }
                    .buttonStyle(.plain)
                }
                if syncMonitor.state != .idle {
                    ToolbarItem(placement: .topBarLeading) {
                        SyncStatusIcon(state: syncMonitor.state)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            if cachedSortedTags.isEmpty == false {
                                Button { showingTagPicker = true } label: {
                                    Label("筛选标签", systemImage: "line.3.horizontal.decrease.circle")
                                }
                            }
                            Button {
                                sortAscending.toggle()
                            } label: {
                                Label(sortAscending ? "正序" : "倒序",
                                      systemImage: sortAscending ? "arrow.up" : "arrow.down")
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) { isGridView.toggle() }
                            } label: {
                                Label(isGridView ? "切换到列表" : "切换到方格",
                                      systemImage: isGridView ? "rectangle.grid.1x2" : "square.grid.2x2")
                            }
                            Divider()
                            Button {
                                pickRandomFragment()
                            } label: {
                                Label("随机回顾", systemImage: "dice")
                            }
                            Divider()
                            Button {
                                searchText = ""
                                selectedTag = nil
                                sortAscending = false
                                isGridView = false
                            } label: {
                                Label("清除筛选", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .glassToolbarIcon(active: selectedTag != nil || !searchText.isEmpty || sortAscending || isGridView)
                        }
                        .buttonStyle(.plain)

                        Button { showingMap = true } label: {
                            Image(systemName: "map")
                                .glassToolbarIcon()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .overlay {
                if filteredFragments.isEmpty {
                    ContentUnavailableView(
                        selectedTag != nil ? "「\(selectedTag!)」下还没有碎片" : "此刻是空的",
                        systemImage: "square.on.square.dashed",
                        description: Text(selectedTag != nil
                            ? "换一个主题，或者去记录一条新的"
                            : "每一个普通的瞬间，都值得被留下来")
                    )
                }
            }
        .onAppear {
            rebuildAll(fragments: fragments)
            refreshDraftStatus()
            WidgetDataStore.rebuildFragmentWidgets(fragments)
        }
        .onChange(of: fragments) { oldFragments, newFragments in
            // Milestone: immediate, no debounce needed
            if newFragments.count > oldFragments.count,
               Self.milestones.contains(newFragments.count) {
                let n = newFragments.count
                milestoneText = n == 1 ? "第一条碎片 🎉" : "第 \(n) 条碎片 🎊"
                showConfetti = true
                HapticFeedback.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    withAnimation(.easeOut(duration: 0.4)) { milestoneText = nil }
                }
            }
            // Heavy rebuild: debounce 150ms to absorb rapid CloudKit sync bursts
            rebuildTask?.cancel()
            rebuildTask = Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                rebuildAll(fragments: newFragments)
                WidgetDataStore.rebuildFragmentWidgets(newFragments)
            }
        }
        .onChange(of: searchText) { _, _ in rebuildFiltered(fragments: fragments) }
        .onChange(of: selectedTag) { _, _ in rebuildFiltered(fragments: fragments) }
        .onChange(of: sortAscending) { _, _ in rebuildFiltered(fragments: fragments) }
        .overlay {
                if fabExpanded {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { fabExpanded = false } }
                        .transition(.opacity)
                }
            }
        .overlay {
                ConfettiView(isVisible: $showConfetti)
                    .allowsHitTesting(false)
            }
        .overlay(alignment: .top) {
                if let text = milestoneText {
                    Text(text)
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.black.opacity(0.72), in: Capsule())
                        .shadow(radius: 8)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: milestoneText)
                }
            }
        .overlay(alignment: .bottomTrailing) {
                SpeedDialFAB(
                    isExpanded: $fabExpanded,
                    hasDraft: hasDraft,
                    onText:   { fabExpanded = false; createRequest = CreateRequest() },
                    onPhoto:  { fabExpanded = false; showingQuickPicker = true },
                    onCamera: { fabExpanded = false; showingCamera = true },
                    onVoice:  { fabExpanded = false; showingVoiceInput = true }
                )
                .padding(.trailing, 20).padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showingMap) {
            FragmentMapView()
        }
        .sheet(item: $randomReviewRequest) { request in
            RandomReviewSheet(initialFragment: request.initialFragment,
                              allFragments: request.allFragments)
        }
        .sheet(isPresented: $showingTagPicker) {
            TagPickerSheet(cachedSortedTags: cachedSortedTags, totalCount: fragments.count, selectedTag: $selectedTag)
        }
        .sheet(isPresented: $showingQuickPicker, onDismiss: {
            if !pendingPickerIDs.isEmpty {
                mediaEditRequest = MediaEditRequest(mediaIDs: pendingPickerIDs)
                pendingPickerIDs = []
            }
        }) {
            PhotoLibraryPicker(selectedIDs: $pendingPickerIDs)
        }
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            if let id = cameraID {
                mediaEditRequest = MediaEditRequest(mediaIDs: [id])
                cameraID = nil
            }
        }) {
            CameraPickerView(capturedID: $cameraID)
                .ignoresSafeArea()
        }
        .sheet(item: $mediaEditRequest, onDismiss: { refreshDraftStatus() }) { request in
            FragmentEditView(preloadedMediaIDs: request.mediaIDs, saveDraftOnCancel: false)
        }
        .sheet(isPresented: $showingVoiceInput, onDismiss: {
            if !pendingVoiceTranscript.isEmpty {
                createRequest = CreateRequest(preloadedContent: pendingVoiceTranscript)
                pendingVoiceTranscript = ""
            }
        }) {
            VoiceInputView { transcript in
                pendingVoiceTranscript = transcript
            }
            .presentationDetents([.fraction(0.65)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $createRequest, onDismiss: { refreshDraftStatus() }) { req in
            FragmentEditView(preloadedContent: req.preloadedContent)
        }
        .sheet(item: $fragmentToEdit, onDismiss: { fragmentToEdit = nil }) { f in
            FragmentEditView(fragment: f)
        }
        .alert("删除碎片", isPresented: $showDeleteAlert) {
            Button("永久删除", role: .destructive) {
                if let f = fragmentToDelete {
                    f.audioFileNames.forEach { AudioStore.delete($0) }
                    f.mediaIdentifiers.forEach { LocalMediaStore.delete(identifier: $0) }
                    SpotlightManager.remove(itemID: SpotlightManager.itemID(for: f))
                    modelContext.delete(f)
                    try? modelContext.save()
                    WidgetDataStore.rebuildFragmentWidgets(fragments.filter { $0.persistentModelID != f.persistentModelID })
                    HapticFeedback.impact(.medium)
                }
                fragmentToDelete = nil
            }
            Button("取消", role: .cancel) { fragmentToDelete = nil }
        } message: {
            Text("此操作无法撤销")
        }
    }
}

// MARK: - Sheet request types

private struct CreateRequest: Identifiable {
    let id = UUID()
    var preloadedContent: String = ""
}

private struct RandomReviewRequest: Identifiable {
    let id = UUID()
    let initialFragment: Fragment
    let allFragments: [Fragment]
}

private struct MediaEditRequest: Identifiable {
    let id = UUID()
    let mediaIDs: [String]
}

private struct LocalOnlySyncBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive.badge.icloud")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("当前仅本机保存")
                    .font(.caption).fontWeight(.semibold)
                Text("iCloud 同步未能启动，可在设置中查看状态。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(Color.orange.opacity(0.28), lineWidth: 0.8))
    }
}

// MARK: - Today entry

private struct TodayEntryCard: View {
    let todayCount: Int
    let daysSinceLastFragment: Int?
    let onThisDayCount: Int
    let upcomingDate: ImportantDate?

    private var statusText: String {
        guard let daysSinceLastFragment else { return "今天从第一条碎片开始" }
        if daysSinceLastFragment == 0 { return "今天已经留下 \(todayCount) 条碎片" }
        if daysSinceLastFragment == 1 { return "昨天记录过，今天继续" }
        return "距离上次记录 \(daysSinceLastFragment) 天"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("今天")
                        .font(.title2).fontWeight(.bold)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(Date(), format: .dateTime.month(.defaultDigits).day())
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
            }

            Text("今日 \(todayCount) · 历史 \(onThisDayCount) · 日期 \(upcomingDate.map { $0.isToday ? "今天" : "\($0.daysUntil) 天后" } ?? "暂无")")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let upcomingDate {
                HStack(spacing: 8) {
                    Text(upcomingDate.emoji)
                    Text(upcomingDate.isToday ? "今天是 \(upcomingDate.title)" : "\(upcomingDate.title) · \(upcomingDate.countdownLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            }

        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}

private struct FeedFilterSummaryLine: View {
    let totalCount: Int
    let filteredCount: Int
    let searchText: String
    let selectedTag: String?
    let sortAscending: Bool
    let isGridView: Bool

    private var activeText: String {
        var parts: [String] = []
        if let selectedTag { parts.append("#\(selectedTag)") }
        if !searchText.isEmpty { parts.append("搜索") }
        if sortAscending { parts.append("正序") }
        if isGridView { parts.append("方格") }
        return parts.isEmpty ? "全部" : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("碎片 \(filteredCount)/\(totalCount)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(activeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Speed-dial FAB

private struct SpeedDialFAB: View {
    @Binding var isExpanded: Bool
    let hasDraft: Bool
    let onText: () -> Void
    let onPhoto: () -> Void
    let onCamera: () -> Void
    let onVoice: () -> Void

    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 14) {
                if cameraAvailable {
                fabAction(icon: "camera.fill",             label: "拍照",  color: AnimePalette.sakura, action: onCamera)
                    .offset(y: isExpanded ? 0 : 40).opacity(isExpanded ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.72).delay(0.0), value: isExpanded)
                }

                fabAction(icon: "photo.on.rectangle.fill", label: "相册",  color: AnimePalette.mint, action: onPhoto)
                    .offset(y: isExpanded ? 0 : 40).opacity(isExpanded ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.72).delay(0.06), value: isExpanded)

                fabAction(icon: "text.alignleft",          label: "文字",  color: AnimePalette.primary, action: onText)
                    .offset(y: isExpanded ? 0 : 40).opacity(isExpanded ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.72).delay(0.12), value: isExpanded)

                fabAction(icon: "waveform",                label: "语音",  color: AnimePalette.violet, action: onVoice)
                    .offset(y: isExpanded ? 0 : 40).opacity(isExpanded ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.72).delay(0.18), value: isExpanded)

                // Main FAB
                mainFAB
            }
        }
    }

    private var mainFAB: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                // Glow ring (only when collapsed)
                if !isExpanded {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 72, height: 72)
                        .blur(radius: 8)
                }

                // Glass disc
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)

                // Icon
                Image(systemName: "plus")
                    .font(.title2).fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .rotationEffect(.degrees(isExpanded ? 45 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isExpanded)
            }
            .overlay(alignment: .topTrailing) {
                if hasDraft && !isExpanded {
                    Circle()
                        .fill(.orange)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .offset(x: 2, y: -2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.55)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    withAnimation(.spring(response: 0.3)) { isExpanded = false }
                    onVoice()
                }
        )
    }

    @ViewBuilder
    private func fabAction(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                Circle()
                    .fill(color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: color.opacity(0.35), radius: 6, y: 3)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - On This Day banner

private struct OnThisDayBanner: View {
    let fragments: [Fragment]
    @State private var showingDetail = false

    private var years: [Int] {
        let cal = Calendar.current
        return Array(Set(fragments.map { cal.component(.year, from: $0.date) })).sorted(by: >)
    }

    var body: some View {
        Button { showingDetail = true } label: {
            HStack(spacing: 12) {
                // Thumbnails stack
                ZStack {
                    ForEach(Array(fragments.prefix(3).enumerated()), id: \.offset) { i, fragment in
                        if let id = fragment.coverMediaID {
                            MediaThumbnailView(identifier: id, size: CGSize(width: 120, height: 120))
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .offset(x: CGFloat(i) * 6, y: CGFloat(i) * -3)
                                .zIndex(Double(3 - i))
                        }
                    }
                }
                .frame(width: 60, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text("今天历史上")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(yearsLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(PressScaleButtonStyle())
        .navigationDestination(isPresented: $showingDetail) {
            OnThisDayView(fragments: fragments)
        }
    }

    private var yearsLabel: String {
        years.map { "\($0) 年" }.joined(separator: "、") + "的碎片"
    }
}

// MARK: - Grid cell

private struct FragmentGridCellView: View {
    let fragment: Fragment
    var highlight: String = ""
    @State private var imageRatio: CGFloat

    // Process-lifetime cache: avoids layout jump on re-appearance
    private static var ratioCache: [String: CGFloat] = [:]

    // (screen - 16*2 padding - 12 gap) / 2 columns
    private static var columnWidth: CGFloat {
        let width = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }
            .first ?? 390
        return (width - 44) / 2
    }

    init(fragment: Fragment, highlight: String = "") {
        self.fragment = fragment
        self.highlight = highlight
        let cached = fragment.coverMediaID.flatMap { FragmentGridCellView.ratioCache[$0] }
        _imageRatio = State(initialValue: cached ?? 1.0)
    }

    var body: some View {
        if fragment.isPrivate {
            privateCell
        } else {
            normalCell
        }
    }

    private var privateCell: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text("私密碎片")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.vertical, 16)
        .animeCard(cornerRadius: 12)
    }

    @ViewBuilder
    private var normalCell: some View {
        if fragment.coverMediaID == nil {
            textOnlyCell
        } else {
            mediaCell
        }
    }

    private var mediaCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverID = fragment.coverMediaID {
                // Frame height = column width × actual h/w ratio so the image
                // fills the frame exactly with no cropping (fitContent mode).
                // Clamp: 0.4 (very wide landscape) – 2.0 (tall portrait/screenshot)
                let imgHeight = Self.columnWidth * min(max(imageRatio, 0.4), 2.0)
                MediaThumbnailView(
                    identifier: coverID,
                    size: CGSize(width: 480, height: 960),
                    fitContent: true
                )
                .frame(width: Self.columnWidth, height: imgHeight)
                .task(id: coverID) {
                    guard Self.ratioCache[coverID] == nil else { return }
                    if let image = LocalMediaStore.thumbnail(for: coverID, targetSize: CGSize(width: 480, height: 960)),
                       image.size.width > 0 {
                        let r = image.size.height / image.size.width
                        Self.ratioCache[coverID] = r
                        imageRatio = r
                        return
                    }
                    let assets = PHAsset.fetchAssets(
                        withLocalIdentifiers: [coverID], options: nil)
                    if let asset = assets.firstObject, asset.pixelWidth > 0 {
                        let r = CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
                        Self.ratioCache[coverID] = r
                        imageRatio = r
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                if !fragment.content.isEmpty {
                    Group {
                        if highlight.isEmpty {
                            Text(fragment.content)
                        } else {
                            Text(highlighted(fragment.content, query: highlight))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                }

                if !fragment.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(fragment.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .gradientTagStyle(fontSize: 9, paddingH: 5, paddingV: 2)
                                .lineLimit(1)
                        }
                        if fragment.tags.count > 2 {
                            Text("+\(fragment.tags.count - 2)")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                HStack(spacing: 4) {
                    if !fragment.mood.isEmpty {
                        Text(fragment.mood).font(.system(size: 10))
                    }
                    if fragment.hasLocation && !fragment.locationName.isEmpty {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(fragment.locationName)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(fragment.date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .animeCard(cornerRadius: 12)
        .overlay(alignment: .topLeading) {
            if fragment.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 4)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                    .padding(6)
            }
        }
    }

    private var textOnlyCell: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                if !fragment.mood.isEmpty {
                    Text(fragment.mood)
                        .font(.title3)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.10), in: Circle())
                } else {
                    Image(systemName: "text.quote")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.10), in: Circle())
                }
                Spacer()
                if fragment.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            if !fragment.content.isEmpty {
                Group {
                    if highlight.isEmpty {
                        Text(fragment.content)
                    } else {
                        Text(highlighted(fragment.content, query: highlight))
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(7)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !fragment.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(fragment.tags.prefix(2), id: \.self) { tag in
                        Text("#\(tag)")
                            .gradientTagStyle(fontSize: 9, paddingH: 5, paddingV: 2)
                            .lineLimit(1)
                    }
                    if fragment.tags.count > 2 {
                        Text("+\(fragment.tags.count - 2)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            HStack(spacing: 4) {
                if fragment.hasLocation && !fragment.locationName.isEmpty {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                    Text(fragment.locationName)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(fragment.date.formatted(.relative(presentation: .named)))
                    .lineLimit(1)
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.035),
                    Color.accentColor.opacity(0.055)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.035), radius: 5, y: 2)
    }
}

// MARK: - Tag picker bottom sheet

private struct TagPickerSheet: View {
    let cachedSortedTags: [(tag: String, count: Int)]
    let totalCount: Int
    @Binding var selectedTag: String?
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    // "全部" cell
                    tagCell(label: "全部", count: totalCount, isSelected: selectedTag == nil) {
                        selectedTag = nil
                        dismiss()
                    }
                    ForEach(cachedSortedTags, id: \.tag) { item in
                        tagCell(label: "#\(item.tag)", count: item.count, isSelected: selectedTag == item.tag) {
                            selectedTag = item.tag
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("选择标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
                if selectedTag != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("清除筛选") { selectedTag = nil; dismiss() }
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func tagCell(label: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(label)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let count {
                    Text("\(count) 条")
                        .font(.caption2)
                        .opacity(0.75)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.08))
            .foregroundStyle(isSelected ? .white : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Photo library picker (PHPickerViewController wrapper)

private struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedIDs: [String]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 20
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uvc: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let ids = results.compactMap { $0.assetIdentifier }
            DispatchQueue.main.async {
                self.parent.selectedIDs = ids
                self.parent.dismiss()
            }
        }
    }
}

// MARK: - Camera picker (UIImagePickerController, camera source only)

private struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var capturedID: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uvc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else { parent.dismiss(); return }
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetChangeRequest.creationRequestForAsset(from: image)
                placeholder = req.placeholderForCreatedAsset
            }) { _, _ in
                DispatchQueue.main.async {
                    self.parent.capturedID = placeholder?.localIdentifier
                    self.parent.dismiss()
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Draft banner

private struct DraftBanner: View {
    let onResume: () -> Void
    let onDiscard: () -> Void

    private struct DraftPreview: Codable {
        var content: String
        var tags: [String]
        var mood: String
        var mediaIdentifiers: [String]
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            content = try c.decode(String.self, forKey: .content)
            tags = try c.decode([String].self, forKey: .tags)
            mood = try c.decode(String.self, forKey: .mood)
            mediaIdentifiers = (try? c.decode([String].self, forKey: .mediaIdentifiers)) ?? []
        }
    }

    private var draft: DraftPreview? {
        guard let data = UserDefaults.standard.data(forKey: FragmentFeedView.draftKey),
              let d = try? JSONDecoder().decode(DraftPreview.self, from: data) else { return nil }
        return d
    }

    var body: some View {
        if let d = draft {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.orange)
                        Text("草稿")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(Color.orange)
                    }

                    let preview = buildPreview(d)
                    if !preview.isEmpty {
                        Text(preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button(action: onResume) {
                        Text("继续编辑")
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.accentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onDiscard) {
                        Image(systemName: "xmark")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.8)
            )
        }
    }

    private func buildPreview(_ d: DraftPreview) -> String {
        var parts: [String] = []
        if !d.mood.isEmpty { parts.append(d.mood) }
        let text = d.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { parts.append(text) }
        if !d.tags.isEmpty { parts.append(d.tags.map { "#\($0)" }.joined(separator: " ")) }
        if !d.mediaIdentifiers.isEmpty { parts.append("\(d.mediaIdentifiers.count) 张照片") }
        return parts.joined(separator: "  ")
    }
}

// MARK: - Random review sheet

private struct RandomReviewSheet: View {
    let allFragments: [Fragment]

    @State private var fragment: Fragment
    // Sliding window of recently seen IDs — fragments in this set are excluded from the next pick.
    // Window size = min(count - 1, 8), so at most 8 items are blocked at a time.
    @State private var seenIDs: [PersistentIdentifier]
    @Environment(\.dismiss) private var dismiss

    init(initialFragment: Fragment, allFragments: [Fragment]) {
        self.allFragments = allFragments
        _fragment = State(initialValue: initialFragment)
        _seenIDs = State(initialValue: [initialFragment.persistentModelID])
    }

    private var windowSize: Int { min(allFragments.count - 1, 8) }

    private func pickNext() -> Fragment? {
        let excluded = Set(seenIDs)
        var pool = allFragments.filter { !excluded.contains($0.persistentModelID) }
        if pool.isEmpty {
            // Full cycle complete — reset history and allow everything except current
            seenIDs = [fragment.persistentModelID]
            pool = allFragments.filter { $0.persistentModelID != fragment.persistentModelID }
        }
        guard let next = pool.randomElement() else { return nil }
        seenIDs.append(next.persistentModelID)
        while seenIDs.count > windowSize { seenIDs.removeFirst() }
        return next
    }

    var body: some View {
        NavigationStack {
            FragmentDetailView(fragment: fragment)
                .id(fragment.persistentModelID)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("关闭") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            guard let next = pickNext() else { return }
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                fragment = next
                            }
                            HapticFeedback.impact(.light)
                        } label: {
                            Image(systemName: "shuffle")
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Upcoming important date banner

private struct ImportantDateBanner: View {
    let item: ImportantDate
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]
    @State private var showingDates = false
    @State private var showingMoment = false

    var body: some View {
        Button {
            if item.isToday {
                showingMoment = true
            } else {
                showingDates = true
            }
        } label: {
            HStack(spacing: 12) {
                Text(item.emoji)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.isToday ? "今天是 \(item.title) 🎉" : item.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(item.isToday ? "去记录一条碎片纪念这一天" : item.countdownLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !item.isToday {
                    Text("\(item.daysUntil)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(item.isToday ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08),
                              lineWidth: item.isToday ? 1.5 : 0.5))
        }
        .buttonStyle(PressScaleButtonStyle())
        .sheet(isPresented: $showingDates) { ImportantDatesView() }
        .sheet(isPresented: $showingMoment) {
            ImportantDateMomentSheet(item: item, fragments: matchingFragments)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var matchingFragments: [Fragment] {
        let cal = Calendar.current
        let target = cal.dateComponents([.month, .day], from: item.date)
        return fragments.filter {
            let comps = cal.dateComponents([.month, .day], from: $0.date)
            if item.recurrenceRule == .monthly {
                return comps.day == target.day
            }
            return comps.month == target.month && comps.day == target.day
        }
    }
}

private struct ImportantDateMomentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: ImportantDate
    let fragments: [Fragment]

    @State private var showingEditor = false

    private var yearsText: String? {
        guard item.recurrenceRule == .yearly, let years = item.yearsElapsed, years > 0 else { return nil }
        return "第 \(years + 1) 年"
    }

    private var prefilledContent: String {
        if let yearsText {
            return "\(item.emoji) 今天是 \(item.title) \(yearsText)。"
        }
        return "\(item.emoji) 今天是 \(item.title)。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Text(item.emoji)
                                .font(.system(size: 42))
                                .frame(width: 64, height: 64)
                                .background(Color.accentColor.opacity(0.12), in: Circle())
                            Spacer()
                            Text("今天")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.10), in: Capsule())
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.title2).fontWeight(.bold)
                            if let yearsText {
                                Text(yearsText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if !item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(item.note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Button { showingEditor = true } label: {
                            Label("记录这个特别的日子", systemImage: "square.and.pencil")
                                .font(.subheadline).fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))

                    if !fragments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("这一天的碎片")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            ForEach(fragments.prefix(6)) { fragment in
                                NavigationLink {
                                    FragmentDetailView(fragment: fragment)
                                } label: {
                                    FragmentCardView(fragment: fragment)
                                }
                                .buttonStyle(PressScaleButtonStyle())
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background { AppBackgroundCanvas().ignoresSafeArea() }
            .navigationTitle("特别的今天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditor) {
                FragmentEditView(preloadedContent: prefilledContent, saveDraftOnCancel: false)
            }
        }
    }
}

// MARK: - Grid cell wrapper (eliminates left/right column duplication)

private struct GridCell: View {
    let fragment: Fragment
    var highlight: String = ""
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationLink {
            FragmentDetailView(fragment: fragment)
        } label: {
            FragmentGridCellView(fragment: fragment, highlight: highlight)
        }
        .buttonStyle(PressScaleButtonStyle())
        .contextMenu {
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            Button {
                fragment.isPinned.toggle()
                HapticFeedback.impact(.light)
            } label: {
                Label(fragment.isPinned ? "取消置顶" : "置顶",
                      systemImage: fragment.isPinned ? "pin.slash" : "pin")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .scrollTransition(.animated(.spring(response: 0.45, dampingFraction: 0.85))) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : max(0, 1 - abs(phase.value) * 0.6))
                .scaleEffect(phase.isIdentity ? 1 : max(0.92, 1 - abs(phase.value) * 0.07))
        }
    }
}

// MARK: - iCloud sync status icon (toolbar)

private struct SyncStatusIcon: View {
    let state: CloudKitSyncMonitor.SyncState

    var body: some View {
        ZStack {
            switch state {
            case .idle:
                EmptyView()
            case .syncing:
                ProgressView()
                    .scaleEffect(0.75)
                    .tint(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.ultraThinMaterial))
                    .transition(.opacity)
            case .succeeded:
                Image(systemName: "checkmark.icloud.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.ultraThinMaterial))
                    .transition(.scale(0.7).combined(with: .opacity))
            case .failed:
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.ultraThinMaterial))
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: state == .idle)
    }
}

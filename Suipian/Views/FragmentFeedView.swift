import SwiftUI
import SwiftData
import PhotosUI
import Photos

struct FragmentFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]

    @AppStorage("fragmentViewIsGrid") private var isGridView = false
    @AppStorage("fragmentSortAscending") private var sortAscending = false

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
    @State private var showingRandomReview = false
    @State private var randomFragment: Fragment? = nil
    @State private var hasDraft = false
    @State private var fabExpanded = false
    @State private var showingVoiceInput = false
    @State private var pendingVoiceTranscript = ""

    static let draftKey = "fragmentDraft_new"
    private func refreshDraftStatus() {
        hasDraft = UserDefaults.standard.data(forKey: Self.draftKey) != nil
    }

    var onThisDayFragments: [Fragment] {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let thisYear = cal.component(.year, from: Date())
        return fragments.filter {
            let c = cal.dateComponents([.month, .day], from: $0.date)
            return c.month == today.month && c.day == today.day
                && cal.component(.year, from: $0.date) < thisYear
        }
    }

    // Cached tag frequency — recomputed only when fragments change, not on every keypress
    @State private var cachedSortedTags: [(tag: String, count: Int)] = []

    private func buildSortedTags() -> [(tag: String, count: Int)] {
        var freq: [String: Int] = [:]
        for fragment in fragments {
            for tag in fragment.tags { freq[tag, default: 0] += 1 }
        }
        return freq.sorted { $0.value > $1.value }.map { (tag: $0.key, count: $0.value) }
    }

    var filteredFragments: [Fragment] {
        var result = fragments
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }
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
        return result.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return sortAscending ? lhs.date < rhs.date : lhs.date > rhs.date
        }
    }

    // Fragments older than 7 days, for random review
    private var reviewableFragments: [Fragment] {
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        return fragments.filter { $0.date < cutoff }
    }

    private func pickRandomFragment() {
        guard !reviewableFragments.isEmpty else { return }
        randomFragment = reviewableFragments.randomElement()
        showingRandomReview = true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
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

                    // On This Day banner
                    if !onThisDayFragments.isEmpty {
                        OnThisDayBanner(fragments: onThisDayFragments)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    // Compact filter bar
                    HStack(spacing: 10) {
                        if let tag = selectedTag {
                            HStack(spacing: 5) {
                                Text("#\(tag)  ·  \(filteredFragments.count) 条碎片")
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundStyle(Color.accentColor)
                                    .lineLimit(1)
                                Button { selectedTag = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.7))
                        } else {
                            Text("全部 · \(fragments.count) 条碎片")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Sort order toggle
                        Button {
                            sortAscending.toggle()
                        } label: {
                            Image(systemName: sortAscending ? "arrow.up.circle" : "arrow.down.circle")
                                .font(.title3)
                                .foregroundStyle(sortAscending ? Color.accentColor : .secondary)
                        }

                        // Tag filter
                        if !cachedSortedTags.isEmpty {
                            Button { showingTagPicker = true } label: {
                                Image(systemName: selectedTag != nil
                                      ? "line.3.horizontal.decrease.circle.fill"
                                      : "line.3.horizontal.decrease.circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedTag != nil ? Color.accentColor : .secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // Fragment cards
                    if isGridView {
                        let enumerated = Array(filteredFragments.enumerated())
                        let leftItems = enumerated.filter { $0.offset % 2 == 0 }.map(\.element)
                        let rightItems = enumerated.filter { $0.offset % 2 == 1 }.map(\.element)
                        HStack(alignment: .top, spacing: 12) {
                            LazyVStack(spacing: 12) {
                                ForEach(leftItems) { fragment in
                                    NavigationLink {
                                        FragmentDetailView(fragment: fragment)
                                    } label: {
                                        FragmentGridCellView(fragment: fragment)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button {
                                            fragment.isPinned.toggle()
                                            HapticFeedback.impact(.light)
                                        } label: {
                                            Label(fragment.isPinned ? "取消置顶" : "置顶",
                                                  systemImage: fragment.isPinned ? "pin.slash" : "pin")
                                        }
                                    }
                                }
                            }
                            LazyVStack(spacing: 12) {
                                ForEach(rightItems) { fragment in
                                    NavigationLink {
                                        FragmentDetailView(fragment: fragment)
                                    } label: {
                                        FragmentGridCellView(fragment: fragment)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button {
                                            fragment.isPinned.toggle()
                                            HapticFeedback.impact(.light)
                                        } label: {
                                            Label(fragment.isPinned ? "取消置顶" : "置顶",
                                                  systemImage: fragment.isPinned ? "pin.slash" : "pin")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                        .transition(.opacity)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(Array(filteredFragments.enumerated()), id: \.element.id) { index, fragment in
                                NavigationLink {
                                    FragmentDetailView(fragment: fragment)
                                } label: {
                                    FragmentCardView(fragment: fragment)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        fragment.isPinned.toggle()
                                        HapticFeedback.impact(.light)
                                    } label: {
                                        Label(fragment.isPinned ? "取消置顶" : "置顶",
                                              systemImage: fragment.isPinned ? "pin.slash" : "pin")
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !reviewableFragments.isEmpty {
                        Button { pickRandomFragment() } label: {
                            Image(systemName: "dice")
                                .glassToolbarIcon()
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { isGridView.toggle() }
                    } label: {
                        Image(systemName: isGridView ? "rectangle.grid.1x2" : "square.grid.2x2")
                            .contentTransition(.symbolEffect(.replace))
                            .glassToolbarIcon(active: isGridView)
                    }
                    .buttonStyle(.plain)
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
            cachedSortedTags = buildSortedTags()
            refreshDraftStatus()
            WidgetDataStore.updateTagFragments(fragments)
        }
        .onChange(of: fragments) { _, newFragments in
            cachedSortedTags = buildSortedTags()
            WidgetDataStore.updateTagFragments(newFragments)
        }
        .overlay {
                if fabExpanded {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { fabExpanded = false } }
                        .transition(.opacity)
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
        .sheet(isPresented: $showingRandomReview) {
            if let fragment = randomFragment {
                RandomReviewSheet(fragment: fragment) {
                    randomFragment = reviewableFragments.filter { $0.id != fragment.id }.randomElement() ?? reviewableFragments.randomElement()
                }
            }
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
    }
}

// MARK: - Sheet request types

private struct CreateRequest: Identifiable {
    let id = UUID()
    var preloadedContent: String = ""
}

private struct MediaEditRequest: Identifiable {
    let id = UUID()
    let mediaIDs: [String]
}

// MARK: - Speed-dial FAB

private struct SpeedDialFAB: View {
    @Binding var isExpanded: Bool
    let hasDraft: Bool
    let onText: () -> Void
    let onPhoto: () -> Void
    let onCamera: () -> Void
    let onVoice: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 14) {
                fabAction(icon: "camera.fill",             label: "拍照",  color: Color(red: 0.45, green: 0.55, blue: 0.72), action: onCamera)
                    .offset(y: isExpanded ? 0 : 40).opacity(isExpanded ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.72).delay(0.0), value: isExpanded)

                fabAction(icon: "photo.on.rectangle.fill", label: "相册",  color: Color(red: 0.42, green: 0.62, blue: 0.55), action: onPhoto)
                    .offset(y: isExpanded ? 0 : 40).opacity(isExpanded ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.72).delay(0.06), value: isExpanded)

                fabAction(icon: "text.alignleft",          label: "文字",  color: Color(red: 0.36, green: 0.44, blue: 0.64), action: onText)
                    .offset(y: isExpanded ? 0 : 40).opacity(isExpanded ? 1 : 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.72).delay(0.12), value: isExpanded)

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
        .buttonStyle(.plain)
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
    @State private var imageRatio: CGFloat

    // Process-lifetime cache: avoids layout jump on re-appearance
    private static var ratioCache: [String: CGFloat] = [:]

    // (screen - 16*2 padding - 12 gap) / 2 columns
    private static var columnWidth: CGFloat {
        (UIScreen.main.bounds.width - 44) / 2
    }

    init(fragment: Fragment) {
        self.fragment = fragment
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

    private var normalCell: some View {
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
                    let assets = PHAsset.fetchAssets(
                        withLocalIdentifiers: [coverID], options: nil)
                    if let asset = assets.firstObject, asset.pixelWidth > 0 {
                        let r = CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
                        Self.ratioCache[coverID] = r
                        imageRatio = r
                    }
                }
            } else {
                // Text-only: warm accent header strip
                Color(red: 0.780, green: 0.624, blue: 0.384).opacity(0.18)
                    .frame(maxWidth: .infinity, minHeight: 6, maxHeight: 6)
            }

            VStack(alignment: .leading, spacing: 5) {
                if !fragment.content.isEmpty {
                    Text(fragment.content)
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

// MARK: - Camera picker (UIImagePickerController wrapper)

private struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var capturedID: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
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
    let fragment: Fragment
    let onNext: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Time context
                    Label(
                        fragment.date.formatted(date: .long, time: .shortened),
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Cover image
                    if let coverID = fragment.coverMediaID {
                        MediaThumbnailView(identifier: coverID, size: CGSize(width: 600, height: 600))
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Mood + content
                    if !fragment.mood.isEmpty || !fragment.content.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            if !fragment.mood.isEmpty {
                                Text(fragment.mood)
                                    .font(.title2)
                            }
                            if !fragment.content.isEmpty {
                                Text(fragment.content)
                                    .font(.body)
                                    .lineSpacing(5)
                            }
                        }
                    }

                    // Tags
                    if !fragment.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(fragment.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .gradientTagStyle(fontSize: 12, paddingH: 10, paddingV: 4)
                            }
                        }
                    }

                    // Location
                    if fragment.hasLocation && !fragment.locationName.isEmpty {
                        Label(fragment.locationName, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("随机回顾")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.35)) { onNext() }
                    } label: {
                        Label("换一条", systemImage: "shuffle")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

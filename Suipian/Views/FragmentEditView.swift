import SwiftUI
import SwiftData
import PhotosUI
import MapKit
import CoreLocation

struct FragmentEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var fragment: Fragment?
    var preloadedMediaIDs: [String] = []

    @State private var content = ""
    @State private var mediaIdentifiers: [String] = []
    @State private var coverIdentifier: String? = nil
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var date = Date()
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var locationName = ""
    @State private var locationSearch = ""
    @State private var locationSuggestions: [NominatimResult] = []
    @State private var isPrivate = false
    @State private var audioFileNames: [String] = []
    @State private var mood: String = ""
    @State private var storyName: String = ""
    @State private var storyFieldFocused = false
    @State private var musicTitle: String = ""
    @State private var musicArtist: String = ""
    @State private var musicAlbum: String = ""
    @State private var musicArtworkData: Data = Data()
    @State private var musicStoreID: String = ""
    @State private var isFetchingLocation = false
    @State private var showDraftRestoredBanner = false

    @Query(sort: \Fragment.date, order: .reverse) private var allFragments: [Fragment]

    private var existingStoryNames: [String] {
        let names = allFragments.compactMap { $0.storyName.isEmpty ? nil : $0.storyName }
        return Array(NSOrderedSet(array: names)) as? [String] ?? []
    }

    private var storySuggestions: [String] {
        guard storyFieldFocused else { return [] }
        if storyName.isEmpty { return existingStoryNames }
        return existingStoryNames.filter { $0.localizedCaseInsensitiveContains(storyName) && $0 != storyName }
    }

    private struct SavedLocation {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    private var frequentLocations: [SavedLocation] {
        var freq: [String: (count: Int, lat: Double, lng: Double)] = [:]
        for f in allFragments where f.hasLocation && !f.locationName.isEmpty {
            if let e = freq[f.locationName] {
                freq[f.locationName] = (e.count + 1, e.lat, e.lng)
            } else {
                freq[f.locationName] = (1, f.latitude, f.longitude)
            }
        }
        return freq.sorted { $0.value.count > $1.value.count }
            .prefix(6)
            .map { SavedLocation(name: $0.key, latitude: $0.value.lat, longitude: $0.value.lng) }
    }

    private var frequentTags: [String] {
        var freq: [String: Int] = [:]
        for f in allFragments {
            for t in f.tags { freq[t, default: 0] += 1 }
        }
        return freq.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key < $1.key  // stable tie-break so order is deterministic across re-renders
        }
        .prefix(12)
        .map { $0.key }
        .filter { !tags.contains($0) }
    }
    @State private var cameraPosition: MapCameraPosition = .automatic

    // MARK: - Draft
    private static let draftKey = "fragmentDraft_new"

    private struct FragmentDraft: Codable {
        var content: String
        var tags: [String]
        var mood: String
        var storyName: String
        var mediaIdentifiers: [String]

        init(content: String, tags: [String], mood: String, storyName: String, mediaIdentifiers: [String]) {
            self.content = content; self.tags = tags; self.mood = mood
            self.storyName = storyName; self.mediaIdentifiers = mediaIdentifiers
        }

        // 兼容旧草稿（无 mediaIdentifiers 字段）
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            content = try c.decode(String.self, forKey: .content)
            tags = try c.decode([String].self, forKey: .tags)
            mood = try c.decode(String.self, forKey: .mood)
            storyName = try c.decode(String.self, forKey: .storyName)
            mediaIdentifiers = (try? c.decode([String].self, forKey: .mediaIdentifiers)) ?? []
        }
    }

    private func saveDraft() {
        guard !isEditing else { return }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !tags.isEmpty || !mediaIdentifiers.isEmpty else {
            UserDefaults.standard.removeObject(forKey: Self.draftKey)
            return
        }
        let draft = FragmentDraft(content: content, tags: tags, mood: mood,
                                  storyName: storyName, mediaIdentifiers: mediaIdentifiers)
        UserDefaults.standard.set(try? JSONEncoder().encode(draft), forKey: Self.draftKey)
    }

    private func restoreDraftIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: Self.draftKey),
              let draft = try? JSONDecoder().decode(FragmentDraft.self, from: data) else { return }
        content = draft.content
        tags = draft.tags
        mood = draft.mood
        storyName = draft.storyName
        if !draft.mediaIdentifiers.isEmpty {
            mediaIdentifiers = draft.mediaIdentifiers
        }
        showDraftRestoredBanner = true
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
    }

    private func discardDraft() {
        clearDraft()
        content = ""; tags = []; mood = ""; storyName = ""; mediaIdentifiers = []
        withAnimation { showDraftRestoredBanner = false }
    }

    var isEditing: Bool { fragment != nil }
    var hasLocation: Bool { latitude != 0 || longitude != 0 }
    var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !mediaIdentifiers.isEmpty
            || !audioFileNames.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── 草稿恢复提示 ──────────────────────────────
                    if showDraftRestoredBanner {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                Text("已恢复上次草稿")
                                    .font(.subheadline).fontWeight(.medium)
                                Spacer()
                                Button {
                                    withAnimation { showDraftRestoredBanner = false }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.accentColor.opacity(0.6))
                                }
                            }
                            HStack(spacing: 12) {
                                Text("继续编辑或直接保存即可")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor.opacity(0.75))
                                Spacer()
                                Button("丢弃草稿") { discardDraft() }
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            withAnimation { showDraftRestoredBanner = false }
                        }
                    }

                    // ── 主文本区 ─────────────────────────────────
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("写下这个碎片……")
                                .foregroundStyle(.tertiary)
                                .font(.body)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $content)
                            .frame(minHeight: 180)
                            .scrollDisabled(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Divider().padding(.vertical, 12)

                    // ── 媒体（照片 & 视频）────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 20,
                            matching: .any(of: [.images, .videos]),
                            photoLibrary: .shared()
                        ) {
                            Label("添加照片或视频", systemImage: "photo.on.rectangle.angled")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.horizontal, 16)

                        if !mediaIdentifiers.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(mediaIdentifiers.enumerated()), id: \.offset) { index, id in
                                        let isCover = id == (coverIdentifier ?? mediaIdentifiers.first)
                                        ZStack(alignment: .topTrailing) {
                                            MediaThumbnailView(
                                                identifier: id,
                                                size: CGSize(width: 200, height: 200)
                                            )
                                            .frame(width: 96, height: 96)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(Color.accentColor, lineWidth: isCover ? 2 : 0)
                                            )

                                            Button {
                                                if coverIdentifier == id { coverIdentifier = nil }
                                                mediaIdentifiers.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.white)
                                                    .shadow(radius: 2)
                                            }
                                            .padding(4)

                                            if isCover {
                                                Image(systemName: "photo.badge.checkmark.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.white)
                                                    .shadow(radius: 2)
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                                    .padding(5)
                                            }
                                        }
                                        .contextMenu {
                                            if !isCover {
                                                Button {
                                                    coverIdentifier = id
                                                } label: {
                                                    Label("设为首图", systemImage: "photo.badge.checkmark")
                                                }
                                            }
                                            Button(role: .destructive) {
                                                if coverIdentifier == id { coverIdentifier = nil }
                                                mediaIdentifiers.remove(at: index)
                                            } label: {
                                                Label("移除", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    Divider().padding(.vertical, 12)

                    // ── 语音 ──────────────────────────────────────
                    AudioRecorderRow(audioFileNames: $audioFileNames)

                    Divider().padding(.vertical, 12)

                    // ── 标签 ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            TextField("添加主题标签", text: $tagInput)
                                .id("tagInput")
                                .submitLabel(.done)
                                .onSubmit { commitTag() }
                            if !tagInput.isEmpty {
                                Button("添加") { commitTag() }
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal, 16)

                        // 常用标签快选（输入框为空且有历史标签时显示）
                        if tagInput.isEmpty && !frequentTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(frequentTags, id: \.self) { tag in
                                        Button {
                                            if !tags.contains(tag) { tags.append(tag) }
                                        } label: {
                                            Text("#\(tag)")
                                                .font(.subheadline)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(.ultraThinMaterial, in: Capsule())
                                                .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack(spacing: 4) {
                                            Text("#\(tag)")
                                                .font(.subheadline)
                                            Button {
                                                tags.removeAll { $0 == tag }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.5))
                                        .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    Divider().padding(.vertical, 12)

                    // ── 情绪 ──────────────────────────────────────
                    MoodPickerRow(selected: $mood)
                        .padding(.horizontal, 16)

                    Divider().padding(.vertical, 12)

                    // ── Apple Music ───────────────────────────────
                    MusicNowPlayingRow(
                        title: $musicTitle,
                        artist: $musicArtist,
                        album: $musicAlbum,
                        artworkData: $musicArtworkData,
                        storeID: $musicStoreID
                    )

                    Divider().padding(.vertical, 12)

                    // ── 故事线 ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            TextField("关联到故事线（选填）", text: $storyName,
                                      onEditingChanged: { storyFieldFocused = $0 })
                                .font(.subheadline)
                            if !storyName.isEmpty {
                                Button { storyName = ""; storyFieldFocused = false } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        if !storySuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(storySuggestions, id: \.self) { name in
                                    Button {
                                        storyName = name
                                        storyFieldFocused = false
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                                        to: nil, from: nil, for: nil)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "link")
                                                .font(.caption)
                                                .foregroundStyle(Color.accentColor)
                                            Text(name)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "arrow.up.left")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                    }
                                    if name != storySuggestions.last {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                        }
                    }

                    Divider().padding(.vertical, 12)

                    // ── 私密 ──────────────────────────────────────
                    Toggle(isOn: $isPrivate) {
                        Label("设为私密", systemImage: "lock.fill")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 16)

                    Divider().padding(.vertical, 12)

                    // ── 时间 & 地点 ───────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("时间", selection: $date)
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 8) {
                            // 一键获取当前位置
                            Button {
                                Task { await useCurrentLocation() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isFetchingLocation {
                                        ProgressView().scaleEffect(0.8)
                                        Text("正在获取位置…")
                                    } else {
                                        Image(systemName: hasLocation ? "location.fill" : "location")
                                        Text(hasLocation ? "已获取当前位置" : "使用当前位置")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(hasLocation ? Color.accentColor : Color.secondary)
                            }
                            .disabled(isFetchingLocation)
                            .padding(.horizontal, 16)

                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)

                                TextField("搜索地点（选填）", text: $locationSearch)
                                    .id("locationSearch")
                                    .submitLabel(.search)
                                    .onChange(of: locationSearch) { _, v in
                                        if v.isEmpty { locationSuggestions = [] }
                                    }
                                    .onSubmit {
                                        if let first = locationSuggestions.first {
                                            selectNominatimResult(first)
                                        }
                                    }
                                    .task(id: locationSearch) {
                                        guard !locationSearch.trimmingCharacters(in: .whitespaces).isEmpty,
                                              !hasLocation else { return }
                                        try? await Task.sleep(nanoseconds: 400_000_000)
                                        guard !Task.isCancelled else { return }
                                        locationSuggestions = await searchNominatim(query: locationSearch)
                                    }

                                if hasLocation {
                                    Button { clearLocation() } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            // 常用地点快选（无已选地点且未在搜索时显示）
                            if !hasLocation && locationSearch.isEmpty && !frequentLocations.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("常用地点")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 16)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(frequentLocations, id: \.name) { loc in
                                                Button {
                                                    locationName = loc.name
                                                    locationSearch = loc.name
                                                    latitude = loc.latitude
                                                    longitude = loc.longitude
                                                    cameraPosition = .region(MKCoordinateRegion(
                                                        center: CLLocationCoordinate2D(
                                                            latitude: loc.latitude,
                                                            longitude: loc.longitude),
                                                        span: MKCoordinateSpan(
                                                            latitudeDelta: 0.05,
                                                            longitudeDelta: 0.05)
                                                    ))
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "location.fill")
                                                            .font(.caption2)
                                                        Text(loc.name)
                                                            .font(.subheadline)
                                                            .lineLimit(1)
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 7)
                                                    .background(Color.accentColor.opacity(0.08))
                                                    .foregroundStyle(Color.accentColor)
                                                    .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }

                            if !locationSuggestions.isEmpty && !hasLocation {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(locationSuggestions.enumerated()), id: \.offset) { index, result in
                                        Button {
                                            selectNominatimResult(result)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.title)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                                if !result.subtitle.isEmpty {
                                                    Text(result.subtitle)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                        }
                                        if index < locationSuggestions.count - 1 {
                                            Divider().padding(.leading, 16)
                                        }
                                    }
                                }
                                .background(Color(.systemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal, 16)
                            }

                            if hasLocation {
                                Map(position: $cameraPosition) {
                                    Marker(
                                        locationName.isEmpty ? "这里" : locationName,
                                        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                                    )
                                }
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    Spacer(minLength: 48)
                }
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "编辑碎片" : "新建碎片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        saveDraft()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { loadExisting() }
            .onChange(of: selectedItems) { _, newItems in
                for item in newItems {
                    if let id = item.itemIdentifier, !mediaIdentifiers.contains(id) {
                        mediaIdentifiers.append(id)
                    }
                }
                selectedItems = []
            }
        }
    }

    // MARK: - Helpers

    private func loadExisting() {
        guard let fragment else {
            if !preloadedMediaIDs.isEmpty { mediaIdentifiers = preloadedMediaIDs }
            restoreDraftIfNeeded()
            return
        }
        isPrivate = fragment.isPrivate
        mood = fragment.mood
        storyName = fragment.storyName
        musicTitle = fragment.musicTitle
        musicArtist = fragment.musicArtist
        musicAlbum = fragment.musicAlbum
        musicArtworkData = fragment.musicArtworkData
        musicStoreID = fragment.musicStoreID
        content = fragment.content
        mediaIdentifiers = fragment.mediaIdentifiers
        coverIdentifier = fragment.coverIdentifier
        audioFileNames = fragment.audioFileNames
        tags = fragment.tags
        date = fragment.date
        latitude = fragment.latitude
        longitude = fragment.longitude
        locationName = fragment.locationName
        locationSearch = fragment.locationName
        if fragment.hasLocation {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: fragment.latitude, longitude: fragment.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }

    private func commitTag() {
        let trimmed = tagInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        tagInput = ""
    }

    private func selectNominatimResult(_ result: NominatimResult) {
        locationName = result.title
        locationSearch = result.title
        latitude = result.latitude
        longitude = result.longitude
        locationSuggestions = []
        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    private func searchNominatim(query: String) async -> [NominatimResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://nominatim.openstreetmap.org/search?q=\(encoded)&format=json&limit=5&accept-language=zh,ja,en") else {
            return []
        }
        var req = URLRequest(url: url)
        req.setValue("SuipianApp/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let items = try? JSONDecoder().decode([NominatimItem].self, from: data) else {
            return []
        }
        return items.map { item in
            let parts = item.displayName.components(separatedBy: ", ")
            let title = item.name ?? parts.first ?? item.displayName
            let sub = parts.dropFirst().prefix(2).joined(separator: ", ")
            return NominatimResult(title: title, subtitle: sub,
                                   latitude: Double(item.lat) ?? 0,
                                   longitude: Double(item.lon) ?? 0)
        }
    }

    private func useCurrentLocation() async {
        isFetchingLocation = true
        defer { isFetchingLocation = false }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                guard let location = update.location else { continue }

                latitude = location.coordinate.latitude
                longitude = location.coordinate.longitude

                // 反向地理编码 → 地名
                if let req = MKReverseGeocodingRequest(location: location),
                   let mapItem = (try? await req.mapItems)?.first {
                    let name = mapItem.address?.shortAddress ?? mapItem.address?.fullAddress ?? mapItem.name ?? ""
                    locationName = name
                    locationSearch = name
                }

                cameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
                break  // 只取第一个精确位置
            }
        } catch {
            // 用户拒绝授权或定位失败，静默处理
        }
    }

    private func clearLocation() {
        latitude = 0; longitude = 0
        locationName = ""; locationSearch = ""
        locationSuggestions = []
        cameraPosition = .automatic
    }

    private func save() {
        if let fragment {
            fragment.content = content
            fragment.mediaIdentifiers = mediaIdentifiers
            fragment.coverIdentifier = coverIdentifier
            fragment.audioFileNames = audioFileNames
            fragment.mood = mood
            fragment.storyName = storyName
            fragment.musicTitle = musicTitle
            fragment.musicArtist = musicArtist
            fragment.musicAlbum = musicAlbum
            fragment.musicArtworkData = musicArtworkData
            fragment.musicStoreID = musicStoreID
            fragment.tags = tags
            fragment.date = date
            fragment.latitude = latitude
            fragment.longitude = longitude
            fragment.locationName = locationName
            fragment.isPrivate = isPrivate
            SpotlightManager.index(fragment)
        } else {
            let f = Fragment(
                content: content,
                mediaIdentifiers: mediaIdentifiers,
                date: date,
                tags: tags,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName
            )
            f.coverIdentifier = coverIdentifier
            f.isPrivate = isPrivate
            f.audioFileNames = audioFileNames
            f.mood = mood
            f.storyName = storyName
            f.musicTitle = musicTitle
            f.musicArtist = musicArtist
            f.musicAlbum = musicAlbum
            f.musicArtworkData = musicArtworkData
            f.musicStoreID = musicStoreID
            modelContext.insert(f)
            SpotlightManager.index(f)
        }
        clearDraft()
        HapticFeedback.success()
        dismiss()
    }
}

// MARK: - Mood picker

private let moodOptions: [(emoji: String, label: String)] = [
    ("😊", "开心"), ("🥰", "幸福"), ("😌", "平静"),
    ("😞", "难过"), ("😤", "生气"), ("😰", "焦虑"), ("😴", "疲惫")
]

private struct MoodPickerRow: View {
    @Binding var selected: String
    @AppStorage("customMoodEmojis") private var customMoodsData: Data = Data()
    @State private var showingAddMood = false
    @State private var newMoodInput = ""

    private var customMoods: [String] {
        (try? JSONDecoder().decode([String].self, from: customMoodsData)) ?? []
    }

    private func addCustomMood(_ emoji: String) {
        let trimmed = emoji.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var moods = customMoods
        guard !moods.contains(trimmed) else { return }
        moods.append(trimmed)
        customMoodsData = (try? JSONEncoder().encode(moods)) ?? Data()
    }

    private func removeCustomMood(_ emoji: String) {
        var moods = customMoods.filter { $0 != emoji }
        customMoodsData = (try? JSONEncoder().encode(moods)) ?? Data()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "face.smiling")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Text("当前心情")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !selected.isEmpty {
                    Button { selected = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 预设情绪
                    ForEach(moodOptions, id: \.emoji) { opt in
                        moodChip(emoji: opt.emoji, label: opt.label)
                    }
                    // 自定义情绪（长按删除）
                    ForEach(customMoods, id: \.self) { emoji in
                        moodChip(emoji: emoji, label: nil)
                            .contextMenu {
                                Button(role: .destructive) {
                                    if selected == emoji { selected = "" }
                                    removeCustomMood(emoji)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                    // 添加按钮
                    Button { showingAddMood = true } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "plus")
                                .font(.body)
                                .frame(height: 28)
                            Text("自定义")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .alert("添加自定义心情", isPresented: $showingAddMood) {
            TextField("输入一个 emoji", text: $newMoodInput)
            Button("添加") {
                addCustomMood(newMoodInput)
                if !newMoodInput.trimmingCharacters(in: .whitespaces).isEmpty {
                    selected = newMoodInput.trimmingCharacters(in: .whitespaces)
                }
                newMoodInput = ""
            }
            Button("取消", role: .cancel) { newMoodInput = "" }
        } message: {
            Text("切换到 Emoji 键盘输入你喜欢的心情符号")
        }
    }

    @ViewBuilder
    private func moodChip(emoji: String, label: String?) -> some View {
        Button {
            selected = selected == emoji ? "" : emoji
        } label: {
            VStack(spacing: 2) {
                Text(emoji).font(.title3)
                if let label {
                    Text(label).font(.caption2)
                        .foregroundStyle(selected == emoji ? Color.accentColor : .secondary)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(selected == emoji ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected == emoji ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Nominatim (OpenStreetMap) location search — global coverage, no region lock

private struct NominatimResult {
    let title: String
    let subtitle: String
    let latitude: Double
    let longitude: Double
}

private struct NominatimItem: Decodable {
    let displayName: String
    let lat: String
    let lon: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case lat, lon, name
    }
}

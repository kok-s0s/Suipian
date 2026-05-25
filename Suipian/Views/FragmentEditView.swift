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
    @State private var searchResults: [FragmentLocationResult] = []
    @State private var isSearching = false
    @State private var isPrivate = false
    @State private var audioFileNames: [String] = []
    @State private var mood: String = ""
    @State private var storyName: String = ""
    @State private var isFetchingLocation = false
    @State private var cameraPosition: MapCameraPosition = .automatic

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
                                .submitLabel(.done)
                                .onSubmit { commitTag() }
                            if !tagInput.isEmpty {
                                Button("添加") { commitTag() }
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal, 16)

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
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(Capsule())
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

                    // ── 故事线 ────────────────────────────────────
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        TextField("关联到故事线（选填）", text: $storyName)
                            .font(.subheadline)
                        if !storyName.isEmpty {
                            Button { storyName = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

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
                                    .submitLabel(.search)
                                    .onSubmit { performSearch() }

                                if isSearching {
                                    ProgressView().scaleEffect(0.8)
                                } else if !locationSearch.isEmpty && !hasLocation {
                                    Button("搜索") { performSearch() }
                                        .font(.subheadline)
                                }
                                if hasLocation {
                                    Button { clearLocation() } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            if !searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(searchResults) { result in
                                        Button { selectLocation(result) } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                                if let sub = result.subtitle {
                                                    Text(sub)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                        }
                                        Divider().padding(.leading, 16)
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
            .navigationTitle(isEditing ? "编辑碎片" : "新建碎片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
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
            return
        }
        isPrivate = fragment.isPrivate
        mood = fragment.mood
        storyName = fragment.storyName
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

    private func performSearch() {
        guard !locationSearch.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        searchResults = []
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationSearch
        Task {
            do {
                let response = try await MKLocalSearch(request: request).start()
                searchResults = response.mapItems.prefix(5).map { FragmentLocationResult(mapItem: $0) }
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }

    private func selectLocation(_ result: FragmentLocationResult) {
        locationName = result.name
        locationSearch = result.name
        latitude = result.coordinate.latitude
        longitude = result.coordinate.longitude
        searchResults = []
        cameraPosition = .region(MKCoordinateRegion(
            center: result.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
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
            fragment.tags = tags
            fragment.date = date
            fragment.latitude = latitude
            fragment.longitude = longitude
            fragment.locationName = locationName
            fragment.isPrivate = isPrivate
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
            modelContext.insert(f)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                    ForEach(moodOptions, id: \.emoji) { opt in
                        Button {
                            selected = selected == opt.emoji ? "" : opt.emoji
                        } label: {
                            VStack(spacing: 2) {
                                Text(opt.emoji).font(.title3)
                                Text(opt.label).font(.caption2)
                                    .foregroundStyle(selected == opt.emoji ? Color.accentColor : .secondary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(selected == opt.emoji
                                        ? Color.accentColor.opacity(0.12)
                                        : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(selected == opt.emoji ? Color.accentColor : .clear, lineWidth: 1.5)
                            )
                        }
                    }
                }
            }
        }
    }
}

struct FragmentLocationResult: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    var name: String { mapItem.name ?? "未知地点" }
    var subtitle: String? { mapItem.address?.shortAddress ?? mapItem.address?.fullAddress }
    var coordinate: CLLocationCoordinate2D { mapItem.location.coordinate }
}

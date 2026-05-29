import SwiftUI
import SwiftData
import MapKit

struct FragmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let fragment: Fragment
    @Query private var storyFragments: [Fragment]

    init(fragment: Fragment) {
        self.fragment = fragment
        let storyName = fragment.storyName
        if storyName.isEmpty {
            _storyFragments = Query(filter: #Predicate<Fragment> { _ in false })
        } else {
            _storyFragments = Query(
                filter: #Predicate<Fragment> { $0.storyName == storyName },
                sort: [SortDescriptor(\Fragment.date, order: .reverse)]
            )
        }
    }

    private var relatedFragments: [Fragment] {
        let currentID = fragment.persistentModelID
        return storyFragments.filter { $0.persistentModelID != currentID }
    }

    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingFullScreen = false
    @State private var fullScreenStartIndex = 0
    @State private var authenticated = false
    @State private var showingShare = false
    @State private var shareImage: UIImage? = nil
    @State private var isRenderingShare = false

    var body: some View {
        if fragment.isPrivate && !authenticated {
            LockScreenView { authenticated = true }
        } else {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Media carousel
                if !fragment.mediaIdentifiers.isEmpty {
                    TabView {
                        ForEach(Array(fragment.mediaIdentifiers.enumerated()), id: \.offset) { index, id in
                            MediaDetailView(identifier: id)
                                .onTapGesture {
                                    fullScreenStartIndex = index
                                    showingFullScreen = true
                                }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: fragment.mediaIdentifiers.count > 1 ? .always : .never))
                    .frame(height: 320)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Date stamp — date is the soul of a journal entry
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(fragment.date.formatted(.dateTime.year().month(.wide).day()))
                                .font(.headline).fontWeight(.light)
                                .foregroundStyle(.primary)
                            Text(fragment.date.formatted(.dateTime.hour().minute()))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            if !fragment.mood.isEmpty {
                                Text(fragment.mood).font(.subheadline)
                            }
                        }
                        if fragment.hasLocation && !fragment.locationName.isEmpty {
                            Label(fragment.locationName, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Content
                    if !fragment.content.isEmpty {
                        Text(fragment.content)
                            .font(.body)
                            .lineSpacing(8)
                    }

                    // Link preview
                    if !fragment.linkURL.isEmpty {
                        LinkPreviewCard(
                            linkURL: fragment.linkURL,
                            linkTitle: fragment.linkTitle,
                            linkDescription: fragment.linkDescription,
                            linkImageURL: fragment.linkImageURL
                        )
                    }

                    // Music
                    if !fragment.musicTitle.isEmpty {
                        MusicDetailCard(
                            title: fragment.musicTitle,
                            artist: fragment.musicArtist,
                            album: fragment.musicAlbum,
                            artworkData: fragment.musicArtworkData,
                            storeID: fragment.musicStoreID
                        )
                    }

                    // Audio clips
                    if !fragment.audioFileNames.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(fragment.audioFileNames.enumerated()), id: \.element) { idx, name in
                                AudioPlayerCard(
                                    fileName: name,
                                    fallbackData: idx < fragment.audioData.count ? fragment.audioData[idx] : nil
                                )
                            }
                        }
                    }

                    // Tags
                    if !fragment.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(fragment.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .gradientTagStyle(fontSize: 13, paddingH: 12, paddingV: 5)
                                }
                            }
                        }
                    }

                    // Map
                    if fragment.hasLocation {
                        Map(initialPosition: .region(
                            MKCoordinateRegion(
                                center: CLLocationCoordinate2D(
                                    latitude: fragment.latitude,
                                    longitude: fragment.longitude
                                ),
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        )) {
                            Marker(
                                fragment.locationName.isEmpty ? "这里" : fragment.locationName,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: fragment.latitude,
                                    longitude: fragment.longitude
                                )
                            )
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    // Related fragments (story line)
                    if !relatedFragments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("「\(fragment.storyName)」的其他碎片", systemImage: "link")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            ForEach(relatedFragments) { related in
                                NavigationLink { FragmentDetailView(fragment: related) } label: {
                                    HStack(spacing: 10) {
                                        if let id = related.coverMediaID {
                                            MediaThumbnailView(identifier: id, size: CGSize(width: 80, height: 80))
                                                .frame(width: 44, height: 44)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.regularMaterial)
                                                .frame(width: 44, height: 44)
                                                .overlay(Image(systemName: "square.on.square").foregroundStyle(Color.accentColor).font(.caption))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            if !related.mood.isEmpty {
                                                Text(related.mood + " " + (related.content.isEmpty ? "（无文字）" : related.content))
                                                    .lineLimit(1)
                                            } else {
                                                Text(related.content.isEmpty ? "（无文字）" : related.content)
                                                    .lineLimit(1)
                                            }
                                            Text(related.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    .padding(10)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
        }
        .background { AppBackgroundCanvas().ignoresSafeArea() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showingEdit = true } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button {
                        Task {
                            isRenderingShare = true
                            shareImage = await renderShareCard(fragment: fragment)
                            isRenderingShare = false
                            if shareImage != nil { showingShare = true }
                        }
                    } label: {
                        Label(isRenderingShare ? "生成中…" : "分享卡片", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isRenderingShare)
                    Divider()
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingDeleteConfirm) {
            DeleteConfirmSheet {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                fragment.audioFileNames.forEach { AudioStore.delete($0) }
                modelContext.delete(fragment)
                WidgetDataStore.clear()
                dismiss()
            }
            .presentationDetents([.height(196)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showingEdit) {
            FragmentEditView(fragment: fragment)
        }
        .sheet(isPresented: $showingShare) {
            if let img = shareImage {
                ShareSheet(items: [img])
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            FullScreenMediaViewer(
                identifiers: fragment.mediaIdentifiers,
                startIndex: fullScreenStartIndex,
                coverIdentifier: fragment.coverIdentifier,
                onSetCover: { id in fragment.coverIdentifier = id }
            )
        }
        } // end else
    }
}

// MARK: - Delete confirmation sheet

private struct DeleteConfirmSheet: View {
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("删除碎片")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("此操作无法撤销，碎片将被永久删除")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 10) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onDelete() }
                } label: {
                    Text("永久删除")
                        .font(.body).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Text("取消")
                        .font(.body).fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

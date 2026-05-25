import SwiftUI
import SwiftData
import MapKit

struct FragmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let fragment: Fragment

    @Query(sort: \Fragment.date, order: .reverse) private var allFragments: [Fragment]

    private var relatedFragments: [Fragment] {
        guard !fragment.storyName.isEmpty else { return [] }
        return allFragments.filter { $0.storyName == fragment.storyName && $0.id != fragment.id }
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
                    // Date & location & mood
                    HStack(spacing: 12) {
                        Label(
                            fragment.date.formatted(date: .long, time: .shortened),
                            systemImage: "clock"
                        )
                        if fragment.hasLocation && !fragment.locationName.isEmpty {
                            Label(fragment.locationName, systemImage: "location.fill")
                        }
                        if !fragment.mood.isEmpty {
                            Text(fragment.mood).font(.body)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Content
                    if !fragment.content.isEmpty {
                        Text(fragment.content)
                            .font(.body)
                            .lineSpacing(6)
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
                            ForEach(fragment.audioFileNames, id: \.self) { name in
                                AudioPlayerCard(fileName: name)
                            }
                        }
                    }

                    // Tags
                    if !fragment.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(fragment.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(Capsule())
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
                                                .fill(Color.accentColor.opacity(0.1))
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
        .confirmationDialog(
            "删除后无法恢复",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除碎片", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                fragment.audioFileNames.forEach { AudioStore.delete($0) }
                modelContext.delete(fragment)
                dismiss()
            }
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

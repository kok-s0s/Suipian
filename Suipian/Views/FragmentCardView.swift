import SwiftUI
import Photos

struct FragmentCardView: View {
    let fragment: Fragment

    var body: some View {
        if fragment.isPrivate {
            privateCard
        } else {
            normalCard
        }
    }

    private var privateCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("私密碎片")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("需要 Face ID 才能查看")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text(fragment.date.formatted(.relative(presentation: .named)))
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .animeCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var normalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverID = fragment.coverMediaID {
                CardCoverView(identifier: coverID, count: fragment.mediaIdentifiers.count)
            }

            // Text & metadata
            VStack(alignment: .leading, spacing: 10) {
                if !fragment.content.isEmpty {
                    Text(fragment.content)
                        .font(fragment.hasMedia ? .subheadline : .body)
                        .foregroundStyle(.primary)
                        .lineLimit(fragment.hasMedia ? 3 : 8)
                        .multilineTextAlignment(.leading)
                }

                HStack(alignment: .center) {
                    if !fragment.tags.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(fragment.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(
                                            LinearGradient(
                                                colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.2)],
                                                startPoint: .leading, endPoint: .trailing
                                            ),
                                            lineWidth: 0.75
                                        )
                                    )
                            }
                            if fragment.tags.count > 3 {
                                Text("+\(fragment.tags.count - 3)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        if !fragment.musicTitle.isEmpty {
                            MusicBadge(title: fragment.musicTitle, artworkData: fragment.musicArtworkData)
                            Text("·").font(.caption).foregroundStyle(.tertiary)
                        }
                        if !fragment.mood.isEmpty {
                            Text(fragment.mood).font(.caption)
                            Text("·").font(.caption).foregroundStyle(.tertiary)
                        }
                        if fragment.hasLocation {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if !fragment.locationName.isEmpty {
                                Text(fragment.locationName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Text(fragment.date.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .animeCard(cornerRadius: 16)
    }
}

// MARK: - Cover image: scaledToFit, no cropping

private struct CardCoverView: View {
    let identifier: String
    let count: Int

    @Environment(\.displayScale) private var displayScale
    @State private var thumbnail: UIImage?
    @State private var isVideo = false
    @State private var cardWidth: CGFloat = 300

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                } else {
                    Color(.systemGray5)
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .overlay(ProgressView().tint(.secondary))
                }
            }
            .background(Color(.systemGray5))

            if isVideo {
                Color.black.opacity(0.15)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }

            if count > 1 {
                Label("\(count)", systemImage: "square.on.square")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(10)
            }
        }
        .background(GeometryReader { geo in
            Color.clear.onAppear { cardWidth = geo.size.width }
        })
        .task(id: identifier) { await load(scale: displayScale) }
    }

    private func load(scale: CGFloat) async {
        await requestPermissionIfNeeded()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return }
        isVideo = asset.mediaType == .video

        let targetWidth = cardWidth * scale
        let targetSize = CGSize(width: targetWidth, height: targetWidth * 2)

        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .highQualityFormat
        opts.resizeMode = .exact

        thumbnail = await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: opts
            ) { img, _ in
                cont.resume(returning: img)
            }
        }
    }
}

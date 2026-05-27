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
                .background(.regularMaterial, in: Circle())

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
                                    .gradientTagStyle()
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
                        if !fragment.linkURL.isEmpty {
                            LinkBadge(linkURL: fragment.linkURL)
                            Text("·").font(.caption).foregroundStyle(.tertiary)
                        }
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
        .overlay(alignment: .topTrailing) {
            if fragment.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                    .padding(8)
                    .accessibilityLabel("已置顶")
            }
        }
    }
}

// MARK: - Cover image: scaledToFit, no cropping

private struct CardCoverView: View {
    let identifier: String
    let count: Int

    @State private var thumbnail: UIImage?
    @State private var isVideo = false
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    // Fixed portrait target — enough detail on any phone, cache-friendly.
    private static let targetSize = CGSize(width: 600, height: 900)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(isVideo ? "视频封面" : "图片封面")
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
        .task(id: identifier) { await load() }
        .onDisappear { cancelPendingRequest() }
    }

    private func cancelPendingRequest() {
        guard requestID != PHInvalidImageRequestID else { return }
        PHImageManager.default().cancelImageRequest(requestID)
        requestID = PHInvalidImageRequestID
    }

    private func load() async {
        cancelPendingRequest()
        let key = "\(identifier)_card" as NSString
        if let cached = sharedThumbnailCache.object(forKey: key) {
            thumbnail = cached
            return
        }

        await requestPermissionIfNeeded()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject, !Task.isCancelled else { return }
        isVideo = asset.mediaType == .video

        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .highQualityFormat
        opts.resizeMode = .exact

        let img: UIImage? = await withCheckedContinuation { cont in
            requestID = PHImageManager.default().requestImage(
                for: asset,
                targetSize: Self.targetSize,
                contentMode: .aspectFit,
                options: opts
            ) { image, _ in cont.resume(returning: image) }
        }

        guard !Task.isCancelled, let img else { return }
        let target = Self.targetSize
        sharedThumbnailCache.setObject(img, forKey: key,
                                       cost: Int(target.width * target.height * 4))
        thumbnail = img
    }
}

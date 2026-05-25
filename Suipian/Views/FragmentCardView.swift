import SwiftUI
import Photos

struct FragmentCardView: View {
    let fragment: Fragment

    var body: some View {
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
                        HStack(spacing: 6) {
                            ForEach(fragment.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.accentColor)
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(.label).opacity(0.06), radius: 8, y: 2)
    }
}

// MARK: - Cover image: scaledToFit, no cropping

private struct CardCoverView: View {
    let identifier: String
    let count: Int

    @State private var thumbnail: UIImage?
    @State private var isVideo = false

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
        .task(id: identifier) { await load() }
    }

    private func load() async {
        await requestPermissionIfNeeded()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return }
        isVideo = asset.mediaType == .video

        let scale = UIScreen.main.scale
        let cardWidth = UIScreen.main.bounds.width - 32
        let targetWidth = cardWidth * scale
        // aspect-fit target: tall enough for 9:16 portrait
        let targetSize = CGSize(width: targetWidth, height: targetWidth * 2)

        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .highQualityFormat
        opts.resizeMode = .exact

        thumbnail = await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,   // fit, not fill — no cropping
                options: opts
            ) { img, _ in
                cont.resume(returning: img)
            }
        }
    }
}

import SwiftUI
import Photos

struct FragmentCardView: View {
    let fragment: Fragment

    // pixelWidth / pixelHeight from PHAsset metadata (fast, no image load)
    @State private var coverAspectRatio: CGFloat? = nil

    private var imageHeight: CGFloat {
        guard let ratio = coverAspectRatio, ratio > 0 else { return 220 }
        let cardWidth = UIScreen.main.bounds.width - 32  // 16pt padding each side
        let natural = cardWidth / ratio
        return max(180, min(natural, 360))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover media (user-chosen or first)
            if let coverID = fragment.coverMediaID {
                MediaThumbnailView(
                    identifier: coverID,
                    size: CGSize(width: 800, height: 1400)
                )
                .frame(maxWidth: .infinity)
                .frame(height: imageHeight)
                .clipped()
                .animation(.easeOut(duration: 0.15), value: coverAspectRatio)
                .overlay(alignment: .bottomTrailing) {
                    if fragment.mediaIdentifiers.count > 1 {
                        Label(
                            "\(fragment.mediaIdentifiers.count)",
                            systemImage: "square.on.square"
                        )
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(10)
                    }
                }
                .task(id: coverID) {
                    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [coverID], options: nil)
                    if let asset = assets.firstObject, asset.pixelWidth > 0 {
                        coverAspectRatio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
                    }
                }
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

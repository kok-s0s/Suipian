import SwiftUI
import Photos

// MARK: - Card view (rendered to image)

struct ShareCardView: View {
    let fragment: Fragment
    var thumbnailImage: UIImage?

    private var dateString: String {
        fragment.date.formatted(date: .long, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image
            if let img = thumbnailImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 12) {
                // App brand
                HStack(spacing: 6) {
                    Image(systemName: "square.on.square.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    Text("碎片")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Text(dateString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !fragment.content.isEmpty {
                    Text(fragment.content)
                        .font(.body)
                        .lineSpacing(5)
                        .lineLimit(10)
                        .foregroundStyle(.primary)
                }

                // Tags & location footer
                if !fragment.tags.isEmpty || (!fragment.locationName.isEmpty && fragment.hasLocation) {
                    HStack(spacing: 8) {
                        ForEach(fragment.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2).fontWeight(.medium)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.08), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5))
                        }
                        if fragment.hasLocation && !fragment.locationName.isEmpty {
                            Spacer()
                            Label(fragment.locationName, systemImage: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .frame(width: 340)
    }
}

// MARK: - Share sheet helper

@MainActor
func renderShareCard(fragment: Fragment) async -> UIImage? {
    var thumbnail: UIImage? = nil

    // Fetch cover thumbnail if available
    if let coverID = fragment.coverMediaID {
        thumbnail = await fetchThumbnail(localIdentifier: coverID)
    }

    let card = ShareCardView(fragment: fragment, thumbnailImage: thumbnail)
        .padding(24)
        .background(Color(.systemGroupedBackground))

    let renderer = ImageRenderer(content: card)
    renderer.scale = 3
    return renderer.uiImage
}

private func fetchThumbnail(localIdentifier: String) async -> UIImage? {
    await withCheckedContinuation { continuation in
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = result.firstObject else { continuation.resume(returning: nil); return }
        let size = CGSize(width: 680, height: 400)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: opts) { img, _ in
            continuation.resume(returning: img)
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

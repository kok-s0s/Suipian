import SwiftUI

struct FragmentCardView: View {
    let fragment: Fragment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover media (first photo or video)
            if let firstID = fragment.mediaIdentifiers.first {
                MediaThumbnailView(
                    identifier: firstID,
                    size: CGSize(width: 800, height: 500)
                )
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 220)
                .clipped()
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

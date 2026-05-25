import SwiftUI
import Photos

struct FullScreenMediaViewer: View {
    let identifiers: [String]
    let startIndex: Int
    var coverIdentifier: String?
    var onSetCover: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    // Precomputed synchronously in init — PHAsset metadata read is fast
    private let videoIDs: Set<String>

    init(identifiers: [String], startIndex: Int, coverIdentifier: String? = nil, onSetCover: ((String) -> Void)? = nil) {
        self.identifiers = identifiers
        self.startIndex = startIndex
        self.coverIdentifier = coverIdentifier
        self.onSetCover = onSetCover
        _currentIndex = State(initialValue: startIndex)

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var vids = Set<String>()
        assets.enumerateObjects { asset, _, _ in
            if asset.mediaType == .video { vids.insert(asset.localIdentifier) }
        }
        videoIDs = vids
    }

    private var effectiveCoverID: String? {
        if let id = coverIdentifier, identifiers.contains(id) { return id }
        return identifiers.first
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(identifiers.enumerated()), id: \.offset) { index, id in
                    if videoIDs.contains(id) {
                        // Videos: no gesture wrapper — VideoPlayer controls must receive touches freely
                        MediaDetailView(identifier: id)
                            .ignoresSafeArea()
                            .tag(index)
                    } else {
                        // Photos: pinch-to-zoom, double-tap, pan
                        ZoomablePhotoView(identifier: id)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: identifiers.count > 1 ? .always : .never))
            .ignoresSafeArea()

            // Close button (top-right)
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)

            // Set-cover button (bottom, photos only, multi-media only)
            if identifiers.count > 1, let onSetCover, !videoIDs.contains(identifiers[currentIndex]) {
                VStack {
                    Spacer()
                    let currentID = identifiers[currentIndex]
                    let isCover = currentID == effectiveCoverID
                    Button { onSetCover(currentID) } label: {
                        Label(
                            isCover ? "当前首图" : "设为首图",
                            systemImage: isCover ? "photo.badge.checkmark.fill" : "photo.badge.checkmark"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isCover ? .white.opacity(0.5) : .white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .disabled(isCover)
                    .padding(.bottom, 48)
                }
            }
        }
    }
}

// MARK: - Zoomable wrapper for photos only

private struct ZoomablePhotoView: View {
    let identifier: String

    @State private var scale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @GestureState private var dragDelta: CGSize = .zero

    var body: some View {
        MediaDetailView(identifier: identifier)
            .scaleEffect(max(1.0, scale * pinchScale))
            .offset(
                x: scale > 1 ? panOffset.width + dragDelta.width : 0,
                y: scale > 1 ? panOffset.height + dragDelta.height : 0
            )
            .gesture(
                MagnificationGesture()
                    .updating($pinchScale) { value, state, _ in state = value }
                    .onEnded { value in
                        let newScale = max(1.0, scale * value)
                        scale = newScale
                        if newScale <= 1.0 { panOffset = .zero }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .updating($dragDelta) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        panOffset = CGSize(
                            width: panOffset.width + value.translation.width,
                            height: panOffset.height + value.translation.height
                        )
                    },
                including: scale > 1 ? .all : .none
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if scale > 1.0 { scale = 1.0; panOffset = .zero }
                    else { scale = 2.5 }
                }
            }
    }
}

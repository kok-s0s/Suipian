import SwiftUI
import Photos

struct FullScreenMediaViewer: View {
    let identifiers: [String]
    let startIndex: Int
    var coverIdentifier: String?
    var onSetCover: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    private let videoIDs: Set<String>

    // Swipe-to-dismiss
    @State private var dismissOffset: CGFloat = 0
    @State private var dismissGestureCommitted = false  // direction-locked flag
    @State private var isCurrentPhotoZoomed = false

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
            Color.black
                .opacity(max(0.15, 1.0 - Double(dismissOffset) / 320))
                .ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(identifiers.enumerated()), id: \.offset) { index, id in
                    if videoIDs.contains(id) {
                        MediaDetailView(identifier: id, isFullScreen: true)
                            .ignoresSafeArea()
                            .tag(index)
                    } else {
                        ZoomablePhotoView(identifier: id, isZoomed: $isCurrentPhotoZoomed)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: identifiers.count > 1 ? .always : .never))
            .ignoresSafeArea()

            // Close button
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

            // Set-cover button (photos only, multi-media only)
            if identifiers.count > 1, let onSetCover,
               !videoIDs.contains(identifiers[currentIndex]) {
                VStack {
                    Spacer()
                    let currentID = identifiers[currentIndex]
                    let isCover = currentID == effectiveCoverID
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSetCover(currentID)
                    } label: {
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
        .offset(y: max(0, dismissOffset))
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard !isCurrentPhotoZoomed else { return }

                    if !dismissGestureCommitted {
                        // Direction lock: require a clearly downward-vertical start.
                        // Horizontal swipes (for TabView page changes) will never commit.
                        let isDown = value.translation.height > 0
                        let isVertical = abs(value.translation.height) > abs(value.translation.width) * 2.0
                        guard isDown && isVertical else { return }
                        dismissGestureCommitted = true
                    }

                    dismissOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    let wasCommitted = dismissGestureCommitted
                    dismissGestureCommitted = false

                    guard !isCurrentPhotoZoomed, wasCommitted else {
                        withAnimation(.spring(response: 0.3)) { dismissOffset = 0 }
                        return
                    }

                    let overThreshold = dismissOffset > 100
                        || value.predictedEndTranslation.height > 260
                    if overThreshold {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dismissOffset = 0
                        }
                    }
                }
        )
        .onChange(of: currentIndex) { _, _ in
            isCurrentPhotoZoomed = false
            dismissGestureCommitted = false
            withAnimation(.spring(response: 0.3)) { dismissOffset = 0 }
        }
    }
}

// MARK: - Zoomable wrapper (photos only)

private struct ZoomablePhotoView: View {
    let identifier: String
    @Binding var isZoomed: Bool

    @State private var scale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @GestureState private var dragDelta: CGSize = .zero

    var body: some View {
        MediaDetailView(identifier: identifier, isFullScreen: true)
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
                        isZoomed = newScale > 1.0
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
                    if scale > 1.0 {
                        scale = 1.0; panOffset = .zero; isZoomed = false
                    } else {
                        scale = 2.5; isZoomed = true
                    }
                }
            }
    }
}

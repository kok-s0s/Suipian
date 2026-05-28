import SwiftUI
import Photos
import AVKit

// Module-level cache shared across all callsites.
// 60 entries × ~256KB avg cost ≈ 15 MB typical; hard cap at 40 MB.
let sharedThumbnailCache: NSCache<NSString, UIImage> = {
    let c = NSCache<NSString, UIImage>()
    c.countLimit = 60
    c.totalCostLimit = 40 * 1024 * 1024
    return c
}()

// Snap requested size to a few standard buckets so the same asset
// shares a single cache entry across different callsites.
func standardThumbnailSize(_ size: CGSize) -> CGSize {
    let dim = max(size.width, size.height)
    let bucket: CGFloat
    switch dim {
    case ..<100:  bucket = 80
    case ..<160:  bucket = 120
    case ..<260:  bucket = 200
    case ..<400:  bucket = 300
    default:      bucket = 480
    }
    return CGSize(width: bucket, height: bucket)
}

struct MediaThumbnailView: View {
    let identifier: String
    var size: CGSize = CGSize(width: 300, height: 300)
    /// When true: requests the full uncroped image (.aspectFit) and displays
    /// with .scaledToFit so no content is lost. Caller is responsible for
    /// sizing the frame to match the image's natural aspect ratio.
    var fitContent: Bool = false

    @State private var thumbnail: UIImage?
    @State private var isVideo = false
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    var body: some View {
        ZStack {
            Color(.systemGray5)
            if let thumbnail {
                if fitContent {
                    Image(uiImage: thumbnail).resizable().scaledToFit()
                } else {
                    Image(uiImage: thumbnail).resizable().scaledToFill()
                }
                if isVideo {
                    Color.black.opacity(0.15)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }
            } else {
                ProgressView().tint(.secondary)
            }
        }
        .task(id: identifier) { await loadThumbnail() }
        .onDisappear { cancelPendingRequest() }
    }

    private func cancelPendingRequest() {
        guard requestID != PHInvalidImageRequestID else { return }
        PHImageManager.default().cancelImageRequest(requestID)
        requestID = PHInvalidImageRequestID
    }

    private func loadThumbnail() async {
        cancelPendingRequest()

        // fitContent: request uncroped image in a tall envelope; fill: square crop as before
        let target: CGSize
        let phMode: PHImageContentMode
        let cacheKey: NSString
        if fitContent {
            target = CGSize(width: 480, height: 960)
            phMode = .aspectFit
            cacheKey = "\(identifier)_fit" as NSString
        } else {
            target = standardThumbnailSize(size)
            phMode = .aspectFill
            cacheKey = "\(identifier)_\(Int(target.width))" as NSString
        }

        if let cached = sharedThumbnailCache.object(forKey: cacheKey) {
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
                targetSize: target,
                contentMode: phMode,
                options: opts
            ) { image, _ in cont.resume(returning: image) }
        }

        guard !Task.isCancelled, let img else { return }
        sharedThumbnailCache.setObject(img, forKey: cacheKey,
                                       cost: Int(target.width * target.height * 4))
        thumbnail = img
    }
}

// MARK: - Full-screen media (photo or video)

struct MediaDetailView: View {
    let identifier: String

    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var isVideo = false
    @State private var loaded = false
    @State private var downloadProgress: Double = 0

    // Cap at a generous but bounded size: enough for any screen at 2–3×,
    // avoiding decoding 48 MB+ originals just to fill a phone display.
    private static let maxDetailSize: CGSize = {
        let s = UIScreen.main.bounds.size
        let scale = min(UIScreen.main.scale, 2)
        return CGSize(width: s.width * scale * 1.5, height: s.height * scale * 1.5)
    }()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !loaded {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    if downloadProgress > 0 && downloadProgress < 1 {
                        VStack(spacing: 6) {
                            ProgressView(value: downloadProgress)
                                .tint(.white)
                                .frame(width: 140)
                            Text("从 iCloud 下载 \(Int(downloadProgress * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            } else if isVideo, let player {
                VideoPlayer(player: player)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: identifier) { await load() }
        .onDisappear { player?.pause() }
    }

    private func load() async {
        await requestPermissionIfNeeded()

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { loaded = true; return }

        isVideo = asset.mediaType == .video

        if isVideo {
            let opts = PHVideoRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = .automatic
            opts.progressHandler = { progress, _, _, _ in
                DispatchQueue.main.async { downloadProgress = progress }
            }

            let avAsset = await withCheckedContinuation { (cont: CheckedContinuation<AVAsset?, Never>) in
                PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { av, _, _ in
                    cont.resume(returning: av)
                }
            }
            if let avAsset {
                player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
            }
        } else {
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            opts.progressHandler = { progress, _, _, _ in
                DispatchQueue.main.async { downloadProgress = progress }
            }

            image = await withCheckedContinuation { cont in
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: Self.maxDetailSize,
                    contentMode: .aspectFit,
                    options: opts
                ) { img, _ in cont.resume(returning: img) }
            }
        }
        loaded = true
    }
}

// MARK: - Permission helper

func requestPermissionIfNeeded() async {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    guard status == .notDetermined else { return }
    _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
}

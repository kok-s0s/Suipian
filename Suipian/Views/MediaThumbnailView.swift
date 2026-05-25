import SwiftUI
import Photos

struct MediaThumbnailView: View {
    let identifier: String
    var size: CGSize = CGSize(width: 400, height: 400)

    @State private var thumbnail: UIImage?
    @State private var isVideo = false

    var body: some View {
        ZStack {
            Color(.systemGray5)

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                if isVideo {
                    Color.black.opacity(0.15)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }
            } else {
                ProgressView()
                    .tint(.secondary)
            }
        }
        .task(id: identifier) {
            await load()
        }
    }

    private func load() async {
        await requestPermissionIfNeeded()

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return }

        isVideo = asset.mediaType == .video

        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .highQualityFormat
        opts.resizeMode = .exact

        thumbnail = await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: opts
            ) { img, _ in
                cont.resume(returning: img)
            }
        }
    }
}

// MARK: - Full-screen media (photo or video)

import AVKit

struct MediaDetailView: View {
    let identifier: String

    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var isVideo = false
    @State private var loaded = false
    @State private var downloadProgress: Double = 0

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
        .task(id: identifier) {
            await load()
        }
        .onDisappear {
            player?.pause()
        }
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

            image = await withCheckedContinuation { cont in
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: opts
                ) { img, _ in
                    cont.resume(returning: img)
                }
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

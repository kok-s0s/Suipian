import SwiftUI
import MediaPlayer

// MARK: - Data model passed between views

struct NowPlayingInfo {
    let title: String
    let artist: String
    let album: String
    let artworkData: Data
    let storeID: String
}

// MARK: - Fetch now playing from system player

@MainActor
func fetchNowPlaying() async -> NowPlayingInfo? {
    let player = MPMusicPlayerController.systemMusicPlayer
    guard let item = player.nowPlayingItem,
          let title = item.title else { return nil }

    let artist = item.artist ?? ""
    let album  = item.albumTitle ?? ""
    let storeID = item.value(forProperty: MPMediaItemPropertyPlaybackStoreID) as? String ?? ""

    var artworkData = Data()
    if let artwork = item.artwork,
       let img = artwork.image(at: CGSize(width: 300, height: 300)),
       let jpeg = img.jpegData(compressionQuality: 0.8) {
        artworkData = jpeg
    }

    return NowPlayingInfo(title: title, artist: artist, album: album,
                          artworkData: artworkData, storeID: storeID)
}

// MARK: - Edit-view row

struct MusicNowPlayingRow: View {
    @Binding var title: String
    @Binding var artist: String
    @Binding var album: String
    @Binding var artworkData: Data
    @Binding var storeID: String

    @State private var fetching = false
    @State private var permissionDenied = false

    private var hasMusic: Bool { !title.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasMusic {
                // Filled state
                HStack(spacing: 12) {
                    artworkView(size: 52)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline).fontWeight(.medium)
                            .lineLimit(1)
                        Text(artist.isEmpty ? album : (album.isEmpty ? artist : "\(artist) · \(album)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button { clearMusic() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            } else {
                // Empty state
                Button {
                    Task { await fetchAndFill() }
                } label: {
                    HStack(spacing: 8) {
                        if fetching {
                            ProgressView().scaleEffect(0.8)
                            Text("读取中…").font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "music.note")
                                .foregroundStyle(Color.accentColor)
                                .font(.subheadline)
                            Text("附加当前播放的歌曲")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .disabled(fetching)
                .padding(.horizontal, 16)
            }
        }
        .alert("无法访问 Apple Music", isPresented: $permissionDenied) {
            Button("去设置") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在系统设置中允许碎片访问媒体与 Apple Music。")
        }
    }

    @ViewBuilder
    private func artworkView(size: CGFloat) -> some View {
        if let img = UIImage(data: artworkData) {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .frame(width: size, height: size)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
        }
    }

    private func fetchAndFill() async {
        fetching = true
        defer { fetching = false }

        // Request permission
        let status = MPMediaLibrary.authorizationStatus()
        if status == .notDetermined {
            let granted = await withCheckedContinuation { cont in
                MPMediaLibrary.requestAuthorization { cont.resume(returning: $0) }
            }
            if granted != .authorized { permissionDenied = true; return }
        } else if status == .denied || status == .restricted {
            permissionDenied = true; return
        }

        guard let info = await fetchNowPlaying() else { return }
        title = info.title
        artist = info.artist
        album = info.album
        artworkData = info.artworkData
        storeID = info.storeID
    }

    private func clearMusic() {
        title = ""; artist = ""; album = ""
        artworkData = Data(); storeID = ""
    }
}

// MARK: - Detail-view music card

struct MusicDetailCard: View {
    let title: String
    let artist: String
    let album: String
    let artworkData: Data
    let storeID: String

    var body: some View {
        Button { openInAppleMusic() } label: {
            HStack(spacing: 14) {
                artworkView(size: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !artist.isEmpty {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !album.isEmpty {
                        Text(album)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func artworkView(size: CGFloat) -> some View {
        if let img = UIImage(data: artworkData) {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .frame(width: size, height: size)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary).font(.title3))
        }
    }

    private func openInAppleMusic() {
        // Try store ID first, fall back to search
        var urlString: String
        if !storeID.isEmpty {
            urlString = "https://music.apple.com/song/id\(storeID)"
        } else {
            let q = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString = "https://music.apple.com/search?term=\(q)"
        }
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Compact badge for card view

struct MusicBadge: View {
    let title: String
    let artworkData: Data

    var body: some View {
        HStack(spacing: 4) {
            if let img = UIImage(data: artworkData) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }
}

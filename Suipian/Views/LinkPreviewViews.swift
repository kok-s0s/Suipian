import SwiftUI

// MARK: - Platform info

struct PlatformInfo {
    let icon: String
    let name: String
    let color: Color
}

func platformInfo(for urlString: String) -> PlatformInfo {
    guard let host = URL(string: urlString)?.host?.lowercased() else {
        return PlatformInfo(icon: "link", name: "链接", color: .secondary)
    }
    switch true {
    case host.contains("x.com") || host.contains("twitter.com"):
        return PlatformInfo(icon: "bubble.left.fill", name: "X (Twitter)", color: Color.primary)
    case host.contains("xiaohongshu.com") || host.contains("xhslink.com") || host.contains("xhs.link"):
        return PlatformInfo(icon: "heart.fill", name: "小红书", color: Color(red: 0.82, green: 0.22, blue: 0.22))
    case host.contains("douyin.com") || host.contains("tiktok.com") || host.contains("iesdouyin.com"):
        return PlatformInfo(icon: "music.note", name: "抖音", color: Color.primary)
    case host.contains("weibo.com") || host.contains("weibo.cn"):
        return PlatformInfo(icon: "flame.fill", name: "微博", color: Color(red: 0.80, green: 0.26, blue: 0.22))
    case host.contains("instagram.com"):
        return PlatformInfo(icon: "camera.fill", name: "Instagram", color: Color(red: 0.75, green: 0.22, blue: 0.56))
    case host.contains("youtube.com") || host.contains("youtu.be"):
        return PlatformInfo(icon: "play.rectangle.fill", name: "YouTube", color: Color(red: 0.80, green: 0.15, blue: 0.15))
    case host.contains("bilibili.com") || host.contains("b23.tv"):
        return PlatformInfo(icon: "play.circle.fill", name: "哔哩哔哩", color: Color(red: 0.0, green: 0.56, blue: 0.76))
    case host.contains("github.com"):
        return PlatformInfo(icon: "chevron.left.forwardslash.chevron.right", name: "GitHub", color: Color.primary)
    default:
        let name = host.replacingOccurrences(of: "www.", with: "").components(separatedBy: ".").first ?? host
        return PlatformInfo(icon: "link", name: name, color: .secondary)
    }
}

// MARK: - OG fetcher

struct LinkPreviewData {
    var url: String
    var title: String
    var description: String
    var imageURL: String
}

func fetchLinkPreview(urlString: String) async -> LinkPreviewData? {
    var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
        normalized = "https://" + normalized
    }
    guard let url = URL(string: normalized) else { return nil }

    var req = URLRequest(url: url)
    req.timeoutInterval = 10
    req.setValue(
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        forHTTPHeaderField: "User-Agent"
    )
    req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
    req.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")

    guard let (data, response) = try? await URLSession.shared.data(for: req) else { return nil }

    let finalURL = (response as? HTTPURLResponse)?.url?.absoluteString ?? normalized

    // Try UTF-8 first, fall back to Latin-1 for some legacy sites
    guard let html = String(data: data, encoding: .utf8)
                  ?? String(data: data, encoding: .isoLatin1) else { return nil }

    let title = ogMeta(html, "og:title") ?? ogMeta(html, "twitter:title") ?? htmlTitle(html) ?? ""
    let description = ogMeta(html, "og:description") ?? ogMeta(html, "twitter:description") ?? ""
    var imageURL = ogMeta(html, "og:image") ?? ogMeta(html, "twitter:image") ?? ""

    // Resolve relative image URL against the final URL
    if !imageURL.isEmpty, !imageURL.hasPrefix("http"), let base = URL(string: finalURL) {
        imageURL = URL(string: imageURL, relativeTo: base)?.absoluteString ?? imageURL
    }

    return LinkPreviewData(url: finalURL, title: title, description: description, imageURL: imageURL)
}

private func ogMeta(_ html: String, _ key: String) -> String? {
    let escaped = NSRegularExpression.escapedPattern(for: key)
    let patterns = [
        "property=[\"']\(escaped)[\"']\\s+content=[\"']([^\"'<>]*)[\"']",
        "content=[\"']([^\"'<>]*)[\"']\\s+property=[\"']\(escaped)[\"']",
        "name=[\"']\(escaped)[\"']\\s+content=[\"']([^\"'<>]*)[\"']",
        "content=[\"']([^\"'<>]*)[\"']\\s+name=[\"']\(escaped)[\"']",
    ]
    for pattern in patterns {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(m.range(at: 1), in: html) else { continue }
        let v = String(html[r]).htmlEntityDecoded
        if !v.isEmpty { return v }
    }
    return nil
}

private func htmlTitle(_ html: String) -> String? {
    guard let re = try? NSRegularExpression(pattern: "<title[^>]*>([^<]+)</title>", options: .caseInsensitive),
          let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
          let r = Range(m.range(at: 1), in: html) else { return nil }
    return String(html[r]).htmlEntityDecoded
}

private extension String {
    var htmlEntityDecoded: String {
        var s = self
        [("&amp;","&"),("&lt;","<"),("&gt;",">"),("&quot;","\""),("&#39;","'"),
         ("&nbsp;"," "),("&#x27;","'"),("&#x2F;","/")].forEach { s = s.replacingOccurrences(of: $0.0, with: $0.1) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Edit-view row

struct LinkPreviewRow: View {
    @Binding var linkURL: String
    @Binding var linkTitle: String
    @Binding var linkDescription: String
    @Binding var linkImageURL: String

    @State private var inputText = ""
    @State private var isExpanded = false
    @State private var isFetching = false
    @State private var fetchFailed = false

    private var hasLink: Bool { !linkURL.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasLink {
                filledCard
            } else if isExpanded {
                inputRow
            } else {
                emptyButton
            }
        }
        .onAppear {
            if hasLink { inputText = linkURL }
        }
    }

    // ── Empty state ──────────────────────────────────────────

    private var emptyButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { isExpanded = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .foregroundStyle(Color.accentColor)
                    .font(.subheadline)
                Text("附加链接预览")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
    }

    // ── Input row ────────────────────────────────────────────

    private var inputRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            TextField("粘贴链接地址", text: $inputText)
                .font(.subheadline)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.go)
                .onSubmit { Task { await doFetch() } }

            if isFetching {
                ProgressView().scaleEffect(0.8)
            } else if !inputText.isEmpty {
                Button { Task { await doFetch() } } label: {
                    Text("获取")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
            }

            Button {
                withAnimation { isExpanded = false; inputText = ""; fetchFailed = false }
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .overlay(alignment: .bottomLeading) {
            if fetchFailed {
                Text("无法获取预览，已保存链接")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.leading, 16).padding(.top, 4)
                    .offset(y: 20)
            }
        }
        .padding(.bottom, fetchFailed ? 16 : 0)
    }

    // ── Filled card ──────────────────────────────────────────

    private var filledCard: some View {
        HStack(spacing: 10) {
            // Thumbnail or platform icon
            Group {
                if !linkImageURL.isEmpty, let imgURL = URL(string: linkImageURL) {
                    AsyncImage(url: imgURL) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            platformIconView(size: 44)
                        }
                    }
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    platformIconView(size: 54)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                let info = platformInfo(for: linkURL)
                Text(info.name)
                    .font(.caption2)
                    .foregroundStyle(info.color)
                Text(linkTitle.isEmpty ? linkURL : linkTitle)
                    .font(.subheadline).fontWeight(.medium)
                    .lineLimit(1)
                if !linkDescription.isEmpty {
                    Text(linkDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button { clearLink() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func platformIconView(size: CGFloat) -> some View {
        let info = platformInfo(for: hasLink ? linkURL : inputText)
        RoundedRectangle(cornerRadius: 8)
            .fill(info.color.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: info.icon)
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(info.color)
            )
    }

    // ── Helpers ──────────────────────────────────────────────

    private func doFetch() async {
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        isFetching = true
        fetchFailed = false
        defer { isFetching = false }

        if let data = await fetchLinkPreview(urlString: raw) {
            linkURL         = data.url
            linkTitle       = data.title
            linkDescription = data.description
            linkImageURL    = data.imageURL
        } else {
            // Save just the URL even if fetch fails
            var url = raw
            if !url.hasPrefix("http") { url = "https://" + url }
            linkURL = url; linkTitle = ""; linkDescription = ""; linkImageURL = ""
            fetchFailed = true
        }
        withAnimation { isExpanded = false }
    }

    private func clearLink() {
        linkURL = ""; linkTitle = ""; linkDescription = ""; linkImageURL = ""
        inputText = ""; isExpanded = false; fetchFailed = false
    }
}

// MARK: - Detail-view card

struct LinkPreviewCard: View {
    let linkURL: String
    let linkTitle: String
    let linkDescription: String
    let linkImageURL: String

    var body: some View {
        Button { open() } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Cover image
                if !linkImageURL.isEmpty, let imgURL = URL(string: linkImageURL) {
                    AsyncImage(url: imgURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .clipped()
                        }
                    }
                }

                HStack(spacing: 12) {
                    let info = platformInfo(for: linkURL)

                    // Platform badge
                    RoundedRectangle(cornerRadius: 8)
                        .fill(info.color.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: info.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(info.color)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.name)
                            .font(.caption2)
                            .foregroundStyle(info.color)
                        Text(linkTitle.isEmpty ? linkURL : linkTitle)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if !linkDescription.isEmpty {
                            Text(linkDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
                .padding(12)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func open() {
        guard let url = URL(string: linkURL) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Compact badge for list cards

struct LinkBadge: View {
    let linkURL: String

    var body: some View {
        let info = platformInfo(for: linkURL)
        HStack(spacing: 4) {
            Image(systemName: info.icon)
                .font(.system(size: 9))
                .foregroundStyle(info.color)
            Text(info.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }
}

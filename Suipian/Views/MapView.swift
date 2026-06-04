import SwiftUI
import SwiftData
import MapKit

// MARK: - Cluster model

struct FragmentCluster: Identifiable {
    var fragments: [Fragment]
    var id: String { fragments.first.map { "\($0.persistentModelID)" } ?? "" }

    var coordinate: CLLocationCoordinate2D {
        let lat = fragments.map { $0.latitude }.reduce(0, +) / Double(fragments.count)
        let lon = fragments.map { $0.longitude }.reduce(0, +) / Double(fragments.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var isSingle: Bool { fragments.count == 1 }

    var displayName: String {
        let names = fragments.compactMap { $0.locationName.isEmpty ? nil : $0.locationName }
        if let first = names.first { return first }
        return "\(fragments.count) 条碎片"
    }
}

private func makeClusters(_ fragments: [Fragment], threshold: Double) -> [FragmentCluster] {
    var clusters: [FragmentCluster] = []
    for f in fragments {
        if let i = clusters.firstIndex(where: { c in
            guard let seed = c.fragments.first else { return false }
            return abs(seed.latitude - f.latitude) < threshold &&
                   abs(seed.longitude - f.longitude) < threshold
        }) {
            clusters[i].fragments.append(f)
        } else {
            clusters.append(FragmentCluster(fragments: [f]))
        }
    }
    return clusters
}

// MARK: - Long-press pin token

private struct LongPressMark: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var resolvedName: String = ""
}

// MARK: - Map view

struct FragmentMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var fragments: [Fragment]
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCluster: FragmentCluster? = nil
    @State private var showingClusterSheet = false
    @State private var showingLocationSearch = false
    @State private var locationSearchText = ""
    @State private var locationSearchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)

    // Map style
    @State private var mapStyle: MapStyleOption = .standard
    enum MapStyleOption: String, CaseIterable {
        case standard = "地图"
        case satellite = "卫星"
        case hybrid = "混合"
        var mapStyle: MapStyle {
            switch self {
            case .standard:  return .standard
            case .satellite: return .imagery
            case .hybrid:    return .hybrid
            }
        }
        var icon: String {
            switch self {
            case .standard:  return "map"
            case .satellite: return "globe.asia.australia"
            case .hybrid:    return "map.fill"
            }
        }
    }

    // Long-press create
    @State private var longPressMark: LongPressMark? = nil
    @State private var isResolvingName = false
    @State private var createRequest: MapCreateRequest? = nil

    private struct MapCreateRequest: Identifiable {
        let id = UUID()
        let latitude: Double
        let longitude: Double
        let locationName: String
    }

    @State private var cachedClusters: [FragmentCluster] = []
    var clusters: [FragmentCluster] { cachedClusters }

    private func rebuildClusters() {
        let located = fragments.filter { $0.hasLocation }
        let threshold = max(mapSpan.latitudeDelta * 0.10, 0.004)
        cachedClusters = makeClusters(located, threshold: threshold)
    }

    private func doLocationSearch() async {
        let query = locationSearchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let response = try? await MKLocalSearch(request: request).start() {
            locationSearchResults = Array(response.mapItems.prefix(6))
        }
        isSearching = false
    }

    private func selectLocationResult(_ item: MKMapItem) {
        withAnimation(.spring(response: 0.3)) {
            position = .region(MKCoordinateRegion(
                center: item.placemark.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            ))
        }
        showingLocationSearch = false
        locationSearchText = ""
        locationSearchResults = []
    }

    private func flyToRandom() {
        guard let randomCluster = clusters.randomElement() else { return }
        selectedCluster = nil
        withAnimation(.easeInOut(duration: 0.9)) {
            position = .region(MKCoordinateRegion(
                center: randomCluster.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            ))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.35)) { selectedCluster = randomCluster }
            HapticFeedback.impact(.light)
        }
    }

    private func resolveName(for coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // MKReverseGeocodingRequest (iOS 18+); fall back to CLGeocoder on older OS
        if #available(iOS 18, *) {
            if let req = MKReverseGeocodingRequest(location: location),
               let item = try? await req.mapItems.first {
                return [item.name, item.placemark.locality]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            }
        } else {
            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let p = placemarks.first {
                return [p.name, p.locality]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            }
        }
        return ""
    }

    // Extracted to help the type-checker — Map + annotations in isolation
    @MapContentBuilder
    private func mapAnnotations() -> some MapContent {
        UserAnnotation()
        ForEach(clusters) { cluster in
            Annotation("", coordinate: cluster.coordinate) {
                ClusterPin(cluster: cluster, isSelected: selectedCluster?.id == cluster.id)
                    .onTapGesture { tapCluster(cluster) }
            }
        }
        if let mark = longPressMark {
            Annotation("", coordinate: mark.coordinate) {
                LongPressPin(isResolving: isResolvingName)
            }
        }
    }

    private func tapCluster(_ cluster: FragmentCluster) {
        if selectedCluster?.id == cluster.id {
            withAnimation(.spring(response: 0.3)) { selectedCluster = nil }
        } else {
            longPressMark = nil
            // Smooth pan — easeInOut feels like the map is gliding, not jumping
            withAnimation(.easeInOut(duration: 0.75)) {
                position = .region(MKCoordinateRegion(
                    center: cluster.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                ))
            }
            // Show the card after the pan lands
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.35)) { selectedCluster = cluster }
            }
        }
    }

    private func handleLongPress(at screenPoint: CGPoint, proxy: MapProxy) {
        guard let coord = proxy.convert(screenPoint, from: .local) else { return }
        HapticFeedback.impact(.medium)
        withAnimation(.spring(response: 0.3)) {
            selectedCluster = nil
            longPressMark = LongPressMark(coordinate: coord)
            position = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        isResolvingName = true
        Task {
            let name = await resolveName(for: coord)
            longPressMark?.resolvedName = name
            isResolvingName = false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    Map(position: $position) { mapAnnotations() }
                        .mapStyle(mapStyle.mapStyle)
                        .ignoresSafeArea(edges: .bottom)
                        .onMapCameraChange(frequency: .onEnd) { context in
                            mapSpan = context.region.span
                            rebuildClusters()
                        }
                        .onTapGesture {
                            withAnimation { selectedCluster = nil; longPressMark = nil }
                        }
                        .overlay {
                            // UILongPressGestureRecognizer is the only reliable way to
                            // intercept long-press with a location on top of MapKit's
                            // own gesture recognizers (SwiftUI gestures get eaten by Map).
                            LongPressOverlay(minimumDuration: 0.6) { screenPoint in
                                handleLongPress(at: screenPoint, proxy: proxy)
                            }
                            .ignoresSafeArea(edges: .bottom)
                        }
                }

                // Location search overlay
                if showingLocationSearch {
                    locationSearchOverlay
                }

                // Bottom card — long-press create / single fragment / cluster
                VStack {
                    Spacer()
                    if let mark = longPressMark {
                        LongPressCreateCard(
                            mark: mark,
                            isResolving: isResolvingName,
                            onCreate: {
                                createRequest = MapCreateRequest(
                                    latitude: mark.coordinate.latitude,
                                    longitude: mark.coordinate.longitude,
                                    locationName: mark.resolvedName
                                )
                            },
                            onDismiss: { withAnimation { longPressMark = nil } }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 16).padding(.bottom, 24)
                    } else if let cluster = selectedCluster {
                        Group {
                            if cluster.isSingle, let fragment = cluster.fragments.first {
                                NavigationLink(destination: FragmentDetailView(fragment: fragment)) {
                                    MapPreviewCard(fragment: fragment)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button { showingClusterSheet = true } label: {
                                    ClusterPreviewCard(cluster: cluster)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 16).padding(.bottom, 24)
                        .id(cluster.id)
                        .gesture(DragGesture(minimumDistance: 20).onEnded { v in
                            if v.translation.height > 60 {
                                withAnimation(.spring(response: 0.3)) { selectedCluster = nil }
                            }
                        })
                    }
                }
            }
            .navigationTitle("地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showingLocationSearch.toggle()
                            if !showingLocationSearch {
                                locationSearchText = ""
                                locationSearchResults = []
                            }
                        }
                    } label: {
                        Image(systemName: showingLocationSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
                            .glassToolbarIcon(active: showingLocationSearch)
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Fly to random fragment
                    if !clusters.isEmpty {
                        Button { flyToRandom() } label: {
                            Image(systemName: "shuffle")
                                .glassToolbarIcon()
                        }
                        .buttonStyle(.plain)
                    }

                    // Map style cycle
                    Menu {
                        ForEach(MapStyleOption.allCases, id: \.self) { style in
                            Button {
                                withAnimation { mapStyle = style }
                            } label: {
                                Label(style.rawValue, systemImage: style.icon)
                            }
                        }
                    } label: {
                        Image(systemName: mapStyle.icon)
                            .glassToolbarIcon(active: mapStyle != .standard)
                    }
                    .buttonStyle(.plain)

                    // My location
                    Button {
                        withAnimation { position = .userLocation(fallback: .automatic) }
                    } label: {
                        Image(systemName: "location.fill")
                            .glassToolbarIcon()
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if cachedClusters.isEmpty && !fragments.filter({ $0.hasLocation }).isEmpty {
                    EmptyView()
                } else if fragments.filter({ $0.hasLocation }).isEmpty {
                    ContentUnavailableView(
                        "还没有位置信息",
                        systemImage: "map",
                        description: Text("记录碎片时添加地点，这里会显示你去过的地方")
                    )
                }
            }
            .onAppear { rebuildClusters() }
            .onChange(of: fragments) { _, _ in rebuildClusters() }
        }
        .sheet(isPresented: $showingClusterSheet) {
            if let cluster = selectedCluster { ClusterDetailSheet(cluster: cluster) }
        }
        .sheet(item: $createRequest) { req in
            FragmentEditView(
                preloadedLatitude: req.latitude,
                preloadedLongitude: req.longitude,
                preloadedLocationName: req.locationName,
                saveDraftOnCancel: false
            )
        }
    }

    // MARK: - Location search overlay

    private var locationSearchOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if isSearching {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                }
                TextField("搜索地点", text: $locationSearchText)
                    .submitLabel(.search)
                    .onSubmit { Task { await doLocationSearch() } }
                if !locationSearchText.isEmpty {
                    Button {
                        locationSearchText = ""
                        locationSearchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
                Button("取消") {
                    showingLocationSearch = false
                    locationSearchText = ""
                    locationSearchResults = []
                }
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            if !locationSearchResults.isEmpty {
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(locationSearchResults.enumerated()), id: \.offset) { index, item in
                            Button { selectLocationResult(item) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "未知地点")
                                        .font(.subheadline).foregroundStyle(.primary)
                                    if let addr = item.placemark.title, addr != item.name {
                                        Text(addr).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                            }
                            if index < locationSearchResults.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .task(id: locationSearchText) {
            guard !locationSearchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await doLocationSearch()
        }
    }
}

// MARK: - Long-press pin annotation

private struct LongPressPin: View {
    let isResolving: Bool
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 8, y: 2)
                if isResolving {
                    ProgressView().scaleEffect(0.6).tint(.white)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Triangle()
                .fill(Color.accentColor)
                .frame(width: 12, height: 7)
                .offset(y: -1)
        }
        .scaleEffect(appeared ? 1 : 0.1)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: appeared)
        .onAppear { appeared = true }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Long-press create card

private struct LongPressCreateCard: View {
    let mark: LongPressMark
    let isResolving: Bool
    let onCreate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isResolving ? "正在识别位置…" : (mark.resolvedName.isEmpty ? "未知地点" : mark.resolvedName))
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                let lat = String(format: "%.4f", mark.coordinate.latitude)
                let lon = String(format: "%.4f", mark.coordinate.longitude)
                Text("\(lat), \(lon)")
                    .font(.caption).foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Button(action: onCreate) {
                Label("在这里记录", systemImage: "plus")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.94))
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(7)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

// MARK: - Cluster pin

private struct ClusterPin: View {
    let cluster: FragmentCluster
    let isSelected: Bool

    var body: some View {
        if cluster.isSingle, let f = cluster.fragments.first {
            singlePin(fragment: f)
        } else {
            multiPin
        }
    }

    @ViewBuilder
    private func singlePin(fragment: Fragment) -> some View {
        ZStack {
            if let id = fragment.coverMediaID {
                MediaThumbnailView(identifier: id, size: CGSize(width: 100, height: 100))
                    .frame(width: isSelected ? 44 : 32, height: isSelected ? 44 : 32)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(isSelected ? Color(red: 0.780, green: 0.624, blue: 0.384) : .white, lineWidth: isSelected ? 3 : 2))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            } else {
                Circle()
                    .fill(isSelected ? Color(red: 0.780, green: 0.624, blue: 0.384) : Color(red: 0.780, green: 0.624, blue: 0.384).opacity(0.85))
                    .frame(width: isSelected ? 20 : 14, height: isSelected ? 20 : 14)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            }
        }
        .animation(.spring(response: 0.25), value: isSelected)
    }

    private var multiPin: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                ForEach(Array(cluster.fragments.prefix(3).enumerated()), id: \.offset) { i, f in
                    if let id = f.coverMediaID {
                        MediaThumbnailView(identifier: id, size: CGSize(width: 100, height: 100))
                            .frame(width: isSelected ? 38 : 30, height: isSelected ? 38 : 30)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: CGFloat(i) * (isSelected ? -6 : -5))
                            .zIndex(Double(3 - i))
                    } else {
                        Circle()
                            .fill(Color(red: 0.780, green: 0.624, blue: 0.384).opacity(0.8 - Double(i) * 0.15))
                            .frame(width: isSelected ? 38 : 30, height: isSelected ? 38 : 30)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: CGFloat(i) * (isSelected ? -6 : -5))
                            .zIndex(Double(3 - i))
                    }
                }
            }
            .padding(.trailing, 6)
            Text("\(cluster.fragments.count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color(red: 0.780, green: 0.624, blue: 0.384))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - Preview cards

private struct MapPreviewCard: View {
    let fragment: Fragment
    var body: some View {
        HStack(spacing: 12) {
            if let id = fragment.coverMediaID {
                MediaThumbnailView(identifier: id, size: CGSize(width: 160, height: 160))
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                if !fragment.content.isEmpty {
                    Text(fragment.content).font(.subheadline).foregroundStyle(.primary).lineLimit(2)
                }
                HStack(spacing: 4) {
                    if !fragment.locationName.isEmpty {
                        Image(systemName: "location.fill").font(.caption2).foregroundStyle(.secondary)
                        Text(fragment.locationName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Text("·").font(.caption).foregroundStyle(.tertiary)
                    }
                    Text(fragment.date.formatted(.relative(presentation: .named)))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }
}

private struct ClusterPreviewCard: View {
    let cluster: FragmentCluster
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                ForEach(Array(cluster.fragments.prefix(3).enumerated()), id: \.offset) { i, f in
                    if let id = f.coverMediaID {
                        MediaThumbnailView(identifier: id, size: CGSize(width: 120, height: 120))
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: CGFloat(i) * 8, y: CGFloat(i) * -4)
                            .zIndex(Double(3 - i))
                    }
                }
            }
            .frame(width: 64, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.displayName).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary).lineLimit(1)
                Text("\(cluster.fragments.count) 条碎片").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.up").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }
}

// MARK: - Cluster detail sheet

private struct ClusterDetailSheet: View {
    let cluster: FragmentCluster
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(cluster.fragments) { fragment in
                        NavigationLink(destination: FragmentDetailView(fragment: fragment)) {
                            FragmentCardView(fragment: fragment)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 16)
            }
            .navigationTitle(cluster.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Long-press overlay (UIKit bridge)
//
// Problem: Map's internal UIGestureRecognizers consume all touches.
// If an overlay UIView is hit-tested first, Map never gets pan/zoom events.
//
// Solution:
//   - hitTest returns nil → overlay is invisible to hit testing, Map gets
//     all touches normally (pan/zoom restored)
//   - UILongPressGestureRecognizer is added to the UIWindow (always in the
//     responder chain), so it still fires regardless of hit test result
//   - bounds check filters: only fire if the touch is within the map area
//   - cleanup in didMoveToWindow(window: nil) removes the window recognizer

private struct LongPressOverlay: UIViewRepresentable {
    var minimumDuration: TimeInterval = 0.6
    var onLongPress: (CGPoint) -> Void

    func makeUIView(context: Context) -> LongPressPassthroughView {
        let view = LongPressPassthroughView()
        view.minimumDuration = minimumDuration
        view.onLongPress = onLongPress
        return view
    }

    func updateUIView(_ uiView: LongPressPassthroughView, context: Context) {
        uiView.onLongPress = onLongPress
    }
}

final class LongPressPassthroughView: UIView {
    var minimumDuration: TimeInterval = 0.6
    var onLongPress: ((CGPoint) -> Void)?
    private weak var windowRecognizer: UILongPressGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    // Invisible to hit testing — Map receives all pan/zoom/tap touches
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

    // Register on window when added; clean up when removed
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            let r = UILongPressGestureRecognizer(target: self, action: #selector(handle(_:)))
            r.minimumPressDuration = minimumDuration
            r.cancelsTouchesInView = false
            window.addGestureRecognizer(r)
            windowRecognizer = r
        } else {
            if let r = windowRecognizer {
                r.view?.removeGestureRecognizer(r)
            }
            windowRecognizer = nil
        }
    }

    @objc private func handle(_ r: UILongPressGestureRecognizer) {
        guard r.state == .began, let window else { return }
        let windowPoint = r.location(in: window)
        // Convert to this view's coordinate space and check it's within the map area
        let localPoint = convert(windowPoint, from: window)
        guard bounds.contains(localPoint) else { return }
        onLongPress?(localPoint)
    }
}

import SwiftUI
import SwiftData
import MapKit

// MARK: - Cluster model

struct FragmentCluster: Identifiable {
    let id = UUID()
    var fragments: [Fragment]

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

private func makeClusters(_ fragments: [Fragment], threshold: Double = 0.012) -> [FragmentCluster] {
    var clusters: [FragmentCluster] = []
    for f in fragments {
        if let i = clusters.firstIndex(where: { c in
            abs(c.coordinate.latitude - f.latitude) < threshold &&
            abs(c.coordinate.longitude - f.longitude) < threshold
        }) {
            clusters[i].fragments.append(f)
        } else {
            clusters.append(FragmentCluster(fragments: [f]))
        }
    }
    return clusters
}

// MARK: - Map view

struct FragmentMapView: View {
    @Query private var fragments: [Fragment]
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCluster: FragmentCluster? = nil
    @State private var showingClusterSheet = false
    @State private var showingLocationSearch = false
    @State private var locationSearchText = ""
    @State private var locationSearchResults: [MKMapItem] = []

    var located: [Fragment] { fragments.filter { $0.hasLocation } }
    var clusters: [FragmentCluster] { makeClusters(located) }

    private func doLocationSearch() async {
        let query = locationSearchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        guard let response = try? await MKLocalSearch(request: request).start() else { return }
        locationSearchResults = Array(response.mapItems.prefix(6))
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

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    UserAnnotation()
                    ForEach(clusters) { cluster in
                        Annotation("", coordinate: cluster.coordinate) {
                            ClusterPin(cluster: cluster, isSelected: selectedCluster?.id == cluster.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        if selectedCluster?.id == cluster.id {
                                            selectedCluster = nil
                                        } else {
                                            selectedCluster = cluster
                                            position = .region(MKCoordinateRegion(
                                                center: cluster.coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                                            ))
                                        }
                                    }
                                }
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .onTapGesture { withAnimation { selectedCluster = nil } }

                // Location search overlay
                if showingLocationSearch {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("搜索地点", text: $locationSearchText)
                                .submitLabel(.search)
                                .onSubmit { Task { await doLocationSearch() } }
                            if !locationSearchText.isEmpty {
                                Button {
                                    locationSearchText = ""
                                    locationSearchResults = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Button("取消") {
                                showingLocationSearch = false
                                locationSearchText = ""
                                locationSearchResults = []
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if !locationSearchResults.isEmpty {
                            Divider()
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(locationSearchResults.enumerated()), id: \.offset) { index, item in
                                        Button { selectLocationResult(item) } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name ?? "未知地点")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                                if let addr = item.placemark.title, addr != item.name {
                                                    Text(addr)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
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

                // Bottom card — single fragment preview or cluster entry
                if let cluster = selectedCluster {
                    VStack {
                        Spacer()
                        if cluster.isSingle, let fragment = cluster.fragments.first {
                            NavigationLink(destination: FragmentDetailView(fragment: fragment)) {
                                MapPreviewCard(fragment: fragment)
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            Button {
                                showingClusterSheet = true
                            } label: {
                                ClusterPreviewCard(cluster: cluster)
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .id(cluster.id)
                }
            }
            .navigationTitle("地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                            .foregroundStyle(Color.accentColor)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            position = .userLocation(fallback: .automatic)
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .overlay {
                if located.isEmpty {
                    ContentUnavailableView(
                        "还没有位置信息",
                        systemImage: "map",
                        description: Text("记录碎片时添加地点，这里会显示你去过的地方")
                    )
                }
            }
        }
        .sheet(isPresented: $showingClusterSheet) {
            if let cluster = selectedCluster {
                ClusterDetailSheet(cluster: cluster)
            }
        }
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
                    .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .white, lineWidth: isSelected ? 3 : 2))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            } else {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.85))
                    .frame(width: isSelected ? 20 : 14, height: isSelected ? 20 : 14)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            }
        }
        .animation(.spring(response: 0.25), value: isSelected)
    }

    private var multiPin: some View {
        ZStack(alignment: .topTrailing) {
            // Stacked thumbnails
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
                            .fill(Color.accentColor.opacity(0.8 - Double(i) * 0.15))
                            .frame(width: isSelected ? 38 : 30, height: isSelected ? 38 : 30)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: CGFloat(i) * (isSelected ? -6 : -5))
                            .zIndex(Double(3 - i))
                    }
                }
            }
            .padding(.trailing, 6)

            // Count badge
            Text("\(cluster.fragments.count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.accentColor)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - Single fragment preview card

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
                    Text(fragment.content)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                HStack(spacing: 4) {
                    if !fragment.locationName.isEmpty {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                        Text(fragment.locationName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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

// MARK: - Cluster preview card (tap to expand)

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
                Text(cluster.displayName)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(cluster.fragments.count) 条碎片")
                    .font(.caption).foregroundStyle(.secondary)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle(cluster.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

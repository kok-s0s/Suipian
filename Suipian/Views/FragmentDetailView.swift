import SwiftUI
import SwiftData
import MapKit

struct FragmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let fragment: Fragment

    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var showingFullScreen = false
    @State private var fullScreenStartIndex = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Media carousel
                if !fragment.mediaIdentifiers.isEmpty {
                    TabView {
                        ForEach(Array(fragment.mediaIdentifiers.enumerated()), id: \.offset) { index, id in
                            MediaDetailView(identifier: id)
                                .onTapGesture {
                                    fullScreenStartIndex = index
                                    showingFullScreen = true
                                }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: fragment.mediaIdentifiers.count > 1 ? .always : .never))
                    .frame(height: 320)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Date & location
                    HStack(spacing: 12) {
                        Label(
                            fragment.date.formatted(date: .long, time: .shortened),
                            systemImage: "clock"
                        )
                        if fragment.hasLocation && !fragment.locationName.isEmpty {
                            Label(fragment.locationName, systemImage: "location.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Content
                    if !fragment.content.isEmpty {
                        Text(fragment.content)
                            .font(.body)
                            .lineSpacing(6)
                    }

                    // Tags
                    if !fragment.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(fragment.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Map
                    if fragment.hasLocation {
                        Map(initialPosition: .region(
                            MKCoordinateRegion(
                                center: CLLocationCoordinate2D(
                                    latitude: fragment.latitude,
                                    longitude: fragment.longitude
                                ),
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        )) {
                            Marker(
                                fragment.locationName.isEmpty ? "这里" : fragment.locationName,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: fragment.latitude,
                                    longitude: fragment.longitude
                                )
                            )
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showingEdit = true } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "删除后无法恢复",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除碎片", role: .destructive) {
                modelContext.delete(fragment)
                dismiss()
            }
        }
        .sheet(isPresented: $showingEdit) {
            FragmentEditView(fragment: fragment)
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            FullScreenMediaViewer(
                identifiers: fragment.mediaIdentifiers,
                startIndex: fullScreenStartIndex,
                coverIdentifier: fragment.coverIdentifier,
                onSetCover: { id in fragment.coverIdentifier = id }
            )
        }
    }
}

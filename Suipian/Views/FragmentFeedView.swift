import SwiftUI
import SwiftData

struct FragmentFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]

    @State private var selectedTag: String? = nil
    @State private var showingCreate = false

    var allTags: [String] {
        Array(Set(fragments.flatMap { $0.tags })).sorted()
    }

    var filteredFragments: [Fragment] {
        guard let tag = selectedTag else { return fragments }
        return fragments.filter { $0.tags.contains(tag) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Tag filter strip
                    if !allTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(label: "全部", isSelected: selectedTag == nil) {
                                    selectedTag = nil
                                }
                                ForEach(allTags, id: \.self) { tag in
                                    FilterChip(label: "#\(tag)", isSelected: selectedTag == tag) {
                                        selectedTag = selectedTag == tag ? nil : tag
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }

                    // Fragment cards
                    LazyVStack(spacing: 14) {
                        ForEach(filteredFragments) { fragment in
                            NavigationLink {
                                FragmentDetailView(fragment: fragment)
                            } label: {
                                FragmentCardView(fragment: fragment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle(selectedTag.map { "#\($0)" } ?? "碎片")
            .navigationBarTitleDisplayMode(.large)
            .overlay {
                if filteredFragments.isEmpty {
                    ContentUnavailableView(
                        selectedTag != nil ? "这个主题还没有碎片" : "还没有任何碎片",
                        systemImage: "square.on.square.dashed",
                        description: Text(selectedTag != nil ? "切换主题，或创建一个新碎片" : "点击右下角，记录第一个碎片")
                    )
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showingCreate) {
            FragmentEditView()
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
    }
}

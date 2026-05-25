import SwiftUI
import SwiftData

struct FragmentFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Fragment.date, order: .reverse) private var fragments: [Fragment]

    @State private var selectedTag: String? = nil
    @State private var showingCreate = false
    @State private var showingTagPicker = false

    // Tags sorted by frequency (most used first)
    var sortedTags: [(tag: String, count: Int)] {
        var freq: [String: Int] = [:]
        for fragment in fragments {
            for tag in fragment.tags { freq[tag, default: 0] += 1 }
        }
        return freq.sorted { $0.value > $1.value }.map { (tag: $0.key, count: $0.value) }
    }

    var filteredFragments: [Fragment] {
        guard let tag = selectedTag else { return fragments }
        return fragments.filter { $0.tags.contains(tag) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Compact filter bar — replaces the old horizontal scroll strip
                    if !sortedTags.isEmpty {
                        HStack(spacing: 10) {
                            if let tag = selectedTag {
                                HStack(spacing: 5) {
                                    Text("#\(tag)")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundStyle(Color.accentColor)
                                        .lineLimit(1)
                                    Button { selectedTag = nil } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.accentColor.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                            } else {
                                Text("全部 · \(fragments.count) 条碎片")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button { showingTagPicker = true } label: {
                                Image(systemName: selectedTag != nil
                                      ? "line.3.horizontal.decrease.circle.fill"
                                      : "line.3.horizontal.decrease.circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedTag != nil ? Color.accentColor : .secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
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
                Button { showingCreate = true } label: {
                    Image(systemName: "plus")
                        .font(.title2).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20).padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showingCreate) {
            FragmentEditView()
        }
        .sheet(isPresented: $showingTagPicker) {
            TagPickerSheet(sortedTags: sortedTags, selectedTag: $selectedTag)
        }
    }
}

// MARK: - Tag picker bottom sheet

private struct TagPickerSheet: View {
    let sortedTags: [(tag: String, count: Int)]
    @Binding var selectedTag: String?
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    // "全部" cell
                    tagCell(label: "全部", count: nil, isSelected: selectedTag == nil) {
                        selectedTag = nil
                        dismiss()
                    }
                    ForEach(sortedTags, id: \.tag) { item in
                        tagCell(label: "#\(item.tag)", count: item.count, isSelected: selectedTag == item.tag) {
                            selectedTag = item.tag
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("选择标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
                if selectedTag != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("清除筛选") { selectedTag = nil; dismiss() }
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func tagCell(label: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(label)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let count {
                    Text("\(count) 条")
                        .font(.caption2)
                        .opacity(0.75)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.08))
            .foregroundStyle(isSelected ? .white : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

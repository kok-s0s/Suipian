import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var fragments: [Fragment]

    @State private var tagToRename: String? = nil
    @State private var renameInput = ""
    @State private var tagToDelete: String? = nil
    @State private var showDeleteAlert = false
    @State private var searchText = ""

    private var sortedTags: [(tag: String, count: Int)] {
        var freq: [String: Int] = [:]
        for f in fragments {
            for t in f.tags { freq[t, default: 0] += 1 }
        }
        let all = freq.sorted { $0.value > $1.value }.map { (tag: $0.key, count: $0.value) }
        if searchText.isEmpty { return all }
        return all.filter { $0.tag.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if sortedTags.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "还没有标签" : "没有匹配的标签",
                    systemImage: "tag.slash"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(sortedTags, id: \.tag) { item in
                    HStack {
                        Text("#\(item.tag)")
                            .font(.body)
                        Spacer()
                        Text("\(item.count) 条")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            tagToDelete = item.tag
                            showDeleteAlert = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            tagToRename = item.tag
                            renameInput = item.tag
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("标签管理")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "搜索标签")
        .alert("重命名标签", isPresented: Binding(
            get: { tagToRename != nil },
            set: { if !$0 { tagToRename = nil } }
        )) {
            TextField("新标签名称", text: $renameInput)
                .autocorrectionDisabled()
            Button("确认") { commitRename() }
            Button("取消", role: .cancel) { tagToRename = nil }
        } message: {
            if let old = tagToRename {
                Text("将把所有碎片中的「#\(old)」替换为新名称")
            }
        }
        .alert("删除标签", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { commitDelete() }
            Button("取消", role: .cancel) { tagToDelete = nil }
        } message: {
            if let tag = tagToDelete {
                Text("将从所有碎片中移除「#\(tag)」，碎片本身不会被删除")
            }
        }
    }

    private func commitRename() {
        guard let old = tagToRename else { return }
        let new = renameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard !new.isEmpty, new != old else { tagToRename = nil; return }
        for fragment in fragments where fragment.tags.contains(old) {
            fragment.tags = fragment.tags.map { $0 == old ? new : $0 }
        }
        try? modelContext.save()
        HapticFeedback.success()
        tagToRename = nil
    }

    private func commitDelete() {
        guard let tag = tagToDelete else { return }
        for fragment in fragments where fragment.tags.contains(tag) {
            fragment.tags = fragment.tags.filter { $0 != tag }
        }
        try? modelContext.save()
        HapticFeedback.impact(.medium)
        tagToDelete = nil
    }
}

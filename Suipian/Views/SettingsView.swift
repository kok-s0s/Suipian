import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("backgroundStyle") private var backgroundStyle = 0
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var fragments: [Fragment]

    @State private var reminderTime = Date()
    @State private var showingPermissionAlert = false
    @State private var exportItem: ExportFile?
    @State private var showingImporter = false
    @State private var importResult: ImportResult?

    var body: some View {
        NavigationStack {
            List {
                // MARK: 外观
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("背景纹理")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("背景纹理", selection: $backgroundStyle) {
                            Text("无").tag(0)
                            Text("点阵").tag(1)
                            Text("斜纹").tag(2)
                            Text("方格").tag(3)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("外观", systemImage: "paintbrush.pointed")
                }

                // MARK: 安全
                Section {
                    Toggle(isOn: $appLockEnabled) {
                        Label("App 锁定", systemImage: "lock.shield")
                    }
                    .onChange(of: appLockEnabled) { _, on in
                        if on { HapticFeedback.impact(.light) }
                    }
                } header: {
                    Label("安全", systemImage: "lock")
                } footer: {
                    Text("开启后每次离开应用需要 Face ID / 密码才能继续")
                }

                // MARK: 通知
                Section {
                    Toggle(isOn: Binding(
                        get: { reminderEnabled },
                        set: { newValue in
                            if newValue {
                                Task { await requestAndEnable() }
                            } else {
                                reminderEnabled = false
                                UNUserNotificationCenter.current().removePendingNotificationRequests(
                                    withIdentifiers: ["daily-reminder"]
                                )
                            }
                        }
                    )) {
                        Label("每日记录提醒", systemImage: "bell.badge")
                    }

                    if reminderEnabled {
                        DatePicker(
                            "提醒时间",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderTime) { _, newTime in
                            let cal = Calendar.current
                            reminderHour = cal.component(.hour, from: newTime)
                            reminderMinute = cal.component(.minute, from: newTime)
                            scheduleNotification()
                        }
                    }
                } header: {
                    Label("通知", systemImage: "bell")
                } footer: {
                    Text(reminderEnabled
                         ? "每天 \(formattedTime) 提醒你记录今天的碎片"
                         : "开启后每天定时提醒，帮助养成记录习惯")
                }

                // MARK: 数据管理
                Section {
                    HStack {
                        Label("已记录碎片", systemImage: "square.on.square")
                        Spacer()
                        Text("\(fragments.count) 条")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Button {
                        exportJSON()
                    } label: {
                        Label("导出数据（JSON）", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingImporter = true
                    } label: {
                        Label("导入数据（JSON）", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Label("数据管理", systemImage: "externaldrive")
                } footer: {
                    Text("导出 / 导入包含文字、标签、情绪、地点等元数据，媒体文件不包含在内")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { loadReminderTime() }
            .alert("需要通知权限", isPresented: $showingPermissionAlert) {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("请在系统设置中允许碎片发送通知。")
            }
            .sheet(item: $exportItem) { file in
                ShareSheet(items: [file.url])
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleImport(result: result) }
            }
            .alert(item: $importResult) { r in
                Alert(
                    title: Text(r.success ? "导入成功" : "导入失败"),
                    message: Text(r.message),
                    dismissButton: .default(Text("好"))
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Data model (encode + decode)

    private struct FragmentRecord: Codable {
        let date: String
        let content: String
        let tags: [String]
        let mood: String
        let storyName: String
        let locationName: String
        let latitude: Double
        let longitude: Double
        let isPrivate: Bool
        let isPinned: Bool
        let mediaCount: Int
    }

    // MARK: - Export

    private func exportJSON() {
        HapticFeedback.impact(.light)
        let fmt = ISO8601DateFormatter()
        let records = fragments.map { f in
            FragmentRecord(
                date: fmt.string(from: f.date),
                content: f.content,
                tags: f.tags,
                mood: f.mood,
                storyName: f.storyName,
                locationName: f.locationName,
                latitude: f.latitude,
                longitude: f.longitude,
                isPrivate: f.isPrivate,
                isPinned: f.isPinned,
                mediaCount: f.mediaIdentifiers.count
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("suipian-export-\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
        exportItem = ExportFile(url: url)
    }

    // MARK: - Import

    private func handleImport(result: Result<[URL], Error>) async {
        switch result {
        case .failure:
            importResult = ImportResult(success: false, message: "无法读取文件，请选择碎片导出的 JSON 文件。")
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importResult = ImportResult(success: false, message: "无法访问所选文件。")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            guard let data = try? Data(contentsOf: url),
                  let records = try? JSONDecoder().decode([FragmentRecord].self, from: data) else {
                importResult = ImportResult(success: false, message: "JSON 格式不匹配，请使用碎片导出的文件。")
                return
            }

            let fmt = ISO8601DateFormatter()
            for record in records {
                let fragment = Fragment(
                    content: record.content,
                    date: fmt.date(from: record.date) ?? Date(),
                    tags: record.tags,
                    latitude: record.latitude,
                    longitude: record.longitude,
                    locationName: record.locationName
                )
                fragment.mood = record.mood
                fragment.storyName = record.storyName
                fragment.isPrivate = record.isPrivate
                fragment.isPinned = record.isPinned
                modelContext.insert(fragment)
            }

            try? modelContext.save()
            HapticFeedback.success()
            importResult = ImportResult(success: true, message: "成功导入 \(records.count) 条碎片。")
        }
    }

    // MARK: - Notification helpers

    private var formattedTime: String {
        String(format: "%02d:%02d", reminderHour, reminderMinute)
    }

    private func loadReminderTime() {
        var comps = DateComponents()
        comps.hour = reminderHour
        comps.minute = reminderMinute
        reminderTime = Calendar.current.date(from: comps) ?? Date()
    }

    private func requestAndEnable() async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted { reminderEnabled = true; scheduleNotification() }
        } else if status == .authorized || status == .provisional {
            reminderEnabled = true; scheduleNotification()
        } else {
            showingPermissionAlert = true
        }
    }

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
        let content = UNMutableNotificationContent()
        content.title = "今天记录了吗？"
        content.body = "打开碎片，把今天的瞬间留下来。"
        content.sound = .default
        var comps = DateComponents()
        comps.hour = reminderHour; comps.minute = reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "daily-reminder", content: content, trigger: trigger))
    }
}

// MARK: - Helpers

private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ImportResult: Identifiable {
    let id = UUID()
    let success: Bool
    let message: String
}

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("backgroundStyle") private var backgroundStyle = 0
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @Environment(\.dismiss) private var dismiss
    @Query private var fragments: [Fragment]

    @State private var reminderTime = Date()
    @State private var showingPermissionAlert = false
    @State private var exportItem: ExportFile?

    var body: some View {
        NavigationStack {
            List {
                // MARK: 外观
                Section("外观") {
                    Picker("背景纹理", selection: $backgroundStyle) {
                        Text("无").tag(0)
                        Text("点阵").tag(1)
                        Text("斜纹").tag(2)
                        Text("方格").tag(3)
                    }
                    .pickerStyle(.segmented)
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
                    Text("安全")
                } footer: {
                    Text("开启后，每次离开应用需要 Face ID / 密码才能继续。")
                }

                // MARK: 提醒
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
                } footer: {
                    if reminderEnabled {
                        Text("每天 \(formattedTime) 提醒你记录今天的碎片")
                    } else {
                        Text("开启后每天定时提醒你记录碎片，帮助养成习惯")
                    }
                }

                // MARK: 数据
                Section {
                    Button {
                        exportJSON()
                    } label: {
                        Label("导出所有碎片（JSON）", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("数据")
                } footer: {
                    Text("导出包含文字、标签、情绪、地点等元数据。媒体文件不包含在导出内。")
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Export

    private struct FragmentExportRecord: Encodable {
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

    private func exportJSON() {
        HapticFeedback.impact(.light)
        let fmt = ISO8601DateFormatter()
        let records = fragments.map { f in
            FragmentExportRecord(
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


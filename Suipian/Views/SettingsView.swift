import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @Environment(\.dismiss) private var dismiss

    @State private var reminderTime = Date()
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationStack {
            List {
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
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { loadReminderTime() }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("导出图标") { Task { await exportAppIcon() } }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #endif
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

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
            if granted {
                reminderEnabled = true
                scheduleNotification()
            }
        } else if status == .authorized || status == .provisional {
            reminderEnabled = true
            scheduleNotification()
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
        comps.hour = reminderHour
        comps.minute = reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-reminder", content: content, trigger: trigger)
        center.add(request)
    }
}

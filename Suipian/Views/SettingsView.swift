import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers
import CloudKit
import CoreData

struct SettingsView: View {
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("backgroundStyle") private var backgroundStyle = 0
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudKitSyncMonitor.self) private var syncMonitor
    @Query private var fragments: [Fragment]
    @Query private var importantDates: [ImportantDate]

    @State private var reminderTime = Date()
    @State private var showingPermissionAlert = false
    @State private var exportItem: ExportFile?
    @State private var showingImporter = false
    @State private var importResult: ImportResult?
    @State private var iCloudAccountStatus: CKAccountStatus = .couldNotDetermine

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - App header
                    VStack(spacing: 10) {
                        Image(systemName: "square.on.square.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 80, height: 80)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)

                        Text("碎片")
                            .font(.title2).fontWeight(.bold)
                        Text("版本 \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // MARK: - 外观
                    SettingsCard(title: "外观", icon: "paintbrush.pointed", iconColor: .purple) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("背景纹理")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 10) {
                                ForEach([
                                    (0, "无",   "square"),
                                    (1, "点阵", "circle.grid.3x3"),
                                    (2, "斜纹", "line.diagonal"),
                                    (3, "方格", "squareshape.split.2x2"),
                                ], id: \.0) { tag, label, icon in
                                    Button { backgroundStyle = tag } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: icon)
                                                .font(.system(size: 20))
                                                .foregroundStyle(backgroundStyle == tag ? .white : .secondary)
                                                .frame(width: 48, height: 48)
                                                .background(
                                                    backgroundStyle == tag
                                                        ? Color.accentColor
                                                        : Color.primary.opacity(0.06),
                                                    in: RoundedRectangle(cornerRadius: 12)
                                                )
                                            Text(label)
                                                .font(.caption2)
                                                .foregroundStyle(backgroundStyle == tag ? Color.accentColor : .secondary)
                                        }
                                    }
                                    .buttonStyle(PressScaleButtonStyle(scale: 0.93))
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }

                    // MARK: - 安全 & 通知
                    SettingsCard(title: "安全", icon: "lock.shield", iconColor: .blue) {
                        SettingsToggleRow(
                            icon: "faceid",
                            label: "App 锁定",
                            sublabel: "切出应用需 Face ID 验证",
                            isOn: $appLockEnabled
                        )
                        .onChange(of: appLockEnabled) { _, on in
                            if on { HapticFeedback.impact(.light) }
                        }
                    }

                    SettingsCard(title: "通知", icon: "bell.badge", iconColor: .orange) {
                        SettingsToggleRow(
                            icon: "bell.fill",
                            label: "每日记录提醒",
                            sublabel: reminderEnabled ? "每天 \(formattedTime) 提醒" : "帮助养成记录习惯",
                            isOn: Binding(
                                get: { reminderEnabled },
                                set: { newValue in
                                    if newValue { Task { await requestAndEnable() } }
                                    else {
                                        reminderEnabled = false
                                        UNUserNotificationCenter.current()
                                            .removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
                                    }
                                }
                            )
                        )
                        if reminderEnabled {
                            Divider().padding(.leading, 48)
                            DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .padding(.leading, 48)
                                .onChange(of: reminderTime) { _, newTime in
                                    let cal = Calendar.current
                                    let h = cal.component(.hour, from: newTime)
                                    let m = cal.component(.minute, from: newTime)
                                    guard h != reminderHour || m != reminderMinute else { return }
                                    reminderHour = h; reminderMinute = m
                                    scheduleNotification()
                                }
                        }
                    }

                    // MARK: - iCloud 同步
                    SettingsCard(title: "iCloud 同步", icon: "icloud", iconColor: .cyan) {
                        iCloudStatusRow
                    }

                    SettingsCard(title: "数据与隐私", icon: "hand.raised", iconColor: .green) {
                        SettingsPrivacyRow(
                            icon: "lock.square",
                            title: "私密碎片",
                            detail: "不会写入主屏幕小组件，也不会出现在 Spotlight 搜索结果中"
                        )
                        Divider().padding(.leading, 48)
                        SettingsPrivacyRow(
                            icon: "rectangle.on.rectangle",
                            title: "桌面小组件",
                            detail: "只读取 App Group 中的公开碎片摘要和重要日期倒计时数据"
                        )
                        Divider().padding(.leading, 48)
                        SettingsPrivacyRow(
                            icon: "square.and.arrow.up",
                            title: "导出数据",
                            detail: "JSON 导出只包含文字、标签、情绪、地点等元数据，不包含照片和视频"
                        )
                    }

                    // MARK: - 数据管理
                    SettingsCard(title: "数据管理", icon: "externaldrive", iconColor: Color(red: 0.780, green: 0.624, blue: 0.384)) {
                        SettingsInfoRow(icon: "square.on.square", label: "已记录碎片",
                                        value: "\(fragments.count) 条")
                        Divider().padding(.leading, 48)
                        NavigationLink { TagManagementView() } label: {
                            SettingsLinkRow(icon: "tag", label: "标签管理")
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 48)
                        Button { exportJSON() } label: {
                            SettingsLinkRow(icon: "square.and.arrow.up", label: "导出数据（JSON）")
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 48)
                        Button { showingImporter = true } label: {
                            SettingsLinkRow(icon: "square.and.arrow.down", label: "导入数据（JSON）")
                        }
                        .buttonStyle(.plain)

                        Text("导出 / 导入包含碎片元数据和重要日期，媒体文件不包含在内")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background { AppBackgroundCanvas().ignoresSafeArea() }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .onAppear {
                loadReminderTime()
                Task { await refreshICloudAccountStatus() }
            }
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
            .sheet(item: $exportItem) { file in ShareSheet(items: [file.url]) }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false) { result in
                Task { await handleImport(result: result) }
            }
            .alert(item: $importResult) { r in
                Alert(title: Text(r.success ? "导入成功" : "导入失败"),
                      message: Text(r.message),
                      dismissButton: .default(Text("好")))
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - iCloud status row

    @ViewBuilder
    private var iCloudStatusRow: some View {
        if iCloudAccountStatus == .noAccount || iCloudAccountStatus == .restricted
            || iCloudAccountStatus == .temporarilyUnavailable {
            HStack(spacing: 14) {
                Image(systemName: accountStatusIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountStatusTitle).font(.subheadline)
                    Text(accountStatusDetail).font(.caption).foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(spacing: 14) {
                Group {
                    switch syncMonitor.state {
                    case .syncing:
                        ProgressView().scaleEffect(0.8).tint(.blue)
                    case .succeeded:
                        Image(systemName: "checkmark.icloud.fill").foregroundStyle(.blue)
                    case .failed:
                        Image(systemName: "exclamationmark.icloud.fill").foregroundStyle(.orange)
                    case .idle:
                        Image(systemName: "icloud").foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 20))
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(syncStateTitle).font(.subheadline)
                    if let date = syncMonitor.lastSyncDate {
                        Text("上次同步：\(date.relativeDescription)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        Text("文字、标签、情绪、位置、音频均通过 iCloud 同步。照片由 iCloud 照片库负责。")
            .font(.caption).foregroundStyle(.tertiary).padding(.top, 4)
    }

    private var syncStateTitle: String {
        switch syncMonitor.state {
        case .syncing:   return "正在同步…"
        case .succeeded: return "已同步"
        case .failed:    return "同步遇到问题"
        case .idle:      return "同步已开启"
        }
    }

    private var accountStatusIcon: String {
        switch iCloudAccountStatus {
        case .noAccount: return "icloud.slash"
        case .restricted: return "lock.icloud"
        default: return "exclamationmark.icloud"
        }
    }

    private var accountStatusTitle: String {
        switch iCloudAccountStatus {
        case .noAccount: return "未登录 Apple ID"
        case .restricted: return "iCloud 访问受限"
        default: return "暂时无法连接 iCloud"
        }
    }

    private var accountStatusDetail: String {
        switch iCloudAccountStatus {
        case .noAccount: return "前往「设置」→「登录 iPhone」以开启同步"
        case .restricted: return "家长控制或设备管理策略限制了 iCloud 使用"
        default: return "请检查网络连接，稍后自动重试"
        }
    }

    private func refreshICloudAccountStatus() async {
        do { iCloudAccountStatus = try await CKContainer.default().accountStatus() }
        catch { iCloudAccountStatus = .couldNotDetermine }
    }

    // MARK: - Data model

    private struct FragmentRecord: Codable {
        let date: String; let content: String; let tags: [String]; let mood: String
        let storyName: String; let locationName: String
        let latitude: Double; let longitude: Double
        let isPrivate: Bool; let isPinned: Bool; let mediaCount: Int
    }

    private struct ImportantDateRecord: Codable {
        let title: String
        let date: String
        let emoji: String
        let category: String
        let note: String
        let isRecurring: Bool
        let notificationEnabled: Bool
        let advanceReminderDays: Int
        let autoRecordFragment: Bool?
    }

    private struct ExportPayload: Codable {
        let fragments: [FragmentRecord]
        let importantDates: [ImportantDateRecord]
    }

    private func exportJSON() {
        HapticFeedback.impact(.light)
        let fmt = ISO8601DateFormatter()
        let fragmentRecords = fragments.map {
            FragmentRecord(date: fmt.string(from: $0.date), content: $0.content, tags: $0.tags,
                           mood: $0.mood, storyName: $0.storyName, locationName: $0.locationName,
                           latitude: $0.latitude, longitude: $0.longitude,
                           isPrivate: $0.isPrivate, isPinned: $0.isPinned,
                           mediaCount: $0.mediaIdentifiers.count)
        }
        let dateRecords = importantDates.map {
            ImportantDateRecord(title: $0.title,
                                date: fmt.string(from: $0.date),
                                emoji: $0.emoji,
                                category: $0.category,
                                note: $0.note,
                                isRecurring: $0.isRecurring,
                                notificationEnabled: $0.notificationEnabled,
                                advanceReminderDays: $0.advanceReminderDays,
                                autoRecordFragment: $0.autoRecordFragment)
        }
        let payload = ExportPayload(fragments: fragmentRecords, importantDates: dateRecords)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("suipian-export-\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
        exportItem = ExportFile(url: url)
    }

    private func handleImport(result: Result<[URL], Error>) async {
        switch result {
        case .failure:
            importResult = ImportResult(success: false, message: "无法读取文件，请选择碎片导出的 JSON 文件。")
        case .success(let urls):
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else {
                importResult = ImportResult(success: false, message: "无法访问所选文件。"); return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else {
                importResult = ImportResult(success: false, message: "JSON 格式不匹配，请使用碎片导出的文件。"); return
            }
            let decoder = JSONDecoder()
            let payload: ExportPayload
            if let decoded = try? decoder.decode(ExportPayload.self, from: data) {
                payload = decoded
            } else if let oldRecords = try? decoder.decode([FragmentRecord].self, from: data) {
                payload = ExportPayload(fragments: oldRecords, importantDates: [])
            } else {
                importResult = ImportResult(success: false, message: "JSON 格式不匹配，请使用碎片导出的文件。"); return
            }
            let fmt = ISO8601DateFormatter()
            let existingSet = Set(fragments.map { "\(Int($0.date.timeIntervalSinceReferenceDate))|\($0.content)" })
            var inserted = 0, skipped = 0
            var insertedFragments: [Fragment] = []
            for r in payload.fragments {
                let date = fmt.date(from: r.date) ?? Date()
                let key = "\(Int(date.timeIntervalSinceReferenceDate))|\(r.content)"
                if existingSet.contains(key) { skipped += 1; continue }
                let f = Fragment(content: r.content, date: date, tags: r.tags,
                                 latitude: r.latitude, longitude: r.longitude, locationName: r.locationName)
                f.mood = r.mood; f.storyName = r.storyName; f.isPrivate = r.isPrivate; f.isPinned = r.isPinned
                modelContext.insert(f)
                SpotlightManager.index(f)
                insertedFragments.append(f)
                inserted += 1
            }

            var existingDateSet = Set(importantDates.map { "\($0.title)|\(Int($0.date.timeIntervalSinceReferenceDate))" })
            var insertedDateItems: [ImportantDate] = []
            var insertedDates = 0, skippedDates = 0
            for r in payload.importantDates {
                let date = fmt.date(from: r.date) ?? Date()
                let key = "\(r.title)|\(Int(date.timeIntervalSinceReferenceDate))"
                if existingDateSet.contains(key) { skippedDates += 1; continue }
                existingDateSet.insert(key)
                let item = ImportantDate(title: r.title,
                                         date: date,
                                         emoji: r.emoji,
                                         category: r.category,
                                         note: r.note,
                                         isRecurring: r.isRecurring,
                                         notificationEnabled: r.notificationEnabled,
                                         advanceReminderDays: r.advanceReminderDays,
                                         autoRecordFragment: r.autoRecordFragment ?? true)
                modelContext.insert(item)
                insertedDateItems.append(item)
                insertedDates += 1
            }
            try? modelContext.save()
            WidgetDataStore.rebuildFragmentWidgets(insertedFragments + fragments)
            let allDates = importantDates + insertedDateItems
            WidgetDataStore.updateImportantDates(allDates)
            ImportantDateNotifier.rescheduleAll(allDates)
            HapticFeedback.success()
            importResult = ImportResult(success: true,
                message: importSummary(inserted: inserted, skipped: skipped,
                                       insertedDates: insertedDates, skippedDates: skippedDates))
        }
    }

    private func importSummary(inserted: Int, skipped: Int, insertedDates: Int, skippedDates: Int) -> String {
        var parts = ["导入 \(inserted) 条碎片"]
        if insertedDates > 0 || skippedDates > 0 {
            parts.append("\(insertedDates) 个重要日期")
        }
        let skippedTotal = skipped + skippedDates
        if skippedTotal > 0 {
            parts.append("跳过 \(skippedTotal) 条重复")
        }
        return parts.joined(separator: "，")
    }

    private var formattedTime: String { String(format: "%02d:%02d", reminderHour, reminderMinute) }

    private func loadReminderTime() {
        var c = DateComponents(); c.hour = reminderHour; c.minute = reminderMinute
        reminderTime = Calendar.current.date(from: c) ?? Date()
    }

    private func requestAndEnable() async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted { reminderEnabled = true; scheduleNotification() }
        } else if status == .authorized || status == .provisional {
            reminderEnabled = true; scheduleNotification()
        } else { showingPermissionAlert = true }
    }

    private func scheduleNotification() {
        NotificationScheduler.schedule(hour: reminderHour, minute: reminderMinute, fragments: fragments)
    }
}

// MARK: - Reusable card container

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

// MARK: - Row components

private struct SettingsToggleRow: View {
    let icon: String
    let label: String
    let sublabel: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.subheadline)
                Text(sublabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
    }
}

private struct SettingsInfoRow: View {
    let icon: String; let label: String; let value: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 28)
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}

private struct SettingsLinkRow: View {
    let icon: String; let label: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 28)
            Text(label).font(.subheadline).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }
}

private struct SettingsPrivacyRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Helpers

private extension Date {
    var relativeDescription: String {
        let diff = Int(Date().timeIntervalSince(self))
        if diff < 60  { return "刚刚" }
        if diff < 3600 { return "\(diff / 60) 分钟前" }
        if diff < 86400 { return "\(diff / 3600) 小时前" }
        return "\(diff / 86400) 天前"
    }
}

private struct ExportFile: Identifiable { let id = UUID(); let url: URL }
private struct ImportResult: Identifiable { let id = UUID(); let success: Bool; let message: String }

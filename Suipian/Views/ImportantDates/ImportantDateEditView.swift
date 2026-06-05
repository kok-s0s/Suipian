import SwiftUI
import SwiftData

struct ImportantDateEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allDates: [ImportantDate]

    var item: ImportantDate? = nil

    @State private var title = ""
    @State private var date = Date()
    @State private var emoji = "🗓"
    @State private var category = "纪念日"
    @State private var note = ""
    @State private var isRecurring = true
    @State private var notificationEnabled = true
    @State private var advanceReminderDays = 0
    @State private var autoRecordFragment = true
    @State private var showingEmojiPicker = false
    @State private var showingPermissionAlert = false

    var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Emoji + Title
                    HStack(spacing: 14) {
                        Button { showingEmojiPicker = true } label: {
                            Text(emoji)
                                .font(.system(size: 32))
                                .frame(width: 64, height: 64)
                                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.93))

                        TextField("日期名称，如「妈妈生日」", text: $title)
                            .font(.title3).fontWeight(.medium)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Category picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("类别").font(.caption).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ImportantDate.categories, id: \.self) { cat in
                                    Button { category = cat } label: {
                                        Text(cat)
                                            .font(.subheadline)
                                            .padding(.horizontal, 14).padding(.vertical, 7)
                                            .background(
                                                category == cat ? Color.accentColor : Color.accentColor.opacity(0.08),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(category == cat ? .white : Color.accentColor)
                                    }
                                    .buttonStyle(PressScaleButtonStyle(scale: 0.93))
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Date + Recurring
                    VStack(spacing: 12) {
                        DatePicker("日期", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Color.accentColor)

                        Divider()

                        Toggle(isOn: $isRecurring) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("每年重复")
                                    .font(.subheadline)
                                Text("适合生日、纪念日等每年循环的日期")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Notification
                    VStack(spacing: 0) {
                        Toggle(isOn: $notificationEnabled) {
                            HStack(spacing: 10) {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(notificationEnabled ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("重要日期提醒")
                                        .font(.subheadline)
                                    Text(notificationDescription)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(16)

                        if notificationEnabled {
                            Divider().padding(.leading, 58)
                            Stepper(value: $advanceReminderDays, in: 0...30) {
                                HStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .foregroundStyle(Color.accentColor)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("提前提醒")
                                            .font(.subheadline)
                                        Text(advanceReminderDays == 0 ? "不提前，只在当天提醒" : "提前 \(advanceReminderDays) 天上午 9 点提醒")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 0) {
                        Toggle(isOn: $autoRecordFragment) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.pencil")
                                    .foregroundStyle(autoRecordFragment ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("当天自动记录碎片")
                                        .font(.subheadline)
                                    Text("到当天时自动生成一条纪念碎片，可避免忘记记录")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注").font(.caption).foregroundStyle(.secondary)
                        TextField("添加备注（选填）", text: $note, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(3...6)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    if isEditing {
                        Button(role: .destructive) {
                            if let it = item {
                                ImportantDateNotifier.remove(it)
                                modelContext.delete(it)
                                WidgetDataStore.updateImportantDates(allDates.filter { $0 !== it })
                            }
                            dismiss()
                        } label: {
                            Label("删除此日期", systemImage: "trash")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background { AppBackgroundCanvas().ignoresSafeArea() }
            .navigationTitle(isEditing ? "编辑日期" : "新增重要日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadExisting() }
        }
        .presentationDragIndicator(.visible)
        .alert("选择 Emoji", isPresented: $showingEmojiPicker) {
            TextField("输入 emoji", text: $emoji)
            Button("确认") {}
            Button("取消", role: .cancel) {}
        } message: {
            Text("输入一个 emoji 作为日期图标")
        }
        .alert("需要通知权限", isPresented: $showingPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在系统设置中允许碎片发送通知，重要日期提醒才会生效。")
        }
    }

    private func loadExisting() {
        guard let it = item else { return }
        title = it.title; date = it.date; emoji = it.emoji
        category = it.category; note = it.note
        isRecurring = it.isRecurring; notificationEnabled = it.notificationEnabled
        advanceReminderDays = it.advanceReminderDays
        autoRecordFragment = it.autoRecordFragment
    }

    @MainActor
    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if notificationEnabled {
            let authorized = await ImportantDateNotifier.requestAuthorizationIfNeeded()
            guard authorized else {
                showingPermissionAlert = true
                return
            }
        }
        if let it = item {
            it.title = trimmed; it.date = date; it.emoji = emoji
            it.category = category; it.note = note
            it.isRecurring = isRecurring; it.notificationEnabled = notificationEnabled
            it.advanceReminderDays = advanceReminderDays
            it.autoRecordFragment = autoRecordFragment
            ImportantDateNotifier.remove(it)
            if notificationEnabled { ImportantDateNotifier.schedule(it) }
            WidgetDataStore.updateImportantDates(allDates)
        } else {
            let newItem = ImportantDate(title: trimmed, date: date, emoji: emoji,
                                        category: category, note: note,
                                        isRecurring: isRecurring, notificationEnabled: notificationEnabled,
                                        advanceReminderDays: advanceReminderDays,
                                        autoRecordFragment: autoRecordFragment)
            modelContext.insert(newItem)
            if notificationEnabled { ImportantDateNotifier.schedule(newItem) }
            WidgetDataStore.updateImportantDates(allDates + [newItem])
        }
        HapticFeedback.success()
        dismiss()
    }

    private var notificationDescription: String {
        advanceReminderDays == 0
            ? "当天上午 9 点通知"
            : "提前 \(advanceReminderDays) 天和当天上午 9 点通知"
    }
}

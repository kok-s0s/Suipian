import SwiftUI
import SwiftData

// MARK: - Tab-level view for Important Dates

struct ImportantDatesTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dates: [ImportantDate]
    @State private var showingAdd = false
    @State private var dateToEdit: ImportantDate? = nil

    private var sorted: [ImportantDate] {
        dates.sorted { $0.daysUntil < $1.daysUntil }
    }

    private var todayItems: [ImportantDate] { sorted.filter { $0.isToday } }
    private var upcomingItems: [ImportantDate] { sorted.filter { !$0.isToday && $0.daysUntil >= 0 } }
    private var pastItems: [ImportantDate] { sorted.filter { $0.isPast } }
    private var nextItem: ImportantDate? { todayItems.first ?? upcomingItems.first }
    private var soonCount: Int { dates.filter { $0.daysUntil >= 0 && $0.daysUntil <= 30 }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if dates.isEmpty {
                        emptyState
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 14) {
                                    DateDashboardCard(nextItem: nextItem,
                                                      totalCount: dates.count,
                                                      todayCount: todayItems.count,
                                                      soonCount: soonCount)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)

                                    DateJumpStrip(
                                        todayCount: todayItems.count,
                                        upcomingCount: upcomingItems.count,
                                        pastCount: pastItems.count,
                                        onAdd: { showingAdd = true }
                                    ) { target in
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            proxy.scrollTo(target, anchor: .top)
                                        }
                                    }
                                    .padding(.horizontal, 16)

                                    if !todayItems.isEmpty {
                                        sectionHeader("🎉 今天", id: "date_today")
                                        ForEach(todayItems) { item in
                                            ImportantDateCard(item: item)
                                                .onTapGesture { dateToEdit = item }
                                                .padding(.horizontal, 16)
                                                .padding(.bottom, 10)
                                        }
                                    }

                                    if !upcomingItems.isEmpty {
                                        sectionHeader("即将到来", id: "date_upcoming")
                                        ForEach(upcomingItems) { item in
                                            ImportantDateCard(item: item)
                                                .onTapGesture { dateToEdit = item }
                                                .padding(.horizontal, 16)
                                                .padding(.bottom, 10)
                                        }
                                    }

                                    if !pastItems.isEmpty {
                                        sectionHeader("已过", id: "date_past")
                                        ForEach(pastItems) { item in
                                            ImportantDateCard(item: item, muted: true)
                                                .onTapGesture { dateToEdit = item }
                                                .padding(.horizontal, 16)
                                                .padding(.bottom, 10)
                                        }
                                    }
                                }
                                .padding(.bottom, 100)
                            }
                        }
                        .background { AppBackgroundCanvas().ignoresSafeArea() }
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .sheet(isPresented: $showingAdd) {
            ImportantDateEditView()
        }
        .sheet(item: $dateToEdit) { item in
            ImportantDateEditView(item: item)
        }
        .onAppear {
            WidgetDataStore.updateImportantDates(dates)
            ImportantDateNotifier.rescheduleAll(dates)
        }
        .onChange(of: dates) { _, newDates in
            WidgetDataStore.updateImportantDates(newDates)
            ImportantDateNotifier.rescheduleAll(newDates)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, id: String) -> some View {
        Text(title)
            .font(.caption).fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .id(id)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                Text("还没有重要日期")
                    .font(.title3).fontWeight(.semibold)
                Text("生日、纪念日、重要目标\n都可以在这里设定倒计时")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button { showingAdd = true } label: {
                Label("添加第一个日期", systemImage: "plus")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DateJumpStrip: View {
    let todayCount: Int
    let upcomingCount: Int
    let pastCount: Int
    let onAdd: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TabActionMetricCard(
                    title: "今天",
                    subtitle: "\(todayCount)",
                    icon: "sparkles",
                    tint: AnimePalette.sakura,
                    onTap: { onSelect("date_today") }
                )
                TabActionMetricCard(
                    title: "即将",
                    subtitle: "\(upcomingCount)",
                    icon: "hourglass",
                    tint: AnimePalette.star,
                    onTap: { onSelect("date_upcoming") }
                )
                TabActionMetricCard(
                    title: "已过",
                    subtitle: "\(pastCount)",
                    icon: "clock.arrow.circlepath",
                    tint: AnimePalette.violet,
                    onTap: { onSelect("date_past") }
                )
            }

            TabActionMetricCard(
                title: "添加日期",
                subtitle: "生日、纪念日、目标日都可以",
                icon: "plus",
                tint: AnimePalette.primary,
                onTap: onAdd
            )
        }
    }
}

// MARK: - Card

private struct DateDashboardCard: View {
    let nextItem: ImportantDate?
    let totalCount: Int
    let todayCount: Int
    let soonCount: Int

    private var accent: Color {
        if nextItem?.isToday == true { return AnimePalette.sakura }
        return AnimePalette.primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("日期")
                        .font(.title2).fontWeight(.bold)
                    Text("把值得提前期待的日子放在眼前")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 40, height: 40)
                    .background(accent.opacity(0.13), in: Circle())
            }

            if let item = nextItem {
                HStack(alignment: .center, spacing: 14) {
                    Text(item.emoji)
                        .font(.system(size: 34))
                        .frame(width: 54, height: 54)
                        .background(accent.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.isToday ? "今天是 \(item.title)" : item.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(item.category + " · " + monthDayLabel(item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 0) {
                        if item.isToday {
                            Text("今天")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(accent)
                        } else {
                            Text("\(item.daysUntil)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(accent)
                                .monospacedDigit()
                            Text("天后")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 10) {
                TabSummaryMetricCard(title: "全部", value: "\(totalCount)", icon: "calendar", tint: AnimePalette.primary)
                TabSummaryMetricCard(title: "今天", value: "\(todayCount)", icon: "sparkles", tint: AnimePalette.sakura)
                TabSummaryMetricCard(title: "30天内", value: "\(soonCount)", icon: "hourglass", tint: AnimePalette.star)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func monthDayLabel(_ item: ImportantDate) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        return fmt.string(from: item.date)
    }
}

private struct ImportantDateCard: View {
    let item: ImportantDate
    var muted: Bool = false

    private var accent: Color {
        item.isToday ? AnimePalette.sakura : AnimePalette.primary
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: emoji + countdown ring
            ZStack {
                Circle()
                    .stroke(accent.opacity(muted ? 0.08 : 0.15), lineWidth: 3)
                    .frame(width: 56, height: 56)
                if !item.isPast {
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(accent.opacity(muted ? 0.25 : 0.6),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 56, height: 56)
                }
                Text(item.emoji)
                    .font(.system(size: 24))
            }

            // Middle: title + meta
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(muted ? .secondary : .primary)
                HStack(spacing: 6) {
                    Text(item.category)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(accent.opacity(0.1), in: Capsule())
                        .foregroundStyle(accent)
                    Text(monthDayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if item.isRecurring, let y = item.yearsElapsed, y > 0 {
                        Text("第\(y + 1)年")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Right: countdown
            VStack(spacing: 0) {
                if item.isToday {
                    Text("今天")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(accent)
                } else {
                    Text("\(abs(item.daysUntil))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(muted ? .tertiary : .primary)
                        .monospacedDigit()
                    Text(item.daysUntil > 0 ? "天后" : "天前")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minWidth: 50, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    item.isToday ? accent.opacity(0.5) : Color.primary.opacity(0.07),
                    lineWidth: item.isToday ? 1.5 : 0.5
                )
        )
        .shadow(color: .black.opacity(item.isToday ? 0.06 : 0.03), radius: 6, y: 2)
    }

    private var monthDayLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        return fmt.string(from: item.date)
    }

    // Progress within the current year cycle (0–1)
    private var ringProgress: CGFloat {
        guard item.isRecurring else { return 1.0 }
        let d = item.daysUntil
        guard d > 0 else { return 1.0 }
        return CGFloat(365 - d) / 365.0
    }
}

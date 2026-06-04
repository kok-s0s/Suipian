import SwiftUI
import SwiftData

struct ImportantDatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ImportantDate.date) private var dates: [ImportantDate]
    @State private var showingAdd = false
    @State private var dateToEdit: ImportantDate? = nil

    private var sorted: [ImportantDate] {
        dates.sorted { $0.daysUntil < $1.daysUntil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if dates.isEmpty {
                    ContentUnavailableView(
                        "还没有重要日期",
                        systemImage: "calendar.badge.clock",
                        description: Text("添加生日、纪念日或目标日期，随时查看倒计时")
                    )
                } else {
                    List {
                        ForEach(sorted) { item in
                            ImportantDateRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { dateToEdit = item }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete { offsets in
                            for i in offsets {
                                let item = sorted[i]
                                ImportantDateNotifier.remove(item)
                                modelContext.delete(item)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background { AppBackgroundCanvas().ignoresSafeArea() }
            .navigationTitle("重要日期")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            ImportantDateEditView()
        }
        .sheet(item: $dateToEdit) { item in
            ImportantDateEditView(item: item)
        }
    }
}

// MARK: - Row

private struct ImportantDateRow: View {
    let item: ImportantDate

    private var accentColor: Color {
        item.isToday ? Color(red: 0.780, green: 0.624, blue: 0.384) : Color.accentColor
    }

    var body: some View {
        HStack(spacing: 14) {
            // Emoji circle
            Text(item.emoji)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(item.category)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(accentColor.opacity(0.1), in: Capsule())
                        .foregroundStyle(accentColor)
                    Text(dateLabel(item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Countdown badge
            VStack(spacing: 1) {
                if item.isToday {
                    Text("今天").font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(accentColor)
                } else {
                    Text("\(abs(item.daysUntil))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(item.isPast ? .secondary : .primary)
                        .monospacedDigit()
                    Text(item.daysUntil > 0 ? "天后" : "天前")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 44)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(item.isToday ? accentColor.opacity(0.5) : Color.primary.opacity(0.07),
                              lineWidth: item.isToday ? 1.5 : 0.5)
        )
        .padding(.horizontal, 16).padding(.vertical, 4)
    }

    private func dateLabel(_ item: ImportantDate) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        let base = fmt.string(from: item.date)
        if item.isRecurring, let y = item.yearsElapsed, y > 0 {
            return "\(base) · 第 \(y + 1) 年"
        }
        return base
    }
}

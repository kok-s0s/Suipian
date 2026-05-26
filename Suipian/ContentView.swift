import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // ⑤ 全局渐变背景
            appBackground.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                FragmentFeedView().tag(0)
                StoryListView().tag(1)
                FragmentMapView().tag(2)
                StatsView().tag(3)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingTabBar(selectedTab: $selectedTab)
            }
        }
    }

    @ViewBuilder
    private var appBackground: some View {
        if colorScheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.15),
                    Color(red: 0.07, green: 0.05, blue: 0.13)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.00),
                    Color(red: 0.91, green: 0.94, blue: 0.99)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - ① 浮动 Tab Bar

struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    private let items: [(icon: String, label: String)] = [
        ("square.on.square.fill", "碎片"),
        ("link",                  "故事线"),
        ("map.fill",              "地图"),
        ("chart.bar.fill",        "统计")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                FloatingTabItem(
                    icon: item.icon,
                    label: item.label,
                    isSelected: selectedTab == index
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.28), lineWidth: 0.75))
        .shadow(color: Color.accentColor.opacity(0.18), radius: 18, y: 5)
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
    }
}

private struct FloatingTabItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .scaleEffect(isSelected ? 1.12 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.13) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
    }
}

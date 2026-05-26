import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
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

// MARK: - Floating Tab Bar

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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 0.75))
        .shadow(color: Color.accentColor.opacity(0.15), radius: 14, y: 4)
        .padding(.horizontal, 40)
        .padding(.bottom, 16)
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
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                // 小圆点选中指示器
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }
}

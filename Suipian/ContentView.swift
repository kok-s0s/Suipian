import SwiftUI

struct ContentView: View {
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var isLocked = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView {
                FragmentFeedView()
                    .tabItem { Label("碎片", systemImage: "square.on.square.fill") }
                StoryListView()
                    .tabItem { Label("故事线", systemImage: "link") }
                FragmentMapView()
                    .tabItem { Label("地图", systemImage: "map.fill") }
                StatsView()
                    .tabItem { Label("统计", systemImage: "chart.bar.fill") }
            }

            if isLocked && appLockEnabled {
                LockScreenView {
                    withAnimation(.easeOut(duration: 0.2)) { isLocked = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeIn(duration: 0.15), value: isLocked)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && appLockEnabled {
                isLocked = true
            }
        }
        .onAppear {
            if appLockEnabled { isLocked = true }
        }
    }
}

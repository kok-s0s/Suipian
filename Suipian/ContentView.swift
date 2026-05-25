import SwiftUI

struct ContentView: View {
    var body: some View {
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
    }
}

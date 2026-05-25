import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            FragmentFeedView()
                .tabItem { Label("碎片", systemImage: "square.on.square.fill") }
            FragmentMapView()
                .tabItem { Label("地图", systemImage: "map.fill") }
            StatsView()
                .tabItem { Label("统计", systemImage: "chart.bar.fill") }
        }
    }
}

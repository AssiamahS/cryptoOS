import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HoldingsView()
                .tabItem { Label("Holdings", systemImage: "chart.pie.fill") }
            MarketsView()
                .tabItem { Label("Markets", systemImage: "chart.line.uptrend.xyaxis") }
            NewsView()
                .tabItem { Label("News", systemImage: "newspaper.fill") }
        }
    }
}

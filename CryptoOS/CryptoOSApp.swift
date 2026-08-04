import SwiftUI

@main
struct CryptoOSApp: App {
    @StateObject private var market = MarketStore()
    @StateObject private var holdings = HoldingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(market)
                .environmentObject(holdings)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.20, green: 0.46, blue: 1.0))
        }
    }
}

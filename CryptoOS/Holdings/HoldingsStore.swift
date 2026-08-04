import Foundation

@MainActor
final class HoldingsStore: ObservableObject {
    @Published var holdings: [Holding] = [] {
        didSet { save() }
    }
    /// coinId -> (price, 24h change %)
    @Published var prices: [String: (Double, Double?)] = [:]
    @Published var lastUpdated: Date?

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("holdings.json")
    }

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Holding].self, from: data) {
            holdings = saved
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(holdings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func upsert(_ holding: Holding) {
        if let i = holdings.firstIndex(where: { $0.coinId == holding.coinId }) {
            holdings[i] = holding
        } else {
            holdings.append(holding)
        }
    }

    func remove(coinId: String) {
        holdings.removeAll { $0.coinId == coinId }
    }

    func refreshPrices() async {
        let ids = holdings.map(\.coinId)
        guard !ids.isEmpty else { return }
        if let fetched = try? await CoinGecko.simplePrices(ids: ids) {
            prices = fetched
            lastUpdated = Date()
        }
    }

    func value(of holding: Holding) -> Double? {
        prices[holding.coinId].map { holding.amount * $0.0 }
    }

    var totalValue: Double {
        holdings.compactMap { value(of: $0) }.reduce(0, +)
    }

    /// Portfolio 24h change in dollars, from per-coin 24h change percentages.
    var totalChange24h: Double {
        holdings.reduce(0) { sum, h in
            guard let (price, changePct) = prices[h.coinId], let pct = changePct else { return sum }
            let now = h.amount * price
            let then = now / (1 + pct / 100)
            return sum + (now - then)
        }
    }
}

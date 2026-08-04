import SwiftUI
import Charts

struct MarketsView: View {
    @EnvironmentObject private var market: MarketStore
    @State private var search = ""

    private var filtered: [Coin] {
        guard !search.isEmpty else { return market.coins }
        let q = search.lowercased()
        return market.coins.filter {
            $0.name.lowercased().contains(q) || $0.symbol.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = market.error {
                    Text(error).foregroundStyle(.secondary)
                }
                ForEach(filtered) { coin in
                    NavigationLink(value: coin.id) {
                        CoinRow(coin: coin)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Markets")
            .navigationDestination(for: String.self) { coinId in
                if let coin = market.coin(for: coinId) {
                    CoinDetailView(coin: coin)
                }
            }
            .searchable(text: $search, prompt: "Search coins")
            .refreshable { await market.refresh() }
            .task {
                if market.coins.isEmpty { await market.refresh() }
            }
            .overlay {
                if market.coins.isEmpty && market.error == nil {
                    ProgressView()
                }
            }
        }
    }
}

struct CoinRow: View {
    let coin: Coin

    private var change: Double { coin.priceChangePercentage24h ?? 0 }

    var body: some View {
        HStack(spacing: 12) {
            CoinIcon(url: coin.image)

            VStack(alignment: .leading, spacing: 2) {
                Text(coin.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(coin.symbol.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let spark = coin.sparklineIn7d?.price, spark.count > 2 {
                SparklineView(prices: spark, up: change >= 0)
                    .frame(width: 56, height: 28)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(coin.currentPrice.usd)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(change.signedPercent)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(change >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SparklineView: View {
    let prices: [Double]
    let up: Bool

    var body: some View {
        Chart(Array(prices.enumerated()), id: \.offset) { index, price in
            LineMark(x: .value("i", index), y: .value("p", price))
                .foregroundStyle(up ? Color.green : Color.red)
                .lineStyle(StrokeStyle(lineWidth: 1.2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (prices.min() ?? 0)...(prices.max() ?? 1))
        .allowsHitTesting(false)
    }
}

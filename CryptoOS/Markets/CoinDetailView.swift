import SwiftUI

struct CoinDetailView: View {
    let coin: Coin
    @EnvironmentObject private var holdings: HoldingsStore

    @State private var range: ChartRange = .day
    @State private var points: [PricePoint] = []
    @State private var selection: ChartSelection?
    @State private var loading = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal)
                .padding(.top, 8)

            Group {
                if points.isEmpty {
                    ZStack {
                        if loading {
                            ProgressView()
                        } else {
                            Text("No chart data")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    PriceChartView(points: points, selection: $selection)
                }
            }
            .frame(height: 280)
            .padding(.vertical, 8)

            rangePicker
                .padding(.horizontal)

            ScrollView {
                statsGrid
                    .padding()
                holdingRow
                    .padding(.horizontal)
            }
        }
        .navigationTitle(coin.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: range) {
            loading = true
            selection = nil
            points = (try? await CoinGecko.marketChart(coinId: coin.id, range: range)) ?? []
            loading = false
        }
    }

    // MARK: header — price + change, or scrub/range readout

    private var displayedPrice: Double {
        switch selection {
        case .point(let p): return p.price
        case .range(_, let b): return b.price
        case nil: return points.last?.price ?? coin.currentPrice
        }
    }

    private var changeText: (String, Bool, String)? {
        switch selection {
        case .point(let p):
            return (p.date.formatted(date: .abbreviated, time: .shortened), true, "")
        case .range(let a, let b):
            let delta = b.price - a.price
            let pct = a.price != 0 ? delta / a.price * 100 : 0
            let dates = "\(a.date.formatted(date: .abbreviated, time: .shortened)) → \(b.date.formatted(date: .abbreviated, time: .shortened))"
            return (dates, delta >= 0, "\(delta >= 0 ? "+" : "")\(delta.usd)  (\(pct.signedPercent))")
        case nil:
            guard let first = points.first, let last = points.last, first.price != 0 else { return nil }
            let delta = last.price - first.price
            let pct = delta / first.price * 100
            return (range.rawValue, delta >= 0, "\(delta >= 0 ? "+" : "")\(delta.usd)  (\(pct.signedPercent))")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                CoinIcon(url: coin.image, size: 24)
                Text(coin.symbol.uppercased())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(displayedPrice.usd)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: displayedPrice)
            if let (label, up, delta) = changeText {
                HStack(spacing: 8) {
                    if !delta.isEmpty {
                        Text(delta)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(up ? .green : .red)
                    }
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(ChartRange.allCases) { r in
                Button {
                    range = r
                } label: {
                    Text(r.rawValue)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(range == r ? Color(.systemGray5) : .clear)
                        )
                        .foregroundStyle(range == r ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCell("Market Cap", coin.marketCap.map { $0.usdCompact } ?? "—")
            statCell("Volume (24h)", coin.totalVolume.map { $0.usdCompact } ?? "—")
            statCell("24h High", coin.high24h.map { $0.usd } ?? "—")
            statCell("24h Low", coin.low24h.map { $0.usd } ?? "—")
        }
    }

    private func statCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private var holdingRow: some View {
        Group {
            if let holding = holdings.holdings.first(where: { $0.coinId == coin.id }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your position")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(holding.amount.qty) \(coin.symbol.uppercased())")
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Text((holding.amount * coin.currentPrice).usd)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }
}

struct CoinIcon: View {
    let url: String?
    var size: CGFloat = 32

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init)) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Circle().fill(Color(.systemGray5))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

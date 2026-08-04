import SwiftUI

struct AddHoldingView: View {
    @EnvironmentObject private var holdings: HoldingsStore
    @EnvironmentObject private var market: MarketStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [SearchCoin] = []
    @State private var searching = false
    @State private var picked: SearchCoin?
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            Group {
                if let coin = picked {
                    amountForm(for: coin)
                } else {
                    searchList
                }
            }
            .navigationTitle(picked == nil ? "Add Holding" : "Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var searchList: some View {
        List {
            if query.isEmpty {
                Section("Top coins") {
                    ForEach(market.coins.prefix(20)) { coin in
                        Button {
                            picked = SearchCoin(
                                id: coin.id, symbol: coin.symbol, name: coin.name,
                                large: coin.image, marketCapRank: coin.marketCapRank
                            )
                        } label: {
                            row(name: coin.name, symbol: coin.symbol, image: coin.image)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                ForEach(results) { coin in
                    Button {
                        picked = coin
                    } label: {
                        row(name: coin.name, symbol: coin.symbol, image: coin.large)
                    }
                    .buttonStyle(.plain)
                }
                if searching { ProgressView() }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search any coin")
        .task(id: query) {
            guard query.count >= 2 else { results = []; return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            searching = true
            results = (try? await CoinGecko.search(query)) ?? []
            searching = false
        }
    }

    private func row(name: String, symbol: String, image: String?) -> some View {
        HStack(spacing: 12) {
            CoinIcon(url: image)
            Text(name).font(.subheadline.weight(.semibold))
            Text(symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func amountForm(for coin: SearchCoin) -> some View {
        Form {
            HStack(spacing: 12) {
                CoinIcon(url: coin.large)
                Text(coin.name).font(.headline)
            }
            TextField("Amount of \(coin.symbol.uppercased())", text: $amountText)
                .keyboardType(.decimalPad)
            Button("Add") {
                if let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 {
                    holdings.upsert(Holding(
                        coinId: coin.id, symbol: coin.symbol, name: coin.name,
                        image: coin.large, amount: amount
                    ))
                    dismiss()
                }
            }
            .disabled(Double(amountText.replacingOccurrences(of: ",", with: ".")) == nil)
        }
    }
}

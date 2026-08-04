import SwiftUI

struct HoldingsView: View {
    @EnvironmentObject private var holdings: HoldingsStore
    @EnvironmentObject private var market: MarketStore
    @State private var showAdd = false
    @State private var editing: Holding?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    balanceHeader
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                Section {
                    if holdings.holdings.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.dashed")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Add your first holding")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(holdings.holdings) { holding in
                            Button {
                                editing = holding
                            } label: {
                                HoldingRow(holding: holding)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for i in offsets {
                                holdings.remove(coinId: holdings.holdings[i].coinId)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Holdings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddHoldingView()
            }
            .sheet(item: $editing) { holding in
                EditHoldingView(holding: holding)
            }
            .refreshable { await holdings.refreshPrices() }
            .task { await holdings.refreshPrices() }
            .task(id: holdings.holdings.count) { await holdings.refreshPrices() }
        }
    }

    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(holdings.totalValue.usd)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            let change = holdings.totalChange24h
            if holdings.totalValue > 0 {
                Text("\(change >= 0 ? "+" : "")\(change.usd) today")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(change >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

struct HoldingRow: View {
    @EnvironmentObject private var holdings: HoldingsStore
    let holding: Holding

    var body: some View {
        HStack(spacing: 12) {
            CoinIcon(url: holding.image)
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(holding.amount.qty) \(holding.symbol.uppercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let value = holdings.value(of: holding) {
                    Text(value.usd)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
                if let pct = holdings.prices[holding.coinId]?.1 {
                    Text(pct.signedPercent)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(pct >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct EditHoldingView: View {
    @EnvironmentObject private var holdings: HoldingsStore
    @Environment(\.dismiss) private var dismiss
    let holding: Holding
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            Form {
                HStack(spacing: 12) {
                    CoinIcon(url: holding.image)
                    Text(holding.name).font(.headline)
                }
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                Button("Remove holding", role: .destructive) {
                    holdings.remove(coinId: holding.coinId)
                    dismiss()
                }
            }
            .navigationTitle("Edit \(holding.symbol.uppercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 {
                            var updated = holding
                            updated.amount = amount
                            holdings.upsert(updated)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { amountText = holding.amount.qty }
        }
        .presentationDetents([.medium])
    }
}

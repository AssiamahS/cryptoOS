import Foundation

enum CoinGeckoError: Error {
    case badURL
    case badResponse(Int)
}

/// Free CoinGecko v3 API — no key, keep call volume polite (10-30/min).
struct CoinGecko {
    static let base = "https://api.coingecko.com/api/v3"

    static func fetch(_ path: String, query: [URLQueryItem]) async throws -> Data {
        var comps = URLComponents(string: base + path)
        comps?.queryItems = query
        guard let url = comps?.url else { throw CoinGeckoError.badURL }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw CoinGeckoError.badResponse(http.statusCode)
        }
        return data
    }

    static func markets(page: Int = 1, perPage: Int = 100) async throws -> [Coin] {
        let data = try await fetch("/coins/markets", query: [
            .init(name: "vs_currency", value: "usd"),
            .init(name: "order", value: "market_cap_desc"),
            .init(name: "per_page", value: String(perPage)),
            .init(name: "page", value: String(page)),
            .init(name: "sparkline", value: "true"),
            .init(name: "price_change_percentage", value: "24h"),
        ])
        return try JSONDecoder().decode([Coin].self, from: data)
    }

    static func marketChart(coinId: String, range: ChartRange) async throws -> [PricePoint] {
        let data = try await fetch("/coins/\(coinId)/market_chart", query: [
            .init(name: "vs_currency", value: "usd"),
            .init(name: "days", value: range.days),
        ])
        struct ChartResponse: Codable { let prices: [[Double]] }
        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        var points = decoded.prices.compactMap { pair -> PricePoint? in
            guard pair.count == 2 else { return nil }
            return PricePoint(date: Date(timeIntervalSince1970: pair[0] / 1000), price: pair[1])
        }
        if range == .hour {
            let cutoff = Date().addingTimeInterval(-3600)
            let hour = points.filter { $0.date >= cutoff }
            if hour.count >= 2 { points = hour }
        }
        return points
    }

    /// [coinId: (price, change24hPercent)]
    static func simplePrices(ids: [String]) async throws -> [String: (Double, Double?)] {
        guard !ids.isEmpty else { return [:] }
        let data = try await fetch("/simple/price", query: [
            .init(name: "ids", value: ids.joined(separator: ",")),
            .init(name: "vs_currencies", value: "usd"),
            .init(name: "include_24hr_change", value: "true"),
        ])
        let decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        var out: [String: (Double, Double?)] = [:]
        for (id, values) in decoded {
            if let price = values["usd"] {
                out[id] = (price, values["usd_24h_change"])
            }
        }
        return out
    }

    static func search(_ query: String) async throws -> [SearchCoin] {
        let data = try await fetch("/search", query: [.init(name: "query", value: query)])
        struct SearchResponse: Codable { let coins: [SearchCoin] }
        return try JSONDecoder().decode(SearchResponse.self, from: data).coins
    }
}

@MainActor
final class MarketStore: ObservableObject {
    @Published var coins: [Coin] = []
    @Published var error: String?
    @Published var lastUpdated: Date?

    func refresh() async {
        do {
            coins = try await CoinGecko.markets()
            lastUpdated = Date()
            error = nil
        } catch {
            if coins.isEmpty { self.error = "Couldn't load prices. Pull to retry." }
        }
    }

    func coin(for id: String) -> Coin? {
        coins.first { $0.id == id }
    }
}

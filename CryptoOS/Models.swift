import Foundation

struct Coin: Identifiable, Codable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let image: String?
    let currentPrice: Double
    let marketCap: Double?
    let marketCapRank: Int?
    let totalVolume: Double?
    let high24h: Double?
    let low24h: Double?
    let priceChange24h: Double?
    let priceChangePercentage24h: Double?
    let sparklineIn7d: Sparkline?

    struct Sparkline: Codable, Equatable {
        let price: [Double]
    }

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case priceChange24h = "price_change_24h"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case sparklineIn7d = "sparkline_in_7d"
    }
}

struct PricePoint: Identifiable, Equatable {
    let date: Date
    let price: Double
    var id: Date { date }
}

enum ChartRange: String, CaseIterable, Identifiable {
    case hour = "1H"
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case quarter = "3M"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    var days: String {
        switch self {
        case .hour: return "1"
        case .day: return "1"
        case .week: return "7"
        case .month: return "30"
        case .quarter: return "90"
        case .year: return "365"
        case .all: return "max"
        }
    }
}

struct Holding: Identifiable, Codable, Equatable {
    var id: String { coinId }
    let coinId: String
    let symbol: String
    let name: String
    let image: String?
    var amount: Double
}

struct SearchCoin: Identifiable, Codable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let large: String?
    let marketCapRank: Int?

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, large
        case marketCapRank = "market_cap_rank"
    }
}

struct NewsItem: Identifiable, Equatable {
    let id: String
    let title: String
    let link: URL
    let source: String
    let date: Date
    let imageURL: URL?
}

// MARK: - Formatting

extension Double {
    var usd: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        if abs(self) >= 1 {
            f.maximumFractionDigits = 2
            f.minimumFractionDigits = 2
        } else {
            f.maximumFractionDigits = 6
            f.minimumFractionDigits = 2
        }
        return f.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    var usdCompact: String {
        let n = abs(self)
        let sign = self < 0 ? "-" : ""
        switch n {
        case 1_000_000_000_000...: return String(format: "%@$%.2fT", sign, n / 1_000_000_000_000)
        case 1_000_000_000...: return String(format: "%@$%.2fB", sign, n / 1_000_000_000)
        case 1_000_000...: return String(format: "%@$%.2fM", sign, n / 1_000_000)
        case 1_000...: return String(format: "%@$%.1fK", sign, n / 1_000)
        default: return usd
        }
    }

    var signedPercent: String {
        String(format: "%@%.2f%%", self >= 0 ? "+" : "", self)
    }

    var qty: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 8
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

import Foundation

struct Ticker: Identifiable, Codable, Hashable {
    var id: String { symbol }

    let symbol: String
    var name: String?
    var lastPrice: Double?
    var changePercent: Double?
    var lastUpdated: Date?
    var isFavorite: Bool = false

    init(symbol: String, name: String? = nil) {
        self.symbol = symbol.uppercased()
        self.name = name
        self.lastPrice = nil
        self.changePercent = nil
        self.lastUpdated = nil
    }
}

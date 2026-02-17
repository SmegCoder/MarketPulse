import Foundation

struct StockListing: Identifiable, Codable, Hashable {
    var id: String { "\(symbol)|\(exchange)|\(assetType)" }

    let symbol: String
    let name: String
    let exchange: String
    let assetType: String
    let status: String
}

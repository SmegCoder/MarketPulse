import Foundation

struct SymbolSuggestion: Identifiable, Hashable {
    var id: String { "\(symbol)|\(region ?? "")" }

    let symbol: String
    let name: String
    let type: String?
    let region: String?
    let currency: String?
    let matchScore: Double?
}

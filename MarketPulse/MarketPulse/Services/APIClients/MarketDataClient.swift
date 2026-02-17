import Foundation

protocol MarketDataClient {
    func fetchQuote(symbol: String) async throws -> (price: Double, changePercent: Double?)
    func fetchDailyCloses(symbol: String, limit: Int) async throws -> [PricePoint]
}

// AlphaVantageClient уже имеет нужные методы fetchQuote/fetchDailyCloses
extension AlphaVantageClient: MarketDataClient {}

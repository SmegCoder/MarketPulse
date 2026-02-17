
import Foundation

final class HybridMarketDataClient: MarketDataClient {
    private let quoteClient: any MarketDataClient   // Finnhub
    private let historyClient: any MarketDataClient // TwelveData (для графика)

    init(quoteClient: any MarketDataClient, historyClient: any MarketDataClient) {
        self.quoteClient = quoteClient
        self.historyClient = historyClient
    }

    func fetchQuote(symbol: String) async throws -> (price: Double, changePercent: Double?) {
        try await quoteClient.fetchQuote(symbol: symbol)
    }

    func fetchDailyCloses(symbol: String, limit: Int) async throws -> [PricePoint] {
        try await historyClient.fetchDailyCloses(symbol: symbol, limit: limit)
    }
}

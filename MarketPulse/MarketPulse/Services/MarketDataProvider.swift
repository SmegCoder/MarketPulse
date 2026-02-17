import Foundation

enum MarketDataProvider {
    static func makeClient() -> any MarketDataClient {
        let finnhubKey = (Bundle.main.object(forInfoDictionaryKey: "FINNHUB_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let twelveKey = (Bundle.main.object(forInfoDictionaryKey: "TWELVEDATA_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Если есть оба ключа — делаем гибрид: котировки Finnhub, график TwelveData
        if !finnhubKey.isEmpty, !twelveKey.isEmpty {
            return HybridMarketDataClient(
                quoteClient: FinnhubClient(token: finnhubKey),
                historyClient: TwelveDataClient(apiKey: twelveKey)
            )
        }

        // Иначе — как раньше (что есть)
        if !finnhubKey.isEmpty {
            return FinnhubClient(token: finnhubKey) // (график может не работать, но quote будет)
        }

        let avKey = (Bundle.main.object(forInfoDictionaryKey: "ALPHAVANTAGE_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return AlphaVantageClient(apiKey: avKey)
    }

    static func providerName() -> String {
        let finnhubKey = (Bundle.main.object(forInfoDictionaryKey: "FINNHUB_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let twelveKey = (Bundle.main.object(forInfoDictionaryKey: "TWELVEDATA_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !finnhubKey.isEmpty, !twelveKey.isEmpty { return "Finnhub (quote) + TwelveData (chart)" }
        if !finnhubKey.isEmpty { return "Finnhub" }
        return "AlphaVantage"
    }
}

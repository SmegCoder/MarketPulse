import Foundation

enum TwelveDataError: LocalizedError {
    case missingKey
    case apiMessage(String)
    case badData

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Missing TWELVEDATA_API_KEY in Target -> Info"
        case .apiMessage(let m): return "TwelveData: \(m)"
        case .badData: return "TwelveData: bad/empty response"
        }
    }
}

final class TwelveDataClient: MarketDataClient {
    private let apiKey: String
    private let network: NetworkService

    // 8/min на free — ставим 7/min для запаса
    private static let limiter = SlidingWindowRateLimiter(maxRequests: 7, windowSeconds: 60)
    // кэш графика на 30 минут
    private static let chartCache = ExpiringCache<[PricePoint]>(ttl: 30 * 60)

    init(apiKey: String, network: NetworkService = NetworkService()) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.network = network
    }

    // Если когда-нибудь понадобится quote из TwelveData (сейчас у тебя quote из Finnhub)
    private struct PriceResponse: Decodable { let price: String? }

    func fetchQuote(symbol: String) async throws -> (price: Double, changePercent: Double?) {
        guard !apiKey.isEmpty else { throw TwelveDataError.missingKey }

        let url = Self.makeURL(path: "/price", items: [
            .init(name: "symbol", value: symbol.uppercased()),
            .init(name: "apikey", value: apiKey)
        ])

        let data = try await network.getData(from: url)

        if let msg = Self.parseMessage(from: data) {
            throw TwelveDataError.apiMessage(msg)
        }

        let decoded = try network.decode(PriceResponse.self, from: data)
        guard let s = decoded.price, let p = Double(s) else { throw TwelveDataError.badData }
        return (p, nil)
    }

    private struct TimeSeriesResponse: Decodable {
        struct Value: Decodable {
            let datetime: String
            let close: String
        }
        let values: [Value]?
        let status: String?
        let message: String?
    }

    func fetchDailyCloses(symbol: String, limit: Int) async throws -> [PricePoint] {
        guard !apiKey.isEmpty else { throw TwelveDataError.missingKey }

        let sym = symbol.uppercased()
        let safeLimit = max(10, min(limit, 200))
        let cacheKey = "TD:1day:\(sym):\(safeLimit)"

        // ВАЖНО: внутри closure не трогаем self.* (чтобы не было MainActor/self capture проблем)
        let apiKeyLocal = apiKey
        let networkLocal = network

        return try await Self.chartCache.getOrCreate(cacheKey) {
            await Self.limiter.acquire()

            let url = Self.makeURL(path: "/time_series", items: [
                .init(name: "symbol", value: sym),
                .init(name: "interval", value: "1day"),
                .init(name: "outputsize", value: String(safeLimit)),
                .init(name: "apikey", value: apiKeyLocal)
            ])

            let data = try await networkLocal.getData(from: url)
            let decoded = try networkLocal.decode(TimeSeriesResponse.self, from: data)

            if let msg = decoded.message { throw TwelveDataError.apiMessage(msg) }
            if decoded.status?.lowercased() == "error" {
                throw TwelveDataError.apiMessage(decoded.message ?? "unknown error")
            }
            guard let vals = decoded.values, !vals.isEmpty else { throw TwelveDataError.badData }

            let df1 = DateFormatter()
            df1.locale = Locale(identifier: "en_US_POSIX")
            df1.timeZone = TimeZone(secondsFromGMT: 0)
            df1.dateFormat = "yyyy-MM-dd"

            let df2 = DateFormatter()
            df2.locale = Locale(identifier: "en_US_POSIX")
            df2.timeZone = TimeZone(secondsFromGMT: 0)
            df2.dateFormat = "yyyy-MM-dd HH:mm:ss"

            var points: [PricePoint] = []
            points.reserveCapacity(vals.count)

            for v in vals {
                let d = df2.date(from: v.datetime) ?? df1.date(from: v.datetime)
                guard let date = d, let close = Double(v.close) else { continue }
                points.append(PricePoint(date: date, close: close))
            }

            points.sort { $0.date < $1.date }
            return points
        }
    }

    private static func makeURL(path: String, items: [URLQueryItem]) -> URL {
        var c = URLComponents()
        c.scheme = "https"
        c.host = "api.twelvedata.com"
        c.path = path
        c.queryItems = items
        return c.url!
    }

    private static func parseMessage(from data: Data) -> String? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = obj["message"] as? String {
            return msg
        }
        return nil
    }
}

import Foundation

enum FinnhubError: Error, LocalizedError {
    case missingToken
    case noData

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Missing FINNHUB_API_KEY in Target -> Info"
        case .noData: return "No data from Finnhub"
        }
    }
}

final class FinnhubClient: MarketDataClient {
    private let token: String
    private let network: NetworkService

    init(token: String, network: NetworkService = NetworkService()) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.network = network
    }

    private struct QuoteResponse: Decodable {
        let c: Double?   // current price
        let dp: Double?  // percent change
    }
    
    private func makeURL(path: String, items: [URLQueryItem]) throws -> URL {
        var c = URLComponents()
        c.scheme = "https"
        c.host = "finnhub.io"
        c.path = "/api/v1" + path

        var q = items
        q.append(URLQueryItem(name: "token", value: token))   // <- вот это важно
        c.queryItems = q

        guard let url = c.url else { throw URLError(.badURL) }
        return url
    }

    func fetchQuote(symbol: String) async throws -> (price: Double, changePercent: Double?) {
        guard !token.isEmpty else { throw FinnhubError.missingToken }

        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "finnhub.io"
        comps.path = "/api/v1/quote"
        comps.queryItems = [
            URLQueryItem(name: "symbol", value: symbol.uppercased())
        ]
        let url = comps.url!

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(token, forHTTPHeaderField: "X-Finnhub-Token")

        let data = try await network.getData(request: req)

        #if DEBUG
        print("Finnhub quote URL:", url.absoluteString)
        print("Finnhub quote raw:", String(data: data, encoding: .utf8) ?? "<non-utf8>")
        #endif

        let decoded = try network.decode(QuoteResponse.self, from: data)
        guard let price = decoded.c else { throw FinnhubError.noData }
        return (price, decoded.dp)
    }

    private struct CandleResponse: Decodable {
        let c: [Double]?
        let t: [Int]?
        let s: String? // "ok" or "no_data"
    }

    func fetchDailyCloses(symbol: String, limit: Int) async throws -> [PricePoint] {
        guard !token.isEmpty else { throw FinnhubError.missingToken }

        let now = Int(Date().timeIntervalSince1970)
        let from = now - 180 * 24 * 3600

        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "finnhub.io"
        comps.path = "/api/v1/stock/candle"
        comps.queryItems = [
            URLQueryItem(name: "symbol", value: symbol.uppercased()),
            URLQueryItem(name: "resolution", value: "D"),
            URLQueryItem(name: "from", value: String(from)),
            URLQueryItem(name: "to", value: String(now))
        ]
        let url = comps.url!

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(token, forHTTPHeaderField: "X-Finnhub-Token")

        let data = try await network.getData(request: req)

        #if DEBUG
        print("Finnhub candle URL:", url.absoluteString)
        #endif

        let decoded = try network.decode(CandleResponse.self, from: data)

        guard decoded.s == "ok",
              let closes = decoded.c,
              let times = decoded.t,
              closes.count == times.count,
              !closes.isEmpty else {
            throw FinnhubError.noData
        }

        var points: [PricePoint] = []
        points.reserveCapacity(min(limit, closes.count))

        for (ts, close) in zip(times, closes) {
            points.append(PricePoint(date: Date(timeIntervalSince1970: TimeInterval(ts)), close: close))
        }

        return points.count > limit ? Array(points.suffix(limit)) : points
    }
}

import Foundation

enum AlphaVantageError: Error, LocalizedError {
    case apiMessage(String)
    case noQuote
    case badResponse

    var errorDescription: String? {
        switch self {
        case .apiMessage(let msg): return msg
        case .noQuote: return "Нет данных котировки (Global Quote) в ответе."
        case .badResponse: return "Некорректный ответ Alpha Vantage."
        }
    }
}

// MARK: - Quote decoding
private struct GlobalQuoteEnvelope: Decodable {
    let globalQuote: GlobalQuote?

    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

private struct GlobalQuote: Decodable {
    let symbol: String?
    let price: String?
    let changePercent: String?

    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case price = "05. price"
        case changePercent = "10. change percent"
    }
}

// MARK: - Daily series decoding
private struct DailySeriesEnvelope: Decodable {
    let timeSeriesDaily: [String: DailyBar]?

    enum CodingKeys: String, CodingKey {
        case timeSeriesDaily = "Time Series (Daily)"
    }
}

private struct DailyBar: Decodable {
    let close: String?

    enum CodingKeys: String, CodingKey {
        case close = "4. close"
    }
}

// MARK: - Autocomplete features
private struct SymbolSearchEnvelope: Decodable {
    let bestMatches: [SymbolMatch]?
}

private struct SymbolMatch: Decodable {
    let symbol: String?
    let name: String?
    let type: String?
    let region: String?
    let currency: String?
    let matchScore: String?

    enum CodingKeys: String, CodingKey {
        case symbol = "1. symbol"
        case name = "2. name"
        case type = "3. type"
        case region = "4. region"
        case currency = "8. currency"
        case matchScore = "9. matchScore"
    }
}


// MARK: - API message decoding (limit/info/error)
private struct AlphaVantageMessageEnvelope: Decodable {
    let information: String?
    let note: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case information = "Information"
        case note = "Note"
        case errorMessage = "Error Message"
    }
}

final class AlphaVantageClient {
    private let apiKey: String
    private let network: NetworkService

    init(apiKey: String, network: NetworkService = NetworkService()) {
        self.apiKey = apiKey
        self.network = network
    }

    // MARK: - Public API
    func fetchQuote(symbol: String) async throws -> (price: Double, changePercent: Double?) {
        let url = makeURL(function: "GLOBAL_QUOTE", symbol: symbol)
        let data = try await network.getData(from: url)

        #if DEBUG
        if let raw = String(data: data, encoding: .utf8) {
            print("AlphaVantage raw response for \(symbol):\n\(raw)")
        }
        #endif

        // 1) сначала проверим сообщения об ошибках/лимитах
        if let msg = try? network.decode(AlphaVantageMessageEnvelope.self, from: data),
           let text = msg.information ?? msg.note ?? msg.errorMessage {
            throw AlphaVantageError.apiMessage(text)
        }

        // 2) декодируем котировку
        let decoded = try network.decode(GlobalQuoteEnvelope.self, from: data)
        guard let quote = decoded.globalQuote,
              let priceStr = quote.price,
              let price = Double(priceStr) else {
            throw AlphaVantageError.noQuote
        }

        let cp = quote.changePercent.flatMap(Self.parsePercent)
        return (price, cp)
    }

    func fetchDailyCloses(symbol: String, limit: Int = 60) async throws -> [PricePoint] {
        let url = makeURL(function: "TIME_SERIES_DAILY", symbol: symbol)
        let data = try await network.getData(from: url)

        // лимиты/ошибки
        if let msg = try? network.decode(AlphaVantageMessageEnvelope.self, from: data),
           let text = msg.information ?? msg.note ?? msg.errorMessage {
            throw AlphaVantageError.apiMessage(text)
        }

        let decoded = try network.decode(DailySeriesEnvelope.self, from: data)
        guard let dict = decoded.timeSeriesDaily else {
            throw AlphaVantageError.badResponse
        }

        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"

        // ключи сортируем по возрастанию, берём последние limit
        let keys = dict.keys.sorted()
        let slice = keys.suffix(limit)

        var points: [PricePoint] = []
        points.reserveCapacity(slice.count)

        for key in slice {
            guard let bar = dict[key],
                  let closeStr = bar.close,
                  let close = Double(closeStr),
                  let date = df.date(from: key) else { continue }
            points.append(PricePoint(date: date, close: close))
        }

        return points
    }
    
    func searchSymbols(keywords: String) async throws -> [SymbolSuggestion] {
        var comps = URLComponents(string: "https://www.alphavantage.co/query")!
        comps.queryItems = [
            URLQueryItem(name: "function", value: "SYMBOL_SEARCH"),
            URLQueryItem(name: "keywords", value: keywords),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        let url = comps.url!

        let data = try await network.getData(from: url)

        // лимиты/ошибки как и в других методах
        if let msg = try? network.decode(AlphaVantageMessageEnvelope.self, from: data),
           let text = msg.information ?? msg.note ?? msg.errorMessage {
            throw AlphaVantageError.apiMessage(text)
        }

        let decoded = try network.decode(SymbolSearchEnvelope.self, from: data)
        let matches = decoded.bestMatches ?? []

        let result: [SymbolSuggestion] = matches.compactMap { m in
            guard let sym = m.symbol, let name = m.name else { return nil }
            return SymbolSuggestion(
                symbol: sym,
                name: name,
                type: m.type,
                region: m.region,
                currency: m.currency,
                matchScore: m.matchScore.flatMap(Double.init)
            )
        }
        // сортируем по matchScore (если есть)
        return result.sorted { ($0.matchScore ?? 0) > ($1.matchScore ?? 0) }
    }

    func downloadListingStatusCSV(state: String = "active", date: String? = nil) async throws -> String {
        var comps = URLComponents(string: "https://www.alphavantage.co/query")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "function", value: "LISTING_STATUS"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        if let date { items.append(URLQueryItem(name: "date", value: date)) }
        comps.queryItems = items

        let url = comps.url!
        let data = try await network.getData(from: url)

        guard let text = String(data: data, encoding: .utf8) else {
            throw AlphaVantageError.apiMessage("Не удалось декодировать CSV (utf-8).")
        }

        // Иногда вместо CSV приходит JSON с Information/Note/Error Message (лимит/ошибка)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let noBOM = trimmed.replacingOccurrences(of: "\u{FEFF}", with: "")
        if trimmed.first == "{" {
            if let msg = try? network.decode(AlphaVantageMessageEnvelope.self, from: Data(trimmed.utf8)),
               let info = msg.information ?? msg.note ?? msg.errorMessage {
                throw AlphaVantageError.apiMessage(info)
            }
        }

        return noBOM
    }


    // MARK: - Helpers
    private func makeURL(function: String, symbol: String) -> URL {
        var comps = URLComponents(string: "https://www.alphavantage.co/query")!
        comps.queryItems = [
            URLQueryItem(name: "function", value: function),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        return comps.url!
    }

    private static func parsePercent(_ s: String) -> Double? {
        // "-1.1650%" -> -1.1650
        let cleaned = s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }
}

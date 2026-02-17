import Foundation

final class ListingStatusService {
    private let store = ListingsStore()
    private let client: AlphaVantageClient

    init(client: AlphaVantageClient) {
        self.client = client
    }

    func loadListings(maxAgeDays: Int = 14) async throws -> [StockListing] {
        let cached = store.load()
        let last = store.lastUpdateDate()

        // если кэш есть и не пустой — используем его сразу (даже если устарел),
        // а обновление попробуем сделать только если кэш слишком старый
        let cacheIsUsable = (cached?.isEmpty == false)
        let cacheAgeOk: Bool = {
            guard let last else { return false }
            return Date().timeIntervalSince(last) < TimeInterval(maxAgeDays) * 24 * 3600
        }()

        if cacheIsUsable && cacheAgeOk {
            return cached!
        }

        // пробуем обновить с сети
        do {
            let raw = try await client.downloadListingStatusCSV(state: "active")

            // убираем BOM и пробелы
            let cleaned = raw
                .replacingOccurrences(of: "\u{FEFF}", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Валидация заголовка CSV (иногда бывает "Symbol,..." или "symbol,...")
            let lower = cleaned.lowercased()
            guard lower.hasPrefix("symbol,") || lower.hasPrefix("\"symbol\",") else {
                throw AlphaVantageError.apiMessage("LISTING_STATUS returned not CSV (probably rate limit).")
            }

            let listings = parse(csv: cleaned)

            // если распарсилось подозрительно мало — не сохраняем как кэш
            guard listings.count > 100 else {
                throw AlphaVantageError.apiMessage("LISTING_STATUS parsed too few rows: \(listings.count)")
            }

            store.save(listings)
            return listings
        } catch {
            // если сеть не удалась, но кэш есть — возвращаем кэш и НЕ ломаем автокомплит
            if let cached, !cached.isEmpty {
                return cached
            }
            throw error
        }
    }


    // MARK: - CSV parsing (с кавычками)
    private func parse(csv: String) -> [StockListing] {
        var result: [StockListing] = []
        result.reserveCapacity(12000)

        var isHeader = true
        csv.enumerateLines { line, _ in
            if isHeader { isHeader = false; return }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return }

            let cols = Self.parseCSVLine(trimmed)
            // ожидаем: symbol,name,exchange,assetType,ipoDate,delistingDate,status
            guard cols.count >= 7 else { return }

            let symbol = cols[0].uppercased()
            let name = cols[1]
            let exchange = cols[2]
            let assetType = cols[3]
            let status = cols[6]

            if symbol.isEmpty || name.isEmpty { return }

            result.append(StockListing(
                symbol: symbol,
                name: name,
                exchange: exchange,
                assetType: assetType,
                status: status
            ))
        }

        return result
    }

    /// Простой CSV-парсер с поддержкой кавычек и запятых внутри имени
    private static func parseCSVLine(_ line: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            if ch == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    cur.append("\"")     // "" внутри кавычек = "
                    i += 2
                    continue
                } else {
                    inQuotes.toggle()
                    i += 1
                    continue
                }
            }

            if ch == "," && !inQuotes {
                out.append(cur)
                cur = ""
                i += 1
                continue
            }

            cur.append(ch)
            i += 1
        }

        out.append(cur)
        return out
    }
}

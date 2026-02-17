import Foundation
import Combine
import SwiftUI

enum SortOption: String, CaseIterable, Identifiable {
    case symbol = "Symbol"
    case price = "Price"
    case change = "Change %"
    case updated = "Updated"

    var id: String { rawValue }
}

@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published var tickers: [Ticker] = []
    @Published var isRefreshing: Bool = false
    @Published var bannerMessage: String? = nil

    @Published var sortOption: SortOption = .symbol
    @Published var sortAscending: Bool = true
    @Published var providerName: String = "?"

    private let store = WatchlistStore()
    private let client: any MarketDataClient

    private let perRequestDelayNs: UInt64 = 1_050_000_000
    private let minRefreshInterval: TimeInterval = 60

    init() {
        let finnhubKey = (Bundle.main.object(forInfoDictionaryKey: "FINNHUB_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !finnhubKey.isEmpty {
            self.client = FinnhubClient(token: finnhubKey)
            self.providerName = "Finnhub"
        } else {
            let avKey = (Bundle.main.object(forInfoDictionaryKey: "ALPHAVANTAGE_API_KEY") as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self.client = AlphaVantageClient(apiKey: avKey)
            self.providerName = "AlphaVantage (fallback)"
            self.bannerMessage = "FINNHUB_API_KEY not set — using AlphaVantage"
        }



        let loaded = store.load()
        if loaded.isEmpty {
            tickers = [
                Ticker(symbol: "AAPL", name: "Apple"),
                Ticker(symbol: "MSFT", name: "Microsoft")
            ]
            store.save(tickers)
        } else {
            tickers = loaded
        }
    }

    // MARK: - Display pipeline (search + sort)
    func displayedTickers(searchText: String) -> [Ticker] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var arr = tickers

        if !q.isEmpty {
            arr = arr.filter { t in
                t.symbol.localizedCaseInsensitiveContains(q) ||
                (t.name?.localizedCaseInsensitiveContains(q) ?? false)
            }
        }

        func less(_ a: Ticker, _ b: Ticker) -> Bool {
            // (опционально) держим избранные сверху всегда:
            if a.isFavorite != b.isFavorite {
                return a.isFavorite && !b.isFavorite
            }

            switch sortOption {
            case .symbol:
                if a.symbol != b.symbol { return a.symbol < b.symbol }
                return (a.name ?? "") < (b.name ?? "")

            case .price:
                switch (a.lastPrice, b.lastPrice) {
                case (.some(let x), .some(let y)):
                    if x != y { return x < y }
                    return a.symbol < b.symbol
                case (.none, .some):
                    return false
                case (.some, .none):
                    return true
                case (.none, .none):
                    return a.symbol < b.symbol
                }


            case .change:
                switch (a.changePercent, b.changePercent) {
                case (.some(let x), .some(let y)):
                    if x != y { return x < y }
                    return a.symbol < b.symbol
                case (.none, .some):
                    return false
                case (.some, .none):
                    return true
                case (.none, .none):
                    return a.symbol < b.symbol
                }

            case .updated:
                switch (a.lastUpdated, b.lastUpdated) {
                case (.some(let x), .some(let y)):
                    if x != y { return x < y }
                    return a.symbol < b.symbol
                case (.none, .some):
                    return false
                case (.some, .none):
                    return true
                case (.none, .none):
                    return a.symbol < b.symbol
                }
            }
        }

        return arr.sorted { lhs, rhs in
            sortAscending ? less(lhs, rhs) : less(rhs, lhs)
        }
    }

    // MARK: - CRUD
    func add(symbol raw: String, name: String? = nil) {
        guard let symbol = raw.normalizedTickerSymbol() else {
            bannerMessage = "Некорректный тикер."
            return
        }

        if let idx = tickers.firstIndex(where: { $0.symbol == symbol }) {
            if tickers[idx].name == nil, let name { tickers[idx].name = name }
            store.save(tickers)
            bannerMessage = "Тикер уже в списке."
            return
        }

        var t = Ticker(symbol: symbol)
        t.name = name
        tickers.append(t)
        store.save(tickers)
    }

    func remove(at offsets: IndexSet) {
        tickers.remove(atOffsets: offsets)
        store.save(tickers)
    }

    // ВАЖНО для удаления в отфильтрованном списке (Favorites/поиск)
    func deleteBySymbols(_ symbols: [String]) {
        let set = Set(symbols)
        tickers.removeAll { set.contains($0.symbol) }
        store.save(tickers)
    }

    // MARK: - Favorites
    func toggleFavorite(symbol: String) {
        guard let idx = tickers.firstIndex(where: { $0.symbol == symbol }) else { return }
        tickers[idx].isFavorite.toggle()
        store.save(tickers)
    }

    // MARK: - Refresh
    func refreshAll(force: Bool = false) async {
        bannerMessage = nil
        isRefreshing = true
        defer { isRefreshing = false }

        for i in tickers.indices {
            if !force, let last = tickers[i].lastUpdated,
               Date().timeIntervalSince(last) < minRefreshInterval {
                continue
            }

            let symbol = tickers[i].symbol
            do {
                let quote = try await client.fetchQuote(symbol: symbol)
                tickers[i].lastPrice = quote.price
                tickers[i].changePercent = quote.changePercent
                tickers[i].lastUpdated = Date()
                store.save(tickers)
            } catch {
                bannerMessage = error.localizedDescription
                return
            }

            try? await Task.sleep(nanoseconds: perRequestDelayNs)
        }
    }
}

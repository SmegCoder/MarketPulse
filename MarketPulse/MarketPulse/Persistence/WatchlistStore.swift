import Foundation

final class WatchlistStore {
    private let key = "watchlist_v1"

    func load() -> [Ticker] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([Ticker].self, from: data)
        } catch {
            print("WatchlistStore load error:", error)
            return []
        }
    }

    func save(_ tickers: [Ticker]) {
        do {
            let data = try JSONEncoder().encode(tickers)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("WatchlistStore save error:", error)
        }
    }
}

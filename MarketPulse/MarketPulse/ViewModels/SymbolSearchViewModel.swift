import Foundation
import Combine

@MainActor
final class SymbolSearchViewModel: ObservableObject {
    @Published var results: [StockListing] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var listings: [StockListing] = []
    private var lastQuery: String = ""
    private var lastBase: [StockListing] = []

    private let service: ListingStatusService

    init() {
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "ALPHAVANTAGE_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let client = AlphaVantageClient(apiKey: apiKey)
        self.service = ListingStatusService(client: client)
    }

    func ensureLoaded() async {
        if !listings.isEmpty { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            listings = try await service.loadListings(maxAgeDays: 14)

            if listings.isEmpty {
                errorMessage = "База тикеров пустая. Использую локальный список."
                listings = FallbackListings.items
            }
        } catch {
            errorMessage = error.localizedDescription + "\n(Использую локальный список популярных тикеров)"
            listings = FallbackListings.items
        }
        print("Listings loaded:", listings.count)

    }

    func search(_ raw: String, limit: Int = 30) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !q.isEmpty else {
            results = []   // можно сделать здесь популярные тикеры, если хочешь
            return
        }

        var out: [StockListing] = []
        out.reserveCapacity(limit)

        // 1) сначала prefix по символу (самый полезный автокомплит)
        for item in listings {
            if item.symbol.uppercased().hasPrefix(q) {
                out.append(item)
                if out.count == limit { results = out; return }
            }
        }

        // 2) потом contains по имени
        let q2 = q
        for item in listings {
            if item.name.uppercased().contains(q2) && !out.contains(item) {
                out.append(item)
                if out.count == limit { break }
            }
        }

        results = out
    }
}

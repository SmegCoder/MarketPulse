import Foundation
import Combine

@MainActor
final class TickerViewModel: ObservableObject {
    @Published var points: [PricePoint] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var providerName: String = MarketDataProvider.providerName()

    private let client: any MarketDataClient = MarketDataProvider.makeClient()

    func loadDaily(symbol: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            points = try await client.fetchDailyCloses(symbol: symbol, limit: 60)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import Foundation

final class ListingsStore {
    private let jsonFileName = "listing_status_active_v2.json"
    private let lastUpdateKey = "listing_status_active_last_update_v2"

    private var jsonURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(jsonFileName)
    }

    func load() -> [StockListing]? {
        guard FileManager.default.fileExists(atPath: jsonURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: jsonURL)
            return try JSONDecoder().decode([StockListing].self, from: data)
        } catch {
            print("ListingsStore load error:", error)
            return nil
        }
    }

    func save(_ listings: [StockListing]) {
        do {
            let data = try JSONEncoder().encode(listings)
            try data.write(to: jsonURL, options: .atomic)
            UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
        } catch {
            print("ListingsStore save error:", error)
        }
    }

    func lastUpdateDate() -> Date? {
        UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
    }
}

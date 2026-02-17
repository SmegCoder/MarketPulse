import Foundation

struct PricePoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let close: Double
}

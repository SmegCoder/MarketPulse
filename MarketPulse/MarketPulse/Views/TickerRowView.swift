import SwiftUI

struct TickerRowView: View {
    let ticker: Ticker
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(ticker.symbol)
                        .font(.headline)

                    Button(action: onToggleFavorite) {
                        Image(systemName: ticker.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(ticker.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let name = ticker.name, !name.isEmpty {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatter.price(ticker.lastPrice))
                    .font(.headline)

                let pct = ticker.changePercent
                Text(AppFormatter.percent(pct))
                    .font(.caption)
                    .foregroundStyle((pct ?? 0) >= 0 ? .green : .red)
            }
        }
    }
}

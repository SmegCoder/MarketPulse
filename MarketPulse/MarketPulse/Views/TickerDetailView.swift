import SwiftUI
import Charts

struct TickerDetailView: View {
    let ticker: Ticker
    @StateObject private var vm = TickerViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.isLoading {
                ProgressView()
            }

            if let msg = vm.errorMessage {
                Text(msg).foregroundStyle(.red)
            }

            if !vm.points.isEmpty {
                Chart(vm.points) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Close", p.close)
                    )
                }
                .frame(height: 240)
            } else if !vm.isLoading && vm.errorMessage == nil {
                Text("Нет данных для графика.").foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle(ticker.symbol)
        .task {
            await vm.loadDaily(symbol: ticker.symbol)
        }
    }
}

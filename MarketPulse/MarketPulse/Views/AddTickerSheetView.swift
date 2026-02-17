import SwiftUI

struct AddTickerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = SymbolSearchViewModel()
    @State private var query: String = ""

    let onPick: (StockListing) -> Void
    let onManualAdd: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Введите тикер или название (AAPL / Apple)", text: $query)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if vm.isLoading {
                    ProgressView("Загружаю базу тикеров…")
                }

                if let msg = vm.errorMessage {
                    Text(msg).foregroundStyle(.red).font(.footnote)
                }

                List {
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Добавить вручную: \(query.uppercased())") {
                            onManualAdd(query)
                            dismiss()
                        }
                    }

                    ForEach(vm.results) { s in
                        Button {
                            onPick(s)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(s.symbol).font(.headline)
                                    Spacer()
                                    Text(s.exchange).font(.caption).foregroundStyle(.secondary)
                                }
                                Text(s.name).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: .infinity)
            }
            .padding()
            .navigationTitle("Добавить акцию")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .task {
            await vm.ensureLoaded()
            // Если пользователь уже что-то ввел, повторим поиск после загрузки базы
            vm.search(query, limit: 30)
        }
        .task(id: query) {
            // debounce 200ms
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            vm.search(query, limit: 30)
        }

    }
}

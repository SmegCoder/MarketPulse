import SwiftUI

struct WatchlistView: View {
    @StateObject private var vm = WatchlistViewModel()

    @State private var showAdd = false
    @State private var searchText = ""

    enum WatchlistFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case favorites = "Favorites"
        var id: String { rawValue }
    }

    @State private var filter: WatchlistFilter = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let msg = vm.bannerMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.85))
                }
                Text("Data: \(vm.providerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)


                Picker("Filter", selection: $filter) {
                    ForEach(WatchlistFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 12)   // <-- вот он, отступ снизу


                let displayed = vm
                    .displayedTickers(searchText: searchText)
                    .filter { t in
                        filter == .all ? true : t.isFavorite
                    }

                List {
                    ForEach(displayed) { t in
                        NavigationLink {
                            TickerDetailView(ticker: t)
                        } label: {
                            TickerRowView(ticker: t) {
                                vm.toggleFavorite(symbol: t.symbol)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                vm.toggleFavorite(symbol: t.symbol)
                            } label: {
                                Label(
                                    t.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: t.isFavorite ? "star.slash" : "star"
                                )
                            }
                            .tint(.yellow)
                        }
                    }

                    .onDelete { offsets in
                        // offsets относятся к displayed, поэтому удаляем по символам
                        let symbols = offsets.map { displayed[$0].symbol }
                        vm.deleteBySymbols(symbols)
                    }
                }
                .refreshable {
                    await vm.refreshAll(force: true)
                }
            }
            .navigationTitle("MarketPulse")

            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(vm.isRefreshing ? "Refreshing..." : "Refresh") {
                        Task { await vm.refreshAll(force: true) }
                    }
                    .disabled(vm.isRefreshing)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $vm.sortOption) {
                            ForEach(SortOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }

                        Divider()

                        Button(vm.sortAscending ? "Descending" : "Ascending") {
                            vm.sortAscending.toggle()
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTickerSheetView(
                    onPick: { s in
                        vm.add(symbol: s.symbol, name: s.name)
                    },
                    onManualAdd: { raw in
                        vm.add(symbol: raw)
                    }
                )
            }
        }
        .task {
            await vm.refreshAll(force: false)
        }
        .searchable(text: $searchText, prompt: "Search symbol or name")
    }
}

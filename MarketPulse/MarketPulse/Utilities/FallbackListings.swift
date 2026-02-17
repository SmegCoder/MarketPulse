import Foundation

enum FallbackListings {
    static let items: [StockListing] = [
        StockListing(symbol: "AAPL", name: "Apple Inc.", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "MSFT", name: "Microsoft Corp.", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "GOOGL", name: "Alphabet Inc. (Class A)", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "AMZN", name: "Amazon.com Inc.", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "NVDA", name: "NVIDIA Corp.", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "META", name: "Meta Platforms Inc.", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "TSLA", name: "Tesla Inc.", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "AMD", name: "Advanced Micro Devices", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "INTC", name: "Intel Corp.", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "NFLX", name: "Netflix Inc.", exchange: "NASDAQ", assetType: "Stock", status: "Active"),
        StockListing(symbol: "UBER", name: "Uber Technologies", exchange: "NYSE", assetType: "Stock", status: "Active"),
        StockListing(symbol: "KO", name: "Coca-Cola Co", exchange: "NYSE", assetType: "Stock", status: "Active"),
        StockListing(symbol: "JPM", name: "JPMorgan Chase & Co", exchange: "NYSE", assetType: "Stock", status: "Active"),
        StockListing(symbol: "V", name: "Visa Inc.", exchange: "NYSE", assetType: "Stock", status: "Active"),
        StockListing(symbol: "MA", name: "Mastercard Inc.", exchange: "NYSE", assetType: "Stock", status: "Active"),
        StockListing(symbol: "SPY", name: "SPDR S&P 500 ETF Trust", exchange: "NYSEARCA", assetType: "ETF", status: "Active"),
        StockListing(symbol: "QQQ", name: "Invesco QQQ Trust", exchange: "NASDAQ", assetType: "ETF", status: "Active")
    ]
}

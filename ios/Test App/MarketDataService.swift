import Foundation

// MARK: - Market Data Service (Marketstack via Cloudflare Worker)
// Handles real-time quotes, historical prices, and 52-week metrics
class MarketDataService {
    private let apiBaseURL: String

    init(apiBaseURL: String = "https://stock-research-api.stock-research-api.workers.dev") {
        self.apiBaseURL = apiBaseURL
    }

    // MARK: - Real-Time Stock Quote
    func fetchQuote(symbol: String) async throws -> StockQuote {
        let urlString = "\(apiBaseURL)/api/quote/\(symbol.uppercased())"
        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MarketstackQuoteResponse.self, from: data)

        return StockQuote(
            symbol: response.symbol,
            currentPrice: response.currentPrice,
            change: response.change,
            changePercent: response.changePercent,
            high: response.high,
            low: response.low,
            open: response.open,
            previousClose: response.previousClose,
            volume: response.volume,
            date: response.date
        )
    }

    // MARK: - End-of-Day Historical Data
    func fetchEODData(symbol: String, limit: Int = 30) async throws -> [EODDataPoint] {
        let urlString = "\(apiBaseURL)/api/eod/\(symbol.uppercased())?limit=\(limit)"
        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([MarketstackEODData].self, from: data)

        return response.map { eod in
            EODDataPoint(
                date: eod.date,
                open: eod.open,
                high: eod.high,
                low: eod.low,
                close: eod.close,
                volume: eod.volume,
                adjClose: eod.adjClose
            )
        }
    }

    // MARK: - 52-Week High/Low
    func fetch52WeekRange(symbol: String) async throws -> (high: Double, low: Double) {
        let eodData = try await fetchEODData(symbol: symbol, limit: 252)

        guard !eodData.isEmpty else {
            throw MarketDataError.noData
        }

        let allHighs = eodData.map { $0.high }
        let allLows = eodData.map { $0.low }

        guard let high = allHighs.max(), let low = allLows.min() else {
            throw MarketDataError.invalidData
        }

        return (high: high, low: low)
    }

    // MARK: - Intraday Data (if needed for charts)
    func fetchIntradayData(symbol: String, interval: String = "1min") async throws -> [IntradayDataPoint] {
        let urlString = "\(apiBaseURL)/api/intraday/\(symbol.uppercased())?interval=\(interval)"
        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([MarketstackIntradayData].self, from: data)

        return response.map { intraday in
            IntradayDataPoint(
                date: intraday.date,
                open: intraday.open,
                high: intraday.high,
                low: intraday.low,
                close: intraday.close,
                volume: intraday.volume
            )
        }
    }
}

// MARK: - Data Models

struct StockQuote {
    let symbol: String
    let currentPrice: Double
    let change: Double
    let changePercent: Double
    let high: Double
    let low: Double
    let open: Double
    let previousClose: Double
    let volume: Int
    let date: String
}

struct EODDataPoint: Identifiable {
    let id = UUID()
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
    let adjClose: Double
}

struct IntradayDataPoint: Identifiable {
    let id = UUID()
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

// MARK: - Marketstack Response Models

struct MarketstackQuoteResponse: Codable {
    let symbol: String
    let currentPrice: Double
    let open: Double
    let high: Double
    let low: Double
    let volume: Int
    let previousClose: Double
    let change: Double
    let changePercent: Double
    let date: String
}

struct MarketstackEODData: Codable {
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
    let adjClose: Double
}

struct MarketstackIntradayData: Codable {
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

// MARK: - Errors

enum MarketDataError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidData
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for market data request"
        case .noData:
            return "No market data available"
        case .invalidData:
            return "Invalid market data received"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

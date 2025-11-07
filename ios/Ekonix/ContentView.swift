import SwiftUI
import SwiftData

// MARK: - API Constants
private enum APIConstants {
    static let cloudflareBaseURL = "https://stock-research-api.stock-research-api.workers.dev"
}

// MARK: - Stock API Service (Using Your Cloudflare API)
class StockAPIService {
    private let apiBaseURL = APIConstants.cloudflareBaseURL
    
    // MARK: - Basic Company Info (For add stock search)
    // Uses SEC data to verify ticker exists
    func searchStock(symbol: String) async throws -> String {
        // Just verify the symbol exists by trying to fetch revenue data
        let _ = try await fetchRevenue(symbol: symbol)
        return symbol.uppercased()
    }

    // MARK: - Ticker Suggestions (For autocomplete)
    func fetchAllTickers() async throws -> [TickerSuggestion] {
        let urlString = "\(apiBaseURL)/api/tickers"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([TickerSuggestion].self, from: data)
    }

    // MARK: - Revenue Data (From Your API)
    func fetchRevenue(symbol: String, freq: String = "quarterly") async throws -> [RevenueDataPoint] {
        let urlString = "\(apiBaseURL)/api/revenue/\(symbol.uppercased())"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APIRevenueResponse: Codable {
            let period: String
            let revenue: Double
        }

        let revenueData = try JSONDecoder().decode([APIRevenueResponse].self, from: data)

        // Debug: Print first few periods to verify format
        #if DEBUG
        if !revenueData.isEmpty {
            print("📊 Quarterly Revenue data for \(symbol):")
            revenueData.prefix(3).forEach { item in
                let formatted = ChartUtilities.formatQuarterDate(item.period)
                print("  Raw: \(item.period) -> Formatted: \(formatted)")
            }
        }
        #endif

        return revenueData.map {
            RevenueDataPoint(period: $0.period, revenue: $0.revenue)
        }
    }
    
    // MARK: - TTM Revenue Data (From Your API)
    func fetchTTMRevenue(symbol: String) async throws -> [RevenueDataPoint] {
        let urlString = "\(apiBaseURL)/api/revenue-ttm/\(symbol.uppercased())"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APIRevenueResponse: Codable {
            let period: String
            let revenue: Double
        }

        let revenueData = try JSONDecoder().decode([APIRevenueResponse].self, from: data)

        // Debug: Print first few periods to verify format
        #if DEBUG
        if !revenueData.isEmpty {
            print("📊 TTM Revenue data for \(symbol):")
            revenueData.prefix(3).forEach { item in
                let formatted = ChartUtilities.formatQuarterDate(item.period)
                print("  Raw: \(item.period) -> Formatted: \(formatted)")
            }
        }
        #endif

        return revenueData.map {
            RevenueDataPoint(period: $0.period, revenue: $0.revenue)
        }
    }

    // MARK: - Earnings Data (From Your API)
    func fetchNetIncome(symbol: String) async throws -> [NetIncomeDataPoint] {
        let urlString = "\(apiBaseURL)/api/earnings/\(symbol.uppercased())"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APINetIncomeResponse: Codable {
            let period: String
            let earnings: Double  // Backend returns "earnings" field

            // Map to our internal naming
            var netIncome: Double { earnings }
        }

        let netIncomeData = try JSONDecoder().decode([APINetIncomeResponse].self, from: data)

        // Debug: Print first few periods to verify format
        #if DEBUG
        if !netIncomeData.isEmpty {
            print("📊 Quarterly Net Income data for \(symbol):")
            netIncomeData.prefix(3).forEach { item in
                let formatted = ChartUtilities.formatQuarterDate(item.period)
                print("  Raw: \(item.period) -> Formatted: \(formatted)")
            }
        }
        #endif

        return netIncomeData.map {
            NetIncomeDataPoint(period: $0.period, netIncome: $0.netIncome)
        }
    }

    // MARK: - TTM Earnings Data (From Your API)
    func fetchTTMNetIncome(symbol: String) async throws -> [NetIncomeDataPoint] {
        let urlString = "\(apiBaseURL)/api/earnings-ttm/\(symbol.uppercased())"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APINetIncomeResponse: Codable {
            let period: String
            let earnings: Double  // Backend returns "earnings" field

            // Map to our internal naming
            var netIncome: Double { earnings }
        }

        let netIncomeData = try JSONDecoder().decode([APINetIncomeResponse].self, from: data)

        // Debug: Print first few periods to verify format
        #if DEBUG
        if !netIncomeData.isEmpty {
            print("📊 TTM Net Income data for \(symbol):")
            netIncomeData.prefix(3).forEach { item in
                let formatted = ChartUtilities.formatQuarterDate(item.period)
                print("  Raw: \(item.period) -> Formatted: \(formatted)")
            }
        }
        #endif

        return netIncomeData.map {
            NetIncomeDataPoint(period: $0.period, netIncome: $0.netIncome)
        }
    }

    // MARK: - Operating Income Data (From Your API)
    func fetchOperatingIncome(symbol: String) async throws -> [OperatingIncomeDataPoint] {
        let urlString = "\(apiBaseURL)/api/operating-income/\(symbol.uppercased())"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APIOperatingIncomeResponse: Codable {
            let period: String
            let operatingIncome: Double
        }

        let operatingIncomeData = try JSONDecoder().decode([APIOperatingIncomeResponse].self, from: data)

        #if DEBUG
        if !operatingIncomeData.isEmpty {
            print("📊 Quarterly Operating Income data for \(symbol):")
            operatingIncomeData.prefix(3).forEach { item in
                let formatted = ChartUtilities.formatQuarterDate(item.period)
                print("  Raw: \(item.period) -> Formatted: \(formatted)")
            }
        }
        #endif

        return operatingIncomeData.map {
            OperatingIncomeDataPoint(period: $0.period, operatingIncome: $0.operatingIncome)
        }
    }

    // MARK: - TTM Operating Income Data (From Your API)
    func fetchTTMOperatingIncome(symbol: String) async throws -> [OperatingIncomeDataPoint] {
        let urlString = "\(apiBaseURL)/api/operating-income-ttm/\(symbol.uppercased())"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APIOperatingIncomeResponse: Codable {
            let period: String
            let operatingIncome: Double
        }

        let operatingIncomeData = try JSONDecoder().decode([APIOperatingIncomeResponse].self, from: data)

        #if DEBUG
        if !operatingIncomeData.isEmpty {
            print("📊 TTM Operating Income data for \(symbol):")
            operatingIncomeData.prefix(3).forEach { item in
                let formatted = ChartUtilities.formatQuarterDate(item.period)
                print("  Raw: \(item.period) -> Formatted: \(formatted)")
            }
        }
        #endif

        return operatingIncomeData.map {
            OperatingIncomeDataPoint(period: $0.period, operatingIncome: $0.operatingIncome)
        }
    }

    // MARK: - Gross Profit Data (From Your API)
    func fetchGrossProfit(symbol: String) async throws -> [GrossProfitDataPoint] {
        let urlString = "\(apiBaseURL)/api/gross-profit/\(symbol.uppercased())"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APIGrossProfitResponse: Codable {
            let period: String
            let grossProfit: Double
            let isRevenueFallback: Bool?
        }

        let grossProfitData = try JSONDecoder().decode([APIGrossProfitResponse].self, from: data)

        #if DEBUG
        if !grossProfitData.isEmpty {
            print("📊 Gross Profit data for \(symbol):")
            grossProfitData.prefix(3).forEach { item in
                let formatted = ChartUtilities.formatQuarterDate(item.period)
                print("  Raw: \(item.period) -> Formatted: \(formatted)")
            }
        }
        #endif

        return grossProfitData.map {
            GrossProfitDataPoint(period: $0.period, grossProfit: $0.grossProfit, isRevenueFallback: $0.isRevenueFallback)
        }
    }

    // MARK: - TTM Gross Profit Data (From Your API)
    func fetchTTMGrossProfit(symbol: String) async throws -> [GrossProfitDataPoint] {
        let urlString = "\(apiBaseURL)/api/gross-profit-ttm/\(symbol.uppercased())"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct APIGrossProfitResponse: Codable {
            let period: String
            let grossProfit: Double
            let isRevenueFallback: Bool?
        }

        let grossProfitData = try JSONDecoder().decode([APIGrossProfitResponse].self, from: data)

        #if DEBUG
        if !grossProfitData.isEmpty {
            print("📊 TTM Gross Profit data for \(symbol):")
            grossProfitData.prefix(3).forEach { item in
                let formatted = ChartUtilities.formatQuarterDate(item.period)
                print("  Raw: \(item.period) -> Formatted: \(formatted)")
            }
        }
        #endif

        return grossProfitData.map {
            GrossProfitDataPoint(period: $0.period, grossProfit: $0.grossProfit, isRevenueFallback: $0.isRevenueFallback)
        }
    }

}

// MARK: - Combined Revenue Charts View (Quarterly + TTM + YoY Growth)
struct RevenueChartsView: View {
    let symbol: String
    let apiService: StockAPIService
    
    @State private var quarterlyData: [RevenueDataPoint] = []
    @State private var ttmData: [RevenueDataPoint] = []
    @State private var yoyData: [RevenueDataPoint] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RevenueChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    quarterlyData = data
                })
                
                Divider()
                    .padding(.vertical, 20)
                
                TTMRevenueChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    ttmData = data
                })
                
                Divider()
                    .padding(.vertical, 20)
                
                YoYGrowthChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    yoyData = data
                })
                
                // Combined Revenue Details Table
                if !quarterlyData.isEmpty || !ttmData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Revenue Details")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 0) {
                            // Fixed Quarter Column
                            VStack(spacing: 0) {
                                // Header
                                Text("Quarter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                    .padding(.vertical, 8)

                                Divider()

                                // Quarter labels
                                ForEach(0..<min(max(quarterlyData.count, ttmData.count), 40), id: \.self) { index in
                                    VStack(spacing: 0) {
                                        if index < quarterlyData.count {
                                            Text(formatDate(quarterlyData[index].period))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                                .frame(width: 80, alignment: .leading)
                                                .padding(.vertical, 8)
                                        } else {
                                            Text("-")
                                                .font(.caption)
                                                .frame(width: 80, alignment: .leading)
                                                .padding(.vertical, 8)
                                        }

                                        if index < min(max(quarterlyData.count, ttmData.count), 40) - 1 {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 16)

                            // Scrollable Data Columns
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Header Row
                                    HStack(spacing: 0) {
                                        Text("Quarterly")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("TTM")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("YoY")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.trailing, 16)

                                    Divider()

                                    // Data Rows
                                    ForEach(0..<min(max(quarterlyData.count, ttmData.count), 40), id: \.self) { index in
                                        VStack(spacing: 0) {
                                            HStack(spacing: 0) {
                                                // Quarterly value
                                                if index < quarterlyData.count {
                                                    Text(formatValue(quarterlyData[index].revenue))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.blue)
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                // TTM value
                                                if index < ttmData.count {
                                                    Text(formatValue(ttmData[index].revenue))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(Color(red: 1.0, green: 0.0, blue: 1.0))
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                // YoY % value (compare TTM to 4 periods ago)
                                                if index + 4 < ttmData.count,
                                                   ttmData[index + 4].revenue != 0 {
                                                    let current = ttmData[index].revenue
                                                    let prior = ttmData[index + 4].revenue
                                                    let yoy = ((current - prior) / prior) * 100
                                                    Text(String(format: "%+.1f%%", yoy))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(yoy >= 0 ? .green : .red)
                                                        .frame(width: 80, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 80, alignment: .trailing)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.trailing, 16)

                                            if index < min(max(quarterlyData.count, ttmData.count), 40) - 1 {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        ChartUtilities.formatQuarterDate(dateString)
    }

    private func formatValue(_ value: Double) -> String {
        ChartUtilities.formatCurrencyValue(value)
    }
}

// MARK: - TTM Revenue Chart View

// MARK: - Combined Net Income Charts View (Quarterly + TTM + YoY Growth)
struct NetIncomeChartsView: View {
    let symbol: String
    let apiService: StockAPIService

    @State private var quarterlyData: [NetIncomeDataPoint] = []
    @State private var ttmData: [NetIncomeDataPoint] = []
    @State private var yoyData: [NetIncomeDataPoint] = []
    @State private var isLoading = false

    // Pre-calculated table data for performance
    struct TableRowData: Identifiable {
        let id = UUID()
        let period: String
        let quarterlyNetIncome: Double?
        let ttmNetIncome: Double?
        let yoyPercent: Double?
    }

    var tableData: [TableRowData] {
        let maxRows = min(max(quarterlyData.count, ttmData.count), 40)
        guard maxRows > 0 else { return [] }

        var rows: [TableRowData] = []
        for index in 0..<maxRows {
            let quarterly = index < quarterlyData.count ? quarterlyData[index] : nil
            let ttm = index < ttmData.count ? ttmData[index] : nil

            // Calculate YoY using TTM data if possible
            var yoy: Double? = nil
            if let ttm = ttm,
               index + 4 < ttmData.count,
               ttmData[index + 4].netIncome != 0 {
                let prior = ttmData[index + 4].netIncome
                yoy = ((ttm.netIncome - prior) / prior) * 100
            }

            rows.append(TableRowData(
                period: quarterly?.period ?? ttm?.period ?? "",
                quarterlyNetIncome: quarterly?.netIncome,
                ttmNetIncome: ttm?.netIncome,
                yoyPercent: yoy
            ))
        }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                NetIncomeChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    quarterlyData = data
                })

                Divider()
                    .padding(.vertical, 20)

                TTMNetIncomeChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    ttmData = data
                })

                Divider()
                    .padding(.vertical, 20)

                YoYNetIncomeGrowthChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    yoyData = data
                })

                // Combined Net Income Details Table
                if !tableData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Net Income Details")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 0) {
                            // Fixed Quarter Column
                            VStack(spacing: 0) {
                                // Header
                                Text("Quarter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                    .padding(.vertical, 8)

                                Divider()

                                // Quarter labels
                                ForEach(tableData) { row in
                                    VStack(spacing: 0) {
                                        Text(formatDate(row.period))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                            .frame(width: 80, alignment: .leading)
                                            .padding(.vertical, 8)

                                        if row.id != tableData.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 16)

                            // Scrollable Data Columns
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Header Row
                                    HStack(spacing: 0) {
                                        Text("Quarterly")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("TTM")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("YoY")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.trailing, 16)

                                    Divider()

                                    // Data Rows - simplified with pre-calculated values
                                    ForEach(tableData) { row in
                                        VStack(spacing: 0) {
                                            HStack(spacing: 0) {
                                                // Quarterly value
                                                if let netIncome = row.quarterlyNetIncome {
                                                    Text(formatValue(netIncome))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(netIncome >= 0 ? .blue : .red)
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                // TTM value
                                                if let ttmNetIncome = row.ttmNetIncome {
                                                    Text(formatValue(ttmNetIncome))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(ttmNetIncome >= 0 ? Color(red: 1.0, green: 0.0, blue: 1.0) : .red)
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                // YoY % value (pre-calculated)
                                                if let yoy = row.yoyPercent {
                                                    Text(String(format: "%+.1f%%", yoy))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(yoy >= 0 ? .green : .red)
                                                        .frame(width: 80, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 80, alignment: .trailing)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.trailing, 16)

                                            if row.id != tableData.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        ChartUtilities.formatQuarterDate(dateString)
    }

    private func formatValue(_ value: Double) -> String {
        ChartUtilities.formatCurrencyValue(value)
    }
}

// MARK: - Combined Operating Income Charts View (Quarterly + TTM + YoY Growth)
struct OperatingIncomeChartsView: View {
    let symbol: String
    let apiService: StockAPIService

    @State private var quarterlyData: [OperatingIncomeDataPoint] = []
    @State private var ttmData: [OperatingIncomeDataPoint] = []
    @State private var yoyData: [OperatingIncomeDataPoint] = []
    @State private var isLoading = false

    // Pre-calculated table data for performance
    struct TableRowData: Identifiable {
        let id = UUID()
        let period: String
        let quarterlyOperatingIncome: Double?
        let ttmOperatingIncome: Double?
        let yoyPercent: Double?
    }

    var tableData: [TableRowData] {
        let maxRows = min(max(quarterlyData.count, ttmData.count), 40)
        guard maxRows > 0 else { return [] }

        var rows: [TableRowData] = []
        for index in 0..<maxRows {
            let quarterly = index < quarterlyData.count ? quarterlyData[index] : nil
            let ttm = index < ttmData.count ? ttmData[index] : nil

            // Calculate YoY using TTM data if possible
            var yoy: Double? = nil
            if let ttm = ttm,
               index + 4 < ttmData.count,
               ttmData[index + 4].operatingIncome != 0 {
                let prior = ttmData[index + 4].operatingIncome
                yoy = ((ttm.operatingIncome - prior) / prior) * 100
            }

            rows.append(TableRowData(
                period: quarterly?.period ?? ttm?.period ?? "",
                quarterlyOperatingIncome: quarterly?.operatingIncome,
                ttmOperatingIncome: ttm?.operatingIncome,
                yoyPercent: yoy
            ))
        }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                OperatingIncomeChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    quarterlyData = data
                })

                Divider()
                    .padding(.vertical, 20)

                TTMOperatingIncomeChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    ttmData = data
                })

                Divider()
                    .padding(.vertical, 20)

                YoYOperatingIncomeGrowthChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    yoyData = data
                })

                // Combined Operating Income Details Table
                if !tableData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Operating Income Details")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 0) {
                            // Fixed Quarter Column
                            VStack(spacing: 0) {
                                // Header
                                Text("Quarter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                    .padding(.vertical, 8)

                                Divider()

                                // Quarter labels
                                ForEach(tableData) { row in
                                    VStack(spacing: 0) {
                                        Text(formatDate(row.period))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                            .frame(width: 80, alignment: .leading)
                                            .padding(.vertical, 8)

                                        if row.id != tableData.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 16)

                            // Scrollable Data Columns
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Header Row
                                    HStack(spacing: 0) {
                                        Text("Quarterly")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("TTM")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("YoY")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.trailing, 16)

                                    Divider()

                                    // Data Rows - simplified with pre-calculated values
                                    ForEach(tableData) { row in
                                        VStack(spacing: 0) {
                                            HStack(spacing: 0) {
                                                // Quarterly value
                                                if let operatingIncome = row.quarterlyOperatingIncome {
                                                    Text(formatValue(operatingIncome))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(operatingIncome >= 0 ? .blue : .red)
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                // TTM value
                                                if let ttmOperatingIncome = row.ttmOperatingIncome {
                                                    Text(formatValue(ttmOperatingIncome))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(ttmOperatingIncome >= 0 ? .blue : .red)
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                // YoY % value (pre-calculated)
                                                if let yoy = row.yoyPercent {
                                                    Text(String(format: "%+.1f%%", yoy))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(yoy >= 0 ? .green : .red)
                                                        .frame(width: 80, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 80, alignment: .trailing)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.trailing, 16)

                                            if row.id != tableData.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        ChartUtilities.formatQuarterDate(dateString)
    }

    private func formatValue(_ value: Double) -> String {
        ChartUtilities.formatCurrencyValue(value)
    }
}

// MARK: - Combined Gross Profit Charts View (Quarterly + TTM + YoY Growth)
struct GrossProfitChartsView: View {
    let symbol: String
    let apiService: StockAPIService

    @State private var quarterlyData: [GrossProfitDataPoint] = []
    @State private var ttmData: [GrossProfitDataPoint] = []
    @State private var yoyData: [GrossProfitDataPoint] = []
    @State private var isLoading = false

    // Pre-calculated table data for performance
    struct TableRowData: Identifiable {
        let id = UUID()
        let period: String
        let quarterlyGrossProfit: Double?
        let ttmGrossProfit: Double?
        let yoyPercent: Double?
    }

    var tableData: [TableRowData] {
        let maxRows = min(max(quarterlyData.count, ttmData.count), 40)
        guard maxRows > 0 else { return [] }

        var rows: [TableRowData] = []
        for index in 0..<maxRows {
            let quarterly = index < quarterlyData.count ? quarterlyData[index] : nil
            let ttm = index < ttmData.count ? ttmData[index] : nil

            // Calculate YoY using TTM data if possible
            var yoy: Double? = nil
            if let ttm = ttm,
               index + 4 < ttmData.count,
               ttmData[index + 4].grossProfit != 0 {
                let prior = ttmData[index + 4].grossProfit
                yoy = ((ttm.grossProfit - prior) / prior) * 100
            }

            rows.append(TableRowData(
                period: quarterly?.period ?? ttm?.period ?? "",
                quarterlyGrossProfit: quarterly?.grossProfit,
                ttmGrossProfit: ttm?.grossProfit,
                yoyPercent: yoy
            ))
        }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GrossProfitChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    quarterlyData = data
                })

                Divider()
                    .padding(.vertical, 20)

                TTMGrossProfitChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    ttmData = data
                })

                Divider()
                    .padding(.vertical, 20)

                YoYGrossProfitGrowthChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    yoyData = data
                })

                // Combined Gross Profit Details Table
                if !tableData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gross Profit Details")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 0) {
                            // Fixed Quarter Column
                            VStack(spacing: 0) {
                                // Header
                                Text("Quarter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                    .padding(.vertical, 8)

                                Divider()

                                // Quarter labels
                                ForEach(tableData) { row in
                                    VStack(spacing: 0) {
                                        Text(formatDate(row.period))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                            .frame(width: 80, alignment: .leading)
                                            .padding(.vertical, 8)

                                        if row.id != tableData.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 16)

                            // Scrollable Data Columns
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Header Row
                                    HStack(spacing: 0) {
                                        Text("Quarterly")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("TTM")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("YoY")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.trailing, 16)

                                    Divider()

                                    // Data Rows - simplified with pre-calculated values
                                    ForEach(tableData) { row in
                                        VStack(spacing: 0) {
                                            HStack(spacing: 0) {
                                                // Quarterly value
                                                if let grossProfit = row.quarterlyGrossProfit {
                                                    Text(formatValue(grossProfit))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(grossProfit >= 0 ? .blue : .red)
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                // TTM value
                                                if let ttmGrossProfit = row.ttmGrossProfit {
                                                    Text(formatValue(ttmGrossProfit))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(ttmGrossProfit >= 0 ? .blue : .red)
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                // YoY % value (pre-calculated)
                                                if let yoy = row.yoyPercent {
                                                    Text(String(format: "%+.1f%%", yoy))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(yoy >= 0 ? .green : .red)
                                                        .frame(width: 80, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 80, alignment: .trailing)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.trailing, 16)

                                            if row.id != tableData.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        ChartUtilities.formatQuarterDate(dateString)
    }

    private func formatValue(_ value: Double) -> String {
        ChartUtilities.formatCurrencyValue(value)
    }
}

// MARK: - App Data Models

struct StockProfile: Codable {
    let name: String
    let ticker: String
    let marketCapitalization: Double?
    let shareOutstanding: Double?
    let logo: String?
    let country: String?
    let currency: String?
    let exchange: String?
    let ipo: String?
    let industry: String?
    let weburl: String?
}

struct NewsArticle: Codable, Identifiable {
    let id: Int
    let headline: String
    let summary: String
    let source: String
    let url: String
    let datetime: Int
    let image: String?
    let related: String?
}

struct RevenueDataPoint: Identifiable {
    let id = UUID()
    let period: String
    let revenue: Double
}

struct NetIncomeDataPoint: Identifiable {
    let id = UUID()
    let period: String
    let netIncome: Double
}

struct OperatingIncomeDataPoint: Identifiable {
    let id = UUID()
    let period: String
    let operatingIncome: Double
}

struct GrossProfitDataPoint: Identifiable, Codable {
    let id: UUID
    let period: String
    let grossProfit: Double
    let isRevenueFallback: Bool?

    enum CodingKeys: String, CodingKey {
        case period
        case grossProfit
        case isRevenueFallback
    }

    init(period: String, grossProfit: Double, isRevenueFallback: Bool? = nil) {
        self.id = UUID()
        self.period = period
        self.grossProfit = grossProfit
        self.isRevenueFallback = isRevenueFallback
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.period = try container.decode(String.self, forKey: .period)
        self.grossProfit = try container.decode(Double.self, forKey: .grossProfit)
        self.isRevenueFallback = try container.decodeIfPresent(Bool.self, forKey: .isRevenueFallback)
    }
}

struct TickerSuggestion: Identifiable, Codable {
    let id = UUID()
    let ticker: String
    let name: String
    let cik: String

    enum CodingKeys: String, CodingKey {
        case ticker, name, cik
    }
}

struct CompanyMetrics {
    var week52High: Double?
    var week52Low: Double?
    var marketCap: Double?
    var peRatio: Double?
    var beta: Double?
    var dividendYield: Double?
}

enum APIError: Error {
    case invalidURL
    case noData
}

// MARK: - Main Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [ResearchItem]
    
    @State private var selectedTab = 0
    @State private var showingAddStock = false
    
    var watchlistItems: [ResearchItem] {
        items.filter { $0.isWatchlist }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ResearchListView(
                items: items,
                showingAddStock: $showingAddStock
            )
            .tabItem {
                Label("Research", systemImage: "magnifyingglass")
            }
            .tag(0)
            
            WatchlistView(
                items: watchlistItems,
                showingAddStock: $showingAddStock
            )
            .tabItem {
                Label("Watchlist", systemImage: "star.fill")
            }
            .tag(1)
            
            MarketNewsView()
                .tabItem {
                    Label("News", systemImage: "newspaper")
                }
                .tag(2)
            
            DiscoverView(showingAddStock: $showingAddStock)
                .tabItem {
                    Label("Discover", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)
        }
        .sheet(isPresented: $showingAddStock) {
            AddStockView(modelContext: modelContext)
        }
    }
}

// MARK: - Research List View
struct ResearchListView: View {
    @Environment(\.modelContext) private var modelContext
    let items: [ResearchItem]
    @Binding var showingAddStock: Bool
    
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    @State private var sortOption: SortOption = .dateAdded
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case rated = "Rated"
        case unrated = "Unrated"
        case watchlist = "Watchlist"
    }
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case symbol = "Symbol"
        case rating = "Rating"
        case priceChange = "Price Change"
    }
    
    var filteredAndSortedItems: [ResearchItem] {
        var filtered = items
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.symbol.lowercased().contains(searchText.lowercased()) ||
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
        
        switch selectedFilter {
        case .all:
            break
        case .rated:
            filtered = filtered.filter { $0.rating > 0 }
        case .unrated:
            filtered = filtered.filter { $0.rating == 0 }
        case .watchlist:
            filtered = filtered.filter { $0.isWatchlist }
        }
        
        switch sortOption {
        case .dateAdded:
            filtered.sort { $0.dateAdded > $1.dateAdded }
        case .symbol:
            filtered.sort { $0.symbol < $1.symbol }
        case .rating:
            filtered.sort { $0.rating > $1.rating }
        case .priceChange:
            filtered.sort { $0.priceChangePercent > $1.priceChangePercent }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 70))
                            .foregroundStyle(.blue.opacity(0.5))
                        Text("No Research Yet")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Start researching stocks")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    List {
                        Section {
                            Picker("Filter", selection: $selectedFilter) {
                                ForEach(FilterOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Picker("Sort by", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        }
                        
                        Section {
                            ForEach(filteredAndSortedItems) { item in
                                NavigationLink(destination: StockDetailView(item: item)) {
                                    ResearchRowView(item: item)
                                }
                            }
                            .onDelete(perform: deleteItems)
                        }

                        // SEC Attribution Footer
                        Section {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Data sourced from the U.S. Securities and Exchange Commission (SEC)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 4)

                                Text("For research and educational purposes only. Not investment advice.")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .navigationTitle("Research")
            .searchable(text: $searchText, prompt: "Search stocks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddStock = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let filtered = filteredAndSortedItems
            if let itemToDelete = items.first(where: { $0.id == filtered[index].id }) {
                modelContext.delete(itemToDelete)
            }
        }
    }
}

// MARK: - Research Row View
struct ResearchRowView: View {
    let item: ResearchItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.symbol.uppercased())
                            .font(.headline)
                            .fontWeight(.bold)

                        if item.isWatchlist {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if item.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < item.rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(index < item.rating ? .yellow : .gray)
                        }
                    }
                }
            }

            HStack {
                if !item.tags.isEmpty {
                    ForEach(item.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }

                Spacer()

                Text(item.dateAdded, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Watchlist View
struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    let items: [ResearchItem]
    @Binding var showingAddStock: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 70))
                            .foregroundStyle(.yellow.opacity(0.5))
                        Text("No Watchlist Items")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Add stocks to track them")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    List {
                        ForEach(items.sorted { $0.symbol < $1.symbol }) { item in
                            NavigationLink(destination: StockDetailView(item: item)) {
                                WatchlistRowView(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddStock = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct WatchlistRowView: View {
    let item: ResearchItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.symbol.uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                Text(item.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if item.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<item.rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                if !item.tags.isEmpty {
                    Text("\(item.tags.count) tag\(item.tags.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Market News View
struct MarketNewsView: View {
    @State private var newsArticles: [NewsArticle] = []
    @State private var isLoading = false
    
    private let apiService = StockAPIService()
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && newsArticles.isEmpty {
                    ProgressView()
                } else if newsArticles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 70))
                            .foregroundStyle(.blue.opacity(0.5))
                        Text("No News Available")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("News feature coming soon!")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    List(newsArticles) { article in
                        NewsRowView(article: article)
                    }
                    .refreshable {
                        loadNews()
                    }
                }
            }
            .navigationTitle("Market News")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: loadNews) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if newsArticles.isEmpty {
                    loadNews()
                }
            }
        }
    }
    
    private func loadNews() {
        isLoading = true

        Task {
            // News feature removed - SEC data only
            await MainActor.run {
                newsArticles = []
                isLoading = false
            }
        }
    }
}

struct NewsRowView: View {
    let article: NewsArticle
    
    var body: some View {
        Link(destination: URL(string: article.url)!) {
            VStack(alignment: .leading, spacing: 8) {
                Text(article.headline)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(article.source)
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    Text(Date(timeIntervalSince1970: TimeInterval(article.datetime)), style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Discover View
struct DiscoverView: View {
    @Binding var showingAddStock: Bool
    
    let popularStocks = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA", "BRK.B", "JPM", "V"]
    let techStocks = ["AAPL", "MSFT", "GOOGL", "NVDA", "META", "AMD", "INTC", "CRM", "ADBE", "ORCL"]
    let financialStocks = ["JPM", "BAC", "WFC", "GS", "MS", "C", "BLK", "SCHW", "AXP", "USB"]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Popular Stocks") {
                    ForEach(popularStocks, id: \.self) { symbol in
                        QuickAddRow(symbol: symbol, showingAddStock: $showingAddStock)
                    }
                }
                
                Section("Technology") {
                    ForEach(techStocks, id: \.self) { symbol in
                        QuickAddRow(symbol: symbol, showingAddStock: $showingAddStock)
                    }
                }
                
                Section("Financials") {
                    ForEach(financialStocks, id: \.self) { symbol in
                        QuickAddRow(symbol: symbol, showingAddStock: $showingAddStock)
                    }
                }
            }
            .navigationTitle("Discover")
        }
    }
}

struct QuickAddRow: View {
    let symbol: String
    @Binding var showingAddStock: Bool
    
    var body: some View {
        HStack {
            Text(symbol)
                .font(.headline)
            
            Spacer()
            
            Button(action: { showingAddStock = true }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Add Stock View
struct AddStockView: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext

    @State private var symbol = ""
    @State private var name = ""
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var allTickers: [TickerSuggestion] = []
    @State private var filteredSuggestions: [TickerSuggestion] = []
    @State private var showSuggestions = false
    @State private var isLoadingTickers = false

    private let apiService = StockAPIService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Stock Symbol or Company Name") {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            TextField("Symbol or company name (e.g., AAPL or Apple)", text: $symbol)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .onChange(of: symbol) { _, newValue in
                                    searchError = nil
                                    filterSuggestions(query: newValue)
                                }

                            if isSearching {
                                ProgressView()
                            }
                        }

                        // Autocomplete dropdown
                        if showSuggestions && !filteredSuggestions.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(filteredSuggestions.prefix(10)) { suggestion in
                                    Button(action: {
                                        selectSuggestion(suggestion)
                                    }) {
                                        HStack(alignment: .center, spacing: 8) {
                                            Text(suggestion.ticker)
                                                .font(.body)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.primary)

                                            Text(suggestion.name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)

                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)

                                    if suggestion.id != filteredSuggestions.prefix(10).last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(8)
                            .padding(.top, 8)
                        }
                    }

                    if let error = searchError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if isLoadingTickers {
                        HStack {
                            ProgressView()
                            Text("Loading tickers...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !name.isEmpty {
                    Section("Stock Details") {
                        HStack {
                            Text("Symbol")
                            Spacer()
                            Text(symbol.uppercased())
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Company")
                            Spacer()
                            Text(name)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Section {
                        Text("View price charts and fundamental data after adding")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Add Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addStock()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            loadTickers()
        }
    }

    private func loadTickers() {
        isLoadingTickers = true

        Task {
            do {
                let tickers = try await apiService.fetchAllTickers()
                await MainActor.run {
                    allTickers = tickers
                    isLoadingTickers = false
                }
            } catch {
                await MainActor.run {
                    // Silent fail - autocomplete won't work but manual search still will
                    isLoadingTickers = false
                }
            }
        }
    }

    private func filterSuggestions(query: String) {
        guard !query.isEmpty, !allTickers.isEmpty else {
            filteredSuggestions = []
            showSuggestions = false
            return
        }

        let lowercased = query.lowercased()
        filteredSuggestions = allTickers.filter {
            $0.ticker.lowercased().contains(lowercased) ||
            $0.name.lowercased().contains(lowercased)
        }

        showSuggestions = !filteredSuggestions.isEmpty
    }

    private func selectSuggestion(_ suggestion: TickerSuggestion) {
        symbol = suggestion.ticker
        name = suggestion.name
        showSuggestions = false
        // Auto-validate the selected ticker
        searchStock()
    }

    private func searchStock() {
        isSearching = true
        searchError = nil

        Task {
            do {
                let validatedSymbol = try await apiService.searchStock(symbol: symbol)

                await MainActor.run {
                    symbol = validatedSymbol

                    // Fetch company name from tickers list if available
                    if let ticker = allTickers.first(where: { $0.ticker.uppercased() == validatedSymbol.uppercased() }) {
                        name = ticker.name
                    } else {
                        name = validatedSymbol  // Fallback to symbol if name not found
                    }

                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchError = "Stock not found in SEC database or no revenue data available"
                    isSearching = false
                }
            }
        }
    }

    private func addStock() {
        let newItem = ResearchItem(
            symbol: symbol,
            name: name,
            currentPrice: 0.0,
            priceChange: 0.0,
            priceChangePercent: 0.0
        )

        modelContext.insert(newItem)
        dismiss()
    }
}

// MARK: - Stock Detail View
struct StockDetailView: View {
    @Bindable var item: ResearchItem
    @State private var editingNotes = false
    @State private var newTag = ""
    @State private var showingAddTag = false
    @State private var selectedTab = 0

    private let apiService = StockAPIService()

    var body: some View {
        VStack(spacing: 0) {
            // Dropdown Menu
            Menu {
                Button(action: { selectedTab = 0 }) {
                    if selectedTab == 0 {
                        Label("Overview", systemImage: "checkmark")
                    } else {
                        Text("Overview")
                    }
                }

                Button(action: { selectedTab = 1 }) {
                    if selectedTab == 1 {
                        Label("Revenue", systemImage: "checkmark")
                    } else {
                        Text("Revenue")
                    }
                }

                Button(action: { selectedTab = 2 }) {
                    if selectedTab == 2 {
                        Label("Net Income", systemImage: "checkmark")
                    } else {
                        Text("Net Income")
                    }
                }

                Button(action: { selectedTab = 3 }) {
                    if selectedTab == 3 {
                        Label("Operating Income", systemImage: "checkmark")
                    } else {
                        Text("Operating Income")
                    }
                }

                Button(action: { selectedTab = 4 }) {
                    if selectedTab == 4 {
                        Label("Gross Profit", systemImage: "checkmark")
                    } else {
                        Text("Gross Profit")
                    }
                }
            } label: {
                HStack {
                    Text(selectedTab == 0 ? "Overview" : selectedTab == 1 ? "Revenue" : selectedTab == 2 ? "Net Income" : selectedTab == 3 ? "Operating Income" : "Gross Profit")
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
            }
            .padding()

            // Content based on selection
            ScrollView {
                if selectedTab == 0 {
                    // Overview (includes notes)
                    VStack(spacing: 0) {
                        StockOverviewSection(
                            item: item,
                            isUpdating: .constant(false),
                            showingAddTag: $showingAddTag,
                            apiService: apiService,
                            onUpdatePrice: {}
                        )

                        SectionDivider(title: "NOTES & RESEARCH")

                        StockNotesSection(
                            item: item,
                            editingNotes: $editingNotes,
                            showingAddTag: $showingAddTag,
                            newTag: $newTag,
                            onAddTag: addTag,
                            onRemoveTag: removeTag
                        )
                        .padding(.bottom, 40)
                    }
                } else if selectedTab == 1 {
                    // Revenue
                    RevenueChartsView(symbol: item.symbol, apiService: apiService)
                        .padding(.bottom, 40)
                } else if selectedTab == 2 {
                    // Net Income
                    NetIncomeChartsView(symbol: item.symbol, apiService: apiService)
                        .padding(.bottom, 40)
                } else if selectedTab == 3 {
                    // Operating Income
                    OperatingIncomeChartsView(symbol: item.symbol, apiService: apiService)
                        .padding(.bottom, 40)
                } else {
                    // Gross Profit
                    GrossProfitChartsView(symbol: item.symbol, apiService: apiService)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle(item.symbol.uppercased())
        .navigationBarTitleDisplayMode(.large)
        .alert("Add Tag", isPresented: $showingAddTag) {
            TextField("Tag name", text: $newTag)
            Button("Cancel", role: .cancel) {
                newTag = ""
            }
            Button("Add") {
                addTag()
            }
        }
    }

    private func addTag() {
        guard !newTag.isEmpty else { return }
        if !item.tags.contains(newTag) {
            item.tags.append(newTag)
        }
        newTag = ""
    }

    private func removeTag(_ tag: String) {
        item.tags.removeAll { $0 == tag }
    }
}

// MARK: - Section Pill Component
struct SectionPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Divider Component
struct SectionDivider: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 20)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Stock Overview Section
struct StockOverviewSection: View {
    @Bindable var item: ResearchItem
    @Binding var isUpdating: Bool
    @Binding var showingAddTag: Bool
    let apiService: StockAPIService
    let onUpdatePrice: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Company Info Header
            VStack(alignment: .leading, spacing: 12) {
                Text("Company Information")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    HStack {
                        Text("Symbol")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.symbol.uppercased())
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))

                    Divider().padding(.horizontal)

                    HStack {
                        Text("Company Name")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.name)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))

                    Divider().padding(.horizontal)

                    HStack {
                        Text("Added")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.dateAdded, format: .dateTime.month().day().year())
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                }
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.top, 12)

            // Research Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Research")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    HStack {
                        Text("Rating")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if item.rating > 0 {
                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < item.rating ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundStyle(index < item.rating ? .yellow : .gray)
                                }
                            }
                        } else {
                            Text("Not rated")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))

                    Divider().padding(.horizontal)

                    HStack {
                        Text("Tags")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !item.tags.isEmpty {
                            Text("\(item.tags.count) tag\(item.tags.count == 1 ? "" : "s")")
                                .fontWeight(.medium)
                        } else {
                            Text("None")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))

                    Divider().padding(.horizontal)

                    HStack {
                        Text("Notes")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !item.notes.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("None")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                }
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Stock Notes Section
struct StockNotesSection: View {
    @Bindable var item: ResearchItem
    @Binding var editingNotes: Bool
    @Binding var showingAddTag: Bool
    @Binding var newTag: String
    let onAddTag: () -> Void
    let onRemoveTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Rating
            VStack(alignment: .leading, spacing: 12) {
                Text("Rating")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { item.rating = star }) {
                            Image(systemName: star <= item.rating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(star <= item.rating ? .yellow : .gray.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)

            // Watchlist Toggle
            Toggle("Add to Watchlist", isOn: $item.isWatchlist)
                .padding(.horizontal)

            // Notes
            VStack(alignment: .leading, spacing: 12) {
                Text("Notes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if editingNotes {
                    TextEditor(text: $item.notes)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)

                    Button("Done") {
                        editingNotes = false
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                } else {
                    if item.notes.isEmpty {
                        Button {
                            editingNotes = true
                        } label: {
                            HStack {
                                Image(systemName: "note.text.badge.plus")
                                Text("Add Notes")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                    } else {
                        Text(item.notes)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(8)

                        Button("Edit") {
                            editingNotes = true
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    }
                }
            }
            .padding(.horizontal)

            // Tags
            VStack(alignment: .leading, spacing: 12) {
                Text("Tags")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if !item.tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(item.tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.caption)

                                Button(action: { onRemoveTag(tag) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .cornerRadius(16)
                        }
                    }
                }

                Button {
                    showingAddTag = true
                } label: {
                    HStack {
                        Image(systemName: "tag.fill")
                        Text("Add Tag")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in sizes {
            if lineWidth + size.width > proposal.width ?? 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            totalWidth = max(totalWidth, lineWidth)
        }

        totalHeight += lineHeight

        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0

        for index in subviews.indices {
            if lineX + sizes[index].width > bounds.maxX {
                lineY += lineHeight + spacing
                lineHeight = 0
                lineX = bounds.minX
            }

            subviews[index].place(
                at: CGPoint(x: lineX, y: lineY),
                proposal: ProposedViewSize(sizes[index])
            )

            lineHeight = max(lineHeight, sizes[index].height)
            lineX += sizes[index].width + spacing
        }
    }
}

// MARK: - Revenue Chart View

#Preview {
    ContentView()
        .modelContainer(for: ResearchItem.self, inMemory: true)
}

/*
// MARK: - Unused Legacy Views (kept for reference during redesign)
struct MetricsView_Legacy: View {
    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let metrics = metrics, let quote = currentQuote {
                VStack(spacing: 20) {
                    if let high = metrics.week52High, let low = metrics.week52Low {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("52-Week Range")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Low")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("High")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    GeometryReader { geometry in
                                        let range = high - low
                                        let position = range > 0 ? (quote.currentPrice - low) / range : 0.5
                                        let xPosition = geometry.size.width * position
                                        
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 16, height: 16)
                                            .offset(x: max(0, min(xPosition - 8, geometry.size.width - 16)))
                                    }
                                    .frame(height: 16)
                                }
                                
                                HStack {
                                    Text("$\(low, specifier: "%.2f")")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("$\(quote.currentPrice, specifier: "%.2f")")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)
                                    Spacer()
                                    Text("$\(high, specifier: "%.2f")")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Metrics")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            if let marketCap = metrics.marketCap {
                                MetricCard(title: "Market Cap", value: formatMarketCap(marketCap))
                            }
                            
                            if let pe = metrics.peRatio {
                                MetricCard(title: "P/E Ratio", value: String(format: "%.2f", pe))
                            }
                            
                            if let beta = metrics.beta {
                                MetricCard(title: "Beta", value: String(format: "%.2f", beta))
                            }
                            
                            if let dividend = metrics.dividendYield {
                                MetricCard(title: "Div Yield", value: String(format: "%.2f%%", dividend))
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Stats")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            StatRow(label: "Open", value: String(format: "$%.2f", quote.open))
                            Divider().padding(.horizontal)
                            StatRow(label: "High", value: String(format: "$%.2f", quote.high))
                            Divider().padding(.horizontal)
                            StatRow(label: "Low", value: String(format: "$%.2f", quote.low))
                            Divider().padding(.horizontal)
                            StatRow(label: "Prev Close", value: String(format: "$%.2f", quote.previousClose))
                        }
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No metrics available")
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        loadMetrics()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            loadMetrics()
        }
    }
    
    private func loadMetrics() {
        isLoading = true
        // Note: Real-time quotes and company metrics require a data provider
        // Finnhub has been removed as it's not legal for commercial use
        // Consider alternative providers like Alpha Vantage, IEX Cloud, or Polygon.io
        metrics = nil
        currentQuote = nil
        isLoading = false
    }
    
    private func formatMarketCap(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.2fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else {
            return String(format: "$%.0f", value)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .padding()
    }
}
*/

//
//  FinancialChartIntegrationExample.swift
//  Examples of how to integrate FinancialChartView with existing app
//
//  Created: 2025-10-26
//

import SwiftUI

// MARK: - Example 1: Simple Integration in ContentView

struct ChartExampleView: View {
    @State private var quarterlyRevenue: [FinancialDataPoint] = []
    @State private var ttmRevenue: [FinancialDataPoint] = []
    @State private var quarterlyNetIncome: [FinancialDataPoint] = []
    @State private var ttmNetIncome: [FinancialDataPoint] = []
    @State private var isLoading = false
    @State private var selectedMetric: MetricTab = .revenue

    let ticker = "AAPL"

    enum MetricTab: String, CaseIterable {
        case revenue = "Revenue"
        case netIncome = "Net Income"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Metric Selector
            Picker("Metric", selection: $selectedMetric) {
                ForEach(MetricTab.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if isLoading {
                ProgressView("Loading chart data...")
                    .padding()
            } else {
                ScrollView {
                    switch selectedMetric {
                    case .revenue:
                        FinancialChartView.revenue(
                            quarterly: quarterlyRevenue,
                            ttm: ttmRevenue,
                            ticker: ticker
                        )
                    case .netIncome:
                        FinancialChartView.netIncome(
                            quarterly: quarterlyNetIncome,
                            ttm: ttmNetIncome,
                            ticker: ticker
                        )
                    }
                }
            }
        }
        .task {
            await loadChartData()
        }
    }

    func loadChartData() async {
        isLoading = true
        defer { isLoading = false }

        // Load revenue and earnings data in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadRevenue() }
            group.addTask { await loadEarnings() }
        }
    }

    func loadRevenue() async {
        let apiService = StockAPIService()

        do {
            // Fetch quarterly revenue and convert to chart data
            let quarterlyResponse = try await apiService.fetchRevenue(symbol: ticker)
            quarterlyRevenue = FinancialDataPoint.fromRevenueData(quarterlyResponse)

            // Fetch TTM revenue and convert to chart data
            let ttmResponse = try await apiService.fetchTTMRevenue(symbol: ticker)
            ttmRevenue = FinancialDataPoint.fromRevenueData(ttmResponse)
        } catch {
            print("Error loading revenue: \(error)")
        }
    }

    func loadEarnings() async {
        let apiService = StockAPIService()

        do {
            // Fetch quarterly earnings and convert to chart data
            let quarterlyResponse = try await apiService.fetchNetIncome(symbol: ticker)
            quarterlyNetIncome = FinancialDataPoint.fromNetIncomeData(quarterlyResponse)

            // Fetch TTM earnings and convert to chart data
            let ttmResponse = try await apiService.fetchTTMNetIncome(symbol: ticker)
            ttmNetIncome = FinancialDataPoint.fromNetIncomeData(ttmResponse)
        } catch {
            print("Error loading earnings: \(error)")
        }
    }
}

// MARK: - Example 2: Integration with Existing ContentView

extension ContentView {
    /// Add this as a new tab or sheet in your existing ContentView
    func showFinancialChart(for ticker: String) -> some View {
        NavigationStack {
            ChartExampleView()
                .navigationTitle("Financial Charts")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Example 3: Convert Your Existing API Response to Chart Data

extension StockAPIService {
    /// Helper to fetch all chart data in parallel
    func getChartData(symbol: String) async throws -> (
        quarterlyRevenue: [FinancialDataPoint],
        ttmRevenue: [FinancialDataPoint],
        quarterlyNetIncome: [FinancialDataPoint],
        ttmNetIncome: [FinancialDataPoint]
    ) {
        // Fetch all data in parallel
        async let quarterly = fetchRevenue(symbol: symbol)
        async let ttm = fetchTTMRevenue(symbol: symbol)
        async let quarterlyEarn = fetchNetIncome(symbol: symbol)
        async let ttmEarn = fetchTTMNetIncome(symbol: symbol)

        let results = try await (quarterly, ttm, quarterlyEarn, ttmEarn)

        // Convert to chart data using helper methods
        return (
            quarterlyRevenue: FinancialDataPoint.fromRevenueData(results.0),
            ttmRevenue: FinancialDataPoint.fromRevenueData(results.1),
            quarterlyNetIncome: FinancialDataPoint.fromNetIncomeData(results.2),
            ttmNetIncome: FinancialDataPoint.fromNetIncomeData(results.3)
        )
    }
}

// MARK: - Example 4: Standalone Chart Modal

struct FinancialChartModal: View {
    let ticker: String
    @Environment(\.dismiss) private var dismiss
    @State private var chartData: ChartData?
    @State private var isLoading = true
    @State private var errorMessage: String?

    struct ChartData {
        let quarterlyRevenue: [FinancialDataPoint]
        let ttmRevenue: [FinancialDataPoint]
        let quarterlyNetIncome: [FinancialDataPoint]
        let ttmNetIncome: [FinancialDataPoint]
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                    }
                } else if let data = chartData {
                    TabView {
                        FinancialChartView.revenue(
                            quarterly: data.quarterlyRevenue,
                            ttm: data.ttmRevenue,
                            ticker: ticker
                        )
                        .tabItem {
                            Label("Revenue", systemImage: "chart.bar.fill")
                        }

                        FinancialChartView.netIncome(
                            quarterly: data.quarterlyNetIncome,
                            ttm: data.ttmNetIncome,
                            ticker: ticker
                        )
                        .tabItem {
                            Label("Earnings", systemImage: "dollarsign.circle.fill")
                        }
                    }
                }
            }
            .navigationTitle("\(ticker) Charts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let apiService = StockAPIService()
            let data = try await apiService.getChartData(symbol: ticker)

            chartData = ChartData(
                quarterlyRevenue: data.quarterlyRevenue,
                ttmRevenue: data.ttmRevenue,
                quarterlyNetIncome: data.quarterlyNetIncome,
                ttmNetIncome: data.ttmNetIncome
            )
        } catch {
            errorMessage = "Failed to load chart data: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Example 5: Add Chart Button to Your Research View

extension ContentView {
    /// Add this button to show the chart modal
    var chartButton: some View {
        Button {
            // Show chart modal
            // You'll need to add @State var showingChart = false
            // showingChart = true
        } label: {
            Label("View Charts", systemImage: "chart.xyaxis.line")
        }
        // Then add this modifier to your main view:
        // .sheet(isPresented: $showingChart) {
        //     FinancialChartModal(ticker: selectedTicker)
        // }
    }
}

// MARK: - Example 6: Inline Chart in Existing View

struct StockDetailWithChartView: View {
    let ticker: String
    @State private var showRevenue = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Your existing stock info here...

                // Add chart inline
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Financial Metrics")
                            .font(.headline)
                        Spacer()
                        Picker("", selection: $showRevenue) {
                            Text("Revenue").tag(true)
                            Text("Earnings").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    .padding(.horizontal)

                    // Chart would be loaded here with your data
                    // if showRevenue {
                    //     FinancialChartView.revenue(...)
                    // } else {
                    //     FinancialChartView.netIncome(...)
                    // }
                }

                // More content...
            }
        }
        .navigationTitle(ticker)
    }
}

// MARK: - Preview

#Preview("Chart Example View") {
    ChartExampleView()
}

#Preview("Chart Modal") {
    FinancialChartModal(ticker: "AAPL")
}

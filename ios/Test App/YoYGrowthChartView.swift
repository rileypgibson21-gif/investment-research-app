//
//  YoYGrowthChartView.swift
//  Test App
//
//  Extracted from ContentView.swift for faster compilation
//

import SwiftUI

struct YoYGrowthChartView: View {
    let symbol: String
    let apiService: StockAPIService
    var onDataLoaded: (([RevenueDataPoint]) -> Void)? = nil

    @State private var revenueData: [RevenueDataPoint] = []
    @State private var isLoading = false
    @State private var selectedBar: String?  // Changed from UUID? to String?

    struct GrowthDataPoint: Identifiable {
        let period: String
        let growthPercent: Double
        let currentRevenue: Double
        let priorRevenue: Double
        var id: String { period }  // Use period string as stable id
    }

    var growthData: [GrowthDataPoint] {
        guard revenueData.count >= 5 else { return [] }

        var growth: [GrowthDataPoint] = []
        let sortedData = revenueData.sorted { $0.period < $1.period }

        // Calculate YoY growth (comparing to 4 quarters ago)
        for i in 4..<sortedData.count {
            let current = sortedData[i]
            let prior = sortedData[i - 4]

            let growthPercent = ((current.revenue - prior.revenue) / prior.revenue) * 100

            growth.append(GrowthDataPoint(
                period: current.period,
                growthPercent: growthPercent,
                currentRevenue: current.revenue,
                priorRevenue: prior.revenue
            ))
        }

        return growth // Already in ascending order (oldest to newest)
    }

    var displayData: [GrowthDataPoint] {
        // Take the latest 36 growth periods (oldest first on left, newest on right)
        Array(growthData.suffix(ChartConstants.growthDataLimit))
    }

    var growthRange: (min: Double, max: Double) {
        let allGrowth = displayData.map { $0.growthPercent }
        let minGrowth = allGrowth.min() ?? 0
        let maxGrowth = allGrowth.max() ?? 10

        // Always show symmetric range centered at 0
        let maxAbs = max(abs(minGrowth), abs(maxGrowth))
        let range = max(ChartUtilities.roundToNiceNumber(maxAbs * 1.05), 10.0)
        return (-range, range)
    }

    private func getYAxisLabels() -> [Double] {
        let range = growthRange
        let interval = (range.max - range.min) / 4
        guard interval > 0 else { return [10, 5, 0, -5, -10] } // Default labels if no valid range
        var labels: [Double] = []
        for i in 0...4 {
            labels.append(range.max - (interval * Double(i)))
        }
        return labels
    }

    @ViewBuilder
    private var chartContentView: some View {
        ScrollView {
                    VStack(spacing: 20) {
                        // Chart with title
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Year-over-Year Growth")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)

                            HStack(alignment: .center, spacing: 8) {
                                // Fixed Y-axis on the left
                                VStack(alignment: .trailing, spacing: 0) {
                                    ForEach(Array(getYAxisLabels().enumerated()), id: \.offset) { index, value in
                                        Text(formatYAxisValue(value))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        if index < getYAxisLabels().count - 1 {
                                            Spacer()
                                        }
                                    }
                                }
                                .frame(width: ChartConstants.yAxisWidth, height: ChartConstants.chartHeight)

                                // Scrollable chart area
                                ScrollView(.horizontal, showsIndicators: false) {
                                    ScrollViewReader { proxy in
                                        VStack(spacing: 0) {
                                            // Space for tooltips above the chart
                                            Spacer()
                                                .frame(height: 60)

                                            ZStack(alignment: .center) {
                                                // Grid lines - center alignment for proper zero line
                                                VStack(spacing: 0) {
                                                    ForEach(0..<5) { index in
                                                        if index == 2 {
                                                            // Prominent zero line at exact center
                                                            Rectangle()
                                                                .fill(Color.primary.opacity(0.8))
                                                                .frame(height: 2)
                                                        } else {
                                                            Divider()
                                                                .background(Color.gray.opacity(0.2))
                                                        }
                                                        if index < 4 {
                                                            Spacer()
                                                        }
                                                    }
                                                }
                                                .frame(height: ChartConstants.chartHeight)

                                                HStack(alignment: .center, spacing: 8) {
                                                    ForEach(Array(displayData.enumerated()), id: \.element.id) { index, point in
                                                        // Bar area - split into top/bottom for perfect zero alignment
                                                        VStack(spacing: 0) {
                                                            // Top half - for positive values (bars grow upward from zero)
                                                            ZStack(alignment: .bottom) {
                                                                Color.clear
                                                                if point.growthPercent >= 0 {
                                                                    let barHeightValue = barHeight(for: point.growthPercent, in: ChartConstants.chartHeight)
                                                                    RoundedRectangle(cornerRadius: 4)
                                                                        .fill(selectedBar == point.id ? Color.green.opacity(0.8) : Color.green)
                                                                        .frame(width: 24, height: max(barHeightValue, 2))
                                                                }
                                                            }
                                                            .frame(width: 40, height: ChartConstants.chartHeight * 0.5)

                                                            // Bottom half - for negative values (bars grow downward from zero)
                                                            ZStack(alignment: .top) {
                                                                Color.clear
                                                                if point.growthPercent < 0 {
                                                                    let barHeightValue = barHeight(for: point.growthPercent, in: ChartConstants.chartHeight)
                                                                    RoundedRectangle(cornerRadius: 4)
                                                                        .fill(selectedBar == point.id ? Color.red.opacity(0.8) : Color.red)
                                                                        .frame(width: 24, height: max(barHeightValue, 2))
                                                                }
                                                            }
                                                            .frame(width: 40, height: ChartConstants.chartHeight * 0.5)
                                                        }
                                                        .frame(width: 40, height: ChartConstants.chartHeight)
                                                        .overlay(alignment: .top) {
                                                            // Tooltip positioned above the bar area
                                                            if selectedBar == point.id {
                                                                VStack(spacing: 2) {
                                                                    Text(formatDate(point.period))
                                                                        .font(.caption2)
                                                                        .fontWeight(.bold)
                                                                    Text(formatGrowthValue(point.growthPercent))
                                                                        .font(.caption2)
                                                                        .fontWeight(.semibold)
                                                                    #if DEBUG
                                                                    Text(point.period)
                                                                        .font(.system(size: 8))
                                                                        .opacity(0.7)
                                                                    #endif
                                                                }
                                                                .foregroundStyle(.white)
                                                                .padding(.horizontal, 8)
                                                                .padding(.vertical, 4)
                                                                .background(
                                                                    RoundedRectangle(cornerRadius: 6)
                                                                        .fill(point.growthPercent >= 0 ? Color.green : Color.red)
                                                                )
                                                                .fixedSize()
                                                                .offset(x: index == 0 ? 20 : (index == displayData.count - 1 ? -20 : 0), y: -55)
                                                                .transition(.opacity.combined(with: .scale))
                                                            }
                                                        }
                                                        .contentShape(Rectangle())
                                                        .onTapGesture {
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                if selectedBar == point.id {
                                                                    selectedBar = nil
                                                                } else {
                                                                    selectedBar = point.id
                                                                }
                                                            }
                                                        }
                                                        .id(point.id)
                                                    }
                                                }
                                                .padding(.horizontal, 40)
                                            }

                                            // X-axis labels
                                            HStack(alignment: .top, spacing: 8) {
                                                ForEach(displayData) { point in
                                                    Text(formatDate(point.period))
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                        .frame(width: 40)
                                                }
                                            }
                                            .padding(.top, 4)
                                            .padding(.horizontal, 40)
                                        }
                                        .onAppear {
                                            // Scroll to the rightmost position (most recent quarter)
                                            if let lastQuarter = displayData.last {
                                                Task { @MainActor in
                                                    try? await Task.sleep(nanoseconds: UInt64(ChartConstants.scrollDelay * 1_000_000_000))
                                                    proxy.scrollTo(lastQuarter.id, anchor: .trailing)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                        .padding()
                    }
                }
    }

    var body: some View {
        ZStack {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if displayData.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("Insufficient data for YoY growth")
                        .foregroundStyle(.secondary)
                    Text("Need at least 5 quarters of data")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                chartContentView
            }
        }
        .onAppear {
            if revenueData.isEmpty {
                loadRevenue()
            }
        }
    }

    private func loadRevenue() {
        isLoading = true

        Task {
            do {
                let data = try await apiService.fetchRevenue(symbol: symbol)
                await MainActor.run {
                    revenueData = data
                    onDataLoaded?(data)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    revenueData = []
                    isLoading = false
                }
            }
        }
    }

    private func barHeight(for value: Double, in totalHeight: CGFloat) -> CGFloat {
        let range = growthRange
        guard range.max > 0 else { return 4 }

        // Since zero is at 50% of the chart, bars grow from the middle
        // Calculate as proportion of the max value, using half the chart height
        let normalized = abs(value) / range.max
        return (totalHeight * 0.5) * normalized
    }

    private func zeroPosition() -> CGFloat {
        // Since growthRange is always symmetric (-X to +X), zero is always at 50%
        return 0.5
    }

    private func formatDate(_ dateString: String) -> String {
        ChartUtilities.formatQuarterDate(dateString)
    }

    private func formatGrowthValue(_ value: Double) -> String {
        ChartUtilities.formatPercentage(value)
    }

    private func formatDetailedValue(_ value: Double) -> String {
        ChartUtilities.formatCurrencyValue(value)
    }

    private func formatYAxisValue(_ value: Double) -> String {
        ChartUtilities.formatYAxisPercentage(value)
    }
}

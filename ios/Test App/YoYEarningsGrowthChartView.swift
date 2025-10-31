//
//  YoYEarningsGrowthChartView.swift
//  Test App
//
//  Extracted from ContentView.swift for faster compilation
//

import SwiftUI

struct YoYEarningsGrowthChartView: View {
    let symbol: String
    let apiService: StockAPIService
    var onDataLoaded: (([EarningsDataPoint]) -> Void)? = nil

    @State private var earningsData: [EarningsDataPoint] = []
    @State private var isLoading = false
    @State private var selectedBar: String?

    struct GrowthDataPoint: Identifiable {
        let period: String
        let growthPercent: Double
        let currentEarnings: Double
        let priorEarnings: Double
        var id: String { period }
    }

    var growthData: [GrowthDataPoint] {
        guard earningsData.count >= 5 else { return [] }

        var growth: [GrowthDataPoint] = []
        let sortedData = earningsData.sorted { $0.period < $1.period }

        // Calculate YoY growth (comparing to 4 quarters ago)
        for i in 4..<sortedData.count {
            let current = sortedData[i]
            let prior = sortedData[i - 4]

            guard prior.earnings != 0 else { continue }

            let growthPercent = ((current.earnings - prior.earnings) / prior.earnings) * 100

            growth.append(GrowthDataPoint(
                period: current.period,
                growthPercent: growthPercent,
                currentEarnings: current.earnings,
                priorEarnings: prior.earnings
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
        guard interval > 0 else { return [10, 5, 0, -5, -10] }
        var labels: [Double] = []
        for i in 0...4 {
            labels.append(range.max - (interval * Double(i)))
        }
        return labels
    }

    /// Calculate the Y position where zero line sits (as fraction of chart height from bottom)
    private var zeroLinePosition: CGFloat {
        let range = growthRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0.5 }
        // Zero position as fraction from bottom: -min / totalRange
        return CGFloat(-range.min / totalRange)
    }

    /// Calculate Y offset for a label at given index to align with gridlines
    private func yOffsetForLabel(at index: Int) -> CGFloat {
        let labels = getYAxisLabels()
        let labelCount = CGFloat(labels.count)
        let step = ChartConstants.chartHeight / (labelCount - 1)
        // Center at 0 (middle of chart), then offset based on index
        return -ChartConstants.chartHeight / 2 + (step * CGFloat(index))
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
                ScrollView {
                    VStack(spacing: 20) {
                        // Chart with title
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Year-over-Year Earnings Growth")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)

                            GeometryReader { geometry in
                                let availableWidth = geometry.size.width - ChartConstants.yAxisWidth - 16
                                let barCount = CGFloat(displayData.count)
                                let dynamicBarWidth = max((availableWidth - (barCount - 1) * ChartConstants.barSpacing) / barCount, 3)

                                HStack(alignment: .center, spacing: 8) {
                                    // Fixed Y-axis on the left - labels aligned with gridlines
                                    ZStack(alignment: .trailing) {
                                        ForEach(Array(getYAxisLabels().enumerated()), id: \.offset) { index, value in
                                            Text(formatYAxisValue(value))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .offset(y: yOffsetForLabel(at: index))
                                        }
                                    }
                                    .frame(width: ChartConstants.yAxisWidth, height: ChartConstants.chartHeight)

                                    // Chart area - no scrolling, all bars visible
                                        VStack(spacing: 0) {
                                            // Space for tooltips above the chart
                                            Spacer()
                                                .frame(height: 60)

                                            ZStack(alignment: .bottom) {
                                                VStack(spacing: 0) {
                                                    ForEach(0..<5) { index in
                                                        Divider()
                                                            .background(Color.gray.opacity(0.2))
                                                        if index < 4 {
                                                            Spacer()
                                                        }
                                                    }
                                                }
                                                .frame(height: ChartConstants.chartHeight)

                                                HStack(alignment: .bottom, spacing: ChartConstants.barSpacing) {
                                                    ForEach(Array(displayData.enumerated()), id: \.element.id) { index, point in
                                                        let heightValue = barHeight(for: point.growthPercent, in: ChartConstants.chartHeight)
                                                        let offsetValue = barOffset(for: point.growthPercent, barHeight: heightValue, in: ChartConstants.chartHeight)

                                                        VStack(spacing: 4) {
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
                                                                .offset(x: index < 3 ? 20 : (index >= displayData.count - 3 ? -20 : 0))
                                                                .transition(.opacity.combined(with: .scale))
                                                            } else {
                                                                // Empty spacer to maintain consistent height
                                                                Color.clear
                                                                    .frame(height: 50)
                                                            }

                                                            Spacer(minLength: 0)

                                                            // Bar positioned at zero line
                                                            ZStack(alignment: .bottom) {
                                                                Color.clear
                                                                    .frame(height: ChartConstants.chartHeight)

                                                                RoundedRectangle(cornerRadius: 2)
                                                                    .fill(point.growthPercent >= 0 ?
                                                                          (selectedBar == point.id ? Color.green.opacity(0.8) : Color.green) :
                                                                          (selectedBar == point.id ? Color.red.opacity(0.8) : Color.red))
                                                                    .frame(width: dynamicBarWidth, height: heightValue)
                                                                    .offset(y: -offsetValue)
                                                                    .onTapGesture {
                                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                                            if selectedBar == point.id {
                                                                                selectedBar = nil
                                                                            } else {
                                                                                selectedBar = point.id
                                                                            }
                                                                        }
                                                                    }
                                                            }
                                                        }
                                                        .frame(width: dynamicBarWidth, height: 290, alignment: .bottom)
                                                        .id(point.id)
                                                    }
                                                }
                                                .padding(.horizontal, 4)
                                            }

                                            // X-axis labels - show every 9th period for 36 bars
                                            HStack(alignment: .top, spacing: ChartConstants.barSpacing) {
                                                ForEach(Array(displayData.enumerated()), id: \.element.id) { index, point in
                                                    let shouldShowLabel = index % 9 == 0 || index == displayData.count - 1

                                                    Text(shouldShowLabel ? formatYearLabel(point.period) : "")
                                                        .font(.system(size: 9))
                                                        .foregroundStyle(.secondary)
                                                        .frame(width: dynamicBarWidth)
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.5)
                                                }
                                            }
                                            .padding(.top, 4)
                                            .padding(.horizontal, 4)
                                        }
                                }
                            }
                            .frame(height: 340)
                        }
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            if earningsData.isEmpty {
                loadEarnings()
            }
        }
    }

    private func loadEarnings() {
        isLoading = true

        Task {
            do {
                let data = try await apiService.fetchEarnings(symbol: symbol)
                await MainActor.run {
                    earningsData = data
                    onDataLoaded?(data)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    earningsData = []
                    onDataLoaded?([])
                    isLoading = false
                }
            }
        }
    }

    private func barHeight(for value: Double, in maxHeight: CGFloat) -> CGFloat {
        let range = growthRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 4 }

        // Normalize value to 0-1 range based on total chart range
        let normalized = abs(value) / totalRange
        return max(maxHeight * normalized, 2) // Minimum 2px for visibility
    }

    /// Calculate the offset from bottom for a bar value
    private func barOffset(for value: Double, barHeight: CGFloat, in chartHeight: CGFloat) -> CGFloat {
        let zeroY = chartHeight * zeroLinePosition

        if value >= 0 {
            // Positive values: bar sits on zero line, grows upward
            return zeroY
        } else {
            // Negative values: bar grows downward from zero line
            return zeroY - barHeight
        }
    }

    private func formatYearLabel(_ dateString: String) -> String {
        ChartUtilities.formatYearOnly(dateString)
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

//
//  YoYOperatingMarginGrowthChartView.swift
//  Ekonix
//
//  Extracted from ContentView.swift for faster compilation
//

import SwiftUI

struct YoYOperatingMarginGrowthChartView: View {
    let symbol: String
    let apiService: StockAPIService
    var onDataLoaded: (([OperatingMarginDataPoint]) -> Void)? = nil

    @State private var operatingMarginData: [OperatingMarginDataPoint] = []
    @State private var isLoading = false
    @State private var selectedBar: String?  // Changed from UUID? to String?
    @State private var hasAppeared = false

    struct GrowthDataPoint: Identifiable {
        let period: String
        let growthPercent: Double
        let currentOperatingMargin: Double
        let priorOperatingMargin: Double
        let shouldRender: Bool
        var id: String { period }  // Use period string as stable id
    }

    var growthData: [GrowthDataPoint] {
        guard operatingMarginData.count >= 5 else { return [] }

        var growth: [GrowthDataPoint] = []
        let sortedData = operatingMarginData.sorted { $0.period < $1.period }

        // Calculate YoY growth (comparing to 4 quarters ago)
        for i in 4..<sortedData.count {
            let current = sortedData[i]
            let prior = sortedData[i - 4]

            let shouldRender = prior.operatingMargin > 0
            let growthPercent = shouldRender ? ((current.operatingMargin - prior.operatingMargin) / prior.operatingMargin) * 100 : 0

            growth.append(GrowthDataPoint(
                period: current.period,
                growthPercent: growthPercent,
                currentOperatingMargin: current.operatingMargin,
                priorOperatingMargin: prior.operatingMargin,
                shouldRender: shouldRender
            ))
        }

        return growth // Already in ascending order (oldest to newest)
    }

    var displayData: [GrowthDataPoint] {
        // Take the latest 36 growth periods (oldest first on left, newest on right)
        Array(growthData.suffix(ChartConstants.growthDataLimit))
    }

    var growthRange: (min: Double, max: Double) {
        let values = displayData.map { $0.growthPercent }
        return ChartUtilities.calculateAdaptiveRange(values: values)
    }

    /// Check if all data points are negative (for inverted Y-axis rendering)
    private var isAllNegative: Bool {
        let values = displayData.map { $0.growthPercent }
        return !values.isEmpty && values.allSatisfy { $0 < 0 }
    }

    private func getYAxisLabels() -> [Double] {
        let range = growthRange
        return ChartUtilities.generateYAxisLabels(minValue: range.min, maxValue: range.max)
    }

    /// Calculate the Y position where zero line sits (as fraction of chart height from bottom)
    private var zeroLinePosition: CGFloat {
        let range = growthRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0.5 }

        if isAllNegative {
            // For all-negative data: 0% at top (1.0), most negative at bottom (0.0)
            return 1.0
        } else {
            // Normal: Zero position as fraction from bottom: -min / totalRange
            return CGFloat(-range.min / totalRange)
        }
    }

    /// Calculate Y offset for a label at given index to align with gridlines
    /// Uses value-based positioning to ensure proportional spacing for asymmetric ranges
    private func yOffsetForLabel(at index: Int) -> CGFloat {
        let labels = getYAxisLabels()
        let range = growthRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0 }

        let labelValue = labels[index]

        if isAllNegative {
            // Inverted Y-axis: 0% at top, most negative at bottom
            // Calculate position as fraction from top (0 = top, 1 = bottom)
            let fractionFromTop = (range.max - labelValue) / totalRange
            // Convert to offset from center (middle of chart = 0)
            return ChartConstants.chartHeight * fractionFromTop - ChartConstants.chartHeight / 2
        } else {
            // Normal Y-axis
            // Calculate position as fraction from bottom (0 = bottom, 1 = top)
            let fractionFromBottom = (labelValue - range.min) / totalRange
            // Convert to offset from center (middle of chart = 0)
            return ChartConstants.chartHeight / 2 - (ChartConstants.chartHeight * fractionFromBottom)
        }
    }

    @ViewBuilder
    private var chartContentView: some View {
        ScrollView {
                    VStack(spacing: 20) {
                        // Chart with title
                        VStack(alignment: .leading, spacing: 16) {
                            Text("TTM YoY Operating Margin Growth")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)

                            GeometryReader { geometry in
                                let availableWidth = geometry.size.width - ChartConstants.yAxisWidth - ChartConstants.rightPadding - 16
                                let barCount = CGFloat(displayData.count)
                                let dynamicBarWidth = max((availableWidth - (barCount - 1) * ChartConstants.barSpacing) / barCount, 3)

                                HStack(alignment: .center, spacing: 8) {
                                    // Fixed Y-axis on the left - labels aligned with gridlines
                                    ZStack(alignment: .trailing) {
                                        ForEach(Array(getYAxisLabels().enumerated()), id: \.offset) { index, value in
                                            Text(formatYAxisValue(value))
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                                .offset(y: yOffsetForLabel(at: index))
                                        }
                                    }
                                    .frame(width: ChartConstants.yAxisWidth, height: ChartConstants.chartHeight)

                                    // Chart area - no scrolling, all bars visible
                                        VStack(spacing: 0) {
                                            // Add top padding for all-negative charts to prevent title overlap
                                            if isAllNegative {
                                                Spacer()
                                                    .frame(height: 30)
                                            }

                                            ZStack(alignment: .bottom) {
                                                // Data bars (drawn first, behind gridlines)
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
                                                            } else {
                                                                // Empty spacer to maintain consistent height
                                                                Color.clear
                                                                    .frame(height: 50)
                                                            }

                                                            // Connecting line from tooltip to bar (fills space between tooltip and bar)
                                                            if selectedBar == point.id {
                                                                Rectangle()
                                                                    .fill(Color.gray.opacity(0.5))
                                                                    .frame(width: 1)
                                                            } else {
                                                                Spacer(minLength: 0)
                                                            }

                                                            // Bar positioned at zero line
                                                            ZStack(alignment: .bottom) {
                                                                Color.clear
                                                                    .frame(height: ChartConstants.chartHeight)

                                                                if point.shouldRender {
                                                                    RoundedRectangle(cornerRadius: 2)
                                                                        .fill(point.growthPercent >= 0 ?
                                                                              (selectedBar == point.id ? Color.green.opacity(0.8) : Color.green) :
                                                                              (selectedBar == point.id ? Color.red.opacity(0.8) : Color.red))
                                                                        .frame(width: dynamicBarWidth, height: heightValue)
                                                                        .offset(y: -offsetValue)
                                                                }
                                                            }
                                                        }
                                                        .frame(width: dynamicBarWidth, height: 290, alignment: .bottom)
                                                        .id(point.id)
                                                        .contentShape(Rectangle())
                                                        .onTapGesture {
                                                            if selectedBar == point.id {
                                                                    selectedBar = nil
                                                                } else {
                                                                    selectedBar = point.id
                                                            }
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal, 4)
                                            .simultaneousGesture(
                                                DragGesture(minimumDistance: 20)
                                                    .onChanged { value in
                                                        // Calculate which bar is being dragged over
                                                        let totalBarWidth = dynamicBarWidth + ChartConstants.barSpacing
                                                        let xPosition = value.location.x - 4 // Account for horizontal padding
                                                        let barIndex = Int(xPosition / totalBarWidth)

                                                        // Update selected bar if valid index
                                                        if barIndex >= 0 && barIndex < displayData.count {
                                                            selectedBar = displayData[barIndex].id
                                                        }
                                                    }
                                                    .onEnded { _ in
                                                        // Keep the last selected bar visible
                                                    }
                                            )


                                                // Background gridlines (drawn second, on top of bars)
                                                ZStack {
                                                    ForEach(Array(getYAxisLabels().enumerated()), id: \.offset) { index, value in
                                                        Divider()
                                                            .background(Color.gray.opacity(0.2))
                                                            .offset(y: yOffsetForLabel(at: index))
                                                    }
                                                }
                                                .frame(height: ChartConstants.chartHeight)
                                                .allowsHitTesting(false)

                                                // Highlighted zero line (drawn last, most prominent)
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.5))
                                                    .frame(height: 1)
                                                    .offset(y: -(ChartConstants.chartHeight * zeroLinePosition))
                                                    .allowsHitTesting(false)
                                            }

                                            // X-axis labels - show every 6th period for 36 bars (shows ~6 year labels)
                                            HStack(alignment: .top, spacing: ChartConstants.barSpacing) {
                                                ForEach(Array(displayData.enumerated()), id: \.element.id) { index, point in
                                                    let isLastIndex = index == displayData.count - 1
                                                    let lastSampledIndex = (displayData.count - 1) / 6 * 6
                                                    let shouldShowLabel = index % 6 == 0 || (isLastIndex && index - lastSampledIndex >= 3)

                                                    Text(shouldShowLabel ? formatYearLabel(point.period) : "")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundStyle(.primary)
                                                        .fixedSize()
                                                        .rotationEffect(.degrees(-45), anchor: .topLeading)
                                                        .frame(width: dynamicBarWidth, alignment: .topLeading)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .padding(.top, 40)
                                            .padding(.leading, 4)
                                            .padding(.trailing, 30)
                                        }

                                    // Right padding to balance Y-axis on left
                                    Spacer()
                                        .frame(width: ChartConstants.rightPadding)
                                }
                            }
                            .frame(height: 380)
                        }
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 4)
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
                    Text("Need at least 5 TTM periods of data")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                chartContentView
            }
        }
        .scaleEffect(hasAppeared ? 1.0 : 0.8)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                hasAppeared = true
            }
            if operatingMarginData.isEmpty {
                loadOperatingMargin()
            }
        }
    }

    private func loadOperatingMargin() {
        isLoading = true

        Task {
            do {
                let data = try await apiService.fetchTTMOperatingMargin(symbol: symbol)
                await MainActor.run {
                    operatingMarginData = data
                    onDataLoaded?(data)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    operatingMarginData = []
                    isLoading = false
                }
            }
        }
    }

    private func barHeight(for value: Double, in maxHeight: CGFloat) -> CGFloat {
        let range = growthRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0 }

        if isAllNegative {
            // For inverted Y-axis: height is proportional to distance from max (0%)
            let normalized = abs(value - range.max) / totalRange
            return maxHeight * normalized
        } else {
            // Normal: Distance from zero to value
            let normalized = abs(value) / totalRange
            return maxHeight * normalized
        }
    }

    /// Calculate the offset from bottom for a bar value
    private func barOffset(for value: Double, barHeight: CGFloat, in chartHeight: CGFloat) -> CGFloat {
        let zeroY = chartHeight * zeroLinePosition

        if isAllNegative {
            // For inverted Y-axis: bars extend downward from top (0%)
            // Zero is at top (zeroY = chartHeight), bars grow downward
            return zeroY - barHeight
        } else {
            // Normal Y-axis
            if value >= 0 {
                // Positive values: bar sits on zero line, grows upward
                return zeroY
            } else {
                // Negative values: bar grows downward from zero line
                return zeroY - barHeight
            }
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
        ChartUtilities.formatPercentageYAxisLabel(value)
    }
}

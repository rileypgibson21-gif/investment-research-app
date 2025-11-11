//
//  TTMGrossProfitChartView.swift
//  Ekonix
//
//  Created for gross profit TTM chart
//

import SwiftUI

struct TTMGrossProfitChartView: View {
    let symbol: String
    let apiService: StockAPIService
    var onDataLoaded: (([GrossProfitDataPoint]) -> Void)? = nil

    @State private var grossProfitData: [GrossProfitDataPoint] = []
    @State private var isLoading = false
    @State private var selectedBar: UUID?
    @State private var errorMessage: String?

    var displayData: [GrossProfitDataPoint] {
        // Sort by period (oldest first on left, newest on right) and take latest 37 TTM periods
        let sorted = grossProfitData.sorted { $0.period < $1.period }
        return Array(sorted.suffix(ChartConstants.ttmDataLimit))
    }

    var grossProfitRange: (min: Double, max: Double) {
        let values = displayData.map { $0.grossProfit }
        return ChartUtilities.calculateAdaptiveRange(values: values)
    }

    private var valueScale: ChartUtilities.ValueScale {
        let values = displayData.map { $0.grossProfit }
        return ChartUtilities.detectValueScale(values: values)
    }

    private func getYAxisLabels() -> [Double] {
        let range = grossProfitRange
        return ChartUtilities.generateYAxisLabels(minValue: range.min, maxValue: range.max)
    }

    /// Calculate the Y position where zero line sits (as fraction of chart height from bottom)
    private var zeroLinePosition: CGFloat {
        let range = grossProfitRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0 }
        // Zero position as fraction from bottom: -min / totalRange
        return CGFloat(-range.min / totalRange)
    }

    var body: some View {
        ZStack {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                    if !error.isEmpty {
                        Text(error)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    Button("Retry") {
                        loadGrossProfit()
                    }
                    Spacer()
                }
            } else if grossProfitData.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No TTM gross profit data available")
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        loadGrossProfit()
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Chart with title
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Trailing Twelve Months Gross Profit")
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
                                        ZStack(alignment: .bottom) {
                                            // Data bars (drawn first, behind gridlines)
                                            HStack(alignment: .bottom, spacing: ChartConstants.barSpacing) {
                                                ForEach(Array(displayData.enumerated()), id: \.element.id) { index, point in
                                                    let heightValue = barHeight(for: point.grossProfit, in: ChartConstants.chartHeight)
                                                    let offsetValue = barOffset(for: point.grossProfit, barHeight: heightValue, in: ChartConstants.chartHeight)

                                                    VStack(spacing: 4) {
                                                        if selectedBar == point.id {
                                                            VStack(spacing: 2) {
                                                                Text(formatDate(point.period))
                                                                    .font(.caption2)
                                                                    .fontWeight(.bold)
                                                                Text(formatDetailedValue(point.grossProfit))
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
                                                                    .fill(Color.blue)
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
                                                                .fill(selectedBar == point.id ? Color.blue.opacity(0.8) : Color.blue)
                                                                .frame(width: dynamicBarWidth, height: heightValue)
                                                                .offset(y: -offsetValue)
                                                        }
                                                    }
                                                    .frame(width: dynamicBarWidth, height: 290, alignment: .bottom)
                                                    .id(point.id)
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
                                                }
                                            }
                                            .padding(.horizontal, 4)

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
                                            if grossProfitRange.min < 0 && grossProfitRange.max > 0 {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.5))
                                                    .frame(height: 1)
                                                    .offset(y: -(ChartConstants.chartHeight * zeroLinePosition))
                                                    .allowsHitTesting(false)
                                            }
                                        }

                                        // X-axis labels - show every 7th period for 37 bars (shows ~5-6 year labels)
                                        HStack(alignment: .top, spacing: ChartConstants.barSpacing) {
                                            ForEach(Array(displayData.enumerated()), id: \.element.id) { index, point in
                                                let isLastIndex = index == displayData.count - 1
                                                let lastSampledIndex = (displayData.count - 1) / 7 * 7
                                                let shouldShowLabel = index % 7 == 0 || (isLastIndex && index - lastSampledIndex >= 3)

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
                                }
                            }
                            .frame(height: 380)
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
            if grossProfitData.isEmpty {
                loadGrossProfit()
            }
        }
    }

    private func loadGrossProfit() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let data = try await apiService.fetchTTMGrossProfit(symbol: symbol)
                await MainActor.run {
                    grossProfitData = data
                    onDataLoaded?(data)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    grossProfitData = []
                    errorMessage = "Failed to load TTM gross profit data"
                    onDataLoaded?([])
                    isLoading = false
                }
            }
        }
    }

    private func barHeight(for value: Double, in maxHeight: CGFloat) -> CGFloat {
        let range = grossProfitRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0 }

        // Distance from zero to value
        let normalized = abs(value) / totalRange
        return maxHeight * normalized
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

    private func formatDate(_ dateString: String) -> String {
        ChartUtilities.formatQuarterDate(dateString)
    }

    private func formatYearLabel(_ dateString: String) -> String {
        ChartUtilities.formatYearOnly(dateString)
    }

    private func formatDetailedValue(_ value: Double) -> String {
        ChartUtilities.formatCurrencyValue(value)
    }

    private func formatYAxisValue(_ value: Double) -> String {
        ChartUtilities.formatFinancialYAxisLabel(value, scale: valueScale)
    }

    /// Calculate Y offset for a label at given index to align with gridlines
    /// Uses value-based positioning to ensure proportional spacing for asymmetric ranges
    private func yOffsetForLabel(at index: Int) -> CGFloat {
        let labels = getYAxisLabels()
        let range = grossProfitRange
        let totalRange = range.max - range.min
        guard totalRange > 0 else { return 0 }

        let labelValue = labels[index]
        // Calculate position as fraction from bottom (0 = bottom, 1 = top)
        let fractionFromBottom = (labelValue - range.min) / totalRange

        // Convert to offset from center (middle of chart = 0)
        return ChartConstants.chartHeight / 2 - (ChartConstants.chartHeight * fractionFromBottom)
    }
}

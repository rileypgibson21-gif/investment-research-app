//
//  RevenueChartView.swift
//  Ekonix
//
//  Created for quarterly revenue chart
//

import SwiftUI

struct RevenueChartView: View {
    let symbol: String
    let apiService: StockAPIService
    var onDataLoaded: (([RevenueDataPoint]) -> Void)? = nil

    @State private var revenueData: [RevenueDataPoint] = []
    @State private var isLoading = false
    @State private var selectedBar: UUID?

    var displayData: [RevenueDataPoint] {
        // Sort by period (oldest first on left, newest on right) and take latest 40 quarters
        let sorted = revenueData.sorted { $0.period < $1.period }
        return Array(sorted.suffix(ChartConstants.quarterlyDataLimit))
    }

    var revenueRange: (min: Double, max: Double) {
        let values = displayData.map { $0.revenue }
        return ChartUtilities.calculateAdaptiveRange(values: values)
    }

    private var valueScale: ChartUtilities.ValueScale {
        let values = displayData.map { $0.revenue }
        return ChartUtilities.detectValueScale(values: values)
    }

    private func getYAxisLabels() -> [Double] {
        let range = revenueRange
        return ChartUtilities.generateYAxisLabels(minValue: range.min, maxValue: range.max)
    }

    /// Calculate the Y position where zero line sits (as fraction of chart height from bottom)
    private var zeroLinePosition: CGFloat {
        let range = revenueRange
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
            } else if revenueData.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No revenue data available")
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        loadRevenue()
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Chart with title
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Quarterly Revenue")
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
                                                .offset(y: yOffsetForLabel(at: index))
                                        }
                                    }
                                    .frame(width: ChartConstants.yAxisWidth, height: ChartConstants.chartHeight)

                                    // Chart area - no scrolling, all bars visible
                                    VStack(spacing: 0) {
                                        ZStack(alignment: .bottom) {
                                            // Background gridlines
                                            VStack(spacing: 0) {
                                                ForEach(Array(getYAxisLabels().enumerated()), id: \.offset) { index, _ in
                                                    Divider()
                                                        .background(Color.gray.opacity(0.2))
                                                    if index < getYAxisLabels().count - 1 {
                                                        Spacer()
                                                    }
                                                }
                                            }
                                            .frame(height: ChartConstants.chartHeight)

                                            // Highlighted zero line (only if range spans negative/positive)
                                            if revenueRange.min < 0 && revenueRange.max > 0 {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.5))
                                                    .frame(height: 1)
                                                    .offset(y: -(ChartConstants.chartHeight * zeroLinePosition))
                                            }

                                            HStack(alignment: .bottom, spacing: ChartConstants.barSpacing) {
                                                ForEach(Array(displayData.enumerated()), id: \.element.id) { index, point in
                                                    let heightValue = barHeight(for: point.revenue, in: ChartConstants.chartHeight)
                                                    let offsetValue = barOffset(for: point.revenue, barHeight: heightValue, in: ChartConstants.chartHeight)

                                                    VStack(spacing: 4) {
                                                        if selectedBar == point.id {
                                                            VStack(spacing: 2) {
                                                                Text(formatDate(point.period))
                                                                    .font(.caption2)
                                                                    .fontWeight(.bold)
                                                                Text(formatDetailedValue(point.revenue))
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

                                                            // Connecting line from tooltip to bar
                                                            Rectangle()
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(width: 1)
                                                        } else {
                                                            // Empty spacer to maintain consistent height
                                                            Color.clear
                                                                .frame(height: 50)
                                                        }

                                                        Spacer(minLength: 0)
                                                            .overlay(
                                                                Group {
                                                                    if selectedBar == point.id {
                                                                        Rectangle()
                                                                            .fill(Color.blue)
                                                                            .frame(width: 2)
                                                                    }
                                                                }
                                                            )

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
                                        }

                                        // X-axis labels - show every 8th quarter for 40 bars (shows ~5 year labels)
                                        HStack(alignment: .top, spacing: ChartConstants.barSpacing) {
                                            ForEach(Array(displayData.enumerated()), id: \.element.id) { index, point in
                                                let isLastIndex = index == displayData.count - 1
                                                let lastSampledIndex = (displayData.count - 1) / 8 * 8
                                                let shouldShowLabel = index % 8 == 0 || (isLastIndex && index - lastSampledIndex >= 4)

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

                        // Remove individual data table from quarterly chart
                    }
                }
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

    private func barHeight(for value: Double, in maxHeight: CGFloat) -> CGFloat {
        let range = revenueRange
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

    /// Calculate Y offset for a label at given index to align with gridlines
    private func yOffsetForLabel(at index: Int) -> CGFloat {
        let labels = getYAxisLabels()
        let labelCount = CGFloat(labels.count)
        let step = ChartConstants.chartHeight / (labelCount - 1)
        // Center at 0 (middle of chart), then offset based on index
        return -ChartConstants.chartHeight / 2 + (step * CGFloat(index))
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
}

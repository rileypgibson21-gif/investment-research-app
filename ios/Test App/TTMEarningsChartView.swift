//
//  TTMEarningsChartView.swift
//  Test App
//
//  Extracted from ContentView.swift for faster compilation
//

import SwiftUI

struct TTMEarningsChartView: View {
    let symbol: String
    let apiService: StockAPIService
    var onDataLoaded: (([EarningsDataPoint]) -> Void)? = nil

    @State private var earningsData: [EarningsDataPoint] = []
    @State private var isLoading = false
    @State private var selectedBar: UUID?
    @State private var errorMessage: String?

    var displayData: [EarningsDataPoint] {
        // Sort by period (oldest first on left, newest on right) and take latest 37 TTM periods
        let sorted = earningsData.sorted { $0.period < $1.period }
        return Array(sorted.suffix(ChartConstants.ttmDataLimit))
    }

    var maxEarnings: Double {
        let actualMax = displayData.map { $0.earnings }.max() ?? 0
        return ChartUtilities.roundToNiceNumber(actualMax * 1.05)
    }

    private func getYAxisLabels() -> [Double] {
        ChartUtilities.generateYAxisLabels(maxValue: maxEarnings)
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
                        loadEarnings()
                    }
                    Spacer()
                }
            } else if earningsData.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No TTM earnings data available")
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        loadEarnings()
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Chart with title
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Trailing Twelve Months Earnings")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)

                            GeometryReader { geometry in
                                let availableWidth = geometry.size.width - ChartConstants.yAxisWidth - 16
                                let barCount = CGFloat(displayData.count)
                                let dynamicBarWidth = max((availableWidth - (barCount - 1) * ChartConstants.barSpacing) / barCount, 3)

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

                                    // Chart area - no scrolling, all bars visible
                                    VStack(spacing: 0) {
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
                                                    VStack(spacing: 4) {
                                                        if selectedBar == point.id {
                                                            VStack(spacing: 2) {
                                                                Text(formatDate(point.period))
                                                                    .font(.caption2)
                                                                    .fontWeight(.bold)
                                                                Text(formatDetailedValue(point.earnings))
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
                                                                    .fill(Color.purple)
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

                                                        RoundedRectangle(cornerRadius: 2)
                                                            .fill(selectedBar == point.id ? Color.purple.opacity(0.8) : Color.purple)
                                                            .frame(width: dynamicBarWidth, height: barHeight(for: point.earnings, in: ChartConstants.barChartHeight))
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
                                                    .frame(width: dynamicBarWidth, height: 290, alignment: .bottom)
                                                    .id(point.id)
                                                }
                                            }
                                            .padding(.horizontal, 4)
                                        }

                                        // X-axis labels - show every 9th period for 37 bars (shows ~4-5 year labels)
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
        errorMessage = nil

        Task {
            do {
                let data = try await apiService.fetchTTMEarnings(symbol: symbol)
                await MainActor.run {
                    earningsData = data
                    onDataLoaded?(data)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    earningsData = []
                    errorMessage = "Failed to load TTM earnings data"
                    onDataLoaded?([])
                    isLoading = false
                }
            }
        }
    }

    private func barHeight(for value: Double, in maxHeight: CGFloat) -> CGFloat {
        guard maxEarnings > 0 else { return 4 }
        let normalized = value / maxEarnings
        return maxHeight * normalized
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
        ChartUtilities.formatYAxisValue(value)
    }
}

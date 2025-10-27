//
//  EarningsChartView.swift
//  Test App
//
//  Extracted from ContentView.swift for faster compilation
//

import SwiftUI

struct EarningsChartView: View {
    let symbol: String
    let apiService: StockAPIService
    var onDataLoaded: (([EarningsDataPoint]) -> Void)? = nil

    @State private var earningsData: [EarningsDataPoint] = []
    @State private var isLoading = false
    @State private var selectedBar: UUID?
    @State private var scrollViewProxy: ScrollViewProxy?

    var displayData: [EarningsDataPoint] {
        // Reverse the order so oldest is first (left side) - show 16 quarters (4 years)
        Array(earningsData.prefix(ChartConstants.quarterlyDataLimit).reversed())
    }

    var maxEarnings: Double {
        let actualMax = displayData.map { $0.earnings }.max() ?? 0
        return ChartUtilities.roundToNiceNumber(actualMax * 1.05)
    }

    private func getYAxisLabels() -> [Double] {
        ChartUtilities.generateYAxisLabels(maxValue: maxEarnings)
    }

    @ViewBuilder
    private func barView(index: Int, point: EarningsDataPoint) -> some View {
        VStack(spacing: 4) {
            if selectedBar == point.id {
                tooltipView(index: index, point: point)
            } else {
                Color.clear.frame(height: 50)
            }

            Spacer(minLength: 0)

            barShape(point: point)
        }
        .frame(width: 40, height: 290, alignment: .bottom)
        .id(point.id)
    }

    @ViewBuilder
    private func tooltipView(index: Int, point: EarningsDataPoint) -> some View {
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
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.green))
        .fixedSize()
        .offset(x: index == 0 ? 20 : (index == displayData.count - 1 ? -20 : 0))
        .transition(.opacity.combined(with: .scale))
    }

    @ViewBuilder
    private func barShape(point: EarningsDataPoint) -> some View {
        let fillColor = selectedBar == point.id ? Color.green.opacity(0.8) : Color.green
        let height = barHeight(for: point.earnings, in: ChartConstants.barChartHeight)

        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .frame(width: 24, height: height)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedBar = selectedBar == point.id ? nil : point.id
                }
            }
    }

    @ViewBuilder
    private var chartContent: some View {
        VStack(spacing: 20) {
            // Chart with title
            VStack(alignment: .leading, spacing: 16) {
                Text("Quarterly Earnings")
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

                                    HStack(alignment: .bottom, spacing: 8) {
                                        ForEach(Array(displayData.enumerated()), id: \.element.id) { index, point in
                                            barView(index: index, point: point)
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

    var body: some View {
        ZStack {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 400)
            } else if earningsData.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No earnings data available")
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        loadEarnings()
                    }
                    Spacer()
                }
                .frame(height: 400)
            } else {
                chartContent
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
                    isLoading = false
                    onDataLoaded?(data)
                }
            } catch {
                await MainActor.run {
                    earningsData = []
                    isLoading = false
                    onDataLoaded?([])
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

    private func formatDetailedValue(_ value: Double) -> String {
        ChartUtilities.formatCurrencyValue(value)
    }

    private func formatYAxisValue(_ value: Double) -> String {
        ChartUtilities.formatYAxisValue(value)
    }
}

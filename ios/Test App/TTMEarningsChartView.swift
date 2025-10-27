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
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var errorMessage: String?

    var displayData: [EarningsDataPoint] {
        // Reverse the order so oldest is first (left side) - show 13 TTM periods
        Array(earningsData.prefix(ChartConstants.ttmDataLimit).reversed())
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
                .frame(height: 400)
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
                .frame(height: 400)
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
                .frame(height: 400)
            } else {
                VStack(spacing: 20) {
                    // Chart with title
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trailing Twelve Months Earnings")
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
                                                            .offset(x: index == 0 ? 20 : (index == displayData.count - 1 ? -20 : 0))
                                                            .transition(.opacity.combined(with: .scale))
                                                        } else {
                                                            // Empty spacer to maintain consistent height
                                                            Color.clear
                                                                .frame(height: 50)
                                                        }

                                                        Spacer(minLength: 0)

                                                        RoundedRectangle(cornerRadius: 4)
                                                            .fill(selectedBar == point.id ? Color.purple.opacity(0.8) : Color.purple)
                                                            .frame(width: 24, height: barHeight(for: point.earnings, in: ChartConstants.barChartHeight))
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
                                                    .frame(width: 40, height: 290, alignment: .bottom)
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
                                        // Scroll to the rightmost position (most recent period)
                                        if let lastPeriod = displayData.last {
                                            Task { @MainActor in
                                                try? await Task.sleep(nanoseconds: UInt64(ChartConstants.scrollDelay * 1_000_000_000))
                                                proxy.scrollTo(lastPeriod.id, anchor: .trailing)
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

    private func formatDetailedValue(_ value: Double) -> String {
        ChartUtilities.formatCurrencyValue(value)
    }

    private func formatYAxisValue(_ value: Double) -> String {
        ChartUtilities.formatYAxisValue(value)
    }
}

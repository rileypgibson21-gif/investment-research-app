//
//  PriceChartView.swift
//  Test App
//
//  Stock price chart using Marketstack EOD data
//

import SwiftUI

struct PriceChartView: View {
    let symbol: String
    let marketDataService: MarketDataService

    @State private var priceData: [EODDataPoint] = []
    @State private var isLoading = false
    @State private var selectedPoint: EODDataPoint?
    @State private var timeRange: TimeRange = .threeMonths

    enum TimeRange: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"

        var days: Int {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 252
            }
        }
    }

    var displayData: [EODDataPoint] {
        Array(priceData.prefix(timeRange.days).reversed())
    }

    var priceRange: (min: Double, max: Double) {
        let prices = displayData.map { $0.close }
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 100
        let padding = (maxPrice - minPrice) * 0.1
        return (min: minPrice - padding, max: maxPrice + padding)
    }

    private func getYAxisLabels() -> [Double] {
        let range = priceRange
        let interval = (range.max - range.min) / 4
        guard interval > 0 else { return [range.max, range.max * 0.75, range.max * 0.5, range.max * 0.25, 0] }
        var labels: [Double] = []
        for i in 0...4 {
            labels.append(range.max - (interval * Double(i)))
        }
        return labels
    }

    @ViewBuilder
    private func priceLineShape() -> some View {
        let range = priceRange
        let width = 300.0
        let height = ChartConstants.chartHeight

        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let points = displayData.enumerated().map { index, dataPoint in
                let x = availableWidth * (Double(index) / Double(max(displayData.count - 1, 1)))
                let normalized = (dataPoint.close - range.min) / (range.max - range.min)
                let y = height * (1 - normalized)
                return CGPoint(x: x, y: y)
            }

            Path { path in
                guard let firstPoint = points.first else { return }
                path.move(to: firstPoint)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.blue, lineWidth: 2)

            // Price change area fill
            Path { path in
                guard let firstPoint = points.first else { return }
                path.move(to: CGPoint(x: firstPoint.x, y: height))
                path.addLine(to: firstPoint)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                if let lastPoint = points.last {
                    path.addLine(to: CGPoint(x: lastPoint.x, y: height))
                }
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Tap points
            ForEach(Array(displayData.enumerated()), id: \.element.id) { index, dataPoint in
                let point = points[index]
                Circle()
                    .fill(selectedPoint?.id == dataPoint.id ? Color.blue : Color.clear)
                    .frame(width: 8, height: 8)
                    .position(x: point.x, y: point.y)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPoint = selectedPoint?.id == dataPoint.id ? nil : dataPoint
                        }
                    }
            }
        }
        .frame(height: height)
    }

    var body: some View {
        ZStack {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Loading price data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 400)
            } else if priceData.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No price data available")
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        loadPriceData()
                    }
                    Spacer()
                }
                .frame(height: 400)
            } else {
                VStack(spacing: 20) {
                    // Chart with title and time range selector
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Stock Price")
                                .font(.headline)

                            Spacer()

                            // Time range picker
                            HStack(spacing: 8) {
                                ForEach(TimeRange.allCases, id: \.self) { range in
                                    Button(range.rawValue) {
                                        timeRange = range
                                        selectedPoint = nil
                                    }
                                    .font(.caption)
                                    .foregroundStyle(timeRange == range ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(timeRange == range ? Color.blue : Color.gray.opacity(0.2))
                                    )
                                }
                            }
                        }

                        // Price change summary
                        if let first = displayData.first, let last = displayData.last {
                            let change = last.close - first.close
                            let changePercent = (change / first.close) * 100

                            HStack(spacing: 12) {
                                Text(formatPrice(last.close))
                                    .font(.title2)
                                    .fontWeight(.bold)

                                HStack(spacing: 4) {
                                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    Text(formatChange(change))
                                    Text("(\(formatPercent(changePercent)))")
                                }
                                .font(.subheadline)
                                .foregroundStyle(change >= 0 ? .green : .red)
                            }
                        }

                        // Selected point tooltip
                        if let selected = selectedPoint {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatDate(selected.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading) {
                                        Text("Close")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(formatPrice(selected.close))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    VStack(alignment: .leading) {
                                        Text("High")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(formatPrice(selected.high))
                                            .font(.caption)
                                    }
                                    VStack(alignment: .leading) {
                                        Text("Low")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(formatPrice(selected.low))
                                            .font(.caption)
                                    }
                                    VStack(alignment: .leading) {
                                        Text("Volume")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(formatVolume(selected.volume))
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }

                        HStack(alignment: .center, spacing: 8) {
                            // Fixed Y-axis on the left
                            VStack(alignment: .trailing, spacing: 0) {
                                ForEach(Array(getYAxisLabels().enumerated()), id: \.offset) { index, value in
                                    Text(formatYAxisPrice(value))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    if index < getYAxisLabels().count - 1 {
                                        Spacer()
                                    }
                                }
                            }
                            .frame(width: ChartConstants.yAxisWidth, height: ChartConstants.chartHeight)

                            // Chart area
                            ZStack(alignment: .bottom) {
                                // Grid lines
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

                                priceLineShape()
                            }
                        }

                        // X-axis labels (dates)
                        HStack(alignment: .top, spacing: 0) {
                            let labelCount = min(displayData.count, 6)
                            let step = max(displayData.count / labelCount, 1)

                            ForEach(Array(stride(from: 0, to: displayData.count, by: step)), id: \.self) { index in
                                if index < displayData.count {
                                    Text(formatDate(displayData[index].date))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.leading, ChartConstants.yAxisWidth + 8)
                    }
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
        .onAppear {
            if priceData.isEmpty {
                loadPriceData()
            }
        }
    }

    private func loadPriceData() {
        isLoading = true

        Task {
            do {
                let data = try await marketDataService.fetchEODData(symbol: symbol, limit: 252)
                await MainActor.run {
                    priceData = data
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    priceData = []
                    isLoading = false
                }
            }
        }
    }

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func formatYAxisPrice(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "$%.1fK", value / 1000)
        }
        return String(format: "$%.0f", value)
    }

    private func formatChange(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.positivePrefix = "+"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.positivePrefix = "+"
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + "%"
    }

    private func formatDate(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        guard components.count >= 2,
              let month = Int(components[1]) else {
            return dateString
        }

        let monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let monthName = month > 0 && month <= 12 ? monthNames[month] : "?"

        if components.count >= 3, let day = Int(components[2]) {
            return "\(monthName) \(day)"
        }
        return monthName
    }

    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", Double(volume) / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.1fK", Double(volume) / 1_000)
        }
        return "\(volume)"
    }
}

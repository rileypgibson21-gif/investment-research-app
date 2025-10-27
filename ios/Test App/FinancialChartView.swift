//
//  FinancialChartView.swift
//  Two-Panel Financial Chart with Dynamic Y-Axis Scaling
//
//  Created: 2025-10-26
//

import SwiftUI
import Charts

// MARK: - Data Models

struct FinancialDataPoint: Identifiable {
    let id = UUID()
    let period: String
    let value: Double  // In actual dollars (will be converted to billions)
    let date: Date

    var valueInBillions: Double {
        value / 1_000_000_000
    }
}

enum MetricType {
    case revenue
    case earnings
    case custom(name: String)

    var displayName: String {
        switch self {
        case .revenue:
            return "Revenue"
        case .earnings:
            return "Net Income"
        case .custom(let name):
            return name
        }
    }

    var allowNegative: Bool {
        switch self {
        case .revenue:
            return false  // Revenue cannot be negative
        case .earnings:
            return true   // Earnings can be negative (losses)
        case .custom:
            return true   // Custom metrics may be negative
        }
    }
}

// MARK: - Financial Chart View

struct FinancialChartView: View {
    // Data
    let quarterlyData: [FinancialDataPoint]
    let ttmData: [FinancialDataPoint]
    let metricType: MetricType
    let ticker: String

    // Styling
    private let barColor = Color(red: 0.4, green: 0.64, blue: 0.82)  // #66A3D2
    private let gridColor = Color.gray.opacity(0.3)

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("\(ticker) \(metricType.displayName)")
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Top Panel: Trailing 12 Months
            VStack(alignment: .leading, spacing: 4) {
                Text("Trailing 12 Months (Billions USD)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)

                Chart {
                    ForEach(ttmData) { dataPoint in
                        BarMark(
                            x: .value("Period", dataPoint.period),
                            y: .value("Value", dataPoint.valueInBillions)
                        )
                        .foregroundStyle(barColor)
                        .cornerRadius(2)
                    }

                    // Add zero line if metric can be negative
                    if metricType.allowNegative && ttmData.contains(where: { $0.value < 0 }) {
                        RuleMark(y: .value("Zero", 0))
                            .foregroundStyle(Color.black.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .chartYScale(domain: calculateYRange(for: ttmData, allowNegative: metricType.allowNegative))
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(gridColor)
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 16)
            }

            Divider()
                .padding(.vertical, 8)

            // Bottom Panel: Quarterly
            VStack(alignment: .leading, spacing: 4) {
                Text("Quarterly (Billions USD)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)

                Chart {
                    ForEach(quarterlyData) { dataPoint in
                        BarMark(
                            x: .value("Period", dataPoint.period),
                            y: .value("Value", dataPoint.valueInBillions)
                        )
                        .foregroundStyle(barColor)
                        .cornerRadius(2)
                    }

                    // Add zero line if metric can be negative
                    if metricType.allowNegative && quarterlyData.contains(where: { $0.value < 0 }) {
                        RuleMark(y: .value("Zero", 0))
                            .foregroundStyle(Color.black.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .chartYScale(domain: calculateYRange(for: quarterlyData, allowNegative: metricType.allowNegative))
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(gridColor)
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Dynamic Y-Axis Calculation

    /// Calculate Y-axis range with dynamic scaling based on metric type
    /// - Parameters:
    ///   - data: Array of financial data points
    ///   - allowNegative: If true, Y-axis extends below zero. If false, starts at 0.
    /// - Returns: ClosedRange for the Y-axis
    private func calculateYRange(for data: [FinancialDataPoint], allowNegative: Bool) -> ClosedRange<Double> {
        guard !data.isEmpty else {
            return 0...1
        }

        let values = data.map { $0.valueInBillions }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1

        let range = maxValue - minValue
        let padding = range * 0.1  // 10% padding

        if allowNegative {
            // For earnings/profit data: extend to lowest point
            var yMin = minValue - padding
            let yMax = maxValue + padding

            // If all data is positive, start from zero
            if minValue >= 0 {
                yMin = 0
            }

            return yMin...yMax
        } else {
            // For revenue data: always start from zero
            let yMin = 0.0
            let yMax = maxValue + padding

            return yMin...yMax
        }
    }
}

// MARK: - Helper Extensions

extension FinancialChartView {
    /// Initialize with revenue data (convenience)
    static func revenue(
        quarterly: [FinancialDataPoint],
        ttm: [FinancialDataPoint],
        ticker: String
    ) -> FinancialChartView {
        FinancialChartView(
            quarterlyData: quarterly,
            ttmData: ttm,
            metricType: .revenue,
            ticker: ticker
        )
    }

    /// Initialize with earnings data (convenience)
    static func earnings(
        quarterly: [FinancialDataPoint],
        ttm: [FinancialDataPoint],
        ticker: String
    ) -> FinancialChartView {
        FinancialChartView(
            quarterlyData: quarterly,
            ttmData: ttm,
            metricType: .earnings,
            ticker: ticker
        )
    }
}

// MARK: - Data Conversion Helpers

extension FinancialDataPoint {
    /// Create from RevenueDataPoint (from your API)
    init(from revenueDataPoint: RevenueDataPoint) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: revenueDataPoint.period) ?? Date()

        // Format period for display (e.g., "Q1 2024")
        let quarter = (Calendar.current.component(.month, from: date) - 1) / 3 + 1
        let year = Calendar.current.component(.year, from: date)
        let periodLabel = "Q\(quarter) \(year)"

        self.period = periodLabel
        self.value = revenueDataPoint.revenue
        self.date = date
    }

    /// Create from EarningsDataPoint (from your API)
    init(from earningsDataPoint: EarningsDataPoint) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: earningsDataPoint.period) ?? Date()

        // Format period for display (e.g., "Q1 2024")
        let quarter = (Calendar.current.component(.month, from: date) - 1) / 3 + 1
        let year = Calendar.current.component(.year, from: date)
        let periodLabel = "Q\(quarter) \(year)"

        self.period = periodLabel
        self.value = earningsDataPoint.earnings
        self.date = date
    }

    /// Create array from RevenueDataPoint array
    static func fromRevenueData(_ data: [RevenueDataPoint]) -> [FinancialDataPoint] {
        return data.map { FinancialDataPoint(from: $0) }
    }

    /// Create array from EarningsDataPoint array
    static func fromEarningsData(_ data: [EarningsDataPoint]) -> [FinancialDataPoint] {
        return data.map { FinancialDataPoint(from: $0) }
    }
}

// MARK: - Preview Provider

#Preview("Revenue Chart") {
    FinancialChartView.revenue(
        quarterly: [
            FinancialDataPoint(period: "Q1 2023", value: 94_836_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2023", value: 81_797_000_000, date: Date()),
            FinancialDataPoint(period: "Q3 2023", value: 89_498_000_000, date: Date()),
            FinancialDataPoint(period: "Q4 2023", value: 119_575_000_000, date: Date()),
            FinancialDataPoint(period: "Q1 2024", value: 90_753_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2024", value: 85_778_000_000, date: Date())
        ],
        ttm: [
            FinancialDataPoint(period: "Q1 2023", value: 394_328_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2023", value: 383_285_000_000, date: Date()),
            FinancialDataPoint(period: "Q3 2023", value: 383_933_000_000, date: Date()),
            FinancialDataPoint(period: "Q4 2023", value: 385_706_000_000, date: Date()),
            FinancialDataPoint(period: "Q1 2024", value: 381_600_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2024", value: 385_604_000_000, date: Date())
        ],
        ticker: "AAPL"
    )
}

#Preview("Earnings Chart") {
    FinancialChartView.earnings(
        quarterly: [
            FinancialDataPoint(period: "Q1 2023", value: 24_160_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2023", value: 19_881_000_000, date: Date()),
            FinancialDataPoint(period: "Q3 2023", value: 22_956_000_000, date: Date()),
            FinancialDataPoint(period: "Q4 2023", value: 33_916_000_000, date: Date()),
            FinancialDataPoint(period: "Q1 2024", value: 23_636_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2024", value: 21_448_000_000, date: Date())
        ],
        ttm: [
            FinancialDataPoint(period: "Q1 2023", value: 99_633_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2023", value: 96_995_000_000, date: Date()),
            FinancialDataPoint(period: "Q3 2023", value: 96_995_000_000, date: Date()),
            FinancialDataPoint(period: "Q4 2023", value: 100_913_000_000, date: Date()),
            FinancialDataPoint(period: "Q1 2024", value: 101_389_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2024", value: 101_300_000_000, date: Date())
        ],
        ticker: "AAPL"
    )
}

#Preview("Losses Chart") {
    FinancialChartView.earnings(
        quarterly: [
            FinancialDataPoint(period: "Q1 2023", value: -500_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2023", value: -1_200_000_000, date: Date()),
            FinancialDataPoint(period: "Q3 2023", value: 300_000_000, date: Date()),
            FinancialDataPoint(period: "Q4 2023", value: 800_000_000, date: Date()),
            FinancialDataPoint(period: "Q1 2024", value: -200_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2024", value: 100_000_000, date: Date())
        ],
        ttm: [
            FinancialDataPoint(period: "Q1 2023", value: -2_000_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2023", value: -1_400_000_000, date: Date()),
            FinancialDataPoint(period: "Q3 2023", value: -600_000_000, date: Date()),
            FinancialDataPoint(period: "Q4 2023", value: 0, date: Date()),
            FinancialDataPoint(period: "Q1 2024", value: -600_000_000, date: Date()),
            FinancialDataPoint(period: "Q2 2024", value: -500_000_000, date: Date())
        ],
        ticker: "LOSS"
    )
}

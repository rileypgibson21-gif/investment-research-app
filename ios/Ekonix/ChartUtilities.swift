//
//  ChartUtilities.swift
//  Ekonix
//
//  Created by Claude Code
//

import Foundation

// MARK: - Chart Utilities
enum ChartUtilities {

    // MARK: - Date Formatting

    /// Formats a date string to quarter format (e.g., "Q1 '24")
    /// Handles multiple formats: YYYY-MM-DD, YYYY-MM, or direct quarter strings
    /// NOTE: SEC filing dates in early month (days 1-7) represent the END of the previous month's quarter
    /// For example, "2023-07-01" is the filing date for Q2 (ending June 30), not Q3
    static func formatQuarterDate(_ dateString: String) -> String {
        // Handle YYYY-MM-DD or YYYY-MM format
        let components = dateString.split(separator: "-")
        guard components.count >= 2,
              let year = components.first,
              var month = Int(components[1]) else {
            return dateString
        }

        // If the date is in the first week of the month (days 1-7), it likely represents
        // a filing date for the previous month's quarter end
        // Example: 2023-07-01 = filing for Q2 ending June 30
        if components.count >= 3, let day = Int(components[2]), day <= 7 {
            month -= 1
            if month == 0 {
                month = 12
            }
        }

        // Calculate quarter from month (1-12 -> Q1-Q4)
        // Q1: Jan(1), Feb(2), Mar(3)
        // Q2: Apr(4), May(5), Jun(6)
        // Q3: Jul(7), Aug(8), Sep(9)
        // Q4: Oct(10), Nov(11), Dec(12)
        let quarter = (month - 1) / 3 + 1
        let shortYear = year.suffix(2)
        return "Q\(quarter) '\(shortYear)"
    }

    /// Formats a date string with detailed month information
    static func formatDetailedQuarterDate(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        guard components.count >= 2,
              let year = components.first,
              let month = Int(components[1]) else {
            return dateString
        }

        let monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let quarter = (month - 1) / 3 + 1
        let monthName = month > 0 && month <= 12 ? monthNames[month] : "?"
        let shortYear = year.suffix(2)

        return "\(monthName) '\(shortYear) (Q\(quarter))"
    }

    /// Formats a date string to year only (e.g., "'24")
    /// Used for X-axis labels where space is limited
    static func formatYearOnly(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        guard let year = components.first else {
            return dateString
        }
        let shortYear = year.suffix(2)
        return "'\(shortYear)"
    }

    // MARK: - Value Formatting

    /// Formats a revenue/currency value with appropriate suffix (T, B, M, K)
    static func formatCurrencyValue(_ value: Double) -> String {
        if abs(value) >= 1_000_000_000_000 {
            return String(format: "$%.2fT", value / 1_000_000_000_000)
        } else if abs(value) >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if abs(value) >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else if abs(value) >= 1_000 {
            return String(format: "$%.2fK", value / 1_000)
        } else {
            return String(format: "$%.0f", value)
        }
    }

    /// Formats Y-axis values with 3-digit limit, no suffix
    static func formatYAxisValue(_ value: Double) -> String {
        if abs(value) >= 1_000_000_000_000 {
            let rounded = value / 1_000_000_000_000
            return String(format: "%.0f", rounded)
        } else if abs(value) >= 1_000_000_000 {
            let rounded = value / 1_000_000_000
            return String(format: "%.0f", rounded)
        } else if abs(value) >= 1_000_000 {
            let rounded = value / 1_000_000
            return String(format: "%.0f", rounded)
        } else if abs(value) >= 1_000 {
            let rounded = value / 1_000
            return String(format: "%.0f", rounded)
        } else {
            return String(format: "%.0f", value)
        }
    }

    /// Formats a percentage value with + sign
    static func formatPercentage(_ value: Double) -> String {
        return String(format: "%+.1f%%", value)
    }

    /// Formats Y-axis percentage values (3 digits max, no % sign)
    static func formatYAxisPercentage(_ value: Double) -> String {
        if value == 0 {
            return "0"
        }
        return String(format: "%.0f", value)
    }

    // MARK: - Financial Y-Axis Formatting

    /// Value scale for Y-axis labels
    enum ValueScale {
        case billions
        case millions
        case thousands
        case ones

        var divisor: Double {
            switch self {
            case .billions: return 1_000_000_000
            case .millions: return 1_000_000
            case .thousands: return 1_000
            case .ones: return 1
            }
        }

        var suffix: String {
            switch self {
            case .billions: return "b"
            case .millions: return "m"
            case .thousands: return "k"
            case .ones: return ""
            }
        }
    }

    /// Detect appropriate scale for financial values
    static func detectValueScale(values: [Double]) -> ValueScale {
        let maxAbs = values.map { abs($0) }.max() ?? 0

        if maxAbs >= 1_000_000_000 {
            return .billions
        } else if maxAbs >= 1_000_000 {
            return .millions
        } else if maxAbs >= 1_000 {
            return .thousands
        } else {
            return .ones
        }
    }

    /// Format Y-axis label with financial notation ($10b, -$250m, $0)
    static func formatFinancialYAxisLabel(_ value: Double, scale: ValueScale) -> String {
        if value == 0 {
            return "$0"
        }

        let scaledValue = value / scale.divisor
        let isNegative = value < 0
        let absScaledValue = abs(scaledValue)

        // Format with appropriate precision
        let formattedNumber: String
        if absScaledValue >= 100 {
            formattedNumber = String(format: "%.0f", absScaledValue)
        } else if absScaledValue >= 10 {
            formattedNumber = String(format: "%.1f", absScaledValue)
        } else {
            formattedNumber = String(format: "%.1f", absScaledValue)
        }

        let prefix = isNegative ? "-$" : "$"
        return "\(prefix)\(formattedNumber)\(scale.suffix)"
    }

    /// Format Y-axis percentage label (+25%, -10%, 0%)
    static func formatPercentageYAxisLabel(_ value: Double) -> String {
        if value == 0 {
            return "0%"
        }
        return String(format: "%+.0f%%", value)
    }

    // MARK: - Chart Calculations

    /// Rounds a value to a nice number for chart scaling
    static func roundToNiceNumber(_ value: Double) -> Double {
        guard value > 0 else { return 0 }

        let magnitude = pow(10, floor(log10(value)))
        let normalized = value / magnitude

        if normalized <= 1 {
            return 1 * magnitude
        } else if normalized <= 1.5 {
            return 1.5 * magnitude
        } else if normalized <= 2 {
            return 2 * magnitude
        } else if normalized <= 3 {
            return 3 * magnitude
        } else if normalized <= 5 {
            return 5 * magnitude
        } else if normalized <= 7.5 {
            return 7.5 * magnitude
        } else {
            return 10 * magnitude
        }
    }

    /// Calculate Y-axis range that adapts to data
    /// - All positive values: returns (0, maxValue) - Y-axis starts at zero
    /// - Has negative values: returns (minValue, maxValue) aligned to tick intervals for perfect spacing
    static func calculateAdaptiveRange(values: [Double]) -> (min: Double, max: Double) {
        guard !values.isEmpty else { return (0, 0) }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0

        if minValue >= 0 {
            // All positive: scale from 0 to nice max (current behavior)
            return (0, roundToNiceNumber(maxValue * 1.05))
        } else {
            // Has negatives: calculate range using same logic as tick generation
            // to ensure perfect alignment between bars, gridlines, and labels
            let range = maxValue - minValue
            let roughInterval = range / 4.0  // Target ~5 ticks
            let niceInterval = calculateNiceInterval(roughInterval)

            // Round min DOWN to nearest interval multiple (e.g., -35 with interval 100 → -100)
            let niceMin = floor(minValue / niceInterval) * niceInterval

            // Round max UP to nearest interval multiple (e.g., 250 with interval 100 → 300)
            let niceMax = ceil(maxValue / niceInterval) * niceInterval

            return (niceMin, niceMax)
        }
    }

    // MARK: - Nice Tick Generation

    /// Calculate a nice interval for axis ticks (1, 2, 2.5, 5, 10, 20, 25, 50, etc.)
    private static func calculateNiceInterval(_ roughInterval: Double) -> Double {
        guard roughInterval > 0 else { return 1 }

        let magnitude = pow(10, floor(log10(roughInterval)))
        let normalized = roughInterval / magnitude

        let niceNormalized: Double
        if normalized <= 1 { niceNormalized = 1 }
        else if normalized <= 2 { niceNormalized = 2 }
        else if normalized <= 2.5 { niceNormalized = 2.5 }
        else if normalized <= 5 { niceNormalized = 5 }
        else { niceNormalized = 10 }

        return niceNormalized * magnitude
    }

    /// Generate nice tick values spanning min to max
    /// Ensures even spacing, especially when range spans zero
    private static func generateNiceTickValues(min: Double, max: Double, targetCount: Int) -> [Double] {
        let range = max - min
        guard range > 0 else { return [0] }

        // Calculate rough tick interval
        let roughInterval = range / Double(targetCount - 1)

        // Round to nice number (1, 2, 5, 10, 20, 25, 50, 100, etc.)
        let niceInterval = calculateNiceInterval(roughInterval)

        // When range spans zero, generate ticks symmetrically from zero
        // This ensures perfect even spacing and zero is always included
        if min < 0 && max > 0 {
            var ticks: [Double] = [0]

            // Generate positive ticks
            var tick = niceInterval
            while tick <= max + (niceInterval * 0.01) {
                ticks.append(tick)
                tick += niceInterval
            }

            // Generate negative ticks
            tick = -niceInterval
            while tick >= min - (niceInterval * 0.01) {
                ticks.append(tick)
                tick -= niceInterval
            }

            return ticks.sorted(by: >)
        }

        // For non-zero-spanning ranges, use original algorithm
        var ticks: [Double] = []
        let startTick = floor(min / niceInterval) * niceInterval

        var currentTick = startTick
        while currentTick <= max + (niceInterval * 0.01) {
            if currentTick >= min - (niceInterval * 0.01) {
                ticks.append(currentTick)
            }
            currentTick += niceInterval
        }

        return ticks.sorted(by: >)
    }

    /// Generates Y-axis labels with nice, round numbers
    static func generateYAxisLabels(maxValue: Double, targetCount: Int = 5) -> [Double] {
        guard maxValue > 0 else { return [0] }

        // Find nice numbers that span 0 to maxValue
        return generateNiceTickValues(min: 0, max: maxValue, targetCount: targetCount)
    }

    /// Generates Y-axis labels for a range (supports negative values)
    /// Ensures 0 is always included as a label when range spans zero
    static func generateYAxisLabels(minValue: Double, maxValue: Double, targetCount: Int = 5) -> [Double] {
        guard maxValue > minValue else { return [0] }

        // Find nice numbers that span the range, ensuring 0 is included if range spans it
        return generateNiceTickValues(min: minValue, max: maxValue, targetCount: targetCount)
    }

    /// Generates Y-axis labels centered around zero (for positive/negative charts)
    static func generateCenteredYAxisLabels(maxAbsValue: Double) -> [Double] {
        return [maxAbsValue, maxAbsValue * 0.5, 0, -maxAbsValue * 0.5, -maxAbsValue]
    }
}

// MARK: - Constants
enum ChartConstants {
    static let quarterlyDataLimit = 40  // 10 years of quarterly data
    static let ttmDataLimit = 37        // 37 TTM periods
    static let growthDataLimit = 36     // 36 growth periods (10 years minus 4 quarters needed for YoY calc)

    static let chartHeight: CGFloat = 240
    static let barChartHeight: CGFloat = 210
    static let yAxisWidth: CGFloat = 50  // Width of Y-axis labels on left
    static let rightPadding: CGFloat = 50  // Match Y-axis width to center chart bars
    static let barSpacing: CGFloat = 2  // Minimal spacing for 40 bars to fit on screen

    static let scrollDelay: TimeInterval = 0.1
}

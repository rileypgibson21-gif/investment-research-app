//
//  ChartUtilities.swift
//  Test App
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

    /// Generates Y-axis labels with equal intervals
    static func generateYAxisLabels(maxValue: Double, divisions: Int = 4) -> [Double] {
        let interval = maxValue / Double(divisions)
        var labels: [Double] = []

        for i in 0...divisions {
            labels.append(maxValue - (interval * Double(i)))
        }

        return labels
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
    static let yAxisWidth: CGFloat = 35
    static let barSpacing: CGFloat = 2  // Minimal spacing for 40 bars to fit on screen

    static let scrollDelay: TimeInterval = 0.1
}

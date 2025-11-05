# New Metric Tab Workflow

This document provides a step-by-step guide for adding a new financial metric tab to the Ekonix app. Follow this workflow to ensure consistency across all metric implementations.

## Overview

Each financial metric (e.g., Revenue, Net Income, Operating Income, Gross Profit) requires:
- **Backend endpoints** (quarterly + TTM data)
- **3 iOS chart views** (Quarterly, TTM, YoY Growth)
- **1 combined view** with data table
- **UI integration** (menu button + content section)

---

## Step 1: Backend Implementation

### 1.1 Add Routes (`backend/src/index.js`)

Add two new routes in the main router (around line 34-52):

```javascript
} else if (url.pathname.startsWith('/api/your-metric-ttm/')) {
  return await handleTTMYourMetric(request, env, url);
} else if (url.pathname.startsWith('/api/your-metric/')) {
  return await handleYourMetric(request, env, url);
}
```

**Pattern:** TTM route must come BEFORE quarterly route to avoid matching conflicts.

### 1.2 Add Endpoint Handlers

Add two handler functions after existing handlers (around line 185-225):

```javascript
/**
 * Handle quarterly your-metric from SEC EDGAR
 * GET /api/your-metric/:symbol
 */
async function handleYourMetric(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const yourMetric = extractYourMetric(facts);
    return jsonResponse(yourMetric);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM your-metric from SEC EDGAR
 * GET /api/your-metric-ttm/:symbol
 */
async function handleTTMYourMetric(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const yourMetric = extractTTMYourMetric(facts);
    return jsonResponse(yourMetric);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}
```

### 1.3 Add Extraction Functions

Add two extraction functions after existing extractors (around line 750-884):

```javascript
/**
 * Extract quarterly your-metric (last 40 quarters = 10 years)
 * Description of what this metric represents
 */
function extractYourMetric(facts) {
  const yourMetricKeys = [
    'YourGAAPFieldName',  // Primary SEC GAAP field
    'AlternativeGAAPFieldName'  // Fallback if needed
  ];

  const allQuarterly = [];
  const allCumulative = [];

  for (const key of yourMetricKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units?.USD;
      if (!units) continue;

      for (const item of units) {
        if (!item.val || item.val === 0 || !item.start || !item.end) continue;

        const startDate = new Date(item.start);
        const endDate = new Date(item.end);
        const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);

        if (daysDiff >= 70 && daysDiff <= 120) {
          allQuarterly.push(item);
        } else if (daysDiff >= 150 && daysDiff <= 380) {
          allCumulative.push(item);
        }
      }
    }
  }

  // Deduplicate and sort (copy from existing extractors)
  const quarterlyDeduped = allQuarterly
    .filter(item => item.frame && /Q[1-4]/.test(item.frame))
    .sort((a, b) => {
      if (a.end !== b.end) return b.end.localeCompare(a.end);
      const aIsAmended = a.form && a.form.includes('/A');
      const bIsAmended = b.form && b.form.includes('/A');
      if (aIsAmended && !bIsAmended) return -1;
      if (!aIsAmended && bIsAmended) return 1;
      return (b.filed || '').localeCompare(a.filed || '');
    })
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.end)) {
        acc.push({ period: item.end, yourMetric: item.val, start: item.start });
      }
      return acc;
    }, []);

  // Calculate missing Q4 from annual data (copy from existing extractors)
  const calculated = [];
  for (const annual of allCumulative) {
    const annualStart = annual.start;
    const annualEnd = annual.end;
    const annualDays = (new Date(annualEnd) - new Date(annualStart)) / (1000 * 60 * 60 * 24);

    if (annualDays < 330 || annualDays > 380) continue;

    const nineMonth = allCumulative.find(item =>
      item.start === annualStart &&
      item.end < annualEnd &&
      Math.abs((new Date(item.end) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 270) < 30
    );

    if (nineMonth) {
      const q4YourMetric = annual.val - nineMonth.val;
      const hasQuarter = quarterlyDeduped.find(x => x.period === annualEnd);
      if (!hasQuarter) {
        calculated.push({ period: annualEnd, yourMetric: q4YourMetric, start: nineMonth.end });
      }
    }
  }

  const combined = [...quarterlyDeduped.map(x => ({ period: x.period, yourMetric: x.yourMetric })), ...calculated];

  const final = combined
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push({ period: item.period, yourMetric: item.yourMetric });
      }
      return acc;
    }, []);

  return final.slice(0, 40);
}

/**
 * Extract TTM your-metric (last 37 periods)
 */
function extractTTMYourMetric(facts) {
  const quarterly = extractYourMetric(facts);
  if (quarterly.length < 4) return [];

  const ttm = [];
  for (let i = 3; i < quarterly.length; i++) {
    const last4Quarters = quarterly.slice(i - 3, i + 1);
    const ttmYourMetric = last4Quarters.reduce((sum, q) => sum + q.yourMetric, 0);

    ttm.push({
      period: quarterly[i - 3].period,
      yourMetric: ttmYourMetric
    });
  }

  return ttm.slice(0, 37);
}
```

**Key SEC GAAP Fields:**
- Revenue: `RevenueFromContractWithCustomerExcludingAssessedTax`, `Revenues`
- Net Income: `NetIncomeLoss`
- Operating Income: `OperatingIncomeLoss`
- Gross Profit: `GrossProfit`
- Find more at: https://xbrlview.fasb.org/yeti

---

## Step 2: iOS Chart Views

### 2.1 Create Quarterly Chart (`ios/Ekonix/YourMetricChartView.swift`)

Copy `GrossProfitChartView.swift` or `OperatingIncomeChartView.swift` and replace:
- Struct name: `GrossProfitChartView` → `YourMetricChartView`
- Data point type: `GrossProfitDataPoint` → `YourMetricDataPoint`
- Property names: `grossProfit` → `yourMetric`
- Display text: `"Quarterly Gross Profit"` → `"Quarterly Your Metric"`
- API call: `fetchGrossProfit` → `fetchYourMetric`

**Color:** Use blue for all absolute value metrics (`.blue`)

### 2.2 Create TTM Chart (`ios/Ekonix/TTMYourMetricChartView.swift`)

Copy `TTMGrossProfitChartView.swift` and replace similar names.

**Display text:** `"Trailing Twelve Months Your Metric"`

### 2.3 Create YoY Growth Chart (`ios/Ekonix/YoYYourMetricGrowthChartView.swift`)

Copy `YoYGrossProfitGrowthChartView.swift` and replace similar names.

**Colors:** Green for positive growth, red for negative (`.green`, `.red`)

**Display text:** `"TTM YoY Your Metric Growth"`

---

## Step 3: iOS Data Integration

### 3.1 Add Data Point Struct (`ios/Ekonix/ContentView.swift`)

After `GrossProfitDataPoint` (around line 865-869):

```swift
struct YourMetricDataPoint: Identifiable {
    let id = UUID()
    let period: String
    let yourMetric: Double
}
```

### 3.2 Add API Fetch Methods

In `StockAPIService` class, after `fetchTTMGrossProfit` (around line 228-288):

```swift
// MARK: - Your Metric Data (From Your API)
func fetchYourMetric(symbol: String) async throws -> [YourMetricDataPoint] {
    let urlString = "\(apiBaseURL)/api/your-metric/\(symbol.uppercased())"
    guard let url = URL(string: urlString) else {
        throw APIError.invalidURL
    }

    let (data, _) = try await URLSession.shared.data(from: url)

    struct APIYourMetricResponse: Codable {
        let period: String
        let yourMetric: Double
    }

    let yourMetricData = try JSONDecoder().decode([APIYourMetricResponse].self, from: data)

    #if DEBUG
    if !yourMetricData.isEmpty {
        print("📊 Your Metric data for \(symbol):")
        yourMetricData.prefix(3).forEach { item in
            let formatted = ChartUtilities.formatQuarterDate(item.period)
            print("  Raw: \(item.period) -> Formatted: \(formatted)")
        }
    }
    #endif

    return yourMetricData.map {
        YourMetricDataPoint(period: $0.period, yourMetric: $0.yourMetric)
    }
}

// MARK: - TTM Your Metric Data (From Your API)
func fetchTTMYourMetric(symbol: String) async throws -> [YourMetricDataPoint] {
    let urlString = "\(apiBaseURL)/api/your-metric-ttm/\(symbol.uppercased())"
    guard let url = URL(string: urlString) else {
        throw APIError.invalidURL
    }

    let (data, _) = try await URLSession.shared.data(from: url)

    struct APIYourMetricResponse: Codable {
        let period: String
        let yourMetric: Double
    }

    let yourMetricData = try JSONDecoder().decode([APIYourMetricResponse].self, from: data)

    #if DEBUG
    if !yourMetricData.isEmpty {
        print("📊 TTM Your Metric data for \(symbol):")
        yourMetricData.prefix(3).forEach { item in
            let formatted = ChartUtilities.formatQuarterDate(item.period)
            print("  Raw: \(item.period) -> Formatted: \(formatted)")
        }
    }
    #endif

    return yourMetricData.map {
        YourMetricDataPoint(period: $0.period, yourMetric: $0.yourMetric)
    }
}
```

### 3.3 Create Combined Charts View

After `GrossProfitChartsView` (around line 882-1085):

```swift
// MARK: - Combined Your Metric Charts View (Quarterly + TTM + YoY Growth)
struct YourMetricChartsView: View {
    let symbol: String
    let apiService: StockAPIService

    @State private var quarterlyData: [YourMetricDataPoint] = []
    @State private var ttmData: [YourMetricDataPoint] = []
    @State private var yoyData: [YourMetricDataPoint] = []
    @State private var isLoading = false

    struct TableRowData: Identifiable {
        let id = UUID()
        let period: String
        let quarterlyYourMetric: Double?
        let ttmYourMetric: Double?
        let yoyPercent: Double?
    }

    var tableData: [TableRowData] {
        let maxRows = min(max(quarterlyData.count, ttmData.count), 40)
        guard maxRows > 0 else { return [] }

        var rows: [TableRowData] = []
        for index in 0..<maxRows {
            let quarterly = index < quarterlyData.count ? quarterlyData[index] : nil
            let ttm = index < ttmData.count ? ttmData[index] : nil

            var yoy: Double? = nil
            if let ttm = ttm,
               index + 4 < ttmData.count,
               ttmData[index + 4].yourMetric != 0 {
                let prior = ttmData[index + 4].yourMetric
                yoy = ((ttm.yourMetric - prior) / prior) * 100
            }

            rows.append(TableRowData(
                period: quarterly?.period ?? ttm?.period ?? "",
                quarterlyYourMetric: quarterly?.yourMetric,
                ttmYourMetric: ttm?.yourMetric,
                yoyPercent: yoy
            ))
        }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                YourMetricChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    quarterlyData = data
                })

                Divider()
                    .padding(.vertical, 20)

                TTMYourMetricChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    ttmData = data
                })

                Divider()
                    .padding(.vertical, 20)

                YoYYourMetricGrowthChartView(symbol: symbol, apiService: apiService, onDataLoaded: { data in
                    yoyData = data
                })

                // Combined Your Metric Details Table
                if !tableData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Metric Details")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 0) {
                            // Fixed Quarter Column
                            VStack(spacing: 0) {
                                Text("Quarter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                    .padding(.vertical, 8)

                                Divider()

                                ForEach(tableData) { row in
                                    VStack(spacing: 0) {
                                        Text(formatDate(row.period))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                            .frame(width: 80, alignment: .leading)
                                            .padding(.vertical, 8)

                                        if row.id != tableData.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 16)

                            // Scrollable Data Columns
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        Text("Quarterly")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("TTM")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text("YoY")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.trailing, 16)

                                    Divider()

                                    ForEach(tableData) { row in
                                        VStack(spacing: 0) {
                                            HStack(spacing: 0) {
                                                if let yourMetric = row.quarterlyYourMetric {
                                                    Text(formatValue(yourMetric))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(yourMetric >= 0 ? .blue : .red)
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                if let ttmYourMetric = row.ttmYourMetric {
                                                    Text(formatValue(ttmYourMetric))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(ttmYourMetric >= 0 ? .blue : .red)
                                                        .frame(width: 120, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 120, alignment: .trailing)
                                                }

                                                if let yoy = row.yoyPercent {
                                                    Text(String(format: "%+.1f%%", yoy))
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(yoy >= 0 ? .green : .red)
                                                        .frame(width: 80, alignment: .trailing)
                                                } else {
                                                    Text("-")
                                                        .font(.caption)
                                                        .frame(width: 80, alignment: .trailing)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.trailing, 16)

                                            if row.id != tableData.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        ChartUtilities.formatQuarterDate(dateString)
    }

    private func formatValue(_ value: Double) -> String {
        ChartUtilities.formatCurrencyValue(value)
    }
}
```

---

## Step 4: UI Integration

### 4.1 Add Menu Button

In `ContentView.swift`, after the last metric button (around line 1925-1931):

```swift
Button(action: { selectedTab = N }) {  // N = next available tab number
    if selectedTab == N {
        Label("Your Metric", systemImage: "checkmark")
    } else {
        Text("Your Metric")
    }
}
```

### 4.2 Update Menu Label

Update the ternary operator chain in the menu label (around line 1934):

```swift
Text(selectedTab == 0 ? "Overview" :
     selectedTab == 1 ? "Revenue" :
     selectedTab == 2 ? "Net Income" :
     selectedTab == 3 ? "Operating Income" :
     selectedTab == 4 ? "Gross Profit" :
     "Your Metric")
```

### 4.3 Add Content Section

Add content section after the last `else if` (around line 1981-1989):

```swift
} else if selectedTab == N {
    // Your Metric
    YourMetricChartsView(symbol: item.symbol, apiService: apiService)
        .padding(.bottom, 40)
}
```

**Pattern:** Use `else if` for all tabs except the last one (use `else` for final tab).

---

## Step 5: Documentation

### 5.1 Update CLAUDE.md

Add references to new chart files:

**iOS Charts section:**
```markdown
- `ios/Ekonix/YourMetricChartView.swift`
- `ios/Ekonix/TTMYourMetricChartView.swift`
- `ios/Ekonix/YoYYourMetricGrowthChartView.swift`
```

**Update chart count:** "Now 15 total chart files" → "Now 18 total chart files"

### 5.2 Update backend/README.md

Document new endpoints:
```markdown
GET /api/your-metric/:symbol - Quarterly your metric (last 40 quarters)
GET /api/your-metric-ttm/:symbol - TTM your metric (last 37 periods)
```

---

## Testing Checklist

- [ ] Backend endpoints return valid JSON
- [ ] Quarterly data shows ~40 quarters
- [ ] TTM data shows ~37 periods
- [ ] YoY growth calculations are correct (compare to 4 quarters ago)
- [ ] Charts render without errors
- [ ] Table displays all three data types correctly
- [ ] Tab switching works smoothly
- [ ] Blue bars for absolute values
- [ ] Green/red bars for growth percentages
- [ ] Tooltip shows correct formatted values

---

## Common Pitfalls

1. **Route Order:** TTM routes must come BEFORE quarterly routes in router
2. **Field Names:** Ensure backend field names (`yourMetric`) match iOS structs
3. **Color Consistency:** Use blue for values, green/red for growth
4. **Tab Numbers:** Maintain sequential tab numbers (0, 1, 2, 3, 4, ...)
5. **Ternary Chains:** Update all ternary operator chains when adding tabs
6. **Data Point Structs:** Must implement `Identifiable` with `id = UUID()`

---

## File Count Summary

Per new metric, you will create/modify:

**New Files:**
- 3 Swift chart view files
- 0 new backend files (modifications only)

**Modified Files:**
- `backend/src/index.js` - Routes, handlers, extractors (~200 lines added)
- `ios/Ekonix/ContentView.swift` - Data point, API methods, combined view, UI integration (~250 lines added)
- `CLAUDE.md` - Documentation updates
- `backend/README.md` - Endpoint documentation

**Total:** ~450-500 lines of code per new metric tab

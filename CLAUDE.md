# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**Investment Research App** - iOS app displaying company financial metrics (revenue, earnings, YoY growth) sourced from SEC EDGAR filings. 100% free data, $0/month operational cost, App Store compliant.

**Architecture:** iOS SwiftUI app → Cloudflare Worker (SEC API proxy + KV cache) → SEC EDGAR API

**Key Constraint:** All data must come from free SEC EDGAR API. No paid APIs, no API keys.

---

## Essential Commands

### iOS Development

```bash
# Build the iOS app
cd ios
xcodebuild -project "Test App.xcodeproj" -scheme "Test App" -sdk iphonesimulator build

# Clean build
xcodebuild -project "Test App.xcodeproj" -scheme "Test App" -sdk iphonesimulator clean build

# Run UI tests (currently minimal - only launch test exists)
xcodebuild -project "Test App.xcodeproj" -scheme "Test App" -sdk iphonesimulator test
```

**Note:** Most development happens in Xcode IDE. Open `ios/Test App.xcodeproj` directly.

### Backend (Cloudflare Worker)

```bash
cd backend

# Install dependencies
npm install

# Local development (runs worker at localhost:8787)
npm run dev

# Deploy to production
npm run deploy

# View live logs
npm run tail
```

### Git Workflow

```bash
# Check status
git status

# Commit changes (use descriptive messages with Claude Code footer)
git add .
git commit -m "Description

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to GitHub
git push origin main
```

---

## Architecture Deep Dive

### Data Flow

1. **iOS App** (`ContentView.swift`) contains `StockAPIService` class that makes HTTP requests
2. **Cloudflare Worker** (`backend/src/index.js`) receives requests, checks KV cache, fetches from SEC if miss
3. **SEC EDGAR API** returns company facts JSON with quarterly revenue/earnings data
4. **Worker calculates** TTM values (sum of last 4 quarters) before returning to iOS
5. **iOS renders** data in separate chart view files

### Critical Architecture Principles

**Chart Performance Pattern:**
Complex SwiftUI charts were extracted from ContentView.swift into separate files to avoid compiler timeouts. Each chart file is ~300 lines and compiles independently:
- `EarningsChartView.swift` - Quarterly earnings
- `TTMEarningsChartView.swift` - TTM earnings
- `YoYGrowthChartView.swift` - Revenue YoY growth
- `YoYEarningsGrowthChartView.swift` - Earnings YoY growth

**Chart Rendering Approach:**
All charts use identical offset-based bar positioning (not split top/bottom halves):
```swift
// Single ZStack with bar offset from bottom
RoundedRectangle(cornerRadius: 2)
    .fill(barColor)
    .frame(width: dynamicBarWidth, height: heightValue)
    .offset(y: -offsetValue)  // Position relative to zero line
```

**Y-Axis Label Alignment:**
Uses ZStack with calculated offsets (not VStack with Spacers) for pixel-perfect gridline alignment:
```swift
ZStack(alignment: .trailing) {
    ForEach(Array(getYAxisLabels().enumerated()), id: \.offset) { index, value in
        Text(formatYAxisValue(value))
            .offset(y: yOffsetForLabel(at: index))  // Precise positioning
    }
}
```

**Dynamic Bar Width Calculation:**
Charts must fit 36-40 bars on screen without scrolling:
```swift
let availableWidth = geometry.size.width - ChartConstants.yAxisWidth - 16
let barCount = CGFloat(displayData.count)
let dynamicBarWidth = max((availableWidth - (barCount - 1) * ChartConstants.barSpacing) / barCount, 3)
```

### Backend SEC API Integration

**Company Facts Endpoint:**
```javascript
// Fetch from SEC
const cik = await lookupCIK(symbol);
const url = `https://data.sec.gov/api/xbrl/companyfacts/CIK${cik}.json`;
const response = await fetch(url, {
  headers: { 'User-Agent': 'InvestmentResearchApp contact@example.com' }
});
```

**User-Agent Requirement:** SEC API requires descriptive User-Agent or returns 403.

**Revenue Data Extraction:**
SEC uses two different GAAP concepts for revenue:
- `us-gaap/Revenues`
- `us-gaap/RevenueFromContractWithCustomerExcludingAssessedTax`

Backend tries both and returns whichever has data.

**TTM Calculation:**
```javascript
// Sum last 4 quarters for each period
for (let i = 3; i < data.length; i++) {
  const ttm = data[i].revenue + data[i-1].revenue +
              data[i-2].revenue + data[i-3].revenue;
  ttmData.push({ period: data[i].period, revenue: ttm });
}
```

**Caching Strategy:**
- Company facts: 24 hours (data updates quarterly)
- Ticker list: 7 days (rarely changes)
- All KV cache keys prefixed: `companyFacts:AAPL`, `tickers`

---

## Shared Chart Utilities

**Location:** `ios/Test App/ChartUtilities.swift`

**Purpose:** Centralized formatting and constants to ensure consistency across all 4 chart views.

**Key Functions:**
- `formatCurrencyValue()` - Converts to billions: `94933000000 → "$94.93B"`
- `formatPercentage()` - YoY growth: `12.5 → "+12.5%"`
- `formatQuarterDate()` - Period labels: `"2024-09-30" → "Q3 2024"`
- `formatYearOnly()` - X-axis labels: `"2024-09-30" → "2024"`
- `calculateAdaptiveRange()` - Y-axis scaling for negative values
- `generateYAxisLabels()` - Ensures zero always included when data spans negative/positive
- `roundToNiceNumber()` - Y-axis rounding (10, 20, 50, 100, etc.)

**Chart Constants:**
```swift
static let chartHeight: CGFloat = 200
static let yAxisWidth: CGFloat = 50
static let barSpacing: CGFloat = 3
static let quarterlyDataLimit = 40  // 10 years
static let ttmDataLimit = 37        // ~9 years
static let growthDataLimit = 36     // 9 years YoY
```

---

## Color Scheme Rules

**Strictly enforced across all charts:**

- **Revenue/Earnings (actual values):** Blue (`Color.blue`)
- **YoY Growth (positive):** Green (`Color.green`)
- **YoY Growth (negative):** Red (`Color.red`)
- **Selected bars:** Same color with `.opacity(0.8)`
- **Tooltips:** White text on colored background matching bar color

**Exception:** Growth charts must use green/red to indicate positive/negative growth direction.

---

## Data Models

**Core Types in ContentView.swift:**

```swift
struct RevenueDataPoint: Identifiable, Codable {
    var id = UUID()
    let period: String   // "2024-09-30"
    let revenue: Double  // In dollars: 94933000000
}

struct EarningsDataPoint: Identifiable, Codable {
    var id = UUID()
    let period: String    // "2024-09-30"
    let earnings: Double  // In dollars, can be negative
}

struct TickerSuggestion: Identifiable, Codable {
    let id = UUID()
    let ticker: String  // "AAPL"
    let name: String    // "Apple Inc."
    let cik: String     // "0000320193"
}
```

**Period Format:** Always `YYYY-MM-DD` (ISO 8601 date) from SEC API, converted to display formats by ChartUtilities.

---

## Test Folders

**`ios/Test AppTests/`** - Empty folder for unit tests (none implemented yet)

**`ios/Test AppUITests/`** - Contains one basic UI test:
- `Test_AppUITestsLaunchTests.swift` - Takes screenshot on launch

These are Xcode-generated test targets. Currently minimal but kept for future test expansion.

---

## Common Development Patterns

### Adding a New Chart

1. Create new file: `ios/Test App/NewChartView.swift`
2. Follow existing chart pattern (see EarningsChartView.swift)
3. Use `ChartUtilities` for all formatting
4. Import constants: `ChartConstants.chartHeight`, etc.
5. Implement required functions:
   - `barHeight(for:in:)` - Calculate bar height
   - `barOffset(for:barHeight:in:)` - Position from zero line
   - `yOffsetForLabel(at:)` - Align Y-axis labels

### Modifying Backend Endpoint

1. Edit `backend/src/index.js`
2. Add route handler in main router
3. Implement SEC API call with User-Agent
4. Add KV caching with appropriate TTL
5. Test locally: `npm run dev`
6. Deploy: `npm run deploy`
7. Update `backend/README.md` with new endpoint

### Changing Chart Appearance

1. **Colors:** Search for `.fill(Color.blue)` in chart files
2. **Bar Width:** Modify `ChartConstants.barSpacing` in ChartUtilities.swift
3. **Data Limit:** Change `ChartConstants.quarterlyDataLimit` (affects all quarterly charts)
4. **Y-Axis Width:** Adjust `ChartConstants.yAxisWidth`

**Warning:** Changes to ChartConstants affect all 4 chart views simultaneously.

---

## Key Constraints

1. **All data must be free** - No paid APIs allowed (App Store compliance)
2. **SEC EDGAR only** - Single source of truth for financial data
3. **No API keys** - Everything uses public data
4. **Charts must fit on screen** - 36-40 bars visible without horizontal scrolling
5. **Zero line must be visible** - When data spans negative/positive values
6. **Consistent color scheme** - Blue for metrics, green/red for growth only

---

## File References

**Must read before major changes:**
- `PROJECT_STATE.md` - Current project state, recent changes, architecture
- `backend/README.md` - Backend API documentation, endpoints, caching
- `VERSION_HISTORY.md` - Version changelog

**Backend:**
- `backend/src/index.js` (590 lines) - All API logic, SEC integration, TTM calculation

**iOS Core:**
- `ios/Test App/ContentView.swift` (2300+ lines) - Main view, StockAPIService, data fetching
- `ios/Test App/ChartUtilities.swift` (220 lines) - Shared formatting, constants

**iOS Charts (all ~300 lines each):**
- `ios/Test App/EarningsChartView.swift`
- `ios/Test App/TTMEarningsChartView.swift`
- `ios/Test App/YoYGrowthChartView.swift`
- `ios/Test App/YoYEarningsGrowthChartView.swift`

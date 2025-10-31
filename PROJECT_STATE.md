# Investment Research App - Current Project State

**Last Updated:** 2025-10-30
**Current Version:** v1.0.0+
**Status:** ✅ Production Ready (App Store Compliant)

---

## 📋 Quick Summary

**What is this app?**
iOS investment research app displaying company financial metrics (revenue, earnings, YoY growth) from SEC filings.

**Data Source:**
100% SEC EDGAR API (free, public data - no API keys, $0/month)

**Key Achievement:**
Fully functional, App Store compliant, zero ongoing costs.

---

## 🏗️ Architecture Overview

```
┌─────────────────────┐
│   iOS App (Swift)   │
│   - SwiftUI Charts  │
│   - 10 years data   │
└──────────┬──────────┘
           │ HTTPS
           ▼
┌─────────────────────┐
│ Cloudflare Worker   │
│ - SEC API Proxy     │
│ - KV Caching        │
└──────────┬──────────┘
           │ HTTPS (User-Agent required)
           ▼
┌─────────────────────┐
│   SEC EDGAR API     │
│ - Company Facts     │
│ - Ticker List       │
└─────────────────────┘
```

**No paid APIs, no secrets, no API keys needed.**

---

## 📂 Project Structure

```
InvestmentResearchApp/
├── backend/                    # Cloudflare Worker
│   ├── src/index.js           # API endpoints + SEC integration
│   ├── wrangler.toml          # Cloudflare config
│   └── README.md              # Backend documentation
│
├── ios/Test App/              # iOS App
│   ├── ContentView.swift      # Main view + StockAPIService
│   ├── ChartUtilities.swift   # Shared chart formatting
│   ├── EarningsChartView.swift          # Quarterly earnings chart
│   ├── TTMEarningsChartView.swift       # TTM earnings chart
│   ├── YoYGrowthChartView.swift         # Revenue YoY growth chart
│   ├── YoYEarningsGrowthChartView.swift # Earnings YoY growth chart
│   └── MarketDataService.swift          # (Legacy - not used)
│
└── Documentation/
    ├── PROJECT_STATE.md       # ← You are here
    ├── VERSION_HISTORY.md     # Version changelog
    └── backend/README.md      # Backend API docs
```

---

## 🎯 Features Implemented

### Data & APIs
- ✅ Quarterly revenue from SEC (40 quarters displayed)
- ✅ TTM revenue calculated from quarterly data (37 periods)
- ✅ Quarterly earnings from SEC (40 quarters displayed)
- ✅ TTM earnings calculated from quarterly data (37 periods)
- ✅ Company ticker autocomplete (~13,000 companies)
- ✅ Search by ticker or company name

### Charts
- ✅ **Revenue Chart** (quarterly) - Blue bars, dynamic Y-axis
- ✅ **Revenue Chart** (TTM) - Blue bars, dynamic Y-axis
- ✅ **Earnings Chart** (quarterly) - Blue bars, supports negative values
- ✅ **Earnings Chart** (TTM) - Blue bars, supports negative values
- ✅ **YoY Growth Chart** (revenue) - Green/red bars, centered at zero
- ✅ **YoY Growth Chart** (earnings) - Green/red bars, centered at zero

### Chart Features
- ✅ Dynamic bar widths (all 40 bars fit on screen, no scrolling)
- ✅ Interactive tooltips on tap
- ✅ Y-axis labels aligned with gridlines
- ✅ Zero line always visible when data spans negative/positive
- ✅ Consistent color scheme (blue for metrics, green/red for growth)
- ✅ X-axis shows years (every 9th period for readability)

### Data Tables
- ✅ Combined revenue/earnings detail tables
- ✅ Shows up to 40 quarters (10 years)
- ✅ Columns: Quarterly, TTM, YoY%
- ✅ Horizontal scroll for data columns
- ✅ Fixed quarter column on left

### Technical
- ✅ Fast builds (charts split into separate files)
- ✅ Shared utilities (ChartUtilities.swift)
- ✅ Cloudflare KV caching (24hr company facts, 7 day tickers)
- ✅ All compiler errors resolved

---

## 📊 Chart Constants

Defined in `ChartUtilities.swift`:

```swift
struct ChartConstants {
    static let chartHeight: CGFloat = 200
    static let yAxisWidth: CGFloat = 50
    static let barSpacing: CGFloat = 3
    static let quarterlyDataLimit = 40  // 10 years
    static let ttmDataLimit = 37        // ~9 years
    static let growthDataLimit = 36     // 9 years YoY
    static let scrollDelay = 0.1
}
```

---

## 🔧 Recent Changes (This Session)

1. **YoY Chart Restructure**
   - Removed horizontal scrolling
   - Changed from bi-directional split to unified offset-based rendering
   - Maintained green/red color coding for growth direction

2. **Earnings Chart Color Update**
   - Changed TTMEarningsChartView from purple → blue
   - Changed EarningsChartView from green → blue
   - Now matches revenue chart color scheme

3. **Data Table Expansion**
   - Expanded from 12 quarters → 40 quarters (10 years)
   - YoY column shows up to 36 quarters (9 years)

4. **Documentation Cleanup**
   - Deleted 6 outdated Marketstack files
   - Updated backend/README.md for SEC-only API
   - Updated VERSION_HISTORY.md
   - Created this PROJECT_STATE.md file

---

## 🚀 Backend API Endpoints

**Base URL:** (Your deployed Cloudflare Worker URL)

| Endpoint | Method | Description | Cache TTL |
|----------|--------|-------------|-----------|
| `/api/revenue/:symbol` | GET | Quarterly revenue | 24 hours |
| `/api/revenue-ttm/:symbol` | GET | TTM revenue | 24 hours |
| `/api/earnings/:symbol` | GET | Quarterly earnings (net income) | 24 hours |
| `/api/earnings-ttm/:symbol` | GET | TTM earnings | 24 hours |
| `/api/tickers` | GET | All SEC company tickers | 7 days |

**Example:**
```bash
curl https://your-worker.workers.dev/api/revenue/AAPL
curl https://your-worker.workers.dev/api/earnings/MSFT
curl https://your-worker.workers.dev/api/tickers
```

---

## 📱 iOS Code Patterns

### Fetching Data
```swift
let apiService = StockAPIService()

// Fetch revenue
let revenue = try await apiService.fetchRevenue(symbol: "AAPL")

// Fetch earnings
let earnings = try await apiService.fetchEarnings(symbol: "AAPL")

// Fetch all tickers (for autocomplete)
let tickers = try await apiService.fetchAllTickers()
```

### Chart Usage
```swift
// Charts are standalone views
EarningsChartView(symbol: "AAPL", apiService: apiService)
TTMEarningsChartView(symbol: "AAPL", apiService: apiService)
YoYGrowthChartView(symbol: "AAPL", apiService: apiService)
YoYEarningsGrowthChartView(symbol: "AAPL", apiService: apiService)
```

### Formatting Utilities
```swift
// Currency
ChartUtilities.formatCurrencyValue(94933000000) // "$94.93B"

// Percentage
ChartUtilities.formatPercentage(12.5) // "+12.5%"

// Date
ChartUtilities.formatQuarterDate("2024-09-30") // "Q3 2024"
ChartUtilities.formatYearOnly("2024-09-30") // "2024"
```

---

## 🎨 Design Patterns

### Chart Color Scheme
- **Revenue/Earnings (actual values):** Blue (`Color.blue`)
- **Growth (positive):** Green (`Color.green`)
- **Growth (negative):** Red (`Color.red`)

### Y-Axis Behavior
- **Revenue:** Always starts at 0 (can't be negative)
- **Earnings:** Dynamic range (can be negative)
- **YoY Growth:** Symmetric range centered at 0 (-X to +X)

### Bar Positioning
All charts use consistent offset-based positioning:
```swift
private func barOffset(for value: Double, barHeight: CGFloat, in chartHeight: CGFloat) -> CGFloat {
    let zeroY = chartHeight * zeroLinePosition
    if value >= 0 {
        return zeroY  // Positive: sit on zero line, grow upward
    } else {
        return zeroY - barHeight  // Negative: grow downward
    }
}
```

---

## 🐛 Known Issues & Considerations

### ✅ Resolved
- Build performance (charts split into separate files)
- Compiler timeouts (extracted complex views)
- Y-axis label alignment (using ZStack with offsets)
- Zero line visibility (always included when data spans zero)

### 📝 Future Enhancements (Not Implemented)
- Stock price data (currently SEC financials only)
- Real-time quotes
- Historical price charts
- Portfolio tracking
- Push notifications

---

## 💰 Cost Breakdown

| Service | Usage | Cost |
|---------|-------|------|
| SEC EDGAR API | Unlimited (public data) | **$0** |
| Cloudflare Workers | 100k requests/day | **$0** (free tier) |
| Cloudflare KV | 100k reads/day | **$0** (free tier) |
| iOS Developer Program | Annual | **$99/year** |

**Total Monthly Operating Cost:** $0
**Total Annual Cost:** $99 (Apple Developer membership only)

---

## 🔑 Key Files to Know

### Backend
- **`backend/src/index.js`** (590 lines)
  - All API endpoint handlers
  - SEC API integration
  - TTM calculation logic
  - KV caching layer

### iOS App
- **`ios/Test App/ContentView.swift`** (2,300+ lines)
  - StockAPIService class
  - Main app views
  - Stock list management
  - Ticker autocomplete

- **`ios/Test App/ChartUtilities.swift`** (220 lines)
  - Shared formatting functions
  - Chart constants
  - Helper methods for all charts

### Chart Views (All ~300 lines each)
- `EarningsChartView.swift` - Quarterly earnings
- `TTMEarningsChartView.swift` - TTM earnings
- `YoYGrowthChartView.swift` - Revenue YoY growth
- `YoYEarningsGrowthChartView.swift` - Earnings YoY growth

---

## 🔄 Git Workflow

**Current Branch:** `main`

**Recent Commits:**
```bash
738646e - Update earnings chart colors and expand data tables
f9954cb - Restructure YoY growth charts to match quarterly/TTM style
a37ee6c - (earlier commits)
```

**To save a version:**
```bash
# User says: "save version: description here"
git add .
git commit -m "Version description..."
git tag v1.x.x
git push origin main --tags
```

---

## 📚 Data Models

### RevenueDataPoint
```swift
struct RevenueDataPoint: Identifiable, Codable {
    var id = UUID()
    let period: String  // "2024-09-30"
    let revenue: Double // In dollars (e.g., 94933000000)
}
```

### EarningsDataPoint
```swift
struct EarningsDataPoint: Identifiable, Codable {
    var id = UUID()
    let period: String   // "2024-09-30"
    let earnings: Double // In dollars, can be negative
}
```

### TickerSuggestion
```swift
struct TickerSuggestion: Identifiable, Codable {
    let id = UUID()
    let ticker: String  // "AAPL"
    let name: String    // "Apple Inc."
    let cik: String     // "0000320193"
}
```

---

## 🚦 Development Workflow

### Starting a New Session
1. Read this PROJECT_STATE.md
2. Check git status for uncommitted changes
3. Review recent commits to understand latest work
4. Ask user what they want to work on

### Making Changes
1. Create todo list for multi-step tasks
2. Test changes with Xcode build
3. Verify charts render correctly
4. Update this file if architecture changes

### Ending a Session
1. Commit changes with descriptive messages
2. Push to GitHub
3. Update PROJECT_STATE.md if needed
4. Clear completed todos

---

## 🎓 Key Learnings

### Chart Performance
- Split complex views into separate files for faster builds
- Use `GeometryReader` for dynamic sizing
- Calculate bar widths based on available space
- Limit displayed data (40 quarters max)

### SEC API Integration
- Use User-Agent header (required by SEC)
- Cache aggressively (data updates quarterly)
- Handle missing data gracefully
- Support both `Revenues` and `RevenueFromContractWithCustomerExcludingAssessedTax`

### SwiftUI Charts
- Use ZStack for precise positioning
- Calculate offsets from bottom for consistency
- Always show zero line when data spans negative/positive
- Use `.frame(alignment: .bottom)` for bar charts

---

## 🔮 Future Session Templates

### "Add a new chart type"
1. Create new file: `ios/Test App/NewChartView.swift`
2. Follow pattern from existing chart views
3. Use ChartUtilities for formatting
4. Add chart constants if needed
5. Update ContentView to display new chart

### "Fix a chart visual issue"
1. Identify which chart file to edit
2. Check ChartUtilities for shared logic
3. Test changes in Xcode
4. Verify across different data ranges

### "Add new backend endpoint"
1. Edit `backend/src/index.js`
2. Add route handler
3. Implement SEC API call
4. Add KV caching
5. Update backend/README.md
6. Deploy with `npm run deploy`

---

## ✅ Status Checklist

**Core Functionality:**
- [x] Display quarterly revenue charts
- [x] Display TTM revenue charts
- [x] Display quarterly earnings charts
- [x] Display TTM earnings charts
- [x] Calculate and display YoY growth
- [x] Company ticker autocomplete
- [x] Search by ticker or name
- [x] 10 years of data in tables
- [x] All charts fit on screen (no scrolling)
- [x] Negative value support
- [x] Zero line always visible
- [x] Consistent color scheme

**Technical:**
- [x] Fast builds (<10 seconds)
- [x] No compiler errors
- [x] No runtime crashes
- [x] Cloudflare Worker deployed
- [x] KV caching working
- [x] Backend documentation updated
- [x] VERSION_HISTORY.md updated

**App Store Compliance:**
- [x] No paid APIs (all data free from SEC)
- [x] No API key requirements
- [x] No third-party terms violations
- [x] Public data sources only

---

## 🤝 Common User Requests

**"Add a new stock"**
→ Use autocomplete in app, no code changes needed

**"Show more years of data"**
→ Increase `ChartConstants.quarterlyDataLimit` in ChartUtilities.swift

**"Change chart colors"**
→ Edit `.fill(Color.blue)` in chart view files

**"Fix slow builds"**
→ Already fixed (charts split into separate files)

**"Add stock prices"**
→ Major change - would need new data source (SEC doesn't provide prices)

**"Export data to CSV"**
→ Not implemented - would need to add export functionality

---

## 📞 Quick Reference

**GitHub:** https://github.com/rileypgibson21-gif/investment-research-app
**Current Version:** v1.0.0 (tagged)
**Backend:** Cloudflare Workers (SEC API proxy)
**Frontend:** iOS SwiftUI
**Data Source:** SEC EDGAR API (100% free)
**Deployment:** TestFlight / App Store Ready

---

**For Future Claude Code Sessions:**
Start by reading this file to understand the current project state, architecture, and recent changes. Check git status and recent commits to see what was last worked on. Ask the user what they want to accomplish in this session.

# Marketstack API Implementation Guide

This guide covers the complete implementation of Marketstack API for real-time and historical price data in the Investment Research App.

## Overview

### What Was Implemented
- **Backend**: Cloudflare Worker proxy for Marketstack API with KV caching
- **iOS**: Updated services to use Marketstack instead of Yahoo Finance
- **Data Sources**:
  - **Price Data** (Marketstack): Real-time quotes, historical EOD, intraday, 52-week high/low
  - **Financial Metrics** (SEC API): Revenue, earnings, and all other financial data

### Why This Architecture?
1. **Security**: API key stored in Cloudflare Worker, never exposed to client
2. **Performance**: KV caching reduces API calls and improves response times
3. **Cost**: Caching maximizes value from Marketstack's rate limits
4. **Compliance**: Marketstack allows commercial use

## Backend Deployment

### Prerequisites
- Node.js 16+ installed
- Cloudflare account
- Wrangler CLI installed: `npm install -g wrangler`

### Step 1: Setup Cloudflare Worker

```bash
cd backend
npm install
```

### Step 2: Authenticate with Cloudflare

```bash
wrangler login
```

### Step 3: Create KV Namespace

```bash
# Create production namespace
wrangler kv:namespace create "CACHE"

# Create preview namespace for testing
wrangler kv:namespace create "CACHE" --preview
```

You'll get output like:
```
{ binding = "CACHE", id = "abc123..." }
{ binding = "CACHE", preview_id = "xyz789..." }
```

### Step 4: Update wrangler.toml

Edit `backend/wrangler.toml` and replace the KV namespace IDs:

```toml
[[kv_namespaces]]
binding = "CACHE"
id = "abc123..."  # Your production ID
preview_id = "xyz789..."  # Your preview ID
```

### Step 5: Set API Key Secret

```bash
wrangler secret put MARKETSTACK_API_KEY
# When prompted, enter: 9dba12fdfa1a0d703eeec5a6123044f1
```

### Step 6: Test Locally

```bash
npm run dev
```

Test the endpoints:
```bash
# Health check
curl http://localhost:8787/api/health

# Real-time quote
curl http://localhost:8787/api/quote/AAPL

# Historical data
curl http://localhost:8787/api/eod/AAPL?limit=30

# Intraday data
curl http://localhost:8787/api/intraday/AAPL?interval=5min
```

### Step 7: Deploy to Production

```bash
npm run deploy
```

Your API will be live at: `https://my-stock-api.stock-research-api.workers.dev`

### Step 8: Update Worker URL (if different)

If your worker deploys to a different URL, update the iOS app:

**File**: `ios/Test App/MarketDataService.swift`
```swift
init(apiBaseURL: String = "https://YOUR-WORKER-URL.workers.dev") {
```

## iOS Integration

### New Service Architecture

The app now has three separate services:

1. **MarketDataService** (`MarketDataService.swift`)
   - Real-time stock quotes
   - Historical price data (EOD)
   - Intraday data
   - 52-week high/low

2. **StockAPIService** (`ContentView.swift` - root)
   - Revenue data (from your existing API)
   - Earnings data (from your existing API)
   - Company profile (from your existing API)

3. **SECAPIService** (`SECAPIService.swift`)
   - SEC filings
   - Company facts
   - CIK lookups

### Usage Examples

#### Fetch Real-Time Quote
```swift
let marketData = MarketDataService()

Task {
    do {
        let quote = try await marketData.fetchQuote(symbol: "AAPL")
        print("Current Price: $\(quote.currentPrice)")
        print("Change: \(quote.changePercent)%")
    } catch {
        print("Error: \(error)")
    }
}
```

#### Fetch Historical Data
```swift
let marketData = MarketDataService()

Task {
    do {
        let history = try await marketData.fetchEODData(symbol: "AAPL", limit: 30)
        // history is an array of EODDataPoint
        for dataPoint in history {
            print("\(dataPoint.date): Close $\(dataPoint.close)")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

#### Fetch 52-Week Range
```swift
let marketData = MarketDataService()

Task {
    do {
        let range = try await marketData.fetch52WeekRange(symbol: "AAPL")
        print("52W High: $\(range.high)")
        print("52W Low: $\(range.low)")
    } catch {
        print("Error: \(error)")
    }
}
```

## API Endpoints Reference

### 1. Health Check
```
GET /api/health
```
Returns worker status and timestamp.

### 2. Real-Time Quote
```
GET /api/quote/:symbol
```
**Example**: `/api/quote/AAPL`

**Response**:
```json
{
  "symbol": "AAPL",
  "currentPrice": 178.50,
  "open": 177.25,
  "high": 179.10,
  "low": 176.80,
  "volume": 52468900,
  "previousClose": 178.50,
  "change": 1.25,
  "changePercent": 0.71,
  "date": "2024-01-26"
}
```
**Cache TTL**: 1 minute

### 3. End-of-Day Historical Data
```
GET /api/eod/:symbol?limit=30
```
**Example**: `/api/eod/AAPL?limit=90`

**Parameters**:
- `limit` (optional): Number of days (default: 30, max: 252 for ~1 year)

**Response**:
```json
[
  {
    "date": "2024-01-26",
    "open": 177.25,
    "high": 179.10,
    "low": 176.80,
    "close": 178.50,
    "volume": 52468900,
    "adjClose": 178.50
  }
]
```
**Cache TTL**: 1 hour

### 4. Intraday Data
```
GET /api/intraday/:symbol?interval=1min
```
**Example**: `/api/intraday/AAPL?interval=5min`

**Parameters**:
- `interval` (optional): `1min`, `5min`, `15min`, `30min`, `1hour`

**Response**:
```json
[
  {
    "date": "2024-01-26T09:30:00+0000",
    "open": 177.25,
    "high": 177.50,
    "low": 177.10,
    "close": 177.35,
    "volume": 1234567
  }
]
```
**Cache TTL**: 5 minutes

## Caching Strategy

### Backend (Cloudflare KV)
- **Quotes**: 60 seconds (1 minute)
- **EOD Data**: 3600 seconds (1 hour)
- **Intraday**: 300 seconds (5 minutes)

### Why These TTLs?
- **Quotes**: Market prices change frequently, 1 minute provides near-real-time with caching benefits
- **EOD**: Historical data doesn't change, 1 hour is safe
- **Intraday**: Balance between freshness and API usage

### Cache Headers
All responses include `X-Cache` header:
- `X-Cache: HIT` - Served from cache
- `X-Cache: MISS` - Fresh from Marketstack API

## Testing

### Backend Testing

#### 1. Test All Endpoints
```bash
# Health
curl https://my-stock-api.stock-research-api.workers.dev/api/health

# Quote
curl https://my-stock-api.stock-research-api.workers.dev/api/quote/AAPL

# EOD
curl https://my-stock-api.stock-research-api.workers.dev/api/eod/TSLA?limit=10

# Intraday
curl https://my-stock-api.stock-research-api.workers.dev/api/intraday/MSFT
```

#### 2. Test Caching
```bash
# First request (should be MISS)
curl -i https://my-stock-api.stock-research-api.workers.dev/api/quote/AAPL | grep X-Cache

# Second request within TTL (should be HIT)
curl -i https://my-stock-api.stock-research-api.workers.dev/api/quote/AAPL | grep X-Cache
```

#### 3. Test Error Handling
```bash
# Invalid symbol
curl https://my-stock-api.stock-research-api.workers.dev/api/quote/INVALID

# Missing symbol
curl https://my-stock-api.stock-research-api.workers.dev/api/quote/
```

### iOS Testing

#### 1. Unit Test Example
```swift
import XCTest

class MarketDataServiceTests: XCTestCase {
    let service = MarketDataService()

    func testFetchQuote() async throws {
        let quote = try await service.fetchQuote(symbol: "AAPL")

        XCTAssertEqual(quote.symbol, "AAPL")
        XCTAssertGreaterThan(quote.currentPrice, 0)
    }

    func testFetch52WeekRange() async throws {
        let range = try await service.fetch52WeekRange(symbol: "AAPL")

        XCTAssertGreaterThan(range.high, range.low)
        XCTAssertGreaterThan(range.low, 0)
    }
}
```

#### 2. Manual Testing Checklist
- [ ] Real-time quote displays correctly
- [ ] Price change (positive/negative) shows proper color
- [ ] Historical chart renders with EOD data
- [ ] 52-week high/low displays accurately
- [ ] Error handling works for invalid symbols
- [ ] Loading states display properly
- [ ] Refresh updates data correctly

## Monitoring

### View Live Logs
```bash
cd backend
npm run tail
```

### Check Worker Analytics
1. Go to Cloudflare Dashboard
2. Navigate to Workers & Pages
3. Click on `stock-research-api`
4. View metrics: requests, errors, CPU time

### Monitor KV Usage
```bash
# List all keys
wrangler kv:key list --namespace-id=YOUR_KV_ID

# Get a specific cached value
wrangler kv:key get "quote:AAPL" --namespace-id=YOUR_KV_ID
```

## Troubleshooting

### Issue: "Symbol not found" errors
**Cause**: Marketstack may not have data for that symbol
**Solution**: Verify symbol exists on Marketstack or use major stocks (AAPL, TSLA, MSFT)

### Issue: Rate limit errors
**Cause**: Exceeded Marketstack API limits
**Solution**:
- Check caching is working (X-Cache headers)
- Upgrade Marketstack plan if needed
- Increase cache TTL

### Issue: Stale data
**Cause**: Cache TTL too long or KV not clearing
**Solution**:
```bash
# Clear specific cache key
wrangler kv:key delete "quote:AAPL" --namespace-id=YOUR_KV_ID

# Or adjust TTL in src/index.js
```

### Issue: iOS app can't connect to worker
**Cause**: Worker URL mismatch or CORS issue
**Solution**:
- Verify worker URL in MarketDataService.swift
- Check worker deployment: `wrangler deployments list`
- Test endpoint directly with curl

### Issue: "Network error" in iOS
**Cause**: App Transport Security or network configuration
**Solution**:
- Ensure using HTTPS (not HTTP)
- Check Info.plist for ATS settings
- Test on device, not just simulator

## Rate Limits & Costs

### Marketstack Free Tier
- 100 requests/month
- HTTPS support
- EOD data only

### Marketstack Paid Tiers
- **Basic**: 10,000 requests/month (~$10)
- **Professional**: 100,000 requests/month (~$50)
- **Business**: 1,000,000 requests/month (~$250)

### Optimization Tips
1. **Increase Cache TTL** for less critical data
2. **Batch Requests** where possible
3. **Use EOD Instead of Intraday** when real-time isn't needed
4. **Monitor Analytics** to track actual usage

## Cloudflare Costs
- Workers: Free tier (100,000 requests/day)
- KV Storage: Free tier (100,000 reads/day, 1,000 writes/day)
- For this use case: **Likely FREE** with caching

## Next Steps

### Recommended Enhancements
1. **Add Historical Chart View** using EOD data
2. **Implement Real-Time Updates** with polling/websockets
3. **Add Market Movers** (top gainers/losers)
4. **Add Watchlist** with bulk quote fetching
5. **Add Price Alerts** using background refresh

### Code Examples Available
All service files include detailed inline documentation and examples.

## Support & Resources

- **Marketstack Docs**: https://marketstack.com/documentation
- **Cloudflare Workers**: https://developers.cloudflare.com/workers/
- **Wrangler CLI**: https://developers.cloudflare.com/workers/wrangler/

## Summary

You now have a production-ready market data system:
- ✅ Secure API key storage in Cloudflare Worker
- ✅ High-performance caching with Cloudflare KV
- ✅ Clean iOS service layer (MarketDataService)
- ✅ Marketstack commercial license compliance
- ✅ Fully replaced Yahoo Finance
- ✅ Maintained SEC API for financial metrics
- ✅ Ready for App Store deployment

Your backend is live at: `https://my-stock-api.stock-research-api.workers.dev`

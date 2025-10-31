# Stock Research API - Cloudflare Worker

Cloudflare Worker backend for the Investment Research iOS app, providing SEC financial data with caching.

## Architecture

**100% Free, SEC-Only Data**
- All financial data from SEC EDGAR API (public, no API keys required)
- No paid API services (Marketstack removed, Yahoo Finance removed)
- Ready for App Store deployment with no ongoing costs

## Features

- Quarterly revenue data from SEC filings
- TTM (Trailing Twelve Months) revenue data
- Quarterly earnings data
- TTM earnings data
- Company ticker lookup
- Cloudflare KV caching for performance
- CORS enabled for iOS app access

## Data Sources

| Endpoint | Data Source | Cost |
|----------|-------------|------|
| `/api/revenue/:symbol` | SEC EDGAR | Free |
| `/api/revenue-ttm/:symbol` | SEC EDGAR (calculated) | Free |
| `/api/earnings/:symbol` | SEC EDGAR | Free |
| `/api/earnings-ttm/:symbol` | SEC EDGAR (calculated) | Free |
| `/api/tickers` | SEC company tickers | Free |

## Setup

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Create KV Namespace
```bash
wrangler kv:namespace create "CACHE"
wrangler kv:namespace create "CACHE" --preview
```

Copy the namespace IDs and update `wrangler.toml`:
```toml
[[kv_namespaces]]
binding = "CACHE"
id = "your_production_kv_id"
preview_id = "your_preview_kv_id"
```

### 3. Test Locally
```bash
npm run dev
```

Visit:
- http://localhost:8787/api/revenue/AAPL
- http://localhost:8787/api/earnings/AAPL
- http://localhost:8787/api/tickers

### 4. Deploy to Production
```bash
npm run deploy
```

## API Endpoints

### Get Quarterly Revenue
```
GET /api/revenue/:symbol
```
Example: `/api/revenue/AAPL`

Returns array of quarterly revenue data points from SEC filings.

Response:
```json
[
  {
    "period": "2024-09-30",
    "revenue": 94933000000
  },
  {
    "period": "2024-06-30",
    "revenue": 85778000000
  }
]
```

### Get TTM Revenue
```
GET /api/revenue-ttm/:symbol
```
Example: `/api/revenue-ttm/AAPL`

Returns array of TTM (trailing twelve months) revenue calculated from quarterly data.

### Get Quarterly Earnings
```
GET /api/earnings/:symbol
```
Example: `/api/earnings/AAPL`

Returns array of quarterly net income data points from SEC filings.

Response:
```json
[
  {
    "period": "2024-09-30",
    "earnings": 14736000000
  },
  {
    "period": "2024-06-30",
    "earnings": 21448000000
  }
]
```

### Get TTM Earnings
```
GET /api/earnings-ttm/:symbol
```
Example: `/api/earnings-ttm/AAPL`

Returns array of TTM (trailing twelve months) earnings calculated from quarterly data.

### Get All Tickers
```
GET /api/tickers
```

Returns array of all SEC-registered company tickers with names and CIK numbers.

Response:
```json
[
  {
    "ticker": "AAPL",
    "name": "Apple Inc.",
    "cik": "0000320193"
  },
  {
    "ticker": "MSFT",
    "name": "Microsoft Corp",
    "cik": "0000789019"
  }
]
```

## Caching Strategy

Cloudflare KV caching reduces load on SEC API and improves response times:

| Data Type | TTL | Rationale |
|-----------|-----|-----------|
| Company Facts | 24 hours | Updates once per quarter |
| Ticker List | 7 days | Rarely changes |

All responses include `X-Cache` header:
- `X-Cache: HIT` - Served from cache
- `X-Cache: MISS` - Fresh from SEC API

## Monitoring

View live logs:
```bash
npm run tail
```

View analytics at Cloudflare Dashboard:
1. Go to https://dash.cloudflare.com
2. Navigate to Workers & Pages
3. Click on your worker
4. View requests, errors, CPU time

## Cost Analysis

**Backend Costs:**
- Cloudflare Workers: **FREE** (100,000 requests/day)
- Cloudflare KV: **FREE** (100,000 reads/day, 1,000 writes/day)
- SEC EDGAR API: **FREE** (no API key required)

**Total Monthly Cost: $0**

## Data Processing

### TTM Calculation
TTM (Trailing Twelve Months) values are calculated by summing the last 4 quarters of data. For example:
- Q4 2024 TTM = Q4 2024 + Q3 2024 + Q2 2024 + Q1 2024

### Revenue Data
Retrieved from SEC company facts using these concepts:
- `us-gaap/Revenues`
- `us-gaap/RevenueFromContractWithCustomerExcludingAssessedTax`

### Earnings Data
Retrieved from SEC company facts using:
- `us-gaap/NetIncomeLoss`

## Rate Limits

SEC EDGAR API guidelines:
- Maximum 10 requests per second
- Must include User-Agent header (implemented)
- Caching recommended (implemented via KV)

## Security

- No API keys required (all data is public SEC filings)
- CORS enabled for iOS app
- HTTPS-only communication
- Rate limiting via Cloudflare

## iOS Integration

The iOS app uses `StockAPIService` to call these endpoints:
```swift
// Example usage
let apiService = StockAPIService()
let revenue = try await apiService.fetchRevenue(symbol: "AAPL")
let earnings = try await apiService.fetchEarnings(symbol: "AAPL")
```

## Troubleshooting

### Issue: "No data for symbol"
**Cause**: Company may not file with SEC or uses different ticker
**Solution**: Verify ticker exists in SEC system at https://www.sec.gov/cgi-bin/browse-edgar

### Issue: Rate limit errors
**Cause**: Exceeded 10 requests/second to SEC
**Solution**: Caching should prevent this; check KV is working

### Issue: Stale data
**Cause**: Cache TTL too long
**Solution**: Clear cache or adjust TTL in `src/index.js`

## Development

The worker code is in `src/index.js` and includes:
- Request routing for all endpoints
- SEC API integration with proper User-Agent
- KV caching layer
- Error handling
- CORS configuration

## Deployment URL

After deployment, your worker will be available at:
```
https://<worker-name>.<subdomain>.workers.dev
```

Update the iOS app's `apiBaseURL` in `ContentView.swift` to match your deployed worker URL.

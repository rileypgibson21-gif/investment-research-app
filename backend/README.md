# Stock Research API - Cloudflare Worker

Cloudflare Worker proxy for Marketstack API with caching for the Investment Research iOS app.

## Features
- Real-time stock quotes
- End-of-day historical data
- Intraday price data
- KV-based caching to reduce API calls
- CORS enabled for iOS app access
- Secure API key storage (never exposed to client)

## Setup

### 1. Install Dependencies
```bash
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

### 3. Set API Key Secret

For local development, the `.dev.vars` file already contains your key.

For production deployment:
```bash
wrangler secret put MARKETSTACK_API_KEY
# Enter: 9dba12fdfa1a0d703eeec5a6123044f1
```

### 4. Test Locally
```bash
npm run dev
```

Visit:
- http://localhost:8787/api/health
- http://localhost:8787/api/quote/AAPL
- http://localhost:8787/api/eod/AAPL?limit=30

### 5. Deploy to Production
```bash
npm run deploy
```

## API Endpoints

### Health Check
```
GET /api/health
```

### Real-Time Quote
```
GET /api/quote/:symbol
```
Example: `/api/quote/AAPL`

Response:
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

### End-of-Day Historical Data
```
GET /api/eod/:symbol?limit=30
```
Example: `/api/eod/AAPL?limit=30`

Returns last 30 days of EOD data.

### Intraday Data
```
GET /api/intraday/:symbol?interval=1min
```
Example: `/api/intraday/AAPL?interval=1min`

Intervals: 1min, 5min, 15min, 30min, 1hour

## Caching
- Quotes: 1 minute TTL
- EOD data: 1 hour TTL
- Intraday: 5 minutes TTL

## Monitoring
View live logs:
```bash
npm run tail
```

## Rate Limits
Marketstack free tier: 100 requests/month
Marketstack paid tiers: Higher limits based on plan

Caching significantly reduces API calls to Marketstack.

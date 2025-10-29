/**
 * Cloudflare Worker - Stock Market Data API Proxy
 * Uses Marketstack API for price data with caching
 */

const MARKETSTACK_BASE_URL = 'http://api.marketstack.com/v1';
const SEC_BASE_URL = 'https://data.sec.gov';
const CACHE_TTL = {
  QUOTE: 60,        // 1 minute for real-time quotes
  EOD: 3600,        // 1 hour for end-of-day data
  INTRADAY: 300,    // 5 minutes for intraday
  SEC_DATA: 86400   // 24 hours for SEC data (updates quarterly)
};

// CORS headers for iOS app
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json'
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    try {
      // Route handling
      if (url.pathname.startsWith('/api/profile/')) {
        return await handleProfile(request, env, url);
      } else if (url.pathname.startsWith('/api/quote/')) {
        return await handleQuote(request, env, url);
      } else if (url.pathname.startsWith('/api/eod/')) {
        return await handleEOD(request, env, url);
      } else if (url.pathname.startsWith('/api/intraday/')) {
        return await handleIntraday(request, env, url);
      } else if (url.pathname.startsWith('/api/revenue-ttm/')) {
        return await handleTTMRevenue(request, env, url);
      } else if (url.pathname.startsWith('/api/revenue/')) {
        return await handleRevenue(request, env, url);
      } else if (url.pathname.startsWith('/api/earnings-ttm/')) {
        return await handleTTMEarnings(request, env, url);
      } else if (url.pathname.startsWith('/api/earnings/')) {
        return await handleEarnings(request, env, url);
      } else if (url.pathname === '/api/health') {
        return jsonResponse({ status: 'healthy', timestamp: new Date().toISOString() });
      } else {
        return jsonResponse({ error: 'Not found' }, 404);
      }
    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse({ error: error.message }, 500);
    }
  }
};

/**
 * Handle stock profile/company info
 * GET /api/profile/:symbol
 */
async function handleProfile(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  // Check cache
  const cacheKey = `profile:${symbol}`;
  const cached = await getCache(env, cacheKey);
  if (cached) {
    return jsonResponse(cached, 200, { 'X-Cache': 'HIT' });
  }

  // Fetch from Marketstack - tickers endpoint
  const marketstackUrl = `${MARKETSTACK_BASE_URL}/tickers/${symbol}?access_key=${env.MARKETSTACK_API_KEY}`;

  const response = await fetch(marketstackUrl);
  if (!response.ok) {
    return jsonResponse({ error: 'Symbol not found' }, 404);
  }

  const data = await response.json();

  // Transform to match iOS app StockProfile format
  const result = {
    name: data.name || symbol,
    ticker: data.symbol || symbol,
    marketCapitalization: data.market_cap || null,
    shareOutstanding: null, // Marketstack doesn't provide this
    logo: null,
    country: data.stock_exchange?.country || null,
    currency: data.stock_exchange?.currency || null,
    exchange: data.stock_exchange?.name || data.stock_exchange?.acronym || null,
    ipo: null,
    industry: null,
    weburl: null
  };

  // Cache for 24 hours (company info doesn't change often)
  await setCache(env, cacheKey, result, 86400);
  return jsonResponse(result, 200, { 'X-Cache': 'MISS' });
}

/**
 * Handle real-time stock quote
 * GET /api/quote/:symbol
 */
async function handleQuote(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  // Check cache
  const cacheKey = `quote:${symbol}`;
  const cached = await getCache(env, cacheKey);
  if (cached) {
    return jsonResponse(cached, 200, { 'X-Cache': 'HIT' });
  }

  // Fetch from Marketstack - latest endpoint
  const marketstackUrl = `${MARKETSTACK_BASE_URL}/eod/latest?access_key=${env.MARKETSTACK_API_KEY}&symbols=${symbol}`;

  const response = await fetch(marketstackUrl);
  if (!response.ok) {
    throw new Error(`Marketstack API error: ${response.status}`);
  }

  const data = await response.json();

  if (!data.data || data.data.length === 0) {
    return jsonResponse({ error: 'Symbol not found' }, 404);
  }

  const quote = data.data[0];

  // Transform to match iOS app format
  const result = {
    symbol: quote.symbol,
    currentPrice: quote.close,
    open: quote.open,
    high: quote.high,
    low: quote.low,
    volume: quote.volume,
    previousClose: quote.close, // Marketstack EOD doesn't have previous, use close
    change: quote.close - quote.open,
    changePercent: ((quote.close - quote.open) / quote.open) * 100,
    date: quote.date
  };

  // Cache the result
  await setCache(env, cacheKey, result, CACHE_TTL.QUOTE);

  return jsonResponse(result, 200, { 'X-Cache': 'MISS' });
}

/**
 * Handle end-of-day historical data
 * GET /api/eod/:symbol?limit=30
 */
async function handleEOD(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  const limit = url.searchParams.get('limit') || '30';

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  // Check cache
  const cacheKey = `eod:${symbol}:${limit}`;
  const cached = await getCache(env, cacheKey);
  if (cached) {
    return jsonResponse(cached, 200, { 'X-Cache': 'HIT' });
  }

  // Fetch from Marketstack
  const marketstackUrl = `${MARKETSTACK_BASE_URL}/eod?access_key=${env.MARKETSTACK_API_KEY}&symbols=${symbol}&limit=${limit}`;

  const response = await fetch(marketstackUrl);
  if (!response.ok) {
    throw new Error(`Marketstack API error: ${response.status}`);
  }

  const data = await response.json();

  if (!data.data || data.data.length === 0) {
    return jsonResponse({ error: 'No data found' }, 404);
  }

  // Transform to simpler format
  const result = data.data.map(item => ({
    date: item.date,
    open: item.open,
    high: item.high,
    low: item.low,
    close: item.close,
    volume: item.volume,
    adjClose: item.adj_close || item.close
  }));

  // Cache the result
  await setCache(env, cacheKey, result, CACHE_TTL.EOD);

  return jsonResponse(result, 200, { 'X-Cache': 'MISS' });
}

/**
 * Handle intraday data
 * GET /api/intraday/:symbol?interval=1min
 */
async function handleIntraday(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  const interval = url.searchParams.get('interval') || '1min';

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  // Check cache
  const cacheKey = `intraday:${symbol}:${interval}`;
  const cached = await getCache(env, cacheKey);
  if (cached) {
    return jsonResponse(cached, 200, { 'X-Cache': 'HIT' });
  }

  // Fetch from Marketstack intraday endpoint
  const marketstackUrl = `${MARKETSTACK_BASE_URL}/intraday/latest?access_key=${env.MARKETSTACK_API_KEY}&symbols=${symbol}&interval=${interval}&limit=100`;

  const response = await fetch(marketstackUrl);
  if (!response.ok) {
    throw new Error(`Marketstack API error: ${response.status}`);
  }

  const data = await response.json();

  if (!data.data || data.data.length === 0) {
    return jsonResponse({ error: 'No data found' }, 404);
  }

  // Transform to simpler format
  const result = data.data.map(item => ({
    date: item.date,
    open: item.open,
    high: item.high,
    low: item.low,
    close: item.close,
    volume: item.volume
  }));

  // Cache the result
  await setCache(env, cacheKey, result, CACHE_TTL.INTRADAY);

  return jsonResponse(result, 200, { 'X-Cache': 'MISS' });
}

/**
 * Handle quarterly revenue from SEC EDGAR
 * GET /api/revenue/:symbol
 */
async function handleRevenue(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  const cacheKey = `revenue:${symbol}`;
  const cached = await getCache(env, cacheKey);
  if (cached) {
    return jsonResponse(cached, 200, { 'X-Cache': 'HIT' });
  }

  try {
    const cik = await getCIK(symbol);
    const facts = await getCompanyFacts(cik);
    const revenue = extractRevenue(facts);

    await setCache(env, cacheKey, revenue, CACHE_TTL.SEC_DATA);
    return jsonResponse(revenue, 200, { 'X-Cache': 'MISS' });
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM revenue from SEC EDGAR
 * GET /api/revenue-ttm/:symbol
 */
async function handleTTMRevenue(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  const cacheKey = `revenue-ttm:${symbol}`;
  const cached = await getCache(env, cacheKey);
  if (cached) {
    return jsonResponse(cached, 200, { 'X-Cache': 'HIT' });
  }

  try {
    const cik = await getCIK(symbol);
    const facts = await getCompanyFacts(cik);
    const revenue = extractTTMRevenue(facts);

    await setCache(env, cacheKey, revenue, CACHE_TTL.SEC_DATA);
    return jsonResponse(revenue, 200, { 'X-Cache': 'MISS' });
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle quarterly earnings from SEC EDGAR
 * GET /api/earnings/:symbol
 */
async function handleEarnings(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  const cacheKey = `earnings:${symbol}`;
  const cached = await getCache(env, cacheKey);
  if (cached) {
    return jsonResponse(cached, 200, { 'X-Cache': 'HIT' });
  }

  try {
    const cik = await getCIK(symbol);
    const facts = await getCompanyFacts(cik);
    const earnings = extractEarnings(facts);

    await setCache(env, cacheKey, earnings, CACHE_TTL.SEC_DATA);
    return jsonResponse(earnings, 200, { 'X-Cache': 'MISS' });
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM earnings from SEC EDGAR
 * GET /api/earnings-ttm/:symbol
 */
async function handleTTMEarnings(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  const cacheKey = `earnings-ttm:${symbol}`;
  const cached = await getCache(env, cacheKey);
  if (cached) {
    return jsonResponse(cached, 200, { 'X-Cache': 'HIT' });
  }

  try {
    const cik = await getCIK(symbol);
    const facts = await getCompanyFacts(cik);
    const earnings = extractTTMEarnings(facts);

    await setCache(env, cacheKey, earnings, CACHE_TTL.SEC_DATA);
    return jsonResponse(earnings, 200, { 'X-Cache': 'MISS' });
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Get CIK from ticker symbol
 */
async function getCIK(symbol) {
  const response = await fetch('https://www.sec.gov/files/company_tickers.json', {
    headers: {
      'User-Agent': 'Investment Research App support@yourcompany.com'
    }
  });

  if (!response.ok) {
    throw new Error('Failed to fetch company tickers');
  }

  const tickers = await response.json();

  for (const key in tickers) {
    if (tickers[key].ticker === symbol) {
      return String(tickers[key].cik_str).padStart(10, '0');
    }
  }

  throw new Error('Company not found');
}

/**
 * Get company facts from SEC EDGAR
 */
async function getCompanyFacts(cik) {
  const response = await fetch(`${SEC_BASE_URL}/api/xbrl/companyfacts/CIK${cik}.json`, {
    headers: {
      'User-Agent': 'Investment Research App support@yourcompany.com'
    }
  });

  if (!response.ok) {
    throw new Error('Failed to fetch company facts');
  }

  return await response.json();
}

/**
 * Extract quarterly revenue (last 40 quarters = 10 years)
 * Identifies quarterly data by period duration (~3 months = quarterly)
 */
function extractRevenue(facts) {
  const revenueKeys = [
    'Revenues',
    'RevenueFromContractWithCustomerExcludingAssessedTax',
    'SalesRevenueNet',
    'RevenueFromContractWithCustomer'
  ];

  for (const key of revenueKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units.USD;
      if (!units) continue;

      // Filter for quarterly data (period duration ~3 months)
      const quarterly = units
        .filter(item => {
          if (!item.val || item.val <= 0 || !item.start || !item.end) return false;

          // Calculate period duration in days
          const startDate = new Date(item.start);
          const endDate = new Date(item.end);
          const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);

          // Quarterly data should be 70-120 days (roughly 3 months, allowing for variation)
          return daysDiff >= 70 && daysDiff <= 120;
        })
        .sort((a, b) => b.end.localeCompare(a.end))
        .reduce((acc, item) => {
          // Deduplicate by end date, keeping first occurrence (most recent filing)
          if (!acc.find(x => x.period === item.end)) {
            acc.push({ period: item.end, revenue: item.val });
          }
          return acc;
        }, [])
        .slice(0, 40);

      if (quarterly.length > 0) {
        return quarterly;
      }
    }
  }

  return [];
}

/**
 * Extract TTM revenue (last 37 periods)
 * TTM = Trailing Twelve Months, calculated as rolling 4-quarter sum
 */
function extractTTMRevenue(facts) {
  // First get quarterly data
  const quarterly = extractRevenue(facts);
  if (quarterly.length < 4) return [];

  // Calculate TTM for each period (starting from Q4)
  const ttm = [];
  for (let i = 3; i < quarterly.length; i++) {
    const last4Quarters = quarterly.slice(i - 3, i + 1);
    const ttmRevenue = last4Quarters.reduce((sum, q) => sum + q.revenue, 0);

    ttm.push({
      period: quarterly[i].period,
      revenue: ttmRevenue
    });
  }

  return ttm.slice(0, 37);
}

/**
 * Extract quarterly earnings (last 40 quarters = 10 years)
 * Identifies quarterly data by period duration (~3 months = quarterly)
 */
function extractEarnings(facts) {
  const earningsKeys = [
    'NetIncomeLoss',
    'ProfitLoss',
    'NetIncomeLossAvailableToCommonStockholdersBasic'
  ];

  for (const key of earningsKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units.USD;
      if (!units) continue;

      // Filter for quarterly data (period duration ~3 months)
      const quarterly = units
        .filter(item => {
          if (!item.val || item.val === 0 || !item.start || !item.end) return false;

          // Calculate period duration in days
          const startDate = new Date(item.start);
          const endDate = new Date(item.end);
          const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);

          // Quarterly data should be 70-120 days (roughly 3 months, allowing for variation)
          return daysDiff >= 70 && daysDiff <= 120;
        })
        .sort((a, b) => b.end.localeCompare(a.end))
        .reduce((acc, item) => {
          // Deduplicate by end date, keeping first occurrence (most recent filing)
          if (!acc.find(x => x.period === item.end)) {
            acc.push({ period: item.end, earnings: item.val });
          }
          return acc;
        }, [])
        .slice(0, 40);

      if (quarterly.length > 0) {
        return quarterly;
      }
    }
  }

  return [];
}

/**
 * Extract TTM earnings (last 37 periods)
 * TTM = Trailing Twelve Months, calculated as rolling 4-quarter sum
 */
function extractTTMEarnings(facts) {
  // First get quarterly data
  const quarterly = extractEarnings(facts);
  if (quarterly.length < 4) return [];

  // Calculate TTM for each period (starting from Q4)
  const ttm = [];
  for (let i = 3; i < quarterly.length; i++) {
    const last4Quarters = quarterly.slice(i - 3, i + 1);
    const ttmEarnings = last4Quarters.reduce((sum, q) => sum + q.earnings, 0);

    ttm.push({
      period: quarterly[i].period,
      earnings: ttmEarnings
    });
  }

  return ttm.slice(0, 37);
}

/**
 * Get data from cache (KV or in-memory fallback)
 */
async function getCache(env, key) {
  try {
    if (env.CACHE) {
      const value = await env.CACHE.get(key, { type: 'json' });
      return value;
    }
  } catch (error) {
    console.error('Cache get error:', error);
  }
  return null;
}

/**
 * Set data in cache with TTL
 */
async function setCache(env, key, value, ttl) {
  try {
    if (env.CACHE) {
      await env.CACHE.put(key, JSON.stringify(value), {
        expirationTtl: ttl
      });
    }
  } catch (error) {
    console.error('Cache set error:', error);
  }
}

/**
 * Helper to create JSON response
 */
function jsonResponse(data, status = 200, additionalHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, ...additionalHeaders }
  });
}

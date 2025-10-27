/**
 * Cloudflare Worker - Stock Market Data API Proxy
 * Uses Marketstack API for price data with caching
 */

const MARKETSTACK_BASE_URL = 'http://api.marketstack.com/v1';
const CACHE_TTL = {
  QUOTE: 60,        // 1 minute for real-time quotes
  EOD: 3600,        // 1 hour for end-of-day data
  INTRADAY: 300     // 5 minutes for intraday
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
      if (url.pathname.startsWith('/api/quote/')) {
        return await handleQuote(request, env, url);
      } else if (url.pathname.startsWith('/api/eod/')) {
        return await handleEOD(request, env, url);
      } else if (url.pathname.startsWith('/api/intraday/')) {
        return await handleIntraday(request, env, url);
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

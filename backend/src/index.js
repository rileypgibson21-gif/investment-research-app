/**
 * Cloudflare Worker - SEC EDGAR Data API
 * Free financial data from SEC filings with intelligent caching
 */

const SEC_BASE_URL = 'https://data.sec.gov';
const CACHE_TTL = {
  COMPANY_FACTS: 86400,  // 24 hours - raw SEC data
  CIK_LOOKUP: 604800     // 7 days - ticker to CIK mapping rarely changes
};

// CORS headers for iOS app
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json'
};

// User-Agent for SEC API compliance
// SEC requires a valid User-Agent identifying your app and contact
// TODO: Replace with your actual contact email before App Store submission
const USER_AGENT = 'SEC-Research-iOS-App/2.0 (contact@yourapp.com)';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    try {
      // Route handling - SEC data only
      if (url.pathname.startsWith('/api/revenue-ttm/')) {
        return await handleTTMRevenue(request, env, url);
      } else if (url.pathname.startsWith('/api/revenue/')) {
        return await handleRevenue(request, env, url);
      } else if (url.pathname.startsWith('/api/earnings-ttm/')) {
        return await handleTTMEarnings(request, env, url);
      } else if (url.pathname.startsWith('/api/earnings/')) {
        return await handleEarnings(request, env, url);
      } else if (url.pathname === '/api/health') {
        return jsonResponse({
          status: 'healthy',
          timestamp: new Date().toISOString(),
          dataSource: 'SEC EDGAR API',
          cost: 'free'
        });
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
 * Handle quarterly revenue from SEC EDGAR
 * GET /api/revenue/:symbol
 */
async function handleRevenue(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const revenue = extractRevenue(facts);
    return jsonResponse(revenue);
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

  try {
    const facts = await getCompanyFacts(symbol, env);
    const revenue = extractTTMRevenue(facts);
    return jsonResponse(revenue);
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

  try {
    const facts = await getCompanyFacts(symbol, env);
    const earnings = extractEarnings(facts);
    return jsonResponse(earnings);
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

  try {
    const facts = await getCompanyFacts(symbol, env);
    const earnings = extractTTMEarnings(facts);
    return jsonResponse(earnings);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Get company facts from SEC EDGAR with caching
 * This is the ONLY function that fetches from SEC API
 * All endpoints share this cached data
 */
async function getCompanyFacts(symbol, env) {
  // Check if companyfacts are already cached
  const cacheKey = `companyfacts:${symbol}`;
  const cached = await getCache(env, cacheKey);

  if (cached) {
    return cached;
  }

  // Cache miss - fetch from SEC
  const cik = await getCIK(symbol, env);
  const response = await fetch(`${SEC_BASE_URL}/api/xbrl/companyfacts/CIK${cik}.json`, {
    headers: {
      'User-Agent': USER_AGENT
    }
  });

  if (!response.ok) {
    throw new Error('Failed to fetch company facts from SEC');
  }

  const facts = await response.json();

  // Cache the raw facts for 24 hours
  await setCache(env, cacheKey, facts, CACHE_TTL.COMPANY_FACTS);

  return facts;
}

/**
 * Get CIK from ticker symbol with caching
 */
async function getCIK(symbol, env) {
  // Check cache first
  const cacheKey = `cik:${symbol}`;
  const cached = await getCache(env, cacheKey);

  if (cached) {
    return cached;
  }

  // Fetch ticker to CIK mapping from SEC
  const response = await fetch('https://www.sec.gov/files/company_tickers.json', {
    headers: {
      'User-Agent': USER_AGENT
    }
  });

  if (!response.ok) {
    throw new Error('Failed to fetch company tickers from SEC');
  }

  const tickers = await response.json();

  for (const key in tickers) {
    if (tickers[key].ticker === symbol) {
      const cik = String(tickers[key].cik_str).padStart(10, '0');

      // Cache CIK for 7 days (rarely changes)
      await setCache(env, cacheKey, cik, CACHE_TTL.CIK_LOOKUP);

      return cik;
    }
  }

  throw new Error(`Company not found for ticker: ${symbol}`);
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
 * Get data from cache (KV)
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

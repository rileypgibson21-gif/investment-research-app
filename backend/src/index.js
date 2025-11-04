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
const USER_AGENT = 'SEC-Research-iOS-App/2.0 (ekonixlab@gmail.com)';

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
      } else if (url.pathname.startsWith('/api/operating-income-ttm/')) {
        return await handleTTMOperatingIncome(request, env, url);
      } else if (url.pathname.startsWith('/api/operating-income/')) {
        return await handleOperatingIncome(request, env, url);
      } else if (url.pathname === '/api/tickers') {
        return await handleTickers(request, env);
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
 * Handle quarterly operating income from SEC EDGAR
 * GET /api/operating-income/:symbol
 */
async function handleOperatingIncome(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const operatingIncome = extractOperatingIncome(facts);
    return jsonResponse(operatingIncome);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM operating income from SEC EDGAR
 * GET /api/operating-income-ttm/:symbol
 */
async function handleTTMOperatingIncome(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const operatingIncome = extractTTMOperatingIncome(facts);
    return jsonResponse(operatingIncome);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle ticker list request
 * GET /api/tickers
 * Returns all available tickers with company names for autocomplete
 */
async function handleTickers(request, env) {
  try {
    // Check cache first
    const cacheKey = 'all_tickers';
    const cached = await getCache(env, cacheKey);

    if (cached) {
      return jsonResponse(cached);
    }

    // Fetch from SEC
    const response = await fetch('https://www.sec.gov/files/company_tickers.json', {
      headers: {
        'User-Agent': USER_AGENT
      }
    });

    if (!response.ok) {
      throw new Error('Failed to fetch company tickers from SEC');
    }

    const tickers = await response.json();

    // Transform to array format: [{ ticker, name, cik }, ...]
    const tickerArray = Object.values(tickers).map(t => ({
      ticker: t.ticker,
      name: t.title,
      cik: String(t.cik_str).padStart(10, '0')
    }));

    // Cache for 7 days
    await setCache(env, cacheKey, tickerArray, CACHE_TTL.CIK_LOOKUP);

    return jsonResponse(tickerArray);
  } catch (error) {
    return jsonResponse({ error: error.message }, 500);
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
 * Combines data from multiple revenue keys to get complete history
 * Calculates missing quarters from cumulative year-to-date data
 */
function extractRevenue(facts) {
  const revenueKeys = [
    'RevenueFromContractWithCustomerExcludingAssessedTax', // Most recent (2017-present)
    'RevenueFromContractWithCustomer',
    'SalesRevenueNet',                                       // Older (2008-2018)
    'Revenues'                                                // Oldest
  ];

  // Collect quarterly data and cumulative data from all available keys
  const allQuarterly = [];
  const allCumulative = [];

  for (const key of revenueKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units?.USD;
      if (!units) continue;

      for (const item of units) {
        if (!item.val || item.val <= 0 || !item.start || !item.end) continue;

        const startDate = new Date(item.start);
        const endDate = new Date(item.end);
        const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);

        // Quarterly data (70-120 days)
        if (daysDiff >= 70 && daysDiff <= 120) {
          allQuarterly.push(item);
        }
        // Cumulative year-to-date data (for calculating missing quarters)
        // 6-month (~180 days), 9-month (~270 days), 12-month (~360 days)
        else if (daysDiff >= 150 && daysDiff <= 380) {
          allCumulative.push(item);
        }
      }
    }
  }

  // Deduplicate quarterly data
  // Filter to only include items with quarterly 'frame' field (excludes cumulative data)
  // Prefer amended filings (10-Q/A) and later filing dates
  const quarterlyDeduped = allQuarterly
    .filter(item => item.frame && /Q[1-4]/.test(item.frame)) // Only true quarterly frames
    .sort((a, b) => {
      // First sort by end date (descending)
      if (a.end !== b.end) return b.end.localeCompare(a.end);

      // For same period, prefer amended filings (forms with /A suffix)
      const aIsAmended = a.form && a.form.includes('/A');
      const bIsAmended = b.form && b.form.includes('/A');
      if (aIsAmended && !bIsAmended) return -1;
      if (!aIsAmended && bIsAmended) return 1;

      // Then prefer later filing dates
      return (b.filed || '').localeCompare(a.filed || '');
    })
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.end)) {
        acc.push({ period: item.end, revenue: item.val, start: item.start });
      }
      return acc;
    }, []);

  // Calculate missing quarters from cumulative data
  // Group cumulative data by fiscal year (same start date)
  const calculated = [];
  for (const annual of allCumulative) {
    const annualStart = annual.start;
    const annualEnd = annual.end;
    const annualDays = (new Date(annualEnd) - new Date(annualStart)) / (1000 * 60 * 60 * 24);

    // Only process annual data (~365 days)
    if (annualDays < 330 || annualDays > 380) continue;

    // Find the 9-month cumulative for the same fiscal year
    const nineMonth = allCumulative.find(item =>
      item.start === annualStart &&
      item.end < annualEnd &&
      Math.abs((new Date(item.end) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 270) < 30
    );

    if (nineMonth) {
      // Calculate Q4 = Annual - 9-month
      const q4Revenue = annual.val - nineMonth.val;
      if (q4Revenue > 0) {
        // Check if we already have this quarter
        const hasQuarter = quarterlyDeduped.find(x => x.period === annualEnd);
        if (!hasQuarter) {
          calculated.push({ period: annualEnd, revenue: q4Revenue, start: nineMonth.end });
        }
      }
    }
  }

  // Combine quarterly and calculated data
  const combined = [...quarterlyDeduped.map(x => ({ period: x.period, revenue: x.revenue })), ...calculated];

  // Sort by end date descending and deduplicate
  const final = combined
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push({ period: item.period, revenue: item.revenue });
      }
      return acc;
    }, []);

  // Return most recent 40 quarters (10 years)
  return final.slice(0, 40);
}

/**
 * Extract TTM revenue (last 37 periods)
 * TTM = Trailing Twelve Months, calculated as rolling 4-quarter sum
 * Period is labeled with the most recent quarter in the sum
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
      period: quarterly[i - 3].period,  // Use most recent quarter, not oldest
      revenue: ttmRevenue
    });
  }

  return ttm.slice(0, 37);
}

/**
 * Extract quarterly earnings (last 40 quarters = 10 years)
 * Identifies quarterly data by period duration (~3 months = quarterly)
 * Combines data from multiple earnings keys to get complete history
 * Calculates missing quarters from cumulative year-to-date data
 */
function extractEarnings(facts) {
  const earningsKeys = [
    'NetIncomeLoss',
    'ProfitLoss',
    'NetIncomeLossAvailableToCommonStockholdersBasic'
  ];

  // Collect quarterly data and cumulative data from all available keys
  const allQuarterly = [];
  const allCumulative = [];

  for (const key of earningsKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units?.USD;
      if (!units) continue;

      for (const item of units) {
        if (!item.val || item.val === 0 || !item.start || !item.end) continue;

        const startDate = new Date(item.start);
        const endDate = new Date(item.end);
        const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);

        // Quarterly data (70-120 days)
        if (daysDiff >= 70 && daysDiff <= 120) {
          allQuarterly.push(item);
        }
        // Cumulative year-to-date data (for calculating missing quarters)
        else if (daysDiff >= 150 && daysDiff <= 380) {
          allCumulative.push(item);
        }
      }
    }
  }

  // Deduplicate quarterly data
  // Filter to only include items with quarterly 'frame' field (excludes cumulative data)
  // Prefer amended filings (10-Q/A) and later filing dates
  const quarterlyDeduped = allQuarterly
    .filter(item => item.frame && /Q[1-4]/.test(item.frame)) // Only true quarterly frames
    .sort((a, b) => {
      // First sort by end date (descending)
      if (a.end !== b.end) return b.end.localeCompare(a.end);

      // For same period, prefer amended filings (forms with /A suffix)
      const aIsAmended = a.form && a.form.includes('/A');
      const bIsAmended = b.form && b.form.includes('/A');
      if (aIsAmended && !bIsAmended) return -1;
      if (!aIsAmended && bIsAmended) return 1;

      // Then prefer later filing dates
      return (b.filed || '').localeCompare(a.filed || '');
    })
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.end)) {
        acc.push({ period: item.end, earnings: item.val, start: item.start });
      }
      return acc;
    }, []);

  // Calculate missing quarters from cumulative data
  const calculated = [];
  for (const annual of allCumulative) {
    const annualStart = annual.start;
    const annualEnd = annual.end;
    const annualDays = (new Date(annualEnd) - new Date(annualStart)) / (1000 * 60 * 60 * 24);

    // Only process annual data (~365 days)
    if (annualDays < 330 || annualDays > 380) continue;

    // Find the 9-month cumulative for the same fiscal year
    const nineMonth = allCumulative.find(item =>
      item.start === annualStart &&
      item.end < annualEnd &&
      Math.abs((new Date(item.end) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 270) < 30
    );

    if (nineMonth) {
      // Calculate Q4 = Annual - 9-month
      const q4Earnings = annual.val - nineMonth.val;
      // Check if we already have this quarter
      const hasQuarter = quarterlyDeduped.find(x => x.period === annualEnd);
      if (!hasQuarter) {
        calculated.push({ period: annualEnd, earnings: q4Earnings, start: nineMonth.end });
      }
    }
  }

  // Combine quarterly and calculated data
  const combined = [...quarterlyDeduped.map(x => ({ period: x.period, earnings: x.earnings })), ...calculated];

  // Sort by end date descending and deduplicate
  const final = combined
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push({ period: item.period, earnings: item.earnings });
      }
      return acc;
    }, []);

  // Return most recent 40 quarters (10 years)
  return final.slice(0, 40);
}

/**
 * Extract TTM earnings (last 37 periods)
 * TTM = Trailing Twelve Months, calculated as rolling 4-quarter sum
 * Period is labeled with the most recent quarter in the sum
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
      period: quarterly[i - 3].period,  // Use most recent quarter, not oldest
      earnings: ttmEarnings
    });
  }

  return ttm.slice(0, 37);
}

/**
 * Extract quarterly operating income (last 40 quarters = 10 years)
 * Operating Income = Revenue - Operating Expenses (before interest and taxes)
 */
function extractOperatingIncome(facts) {
  const operatingIncomeKeys = [
    'OperatingIncomeLoss',
    'IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest'
  ];

  // Collect quarterly data and cumulative data from all available keys
  const allQuarterly = [];
  const allCumulative = [];

  for (const key of operatingIncomeKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units?.USD;
      if (!units) continue;

      for (const item of units) {
        if (!item.val || item.val === 0 || !item.start || !item.end) continue;

        const startDate = new Date(item.start);
        const endDate = new Date(item.end);
        const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);

        // Quarterly data (70-120 days)
        if (daysDiff >= 70 && daysDiff <= 120) {
          allQuarterly.push(item);
        }
        // Cumulative year-to-date data (for calculating missing quarters)
        else if (daysDiff >= 150 && daysDiff <= 380) {
          allCumulative.push(item);
        }
      }
    }
  }

  // Deduplicate quarterly data
  // Filter to only include items with quarterly 'frame' field (excludes cumulative data)
  // Prefer amended filings (10-Q/A) and later filing dates
  const quarterlyDeduped = allQuarterly
    .filter(item => item.frame && /Q[1-4]/.test(item.frame)) // Only true quarterly frames
    .sort((a, b) => {
      // First sort by end date (descending)
      if (a.end !== b.end) return b.end.localeCompare(a.end);

      // For same period, prefer amended filings (forms with /A suffix)
      const aIsAmended = a.form && a.form.includes('/A');
      const bIsAmended = b.form && b.form.includes('/A');
      if (aIsAmended && !bIsAmended) return -1;
      if (!aIsAmended && bIsAmended) return 1;

      // Then prefer later filing dates
      return (b.filed || '').localeCompare(a.filed || '');
    })
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.end)) {
        acc.push({ period: item.end, operatingIncome: item.val, start: item.start });
      }
      return acc;
    }, []);

  // Calculate missing quarters from cumulative data
  const calculated = [];
  for (const annual of allCumulative) {
    const annualStart = annual.start;
    const annualEnd = annual.end;
    const annualDays = (new Date(annualEnd) - new Date(annualStart)) / (1000 * 60 * 60 * 24);

    // Only process annual data (~365 days)
    if (annualDays < 330 || annualDays > 380) continue;

    // Find the 9-month cumulative for the same fiscal year
    const nineMonth = allCumulative.find(item =>
      item.start === annualStart &&
      item.end < annualEnd &&
      Math.abs((new Date(item.end) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 270) < 30
    );

    if (nineMonth) {
      // Calculate Q4 = Annual - 9-month
      const q4OperatingIncome = annual.val - nineMonth.val;
      // Check if we already have this quarter
      const hasQuarter = quarterlyDeduped.find(x => x.period === annualEnd);
      if (!hasQuarter) {
        calculated.push({ period: annualEnd, operatingIncome: q4OperatingIncome, start: nineMonth.end });
      }
    }
  }

  // Combine quarterly and calculated data
  const combined = [...quarterlyDeduped.map(x => ({ period: x.period, operatingIncome: x.operatingIncome })), ...calculated];

  // Sort by end date descending and deduplicate
  const final = combined
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push({ period: item.period, operatingIncome: item.operatingIncome });
      }
      return acc;
    }, []);

  // Return most recent 40 quarters (10 years)
  return final.slice(0, 40);
}

/**
 * Extract TTM operating income (last 37 periods)
 * TTM = Trailing Twelve Months, calculated as rolling 4-quarter sum
 * Period is labeled with the most recent quarter in the sum
 */
function extractTTMOperatingIncome(facts) {
  // First get quarterly data
  const quarterly = extractOperatingIncome(facts);
  if (quarterly.length < 4) return [];

  // Calculate TTM for each period (starting from Q4)
  const ttm = [];
  for (let i = 3; i < quarterly.length; i++) {
    const last4Quarters = quarterly.slice(i - 3, i + 1);
    const ttmOperatingIncome = last4Quarters.reduce((sum, q) => sum + q.operatingIncome, 0);

    ttm.push({
      period: quarterly[i - 3].period,  // Use most recent quarter, not oldest
      operatingIncome: ttmOperatingIncome
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

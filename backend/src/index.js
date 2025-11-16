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
      } else if (url.pathname.startsWith('/api/gross-profit-ttm/')) {
        return await handleTTMGrossProfit(request, env, url);
      } else if (url.pathname.startsWith('/api/gross-profit/')) {
        return await handleGrossProfit(request, env, url);
      } else if (url.pathname.startsWith('/api/assets-ttm/')) {
        return await handleTTMAssets(request, env, url);
      } else if (url.pathname.startsWith('/api/assets/')) {
        return await handleAssets(request, env, url);
      } else if (url.pathname.startsWith('/api/liabilities/')) {
        return await handleLiabilities(request, env, url);
      } else if (url.pathname.startsWith('/api/dividends/')) {
        return await handleDividends(request, env, url);
      } else if (url.pathname.startsWith('/api/ebitda-ttm/')) {
        return await handleTTMEBITDA(request, env, url);
      } else if (url.pathname.startsWith('/api/ebitda/')) {
        return await handleEBITDA(request, env, url);
      } else if (url.pathname.startsWith('/api/free-cash-flow-ttm/')) {
        return await handleTTMFreeCashFlow(request, env, url);
      } else if (url.pathname.startsWith('/api/free-cash-flow/')) {
        return await handleFreeCashFlow(request, env, url);
      } else if (url.pathname.startsWith('/api/net-margin-ttm/')) {
        return await handleTTMNetMargin(request, env, url);
      } else if (url.pathname.startsWith('/api/net-margin/')) {
        return await handleNetMargin(request, env, url);
      } else if (url.pathname.startsWith('/api/operating-margin-ttm/')) {
        return await handleTTMOperatingMargin(request, env, url);
      } else if (url.pathname.startsWith('/api/operating-margin/')) {
        return await handleOperatingMargin(request, env, url);
      } else if (url.pathname.startsWith('/api/gross-margin-ttm/')) {
        return await handleTTMGrossMargin(request, env, url);
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
 * Handle quarterly gross profit from SEC EDGAR
 * GET /api/gross-profit/:symbol
 */
async function handleGrossProfit(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const grossProfit = extractGrossProfit(facts);
    return jsonResponse(grossProfit);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM gross profit from SEC EDGAR
 * GET /api/gross-profit-ttm/:symbol
 */
async function handleTTMGrossProfit(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const grossProfit = extractTTMGrossProfit(facts);
    return jsonResponse(grossProfit);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle quarterly assets from SEC EDGAR
 * GET /api/assets/:symbol
 */
async function handleAssets(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const assets = extractAssets(facts);
    return jsonResponse(assets);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM assets from SEC EDGAR
 * GET /api/assets-ttm/:symbol
 */
async function handleTTMAssets(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const assets = extractTTMAssets(facts);
    return jsonResponse(assets);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle quarterly liabilities from SEC EDGAR
 * GET /api/liabilities/:symbol
 */
async function handleLiabilities(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const liabilities = extractLiabilities(facts);
    return jsonResponse(liabilities);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle quarterly dividends from SEC EDGAR
 * GET /api/dividends/:symbol
 */
async function handleDividends(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const dividends = extractDividends(facts);
    return jsonResponse(dividends);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle quarterly EBITDA from SEC EDGAR
 * GET /api/ebitda/:symbol
 */
async function handleEBITDA(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const ebitda = extractEBITDA(facts);
    return jsonResponse(ebitda);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM EBITDA from SEC EDGAR
 * GET /api/ebitda-ttm/:symbol
 */
async function handleTTMEBITDA(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const ebitda = extractTTMEBITDA(facts);
    return jsonResponse(ebitda);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle quarterly Free Cash Flow from SEC EDGAR
 * GET /api/free-cash-flow/:symbol
 */
async function handleFreeCashFlow(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const fcf = extractFreeCashFlow(facts);
    return jsonResponse(fcf);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM Free Cash Flow from SEC EDGAR
 * GET /api/free-cash-flow-ttm/:symbol
 */
async function handleTTMFreeCashFlow(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const fcf = extractTTMFreeCashFlow(facts);
    return jsonResponse(fcf);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle quarterly net margin from SEC EDGAR
 * GET /api/net-margin/:symbol
 */
async function handleNetMargin(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const netMargin = extractNetMargin(facts);
    return jsonResponse(netMargin);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle quarterly operating margin from SEC EDGAR
 * GET /api/operating-margin/:symbol
 */
async function handleOperatingMargin(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const operatingMargin = extractOperatingMargin(facts);
    return jsonResponse(operatingMargin);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM net margin from SEC EDGAR
 * GET /api/net-margin-ttm/:symbol
 */
async function handleTTMNetMargin(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const netMargin = extractTTMNetMargin(facts);
    return jsonResponse(netMargin);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM operating margin from SEC EDGAR
 * GET /api/operating-margin-ttm/:symbol
 */
async function handleTTMOperatingMargin(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const operatingMargin = extractTTMOperatingMargin(facts);
    return jsonResponse(operatingMargin);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM gross margin from SEC EDGAR
 * GET /api/gross-margin-ttm/:symbol
 */
async function handleTTMGrossMargin(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();

  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const grossMargin = extractTTMGrossMargin(facts);
    return jsonResponse(grossMargin);
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
    'Revenues',                                              // Preferred - net revenue (most accurate)
    'SalesRevenueNet',                                       // Alternative net revenue
    'RevenueFromContractWithCustomerExcludingAssessedTax',  // ASC 606 (2018+) - can include gross amounts
    'RevenueFromContractWithCustomer'                        // ASC 606 alternative
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
  // Exclude Q4 to force calculation (prevents mixing incompatible GAAP concepts)
  // Prefer amended filings (10-Q/A) and later filing dates
  const quarterlyDeduped = allQuarterly
    .filter(item => item.frame && /Q[1-3]/.test(item.frame)) // Only Q1-Q3 frames, Q4 will be calculated
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
      period: quarterly[i - 3].period,  // Use most recent quarter (data is descending)
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
  // Exclude Q4 to force calculation (prevents mixing incompatible GAAP concepts)
  // Prefer amended filings (10-Q/A) and later filing dates
  const quarterlyDeduped = allQuarterly
    .filter(item => item.frame && /Q[1-3]/.test(item.frame)) // Only Q1-Q3 frames, Q4 will be calculated
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
      period: quarterly[i - 3].period,  // Use most recent quarter (data is descending)
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
  // Exclude Q4 to force calculation (prevents mixing incompatible GAAP concepts)
  // Prefer amended filings (10-Q/A) and later filing dates
  const quarterlyDeduped = allQuarterly
    .filter(item => item.frame && /Q[1-3]/.test(item.frame)) // Only Q1-Q3 frames, Q4 will be calculated
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
      period: quarterly[i - 3].period,  // Use most recent quarter (data is descending)
      operatingIncome: ttmOperatingIncome
    });
  }

  return ttm.slice(0, 37);
}

/**
 * Extract quarterly gross profit (last 40 quarters = 10 years)
 * Gross Profit = Revenue - Cost of Goods Sold
 *
 * Strategy:
 * 1. Try to extract direct GrossProfit field
 * 2. If insufficient data, calculate from Revenue - CostOfRevenue
 * 3. Fall back to revenue for financial services companies
 */
function extractGrossProfit(facts) {
  const grossProfitKeys = [
    'GrossProfit'
  ];

  // Collect quarterly data and cumulative data from all available keys
  const allQuarterly = [];
  const allCumulative = [];

  for (const key of grossProfitKeys) {
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
  // Exclude Q4 to force calculation (prevents mixing incompatible GAAP concepts)
  // Prefer amended filings (10-Q/A) and later filing dates
  const quarterlyDeduped = allQuarterly
    .filter(item => item.frame && /Q[1-3]/.test(item.frame)) // Only Q1-Q3 frames, Q4 will be calculated
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
        acc.push({ period: item.end, grossProfit: item.val, start: item.start });
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
      const q4GrossProfit = annual.val - nineMonth.val;
      // Check if we already have this quarter
      const hasQuarter = quarterlyDeduped.find(x => x.period === annualEnd);
      if (!hasQuarter) {
        calculated.push({ period: annualEnd, grossProfit: q4GrossProfit, start: nineMonth.end });
      }
    }
  }

  // Combine quarterly and calculated data
  const combined = [...quarterlyDeduped.map(x => ({ period: x.period, grossProfit: x.grossProfit })), ...calculated];

  // Sort by end date descending and deduplicate
  const final = combined
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push({ period: item.period, grossProfit: item.grossProfit });
      }
      return acc;
    }, []);

  // Always try calculating from Revenue - Cost of Revenue
  const calculatedGrossProfit = calculateGrossProfitFromComponents(facts);

  // Prefer calculated data if:
  // 1. Direct GrossProfit field has < 20 quarters, OR
  // 2. Calculated data has more quarters, OR
  // 3. Calculated data is more recent (newer data)
  if (final.length < 20 ||
      calculatedGrossProfit.length > final.length ||
      (calculatedGrossProfit.length > 0 && final.length > 0 && calculatedGrossProfit[0].period > final[0].period)) {
    if (calculatedGrossProfit.length > 0) {
      return calculatedGrossProfit.slice(0, 40);
    }
  }

  // If no gross profit data found, fall back to revenue data
  // This is common for financial services companies (e.g., Mastercard, banks)
  if (final.length === 0) {
    const revenueData = extractRevenue(facts);
    return revenueData.map(item => ({
      period: item.period,
      grossProfit: item.revenue,
      isRevenueFallback: true
    }));
  }

  // Return most recent 40 quarters (10 years)
  return final.slice(0, 40);
}

/**
 * Calculate gross profit from Revenue - Cost of Revenue
 * Used when GrossProfit field is not directly available
 */
function calculateGrossProfitFromComponents(facts) {
  // Get revenue data
  const revenueData = extractRevenue(facts);
  if (revenueData.length === 0) return [];

  // Get cost of revenue data
  const costKeys = [
    'CostOfRevenue',
    'CostOfGoodsAndServicesSold',
    'CostOfGoodsSold'
  ];

  const allCostData = [];
  const allCostCumulative = [];

  for (const key of costKeys) {
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
          allCostData.push(item);
        }
        // Cumulative year-to-date data
        else if (daysDiff >= 150 && daysDiff <= 380) {
          allCostCumulative.push(item);
        }
      }
    }
  }

  // Deduplicate cost data
  const costDeduped = allCostData
    .filter(item => item.frame && /Q[1-3]/.test(item.frame))
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
        acc.push({ period: item.end, cost: item.val, start: item.start });
      }
      return acc;
    }, []);

  // Calculate Q4 costs from cumulative data
  const calculatedCosts = [];
  for (const annual of allCostCumulative) {
    const annualStart = annual.start;
    const annualEnd = annual.end;
    const annualDays = (new Date(annualEnd) - new Date(annualStart)) / (1000 * 60 * 60 * 24);

    if (annualDays < 330 || annualDays > 380) continue;

    const nineMonth = allCostCumulative.find(item =>
      item.start === annualStart &&
      item.end < annualEnd &&
      Math.abs((new Date(item.end) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 270) < 30
    );

    if (nineMonth) {
      const q4Cost = annual.val - nineMonth.val;
      if (q4Cost > 0) {
        const hasQuarter = costDeduped.find(x => x.period === annualEnd);
        if (!hasQuarter) {
          calculatedCosts.push({ period: annualEnd, cost: q4Cost });
        }
      }
    }
  }

  // Combine all cost data
  const allCosts = [...costDeduped, ...calculatedCosts]
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push(item);
      }
      return acc;
    }, []);

  // Calculate gross profit = Revenue - Cost
  const grossProfitData = [];
  for (const rev of revenueData) {
    const cost = allCosts.find(c => c.period === rev.period);
    if (cost) {
      grossProfitData.push({
        period: rev.period,
        grossProfit: rev.revenue - cost.cost
      });
    }
  }

  return grossProfitData.sort((a, b) => b.period.localeCompare(a.period));
}

/**
 * Extract TTM gross profit (last 37 periods)
 * TTM = Trailing Twelve Months, calculated as rolling 4-quarter sum
 * Period is labeled with the most recent quarter in the sum
 */
function extractTTMGrossProfit(facts) {
  // First get quarterly data
  const quarterly = extractGrossProfit(facts);
  if (quarterly.length < 4) return [];

  // Check if this is revenue fallback data
  const isRevenueFallback = quarterly[0]?.isRevenueFallback || false;

  // Calculate TTM for each period (starting from Q4)
  const ttm = [];
  for (let i = 3; i < quarterly.length; i++) {
    const last4Quarters = quarterly.slice(i - 3, i + 1);
    const ttmGrossProfit = last4Quarters.reduce((sum, q) => sum + q.grossProfit, 0);

    const ttmPoint = {
      period: quarterly[i - 3].period,  // Use most recent quarter (data is descending)
      grossProfit: ttmGrossProfit
    };

    // Pass through revenue fallback flag if applicable
    if (isRevenueFallback) {
      ttmPoint.isRevenueFallback = true;
    }

    ttm.push(ttmPoint);
  }

  return ttm.slice(0, 37);
}

/**
 * Extract quarterly assets from SEC EDGAR data
 * Assets are balance sheet items (point-in-time measurements)
 * Returns last 40 quarters of total assets
 */
function extractAssets(facts) {
  const assetsKeys = [
    'Assets'
  ];

  // Collect point-in-time asset data
  const allAssets = [];

  for (const key of assetsKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units?.USD;
      if (!units) continue;

      for (const item of units) {
        // Assets are instant measurements (no start date, only end date)
        if (!item.val || item.val <= 0 || !item.end) continue;
        allAssets.push(item);
      }
    }
  }

  // Deduplicate by period end date
  // Prefer amended filings and later filing dates
  const assetsDeduped = allAssets
    .filter(item => {
      // Filter to quarterly reports using frame field if available
      if (item.frame) {
        return /Q[1-4]/.test(item.frame) || /CY\d{4}$/.test(item.frame);
      }
      // If no frame, include all (will be filtered by filing form)
      return item.form === '10-Q' || item.form === '10-K' ||
             item.form === '10-Q/A' || item.form === '10-K/A';
    })
    .sort((a, b) => {
      // First sort by end date (descending)
      if (a.end !== b.end) return b.end.localeCompare(a.end);

      // For same period, prefer amended filings
      const aIsAmended = a.form && a.form.includes('/A');
      const bIsAmended = b.form && b.form.includes('/A');
      if (aIsAmended && !bIsAmended) return -1;
      if (!aIsAmended && bIsAmended) return 1;

      // Then prefer later filing dates
      return (b.filed || '').localeCompare(a.filed || '');
    })
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.end)) {
        acc.push({ period: item.end, assets: item.val });
      }
      return acc;
    }, []);

  return assetsDeduped.slice(0, 40);
}

/**
 * Extract TTM assets (last 37 periods)
 * For balance sheet items like assets, TTM is simply the average of the last 4 quarters
 */
function extractTTMAssets(facts) {
  // First get quarterly data
  const quarterly = extractAssets(facts);
  if (quarterly.length < 4) return [];

  // Calculate TTM average for each period
  const ttm = [];
  for (let i = 3; i < quarterly.length; i++) {
    const last4Quarters = quarterly.slice(i - 3, i + 1);
    const avgAssets = last4Quarters.reduce((sum, q) => sum + q.assets, 0) / 4;

    ttm.push({
      period: quarterly[i - 3].period,  // Use most recent quarter (data is descending)
      assets: avgAssets
    });
  }

  return ttm.slice(0, 37);
}

/**
 * Extract quarterly liabilities from SEC EDGAR data
 * Liabilities are balance sheet items (point-in-time measurements)
 * Returns last 40 quarters of total liabilities
 */
function extractLiabilities(facts) {
  const liabilitiesKeys = [
    'Liabilities'
  ];

  // Collect point-in-time liability data
  const allLiabilities = [];

  for (const key of liabilitiesKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units?.USD;
      if (!units) continue;

      for (const item of units) {
        // Liabilities are instant measurements (no start date, only end date)
        if (!item.val || item.val <= 0 || !item.end) continue;
        allLiabilities.push(item);
      }
    }
  }

  // Deduplicate by period end date
  // Prefer amended filings and later filing dates
  const liabilitiesDeduped = allLiabilities
    .filter(item => {
      // Filter to quarterly reports using frame field if available
      if (item.frame) {
        return /Q[1-4]/.test(item.frame) || /CY\d{4}$/.test(item.frame);
      }
      // If no frame, include all (will be filtered by filing form)
      return item.form === '10-Q' || item.form === '10-K' ||
             item.form === '10-Q/A' || item.form === '10-K/A';
    })
    .sort((a, b) => {
      // First sort by end date (descending)
      if (a.end !== b.end) return b.end.localeCompare(a.end);

      // For same period, prefer amended filings
      const aIsAmended = a.form && a.form.includes('/A');
      const bIsAmended = b.form && b.form.includes('/A');
      if (aIsAmended && !bIsAmended) return -1;
      if (!aIsAmended && bIsAmended) return 1;

      // Then prefer later filing dates
      return (b.filed || '').localeCompare(a.filed || '');
    })
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.end)) {
        acc.push({ period: item.end, liabilities: item.val });
      }
      return acc;
    }, []);

  return liabilitiesDeduped.slice(0, 40);
}

/**
 * Extract quarterly dividends from SEC EDGAR data
 * Dividends are cash flow items (have start and end dates)
 * Returns last 40 quarters of dividend payments
 *
 * Note: Many companies report dividends cumulatively (YTD), so we need to
 * calculate quarterly values by subtracting the previous quarter's cumulative value
 */
function extractDividends(facts) {
  const dividendsKeys = [
    'PaymentsOfDividendsCommonStock',
    'PaymentsOfDividends'
  ];

  // Collect all dividend data (both quarterly and cumulative)
  const allData = [];

  for (const key of dividendsKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units?.USD;
      if (!units) continue;

      for (const item of units) {
        if (!item.val || item.val <= 0 || !item.start || !item.end) continue;

        const startDate = new Date(item.start);
        const endDate = new Date(item.end);
        const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);

        // Accept quarterly (70-120 days) and cumulative (150-380 days) data
        if ((daysDiff >= 70 && daysDiff <= 120) || (daysDiff >= 150 && daysDiff <= 380)) {
          allData.push(item);
        }
      }
    }
  }

  // Separate quarterly and cumulative data
  const quarterly = [];
  const cumulative = [];

  for (const item of allData) {
    const startDate = new Date(item.start);
    const endDate = new Date(item.end);
    const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);

    if (daysDiff >= 70 && daysDiff <= 120) {
      quarterly.push(item);
    } else if (daysDiff >= 150 && daysDiff <= 380) {
      cumulative.push(item);
    }
  }

  // Deduplicate quarterly data
  const quarterlyDeduped = quarterly
    .filter(item => {
      // Accept items with quarterly frames or fiscal periods
      if (item.frame && /Q[1-4]/.test(item.frame)) return true;
      if (item.fp && /^Q[1-4]$/.test(item.fp)) return true;
      return false;
    })
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
        acc.push({ period: item.end, dividends: item.val });
      }
      return acc;
    }, []);

  // Calculate quarterly values from cumulative data
  const calculated = [];

  // Group cumulative data by fiscal year (same start date)
  const byFiscalYear = {};
  for (const item of cumulative) {
    const key = item.start;
    if (!byFiscalYear[key]) byFiscalYear[key] = [];
    byFiscalYear[key].push(item);
  }

  // For each fiscal year, calculate quarterly dividends
  for (const fiscalYear in byFiscalYear) {
    const periods = byFiscalYear[fiscalYear].sort((a, b) => a.end.localeCompare(b.end));

    for (let i = 0; i < periods.length; i++) {
      const current = periods[i];

      // Skip if we already have this quarter from quarterly data
      if (quarterlyDeduped.find(x => x.period === current.end)) continue;

      // Calculate quarterly value
      let quarterlyValue;
      if (i === 0) {
        // First period of the year - use the value as-is (it's Q1)
        quarterlyValue = current.val;
      } else {
        // Subtract previous cumulative to get this quarter
        quarterlyValue = current.val - periods[i - 1].val;
      }

      // Only add if positive
      if (quarterlyValue > 0) {
        calculated.push({ period: current.end, dividends: quarterlyValue });
      }
    }
  }

  // Combine quarterly and calculated, deduplicate, and sort
  const combined = [...quarterlyDeduped, ...calculated]
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push(item);
      }
      return acc;
    }, []);

  return combined.slice(0, 40);
}

/**
 * Extract quarterly EBITDA (last 40 quarters = 10 years)
 * EBITDA = Operating Income + Depreciation & Amortization
 * Calculates EBITDA from SEC EDGAR components
 */
function extractEBITDA(facts) {
  // First, get operating income data
  const operatingIncomeData = extractOperatingIncome(facts);

  // Get depreciation & amortization data
  const depreciationKeys = [
    'DepreciationDepletionAndAmortization',
    'Depreciation',
    'DepreciationAndAmortization'
  ];

  // Collect quarterly depreciation data
  const allQuarterly = [];
  const allCumulative = [];

  for (const key of depreciationKeys) {
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
        // Cumulative year-to-date data
        else if (daysDiff >= 150 && daysDiff <= 380) {
          allCumulative.push(item);
        }
      }
    }
  }

  // Deduplicate quarterly depreciation data
  const quarterlyDeduped = allQuarterly
    .filter(item => item.frame && /Q[1-3]/.test(item.frame))
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
        acc.push({ period: item.end, depreciation: item.val });
      }
      return acc;
    }, []);

  // Calculate Q4 depreciation from annual data
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
      const q4Depreciation = annual.val - nineMonth.val;
      if (q4Depreciation > 0) {
        const hasQuarter = quarterlyDeduped.find(x => x.period === annualEnd);
        if (!hasQuarter) {
          calculated.push({ period: annualEnd, depreciation: q4Depreciation });
        }
      }
    }
  }

  // Combine depreciation data
  const depreciationData = [...quarterlyDeduped, ...calculated]
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push(item);
      }
      return acc;
    }, []);

  // Calculate EBITDA = Operating Income + Depreciation & Amortization
  // If quarterly depreciation data isn't available, estimate from annual data
  const ebitdaData = [];

  for (const opIncome of operatingIncomeData) {
    const depreciation = depreciationData.find(d => d.period === opIncome.period);

    if (depreciation) {
      // Use exact quarterly depreciation data
      ebitdaData.push({
        period: opIncome.period,
        ebitda: opIncome.operatingIncome + depreciation.depreciation
      });
    } else {
      // Find annual depreciation for this period's fiscal year
      const periodDate = new Date(opIncome.period);
      const fiscalYearEnd = depreciationData.find(d => {
        const depDate = new Date(d.period);
        return depDate.getFullYear() === periodDate.getFullYear() &&
               Math.abs(depDate.getMonth() - periodDate.getMonth()) < 3;
      });

      if (fiscalYearEnd) {
        // Estimate quarterly depreciation as annual/4
        const estimatedQuarterlyDepreciation = fiscalYearEnd.depreciation / 4;
        ebitdaData.push({
          period: opIncome.period,
          ebitda: opIncome.operatingIncome + estimatedQuarterlyDepreciation
        });
      } else {
        // If no depreciation data at all, just use operating income
        // (Some companies may not report depreciation separately)
        ebitdaData.push({
          period: opIncome.period,
          ebitda: opIncome.operatingIncome
        });
      }
    }
  }

  return ebitdaData.slice(0, 40);
}

/**
 * Extract TTM EBITDA (last 37 TTM periods)
 * Calculates TTM by summing last 4 quarters for each period
 */
function extractTTMEBITDA(facts) {
  // First get quarterly EBITDA data
  const quarterly = extractEBITDA(facts);
  if (quarterly.length < 4) return [];

  // Calculate TTM for each period (starting from Q4)
  const ttm = [];
  for (let i = 3; i < quarterly.length; i++) {
    const last4Quarters = quarterly.slice(i - 3, i + 1);
    const ttmEBITDA = last4Quarters.reduce((sum, q) => sum + q.ebitda, 0);

    ttm.push({
      period: quarterly[i - 3].period,  // Use most recent quarter (data is descending) period
      ebitda: ttmEBITDA
    });
  }

  return ttm.slice(0, 37);
}

/**
 * Extract quarterly Free Cash Flow (last 40 quarters = 10 years)
 * FCF = Operating Cash Flow - Capital Expenditures
 * Calculates FCF from SEC EDGAR cash flow components
 */
function extractFreeCashFlow(facts) {
  // Get operating cash flow data
  const operatingCashFlowKeys = [
    'NetCashProvidedByUsedInOperatingActivities',
    'CashProvidedByUsedInOperatingActivities'
  ];

  // Collect quarterly operating cash flow data
  const allQuarterly = [];
  const allCumulative = [];

  for (const key of operatingCashFlowKeys) {
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
        // Cumulative year-to-date data
        else if (daysDiff >= 150 && daysDiff <= 380) {
          allCumulative.push(item);
        }
      }
    }
  }

  // Deduplicate quarterly operating cash flow data
  const quarterlyDeduped = allQuarterly
    .filter(item => !item.frame || /Q[1-3]/.test(item.frame))  // Include items without frame, or with Q1-Q3 frames
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
        acc.push({ period: item.end, operatingCashFlow: item.val, start: item.start });
      }
      return acc;
    }, []);

  // Calculate Q2, Q3, Q4 operating cash flow from cumulative data
  const calculated = [];
  for (const annual of allCumulative) {
    const annualStart = annual.start;
    const annualEnd = annual.end;
    const annualDays = (new Date(annualEnd) - new Date(annualStart)) / (1000 * 60 * 60 * 24);

    if (annualDays < 330 || annualDays > 380) continue;

    // Find 9-month, 6-month, and Q1 data for the same fiscal year
    const nineMonth = allCumulative.find(item =>
      item.start === annualStart &&
      item.end < annualEnd &&
      Math.abs((new Date(item.end) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 270) < 30
    );

    const sixMonth = allCumulative.find(item =>
      item.start === annualStart &&
      item.end < annualEnd &&
      Math.abs((new Date(item.end) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 180) < 30
    );

    const q1 = quarterlyDeduped.find(item =>
      item.start === annualStart &&
      Math.abs((new Date(item.period) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 90) < 30
    );

    // Calculate Q4 = Annual - 9-month
    if (nineMonth) {
      const q4OperatingCashFlow = annual.val - nineMonth.val;
      const hasQuarter = quarterlyDeduped.find(x => x.period === annualEnd);
      if (!hasQuarter) {
        calculated.push({ period: annualEnd, operatingCashFlow: q4OperatingCashFlow });
      }
    }

    // Calculate Q3 = 9-month - 6-month
    if (nineMonth && sixMonth) {
      const q3OperatingCashFlow = nineMonth.val - sixMonth.val;
      const hasQuarter = quarterlyDeduped.find(x => x.period === nineMonth.end);
      if (!hasQuarter) {
        calculated.push({ period: nineMonth.end, operatingCashFlow: q3OperatingCashFlow });
      }
    }

    // Calculate Q2 = 6-month - Q1
    if (sixMonth && q1) {
      const q2OperatingCashFlow = sixMonth.val - q1.operatingCashFlow;
      const hasQuarter = quarterlyDeduped.find(x => x.period === sixMonth.end);
      if (!hasQuarter) {
        calculated.push({ period: sixMonth.end, operatingCashFlow: q2OperatingCashFlow });
      }
    }
  }

  // Combine operating cash flow data
  const operatingCashFlowData = [...quarterlyDeduped, ...calculated]
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push(item);
      }
      return acc;
    }, []);

  // Get capital expenditures data
  const capexKeys = [
    'PaymentsToAcquirePropertyPlantAndEquipment',
    'PaymentsForCapitalImprovements'
  ];

  const allCapexQuarterly = [];
  const allCapexCumulative = [];

  for (const key of capexKeys) {
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
          allCapexQuarterly.push(item);
        }
        // Cumulative year-to-date data
        else if (daysDiff >= 150 && daysDiff <= 380) {
          allCapexCumulative.push(item);
        }
      }
    }
  }

  // Deduplicate quarterly capex data
  const capexQuarterlyDeduped = allCapexQuarterly
    .filter(item => !item.frame || /Q[1-3]/.test(item.frame))  // Include items without frame, or with Q1-Q3 frames
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
        acc.push({ period: item.end, capex: item.val, start: item.start });
      }
      return acc;
    }, []);

  // Calculate Q2, Q3, Q4 capex from cumulative data
  const capexCalculated = [];
  for (const annual of allCapexCumulative) {
    const annualStart = annual.start;
    const annualEnd = annual.end;
    const annualDays = (new Date(annualEnd) - new Date(annualStart)) / (1000 * 60 * 60 * 24);

    if (annualDays < 330 || annualDays > 380) continue;

    // Find 9-month, 6-month, and Q1 data for the same fiscal year
    const nineMonth = allCapexCumulative.find(item =>
      item.start === annualStart &&
      item.end < annualEnd &&
      Math.abs((new Date(item.end) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 270) < 30
    );

    const sixMonth = allCapexCumulative.find(item =>
      item.start === annualStart &&
      item.end < annualEnd &&
      Math.abs((new Date(item.end) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 180) < 30
    );

    const q1 = capexQuarterlyDeduped.find(item =>
      item.start === annualStart &&
      Math.abs((new Date(item.period) - new Date(item.start)) / (1000 * 60 * 60 * 24) - 90) < 30
    );

    // Calculate Q4 = Annual - 9-month
    if (nineMonth) {
      const q4Capex = annual.val - nineMonth.val;
      if (q4Capex > 0) {
        const hasQuarter = capexQuarterlyDeduped.find(x => x.period === annualEnd);
        if (!hasQuarter) {
          capexCalculated.push({ period: annualEnd, capex: q4Capex });
        }
      }
    }

    // Calculate Q3 = 9-month - 6-month
    if (nineMonth && sixMonth) {
      const q3Capex = nineMonth.val - sixMonth.val;
      if (q3Capex > 0) {
        const hasQuarter = capexQuarterlyDeduped.find(x => x.period === nineMonth.end);
        if (!hasQuarter) {
          capexCalculated.push({ period: nineMonth.end, capex: q3Capex });
        }
      }
    }

    // Calculate Q2 = 6-month - Q1
    if (sixMonth && q1) {
      const q2Capex = sixMonth.val - q1.capex;
      if (q2Capex > 0) {
        const hasQuarter = capexQuarterlyDeduped.find(x => x.period === sixMonth.end);
        if (!hasQuarter) {
          capexCalculated.push({ period: sixMonth.end, capex: q2Capex });
        }
      }
    }
  }

  // Combine capex data
  const capexData = [...capexQuarterlyDeduped, ...capexCalculated]
    .sort((a, b) => b.period.localeCompare(a.period))
    .reduce((acc, item) => {
      if (!acc.find(x => x.period === item.period)) {
        acc.push(item);
      }
      return acc;
    }, []);

  // Calculate FCF = Operating Cash Flow - Capital Expenditures
  const fcfData = [];
  for (const ocf of operatingCashFlowData) {
    const capex = capexData.find(c => c.period === ocf.period);
    if (capex) {
      fcfData.push({
        period: ocf.period,
        freeCashFlow: ocf.operatingCashFlow - capex.capex
      });
    } else {
      // If no capex data, use OCF as FCF (some companies may not report capex separately)
      fcfData.push({
        period: ocf.period,
        freeCashFlow: ocf.operatingCashFlow
      });
    }
  }

  return fcfData.slice(0, 40);
}

/**
 * Extract TTM Free Cash Flow (last 37 TTM periods)
 * Calculates TTM by summing last 4 quarters for each period
 */
function extractTTMFreeCashFlow(facts) {
  // First get quarterly FCF data
  const quarterly = extractFreeCashFlow(facts);
  if (quarterly.length < 4) return [];

  // Calculate TTM for each period (starting from Q4)
  const ttm = [];
  for (let i = 3; i < quarterly.length; i++) {
    const last4Quarters = quarterly.slice(i - 3, i + 1);
    const ttmFCF = last4Quarters.reduce((sum, q) => sum + q.freeCashFlow, 0);

    ttm.push({
      period: quarterly[i - 3].period,  // Use most recent quarter (data is descending) period
      freeCashFlow: ttmFCF
    });
  }

  return ttm.slice(0, 37);
}

/**
 * Extract Net Margin (last 40 quarters)
 * Net Margin = (Net Income / Revenue) × 100
 * Returns percentage values
 */
function extractNetMargin(facts) {
  // Get quarterly earnings (net income) and revenue data
  const earningsData = extractEarnings(facts);
  const revenueData = extractRevenue(facts);

  // Calculate net margin for each period where we have both values
  const netMarginData = [];
  for (const earnings of earningsData) {
    const revenue = revenueData.find(r => r.period === earnings.period);
    if (revenue && revenue.revenue > 0) {
      const netMargin = (earnings.earnings / revenue.revenue) * 100;
      netMarginData.push({
        period: earnings.period,
        netMargin: netMargin
      });
    }
  }

  return netMarginData.slice(0, 40);
}

/**
 * Extract Operating Margin (last 40 quarters)
 * Operating Margin = (Operating Income / Revenue) × 100
 * Returns percentage values
 */
function extractOperatingMargin(facts) {
  // Get quarterly operating income and revenue data
  const operatingIncomeData = extractOperatingIncome(facts);
  const revenueData = extractRevenue(facts);

  // Calculate operating margin for each period where we have both values
  const operatingMarginData = [];
  for (const opIncome of operatingIncomeData) {
    const revenue = revenueData.find(r => r.period === opIncome.period);
    if (revenue && revenue.revenue > 0) {
      const operatingMargin = (opIncome.operatingIncome / revenue.revenue) * 100;
      operatingMarginData.push({
        period: opIncome.period,
        operatingMargin: operatingMargin
      });
    }
  }

  return operatingMarginData.slice(0, 40);
}

/**
 * Extract TTM Net Margin (last 37 TTM periods)
 * TTM Net Margin = (TTM Net Income / TTM Revenue) × 100
 * Returns percentage values
 */
function extractTTMNetMargin(facts) {
  // Get TTM earnings and revenue data
  const ttmEarningsData = extractTTMEarnings(facts);
  const ttmRevenueData = extractTTMRevenue(facts);

  // Calculate TTM net margin for each period where we have both values
  const ttmNetMarginData = [];
  for (const earnings of ttmEarningsData) {
    const revenue = ttmRevenueData.find(r => r.period === earnings.period);
    if (revenue && revenue.revenue > 0) {
      const netMargin = (earnings.earnings / revenue.revenue) * 100;
      ttmNetMarginData.push({
        period: earnings.period,
        netMargin: netMargin
      });
    }
  }

  return ttmNetMarginData.slice(0, 37);
}

/**
 * Extract TTM Operating Margin (last 37 TTM periods)
 * TTM Operating Margin = (TTM Operating Income / TTM Revenue) × 100
 * Returns percentage values
 */
function extractTTMOperatingMargin(facts) {
  // Get TTM operating income and revenue data
  const ttmOperatingIncomeData = extractTTMOperatingIncome(facts);
  const ttmRevenueData = extractTTMRevenue(facts);

  // Calculate TTM operating margin for each period where we have both values
  const ttmOperatingMarginData = [];
  for (const opIncome of ttmOperatingIncomeData) {
    const revenue = ttmRevenueData.find(r => r.period === opIncome.period);
    if (revenue && revenue.revenue > 0) {
      const operatingMargin = (opIncome.operatingIncome / revenue.revenue) * 100;
      ttmOperatingMarginData.push({
        period: opIncome.period,
        operatingMargin: operatingMargin
      });
    }
  }

  return ttmOperatingMarginData.slice(0, 37);
}

/**
 * Extract TTM Gross Margin (last 37 TTM periods)
 * TTM Gross Margin = (TTM Gross Profit / TTM Revenue) × 100
 * Returns percentage values
 */
function extractTTMGrossMargin(facts) {
  // Get TTM gross profit and revenue data
  const ttmGrossProfitData = extractTTMGrossProfit(facts);
  const ttmRevenueData = extractTTMRevenue(facts);

  // Calculate TTM gross margin for each period where we have both values
  const ttmGrossMarginData = [];
  for (const grossProfit of ttmGrossProfitData) {
    const revenue = ttmRevenueData.find(r => r.period === grossProfit.period);
    if (revenue && revenue.revenue > 0) {
      const grossMargin = (grossProfit.grossProfit / revenue.revenue) * 100;
      ttmGrossMarginData.push({
        period: grossProfit.period,
        grossMargin: grossMargin
      });
    }
  }

  return ttmGrossMarginData.slice(0, 37);
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

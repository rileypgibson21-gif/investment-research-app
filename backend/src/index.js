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
      } else if (url.pathname.startsWith('/api/shares-outstanding-ttm/')) {
        return await handleTTMSharesOutstanding(request, env, url);
      } else if (url.pathname.startsWith('/api/shares-outstanding/')) {
        return await handleSharesOutstanding(request, env, url);
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
 * Handle quarterly shares outstanding from SEC EDGAR
 * GET /api/shares-outstanding/:symbol
 */
async function handleSharesOutstanding(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const sharesOutstanding = extractSharesOutstanding(facts);
    return jsonResponse(sharesOutstanding);
  } catch (error) {
    return jsonResponse({ error: error.message }, 404);
  }
}

/**
 * Handle TTM shares outstanding from SEC EDGAR
 * GET /api/shares-outstanding-ttm/:symbol
 */
async function handleTTMSharesOutstanding(request, env, url) {
  const symbol = url.pathname.split('/').pop().toUpperCase();
  if (!symbol) {
    return jsonResponse({ error: 'Symbol required' }, 400);
  }

  try {
    const facts = await getCompanyFacts(symbol, env);
    const sharesOutstanding = extractTTMSharesOutstanding(facts);
    return jsonResponse(sharesOutstanding);
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
      period: quarterly[i - 3].period,  // Use most recent quarter, not oldest
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
      period: quarterly[i - 3].period,  // Use most recent quarter, not oldest
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
 * Extract quarterly shares outstanding from SEC EDGAR data
 * Returns last 40 quarters of weighted average shares outstanding
 */
function extractSharesOutstanding(facts) {
  // Prioritize diluted shares, then instant measurements, then basic
  const sharesKeys = [
    'WeightedAverageNumberOfDilutedSharesOutstanding',
    'CommonStockSharesOutstanding',
    'WeightedAverageNumberOfSharesOutstandingBasic'
  ];

  // Collect quarterly data from all available keys
  const allQuarterly = [];

  for (const key of sharesKeys) {
    if (facts.facts['us-gaap'] && facts.facts['us-gaap'][key]) {
      const units = facts.facts['us-gaap'][key].units?.shares;
      if (!units) continue;

      for (const item of units) {
        if (!item.val || item.val <= 0 || !item.end) continue;

        // For shares outstanding, look for quarterly reports
        // Weighted average shares are typically quarterly (with start/end)
        // Point-in-time shares may only have end date
        if (item.start) {
          const startDate = new Date(item.start);
          const endDate = new Date(item.end);
          const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);

          // Quarterly data (70-120 days)
          if (daysDiff >= 70 && daysDiff <= 120) {
            allQuarterly.push(item);
          }
        } else {
          // Point-in-time measurement (like CommonStockSharesOutstanding)
          // These typically represent quarter-end values
          allQuarterly.push(item);
        }
      }
    }
  }

  // Group by period end date, keeping all candidates per period
  const byPeriod = {};
  for (const item of allQuarterly) {
    // Check if this is quarterly data using frame (if available) or fiscal period
    let isQuarterly = false;
    let isInstant = false;
    let isAnnual = false;

    if (item.frame) {
      // Use frame if available
      isQuarterly = /Q[1-4]/.test(item.frame);
      isInstant = item.frame.endsWith('I');
      isAnnual = /CY\d{4}$/.test(item.frame);
    } else if (item.fp) {
      // Fallback to fiscal period (fp) if frame not available
      // fp values: Q1, Q2, Q3, Q4, FY
      isQuarterly = /^Q[1-4]$/.test(item.fp);
      isAnnual = item.fp === 'FY';
    } else if (item.form) {
      // Last fallback: use form type
      isQuarterly = item.form === '10-Q';
      isAnnual = item.form === '10-K';
    }

    // Skip if not quarterly, instant, or annual
    if (!isQuarterly && !isInstant && !isAnnual) continue;

    // For quarterly data, verify period duration if we have start/end dates
    if (item.start && !isInstant && !isAnnual) {
      const startDate = new Date(item.start);
      const endDate = new Date(item.end);
      const daysDiff = (endDate - startDate) / (1000 * 60 * 60 * 24);
      // Skip if not quarterly period (70-120 days)
      if (daysDiff < 70 || daysDiff > 120) continue;
    }

    if (!byPeriod[item.end]) byPeriod[item.end] = [];
    byPeriod[item.end].push(item);
  }

  // For each period, select the best value
  const quarterlyDeduped = Object.keys(byPeriod)
    .sort((a, b) => b.localeCompare(a)) // Sort periods descending
    .map(period => {
      const candidates = byPeriod[period];

      // Sort candidates: prefer larger values (split-adjusted), then weighted averages, then later filings
      candidates.sort((a, b) => {
        // Prefer larger values (split-adjusted data)
        if (a.val !== b.val) return b.val - a.val;

        // Prefer weighted average periods over instant measurements (more accurate for quarterly data)
        const aIsInstant = a.frame && a.frame.endsWith('I');
        const bIsInstant = b.frame && b.frame.endsWith('I');
        const aHasPeriod = a.start != null;
        const bHasPeriod = b.start != null;

        // Prefer items with periods (weighted averages) over instant measurements
        if (aHasPeriod && !bHasPeriod && !bIsInstant) return -1;
        if (!aHasPeriod && bHasPeriod && !aIsInstant) return 1;

        // Prefer later filing dates (newer filings often have split-adjusted data)
        if (a.filed && b.filed && a.filed !== b.filed) {
          return b.filed.localeCompare(a.filed);
        }

        // Prefer amended filings
        const aIsAmended = a.form && a.form.includes('/A');
        const bIsAmended = b.form && b.form.includes('/A');
        if (aIsAmended && !bIsAmended) return -1;
        if (!aIsAmended && bIsAmended) return 1;

        return 0;
      });

      return { period: period, sharesOutstanding: candidates[0].val };
    });

  // Apply stock split adjustments
  const adjusted = adjustForStockSplits(quarterlyDeduped);

  return adjusted.slice(0, 40);
}

/**
 * Detect and adjust for stock splits in shares outstanding data
 * Works backwards from newest data to detect and adjust historical splits
 */
function adjustForStockSplits(data) {
  if (data.length < 2) return data;

  // Sort by period descending (newest first) for processing
  const sorted = [...data].sort((a, b) => b.period.localeCompare(a.period));

  // Track cumulative split ratio (starts at 1.0)
  let cumulativeSplitRatio = 1.0;
  const adjusted = [];

  for (let i = 0; i < sorted.length; i++) {
    const current = sorted[i];

    // Apply current cumulative ratio (for periods before any detected splits)
    adjusted.push({
      period: current.period,
      sharesOutstanding: current.sharesOutstanding * cumulativeSplitRatio
    });

    // Check if there's a split between this period and the previous (older) one
    if (i < sorted.length - 1) {
      const previous = sorted[i + 1]; // Older period
      const ratio = current.sharesOutstanding / previous.sharesOutstanding;

      // Detect split going backwards: current shares are significantly higher than previous
      // This means a split happened, and we need to adjust older data
      if (ratio >= 1.5 && ratio <= 10) {
        // Round to nearest common split ratio (2, 3, 4, 5, 7, 10)
        const commonRatios = [2, 3, 4, 5, 7, 10];
        let detectedRatio = ratio;

        for (const commonRatio of commonRatios) {
          if (Math.abs(ratio - commonRatio) < 0.3) {
            detectedRatio = commonRatio;
            break;
          }
        }

        // Accumulate the ratio for older periods
        cumulativeSplitRatio *= detectedRatio;
      }
    }
  }

  // Return in original order (newest first)
  return adjusted;
}

/**
 * Extract TTM shares outstanding (last 37 periods)
 * For shares outstanding, TTM is simply the average of the last 4 quarters
 */
function extractTTMSharesOutstanding(facts) {
  // First get quarterly data
  const quarterly = extractSharesOutstanding(facts);
  if (quarterly.length < 4) return [];

  // Calculate TTM average for each period
  const ttm = [];
  for (let i = 3; i < quarterly.length; i++) {
    const last4Quarters = quarterly.slice(i - 3, i + 1);
    const avgShares = last4Quarters.reduce((sum, q) => sum + q.sharesOutstanding, 0) / 4;

    ttm.push({
      period: quarterly[i - 3].period,  // Use most recent quarter
      sharesOutstanding: avgShares
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

import Foundation

// MARK: - SEC EDGAR API Service (via Cloudflare Workers with caching)
class SECAPIService {
    // Use backend API with caching to support 1000s of users
    private let baseURL = "https://my-stock-api.stock-research-api.workers.dev"
    
    // MARK: - Get Company CIK from Ticker
    func getCIK(for ticker: String) async throws -> String {
        // Use cached backend endpoint
        let tickersURL = URL(string: "\(baseURL)/api/sec/tickers")!

        let request = URLRequest(url: tickersURL)

        let (data, _) = try await URLSession.shared.data(for: request)
        let tickers = try JSONDecoder().decode([String: CompanyTicker].self, from: data)
        
        // Find matching ticker
        for (_, company) in tickers {
            if company.ticker.uppercased() == ticker.uppercased() {
                // CIK needs to be padded to 10 digits
                return String(format: "%010d", company.cik_str)
            }
        }
        
        throw SECError.companyNotFound
    }
    
    // MARK: - Get Company Facts (All Financial Data)
    func getCompanyFacts(cik: String) async throws -> CompanyFacts {
        // Use cached backend endpoint
        let urlString = "\(baseURL)/api/sec/facts/\(cik)"
        guard let url = URL(string: urlString) else {
            throw SECError.invalidURL
        }

        let request = URLRequest(url: url)

        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Use a decoder that handles null values
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        do {
            return try decoder.decode(CompanyFacts.self, from: data)
        } catch {
            print("❌ Decoding error: \(error)")
            throw SECError.invalidResponse
        }
    }
    
    // MARK: - Get Company Submissions (Filings List)
    func getCompanySubmissions(cik: String) async throws -> CompanySubmissions {
        // Use cached backend endpoint
        let urlString = "\(baseURL)/api/sec/submissions/\(cik)"
        guard let url = URL(string: urlString) else {
            throw SECError.invalidURL
        }

        let request = URLRequest(url: url)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(CompanySubmissions.self, from: data)
    }
    
    // MARK: - Extract Revenue Data (Quarterly + TTM)
    func extractRevenueData(from facts: CompanyFacts) -> [RevenueDataPoint] {
        var revenuePoints: [RevenueDataPoint] = []
        
        // Try different revenue keys (companies use different XBRL tags)
        let revenueKeys = [
            "Revenues",
            "RevenueFromContractWithCustomerExcludingAssessedTax",
            "SalesRevenueNet",
            "RevenueFromContractWithCustomer",
            "SalesRevenueGoodsNet"
        ]
        
        guard let usGaap = facts.facts.us_gaap else {
            print("⚠️ No us-gaap facts found")
            return []
        }
        
        for key in revenueKeys {
            guard let revenueFact = usGaap[key] else {
                continue
            }
            
            print("📊 Found revenue data under key: \(key)")
            
            // Get quarterly data (10-Q filings)
            guard let units = revenueFact.units["USD"] else {
                print("⚠️ No USD units found for \(key)")
                continue
            }
            
            // Filter for 10-Q (quarterly) filings only
            let quarterlyData = units.filter { $0.form == "10-Q" }
                .sorted { $0.end > $1.end }
            
            print("✓ Found \(quarterlyData.count) quarterly data points")
            
            // Return individual quarterly revenues (not TTM sums)
            var processedPeriods = Set<String>()
            
            for dataPoint in quarterlyData.prefix(12) {
                let endDate = dataPoint.end
                
                // Skip if we've already processed this period
                if processedPeriods.contains(endDate) {
                    continue
                }
                
                if dataPoint.val > 0 {
                    revenuePoints.append(RevenueDataPoint(
                        period: endDate,
                        revenue: dataPoint.val
                    ))
                    processedPeriods.insert(endDate)
                }
            }
            
            // If we found data, return it
            if !revenuePoints.isEmpty {
                print("✅ Successfully extracted \(revenuePoints.count) quarterly revenue points")
                return revenuePoints.sorted { $0.period < $1.period }
            }
        }
        
        print("⚠️ No revenue data found for any known keys")
        return []
    }
    
    // MARK: - Extract Key Metrics
    func extractKeyMetrics(from facts: CompanyFacts, submissions: CompanySubmissions) -> CompanyMetrics {
        var metrics = CompanyMetrics(
            week52High: nil,
            week52Low: nil,
            marketCap: nil,
            peRatio: nil,
            beta: nil,
            dividendYield: nil
        )
        
        // Extract market cap from EntityPublicFloat
        if let publicFloat = facts.facts.dei?["EntityPublicFloat"],
           let units = publicFloat.units["USD"],
           let latest = units.sorted(by: { $0.end > $1.end }).first {
            metrics.marketCap = latest.val
        }

        return metrics
    }
    
    // MARK: - Get Basic Stock Quote (from company name and last filing)
    func getBasicInfo(ticker: String) async throws -> StockBasicInfo {
        let cik = try await getCIK(for: ticker)
        let submissions = try await getCompanySubmissions(cik: cik)
        
        return StockBasicInfo(
            ticker: ticker,
            name: submissions.name,
            cik: cik,
            sic: submissions.sic,
            sicDescription: submissions.sicDescription,
            fiscalYearEnd: submissions.fiscalYearEnd
        )
    }
}

// MARK: - SEC Data Models

struct CompanyTicker: Codable {
    let cik_str: Int
    let ticker: String
    let title: String
}

struct CompanyFacts: Codable {
    let cik: Int
    let entityName: String
    let facts: Facts
}

struct Facts: Codable {
    let dei: [String: Fact]?
    let us_gaap: [String: Fact]?
    
    enum CodingKeys: String, CodingKey {
        case dei
        case us_gaap = "us-gaap"
    }
}

struct Fact: Codable {
    let label: String?
    let description: String?
    let units: [String: [FactValue]]
}

struct FactValue: Codable {
    let end: String
    let val: Double
    let accn: String
    let fy: Int?
    let fp: String?
    let form: String
    let filed: String
    let frame: String?
}

struct CompanySubmissions: Codable {
    let cik: String
    let entityType: String
    let sic: String
    let sicDescription: String
    let name: String
    let tickers: [String]
    let exchanges: [String]
    let ein: String?
    let description: String?
    let website: String?
    let category: String
    let fiscalYearEnd: String
    let stateOfIncorporation: String?
    let phone: String?
    let filings: Filings
}

struct Filings: Codable {
    let recent: RecentFilings
}

struct RecentFilings: Codable {
    let accessionNumber: [String]
    let filingDate: [String]
    let reportDate: [String]
    let acceptanceDateTime: [String]
    let act: [String]
    let form: [String]
    let fileNumber: [String]
    let filmNumber: [String]
    let items: [String]
    let size: [Int]
    let isXBRL: [Int]
    let isInlineXBRL: [Int]
    let primaryDocument: [String]
    let primaryDocDescription: [String]
}

struct StockBasicInfo {
    let ticker: String
    let name: String
    let cik: String
    let sic: String
    let sicDescription: String
    let fiscalYearEnd: String
}

enum SECError: Error {
    case invalidURL
    case companyNotFound
    case noData
    case invalidResponse
}

//
//  AuthenticationService.swift
//  Test App
//
//  Created by Claude Code
//

import Foundation
import Security
import UIKit
import Combine

// MARK: - Authentication Service
@MainActor
class AuthenticationService: ObservableObject {

    static let shared = AuthenticationService()

    @Published var isAuthenticated: Bool = false
    @Published var apiKey: String?

    private let apiBaseURL = "https://my-stock-api.stock-research-api.workers.dev"
    private let keychainService = "com.yourapp.stockresearch"
    private let apiKeyAccount = "api-key"
    private let deviceIdKey = "device-id"

    private init() {
        // Load API key from keychain on init
        self.apiKey = loadAPIKeyFromKeychain()
        self.isAuthenticated = (apiKey != nil)
    }

    // MARK: - Device ID

    /// Get unique device identifier
    func getDeviceID() -> String {
        // First, check if we have a stored device ID
        if let stored = UserDefaults.standard.string(forKey: deviceIdKey) {
            return stored
        }

        // Generate new device ID
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        // Store for future use
        UserDefaults.standard.set(deviceId, forKey: deviceIdKey)

        return deviceId
    }

    // MARK: - API Key Management

    /// Register device and get API key (call this when user subscribes)
    func registerDevice() async throws {
        let deviceId = getDeviceID()

        let url = URL(string: "\(apiBaseURL)/api/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["deviceId": deviceId]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            throw AuthError.registrationFailed
        }

        let result = try JSONDecoder().decode(RegistrationResponse.self, from: data)

        // Save API key to keychain
        try saveAPIKeyToKeychain(result.apiKey)

        // Update state
        self.apiKey = result.apiKey
        self.isAuthenticated = true

        print("✅ Device registered successfully. User ID: \(result.userId)")
    }

    /// Create authenticated URLRequest with API key headers
    func createAuthenticatedRequest(url: URL) throws -> URLRequest {
        guard let apiKey = self.apiKey else {
            throw AuthError.noAPIKey
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue(getDeviceID(), forHTTPHeaderField: "X-Device-ID")

        return request
    }

    /// Clear API key (when user unsubscribes or logs out)
    func clearAuthentication() {
        deleteAPIKeyFromKeychain()
        self.apiKey = nil
        self.isAuthenticated = false
    }

    // MARK: - Keychain Operations

    private func saveAPIKeyToKeychain(_ apiKey: String) throws {
        // Delete existing key first
        deleteAPIKeyFromKeychain()

        guard let data = apiKey.data(using: .utf8) else {
            throw AuthError.keychainError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            throw AuthError.keychainError
        }
    }

    private func loadAPIKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        }

        return nil
    }

    private func deleteAPIKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyAccount
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Models

struct RegistrationResponse: Codable {
    let success: Bool
    let apiKey: String
    let userId: String
    let message: String
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case registrationFailed
    case keychainError
    case networkError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key found. Please subscribe to access this feature."
        case .invalidResponse:
            return "Invalid response from server."
        case .registrationFailed:
            return "Failed to register device. Please try again."
        case .keychainError:
            return "Failed to save credentials securely."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}

// MARK: - Extension for StockAPIService

extension StockAPIService {
    /// Create authenticated request for API calls
    private func createAuthenticatedRequest(path: String) async throws -> URLRequest {
        let apiBaseURL = "https://my-stock-api.stock-research-api.workers.dev"
        let urlString = "\(apiBaseURL)\(path)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        // Get authenticated request from AuthenticationService
        return try AuthenticationService.shared.createAuthenticatedRequest(url: url)
    }

    /// Fetch revenue with authentication
    func fetchRevenueAuthenticated(symbol: String) async throws -> [RevenueDataPoint] {
        let request = try await createAuthenticatedRequest(path: "/api/revenue/\(symbol.uppercased())")

        let (data, response) = try await URLSession.shared.data(for: request)

        // Handle authentication errors
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 401:
                throw AuthError.noAPIKey
            case 429:
                throw APIError.rateLimitExceeded
            case 402:
                throw APIError.subscriptionRequired
            default:
                break
            }
        }

        struct APIRevenueResponse: Codable {
            let period: String
            let revenue: Double
        }

        let revenueData = try JSONDecoder().decode([APIRevenueResponse].self, from: data)
        return revenueData.map { RevenueDataPoint(period: $0.period, revenue: $0.revenue) }
    }

    /// Fetch TTM revenue with authentication
    func fetchTTMRevenueAuthenticated(symbol: String) async throws -> [RevenueDataPoint] {
        let request = try await createAuthenticatedRequest(path: "/api/revenue-ttm/\(symbol.uppercased())")

        let (data, response) = try await URLSession.shared.data(for: request)

        // Handle authentication errors
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 401:
                throw AuthError.noAPIKey
            case 429:
                throw APIError.rateLimitExceeded
            case 402:
                throw APIError.subscriptionRequired
            default:
                break
            }
        }

        struct APIRevenueResponse: Codable {
            let period: String
            let revenue: Double
        }

        let revenueData = try JSONDecoder().decode([APIRevenueResponse].self, from: data)
        return revenueData.map { RevenueDataPoint(period: $0.period, revenue: $0.revenue) }
    }

    /// Fetch profile with authentication
    func searchStockAuthenticated(symbol: String) async throws -> StockProfile {
        let request = try await createAuthenticatedRequest(path: "/api/profile/\(symbol.uppercased())")

        let (data, response) = try await URLSession.shared.data(for: request)

        // Handle authentication errors
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 401:
                throw AuthError.noAPIKey
            case 429:
                throw APIError.rateLimitExceeded
            case 402:
                throw APIError.subscriptionRequired
            default:
                break
            }
        }

        return try JSONDecoder().decode(StockProfile.self, from: data)
    }
}

// MARK: - Additional API Errors

extension APIError {
    static let rateLimitExceeded = APIError.noData // Reuse or create specific
    static let subscriptionRequired = APIError.noData // Reuse or create specific
}

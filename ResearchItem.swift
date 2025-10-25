//
//  ResearchItem.swift
//  Test App
//
//  Created by Riley Gibson on 10/19/25.
//


import Foundation
import SwiftData

@Model
@MainActor
class ResearchItem {
    var symbol: String
    var name: String
    var currentPrice: Double
    var priceChange: Double
    var priceChangePercent: Double
    var marketCap: Double?
    var peRatio: Double?
    var dividendYield: Double?
    var week52High: Double?
    var week52Low: Double?
    var volume: Int?
    var notes: String
    var rating: Int
    var tags: [String]
    var isWatchlist: Bool
    var dateAdded: Date
    var lastUpdated: Date
    
    init(symbol: String, name: String, currentPrice: Double, priceChange: Double = 0, priceChangePercent: Double = 0) {
        self.symbol = symbol
        self.name = name
        self.currentPrice = currentPrice
        self.priceChange = priceChange
        self.priceChangePercent = priceChangePercent
        self.notes = ""
        self.rating = 0
        self.tags = []
        self.isWatchlist = false
        self.dateAdded = Date()
        self.lastUpdated = Date()
    }
    
    var priceFromHigh: Double? {
        guard let high = week52High, high > 0 else { return nil }
        return ((currentPrice - high) / high) * 100
    }
    
    var priceFromLow: Double? {
        guard let low = week52Low, low > 0 else { return nil }
        return ((currentPrice - low) / low) * 100
    }
}

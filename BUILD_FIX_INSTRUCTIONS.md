# How to Fix Slow Builds & Compiler Timeouts

## Problem
- ContentView.swift is 3784 lines with complex SwiftUI views
- Compiler times out trying to type-check complex chart expressions
- Swift 6 concurrency warnings

## Quick Fixes

### 1. Disable Swift 6 Strict Concurrency (FASTEST FIX)
In Xcode:
1. Select project "Test App" in navigator
2. Select "Test App" target
3. Go to "Build Settings"
4. Search for "Strict Concurrency"
5. Set to **"Minimal"** or **"Complete" → "Minimal"**

This will eliminate the ResearchItem concurrency errors immediately.

### 2. Increase Type-Checking Timeout
In Xcode Build Settings:
1. Search for "Other Swift Flags"
2. Add: `-Xfrontend -warn-long-expression-type-checking=500`
3. Add: `-Xfrontend -warn-long-function-bodies=500`

This gives the compiler more time (500ms instead of default 100ms).

### 3. Split ContentView.swift (BEST LONG-TERM FIX)
Extract these structs into separate files:
- `YoYGrowthChartView` → YoYGrowthChartView.swift
- `EarningsChartView` → EarningsChartView.swift  
- `TTMEarningsChartView` → TTMEarningsChartView.swift
- `YoYEarningsGrowthChartView` → YoYEarningsGrowthChartView.swift

Each file compiles independently = Much faster!

## Already Fixed
✅ SubscriptionManager infinite recursion (removed duplicate properties)
✅ FinancialChartView warning (changed `var` to `let`)

## Current Status
- ResearchItem: Added `nonisolated` but still has Swift 6 warnings
- Chart views: Still timing out - need Xcode settings changed

## Next Steps
1. Apply "Quick Fix #1" above (takes 30 seconds)
2. Try building
3. If still slow, apply "Quick Fix #2"
4. For best performance long-term, do "Quick Fix #3"

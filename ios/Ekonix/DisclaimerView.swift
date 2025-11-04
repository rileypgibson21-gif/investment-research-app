//
//  DisclaimerView.swift
//  Ekonix
//
//  Created by Claude Code
//

import SwiftUI

struct DisclaimerView: View {
    @Binding var hasAcceptedDisclaimer: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                        .padding(.top, 60)

                    Text("Important Disclaimer")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 32)

                // Scrollable disclaimer content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        DisclaimerSection(
                            title: "For Research & Educational Purposes Only",
                            content: "This application is designed for research and educational purposes only. The information provided does not constitute investment advice, financial advice, trading advice, or any other type of advice."
                        )

                        DisclaimerSection(
                            title: "Not Professional Advice",
                            content: "You should not rely on this information as a substitute for, nor does it replace, professional financial advice, due diligence, or consultation with a qualified financial professional."
                        )

                        DisclaimerSection(
                            title: "Data Source",
                            content: "All data is sourced from the U.S. Securities and Exchange Commission (SEC) public filings. While we strive for accuracy, we make no representations or warranties regarding the completeness, accuracy, or reliability of the information."
                        )

                        DisclaimerSection(
                            title: "Investment Risks",
                            content: "Past performance is not indicative of future results. Investing in securities involves risk of loss, including potential loss of principal."
                        )

                        DisclaimerSection(
                            title: "Your Responsibility",
                            content: "By using this app, you acknowledge that you understand these risks and agree to make your own investment decisions. Always conduct your own research and consult with financial professionals before making investment decisions."
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }

                Spacer()
            }

            // Bottom button overlay
            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        hasAcceptedDisclaimer = true
                    }) {
                        Text("I Understand & Accept")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        // Exit the app
                        exit(0)
                    }) {
                        Text("Decline & Exit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .systemBackground).opacity(0),
                            Color(uiColor: .systemBackground),
                            Color(uiColor: .systemBackground)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .interactiveDismissDisabled()
    }
}

struct DisclaimerSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    DisclaimerView(hasAcceptedDisclaimer: .constant(false))
}

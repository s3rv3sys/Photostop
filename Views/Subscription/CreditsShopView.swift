//
//  CreditsShopView.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI
import StoreKit

/// View for purchasing consumable premium credits
struct CreditsShopView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()
    @ObservedObject private var storeKit = StoreKitService.shared
    
    @State private var showingPaywall = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Current Credits
                    currentCreditsSection
                    
                    // Credit Packages
                    creditPackagesSection
                    
                    // Subscription Upsell
                    subscriptionUpsellSection
                    
                    // FAQ Section
                    faqSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Buy Credits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await storeKit.loadProducts()
            }
        }
        .onChange(of: viewModel.purchaseSuccess) { success in
            if success {
                // Show success feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Auto-dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
        .alert("Purchase Error", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error occurred")
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(context: .general)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            
            Text("Premium AI Credits")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Get extra credits for premium AI enhancements when you need them most")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Current Credits Section
    
    private var currentCreditsSection: some View {
        VStack(spacing: 16) {
            Text("Your Credits")
                .font(.headline)
            
            HStack(spacing: 20) {
                // Subscription Credits
                CreditDisplay(
                    title: "Monthly Allowance",
                    count: viewModel.usageStats.premiumRemaining,
                    color: .blue,
                    icon: "calendar"
                )
                
                // Bonus Credits
                CreditDisplay(
                    title: "Bonus Credits",
                    count: viewModel.addonPremiumCredits,
                    color: .green,
                    icon: "plus.circle.fill"
                )
            }
            
            Text("Total: \(viewModel.totalPremiumCredits) premium credits available")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // MARK: - Credit Packages Section
    
    private var creditPackagesSection: some View {
        VStack(spacing: 16) {
            Text("Buy More Credits")
                .font(.headline)
            
            VStack(spacing: 12) {
                // 10 Credits Package
                CreditPackageCard(
                    title: "10 Premium Credits",
                    subtitle: "Perfect for a few special edits",
                    price: viewModel.credits10Product?.displayPrice ?? "$2.99",
                    credits: 10,
                    pricePerCredit: calculatePricePerCredit(product: viewModel.credits10Product, credits: 10),
                    isLoading: storeKit.isLoading,
                    isPurchasing: viewModel.isPurchasing
                ) {
                    Task {
                        await viewModel.purchaseCredits(.credits10)
                    }
                }
                
                // 50 Credits Package
                CreditPackageCard(
                    title: "50 Premium Credits",
                    subtitle: "Great value for power users",
                    price: viewModel.credits50Product?.displayPrice ?? "$9.99",
                    credits: 50,
                    pricePerCredit: calculatePricePerCredit(product: viewModel.credits50Product, credits: 50),
                    isLoading: storeKit.isLoading,
                    isPurchasing: viewModel.isPurchasing,
                    badge: "BEST VALUE"
                ) {
                    Task {
                        await viewModel.purchaseCredits(.credits50)
                    }
                }
            }
        }
    }
    
    // MARK: - Subscription Upsell Section
    
    private var subscriptionUpsellSection: some View {
        VStack(spacing: 16) {
            Text("Want Unlimited Credits?")
                .font(.headline)
            
            VStack(spacing: 12) {
                Text("PhotoStop Pro includes 300 premium credits every month, plus unlimited budget AI edits!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Upgrade to Pro") {
                    showingPaywall = true
                }
                .buttonStyle(ProUpgradeButtonStyle())
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
    }
    
    // MARK: - FAQ Section
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Frequently Asked Questions")
                .font(.headline)
            
            VStack(spacing: 12) {
                FAQItem(
                    question: "What are Premium AI Credits?",
                    answer: "Premium credits are used for high-quality AI enhancements using advanced models like Gemini 2.5 Flash Image."
                )
                
                FAQItem(
                    question: "Do credits expire?",
                    answer: "Purchased credits never expire! Your monthly subscription allowance resets each month."
                )
                
                FAQItem(
                    question: "Can I get a refund?",
                    answer: "Refunds are handled through the App Store. Contact Apple Support for assistance with refund requests."
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculatePricePerCredit(product: Product?, credits: Int) -> String {
        guard let product = product, credits > 0 else { return "$0.00" }
        
        let pricePerCredit = product.price / Decimal(credits)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        
        return formatter.string(from: pricePerCredit as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Supporting Views

private struct CreditDisplay: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CreditPackageCard: View {
    let title: String
    let subtitle: String
    let price: String
    let credits: Int
    let pricePerCredit: String
    let isLoading: Bool
    let isPurchasing: Bool
    let badge: String?
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String,
        price: String,
        credits: Int,
        pricePerCredit: String,
        isLoading: Bool,
        isPurchasing: Bool,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.price = price
        self.credits = credits
        self.pricePerCredit = pricePerCredit
        self.isLoading = isLoading
        self.isPurchasing = isPurchasing
        self.badge = badge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if isLoading {
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        HStack {
                            Text(price)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("(\(pricePerCredit) each)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack {
                    if isPurchasing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Text("\(credits)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(UIColor.separator))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading || isPurchasing)
    }
}

private struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

private struct ProUpgradeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    CreditsShopView()
}


//
//  ManageSubscriptionView.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI
import StoreKit

/// View for managing existing subscriptions and viewing usage
struct ManageSubscriptionView: View {
    @ObservedObject private var storeKit = StoreKitService.shared
    @ObservedObject private var viewModel = SubscriptionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingPaywall = false
    @State private var showingCreditsShop = false
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            List {
                // Current Plan Section
                currentPlanSection
                
                // Usage Section
                usageSection
                
                // Credits Section
                if viewModel.addonPremiumCredits > 0 {
                    creditsSection
                }
                
                // Actions Section
                actionsSection
                
                // Support Section
                supportSection
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await refreshSubscriptionData()
            }
        }
        .onAppear {
            Task {
                await storeKit.loadProducts()
                await storeKit.refreshSubscriptionStatus()
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(context: .general)
        }
        .sheet(isPresented: $showingCreditsShop) {
            CreditsShopView()
        }
    }
    
    // MARK: - Current Plan Section
    
    private var currentPlanSection: some View {
        Section("Current Plan") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.subscriptionStatus.displayName)
                        .font(.headline)
                    
                    Text(planDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.hasActiveSubscription {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                }
            }
            .padding(.vertical, 4)
            
            if !viewModel.hasActiveSubscription {
                Button("Upgrade to Pro") {
                    showingPaywall = true
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Usage Section
    
    private var usageSection: some View {
        Section("Usage This Month") {
            let stats = viewModel.usageStats
            
            // Budget AI Usage
            UsageRow(
                title: "Budget AI Edits",
                used: stats.budget,
                remaining: stats.budgetRemaining,
                total: stats.budget + stats.budgetRemaining,
                color: .blue
            )
            
            // Premium AI Usage
            UsageRow(
                title: "Premium AI Credits",
                used: stats.premium,
                remaining: stats.premiumRemaining,
                total: stats.premium + stats.premiumRemaining,
                color: .purple
            )
            
            // Reset date
            Text("Usage resets on \(nextResetDate)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Credits Section
    
    private var creditsSection: some View {
        Section("Bonus Credits") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Premium Credits")
                        .font(.subheadline)
                    
                    Text("From credit purchases")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(viewModel.addonPremiumCredits)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .padding(.vertical, 4)
            
            Button("Buy More Credits") {
                showingCreditsShop = true
            }
            .foregroundColor(.blue)
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section("Actions") {
            if viewModel.hasActiveSubscription {
                Button("Manage in App Store") {
                    Task {
                        try? await storeKit.showManageSubscriptions()
                    }
                }
                .foregroundColor(.blue)
            }
            
            Button("Restore Purchases") {
                Task {
                    isRefreshing = true
                    await viewModel.restorePurchases()
                    isRefreshing = false
                }
            }
            .foregroundColor(.blue)
            .disabled(isRefreshing)
            
            if !viewModel.hasActiveSubscription {
                Button("Buy More Credits") {
                    showingCreditsShop = true
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section("Support") {
            Link("Help & FAQ", destination: URL(string: "https://photostop.app/help")!)
                .foregroundColor(.blue)
            
            Link("Contact Support", destination: URL(string: "mailto:support@photostop.app")!)
                .foregroundColor(.blue)
            
            Link("Privacy Policy", destination: URL(string: "https://photostop.app/privacy")!)
                .foregroundColor(.blue)
            
            Link("Terms of Service", destination: URL(string: "https://photostop.app/terms")!)
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshSubscriptionData() async {
        isRefreshing = true
        await storeKit.refreshSubscriptionStatus()
        isRefreshing = false
    }
    
    private var planDescription: String {
        switch viewModel.subscriptionStatus {
        case .notSubscribed:
            return "Limited features with basic AI credits"
        case .subscribed(let productID):
            if productID == StoreKitService.ProductID.proYearly.rawValue {
                return "Full access • Renews yearly"
            } else {
                return "Full access • Renews monthly"
            }
        case .expired:
            return "Subscription expired"
        case .inGracePeriod:
            return "Grace period • Update payment method"
        }
    }
    
    private var nextResetDate: String {
        let calendar = Calendar.current
        let now = Date()
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        let firstOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) ?? now
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: firstOfNextMonth)
    }
}

// MARK: - Usage Row Component

private struct UsageRow: View {
    let title: String
    let used: Int
    let remaining: Int
    let total: Int
    let color: Color
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(remaining) remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                
                HStack {
                    Text("\(used) used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(total) total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ManageSubscriptionView()
}


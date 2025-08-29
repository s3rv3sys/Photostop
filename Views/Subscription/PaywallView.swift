//
//  PaywallView.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI
import StoreKit

/// Beautiful paywall view for subscription upgrades
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()
    @ObservedObject private var storeKit = StoreKitService.shared
    
    let context: SubscriptionViewModel.PaywallContext
    let onPurchaseComplete: (() -> Void)?
    
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    
    init(
        context: SubscriptionViewModel.PaywallContext = .general,
        onPurchaseComplete: (() -> Void)? = nil
    ) {
        self.context = context
        self.onPurchaseComplete = onPurchaseComplete
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    heroSection
                    
                    // Plan Selection
                    planSelectionSection
                    
                    // Feature Comparison
                    featureComparisonSection
                    
                    // Credits Option (if applicable)
                    if context.showCreditsOption {
                        creditsSection
                    }
                    
                    // Call to Action
                    callToActionSection
                    
                    // Legal Footer
                    legalFooterSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Not Now") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            viewModel.setPresentationContext(context)
            
            Task {
                await storeKit.loadProducts()
            }
        }
        .onChange(of: viewModel.purchaseSuccess) { success in
            if success {
                onPurchaseComplete?()
                dismiss()
            }
        }
        .alert("Purchase Error", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error occurred")
        }
        .sheet(isPresented: $showingTerms) {
            SafariView(url: URL(string: "https://photostop.app/terms")!)
        }
        .sheet(isPresented: $showingPrivacy) {
            SafariView(url: URL(string: "https://photostop.app/privacy")!)
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            // App Icon
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.11, blue: 0.23),
                            Color(red: 0.24, green: 0.12, blue: 0.39)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white)
                }
            
            // Title and Subtitle
            VStack(spacing: 8) {
                Text(context.title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text(context.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Plan Selection
    
    private var planSelectionSection: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Monthly Plan
                PlanCard(
                    title: "Monthly",
                    price: viewModel.monthlyProduct?.displayPrice ?? "$9.99",
                    period: "month",
                    subtitle: "7-day free trial",
                    isSelected: viewModel.selectedPlan == .proMonthly,
                    isLoading: storeKit.isLoading
                ) {
                    viewModel.selectedPlan = .proMonthly
                }
                
                // Yearly Plan
                PlanCard(
                    title: "Yearly",
                    price: viewModel.yearlyProduct?.displayPrice ?? "$79.99",
                    period: "year",
                    subtitle: "Save \(viewModel.yearlySavingsPercentage)% • Best Value",
                    isSelected: viewModel.selectedPlan == .proYearly,
                    isLoading: storeKit.isLoading,
                    badge: "POPULAR"
                ) {
                    viewModel.selectedPlan = .proYearly
                }
            }
        }
    }
    
    // MARK: - Feature Comparison
    
    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What You Get")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(viewModel.featureComparison, id: \.feature) { item in
                    FeatureRow(
                        feature: item.feature,
                        freeValue: item.free,
                        proValue: item.pro
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Credits Section
    
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Just Need a Few Credits?")
                .font(.headline)
            
            HStack(spacing: 12) {
                // 10 Credits
                CreditCard(
                    title: "10 Premium Credits",
                    price: viewModel.credits10Product?.displayPrice ?? "$2.99",
                    isLoading: storeKit.isLoading
                ) {
                    Task {
                        await viewModel.purchaseCredits(.credits10)
                    }
                }
                
                // 50 Credits
                CreditCard(
                    title: "50 Premium Credits",
                    price: viewModel.credits50Product?.displayPrice ?? "$9.99",
                    isLoading: storeKit.isLoading
                ) {
                    Task {
                        await viewModel.purchaseCredits(.credits50)
                    }
                }
            }
        }
    }
    
    // MARK: - Call to Action
    
    private var callToActionSection: some View {
        VStack(spacing: 16) {
            // Primary CTA
            Button(action: {
                Task {
                    await viewModel.purchaseSelectedPlan()
                }
            }) {
                HStack {
                    if viewModel.isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(viewModel.getCallToActionText())
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.isAnyOperationInProgress || storeKit.isLoading)
            
            // Restore Purchases
            Button("Restore Purchases") {
                Task {
                    await viewModel.restorePurchases()
                }
            }
            .foregroundColor(.secondary)
            .disabled(viewModel.isAnyOperationInProgress)
        }
    }
    
    // MARK: - Legal Footer
    
    private var legalFooterSection: some View {
        VStack(spacing: 12) {
            Text("By subscribing you agree to our Terms and Privacy Policy. Subscription auto-renews until canceled in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Terms of Service") {
                    showingTerms = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Privacy Policy") {
                    showingPrivacy = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Supporting Views

private struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let subtitle: String
    let isSelected: Bool
    let isLoading: Bool
    let badge: String?
    let action: () -> Void
    
    init(
        title: String,
        price: String,
        period: String,
        subtitle: String,
        isSelected: Bool,
        isLoading: Bool,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.price = price
        self.period = period
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isLoading = isLoading
        self.badge = badge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
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
                    
                    if isLoading {
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(price)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("/\(period)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.blue : Color(UIColor.separator),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct FeatureRow: View {
    let feature: String
    let freeValue: String
    let proValue: String
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Free: \(freeValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Pro: \(proValue)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
    }
}

private struct CreditCard: View {
    let title: String
    let price: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(price)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(UIColor.separator))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Safari View for Legal Pages

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredBarTintColor = UIColor.systemBackground
        safari.preferredControlTintColor = UIColor.systemBlue
        
        return safari
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

import SafariServices

// MARK: - Preview

#Preview {
    PaywallView(context: .general)
}


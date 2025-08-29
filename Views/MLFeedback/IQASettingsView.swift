//
//  IQASettingsView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// Settings view for Image Quality Assessment feedback system
struct IQASettingsView: View {
    @StateObject private var feedbackService = IQAFeedbackService.shared
    @StateObject private var uploadQueue = UploadQueue.shared
    @StateObject private var personalizedScoring = PersonalizedScoringService.shared
    
    @State private var showExportSheet = false
    @State private var showClearAlert = false
    @State private var showResetAlert = false
    @State private var exportURL: URL?
    
    var body: some View {
        List {
            // Main toggle section
            Section {
                Toggle("Help Improve Auto-Selection", isOn: $feedbackService.isEnabled)
                    .onChange(of: feedbackService.isEnabled) { _, newValue in
                        feedbackService.enableFeedback(newValue)
                    }
                
                if feedbackService.isEnabled {
                    Text("Rate photo selections to help improve PhotoStop's auto-selection algorithm. Your feedback helps train better AI models.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Feedback System")
            }
            
            // Contribution section
            if feedbackService.isEnabled {
                Section {
                    Toggle("Contribute Anonymized Samples", isOn: $feedbackService.contributionEnabled)
                        .onChange(of: feedbackService.contributionEnabled) { _, newValue in
                            feedbackService.enableContribution(newValue)
                        }
                    
                    if feedbackService.contributionEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Share tiny, anonymized thumbnails and your ratings to make PhotoStop smarter for everyone.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text("No personal info • You can turn this off anytime")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Cloud Contribution")
                } footer: {
                    if feedbackService.contributionEnabled {
                        Text("Data is uploaded securely and used only to improve the AI model. See our Privacy Policy for details.")
                    }
                }
            }
            
            // Statistics section
            if feedbackService.isEnabled {
                Section("Your Contribution") {
                    StatRow(
                        title: "Total Ratings",
                        value: "\(feedbackService.totalRatings)",
                        icon: "star.fill",
                        color: .blue
                    )
                    
                    StatRow(
                        title: "Credits Earned",
                        value: "\(feedbackService.creditsEarned)/20",
                        icon: "gift.fill",
                        color: .green
                    )
                    
                    if feedbackService.contributionEnabled {
                        StatRow(
                            title: "Pending Uploads",
                            value: "\(uploadQueue.pendingUploads)",
                            icon: "icloud.and.arrow.up",
                            color: .orange
                        )
                        
                        StatRow(
                            title: "Total Uploaded",
                            value: "\(uploadQueue.totalUploaded)",
                            icon: "checkmark.icloud.fill",
                            color: .green
                        )
                    }
                }
            }
            
            // Personalization section
            if feedbackService.isEnabled {
                Section("Personalization") {
                    Toggle("Personalized Scoring", isOn: $personalizedScoring.isEnabled)
                    
                    if personalizedScoring.isEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Preferences")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(personalizedScoring.getPreferenceSummary())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        if personalizedScoring.preferences.totalRatings > 0 {
                            Button("Reset Preferences") {
                                showResetAlert = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                } footer: {
                    if personalizedScoring.isEnabled {
                        Text("Learns your photo preferences to better select frames that match your style.")
                    }
                }
            }
            
            // Data management section
            if feedbackService.isEnabled {
                Section("Data Management") {
                    Button("Export Training Data") {
                        exportData()
                    }
                    .disabled(feedbackService.totalRatings == 0)
                    
                    if feedbackService.contributionEnabled && uploadQueue.pendingUploads > 0 {
                        Button("Retry Failed Uploads") {
                            uploadQueue.retryFailedUploads()
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Button("Clear Local Data") {
                        showClearAlert = true
                    }
                    .foregroundColor(.red)
                    .disabled(feedbackService.totalRatings == 0)
                }
            }
            
            // Incentive information
            if feedbackService.isEnabled {
                Section {
                    IncentiveInfoView(
                        ratingsCount: feedbackService.totalRatings,
                        creditsEarned: feedbackService.creditsEarned
                    )
                } header: {
                    Text("Rewards")
                }
            }
        }
        .navigationTitle("Improve Auto-Selection")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExportSheet) {
            if let exportURL = exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .alert("Clear Local Data", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                feedbackService.clearLocalData()
            }
        } message: {
            Text("This will delete all local rating data and training samples. This action cannot be undone.")
        }
        .alert("Reset Preferences", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                personalizedScoring.resetPreferences()
            }
        } message: {
            Text("This will reset your personalized scoring preferences to default. Your rating history will be preserved.")
        }
    }
    
    private func exportData() {
        if let url = feedbackService.exportData() {
            exportURL = url
            showExportSheet = true
        }
    }
}

/// Statistics row view
struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
}

/// Incentive information view
struct IncentiveInfoView: View {
    let ratingsCount: Int
    let creditsEarned: Int
    
    private var nextRewardProgress: Float {
        let ratingsToNextReward = ratingsCount % 5
        return Float(ratingsToNextReward) / 5.0
    }
    
    private var ratingsUntilNextReward: Int {
        5 - (ratingsCount % 5)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.green)
                
                Text("Earn +1 Budget Credit per 5 ratings")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if creditsEarned < 20 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Progress to next reward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(ratingsUntilNextReward) more ratings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: nextRewardProgress)
                        .tint(.green)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Monthly reward limit reached")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Maximum 20 bonus credits per month")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#Preview {
    NavigationView {
        IQASettingsView()
    }
}


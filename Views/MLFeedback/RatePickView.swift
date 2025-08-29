//
//  RatePickView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI

/// View for rating frame selection quality
struct RatePickView: View {
    let onRate: (Bool, RatingReason?) -> Void
    let onDismiss: () -> Void
    
    @State private var showReasonSheet = false
    @State private var selectedRating: Bool?
    @State private var customFeedback = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Main question
            Text("Was this the best pick?")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Rating buttons
            HStack(spacing: 20) {
                Button {
                    selectedRating = true
                    onRate(true, nil)
                } label: {
                    Label("Yes", systemImage: "hand.thumbsup.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Rate as good pick")
                
                Button {
                    selectedRating = false
                    showReasonSheet = true
                } label: {
                    Label("No", systemImage: "hand.thumbsdown.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Rate as poor pick")
            }
            
            // Dismiss button
            Button("Maybe Later") {
                onDismiss()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showReasonSheet) {
            RatingReasonSheet { reason, feedback in
                onRate(false, reason)
                showReasonSheet = false
            } onCancel: {
                showReasonSheet = false
            }
        }
    }
}

/// Sheet for selecting rating reason
struct RatingReasonSheet: View {
    let onSubmit: (RatingReason?, String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedReason: RatingReason?
    @State private var customFeedback = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why wasn't this the best pick?")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Help us improve auto-selection by sharing what went wrong.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Reason options
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(RatingReason.allCases, id: \.self) { reason in
                            ReasonOptionView(
                                reason: reason,
                                isSelected: selectedReason == reason
                            ) {
                                selectedReason = reason
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Optional feedback
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional feedback (optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Tell us more...", text: $customFeedback, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button("Submit") {
                        onSubmit(selectedReason, customFeedback)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(selectedReason == nil)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Individual reason option view
struct ReasonOptionView: View {
    let reason: RatingReason
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: reason.systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 24)
                
                Text(reason.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(reason.displayName) reason")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Compact rating view for inline display
struct CompactRatePickView: View {
    let onRate: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Good pick?")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                onRate(true)
            } label: {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            }
            .accessibilityLabel("Rate as good")
            
            Button {
                onRate(false)
            } label: {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
            .accessibilityLabel("Rate as poor")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Previews

#Preview("Rate Pick View") {
    RatePickView(
        onRate: { rating, reason in
            print("Rated: \(rating), reason: \(reason?.displayName ?? "none")")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .padding()
}

#Preview("Rating Reason Sheet") {
    RatingReasonSheet(
        onSubmit: { reason, feedback in
            print("Reason: \(reason?.displayName ?? "none"), feedback: \(feedback)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}

#Preview("Compact Rate Pick View") {
    CompactRatePickView { rating in
        print("Compact rating: \(rating)")
    }
    .padding()
}


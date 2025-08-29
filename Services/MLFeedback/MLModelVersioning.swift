//
//  MLModelVersioning.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import CoreML
import OSLog

/// Service for managing ML model versions and training automation
@MainActor
final class MLModelVersioning: ObservableObject {
    
    static let shared = MLModelVersioning()
    
    @Published var currentModelVersion: String = "v20250829"
    @Published var availableUpdate: String?
    @Published var isCheckingForUpdates = false
    @Published var lastUpdateCheck: Date?
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "MLModelVersioning")
    private let userDefaults = UserDefaults.standard
    
    // Model paths
    private var modelURL: URL {
        Bundle.main.url(forResource: "FrameScoring", withExtension: "mlmodel")!
    }
    
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var updatedModelURL: URL {
        documentsURL.appendingPathComponent("FrameScoring_Updated.mlmodel")
    }
    
    private var versionInfoURL: URL {
        documentsURL.appendingPathComponent("model_version.json")
    }
    
    private init() {
        loadVersionInfo()
    }
    
    // MARK: - Public Interface
    
    func checkForModelUpdates() async {
        guard !isCheckingForUpdates else { return }
        
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }
        
        do {
            let latestVersion = try await fetchLatestModelVersion()
            
            if latestVersion != currentModelVersion {
                availableUpdate = latestVersion
                logger.info("Model update available: \(currentModelVersion) -> \(latestVersion)")
            } else {
                availableUpdate = nil
                logger.info("Model is up to date: \(currentModelVersion)")
            }
            
            lastUpdateCheck = Date()
            saveVersionInfo()
            
        } catch {
            logger.error("Failed to check for model updates: \(error.localizedDescription)")
        }
    }
    
    func downloadAndInstallUpdate() async -> Bool {
        guard let updateVersion = availableUpdate else {
            logger.warning("No update available to install")
            return false
        }
        
        do {
            let success = try await downloadModel(version: updateVersion)
            
            if success {
                currentModelVersion = updateVersion
                availableUpdate = nil
                saveVersionInfo()
                
                logger.info("Successfully updated model to version \(updateVersion)")
                return true
            } else {
                logger.error("Failed to download model update")
                return false
            }
            
        } catch {
            logger.error("Error installing model update: \(error.localizedDescription)")
            return false
        }
    }
    
    func getModelInfo() -> ModelInfo {
        return ModelInfo(
            version: currentModelVersion,
            bundledVersion: getBundledModelVersion(),
            isUpdated: FileManager.default.fileExists(atPath: updatedModelURL.path),
            lastUpdateCheck: lastUpdateCheck,
            availableUpdate: availableUpdate
        )
    }
    
    func getCurrentModel() throws -> MLModel {
        // Try to load updated model first, fall back to bundled model
        if FileManager.default.fileExists(atPath: updatedModelURL.path) {
            do {
                let model = try MLModel(contentsOf: updatedModelURL)
                logger.info("Loaded updated model from documents directory")
                return model
            } catch {
                logger.warning("Failed to load updated model, falling back to bundled: \(error.localizedDescription)")
            }
        }
        
        let model = try MLModel(contentsOf: modelURL)
        logger.info("Loaded bundled model")
        return model
    }
    
    // MARK: - Training Integration
    
    func submitTrainingData() async -> Bool {
        let feedbackService = IQAFeedbackService.shared
        
        guard feedbackService.totalRatings >= 50 else {
            logger.info("Insufficient training data: \(feedbackService.totalRatings) ratings (minimum 50)")
            return false
        }
        
        guard let exportURL = feedbackService.exportData() else {
            logger.error("Failed to export training data")
            return false
        }
        
        do {
            let success = try await uploadTrainingData(exportURL)
            
            if success {
                logger.info("Successfully submitted training data for model improvement")
                return true
            } else {
                logger.error("Failed to submit training data")
                return false
            }
            
        } catch {
            logger.error("Error submitting training data: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchLatestModelVersion() async throws -> String {
        // Simulate API call to check for latest model version
        let endpoint = "https://api.servesys.com/photostop/ml/latest-version"
        
        guard let url = URL(string: endpoint) else {
            throw ModelVersionError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ModelVersionError.serverError
        }
        
        let versionResponse = try JSONDecoder().decode(VersionResponse.self, from: data)
        return versionResponse.version
    }
    
    private func downloadModel(version: String) async throws -> Bool {
        // Simulate model download
        let endpoint = "https://api.servesys.com/photostop/ml/models/\(version)/FrameScoring.mlmodel"
        
        guard let url = URL(string: endpoint) else {
            throw ModelVersionError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ModelVersionError.downloadFailed
        }
        
        // Validate model before saving
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_model.mlmodel")
        try data.write(to: tempURL)
        
        // Try to load the model to validate it
        do {
            _ = try MLModel(contentsOf: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw ModelVersionError.invalidModel
        }
        
        // Move to final location
        if FileManager.default.fileExists(atPath: updatedModelURL.path) {
            try FileManager.default.removeItem(at: updatedModelURL)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: updatedModelURL)
        
        logger.info("Downloaded and validated model version \(version)")
        return true
    }
    
    private func uploadTrainingData(_ dataURL: URL) async throws -> Bool {
        // Simulate training data upload
        let endpoint = "https://api.servesys.com/photostop/ml/training-data"
        
        guard let url = URL(string: endpoint) else {
            throw ModelVersionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        let data = try Data(contentsOf: dataURL)
        request.httpBody = data
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ModelVersionError.uploadFailed
        }
        
        return true
    }
    
    private func getBundledModelVersion() -> String {
        // Extract version from bundled model metadata or use default
        return "v20250829" // This would be set during build process
    }
    
    private func loadVersionInfo() {
        guard FileManager.default.fileExists(atPath: versionInfoURL.path) else {
            currentModelVersion = getBundledModelVersion()
            return
        }
        
        do {
            let data = try Data(contentsOf: versionInfoURL)
            let versionInfo = try JSONDecoder().decode(StoredVersionInfo.self, from: data)
            
            currentModelVersion = versionInfo.currentVersion
            availableUpdate = versionInfo.availableUpdate
            lastUpdateCheck = versionInfo.lastUpdateCheck
            
        } catch {
            logger.error("Failed to load version info: \(error.localizedDescription)")
            currentModelVersion = getBundledModelVersion()
        }
    }
    
    private func saveVersionInfo() {
        let versionInfo = StoredVersionInfo(
            currentVersion: currentModelVersion,
            availableUpdate: availableUpdate,
            lastUpdateCheck: lastUpdateCheck
        )
        
        do {
            let data = try JSONEncoder().encode(versionInfo)
            try data.write(to: versionInfoURL)
        } catch {
            logger.error("Failed to save version info: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

struct ModelInfo {
    let version: String
    let bundledVersion: String
    let isUpdated: Bool
    let lastUpdateCheck: Date?
    let availableUpdate: String?
}

private struct VersionResponse: Codable {
    let version: String
    let releaseDate: String
    let improvements: [String]
}

private struct StoredVersionInfo: Codable {
    let currentVersion: String
    let availableUpdate: String?
    let lastUpdateCheck: Date?
}

private enum ModelVersionError: Error, LocalizedError {
    case invalidURL
    case serverError
    case downloadFailed
    case invalidModel
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid model service URL"
        case .serverError:
            return "Model service unavailable"
        case .downloadFailed:
            return "Failed to download model update"
        case .invalidModel:
            return "Downloaded model is invalid"
        case .uploadFailed:
            return "Failed to upload training data"
        }
    }
}

// MARK: - Extensions

extension MLModelVersioning {
    /// Check if automatic updates should be performed
    var shouldCheckForUpdates: Bool {
        guard let lastCheck = lastUpdateCheck else { return true }
        
        // Check for updates weekly
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return lastCheck < weekAgo
    }
    
    /// Get human-readable version info
    var versionDisplayString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        if let date = lastUpdateCheck {
            return "\(currentModelVersion) (checked \(dateFormatter.string(from: date)))"
        } else {
            return "\(currentModelVersion) (never checked)"
        }
    }
}


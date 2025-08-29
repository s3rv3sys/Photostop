//
//  UploadQueue.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import Foundation
import Network
import OSLog

/// Service for managing upload queue with exponential backoff and offline persistence
@MainActor
final class UploadQueue: ObservableObject {
    
    static let shared = UploadQueue()
    
    @Published var isUploading = false
    @Published var pendingUploads = 0
    @Published var totalUploaded = 0
    @Published var lastUploadDate: Date?
    
    private let logger = Logger(subsystem: "com.servesys.photostop", category: "UploadQueue")
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    private var isNetworkAvailable = false
    private var uploadTimer: Timer?
    
    // Configuration
    private let maxRetries = 5
    private let baseRetryDelay: TimeInterval = 2.0
    private let maxRetryDelay: TimeInterval = 300.0 // 5 minutes
    private let uploadInterval: TimeInterval = 30.0 // Try uploads every 30 seconds
    
    // File paths
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var queueURL: URL {
        documentsURL.appendingPathComponent("PhotoStopIQA/upload_queue.json")
    }
    
    private var statsURL: URL {
        documentsURL.appendingPathComponent("PhotoStopIQA/upload_stats.json")
    }
    
    private init() {
        setupNetworkMonitoring()
        loadStats()
        updatePendingCount()
        startUploadTimer()
    }
    
    deinit {
        networkMonitor.cancel()
        uploadTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    func enqueue(sample: IQASample, imageData: Data, installID: String) {
        let uploadItem = IQAUploadItem(sample: sample, imageData: imageData, installID: installID)
        
        var queue = loadQueue()
        queue.append(uploadItem)
        saveQueue(queue)
        
        updatePendingCount()
        
        logger.info("Enqueued IQA sample for upload: \(sample.id)")
        
        // Try immediate upload if network is available
        if isNetworkAvailable {
            Task {
                await processQueue()
            }
        }
    }
    
    func clearQueue() {
        saveQueue([])
        updatePendingCount()
        logger.info("Upload queue cleared")
    }
    
    func retryFailedUploads() {
        Task {
            await processQueue()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
                
                if path.status == .satisfied {
                    self?.logger.info("Network became available, processing upload queue")
                    await self?.processQueue()
                } else {
                    self?.logger.info("Network unavailable, pausing uploads")
                }
            }
        }
        
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func startUploadTimer() {
        uploadTimer = Timer.scheduledTimer(withTimeInterval: uploadInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processQueue()
            }
        }
    }
    
    private func processQueue() async {
        guard isNetworkAvailable && !isUploading else { return }
        
        var queue = loadQueue()
        guard !queue.isEmpty else { return }
        
        isUploading = true
        
        var processedItems: [IQAUploadItem] = []
        var remainingItems: [IQAUploadItem] = []
        
        for item in queue {
            let result = await uploadItem(item)
            
            switch result {
            case .success:
                processedItems.append(item)
                totalUploaded += 1
                lastUploadDate = Date()
                logger.info("Successfully uploaded IQA sample: \(item.sample.id)")
                
            case .failure(let error):
                let updatedItem = handleUploadFailure(item, error: error)
                
                if updatedItem.uploadAttempts < maxRetries {
                    remainingItems.append(updatedItem)
                } else {
                    logger.error("Max retries exceeded for IQA sample: \(item.sample.id)")
                }
            }
        }
        
        // Update queue with remaining items
        saveQueue(remainingItems)
        updatePendingCount()
        saveStats()
        
        isUploading = false
        
        logger.info("Upload batch completed: \(processedItems.count) uploaded, \(remainingItems.count) remaining")
    }
    
    private func uploadItem(_ item: IQAUploadItem) async -> Result<Void, Error> {
        // Simulate API endpoint - replace with actual implementation
        let endpoint = "https://api.servesys.com/photostop/iqa/submit"
        
        guard let url = URL(string: endpoint) else {
            return .failure(UploadError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body
        let requestBody = IQAUploadRequest(
            installID: item.installID,
            sample: item.sample,
            imageBase64: item.imageData.base64EncodedString()
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if 200...299 ~= httpResponse.statusCode {
                    return .success(())
                } else {
                    return .failure(UploadError.serverError(httpResponse.statusCode))
                }
            }
            
            return .failure(UploadError.invalidResponse)
            
        } catch {
            return .failure(error)
        }
    }
    
    private func handleUploadFailure(_ item: IQAUploadItem, error: Error) -> IQAUploadItem {
        let newAttempts = item.uploadAttempts + 1
        let delay = min(baseRetryDelay * pow(2.0, Double(newAttempts - 1)), maxRetryDelay)
        
        logger.warning("Upload failed for IQA sample \(item.sample.id), attempt \(newAttempts)/\(maxRetries), retry in \(delay)s: \(error.localizedDescription)")
        
        return IQAUploadItem(
            sample: item.sample,
            imageData: item.imageData,
            uploadAttempts: newAttempts,
            lastAttempt: Date(),
            installID: item.installID
        )
    }
    
    private func loadQueue() -> [IQAUploadItem] {
        guard FileManager.default.fileExists(atPath: queueURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: queueURL)
            return try JSONDecoder().decode([IQAUploadItem].self, from: data)
        } catch {
            logger.error("Failed to load upload queue: \(error.localizedDescription)")
            return []
        }
    }
    
    private func saveQueue(_ queue: [IQAUploadItem]) {
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: queueURL)
        } catch {
            logger.error("Failed to save upload queue: \(error.localizedDescription)")
        }
    }
    
    private func updatePendingCount() {
        pendingUploads = loadQueue().count
    }
    
    private func loadStats() {
        guard FileManager.default.fileExists(atPath: statsURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: statsURL)
            let stats = try JSONDecoder().decode(UploadStats.self, from: data)
            
            totalUploaded = stats.totalUploaded
            lastUploadDate = stats.lastUploadDate
        } catch {
            logger.error("Failed to load upload stats: \(error.localizedDescription)")
        }
    }
    
    private func saveStats() {
        let stats = UploadStats(
            totalUploaded: totalUploaded,
            lastUploadDate: lastUploadDate
        )
        
        do {
            let data = try JSONEncoder().encode(stats)
            try data.write(to: statsURL)
        } catch {
            logger.error("Failed to save upload stats: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

private struct IQAUploadRequest: Codable {
    let installID: String
    let sample: IQASample
    let imageBase64: String
}

private struct UploadStats: Codable {
    let totalUploaded: Int
    let lastUploadDate: Date?
}

private enum UploadError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid upload URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

// Extension to IQAUploadItem to support retry logic
extension IQAUploadItem {
    init(sample: IQASample, imageData: Data, uploadAttempts: Int, lastAttempt: Date?, installID: String) {
        self.sample = sample
        self.imageData = imageData
        self.uploadAttempts = uploadAttempts
        self.lastAttempt = lastAttempt
        self.installID = installID
    }
}


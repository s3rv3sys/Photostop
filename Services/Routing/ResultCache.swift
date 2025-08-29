//
//  ResultCache.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import CryptoKit
import os.log

/// Caches edit results to avoid duplicate API calls and improve performance
final class ResultCache: @unchecked Sendable {
    static let shared = ResultCache()
    
    private let memoryCache = NSCache<NSString, CachedResult>()
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "PhotoStop", category: "ResultCache")
    
    // Cache configuration
    private let maxMemoryItems = 50
    private let maxDiskSizeMB = 100
    private let cacheExpirationDays = 7
    
    private lazy var cacheDirectory: URL = {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = urls[0].appendingPathComponent("PhotoStop/EditCache")
        
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }()
    
    private init() {
        setupMemoryCache()
        cleanupExpiredEntries()
    }
    
    // MARK: - Public Interface
    
    /// Generate cache key for an edit operation
    public func key(
        for image: UIImage,
        prompt: String?,
        provider: ProviderID,
        task: EditTask,
        options: EditOptions
    ) -> String {
        var data = Data()
        
        // Add image data (use smaller representation for key generation)
        if let thumbnail = image.prepareThumbnail(of: CGSize(width: 256, height: 256)),
           let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
            data.append(thumbnailData)
        }
        
        // Add prompt
        if let prompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty {
            data.append(prompt.data(using: .utf8) ?? Data())
        }
        
        // Add provider and task
        data.append(provider.rawValue.data(using: .utf8) ?? Data())
        data.append(task.rawValue.data(using: .utf8) ?? Data())
        
        // Add relevant options
        if let targetSize = options.targetSize {
            data.append("\(targetSize.width)x\(targetSize.height)".data(using: .utf8) ?? Data())
        }
        data.append("\(options.quality)".data(using: .utf8) ?? Data())
        data.append(options.allowWatermark ? "1" : "0".data(using: .utf8) ?? Data())
        
        // Generate SHA256 hash
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Get cached result if available
    public func get(_ key: String) -> CachedResult? {
        // Check memory cache first
        if let result = memoryCache.object(forKey: key as NSString) {
            if !result.isExpired {
                logger.debug("Cache hit (memory): \(key)")
                return result
            } else {
                memoryCache.removeObject(forKey: key as NSString)
            }
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let result = try? JSONDecoder().decode(CachedResult.self, from: data) else {
            return nil
        }
        
        if result.isExpired {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        // Load image from disk
        let imageURL = cacheDirectory.appendingPathComponent("\(key).jpg")
        if let imageData = try? Data(contentsOf: imageURL),
           let image = UIImage(data: imageData) {
            let fullResult = CachedResult(
                image: image,
                provider: result.provider,
                costClass: result.costClass,
                processingTime: result.processingTime,
                timestamp: result.timestamp,
                metadata: result.metadata
            )
            
            // Add back to memory cache
            memoryCache.setObject(fullResult, forKey: key as NSString)
            logger.debug("Cache hit (disk): \(key)")
            return fullResult
        }
        
        return nil
    }
    
    /// Store result in cache
    public func set(_ key: String, result: ProviderResult) {
        let cachedResult = CachedResult(
            image: result.image,
            provider: result.provider,
            costClass: result.costClass,
            processingTime: result.processingTime,
            timestamp: Date(),
            metadata: result.metadata
        )
        
        // Store in memory cache
        memoryCache.setObject(cachedResult, forKey: key as NSString)
        
        // Store on disk asynchronously
        Task.detached { [weak self] in
            await self?.storeToDisk(key: key, result: cachedResult)
        }
        
        logger.debug("Cached result: \(key)")
    }
    
    /// Clear all cached results
    public func clearAll() {
        memoryCache.removeAllObjects()
        
        Task.detached { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
        
        logger.info("Cache cleared")
    }
    
    /// Get cache statistics
    public func getStats() -> CacheStats {
        let memoryCount = memoryCache.totalCostLimit > 0 ? memoryCache.totalCostLimit : 0
        
        var diskCount = 0
        var diskSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "cache" || fileURL.pathExtension == "jpg" {
                    diskCount += 1
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        diskSize += Int64(size)
                    }
                }
            }
        }
        
        return CacheStats(
            memoryItems: memoryCount,
            diskItems: diskCount / 2, // Each entry has 2 files (.cache + .jpg)
            diskSizeBytes: diskSize,
            hitRate: 0.0 // Would need to track hits/misses for accurate rate
        )
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryCache() {
        memoryCache.countLimit = maxMemoryItems
        memoryCache.totalCostLimit = maxMemoryItems * 1024 * 1024 // Rough estimate
        
        // Clear memory cache on memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.memoryCache.removeAllObjects()
        }
    }
    
    private func storeToDisk(key: String, result: CachedResult) async {
        do {
            // Store metadata
            let metadataURL = cacheDirectory.appendingPathComponent("\(key).cache")
            let metadataData = try JSONEncoder().encode(result)
            try metadataData.write(to: metadataURL)
            
            // Store image
            let imageURL = cacheDirectory.appendingPathComponent("\(key).jpg")
            if let imageData = result.image.jpegData(compressionQuality: 0.9) {
                try imageData.write(to: imageURL)
            }
            
        } catch {
            logger.error("Failed to store cache entry: \(error)")
        }
    }
    
    private func cleanupExpiredEntries() {
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            let cutoffDate = Date().addingTimeInterval(-TimeInterval(self.cacheExpirationDays * 24 * 60 * 60))
            
            guard let enumerator = self.fileManager.enumerator(
                at: self.cacheDirectory,
                includingPropertiesForKeys: [.creationDateKey]
            ) else { return }
            
            var removedCount = 0
            
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "cache" else { continue }
                
                do {
                    let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
                    if let creationDate = attributes.creationDate, creationDate < cutoffDate {
                        // Remove both metadata and image files
                        let baseName = fileURL.deletingPathExtension().lastPathComponent
                        let imageURL = self.cacheDirectory.appendingPathComponent("\(baseName).jpg")
                        
                        try? self.fileManager.removeItem(at: fileURL)
                        try? self.fileManager.removeItem(at: imageURL)
                        removedCount += 1
                    }
                } catch {
                    // Ignore errors for individual files
                }
            }
            
            if removedCount > 0 {
                self.logger.info("Cleaned up \(removedCount) expired cache entries")
            }
        }
    }
}

// MARK: - Supporting Types

/// Cached result with metadata
public class CachedResult: NSObject, Codable {
    public let image: UIImage
    public let provider: ProviderID
    public let costClass: CostClass
    public let processingTime: TimeInterval
    public let timestamp: Date
    public let metadata: [String: String] // Simplified for Codable
    
    public init(
        image: UIImage,
        provider: ProviderID,
        costClass: CostClass,
        processingTime: TimeInterval,
        timestamp: Date,
        metadata: [String: Any] = [:]
    ) {
        self.image = image
        self.provider = provider
        self.costClass = costClass
        self.processingTime = processingTime
        self.timestamp = timestamp
        
        // Convert metadata to string-only dictionary for Codable
        self.metadata = metadata.compactMapValues { value in
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            } else {
                return String(describing: value)
            }
        }
        
        super.init()
    }
    
    /// Check if this cached result has expired
    public var isExpired: Bool {
        let expirationInterval = TimeInterval(7 * 24 * 60 * 60) // 7 days
        return Date().timeIntervalSince(timestamp) > expirationInterval
    }
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case imageData, provider, costClass, processingTime, timestamp, metadata
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let imageData = try container.decode(Data.self, forKey: .imageData)
        guard let image = UIImage(data: imageData) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid image data")
            )
        }
        
        self.image = image
        self.provider = try container.decode(ProviderID.self, forKey: .provider)
        self.costClass = try container.decode(CostClass.self, forKey: .costClass)
        self.processingTime = try container.decode(TimeInterval.self, forKey: .processingTime)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.metadata = try container.decode([String: String].self, forKey: .metadata)
        
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw EncodingError.invalidValue(
                image,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode image")
            )
        }
        
        try container.encode(imageData, forKey: .imageData)
        try container.encode(provider, forKey: .provider)
        try container.encode(costClass, forKey: .costClass)
        try container.encode(processingTime, forKey: .processingTime)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(metadata, forKey: .metadata)
    }
}

/// Cache performance statistics
public struct CacheStats {
    public let memoryItems: Int
    public let diskItems: Int
    public let diskSizeBytes: Int64
    public let hitRate: Double
    
    public var diskSizeMB: Double {
        return Double(diskSizeBytes) / (1024 * 1024)
    }
    
    public var formattedDiskSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: diskSizeBytes)
    }
}


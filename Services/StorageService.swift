//
//  StorageService.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import UIKit
import Photos
import Foundation

/// Service responsible for saving images to Photos library and managing local storage
@MainActor
class StorageService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var isSaving = false
    @Published var saveError: StorageError?
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private lazy var documentsDirectory: URL = {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }()
    
    private lazy var editedImagesDirectory: URL = {
        let url = documentsDirectory.appendingPathComponent("EditedImages")
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    
    init() {
        checkPhotoLibraryAuthorizationStatus()
    }
    
    // MARK: - Public Methods
    
    /// Request photo library permission
    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            await updateAuthorizationStatus()
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            await updateAuthorizationStatus()
            return false
        @unknown default:
            return false
        }
    }
    
    /// Save image to Photos library
    func saveToPhotos(_ image: UIImage) async -> Bool {
        guard await requestPhotoLibraryPermission() else {
            saveError = .permissionDenied
            return false
        }
        
        isSaving = true
        saveError = nil
        
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }) { [weak self] success, error in
                DispatchQueue.main.async {
                    self?.isSaving = false
                    
                    if let error = error {
                        self?.saveError = .saveError(error.localizedDescription)
                    }
                    
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    /// Save EditedImage locally
    func saveEditedImageLocally(_ editedImage: EditedImage) async -> Bool {
        do {
            let filename = "\(editedImage.id.uuidString).json"
            let fileURL = editedImagesDirectory.appendingPathComponent(filename)
            
            let data = try JSONEncoder().encode(editedImage)
            try data.write(to: fileURL)
            
            return true
        } catch {
            saveError = .localSaveError(error.localizedDescription)
            return false
        }
    }
    
    /// Load all locally saved EditedImages
    func loadEditedImages() async -> [EditedImage] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: editedImagesDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
            
            var editedImages: [EditedImage] = []
            
            for fileURL in fileURLs {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let editedImage = try JSONDecoder().decode(EditedImage.self, from: data)
                    editedImages.append(editedImage)
                } catch {
                    print("Failed to load edited image from \(fileURL): \(error)")
                }
            }
            
            // Sort by timestamp, newest first
            return editedImages.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Failed to load edited images directory: \(error)")
            return []
        }
    }
    
    /// Delete locally saved EditedImage
    func deleteEditedImage(_ editedImage: EditedImage) async -> Bool {
        do {
            let filename = "\(editedImage.id.uuidString).json"
            let fileURL = editedImagesDirectory.appendingPathComponent(filename)
            
            try fileManager.removeItem(at: fileURL)
            return true
        } catch {
            saveError = .deleteError(error.localizedDescription)
            return false
        }
    }
    
    /// Get total storage used by edited images
    func getStorageUsed() async -> Int64 {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: editedImagesDirectory,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            var totalSize: Int64 = 0
            
            for fileURL in fileURLs {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
            
            return totalSize
        } catch {
            return 0
        }
    }
    
    /// Clean up old edited images (keep only recent ones)
    func cleanupOldImages(keepCount: Int = 50) async -> Int {
        let editedImages = await loadEditedImages()
        
        guard editedImages.count > keepCount else { return 0 }
        
        let imagesToDelete = Array(editedImages.dropFirst(keepCount))
        var deletedCount = 0
        
        for image in imagesToDelete {
            if await deleteEditedImage(image) {
                deletedCount += 1
            }
        }
        
        return deletedCount
    }
    
    /// Export edited image as high-quality JPEG
    func exportImage(_ image: UIImage, quality: CGFloat = 0.9) -> Data? {
        return image.jpegData(compressionQuality: quality)
    }
    
    /// Get human-readable storage size
    func getStorageUsedString() async -> String {
        let bytes = await getStorageUsed()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Private Methods
    
    private func checkPhotoLibraryAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
    
    private func updateAuthorizationStatus() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
}

// MARK: - Storage Errors
enum StorageError: LocalizedError {
    case permissionDenied
    case saveError(String)
    case localSaveError(String)
    case deleteError(String)
    case loadError(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo library permission denied"
        case .saveError(let message):
            return "Failed to save to Photos: \(message)"
        case .localSaveError(let message):
            return "Failed to save locally: \(message)"
        case .deleteError(let message):
            return "Failed to delete: \(message)"
        case .loadError(let message):
            return "Failed to load: \(message)"
        }
    }
}


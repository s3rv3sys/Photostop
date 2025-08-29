//
//  StorageServiceTests.swift
//  PhotoStopTests
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import XCTest
@testable import PhotoStop

@MainActor
final class StorageServiceTests: XCTestCase {
    
    var storageService: StorageService!
    var testImage: UIImage!
    var testEditedImage: EditedImage!
    
    override func setUp() {
        super.setUp()
        storageService = StorageService()
        testImage = UIImage(systemName: "photo")!
        
        // Create test edited image
        testEditedImage = EditedImage(
            originalImage: testImage,
            enhancedImage: testImage,
            prompt: "Test enhancement",
            qualityScore: 0.85,
            processingTime: 1.5
        )
    }
    
    override func tearDown() {
        storageService = nil
        testImage = nil
        testEditedImage = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testStorageServiceInitialization() {
        XCTAssertNotNil(storageService)
        XCTAssertFalse(storageService.isSaving)
        XCTAssertNil(storageService.saveError)
    }
    
    // MARK: - Local Storage Tests
    
    func testSaveImageLocally() async {
        do {
            let url = try await storageService.saveImageLocally(testImage, filename: "test_image")
            
            XCTAssertNotNil(url)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            
            // Clean up
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testSaveEditedImageLocally() async {
        do {
            let url = try await storageService.saveEditedImageLocally(testEditedImage)
            
            XCTAssertNotNil(url)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            
            // Clean up
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testLoadEditedImagesFromLocal() async {
        // First save an image
        do {
            _ = try await storageService.saveEditedImageLocally(testEditedImage)
            
            // Then load all images
            let loadedImages = await storageService.loadEditedImagesFromLocal()
            
            XCTAssertFalse(loadedImages.isEmpty)
            
            // Clean up
            for image in loadedImages {
                if let url = image.localURL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testDeleteLocalImage() async {
        // First save an image
        do {
            let url = try await storageService.saveImageLocally(testImage, filename: "test_delete")
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            
            // Delete the image
            let success = await storageService.deleteLocalImage(at: url)
            
            XCTAssertTrue(success)
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    // MARK: - File Management Tests
    
    func testDocumentsDirectory() {
        let documentsURL = storageService.documentsDirectory
        
        XCTAssertNotNil(documentsURL)
        XCTAssertTrue(documentsURL.hasDirectoryPath)
    }
    
    func testPhotoStopDirectory() {
        let photoStopURL = storageService.photoStopDirectory
        
        XCTAssertNotNil(photoStopURL)
        XCTAssertTrue(photoStopURL.hasDirectoryPath)
        XCTAssertTrue(photoStopURL.lastPathComponent == "PhotoStop")
    }
    
    func testUniqueFilename() {
        let filename1 = storageService.uniqueFilename(base: "test", extension: "jpg")
        let filename2 = storageService.uniqueFilename(base: "test", extension: "jpg")
        
        XCTAssertNotEqual(filename1, filename2)
        XCTAssertTrue(filename1.hasSuffix(".jpg"))
        XCTAssertTrue(filename2.hasSuffix(".jpg"))
    }
    
    // MARK: - Error Handling Tests
    
    func testStorageErrorTypes() {
        let permissionError = StorageError.permissionDenied
        let fileError = StorageError.fileNotFound
        let saveError = StorageError.saveFailed("Test error")
        let loadError = StorageError.loadFailed("Test error")
        
        XCTAssertEqual(permissionError.errorDescription, "Photo library permission denied")
        XCTAssertEqual(fileError.errorDescription, "File not found")
        XCTAssertEqual(saveError.errorDescription, "Save failed: Test error")
        XCTAssertEqual(loadError.errorDescription, "Load failed: Test error")
    }
    
    // MARK: - Performance Tests
    
    func testSavePerformance() {
        measure {
            Task {
                do {
                    let url = try await storageService.saveImageLocally(testImage, filename: "perf_test")
                    try? FileManager.default.removeItem(at: url)
                } catch {
                    // Expected in performance test
                }
            }
        }
    }
    
    func testLoadPerformance() {
        measure {
            Task {
                _ = await storageService.loadEditedImagesFromLocal()
            }
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentSave() async {
        let image1 = testImage
        let image2 = UIImage(systemName: "photo.fill")!
        
        // Save two images concurrently
        async let save1 = storageService.saveImageLocally(image1, filename: "concurrent1")
        async let save2 = storageService.saveImageLocally(image2, filename: "concurrent2")
        
        do {
            let (url1, url2) = try await (save1, save2)
            
            XCTAssertNotEqual(url1, url2)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url1.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: url2.path))
            
            // Clean up
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        } catch {
            XCTFail("Concurrent saves should succeed: \(error)")
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryUsage() {
        weak var weakStorageService = storageService
        storageService = nil
        
        // Give some time for deallocation
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNil(weakStorageService, "StorageService should be deallocated")
    }
}

// MARK: - Mock Storage Service

class MockStorageService: StorageService {
    var mockSaveSuccess = true
    var mockLoadedImages: [EditedImage] = []
    var mockError: StorageError?
    
    override func saveImageLocally(_ image: UIImage, filename: String) async throws -> URL {
        if let error = mockError {
            throw error
        }
        
        if !mockSaveSuccess {
            throw StorageError.saveFailed("Mock save failed")
        }
        
        // Return a mock URL
        return documentsDirectory.appendingPathComponent("\(filename).jpg")
    }
    
    override func saveEditedImageLocally(_ editedImage: EditedImage) async throws -> URL {
        if let error = mockError {
            throw error
        }
        
        if !mockSaveSuccess {
            throw StorageError.saveFailed("Mock save failed")
        }
        
        return documentsDirectory.appendingPathComponent("mock_edited.jpg")
    }
    
    override func loadEditedImagesFromLocal() async -> [EditedImage] {
        return mockLoadedImages
    }
    
    override func deleteLocalImage(at url: URL) async -> Bool {
        return mockSaveSuccess
    }
}

// MARK: - Integration Tests

final class StorageServiceIntegrationTests: XCTestCase {
    
    var mockStorageService: MockStorageService!
    var testImage: UIImage!
    var testEditedImage: EditedImage!
    
    override func setUp() {
        super.setUp()
        mockStorageService = MockStorageService()
        testImage = UIImage(systemName: "photo")!
        testEditedImage = EditedImage(
            originalImage: testImage,
            enhancedImage: testImage,
            prompt: "Test",
            qualityScore: 0.8,
            processingTime: 1.0
        )
    }
    
    override func tearDown() {
        mockStorageService = nil
        testImage = nil
        testEditedImage = nil
        super.tearDown()
    }
    
    func testSuccessfulSave() async {
        mockStorageService.mockSaveSuccess = true
        
        do {
            let url = try await mockStorageService.saveImageLocally(testImage, filename: "test")
            XCTAssertNotNil(url)
        } catch {
            XCTFail("Mock save should succeed: \(error)")
        }
    }
    
    func testFailedSave() async {
        mockStorageService.mockSaveSuccess = false
        
        do {
            _ = try await mockStorageService.saveImageLocally(testImage, filename: "test")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is StorageError)
        }
    }
    
    func testLoadImages() async {
        let mockImages = [testEditedImage, testEditedImage]
        mockStorageService.mockLoadedImages = mockImages
        
        let loadedImages = await mockStorageService.loadEditedImagesFromLocal()
        
        XCTAssertEqual(loadedImages.count, 2)
    }
    
    func testDeleteImage() async {
        mockStorageService.mockSaveSuccess = true
        
        let url = URL(fileURLWithPath: "/mock/path")
        let success = await mockStorageService.deleteLocalImage(at: url)
        
        XCTAssertTrue(success)
    }
}


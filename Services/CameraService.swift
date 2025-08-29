//
//  CameraService.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import AVFoundation
import UIKit
import Combine

/// Service responsible for camera operations including burst capture and live preview
@MainActor
class CameraService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isSessionRunning = false
    @Published var isCapturing = false
    @Published var captureError: CameraError?
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    // MARK: - Private Properties
    private let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // Burst capture properties
    private var burstCaptureCount = 0
    private var targetBurstCount = 3
    private var capturedImages: [UIImage] = []
    private var burstCompletion: (([UIImage]) -> Void)?
    
    // Preview layer
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    // MARK: - Public Methods
    
    /// Request camera permission and setup session
    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            await setupSession()
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await setupSession()
            }
            await updateAuthorizationStatus()
            return granted
        case .denied, .restricted:
            await updateAuthorizationStatus()
            return false
        @unknown default:
            return false
        }
    }
    
    /// Start the camera session
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.session.isRunning {
                self.session.startRunning()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }
    
    /// Stop the camera session
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    /// Capture burst of images with different exposures
    func captureBurst(count: Int = 3) async -> [UIImage] {
        guard !isCapturing else {
            return []
        }
        
        isCapturing = true
        capturedImages.removeAll()
        burstCaptureCount = 0
        targetBurstCount = count
        
        return await withCheckedContinuation { continuation in
            burstCompletion = { images in
                continuation.resume(returning: images)
            }
            
            // Start burst capture
            sessionQueue.async { [weak self] in
                self?.startBurstCapture()
            }
        }
    }
    
    /// Get preview layer for camera view
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard previewLayer == nil else { return previewLayer }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        return previewLayer
    }
    
    /// Switch between front and back camera
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Remove current input
            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }
            
            // Get the other camera
            let currentPosition = self.videoDeviceInput?.device.position ?? .back
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            
            if let newDevice = self.getCamera(for: newPosition),
               let newInput = try? AVCaptureDeviceInput(device: newDevice) {
                
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                }
            }
            
            self.session.commitConfiguration()
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    private func updateAuthorizationStatus() async {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    private func setupSession() async {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Configure session preset
            if self.session.canSetSessionPreset(.photo) {
                self.session.sessionPreset = .photo
            }
            
            // Add video input
            guard let videoDevice = self.getCamera(for: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                DispatchQueue.main.async {
                    self.captureError = .deviceNotFound
                }
                return
            }
            
            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            }
            
            // Add photo output
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                
                // Configure photo output
                self.photoOutput.isHighResolutionCaptureEnabled = true
                if self.photoOutput.isLivePhotoCaptureSupported {
                    self.photoOutput.isLivePhotoCaptureEnabled = false
                }
            }
            
            self.session.commitConfiguration()
        }
    }
    
    private func getCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualCamera,
            .builtInTrueDepthCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        
        return discoverySession.devices.first
    }
    
    private func startBurstCapture() {
        guard burstCaptureCount < targetBurstCount else {
            completeBurstCapture()
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        
        // Vary exposure for burst
        if let device = videoDeviceInput?.device {
            do {
                try device.lockForConfiguration()
                
                // Adjust exposure for each shot
                let exposureBias: Float = {
                    switch burstCaptureCount {
                    case 0: return -0.5  // Slightly underexposed
                    case 1: return 0.0   // Normal exposure
                    case 2: return 0.5   // Slightly overexposed
                    default: return 0.0
                    }
                }()
                
                device.setExposureTargetBias(exposureBias, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                print("Failed to adjust exposure: \(error)")
            }
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func completeBurstCapture() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isCapturing = false
            self.burstCompletion?(self.capturedImages)
            self.burstCompletion = nil
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = .captureError(error.localizedDescription)
                self?.isCapturing = false
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = .imageProcessingError
                self?.isCapturing = false
            }
            return
        }
        
        // Add captured image to burst collection
        capturedImages.append(image)
        burstCaptureCount += 1
        
        // Continue burst or complete
        if burstCaptureCount < targetBurstCount {
            // Small delay between captures
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.startBurstCapture()
            }
        } else {
            completeBurstCapture()
        }
    }
}

// MARK: - Camera Errors
enum CameraError: LocalizedError {
    case deviceNotFound
    case permissionDenied
    case captureError(String)
    case imageProcessingError
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Camera device not found"
        case .permissionDenied:
            return "Camera permission denied"
        case .captureError(let message):
            return "Capture error: \(message)"
        case .imageProcessingError:
            return "Failed to process captured image"
        }
    }
}

